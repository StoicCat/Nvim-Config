local function find_maven_root(path)
  local dir = path

  -- if it's a file, go to its directory
  if vim.loop.fs_stat(path) and vim.loop.fs_stat(path).type ~= "directory" then
    dir = vim.fs.dirname(path)
  end

  local last = nil

  while dir do
    local pom = vim.fs.joinpath(dir, "pom.xml")

    if vim.loop.fs_stat(pom) then
      last = dir
    end

    local parent = vim.fs.dirname(dir)
    if parent == dir then break end
    dir = parent
  end

  return last
end

return {
  "mfussenegger/nvim-jdtls",
  name = "nvim-jdtls",

  init = function()
    vim.api.nvim_create_autocmd("VimEnter", {
      callback = function()
        local root = find_maven_root(vim.fn.getcwd())

        print("JDTLS root:", root)

        if not root then
          return
        end

        -- load plugin
        require("lazy").load({
          plugins = { "nvim-jdtls" },
          wait = true,
        })

        -- start jdtls after plugin is loaded
        vim.schedule(function()
          print("Starting JDTLS...")
          require("plugins.jdtls").start(root)
        end)
      end,
    })
  end,

  config = function()
    local jdtls = require("jdtls")
    if not jdtls then
      print("JDTLS not loaded!")
      return
    end
    local function start_jdtls(root_dir)
      if not root_dir then
        return
      end

      -- unique workspace per project
      local workspace_dir = vim.fn.stdpath("data")
          .. "/jdtls/workspace/"
          .. vim.fn.sha256(root_dir):sub(1, 8)

      local lombok_path =
      "C:/Users/Pongo/.m2/repository/org/projectlombok/lombok/1.18.44/lombok-1.18.44.jar"

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
          "-configuration",
          "C:/Users/Pongo/AppData/Local/nvim-data/mason/packages/jdtls/config_win",
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

    -- expose start function
    package.loaded["plugins.jdtls"] = {
      start = start_jdtls,
    }

    -- attach buffers to existing jdtls
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "java",
      callback = function()
        local clients = vim.lsp.get_clients({ name = "jdtls" })
        if #clients > 0 then
          vim.lsp.buf_attach_client(0, clients[1].id)
        end
      end,
    })
  end,
}
