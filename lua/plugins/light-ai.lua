return {
  name = 'fstaniul/light-ai.nvim',
  dir = '~/.config/nvim/plugins/light-ai',
  dependencies = {
    'MunifTanjim/nui.nvim',
    'nvim-lua/plenary.nvim',
  },
  config = function()
    local ai = require 'light-ai'
    ai.setup {
      temp_dir = './.tmp',
    }

    vim.keymap.set('v', '<leader>ai', function() ai.visual_replace() end, { desc = 'AI replace selection' })
    vim.keymap.set('n', '<leader>ai', function() ai.search() end, { desc = 'AI search codebase' })
    vim.keymap.set('n', '<leader>as', function() ai.pick_searches() end, { desc = 'AI pick [S]earch results' })

    vim.keymap.set('n', '<leader>ax', function() ai.abort_all() end, { desc = 'AI abort all runners' })

    vim.keymap.set('n', '<leader>aa', function() ai.preview_agents() end, { desc = 'AI [A]gents picker' })
    vim.keymap.set('n', '<leader>al', function() ai.pick_logs() end, { desc = 'AI agent [L]ogs picker' })
  end,
}
