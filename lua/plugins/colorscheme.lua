local selected_theme = 'github-theme'

---@param name string
local function isSelected(name) return name == selected_theme end

---@module 'lazy'
---@type LazyConfig
return {
  {
    'rose-pine/neovim',
    lazy = false,
    priority = 1000,
    name = 'rose-pine',
    enabled = isSelected 'rose-pine',
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
    lazy = false, -- make sure we load this during startup if it is your main colorscheme
    priority = 1000, -- make sure to load this before all the other start plugins
    enabled = isSelected 'github-theme',
    config = function()
      require('github-theme').setup {}

      vim.cmd 'colorscheme github_dark'
    end,
  },
}
