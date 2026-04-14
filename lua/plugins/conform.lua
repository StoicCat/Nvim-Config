return {
  "stevearc/conform.nvim",
  config = function()
    local google_java_format = "C:/tools/google-java-format/google-java-format-1.17.0-all-deps.jar"

    require("conform").setup({
      formatters_by_ft = {
        java = { "google-java-format" },
        -- lua = { "stylua" },
        -- javascript = { "prettier" },
      },

      formatters = {
        ["google-java-format"] = {
          command = "C:/Program Files/Eclipse Adoptium/jdk-17.0.18.8-hotspot/bin/java.exe",
          args = {
            "-jar",
            google_java_format,
            "-",
          },
          stdin = true,
        },
      },
    })

    -- 🧠 SAFE pipeline (no manual LSP looping)
    local function format_and_fix()
      local ft = vim.bo.filetype

      if ft == "java" then
        -- 1. organize imports (SAFE: only one action applied)
        vim.lsp.buf.code_action({
          context = { only = { "source.organizeImports" } },
          apply = true,
        })

        -- 2. wait briefly to avoid race condition
        vim.wait(100)

        -- 3. format
        require("conform").format({
          async = false,
          timeout_ms = 3000,
          lsp_fallback = false,
        })
      else
        require("conform").format({
          async = false,
          timeout_ms = 3000,
          lsp_fallback = true,
        })
      end
    end

    -- 🎮 manual format (same as save)
    vim.keymap.set("n", "<leader>f", function()
      format_and_fix()
    end, { desc = "Format + Fix Imports" })

    -- 📦 manual organize imports ONLY
    vim.keymap.set("n", "<leader>oi", function()
      vim.lsp.buf.code_action({
        context = { only = { "source.organizeImports" } },
        apply = true,
      })
    end, { desc = "Organize Imports" })
  end,
}
