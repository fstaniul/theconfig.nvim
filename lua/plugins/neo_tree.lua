-- Neo-tree is a Neovim plugin to browse the file system
-- https://github.com/nvim-neo-tree/neo-tree.nvim

---@module 'lazy'
---@type LazySpec
return {
  'nvim-neo-tree/neo-tree.nvim',
  version = '*',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-tree/nvim-web-devicons', -- not strictly required, but recommended
    'MunifTanjim/nui.nvim',
  },
  lazy = false,
  keys = {
    { '\\', ':Neotree reveal<CR>', desc = 'NeoTree reveal', silent = true },
  },
  ---@module 'neo-tree'
  ---@type neotree.Config
  opts = {
    filesystem = {
      window = {
        mappings = {
          ['\\'] = 'close_window',
        },
      },
      filtered_items = {
        visible = true,
        children_inherit_highlights = true,
        hide_dotfiles = false,
        hide_gitignored = false,
        -- remains hidden even if visible is toggled to true, this overrides always_show
        never_show = {
          '.DS_Store',
          'thumbs.db',
        },
      },
    },
  },
  {
    'nvim-neo-tree/neo-tree.nvim',
    ---@module 'neo-tree'
    ---@param opts neotree.Config
    opts = function(_, opts)
      -- snacks.rename integration with neo-tree
      local function on_move(data) Snacks.rename.on_rename_file(data.source, data.destination) end
      local events = require 'neo-tree.events'
      opts.event_handlers = opts.event_handlers or {}
      vim.list_extend(opts.event_handlers, {
        { event = events.FILE_MOVED, handler = on_move },
        { event = events.FILE_RENAMED, handler = on_move },
      })
    end,
  },
}
