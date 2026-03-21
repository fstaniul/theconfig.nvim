-- typescript support in nvim
-- See more info here: https://github.com/pmizio/typescript-tools.nvim
return {
  'pmizio/typescript-tools.nvim',
  dependencies = { 'nvim-lua/plenary.nvim', 'neovim/nvim-lspconfig' },
  opts = {
    settings = {
      tsserver_max_memory = 'auto',
      tsserver_locale = 'en',
      complete_function_calls = true,
      include_completions_with_insert_text = true,
      jsx_close_tag = {
        enable = true,
        filetypes = { 'javascriptreact', 'typescriptreact' },
      },
    },
  },
}
