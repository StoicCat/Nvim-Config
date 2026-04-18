return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
  },
  config = function()
    local layout = require("config.layout")
    local function open_in_main_area(path)
      local full_path = vim.fn.fnamemodify(path, ":p")

      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)

        if vim.bo[buf].filetype ~= "neo-tree" then
          local name = vim.api.nvim_buf_get_name(buf)

          if name ~= "" and vim.fn.fnamemodify(name, ":p") == full_path then
            vim.api.nvim_set_current_win(win)
            layout.fix_layout()
            return
          end
        end
      end

      layout.focus_main_window()
      vim.cmd("edit " .. vim.fn.fnameescape(full_path))
      layout.fix_layout()
    end

    require("neo-tree").setup({
      close_if_last_window = false,
      popup_border_style = "rounded",
      enable_git_status = true,
      enable_diagnostics = true,

      filesystem = {
        bind_to_cwd = false,
        filtered_items = {
          visible = false,
          hide_dotfiles = true,
          hide_gitignored = true,
          hide_by_name = {
            "node_modules",
            ".git",
            "target",
            "build"
          },
        },
        group_empty_dirs = false,
        follow_current_file = {
          enabled = true,
          leave_dirs_open = true,
        },
        hijack_netrw_behavior = "disabled",
        use_libuv_file_watcher = true,
        commands = {
          open = function(state)
            local node = state.tree:get_node()

            if node.type == "file" then
              open_in_main_area(node:get_id())
            else
              require("neo-tree.sources.filesystem.commands").open(state)
            end
          end,
        },
      },

      window = {
        position = "left",
        width = 30,

        mappings = {
          ["<cr>"] = "open",
          ["l"] = "open",
          ["h"] = "close_node",

          ["a"] = "add",
          ["d"] = "delete",
          ["r"] = "rename",
          ["c"] = "copy_to_clipboard",
          ["x"] = "cut_to_clipboard",
          ["p"] = "paste_from_clipboard",
          ["P"] = { "toggle_preview", config = { use_float = true } },

          ["R"] = "refresh",
        },
      },

      default_component_configs = {
        name = {
          truncation_character = "...",
        },
        indent = { padding = 1 },
        icon = {
          folder_closed = "",
          folder_open = "",
          folder_empty = "",
        },
        git_status = {
          symbols = {
            added     = "✚",
            modified  = "",
            deleted   = "✖",
            renamed   = "󰁕",
            untracked = "",
            ignored   = "",
            unstaged  = "󰄱",
            staged    = "",
            conflict  = "",
          },
        },
      },

      event_handlers = {
        -- ✅ FILE ADDED
        {
          event = "file_added",
          handler = function(file_path)
            vim.schedule(function()
              open_in_main_area(file_path)
            end)
          end,
        },

        -- ✅ FILE DELETED
        {
          event = "file_deleted",
          handler = function()
            vim.schedule(function()
              local has_real = false

              for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                if vim.api.nvim_buf_is_valid(buf) then
                  local name = vim.api.nvim_buf_get_name(buf)
                  local ft = vim.bo[buf].filetype
                  local bt = vim.bo[buf].buftype

                  if name ~= "" and ft ~= "alpha" and ft ~= "neo-tree" and bt == "" then
                    has_real = true
                    break
                  end
                end
              end

              if not has_real then
                layout.show_dashboard()
              end
            end)
          end,
        },
      },
    })
  end,
}
