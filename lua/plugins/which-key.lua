return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  config = function()
    local wk = require("which-key")

    wk.setup({})

    wk.add({
      { "<leader>b", group = "Buffers" },
      { "<leader>c", group = "Code" },
      { "<leader>e", group = "Explorer" },
      { "<leader>f", group = "Files" },
      { "<leader>h", group = "Harpoon" },
      { "<leader>r", group = "Run" },
      { "<leader>y", group = "Yank" },
    })
  end,
}
