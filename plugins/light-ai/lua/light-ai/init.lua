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
---@diagnostic disable: assign-type-mismatch
local state = {
  provider = nil,
  model = nil,
  temp_dir = nil,
  agents = {},
  spinner_manager = nil,
}
---@diagnostic enable: assign-type-mismatch

local log = Logger.new 'system'

-- ─── search highlights ────────────────────────────────────────────────────────

-- Namespace for all search range extmarks.
local search_ns = vim.api.nvim_create_namespace 'light-ai-search'

-- Persistent table: absolute filepath → list of { lnum, col, len } (1-based).
-- Accumulates across searches; never cleared automatically.
---@type table<string, {lnum:integer, col:integer, len:integer}[]>
local search_highlights = {}

---Applies any pending search highlights to bufnr if its name is in search_highlights.
---@param bufnr integer
local function apply_search_highlights(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  local entries = search_highlights[name]
  if not entries then return end
  for _, e in ipairs(entries) do
    -- lnum/col are 1-based from the agent; nvim_buf_set_extmark expects 0-based.
    vim.api.nvim_buf_set_extmark(bufnr, search_ns, e.lnum - 1, e.col - 1, {
      end_row = e.lnum - 1 + e.len - 1,
      hl_group = 'Search',
      hl_eol = true,
      priority = 100,
    })
  end
  log:debug('applied %d search highlight(s) to %s', #entries, name)
end

---Clears all search highlights from every loaded buffer and resets the table.
function M.clear_search_highlights()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then vim.api.nvim_buf_clear_namespace(bufnr, search_ns, 0, -1) end
  end
  search_highlights = {}
  log:info 'search highlights cleared'
end

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
<MustObey>
NEVER alter any files other than a TEMP_FILE.
NEVER provide the requested changes as conversational output. Return only the code.
Read TEMP_FILE before writing, it will be empty.
ONLY provide requested changes by writing the change to TEMP_FILE.
After writing TEMP_FILE once you MUST end the session.
</MustObey>
]]

local search_prompt = [[<Output>
/path/to/project/foo.js:24:8,3,Some notes here about some stuff, it can contain commas.
/path/to/project/foo.js:71:12,7,More notes go here, about why this part is important!
/path/to/project/bar.js:13:2,1,Even more notes, this time specfically about bar and why bar is so important.
/path/to/project/baz.js:1:1,52,Notes about why baz is very important to the results.

Here is the answer and explanation for the user, together with any additional
notes and remarks. Keep the notes that are also added above here. Provide a longer,
more detailed explanation here.
</Output>
<MustObey>
NEVER alter any files other than a TEMP_FILE.
ALWAYS write locations first with short comments to TEMP_FILE.
NEVER provide the answer or locations as conversational output.
ALWAYS follow the locations format.
PROVIDE the answer and explanation to the user after the list of locations.
In case you're not sure about some location, include it and mention it in the notes.

Each location line is in format: <location>:<line>:<col>,<len>,<notes>
Where each line contains just one location, file paths are always absolute. After locations provide two empty lines and write your notes.
location - absolute file path
line - starting line number, 1 based
col - starting column number, 1 based
len - how many lines should be highlited
notes - interesting notes about this location, it can be empty but the comma must be there. Notes can contain any characters including commas, but they cannot contain newlines.

See <Output> for example of locations file.
</MustObey>
<TEMP_FILE>{{temp_file}}</TEMP_FILE>
<TaskDescription>
You're given a task to find interesting locations throughtout the codebase, 
follow provided prompt for what locations are of interest to the user. 
Provide output in the given format alongside the explanation. Your job is to aid
user in what he want to achieve.
</TaskDescription>
<Prompt>{{prompt}}</Prompt>
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
function M.visual_replace()
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
    local agent = agents_mod.Agent.new(num, run_id, 'code', state.provider, PromptProvider.new(visual_replace_prompt))

    table.insert(state.agents, agent)
    log:info('agent #%d created (id=%s), log=%s', num, agent.id, agent:log_file())

    state.spinner_manager:agent_start(agent)

    agent:run(user_prompt, context, function(status, content)
      state.spinner_manager:agent_done(agent)
      log:info('agent #%d finished with status=%s', num, status)

      local cur_start, cur_end = util.pop_selection_marks(bufnr, ns, mark_start, mark_end)
      log:info('extmarks resolved: start=%d end=%d (original %d-%d)', cur_start, cur_end, start_line, end_line)

      if status ~= 'done' then return end

      local lines = vim.split(content, '\n', { plain = true })

      vim.api.nvim_buf_set_lines(bufnr, cur_start - 1, cur_end, false, lines)
      log:info('agent #%d: replaced lines %d-%d (%d lines written)', num, cur_start, cur_end, #lines)
    end)
  end

  local function on_prompt_cancel(_) log:info 'prompt cancelled' end

  popup.input('AI Prompt', on_prompt_submit, on_prompt_cancel)
end

---Asks for a prompt, runs the search agent, populates the quickfix list with
---the locations found, and opens a readonly scratch buffer in a horizontal
---split containing the agent's notes.
function M.search()
  local function on_prompt_submit(user_prompt)
    log:info('search: prompt captured (length=%d), spawning agent', #user_prompt)

    M.clear_search_highlights()

    local run_id = util.random_string(8)

    ---@type AgentContext
    local context = {
      filename = '',
      temp_dir = state.temp_dir,
      temp_file = '',
      model = state.model,
      selection = '',
      buffer = '',
      range = nil,
      user_prompt = user_prompt,
    }

    local num = #state.agents + 1
    local agent = agents_mod.Agent.new(num, run_id, 'search', state.provider, PromptProvider.new(search_prompt))

    table.insert(state.agents, agent)
    log:info('search agent #%d created (id=%s)', num, agent.id)

    state.spinner_manager:agent_start(agent)

    agent:run(user_prompt, context, function(status, content)
      state.spinner_manager:agent_done(agent)
      log:info('search agent #%d finished with status=%s', num, status)

      if status ~= 'done' then return end

      local parsed = util.parse_locations_file(content)
      local notes_lines = parsed.notes_lines
      local qf_items = {}

      for _, loc in ipairs(parsed.locations) do
        table.insert(qf_items, {
          filename = loc.filename,
          lnum = loc.lnum,
          col = loc.col,
          text = loc.notes,
        })
        if not search_highlights[loc.filename] then search_highlights[loc.filename] = {} end
        table.insert(search_highlights[loc.filename], { lnum = loc.lnum, col = loc.col, len = loc.len })
      end

      if #notes_lines > 0 then
        local notes_buf = vim.api.nvim_create_buf(false, true)
        vim.bo[notes_buf].buftype = 'nofile'
        vim.bo[notes_buf].bufhidden = 'wipe'
        vim.api.nvim_buf_set_lines(notes_buf, 0, -1, false, notes_lines)
        vim.bo[notes_buf].modifiable = true

        vim.cmd 'split'
        vim.api.nvim_win_set_buf(0, notes_buf)

        log:info('search agent #%d: opened notes buffer with %d lines', num, #notes_lines)
      end

      if #qf_items == 0 then
        log:warn('search agent #%d: no parseable locations found', num)
        vim.notify('light-ai: search returned no locations', vim.log.levels.WARN)
      else
        vim.fn.setqflist({}, ' ', { title = 'AI Search: ' .. user_prompt, items = qf_items })
        log:info('search agent #%d: populated quickfix with %d items', num, #qf_items)

        -- Apply highlights to any matching buffers already open.
        for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_is_loaded(bufnr) then apply_search_highlights(bufnr) end
        end

        vim.cmd 'Trouble quickfix open'
      end
    end)
  end

  local function on_prompt_cancel(_) log:info 'search: prompt cancelled' end

  popup.input('AI Search', on_prompt_submit, on_prompt_cancel)
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

  -- Highlight search result ranges whenever a file buffer is displayed.
  vim.api.nvim_create_augroup('LightAiSearch', { clear = true })
  vim.api.nvim_create_autocmd('BufWinEnter', {
    group = 'LightAiSearch',
    callback = function(ev) apply_search_highlights(ev.buf) end,
  })
end

return M
