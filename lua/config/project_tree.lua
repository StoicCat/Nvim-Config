local M = {}
local neotree_command = require("neo-tree.command")

local project_markers = {
  "pom.xml",
  "build.gradle",
  "build.gradle.kts",
  "settings.gradle",
  "settings.gradle.kts",
  "mvnw",
  "gradlew",
  "package.json",
  "tsconfig.json",
  "jsconfig.json",
  "pyproject.toml",
  "setup.py",
  "setup.cfg",
  "requirements.txt",
  "Cargo.toml",
  "go.mod",
  "Makefile",
  "justfile",
}

local function normalize(path)
  return vim.fs.normalize(path)
end

local function is_real_file(path)
  return path and path ~= "" and vim.loop.fs_stat(path) ~= nil
end

local function current_buffer_path()
  local path = vim.api.nvim_buf_get_name(0)

  if is_real_file(path) then
    return normalize(path)
  end

  return normalize(vim.fn.getcwd())
end

local function path_dir(path)
  local stat = vim.loop.fs_stat(path)
  if stat and stat.type == "directory" then
    return path
  end

  return vim.fs.dirname(path)
end

local function find_upward(markers, start_path)
  local found = vim.fs.find(markers, {
    upward = true,
    path = path_dir(start_path),
  })

  if not found or #found == 0 then
    return nil
  end

  return normalize(vim.fs.dirname(found[1]))
end

local function git_toplevel(start_path)
  if vim.fn.executable("git") ~= 1 then
    return nil
  end

  local dir = path_dir(start_path)
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

function M.find_project_root(start_path)
  return find_upward(project_markers, start_path or current_buffer_path())
end

function M.find_repo_root(start_path)
  local path = start_path or current_buffer_path()
  local git_root = git_toplevel(path) or find_upward({ ".git" }, path)
  if git_root then
    return git_root
  end

  return M.find_project_root(path) or normalize(vim.fn.getcwd())
end

local function open_neotree_at(dir, reveal_file)
  if not dir or dir == "" then
    return
  end

  local args = {
    action = "show",
    source = "filesystem",
    position = "left",
    dir = dir,
  }

  if reveal_file and reveal_file ~= "" then
    args.reveal_file = reveal_file
  end

  neotree_command.execute(args)
end

function M.focus_project_root()
  local file = current_buffer_path()
  local project_root = M.find_project_root(file)

  if not project_root then
    vim.notify("No project root found for current buffer", vim.log.levels.WARN)
    return
  end

  open_neotree_at(project_root, file)
end

function M.focus_repo_root()
  local file = current_buffer_path()
  local repo_root = M.find_repo_root(file)
  open_neotree_at(repo_root)
end

return M
