return {
  {
    'dlyongemallo/diffview-plus.nvim',
    version = '*',
    opts = {
      enhanced_diff_hl = true,
      diffopt = { algorithm = 'histogram' },
      view = {
        default = {
          layout = 'diff2_horizontal',
        },
        merge_tool = {
          layout = 'diff3_mixed',
          disable_diagnostics = true,
          winbar_info = true,
        },
      },
    },
  },
}
