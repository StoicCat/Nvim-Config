return {
  "nvim-treesitter/nvim-treesitter",
  tag = 'v0.10.0',
  lazy = false,
  build = ":TSUpdate",
  config = function()
    local configs = require("nvim-treesitter.configs").setup({
      ensure_installed = { "lua", "vim", "vimdoc", "query", "javascript", "typescript", "powershell", "java", "bash" },
      sync_install = false,
      auto_install = true,
      highlight = {
        enable = true,
      },
      autotage = true,
      indent = {
        enable = true,
      },
    })
  end
}
