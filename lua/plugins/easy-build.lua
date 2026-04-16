return {
  'fstaniul/easy-build.nvim',
  dir = '~/easy-build/',
  opts = {},
  keys = {
    { '<leader>bg', function() require('easy-build').make 'go' end, desc = '[B]uild [G]o' },
    { '<leader>B', function() require('easy-build').make() end, desc = '[B]uild current file' },
  },
}
