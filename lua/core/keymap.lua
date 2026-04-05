-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

-- Remap j k to visual moves
vim.keymap.set({ 'n', 'v' }, 'j', 'gj')
vim.keymap.set({ 'n', 'v' }, 'k', 'gk')

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Stop capital J from joining the next line to the current one, which is the default behavior of J.
vim.keymap.set({ 'n', 'v' }, 'J', 'j')

-- Move between files on quickfix list
vim.keymap.set('n', '[q', ':cprev<CR>', { desc = 'Quickfix list prev' })
vim.keymap.set('n', ']q', ':cnext<CR>', { desc = 'Quickfix list next' })

-- Diagnostic Config & Keymaps
-- See :help vim.diagnostic.Opts
vim.diagnostic.config {
  update_in_insert = false,
  severity_sort = true,
  float = { border = 'rounded', source = 'if_many' },
  underline = { severity = { min = vim.diagnostic.severity.WARN } },

  -- Can switch between these as you prefer
  virtual_text = true, -- Text shows up at the end of the line
  virtual_lines = false, -- Text shows up underneath the line, with virtual lines

  -- Auto open the float, so you can easily read the errors when jumping with `[d` and `]d`
  jump = { float = true },
}

vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
--
--  See `:help wincmd` for a list of all window commands
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- NOTE: Some terminals have colliding key maps or are not able to send distinct key codes
vim.keymap.set('n', '<C-S-h>', '<C-w>H', { desc = 'Move window to the left' })
vim.keymap.set('n', '<C-S-l>', '<C-w>L', { desc = 'Move window to the right' })
vim.keymap.set('n', '<C-S-j>', '<C-w>J', { desc = 'Move window to the lower' })
vim.keymap.set('n', '<C-S-k>', '<C-w>K', { desc = 'Move window to the upper' })

-- Move up and down in visual mode with J and K
vim.keymap.set({ 'v' }, 'K', ":m'<-2<CR>gv=`>my`<mzgv`yo`z", { desc = 'Move lines one line up' })
vim.keymap.set({ 'v' }, 'J', ":m'>+<CR>gv=`<my`>mzgv`yo`z", { desc = 'Move lines one line down' })

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'lua',
  callback = function() vim.keymap.set({ 'n' }, '<leader>X', ':source %<CR>', { desc = 'Source current buffer', buffer = true, silent = true }) end,
})

vim.keymap.set('n', '<leader>yf', function()
  local path = vim.fn.expand '%'
  vim.fn.setreg('+', path)
  vim.notify('Yanked relative path: ' .. path)
end, { desc = '[Y]ank relative [F]ile path' })

vim.keymap.set('n', '<leader>yF', function()
  local path = vim.fn.expand '%:p'
  vim.fn.setreg('+', path)
  vim.notify('Yanked absolute path: ' .. path)
end, { desc = '[Yank] absolute [F]ile path' })

vim.keymap.set('x', '<leader>p', '"_dp', { desc = 'Paste without cutting', silent = true })
vim.keymap.set('x', '<leader>d', '"_d', { desc = 'Delete without cutting', silent = true })
vim.keymap.set('n', '<leader>D', '"_D', { desc = 'Delete till EOL without cutting', silent = true })
vim.keymap.set('n', '<leader>dd', '"_dd', { desc = 'Delete line without cutting', silent = true })

-- Yank into 0 and 1 registers (so that we can keep history)
local mirror_reg_01 = function() vim.fn.setreg('1', vim.fn.getreg '0') end
vim.api.nvim_create_autocmd('TextYankPost', {
  pattern = '*',
  callback = mirror_reg_01,
})
vim.api.nvim_create_user_command('MReg01', mirror_reg_01, { desc = 'Mirror contents of a register 0 to 1' })

-- vim: ts=2 sts=2 sw=2 et
