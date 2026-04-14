return {
  'nvim-telescope/telescope.nvim',
  tag = '0.1.8',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    local builtin = require('telescope.builtin')
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local layout = require("config.layout")

    local function open_file_from_picker(prompt_bufnr)
      local selection = action_state.get_selected_entry()
      actions.close(prompt_bufnr)

      if not selection then
        return
      end

      local path = selection.path or selection.filename or selection.value
      if not path or path == "" then
        return
      end

      layout.focus_main_window()
      vim.cmd.edit(vim.fn.fnameescape(path))
    end

    local function find_files_in_editor(opts)
      opts = opts or {}

      builtin.find_files(vim.tbl_extend("force", opts, {
        attach_mappings = function(_, _)
          actions.select_default:replace(open_file_from_picker)
          return true
        end,
      }))
    end

    vim.keymap.set('n', '<leader>ff', find_files_in_editor, { desc = 'Telescope find files' })
    vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Telescope live grep' })
    vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Telescope buffers' })
    vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Telescope help tags' })
    vim.keymap.set('n', "<leader>fm", function()
      local module = vim.fn.input("Module: ")
      find_files_in_editor({
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
