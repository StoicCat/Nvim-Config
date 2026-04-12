local M = {}

local function get_buf_meta(buf)
  return {
    name = vim.api.nvim_buf_get_name(buf),
    ft = vim.bo[buf].filetype,
    bt = vim.bo[buf].buftype,
  }
end

local function is_terminal_ft(ft, bt)
  return bt == "terminal" or ft == "toggleterm" or ft == "spring-terminal"
end

local function is_real_editor(meta)
  return meta.bt == "" and meta.ft ~= "neo-tree" and meta.ft ~= "alpha"
end

local function sort_right_column(a, b)
  local a_pos = vim.api.nvim_win_get_position(a)
  local b_pos = vim.api.nvim_win_get_position(b)

  if a_pos[2] == b_pos[2] then
    return a_pos[1] < b_pos[1]
  end

  return a_pos[2] > b_pos[2]
end

function M.get_windows()
  local state = {
    neotree = nil,
    terminal = nil,
    alpha = nil,
    editor = nil,
    fallback = nil,
  }

  local editor_candidates = {}
  local alpha_candidates = {}

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local cfg = vim.api.nvim_win_get_config(win)

    if cfg.relative == "" then
      local buf = vim.api.nvim_win_get_buf(win)
      local meta = get_buf_meta(buf)

      if meta.ft == "neo-tree" then
        state.neotree = win
      elseif is_terminal_ft(meta.ft, meta.bt) then
        state.terminal = win
      else
        table.insert(editor_candidates, win)

        if meta.ft == "alpha" then
          table.insert(alpha_candidates, win)
        end

        if is_real_editor(meta) then
          state.editor = win
        end
      end
    end
  end

  table.sort(editor_candidates, sort_right_column)
  table.sort(alpha_candidates, sort_right_column)

  if not state.editor then
    state.editor = editor_candidates[1]
  end

  state.alpha = alpha_candidates[1]
  state.fallback = editor_candidates[1]

  return state
end

function M.focus_main_window()
  local state = M.get_windows()
  local target = state.editor or state.alpha or state.fallback

  if target and vim.api.nvim_win_is_valid(target) then
    vim.api.nvim_set_current_win(target)
    return target
  end

  return nil
end

function M.enforce_neotree_width()
  local state = M.get_windows()

  if state.neotree and vim.api.nvim_win_is_valid(state.neotree) then
    vim.api.nvim_win_set_width(state.neotree, 30)
  end
end

function M.cleanup_duplicate_alpha_windows()
  local seen = false

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)

    if vim.bo[buf].filetype == "alpha" then
      if seen then
        pcall(vim.api.nvim_win_close, win, true)
      else
        seen = true
      end
    end
  end

  local keep = nil

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "alpha" then
      if keep == nil then
        keep = buf
      else
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end
    end
  end
end

function M.show_dashboard()
  local state = M.get_windows()

  if state.alpha and vim.api.nvim_win_is_valid(state.alpha) then
    vim.api.nvim_set_current_win(state.alpha)
    M.cleanup_duplicate_alpha_windows()
    M.enforce_neotree_width()
    return state.alpha
  end

  local target = state.editor or state.fallback

  if target and vim.api.nvim_win_is_valid(target) then
    vim.api.nvim_set_current_win(target)
  end

  vim.cmd("Alpha")
  vim.cmd("stopinsert")

  M.cleanup_duplicate_alpha_windows()
  M.enforce_neotree_width()

  return vim.api.nvim_get_current_win()
end

function M.place_buffer_below_main(bufnr, height)
  local state = M.get_windows()
  local anchor = state.editor or state.alpha or state.fallback

  if not anchor or not vim.api.nvim_win_is_valid(anchor) then
    return nil
  end

  vim.api.nvim_set_current_win(anchor)
  vim.cmd("belowright split")

  local term_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(term_win, bufnr)
  vim.cmd(("resize %d"):format(height or 15))

  M.enforce_neotree_width()
  M.cleanup_duplicate_alpha_windows()

  return term_win
end

function M.reposition_terminal(bufnr, height)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end

  local state = M.get_windows()

  if not (state.neotree and vim.api.nvim_win_is_valid(state.neotree)) then
    M.cleanup_duplicate_alpha_windows()
    return state.terminal
  end

  if state.terminal and vim.api.nvim_win_is_valid(state.terminal) then
    pcall(vim.api.nvim_win_close, state.terminal, true)
  end

  return M.place_buffer_below_main(bufnr, height)
end

function M.fix_layout()
  M.enforce_neotree_width()
  M.cleanup_duplicate_alpha_windows()
end

return M
