return {
  {
    'dlyongemallo/diffview-plus.nvim',
    version = '*',
    -- optional: lazy-load on command
    cmd = {
      'DiffviewOpen',
      'DiffviewToggle',
      'DiffviewFileHistory',
      'DiffviewDiffFiles',
      'DiffviewLog',
    },
    opts = {
      enhanced_diff_hl = true,
      diffopt = { algorithm = 'histogram' },
      merge_tool = {
        layout = 'diff3_mixed',
        disable_diagnostics = true,
        winbar_info = true,
      },
    },
  },
}
