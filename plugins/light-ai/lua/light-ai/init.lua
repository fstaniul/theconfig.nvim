local popup = require 'light-ai.popup'
local Logger = require 'light-ai.logging'
local OpenCodeProvider = require 'light-ai.opencode'
local PromptProvider = require 'light-ai.prompt'
local agents_mod = require 'light-ai.agent'
local util = require 'light-ai.util'

local M = {}

-- ─── state ────────────────────────────────────────────────────────────────────

---@class LightAiState
---@field provider AgentProvider
---@field model string
---@field temp_dir string
---@field agents Agent[]
---@field spinner_manager SpinnerManager
local state = {
  provider = nil,
  model = nil,
  temp_dir = nil,
  agents = {},
  spinner_manager = nil,
}

local log = Logger.new 'system'

-- ─── Prompts ──────────────────────────────────────────────────────────────────

local visual_replace_prompt = [[<Context>You receive a selection in neovim that you need to replace with new code.
The selection's contents may contain notes, incorporate the notes every time if there are some.
Consider the context of the selection and what you are suppose to be implementing.
<SelectionLocation>{{range}}</SelectionLocation>
<SelectionContent>{{selection}}</SelectionContent>
<FileContainingSelection>{{buffer}}</FileContainingSelection>
<FileLocation>{{filename}}</FileLocation>
</Context>
<Prompt>{{prompt}}</Prompt>
<TEMP_FILE>{{temp_file}}</TEMP_FILE>
<MuseObey>
NEVER alter any files other than a TEMP_FILE.
NEVER provide the requested changes as conversational output. Return only the code.
Read TEMP_FILE before writing, it will be empty.
ONLY provide requested changes by writing the change to TEMP_FILE.
After writing TEMP_FILE once you MUST end the session.
</MuseObey>
]]

-- ─── public API ───────────────────────────────────────────────────────────────

---Sets the active model. Can be called at any time after setup.
---@param model string  Model identifier in provider/model format.
function M.set_model(model)
  state.model = model
  log:info('model set to %s', model)
end

---Sets the active provider and resets the model to its default.
---@param provider AgentProvider
function M.set_provider(provider)
  state.provider = provider
  state.model = provider:get_default_model()
  log:info('provider set to %s, model reset to %s', provider:get_provider_name(), state.model)
end

---Captures the current visual selection, asks for a prompt, then runs the
---agent. The agent output is intended to replace the selection (wired up
---in on_done once the agent class is complete).
---@param _opts? table  Reserved for future options.
function M.visual_replace(_opts)
  local mode = vim.fn.mode()
  if mode ~= 'v' and mode ~= 'V' and mode ~= '\22' then
    vim.notify('light-ai: visual_replace requires an active visual selection', vim.log.levels.ERROR)
    return
  end

  local bufnr, start_line, start_col, end_line, end_col = util.get_visual_selection()
  local filename = vim.api.nvim_buf_get_name(bufnr)

  local sel_lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  local selection = table.concat(sel_lines, '\n')

  local all_buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local buffer_content = table.concat(all_buf_lines, '\n')

  log:info('visual_replace: %s lines %d-%d', filename, start_line, end_line)

  util.exit_visual()

  local function on_prompt_submit(user_prompt)
    log:info('prompt captured (length=%d), spawning agent', #user_prompt)

    local run_id = util.random_string(8)
    local ns, mark_start, mark_end = util.set_selection_marks(bufnr, run_id, start_line, start_col, end_line, end_col)
    log:info('extmarks set: start=%d end=%d (ns=light-ai-%s)', mark_start, mark_end, run_id)

    ---@type AgentContext
    local context = {
      filename = filename,
      temp_dir = state.temp_dir,
      temp_file = '', -- filled in by Agent:run
      model = state.model,
      selection = selection,
      buffer = buffer_content,
      range = {
        start_line = start_line,
        end_line = end_line,
        start_col = start_col,
        end_col = end_col,
      },
      user_prompt = user_prompt,
    }

    local num = #state.agents + 1
    local agent = agents_mod.Agent.new(num, run_id, state.provider, PromptProvider.new(visual_replace_prompt))

    table.insert(state.agents, agent)
    log:info('agent #%d created (id=%s), log=%s', num, agent.id, agent:log_file())

    state.spinner_manager:agent_start(agent)

    agent:run(user_prompt, context, function(status)
      state.spinner_manager:agent_done(agent)
      log:info('agent #%d finished with status=%s', num, status)

      local cur_start, cur_end = util.pop_selection_marks(bufnr, ns, mark_start, mark_end)
      log:info('extmarks resolved: start=%d end=%d (original %d-%d)', cur_start, cur_end, start_line, end_line)

      if status ~= 'done' then return end

      local fh = io.open(agent.temp_file, 'r')
      if not fh then
        log:error('agent #%d: could not open temp file %s', num, agent.temp_file)
        vim.notify('light-ai: could not read agent output', vim.log.levels.ERROR)
        return
      end

      local content = fh:read '*a'
      fh:close()

      if not content or vim.trim(content) == '' then
        log:error('agent #%d: temp file is empty', num)
        vim.notify('light-ai: agent returned empty output', vim.log.levels.ERROR)
        return
      end

      local lines = vim.split(content, '\n', { plain = true })

      vim.api.nvim_buf_set_lines(bufnr, cur_start - 1, cur_end, false, lines)
      log:info('agent #%d: replaced lines %d-%d (%d lines written)', num, cur_start, cur_end, #lines)
    end)
  end

  local function on_prompt_cancel(_) log:info 'prompt cancelled' end

  popup.input('AI Prompt', on_prompt_submit, on_prompt_cancel)
end

---Aborts all currently running agents.
function M.abort_all()
  local count = 0
  for _, agent in ipairs(state.agents) do
    if agent.status == 'running' then
      agent:abort()
      count = count + 1
    end
  end
  log:info('abort_all: aborted %d agent(s)', count)
  if count > 0 then
    vim.notify(string.format('light-ai: aborted %d running agent(s)', count), vim.log.levels.INFO)
  else
    vim.notify('light-ai: no running agents to abort', vim.log.levels.INFO)
  end
end

-- ─── setup ────────────────────────────────────────────────────────────────────

---@class LightAiOpts
---@field provider? AgentProvider  Defaults to OpenCodeProvider.
---@field model? string            Defaults to provider:get_default_model().
---@field temp_dir string          Directory for temporary files.

---@param opts? LightAiOpts
function M.setup(opts)
  opts = opts or {}

  assert(opts.temp_dir and opts.temp_dir ~= '', 'light-ai: opts.temp_dir is required')

  state.provider = opts.provider or OpenCodeProvider:new()
  state.model = opts.model or state.provider:get_default_model()
  state.temp_dir = opts.temp_dir
  state.spinner_manager = popup.SpinnerManager.new(state.agents)
end

return M
