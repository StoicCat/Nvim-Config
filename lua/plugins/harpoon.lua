local conf = require('telescope.config').values
local themes = require('telescope.themes')
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

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
          harpoon_files:select(selection.value.index)
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

    harpoon:setup()

    vim.keymap.set("n", "<leader>ha", function() list():add() end, { desc = "Harpoon add file" })
    vim.keymap.set("n", "<leader>hd", function() list():remove() end, { desc = "Harpoon remove file" })
    vim.keymap.set("n", "<leader>hc", function() list():clear() end, { desc = "Harpoon clear all" })
    vim.keymap.set("n", "<leader>hh", function() open_harpoon_picker(list()) end, { desc = "Harpoon menu" })
    vim.keymap.set("n", "<leader>fl", function() toggle_telescope(harpoon:list()) end,
      { desc = "Open harpoon window" })
    vim.keymap.set("n", "<leader>hp", function() list():prev() end, { desc = "Harpoon previous" })
    vim.keymap.set("n", "<leader>hn", function() list():next() end, { desc = "Harpoon next" })
    vim.keymap.set("n", "<leader>h1", function() list():select(1) end, { desc = "Harpoon file 1" })
    vim.keymap.set("n", "<leader>h2", function() list():select(2) end, { desc = "Harpoon file 2" })
    vim.keymap.set("n", "<leader>h3", function() list():select(3) end, { desc = "Harpoon file 3" })
    vim.keymap.set("n", "<leader>h4", function() list():select(4) end, { desc = "Harpoon file 4" })
    vim.keymap.set("n", "<C-p>", function() list():prev() end)
    vim.keymap.set("n", "<C-n>", function() list():next() end)
  end
}
