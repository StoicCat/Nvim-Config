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

local function find_workspace_root(path)
  local start = path

  if not start or start == "" then
    start = vim.fn.getcwd()
  end

  local stat = vim.uv.fs_stat(start)
  if stat and stat.type ~= "directory" then
    start = vim.fs.dirname(start)
  end

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

      if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
        local bufname = vim.api.nvim_buf_get_name(bufnr)
        if bufname ~= "" then
          root_hint = bufname
        end
      end

      local root_dir = find_workspace_root(root_hint)

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

    package.loaded["plugins.jdtls"] = {
      start = start_jdtls,
      ensure = ensure_java_buffer,
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
