local conf = require('telescope.config').values
local themes = require('telescope.themes')
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local layout = require("config.layout")

local function restore_harpoon_cursor(item)
  local context = item and item.context or {}
  local row = context.row or 1
  local col = context.col or 0
  local line_count = vim.api.nvim_buf_line_count(0)

  if line_count < 1 then
    return
  end

  row = math.max(1, math.min(row, line_count))

  local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""
  col = math.max(0, math.min(col, #line))

  pcall(vim.api.nvim_win_set_cursor, 0, { row, col })
end

local function open_harpoon_item(item)
  if not item or not item.value then
    return
  end

  local absolute_path = vim.fn.fnamemodify(item.value, ":p")
  local current_buf = vim.api.nvim_get_current_buf()
  local current_name = vim.api.nvim_buf_get_name(current_buf)

  if current_name == absolute_path then
    restore_harpoon_cursor(item)
    return
  end

  layout.focus_main_window()

  local existing_buf = vim.fn.bufnr(absolute_path)
  if existing_buf ~= -1 then
    vim.api.nvim_set_current_buf(existing_buf)
  else
    vim.cmd.edit(vim.fn.fnameescape(absolute_path))
  end

  restore_harpoon_cursor(item)
end

local function toggle_telescope(harpoon_files)
  local file_paths = {}
  for _, item in ipairs(harpoon_files.items) do
    if item.value then
      table.insert(file_paths, item.value)
    end
  end
  local opts = themes.get_ivy({
    prompt_title = "Working List"
  })

  require("telescope.pickers").new(opts, {
    finder = require("telescope.finders").new_table({
      results = file_paths,
    }),
    previewer = conf.file_previewer(opts),
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)

        if selection then
          local path = selection.path or selection.filename or selection.value
          if path and path ~= "" then
            layout.focus_main_window()
            vim.cmd.edit(vim.fn.fnameescape(path))
          end
        end
      end)

      return true
    end,
  }):find()
end

local function open_harpoon_picker(harpoon_files)
  local entries = {}
  for index, item in ipairs(harpoon_files.items) do
    if item and item.value then
      table.insert(entries, {
        index = index,
        value = item.value,
        ordinal = item.value,
        display = string.format("%d %s", index, item.value),
      })
    end
  end

  local opts = themes.get_dropdown({
    prompt_title = "Harpoon",
    previewer = false,
  })

  require("telescope.pickers").new(opts, {
    finder = require("telescope.finders").new_table({
      results = entries,
      entry_maker = function(entry)
        return {
          value = entry,
          ordinal = entry.ordinal,
          display = entry.display,
          path = entry.value,
        }
      end,
    }),
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)

        if selection and selection.value and selection.value.index then
          layout.focus_main_window()
          open_harpoon_item(harpoon_files.items[selection.value.index])
        end
      end)

      return true
    end,
  }):find()
end

return {
  "ThePrimeagen/harpoon",
  branch = "harpoon2",
  dependencies = {
    "nvim-lua/plenary.nvim"
  },
  config = function()
    local harpoon = require('harpoon')
    local list = function()
      return harpoon:list()
    end
    local select_file = function(index)
      open_harpoon_item(list().items[index])
    end

    harpoon:setup()

    vim.keymap.set("n", "<leader>ha", function() list():add() end, { desc = "Harpoon add file" })
    vim.keymap.set("n", "<leader>hd", function() list():remove() end, { desc = "Harpoon remove file" })
    vim.keymap.set("n", "<leader>hc", function() list():clear() end, { desc = "Harpoon clear all" })
    vim.keymap.set("n", "<leader>hh", function() open_harpoon_picker(list()) end, { desc = "Harpoon menu" })
    vim.keymap.set("n", "<leader>fl", function() toggle_telescope(harpoon:list()) end,
      { desc = "Open harpoon window" })
    vim.keymap.set("n", "<leader>hp", function() list():prev() end, { desc = "Harpoon previous" })
    vim.keymap.set("n", "<leader>hn", function() list():next() end, { desc = "Harpoon next" })
    vim.keymap.set("n", "<leader>h1", function() select_file(1) end, { desc = "Harpoon file 1" })
    vim.keymap.set("n", "<leader>h2", function() select_file(2) end, { desc = "Harpoon file 2" })
    vim.keymap.set("n", "<leader>h3", function() select_file(3) end, { desc = "Harpoon file 3" })
    vim.keymap.set("n", "<leader>h4", function() select_file(4) end, { desc = "Harpoon file 4" })
    vim.keymap.set("n", "<C-p>", function() list():prev() end)
    vim.keymap.set("n", "<C-n>", function() list():next() end)
  end
}
