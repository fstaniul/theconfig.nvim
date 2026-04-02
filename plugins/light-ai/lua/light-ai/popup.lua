local Popup = require('nui.popup')
local event = require('nui.utils.autocmd').event

local M = {}

---Opens a large floating popup for multi-line prompt input.
---The buffer is a normal scratch buffer — all Neovim editing features work.
---
---Keymaps (normal mode):
---  <CR>  - submit: calls on_submit with the buffer contents, closes popup
---  <Esc> - abort:  closes popup, calls on_cancel with the current contents
---
---@param title string  Label shown on the top border.
---@param on_submit fun(value: string)  Called with the full buffer text on submit.
---@param on_cancel fun(value: string)  Called with the current buffer text on cancel.
---@param initial_content? string  Optional text pre-filled into the buffer.
function M.input(title, on_submit, on_cancel, initial_content)
  local popup = Popup({
    enter = true,
    focusable = true,
    relative = 'editor',
    position = '50%',
    size = {
      width = '70%',
      height = '40%',
    },
    border = {
      style = 'rounded',
      text = {
        top = ' ' .. title .. ' ',
        top_align = 'center',
        bottom = ' [<CR>] submit  [<Esc>] cancel ',
        bottom_align = 'center',
      },
    },
    buf_options = {
      modifiable = true,
      readonly = false,
      filetype = 'markdown', -- syntax highlighting for code blocks etc.
    },
    win_options = {
      winhighlight = 'Normal:Normal,FloatBorder:Normal',
      wrap = true,
      linebreak = true,
    },
  })

  popup:mount()

  -- pre-fill initial content if provided
  if initial_content and initial_content ~= '' then
    local lines = vim.split(initial_content, '\n', { plain = true })
    vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, lines)
  end

  -- start in insert mode so the user can type immediately
  vim.cmd('startinsert')

  local function get_content()
    local lines = vim.api.nvim_buf_get_lines(popup.bufnr, 0, -1, false)
    return vim.trim(table.concat(lines, '\n'))
  end

  local submitted = false

  local function submit()
    submitted = true
    local value = get_content()
    popup:unmount()
    if value ~= '' then
      on_submit(value)
    end
  end

  local function abort()
    if submitted then return end
    local value = get_content()
    popup:unmount()
    if on_cancel then
      on_cancel(value)
    end
  end

  popup:map('n', '<CR>', submit, { noremap = true })
  popup:map('n', '<Esc>', abort, { noremap = true })

  -- close if focus moves away
  popup:on(event.BufLeave, function()
    abort()
  end)
end

local SPINNER_FRAMES = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }
local SPINNER_INTERVAL_MS = 80

---@class SpinnerManager
---Manages a single bottom-right popup that lists one line per running agent.
---Call :agent_start(agent) when an agent begins and :agent_done(agent) when it ends.
---The popup and timer are created on the first running agent and destroyed when
---the last one finishes.
---@field _agents Agent[]   Reference to the shared agents table from state.
---@field _popup  table|nil nui.Popup handle while active.
---@field _timer  table|nil uv timer handle while active.
---@field _frame  integer   Current spinner frame index.
---@field _running boolean  Whether the timer/popup are currently live.
local SpinnerManager = {}
SpinnerManager.__index = SpinnerManager

---Creates a new SpinnerManager.
---@param agents Agent[]  The shared agents table (by reference).
---@return SpinnerManager
function SpinnerManager.new(agents)
  return setmetatable({
    _agents  = agents,
    _popup   = nil,
    _timer   = nil,
    _frame   = 1,
    _running = false,
  }, SpinnerManager)
end

---Returns the lines to display — one per running agent.
---@return string[]
function SpinnerManager:_lines()
  local frame_char = SPINNER_FRAMES[self._frame]
  local lines = {}
  for _, agent in ipairs(self._agents) do
    if agent.status == 'running' then
      table.insert(lines, frame_char .. ' agent #' .. agent.num .. ' ' .. agent.kind)
    end
  end
  return lines
end

---Starts the popup and timer. Called when the first agent becomes active.
function SpinnerManager:_start()
  local lines = self:_lines()
  local max_w = 0
  for _, l in ipairs(lines) do max_w = math.max(max_w, #l) end

  self._popup = require('nui.popup')({
    enter = false,
    focusable = false,
    relative = 'editor',
    position = { row = '98%', col = '99%' },
    size = { width = math.max(max_w, 20), height = math.max(#lines, 1) },
    border = { style = 'none' },
    buf_options = { modifiable = true, readonly = false },
    win_options = { winhighlight = 'Normal:Normal' },
  })
  self._popup:mount()

  self._timer = vim.uv.new_timer()
  self._running = true

  self._timer:start(0, SPINNER_INTERVAL_MS, function()
    vim.schedule(function()
      if not self._running then return end
      if not vim.api.nvim_buf_is_valid(self._popup.bufnr) then return end

      self._frame = (self._frame % #SPINNER_FRAMES) + 1
      local new_lines = self:_lines()

      -- resize height to match current running count
      local h = math.max(#new_lines, 1)
      local max_w2 = 20
      for _, l in ipairs(new_lines) do max_w2 = math.max(max_w2, #l) end
      self._popup:update_layout({ size = { width = max_w2, height = h } })

      vim.api.nvim_buf_set_lines(self._popup.bufnr, 0, -1, false, new_lines)
    end)
  end)
end

---Stops the timer and unmounts the popup.
function SpinnerManager:_stop()
  self._running = false
  if self._timer then
    self._timer:stop()
    self._timer:close()
    self._timer = nil
  end
  if self._popup then
    self._popup:unmount()
    self._popup = nil
  end
end

---Call this immediately after an agent is started.
---@param _agent Agent
function SpinnerManager:agent_start(_agent)
  if not self._running then
    self:_start()
  end
end

---Call this in the agent's on_done callback.
---@param _agent Agent
function SpinnerManager:agent_done(_agent)
  -- check if any agents are still running
  for _, agent in ipairs(self._agents) do
    if agent.status == 'running' then return end
  end
  self:_stop()
end

M.SpinnerManager = SpinnerManager

return M
