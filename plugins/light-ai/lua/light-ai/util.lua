local M = {}

---Generates a random numeric string of the given length.
---@param length integer
---@return string
function M.random_string(length)
  local chars = '0123456789'
  local result = {}
  for _ = 1, length do
    result[#result + 1] = chars:sub(math.random(1, #chars), math.random(1, #chars))
  end
  return table.concat(result)
end

---Returns the current visual selection range (1-indexed, normalised so start <= end)
---and the bufnr. Must be called while still in visual mode.
---@return integer bufnr
---@return integer start_line
---@return integer start_col
---@return integer end_line
---@return integer end_col
function M.get_visual_selection()
  local start_pos = vim.fn.getpos 'v'
  local end_pos   = vim.fn.getpos '.'
  local sl, sc = start_pos[2], start_pos[3]
  local el, ec = end_pos[2],   end_pos[3]

  if sl > el or (sl == el and sc > ec) then
    sl, el = el, sl
    sc, ec = ec, sc
  end

  return vim.api.nvim_get_current_buf(), sl, sc, el, ec
end

---Exits visual mode, returning to normal mode.
function M.exit_visual()
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'x', false
  )
end

---Places two extmarks at the given (1-indexed) start/end positions in a
---freshly-created namespace whose name embeds the run_id, ensuring isolation
---between concurrent runs.
---@param bufnr integer
---@param run_id string
---@param start_line integer
---@param start_col integer
---@param end_line integer
---@param end_col integer
---@return integer ns        The namespace id (unique per run_id).
---@return integer mark_start
---@return integer mark_end
function M.set_selection_marks(bufnr, run_id, start_line, start_col, end_line, end_col)
  local ns = vim.api.nvim_create_namespace('light-ai-' .. run_id)
  local ms = vim.api.nvim_buf_set_extmark(bufnr, ns, start_line - 1, start_col - 1, {})
  local me = vim.api.nvim_buf_set_extmark(bufnr, ns, end_line - 1,   end_col - 1,   {})
  return ns, ms, me
end

---Reads back the (possibly shifted) positions of two extmarks and deletes them.
---Returns 1-indexed line numbers.
---@param bufnr integer
---@param ns integer
---@param mark_start integer
---@param mark_end integer
---@return integer cur_start_line
---@return integer cur_end_line
function M.pop_selection_marks(bufnr, ns, mark_start, mark_end)
  local ms = vim.api.nvim_buf_get_extmark_by_id(bufnr, ns, mark_start, {})
  local me = vim.api.nvim_buf_get_extmark_by_id(bufnr, ns, mark_end,   {})
  vim.api.nvim_buf_del_extmark(bufnr, ns, mark_start)
  vim.api.nvim_buf_del_extmark(bufnr, ns, mark_end)
  return ms[1] + 1, me[1] + 1  -- extmarks are 0-indexed
end

return M
