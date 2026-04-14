return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      require("catppuccin").setup({
        flavour = "macchiato",
        background = {
          light = "latte",
          dark = "mocha",
        },
        transparent_background = false,
        float = {
          transparent = true,
          solid = false,
        },
        term_colors = true,
      })

      vim.cmd.colorscheme("catppuccin")
    end,
  },
  {
    "nvim-lualine/lualine.nvim",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    opts = {
      theme = "catppuccin",
    },
  },
}
