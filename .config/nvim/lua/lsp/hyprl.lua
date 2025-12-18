local lspconfig = require("lspconfig")
local configs = require("lspconfig.configs")

if not configs.hyprlang then
  configs.hyprlang = {
    default_config = {
      cmd = { "hyprls" },
      filetypes = { "hyprlang", "hypr", "conf" },
      root_dir = function(fname)
        return vim.fn.getcwd()
      end,
      settings = {
        hyprls = {},
      },
    },
  }
end

lspconfig.hyprlang.setup({
  settings = {
    hyprls = {
      preferIgnoreFile = false,
      ignore = { "hyprlock.conf", "hypridle.conf" },
    },
  },
})
