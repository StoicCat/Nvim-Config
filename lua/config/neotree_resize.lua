local M = {}

local DEFAULT_WIDTH = 30
local WIDE_WIDTH = 50
local STEP = 5

local function find_neotree_window()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "neo-tree" then
      return win
    end
  end

  return nil
end

local function set_width(width)
  local win = find_neotree_window()
  if not win then
    vim.notify("Neo-tree is not open", vim.log.levels.WARN)
    return
  end

  vim.api.nvim_win_set_width(win, width)
end

function M.widen()
  local win = find_neotree_window()
  if not win then
    vim.notify("Neo-tree is not open", vim.log.levels.WARN)
    return
  end

  local current = vim.api.nvim_win_get_width(win)
  if current < WIDE_WIDTH then
    set_width(WIDE_WIDTH)
  else
    set_width(DEFAULT_WIDTH)
  end
end

function M.increase()
  local win = find_neotree_window()
  if not win then
    vim.notify("Neo-tree is not open", vim.log.levels.WARN)
    return
  end

  set_width(vim.api.nvim_win_get_width(win) + STEP)
end

function M.decrease()
  local win = find_neotree_window()
  if not win then
    vim.notify("Neo-tree is not open", vim.log.levels.WARN)
    return
  end

  set_width(math.max(20, vim.api.nvim_win_get_width(win) - STEP))
end

function M.reset()
  set_width(DEFAULT_WIDTH)
end

return M
