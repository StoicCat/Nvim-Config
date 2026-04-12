return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    cmd = "ToggleTerm",
    lazy = false,
    config = function()
      require("toggleterm").setup({
        direction = "horizontal",
        size = 15,
        shade_terminals = false,
        persist_size = true,
        close_on_exit = false,
      })

      vim.api.nvim_create_autocmd("TermOpen", {
        pattern = "term://*toggleterm#*",
        callback = function()
          vim.cmd("resize 15")
        end,
      })
    end,
  },
}
