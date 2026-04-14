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
        root_dir = function(bufnr, on_dir)
          local fname = vim.api.nvim_buf_get_name(bufnr)
          local root = vim.fs.root(fname, "angular.json")
          if root then
            on_dir(root)
          end
        end,
      })

      ------------------------------------------------------------------
      -- HTML / CSS / ESLINT
      ------------------------------------------------------------------
      vim.lsp.config("html", {
        capabilities = capabilities,
        filetypes = { "html", "templ" },
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
      vim.lsp.enable("lua_ls", { force = true })
      vim.lsp.enable("ts_ls")
      vim.lsp.enable("angularls")
      vim.lsp.enable("html")
      vim.lsp.enable("cssls")
      vim.lsp.enable("eslint")
    end,
  },
}
