return {
  "stevearc/conform.nvim",
  config = function()
    local google_java_format = "C:/tools/google-java-format/google-java-format-1.17.0-all-deps.jar"
    local function find_prettier_entry(ctx)
      local prettier_files = vim.fs.find("node_modules/prettier/bin/prettier.cjs", {
        upward = true,
        path = ctx.dirname,
        limit = 1,
      })

      if #prettier_files > 0 then
        return prettier_files[1]
      end

      prettier_files = vim.fs.find("node_modules/prettier/bin/prettier.js", {
        upward = true,
        path = ctx.dirname,
        limit = 1,
      })

      return prettier_files[1]
    end

    local web_filetypes = {
      javascript = true,
      javascriptreact = true,
      typescript = true,
      typescriptreact = true,
      html = true,
      css = true,
      scss = true,
    }

    require("conform").setup({
      format_on_save = function(bufnr)
        local ft = vim.bo[bufnr].filetype

        if web_filetypes[ft] then
          return {
            timeout_ms = 3000,
            lsp_fallback = true,
          }
        end
      end,

      formatters_by_ft = {
        java = { "google-java-format" },
        javascript = { "prettierd", "prettier", stop_after_first = true },
        javascriptreact = { "prettierd", "prettier", stop_after_first = true },
        typescript = { "prettierd", "prettier", stop_after_first = true },
        typescriptreact = { "prettierd", "prettier", stop_after_first = true },
        html = { "prettierd", "prettier", stop_after_first = true },
        css = { "prettierd", "prettier", stop_after_first = true },
        scss = { "prettierd", "prettier", stop_after_first = true },
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
        prettier = {
          command = "node",
          args = function(self, ctx)
            local prettier = find_prettier_entry(ctx)
            if not prettier then
              return { "--version" }
            end

            return {
              prettier,
              "--stdin-filepath",
              "$FILENAME",
            }
          end,
          cwd = function(self, ctx)
            return vim.fs.root(ctx.dirname, {
              ".prettierrc",
              ".prettierrc.json",
              ".prettierrc.yml",
              ".prettierrc.yaml",
              ".prettierrc.json5",
              ".prettierrc.js",
              ".prettierrc.cjs",
              ".prettierrc.mjs",
              ".prettierrc.toml",
              "prettier.config.js",
              "prettier.config.cjs",
              "prettier.config.mjs",
              "package.json",
            })
          end,
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
