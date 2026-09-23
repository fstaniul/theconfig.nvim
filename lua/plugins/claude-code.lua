return {
  'greggh/claude-code.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim', -- Required for git operations
  },
  config = function()
    local claude_code = require 'claude-code'

    claude_code.setup {
      window = {
        position = 'botright vsplit', -- Pin to the right as a vertical split
        split_ratio = 0.4, -- Take up 40% of the screen width
      },
    }

    local function send_to_claude(content)
      local instance_id = claude_code.claude_code.current_instance
      local bufnr = instance_id and claude_code.claude_code.instances[instance_id]
      local visible = bufnr and vim.api.nvim_buf_is_valid(bufnr) and #vim.fn.win_findbuf(bufnr) > 0

      if not visible then
        claude_code.toggle()
        instance_id = claude_code.claude_code.current_instance
        bufnr = instance_id and claude_code.claude_code.instances[instance_id]
      end

      if not (bufnr and vim.api.nvim_buf_is_valid(bufnr)) then return end

      local job_id = vim.b[bufnr].terminal_job_id
      if not job_id then return end

      -- Wrap in bracketed paste so the embedded newline lands as a literal
      -- newline in the prompt instead of submitting the message early.
      local payload = '\27[200~' .. content .. '\27[201~'
      vim.api.nvim_chan_send(job_id, payload)

      local win_id = vim.fn.win_findbuf(bufnr)[1]
      if win_id then
        vim.api.nvim_set_current_win(win_id)
        vim.cmd 'startinsert!'
      end
    end

    local function file_ref()
      local file = vim.fn.expand '%:.'
      return string.format('%s:%d:\n', file, vim.fn.line '.')
    end

    local function file_range_ref()
      local file = vim.fn.expand '%:.'
      local start_line = vim.fn.line 'v'
      local end_line = vim.fn.line '.'
      if start_line > end_line then
        start_line, end_line = end_line, start_line
      end
      if start_line == end_line then return string.format('%s:%d:\n', file, start_line) end
      return string.format('%s:%d-%d:\n', file, start_line, end_line)
    end

    vim.keymap.set('n', '<C-a>', function() send_to_claude(file_ref()) end, { desc = 'Send file:line reference to Claude Code' })

    vim.keymap.set('v', '<C-a>', function()
      local ref = file_range_ref()
      vim.cmd 'normal! \27' -- leave visual mode before switching windows
      send_to_claude(ref)
    end, { desc = 'Send file:line-range reference to Claude Code' })
  end,
}
