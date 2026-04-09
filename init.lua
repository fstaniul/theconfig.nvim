require 'core.options'
pcall(require, 'core.options_local')

require 'core.keymap'
pcall(require, 'core.keymap_local')

require 'core.autocmd'
pcall(require, 'core.autocmd_local')

require 'core.lazy'

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
