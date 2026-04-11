---@module 'lazy'
---@type LazyConfig
return {
  {
    'folke/snacks.nvim',
    priority = 1000,
    lazy = false,
    ---@module 'snacks'
    ---@type Config
    ---@diagnostic disable-next-line: missing-fields
    opts = {
      -- your configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
      -- bigfile = { enabled = true },
      dashboard = {
        enabled = true,
        formats = {
          key = function(item) return { { '[', hl = 'special' }, { item.key, hl = 'key' }, { ']', hl = 'special' } } end,
        },
        preset = {
          -- Used by the `keys` section to show keymaps.
          -- Set your custom keymaps here.
          -- When using a function, the `items` argument are the default keymaps.
          ---@type snacks.dashboard.Item[]
          keys = {
            { icon = ' ', key = 'f', desc = 'Find File', action = ":lua Snacks.dashboard.pick('files')" },
            { icon = ' ', key = 'n', desc = 'New File', action = ':ene | startinsert' },
            { icon = ' ', key = 'g', desc = 'Find Text', action = ":lua Snacks.dashboard.pick('live_grep')" },
            { icon = ' ', key = 'r', desc = 'Recent Files', action = ":lua Snacks.dashboard.pick('oldfiles')" },
            { icon = ' ', key = 'c', desc = 'Config', action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
            { icon = ' ', key = 's', desc = 'Restore Session', section = 'session' },
            { icon = '󰒲 ', key = 'L', desc = 'Lazy', action = ':Lazy', enabled = package.loaded.lazy ~= nil },
            { icon = ' ', key = 'M', desc = 'Mason', action = ':Mason' },
            { icon = ' ', key = 'q', desc = 'Quit', action = ':qa' },
          },
        },
        sections = {
          { section = 'header' },
          {
            pane = 2,
            section = 'terminal',
            cmd = vim.fn.executable 'colorscript' == 1 and 'colorscript -e fade' or 'echo "colorscript not installed"',
            height = 5,
            padding = 1,
          },
          {
            section = 'keys',
            gap = 1,
            padding = 2,
          },
          { pane = 2, icon = ' ', title = 'Recent Files', section = 'recent_files', indent = 2, padding = 1 },
          {
            pane = 2,
            icon = ' ',
            desc = 'Browse Repo',
            padding = 1,
            key = 'b',
            action = function() Snacks.gitbrowse() end,
          },
          function()
            local in_git = Snacks.git.get_root() ~= nil
            local cmds = {
              {
                icon = ' ',
                title = 'Review requests',
                cmd = [[gh search prs --review-requested=@me --state=open --json number,repository,title --template '{{range . }}{{tablerow (printf "#%v" .number | autocolor "green") .repository.name .title}}{{end}}{{tablerender}}']],
                key = 'P',
                action = function() vim.ui.open 'https://github.com/pulls/review-requested' end,
                height = 6,
              },
              {
                icon = ' ',
                title = 'Git Status',
                cmd = 'git --no-pager diff --stat -B -M -C',
                height = 10,
              },
            }
            return vim.tbl_map(
              function(cmd)
                return vim.tbl_extend('force', {
                  pane = 2,
                  section = 'terminal',
                  enabled = in_git,
                  padding = 1,
                  ttl = 5 * 60,
                  indent = 3,
                }, cmd)
              end,
              cmds
            )
          end,
          { section = 'startup', padding = 1 },
        },
      },
      -- explorer = { enabled = true },
      -- indent = { enabled = true },
      input = { enabled = true },
      -- picker = { enabled = true },
      -- notifier = { enabled = true },
      -- quickfile = { enabled = true },
      -- scope = { enabled = true },
      -- scroll = { enabled = true },
      statuscolumn = { enabled = true },
      -- words = { enabled = true },
    },
  },
}
