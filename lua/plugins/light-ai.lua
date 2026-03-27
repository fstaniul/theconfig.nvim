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
    vim.keymap.set('n', '<leader>aX', function() ai.abort_all() end, { desc = 'AI abort all runners' })
  end,
}
