local selected_theme = 'alabaster'

---@param name string
local function isSelected(name) return name == selected_theme end

-- (default: false). When true, floating window borders have a foreground colour and background colour is the same as Normal. When false, floating window borders have no foreground colour and background colour is the same as popup menus.
vim.g.alabaster_floatborder = true

local function overwrite(spec, path, url)
  local s = {}

  local fs = vim.uv.fs_stat(path)
  if fs and fs.type == 'directory' then
    s.dir = path
  else
    s.url = url
  end

  return vim.tbl_deep_extend('force', s, spec)
end

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
  overwrite({
    '~p00f/alabaster.nvim',
    name = 'alabaster',
    enabled = not local_alabaster,
    config = function()
      vim.cmd [[set termguicolors]]
      vim.cmd [[colorscheme alabaster]]
    end,
  }, '~/alabaster.nvim', 'https://git.sr.ht/~p00f/alabaster.nvim'),
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
