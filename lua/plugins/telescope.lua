return {
  'nvim-telescope/telescope.nvim',
  tag = '0.1.8',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    local builtin = require('telescope.builtin')
    vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Telescope find files' })
    vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Telescope live grep' })
    vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Telescope buffers' })
    vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Telescope help tags' })
    vim.keymap.set('n', "<leader>fm", function()
      local module = vim.fn.input("Module: ")
      builtin.find_files({
        cwd = module,
      })
    end)
    vim.keymap.set("n", "<leader>o", function()
      builtin.lsp_document_symbols()
    end, { desc = "File Symbols" })
    vim.keymap.set("n", "<leader>fr", function()
      builtin.lsp_references()
    end, { desc = "Find References" })
  end
}
