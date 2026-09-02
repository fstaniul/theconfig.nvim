return {
  'fstaniul/easy-build.nvim',
  dir = '~/easy-build/',
  ---@module 'easy-build'
  ---@class EasyBuildOpts
  opts = {
    compilers = {
      go = {
        cmd = 'go build ./...',
        root_markers = { 'go.mod' },
      },
      ['go-lint'] = {
        cmd = 'golangci-lint run ./...',
        root_markers = { 'go.mod' },
      },
    },
  },
  keys = {
    { '<leader>bgb', function() require('easy-build').make 'go' end, desc = '[B]uild [G]o' },
    { '<leader>bgl', function() require('easy-build').make 'go-lint' end, desc = '[Build] [G]o [L]int' },
    { '<leader>B', function() require('easy-build').make() end, desc = '[B]uild current file' },
  },
}
