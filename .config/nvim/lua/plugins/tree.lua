return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    filesystem = {
      filtered_items = {
        visible = true,
        show_hidden_count = true,
        hide_dotfiles = false, -- Set to false to show dotfiles
        hide_gitignored = true,
        never_show = {},
      },
    },
  },
}
