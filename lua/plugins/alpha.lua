return {
  "goolord/alpha-nvim",
  config = function()
    local alpha = require("alpha")
    local dashboard = require("alpha.themes.dashboard")
    local layout = require("config.layout")

    alpha.setup(dashboard.config)

    vim.api.nvim_create_autocmd("VimEnter", {
      callback = function()
        if vim.fn.argc() == 1 and vim.fn.isdirectory(vim.fn.argv()[1]) == 1 then
          vim.schedule(function()
            layout.show_dashboard()

            require("neo-tree.command").execute({
              action = "show",
              position = "left",
            })

            layout.fix_layout()

            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
              local name = vim.api.nvim_buf_get_name(buf)
              if name ~= "" and vim.fn.isdirectory(name) == 1 then
                vim.api.nvim_buf_delete(buf, { force = true })
              end
            end
          end)
        end
      end,
    })
  end,
}
