return {
  {
    "nvim-lua/plenary.nvim",
    config = function()
      local function smart_insert(mode)
        local line = vim.api.nvim_get_current_line()
        if not line:match("^%s*$") then
          local keys = vim.api.nvim_replace_termcodes(mode, true, false, true)
          vim.api.nvim_feedkeys(keys, "n", false)
          return
        end

        local keys = vim.api.nvim_replace_termcodes("cc", true, false, true)
        vim.api.nvim_feedkeys(keys, "n", false)
      end

      vim.keymap.set("n", "i", function()
        smart_insert("i")
      end, { desc = "Insert with smart indent on blank lines" })

      vim.keymap.set("n", "a", function()
        smart_insert("a")
      end, { desc = "Append with smart indent on blank lines" })
    end,
  },
}
