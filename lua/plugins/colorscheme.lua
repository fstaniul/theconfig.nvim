local selected_theme = 'alabaster'

---@param name string
local function isSelected(name) return name == selected_theme end

-- (default: false). When true, floating window borders have a foreground colour and background colour is the same as Normal. When false, floating window borders have no foreground colour and background colour is the same as popup menus.
vim.g.alabaster_floatborder = true

---@type LazyPluginSpec[]
local themes = {
  {
    'rose-pine/neovim',
    name = 'rose-pine',
    config = function()
      require('rose-pine').setup {
        styles = {
          italic = false,
        },
      }
      vim.cmd 'colorscheme rose-pine'
    end,
  },
  {
    -- see: https://github.com/projekt0n/github-nvim-theme
    'projekt0n/github-nvim-theme',
    name = 'github-theme',
    config = function()
      require('github-theme').setup {}

      vim.cmd 'colorscheme github_dark'
    end,
  },
  {
    -- https://github.com/dchinmay2/alabaster.nvim
    'dchinmay2/alabaster.nvim',
    name = 'alabaster',
    config = function()
      vim.cmd [[set termguicolors]]
      vim.cmd [[colorscheme alabaster]]

      -- vim.api.nvim_set_hl(0, '@keyword.return', { fg = '#71ade7' })
    end,
  },
}

---@module 'lazy'
---@type LazyPluginSpec[]
local config = {}

for _, spec in ipairs(themes) do
  ---@type LazyPluginSpec[]
  local additional = {
    priority = 1000,
    lazy = false,
    enabled = isSelected(spec.name),
  }
  spec = vim.tbl_deep_extend('force', additional, spec)
  table.insert(config, spec)
end

return config
