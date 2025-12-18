return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        qmlls = {}, -- важно: здесь ключ qmlls (название LSP в nvim-lspconfig)
      },
    },
  },

  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    opts = {
      ensure_installed = { "qmljs", "lua", "json" },
    },
  },
}
