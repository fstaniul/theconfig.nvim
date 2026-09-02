-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Trigger autoread automatically after coming back to vim
vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter' }, {
  pattern = '*',
  command = 'checktime',
})

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.hl.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('highlight-yank', { clear = true }),
  callback = function() vim.hl.on_yank() end,
})

-- Update settings for ts,tsx,js,jsx
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'javascript', 'typescript', 'javascriptreact', 'typescriptreact' },
  callback = function()
    vim.opt_local.expandtab = true -- Convert tabs to spaces
    vim.opt_local.shiftwidth = 4 -- Size of an indent
    vim.opt_local.tabstop = 4 -- Number of spaces tabs count for
    vim.opt_local.softtabstop = 4 -- Number of spaces tabs count for while editing
  end,
})

-- vim: ts=2 sts=2 sw=2 et
