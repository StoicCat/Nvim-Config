return {
  "stevearc/conform.nvim",
  config = function()
    local google_java_format = "C:/tools/google-java-format/google-java-format-1.17.0-all-deps.jar"
    local conform_util = require("conform.util")
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

    local function find_prettier_cwd(ctx)
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
    end

    local function run_prettier(self, ctx, input_lines, callback)
      local prettier = find_prettier_entry(ctx)
      if not prettier then
        callback("Prettier executable not found")
        return
      end

      local argv = {
        "node",
        prettier,
        "--stdin-filepath",
        ctx.filename,
      }

      if ctx.range then
        local start_offset, end_offset = conform_util.get_offsets_from_range(ctx.buf, ctx.range)
        vim.list_extend(argv, {
          "--range-start=" .. start_offset,
          "--range-end=" .. end_offset,
        })
      end

      local cwd = find_prettier_cwd(ctx)
      local buffer_text = table.concat(input_lines, "\n")

      vim.system(argv, {
        cwd = cwd,
        stdin = buffer_text,
        text = true,
      }, vim.schedule_wrap(function(result)
        if result.code ~= 0 then
          local err = result.stderr
          if not err or err == "" then
            err = result.stdout
          end
          callback(err ~= "" and err or "Prettier failed")
          return
        end

        local output = vim.split(result.stdout or "", "\r?\n")
        if output[#output] == "" then
          table.remove(output)
        end
        if #output == 0 then
          output = { "" }
        end

        callback(nil, output)
      end))
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
          range_args = function(self, ctx)
            return {
              "-jar",
              google_java_format,
              "--lines",
              string.format("%d:%d", ctx.range["start"][1], ctx.range["end"][1]),
              "-",
            }
          end,
          stdin = true,
        },
        prettier = {
          format = run_prettier,
          range_args = function()
            return {}
          end,
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

    vim.keymap.set("x", "<leader>f", function()
      local start_pos = vim.fn.getpos("v")
      local end_pos = vim.fn.getpos(".")
      local start_row = start_pos[2]
      local start_col = start_pos[3]
      local end_row = end_pos[2]
      local end_col = end_pos[3]

      if start_row == end_row and end_col < start_col then
        start_col, end_col = end_col, start_col
      elseif end_row < start_row then
        start_row, end_row = end_row, start_row
        start_col, end_col = end_col, start_col
      end

      require("conform").format({
        async = false,
        timeout_ms = 3000,
        lsp_fallback = false,
        range = {
          ["start"] = { start_row, start_col - 1 },
          ["end"] = { end_row, end_col - 1 },
        },
      })
    end, { desc = "Format Selection" })

    -- 📦 manual organize imports ONLY
    vim.keymap.set("n", "<leader>oi", function()
      vim.lsp.buf.code_action({
        context = { only = { "source.organizeImports" } },
        apply = true,
      })
    end, { desc = "Organize Imports" })
  end,
}
