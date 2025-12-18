-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
-- ~/.config/nvim/init.lua
require("lazy").setup("plugins")
require("lsp.qmlls")
require("lsp.hyprl")
