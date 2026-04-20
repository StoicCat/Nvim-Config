return {
  -- Mason for installing lsp's
  {
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup()
    end,
  },
  {
    "williamboman/mason.lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim" },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = { "lua_ls", "jdtls", "angularls", "html", "cssls", "eslint" },
        automatic_enable = false,
      })
    end,
  },
  -- CMP for list of suggestions
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
      "rafamadriz/friendly-snippets",
      "onsails/lspkind.nvim",
    },
    config = function()
      local cmp = require("cmp")
      local lspkind = require("lspkind")
      local luasnip = require("luasnip")
      local termcodes = vim.api.nvim_replace_termcodes

      local function has_closing_char_ahead()
        local line = vim.api.nvim_get_current_line()
        local col = vim.fn.col(".")
        local next_char = line:sub(col, col)
        return next_char:match("[%)%]%}%>\"'%`]")
      end

      require("luasnip.loaders.from_vscode").lazy_load()

      -- Reuse HTML/CSS snippets in Angular templates and component styles.
      luasnip.filetype_extend("htmlangular", { "html" })
      luasnip.filetype_extend("scss", { "css" })

      cmp.setup({
        formatting = {
          format = lspkind.cmp_format({
            mode = "symbol_text",
            maxwidth = 50,
            ellipsis_char = "...",
          }),
        },
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"] = cmp.mapping(function(fallback)
            if cmp.visible() and cmp.get_selected_entry() then
              cmp.confirm({ select = false })
            else
              fallback()
            end
          end),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            elseif has_closing_char_ahead() and vim.fn.maparg("<Plug>(TaboutMulti)", "i") ~= "" then
              vim.api.nvim_feedkeys(termcodes("<Plug>(TaboutMulti)", true, true, true), "", true)
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            elseif has_closing_char_ahead() and vim.fn.maparg("<Plug>(TaboutBackMulti)", "i") ~= "" then
              vim.api.nvim_feedkeys(termcodes("<Plug>(TaboutBackMulti)", true, true, true), "", true)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = {
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "buffer" },
          { name = "path" },
        },
      })

      local cmp_autopairs = require("nvim-autopairs.completion.cmp")
      cmp.event:on(
        "confirm_done",
        cmp_autopairs.on_confirm_done()
      )
    end,
  },
  -- LSP Config
  -- LSP
  {
    "neovim/nvim-lspconfig",
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      local fs = vim.fs
      local uv = vim.uv
      local fn = vim.fn

      local function resolve_ngserver_path(cmd_path)
        if not cmd_path or cmd_path == "" or not cmd_path:lower():match("ngserver%.cmd$") then
          return cmd_path
        end

        local ok, content = pcall(fn.readblob, cmd_path)
        if not ok or not content then
          return cmd_path
        end

        local target = content:match('%s%"%%dp0%%\\([^\r\n]-ngserver[^\r\n]-)%"')
        if not target then
          return cmd_path
        end

        local full = fs.normalize(fs.joinpath(fs.dirname(cmd_path), target))
        return resolve_ngserver_path(full)
      end

      local function collect_angular_node_modules(root_dir)
        local results = {}
        local seen = {}

        local function add(path)
          if path and not seen[path] and uv.fs_stat(path) then
            seen[path] = true
            table.insert(results, path)
          end
        end

        add(fs.joinpath(root_dir, "node_modules"))

        local ngserver_exe = fn.exepath("ngserver")
        if ngserver_exe and ngserver_exe ~= "" then
          local realpath = uv.fs_realpath(ngserver_exe) or ngserver_exe
          local ngserver_path = resolve_ngserver_path(realpath)
          add(fs.normalize(fs.joinpath(fs.dirname(ngserver_path), "../../..")))
        end

        return results
      end

      local function get_angular_core_version(root_dir)
        local package_json = fs.joinpath(root_dir, "package.json")
        if not uv.fs_stat(package_json) then
          return ""
        end

        local ok, content = pcall(fn.readblob, package_json)
        if not ok or not content then
          return ""
        end

        local json = vim.json.decode(content) or {}
        local version = (json.dependencies or {})["@angular/core"] or (json.devDependencies or {})["@angular/core"] or ""
        return version:match("%d+%.%d+%.%d+") or ""
      end

      ------------------------------------------------------------------
      -- Diagnostics
      ------------------------------------------------------------------
      vim.diagnostic.config({
        virtual_text = true,
        signs = true,
        underline = true,
        update_in_insert = false,
        severity_sort = true,
      })

      ------------------------------------------------------------------
      -- LUA
      ------------------------------------------------------------------
      vim.lsp.config("lua_ls", {
        capabilities = capabilities,
        settings = {
          Lua = {
            runtime = { version = "LuaJIT" },
            diagnostics = { globals = { "vim", "require" } },
            workspace = {
              library = {
                vim.env.VIMRUNTIME,
              },
              checkThirdParty = false,
            },
            telemetry = { enable = false },
          },
        },
      })

      ------------------------------------------------------------------
      -- TYPESCRIPT (NEW: ts_ls)
      ------------------------------------------------------------------
      vim.lsp.config("ts_ls", {
        capabilities = capabilities,
        on_attach = function(client)
          client.server_capabilities.documentFormattingProvider = false
        end,
      })

      ------------------------------------------------------------------
      -- ANGULAR (FIXED)
      ------------------------------------------------------------------
      vim.lsp.config("angularls", {
        capabilities = capabilities,
        cmd = function(dispatchers, config)
          local root_dir = (config and config.root_dir) or fn.getcwd()
          local node_paths = collect_angular_node_modules(root_dir)
          local ts_probe = table.concat(node_paths, ",")
          local ng_probe = table.concat(vim.iter(node_paths):map(function(path)
            return fs.joinpath(path, "@angular/language-server/node_modules")
          end):totable(), ",")

          local ngserver_exe = fn.exepath("ngserver")
          local ngserver_path = resolve_ngserver_path(uv.fs_realpath(ngserver_exe) or ngserver_exe)

          local cmd = {
            "node",
            "--max-old-space-size=4096",
            ngserver_path,
            "--stdio",
            "--tsProbeLocations",
            ts_probe,
            "--ngProbeLocations",
            ng_probe,
            "--angularCoreVersion",
            get_angular_core_version(root_dir),
          }

          return vim.lsp.rpc.start(cmd, dispatchers)
        end,
      })

      ------------------------------------------------------------------
      -- HTML / CSS / ESLINT
      ------------------------------------------------------------------
      vim.lsp.config("html", {
        capabilities = capabilities,
        filetypes = { "html" },
        root_dir = function(bufnr, on_dir)
          local angular_root = vim.fs.root(bufnr, { "angular.json", "nx.json" })
          if angular_root then
            return
          end

          local root = vim.fs.root(bufnr, { "package.json", ".git" })
          if root then
            on_dir(root)
          end
        end,
      })

      vim.lsp.config("cssls", {
        capabilities = capabilities,
      })

      vim.lsp.config("eslint", {
        capabilities = capabilities,
      })

      ------------------------------------------------------------------
      -- ENABLE (since you're using config API)
      ------------------------------------------------------------------
      vim.keymap.set("n", "<leader>rn", function()
        local ft = vim.bo.filetype

        if ft == "java" then
          local ok, api = pcall(require, "plugins.jdtls")
          if ok and api.rename then
            api.rename()
            return
          end
        end

        if ft == "typescript" or ft == "typescriptreact" or ft == "javascript" or ft == "javascriptreact" then
          vim.lsp.buf.rename(nil, { name = "ts_ls" })
          return
        end

        vim.lsp.buf.rename()
      end, { desc = "LSP Rename Symbol" })

      vim.lsp.enable("lua_ls", { force = true })
      vim.lsp.enable("ts_ls")
      vim.lsp.enable("angularls")
      vim.lsp.enable("html")
      vim.lsp.enable("cssls")
      vim.lsp.enable("eslint")
    end,
  },
}
