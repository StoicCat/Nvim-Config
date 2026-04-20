local root_markers = {
  "pom.xml",
  "mvnw",
  "build.gradle",
  "build.gradle.kts",
  "gradlew",
  "gradlew.bat",
  "settings.gradle",
  "settings.gradle.kts",
}

local function normalize_start_path(path)
  local start = path

  if not start or start == "" then
    start = vim.fn.getcwd()
  end

  local stat = vim.uv.fs_stat(start)
  if stat and stat.type ~= "directory" then
    start = vim.fs.dirname(start)
  end

  return start
end

local function find_workspace_root(path)
  local start = normalize_start_path(path)

  local matches = vim.fs.find(root_markers, {
    upward = true,
    path = start,
    limit = math.huge,
    stop = vim.uv.os_homedir(),
  })

  if #matches == 0 then
    return nil
  end

  return vim.fs.dirname(matches[#matches])
end

local function find_plain_java_root(path)
  local start = normalize_start_path(path)

  local git_root = vim.fs.root(start, ".git")
  if git_root then
    return git_root
  end

  return start
end

local function is_java_project(path)
  return find_workspace_root(path) ~= nil
end

return {
  "mfussenegger/nvim-jdtls",
  name = "nvim-jdtls",

  init = function()
    local group = vim.api.nvim_create_augroup("SpringJavaJdtlsInit", { clear = true })

    vim.api.nvim_create_autocmd("VimEnter", {
      group = group,
      callback = function()
        if not is_java_project(vim.fn.getcwd()) then
          return
        end

        require("lazy").load({
          plugins = { "nvim-jdtls" },
          wait = true,
        })

        vim.schedule(function()
          local ok, api = pcall(require, "plugins.jdtls")
          if ok then
            api.start()
          end
        end)
      end,
    })

    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = "java",
      callback = function(args)
        require("lazy").load({
          plugins = { "nvim-jdtls" },
          wait = true,
        })

        vim.schedule(function()
          local ok, api = pcall(require, "plugins.jdtls")
          if ok then
            api.start(args.buf)
          end
        end)
      end,
    })
  end,

  config = function()
    local ok, jdtls = pcall(require, "jdtls")
    if not ok then
      vim.notify("nvim-jdtls failed to load", vim.log.levels.ERROR)
      return
    end

    local capabilities = require("cmp_nvim_lsp").default_capabilities()
    local launcher_glob = vim.fn.stdpath("data")
        .. "/mason/packages/jdtls/plugins/org.eclipse.equinox.launcher_*.jar"
    local launcher_jar = vim.fn.glob(launcher_glob, true, true)[1]
    local lombok_path =
    "C:/Users/Pongo/.m2/repository/org/projectlombok/lombok/1.18.44/lombok-1.18.44.jar"
    local jdtls_config_dir = vim.fn.stdpath("data") .. "/mason/packages/jdtls/config_win"

    local function get_workspace_dir(root_dir)
      local project_name = vim.fs.basename(root_dir):gsub("[^%w%-_]", "_")
      local project_hash = vim.fn.sha256(root_dir):sub(1, 8)

      return vim.fn.stdpath("data")
          .. "/jdtls/workspace/"
          .. project_name
          .. "-"
          .. project_hash
    end

    local function build_config(root_dir)
      if not launcher_jar or launcher_jar == "" then
        vim.notify("JDTLS launcher jar not found in Mason install", vim.log.levels.ERROR)
        return nil
      end

      return {
        cmd = {
          "C:/Program Files/Java/jdk-22/bin/java.exe",
          "--add-modules=ALL-SYSTEM",
          "--add-opens", "java.base/java.util=ALL-UNNAMED",
          "--add-opens", "java.base/java.lang=ALL-UNNAMED",
          "-javaagent:" .. lombok_path,
          "-jar", launcher_jar,
          "-configuration", jdtls_config_dir,
          "-data", get_workspace_dir(root_dir),
        },
        root_dir = root_dir,
        capabilities = capabilities,
        settings = {
          java = {},
        },
        init_options = {
          bundles = {},
        },
      }
    end

    local function ensure_treesitter(bufnr)
      if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].filetype ~= "java" then
        return
      end

      pcall(vim.treesitter.start, bufnr, "java")
    end

    local function buffer_has_jdtls(bufnr)
      local clients = vim.lsp.get_clients({ bufnr = bufnr, name = "jdtls" })
      return #clients > 0
    end

    local function start_jdtls(bufnr)
      local root_hint = vim.fn.getcwd()
      local allow_plain_java = false

      if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
        local bufname = vim.api.nvim_buf_get_name(bufnr)
        if bufname ~= "" then
          root_hint = bufname
        end

        allow_plain_java = vim.bo[bufnr].filetype == "java"
      end

      local root_dir = find_workspace_root(root_hint)

      if not root_dir and allow_plain_java then
        root_dir = find_plain_java_root(root_hint)
      end

      if not root_dir then
        return
      end

      local config = build_config(root_dir)
      if not config then
        return
      end

      vim.fn.mkdir(get_workspace_dir(root_dir), "p")

      jdtls.start_or_attach(config)

      if bufnr and vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype == "java" then
        ensure_treesitter(bufnr)
      end
    end

    local function ensure_java_buffer(bufnr)
      if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].filetype ~= "java" then
        return
      end

      if not buffer_has_jdtls(bufnr) then
        start_jdtls(bufnr)
      end

      ensure_treesitter(bufnr)
    end

    local function rename_java_symbol()
      local bufnr = vim.api.nvim_get_current_buf()
      if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].filetype ~= "java" then
        return false
      end

      local jdtls_client = vim.lsp.get_clients({ bufnr = bufnr, name = "jdtls" })[1]
      if not jdtls_client then
        vim.lsp.buf.rename()
        return true
      end

      local current_word = vim.fn.expand("<cword>")
      local old_path = nil

      local params = vim.lsp.util.make_position_params(0, jdtls_client.offset_encoding)
      local responses = vim.lsp.buf_request_sync(bufnr, "textDocument/definition", params, 1000) or {}
      for client_id, response in pairs(responses) do
        local client = vim.lsp.get_client_by_id(client_id)
        if client and client.name == "jdtls" and response and response.result then
          local result = response.result
          if not vim.islist(result) then
            result = { result }
          end

          for _, item in ipairs(result) do
            local uri = item.uri or item.targetUri
            if uri and vim.startswith(uri, "file://") then
              local candidate = vim.uri_to_fname(uri)
              if vim.fn.fnamemodify(candidate, ":e") == "java"
                  and vim.fn.fnamemodify(candidate, ":t:r") == current_word then
                old_path = candidate
                break
              end
            end
          end
        end

        if old_path then
          break
        end
      end

      if not old_path or old_path == "" then
        local current_path = vim.api.nvim_buf_get_name(bufnr)
        if current_path ~= "" and vim.fn.fnamemodify(current_path, ":t:r") == current_word then
          old_path = current_path
        end
      end

      if not old_path or old_path == "" then
        vim.lsp.buf.rename()
        return true
      end

      local old_name = vim.fn.fnamemodify(old_path, ":t:r")

      vim.ui.input({
        prompt = "New Java type name: ",
        default = old_name,
      }, function(input)
        local new_name = vim.trim(input or "")
        if new_name == "" or new_name == old_name then
          return
        end

        local new_path = vim.fs.joinpath(vim.fs.dirname(old_path), new_name .. ".java")
        if vim.uv.fs_stat(new_path) then
          vim.notify("Target Java file already exists: " .. new_path, vim.log.levels.ERROR)
          return
        end

        local declaration_buf = vim.fn.bufnr(old_path)
        if declaration_buf ~= -1 and vim.api.nvim_buf_is_valid(declaration_buf) and vim.bo[declaration_buf].modified then
          vim.api.nvim_buf_call(declaration_buf, function()
            vim.cmd.write()
          end)
        elseif vim.bo[bufnr].modified then
          vim.api.nvim_buf_call(bufnr, function()
            vim.cmd.write()
          end)
        end

        local rename_params = vim.lsp.util.make_position_params(0, jdtls_client.offset_encoding)
        rename_params.newName = new_name

        jdtls_client:request("textDocument/rename", rename_params, function(err, result)
          if err then
            vim.schedule(function()
              vim.notify("Java rename failed: " .. err.message, vim.log.levels.ERROR)
            end)
            return
          end

          if result then
            vim.schedule(function()
              vim.lsp.util.apply_workspace_edit(result, jdtls_client.offset_encoding)
            end)
          end

          vim.defer_fn(function()
          local target_buf = declaration_buf ~= -1 and declaration_buf or vim.fn.bufnr(old_path)
          if target_buf == -1 or not vim.api.nvim_buf_is_valid(target_buf) then
            target_buf = nil
          end

          if target_buf and vim.bo[target_buf].modified then
            vim.api.nvim_buf_call(target_buf, function()
              vim.cmd.write()
            end)
          elseif vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].modified then
            vim.api.nvim_buf_call(bufnr, function()
              vim.cmd.write()
            end)
          end

          local ok_rename, rename_err = vim.uv.fs_rename(old_path, new_path)
          if not ok_rename then
            vim.notify("Failed to rename Java file: " .. (rename_err or "unknown error"), vim.log.levels.ERROR)
            return
          end

          if target_buf and vim.api.nvim_buf_is_valid(target_buf) then
            vim.api.nvim_buf_set_name(target_buf, new_path)
            vim.api.nvim_buf_call(target_buf, function()
              vim.cmd.edit()
            end)
          end

          if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_get_name(bufnr) == old_path then
            vim.api.nvim_buf_set_name(bufnr, new_path)
            vim.api.nvim_buf_call(bufnr, function()
              vim.cmd.edit()
            end)
          end
          end, 300)
        end, bufnr)
      end)

      return true
    end

    package.loaded["plugins.jdtls"] = {
      start = start_jdtls,
      ensure = ensure_java_buffer,
      rename = rename_java_symbol,
    }

    local group = vim.api.nvim_create_augroup("SpringJavaJdtlsRuntime", { clear = true })

    vim.api.nvim_create_autocmd("BufEnter", {
      group = group,
      pattern = "*.java",
      callback = function(args)
        vim.schedule(function()
          local ok_api, api = pcall(require, "plugins.jdtls")
          if ok_api then
            api.ensure(args.buf)
          end
        end)
      end,
    })
  end,
}
