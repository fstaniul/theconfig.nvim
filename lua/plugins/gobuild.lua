return {
  dependencies = { 'folke/snacks.nvim' },
  name = 'gobuild',
  dir = '~/.config/nvim/plugins/gobuild',
  opts = {},
  keys = {
    { '<leader>bg', ':GoBuild<CR>', desc = '[B]uild [G]o' },
    { '<leader>bq', ':GoBuild quickfix<CR>', desc = 'Set [B]uild errors in [Q]uick fix list' },
  },
}
