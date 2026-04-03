local popup = require 'light-ai.popup'
local Logger = require 'light-ai.logging'
local OpenCodeProvider = require 'light-ai.opencode'
local PromptProvider = require 'light-ai.prompt'
local agents_mod = require 'light-ai.agent'
local util = require 'light-ai.util'

local M = {}

-- ─── config ───────────────────────────────────────────────────────────────────

---@class LightAiConfig
---@field provider AgentProvider
---@field model string
---@field temp_dir string
---@diagnostic disable: assign-type-mismatch
local config = {
  provider = nil,
  model = nil,
  temp_dir = nil,
}
---@diagnostic enable: assign-type-mismatch

-- ─── state ────────────────────────────────────────────────────────────────────

---@class LightAiState
---@field agents Agent[]
---@field spinner_manager SpinnerManager
---@diagnostic disable: assign-type-mismatch
local state = {
  agents = {},
  spinner_manager = nil,
}
---@diagnostic enable: assign-type-mismatch

local log = Logger.new 'system'

-- ─── highlights ───────────────────────────────────────────────────────────────

-- Namespace for all AI extmarks.
local search_ns = vim.api.nvim_create_namespace 'light-ai-search'

-- Persistent table: absolute filepath → list of { lnum, col, len } (1-based).
---@type table<string, {lnum:integer, col:integer, len:integer}[]>
local highlights = {}

---Applies any pending highlights to bufnr if its name is in highlights.
---@param bufnr integer
local function apply_highlights(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  local entries = highlights[name]
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
  log:debug('applied %d highlight(s) to %s', #entries, name)
end

---Clears all AI highlights from every loaded buffer and resets the table.
function M.clear_highlights()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then vim.api.nvim_buf_clear_namespace(bufnr, search_ns, 0, -1) end
  end
  highlights = {}
  log:info 'highlights cleared'
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
After you write the changes perform a review of the written changes and see
if you need to change anything.
ONCE you're done say "Done." and end the session.
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

ONCE you're done with the answer and locations say "Done." and end the session.
</MustObey>
<TEMP_FILE>{{temp_file}}</TEMP_FILE>
<Context>
  <CurrentFilename>{{filename}}</CurrentFilename>
  <CursorLocation>{{range}}</CursorLocation>
  <CurrentFile>{{buffer}}</CurrentFile>
</Context>
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
  config.model = model
  log:info('model set to %s', model)
end

---Sets the active provider and resets the model to its default.
---@param provider AgentProvider
function M.set_provider(provider)
  config.provider = provider
  config.model = provider:get_default_model()
  log:info('provider set to %s, model reset to %s', provider:get_provider_name(), config.model)
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
      temp_dir = config.temp_dir,
      temp_file = '', -- filled in by Agent:run
      model = config.model,
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
    local agent = agents_mod.Agent.new(num, run_id, 'code', config.provider, PromptProvider.new(visual_replace_prompt))

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
      vim.notify(string.format('light-ai: agent #%d finished the job', num), vim.log.levels.INFO)

      -- Highlight the replaced region so it's easy to spot.
      local fname = vim.api.nvim_buf_get_name(bufnr)
      if not highlights[fname] then highlights[fname] = {} end
      table.insert(highlights[fname], { lnum = cur_start, col = 1, len = #lines })
      apply_highlights(bufnr)
    end)
  end

  local function on_prompt_cancel(_) log:info 'prompt cancelled' end

  popup.input('AI Prompt', on_prompt_submit, on_prompt_cancel)
end

---Parses a search agent's temp file content and applies results:
---populates quickfix, sets search highlights, opens a notes split.
---@param content string
---@param title string  Quickfix list title.
---@param agent_num integer  Used only for log messages.
local function apply_search_results(content, title, agent_num)
  M.clear_highlights()

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
    if not highlights[loc.filename] then highlights[loc.filename] = {} end
    table.insert(highlights[loc.filename], { lnum = loc.lnum, col = loc.col, len = loc.len })
  end

  if #notes_lines > 0 then
    local notes_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[notes_buf].buftype = 'nofile'
    vim.bo[notes_buf].bufhidden = 'wipe'
    vim.api.nvim_buf_set_lines(notes_buf, 0, -1, false, notes_lines)
    vim.bo[notes_buf].modifiable = true

    vim.cmd 'split'
    vim.api.nvim_win_set_buf(0, notes_buf)

    log:info('search agent #%d: opened notes buffer with %d lines', agent_num, #notes_lines)
  end

  if #qf_items == 0 then
    log:error('search agent #%d: no parseable locations found', agent_num)
    vim.notify('light-ai: search returned no locations', vim.log.levels.WARN)
  else
    vim.fn.setqflist({}, ' ', { title = title, items = qf_items })
    log:info('search agent #%d: populated quickfix with %d items', agent_num, #qf_items)

    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(bufnr) then apply_highlights(bufnr) end
    end

    vim.cmd 'Trouble quickfix open'
  end
end

---the locations found, and opens a readonly scratch buffer in a horizontal
---split containing the agent's notes.
function M.search()
  local bufnr = vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(bufnr)

  local cursor = vim.api.nvim_win_get_cursor(0)
  local cursor_line, cursor_col = cursor[1], cursor[0]

  local function on_prompt_submit(user_prompt)
    log:info('search: prompt captured (length=%d), spawning agent', #user_prompt)

    local run_id = util.random_string(8)

    local all_buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local buffer_content = table.concat(all_buf_lines, '\n')

    ---@type AgentContext
    local context = {
      filename = filename,
      temp_dir = config.temp_dir,
      temp_file = '',
      model = config.model,
      selection = '',
      buffer = buffer_content,
      range = {
        start_line = cursor_line,
        start_col = cursor_col,
        end_line = cursor_line,
        end_col = cursor_col,
      },
      user_prompt = user_prompt,
    }

    local num = #state.agents + 1
    local agent = agents_mod.Agent.new(num, run_id, 'search', config.provider, PromptProvider.new(search_prompt))

    table.insert(state.agents, agent)
    log:info('search agent #%d created (id=%s)', num, agent.id)

    state.spinner_manager:agent_start(agent)

    agent:run(user_prompt, context, function(status, content)
      state.spinner_manager:agent_done(agent)
      log:info('search agent #%d finished with status=%s', num, status)

      if status ~= 'done' then return end

      apply_search_results(content, 'AI Search: ' .. user_prompt, num)
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

---Opens a Telescope picker listing all agents that have been run this session.
---The preview window shows the contents of the agent's temp file output.
function M.preview_agents()
  local pickers = require 'telescope.pickers'
  local finders = require 'telescope.finders'
  local conf = require('telescope.config').values

  if #state.agents == 0 then
    vim.notify('light-ai: no agents have been run this session', vim.log.levels.INFO)
    return
  end

  pickers
    .new({}, {
      prompt_title = 'AI Agents',
      finder = finders.new_table {
        results = state.agents,
        entry_maker = function(agent)
          local prompt_preview = agent.user_prompt and agent.user_prompt:gsub('\n', ' ') or '(no prompt)'
          local display = string.format('#%d  %-6s  %-8s  %s', agent.num, agent.kind, agent.status, prompt_preview)
          return {
            value = agent,
            display = display,
            ordinal = display,
            filename = agent.temp_file,
            lnum = 1,
            col = 1,
          }
        end,
      },
      sorter = conf.generic_sorter {},
      previewer = conf.file_previewer {},
    })
    :find()
end

---Opens a Telescope picker listing all agents, previewing each agent's log file.
function M.pick_logs()
  local pickers = require 'telescope.pickers'
  local finders = require 'telescope.finders'
  local conf = require('telescope.config').values

  if #state.agents == 0 then
    vim.notify('light-ai: no agents have been run this session', vim.log.levels.INFO)
    return
  end

  pickers
    .new({}, {
      prompt_title = 'AI Agent Logs',
      finder = finders.new_table {
        results = state.agents,
        entry_maker = function(agent)
          local prompt_preview = agent.user_prompt and agent.user_prompt:gsub('\n', ' ') or '(no prompt)'
          local display = string.format('#%d  %-6s  %-8s  %s', agent.num, agent.kind, agent.status, prompt_preview)
          return {
            value = agent,
            display = display,
            ordinal = display,
            filename = agent:log_file(),
            lnum = 1,
            col = 1,
          }
        end,
      },
      sorter = conf.generic_sorter {},
      previewer = conf.file_previewer {},
    })
    :find()
end

---Re-applies the results of a past search agent by its index in state.agents (1-based).
---Errors if the agent does not exist, is not of kind "search", or is not done.
---You can pass a negative number to search from the end of the list, eg. (-1 for last agent).
---@param idx integer
function M.restore_search(idx)
  if idx < 0 then idx = #state.agents + idx + 1 end
  local agent = state.agents[idx]
  if not agent then
    vim.notify(string.format('light-ai: no #%d agent', idx), vim.log.levels.ERROR)
    return
  end
  if agent.kind ~= 'search' then
    vim.notify(string.format('light-ai: agent #%d is not a search agent', agent.num), vim.log.levels.ERROR)
    return
  end
  if agent.status ~= 'done' then
    vim.notify(string.format('light-ai: agent #%d is not done (status: %s)', agent.num, agent.status), vim.log.levels.ERROR)
    return
  end

  local content = util.read_file(agent.temp_file)
  if not content then
    vim.notify('light-ai: could not read temp file for search #' .. agent.num, vim.log.levels.ERROR)
    return
  end

  local title = 'AI Search: ' .. (agent.user_prompt or '(no prompt)')
  log:info('restore_search: restoring agent #%d (%s)', agent.num, title)
  apply_search_results(content, title, agent.num)
end

---Opens a Telescope picker listing all completed search agents.
---Selecting one restores its quickfix list, highlights, and notes.
function M.pick_searches()
  local pickers = require 'telescope.pickers'
  local finders = require 'telescope.finders'
  local conf = require('telescope.config').values
  local actions = require 'telescope.actions'
  local action_state = require 'telescope.actions.state'

  local searches = {}
  for _, agent in ipairs(state.agents) do
    if agent.kind == 'search' and agent.status == 'done' then table.insert(searches, agent) end
  end

  if #searches == 0 then
    vim.notify('light-ai: no completed search results this session', vim.log.levels.INFO)
    return
  end

  pickers
    .new({}, {
      prompt_title = 'AI Search Results',
      finder = finders.new_table {
        results = searches,
        entry_maker = function(agent)
          local prompt_preview = agent.user_prompt and agent.user_prompt:gsub('\n', ' ') or '(no prompt)'
          local display = string.format('#%d  %s', agent.num, prompt_preview)
          return {
            value = agent,
            display = display,
            ordinal = display,
            filename = agent.temp_file,
            lnum = 1,
            col = 1,
          }
        end,
      },
      sorter = conf.generic_sorter {},
      previewer = conf.file_previewer {},
      attach_mappings = function(prompt_bufnr, _)
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if not entry then return end
          local agent = entry.value
          local content = util.read_file(agent.temp_file)
          if not content then
            vim.notify('light-ai: could not read temp file for search #' .. agent.num, vim.log.levels.ERROR)
            return
          end
          local title = 'AI Search: ' .. (agent.user_prompt or '(no prompt)')
          log:info('pick_searches: restoring agent #%d', agent.num)
          apply_search_results(content, title, agent.num)
        end)
        return true
      end,
    })
    :find()
end

-- ─── setup ────────────────────────────────────────────────────────────────────
---@return LightAiConfig
function M.get_config() return { provider = config.provider, model = config.model, temp_dir = config.temp_dir } end

---@class LightAiOpts
---@field provider? AgentProvider  Defaults to OpenCodeProvider.
---@field model? string            Defaults to provider:get_default_model().
---@field temp_dir string          Directory for temporary files.
---
---@param opts? LightAiOpts
function M.setup(opts)
  opts = opts or {}

  assert(opts.temp_dir and opts.temp_dir ~= '', 'light-ai: opts.temp_dir is required')

  config.provider = opts.provider or OpenCodeProvider:new()
  config.model = opts.model or config.provider:get_default_model()
  config.temp_dir = opts.temp_dir
  state.spinner_manager = popup.SpinnerManager.new(state.agents)

  -- Apply highlights whenever a file buffer is displayed.
  vim.api.nvim_create_augroup('LightAiHighlights', { clear = true })
  vim.api.nvim_create_autocmd('BufWinEnter', {
    group = 'LightAiHighlights',
    callback = function(ev) apply_highlights(ev.buf) end,
  })
end

return M
