return {
  "abecodes/tabout.nvim",
  event = "InsertEnter",
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
  },
  config = function()
    require("tabout").setup({
      tabkey = "",
      backwards_tabkey = "",
      act_as_tab = false,
      act_as_shift_tab = false,
      completion = false,
    })
  end,
}
