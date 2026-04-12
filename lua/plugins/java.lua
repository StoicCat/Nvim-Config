local java_root_markers = {
  "pom.xml",
  "build.gradle",
  "build.gradle.kts",
  "settings.gradle",
  "settings.gradle.kts",
  "mvnw",
  "gradlew",
}

local function normalize(path)
  return vim.fs.normalize(path)
end

local function path_dir(path)
  local stat = path and vim.loop.fs_stat(path) or nil
  if stat and stat.type == "directory" then
    return path
  end

  return vim.fs.dirname(path)
end

local function git_toplevel(start_path)
  if vim.fn.executable("git") ~= 1 then
    return nil
  end

  local dir = path_dir(start_path or vim.fn.getcwd())
  local result = vim.system({ "git", "-C", dir, "rev-parse", "--show-toplevel" }, { text = true }):wait()
  if result.code ~= 0 or not result.stdout then
    return nil
  end

  local root = vim.trim(result.stdout)
  if root == "" then
    return nil
  end

  return normalize(root)
end

local function find_java_root(start_path)
  local git_root = git_toplevel(start_path)
  if git_root then
    local root_markers = vim.fs.find(java_root_markers, {
      upward = false,
      path = git_root,
      limit = math.huge,
    })

    if root_markers and #root_markers > 0 then
      return git_root
    end
  end

  local found = vim.fs.find(java_root_markers, {
    upward = true,
    path = start_path or vim.fn.getcwd(),
  })

  if not found or #found == 0 then
    return nil
  end

  return normalize(vim.fs.dirname(found[#found]))
end

return {
  "mfussenegger/nvim-jdtls",
  name = "nvim-jdtls",
  ft = "java",
  init = function()
    local group = vim.api.nvim_create_augroup("JavaProjectLoader", { clear = true })

    local function load_for_java_project(path)
      if find_java_root(path) then
        require("lazy").load({ plugins = { "nvim-jdtls" } })
      end
    end

    vim.api.nvim_create_autocmd("VimEnter", {
      group = group,
      callback = function()
        load_for_java_project(vim.fn.getcwd())
      end,
    })

    vim.api.nvim_create_autocmd("DirChanged", {
      group = group,
      callback = function(args)
        load_for_java_project(args.file)
      end,
    })
  end,
  config = function()
    local jdtls = require("jdtls")
    local group = vim.api.nvim_create_augroup("JavaLspAttach", { clear = true })

    local function start_jdtls(bufnr)
      local file = vim.api.nvim_buf_get_name(bufnr)
      local root_dir = find_java_root(file)

      if not root_dir then
        return
      end

      local workspace_dir = vim.fn.stdpath("data")
        .. "/jdtls/workspace/"
        .. vim.fs.basename(root_dir)

      local lombok_path = "C:/Users/Pongo/.m2/repository/org/projectlombok/lombok/1.18.44/lombok-1.18.44.jar"
      local launcher_jar =
        "C:/Users/Pongo/AppData/Local/nvim-data/mason/packages/jdtls/plugins/org.eclipse.equinox.launcher_1.7.100.v20251111-0406.jar"

      local config = {
        cmd = {
          "C:/Program Files/Java/jdk-22/bin/java.exe",
          "--add-modules=ALL-SYSTEM",
          "--add-opens", "java.base/java.util=ALL-UNNAMED",
          "--add-opens", "java.base/java.lang=ALL-UNNAMED",
          "-javaagent:" .. lombok_path,
          "-jar", launcher_jar,
          "-configuration", "C:/Users/Pongo/AppData/Local/nvim-data/mason/packages/jdtls/config_win",
          "-data",
          workspace_dir,
        },
        root_dir = root_dir,
        settings = {
          java = {},
        },
        init_options = {
          bundles = {},
        },
      }

      jdtls.start_or_attach(config)
    end

    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = "java",
      callback = function(args)
        start_jdtls(args.buf)
      end,
    })

    if vim.bo.filetype == "java" then
      start_jdtls(vim.api.nvim_get_current_buf())
    end
  end,
}
