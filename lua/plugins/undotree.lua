return {
  'jiaoshijie/undotree',
  opts = {
    -- these are some default keymaps inside the undotree
    -- keymaps = {
    -- ["j"] = "move_next",
    -- ["k"] = "move_prev",
    -- ["gj"] = "move2parent",
    -- ["J"] = "move_change_next",
    -- ["K"] = "move_change_prev",
    -- ["<cr>"] = "action_enter",
    -- ["p"] = "enter_diffbuf", -- this can switch between preview and undotree window
    -- ["q"] = "quit",
    -- ["S"] = "update_undotree_view",
    -- },
  },
  keys = { -- load the plugin only when using it's keybinding:
    { '<leader>u', "<cmd>lua require('undotree').toggle()<cr>" },
  },
}
