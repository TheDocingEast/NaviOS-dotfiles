-- ~/.config/nvim/lua/lsp/qml.lua
local lspconfig = require("lspconfig")

lspconfig.qmlls.setup({
  cmd = { "qmlls6" }, -- используем бинарник, который есть на Arch
  filetypes = { "qml", "qtquick" },
  root_dir = lspconfig.util.root_pattern(".git", "."),
  on_attach = function(client, bufnr)
    print("QML LSP подключен!")
    -- можно добавить горячие клавиши LSP здесь
  end,
})
