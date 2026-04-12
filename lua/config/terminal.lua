local Terminal = require("toggleterm.terminal").Terminal
local layout = require("config.layout")

local is_running = false
local job_id = nil
local spring = nil

-- =========================
-- Command resolver
-- =========================
local function get_spring_cmd()
  if vim.fn.filereadable("mvnw.cmd") == 1 then
    return ".\\mvnw.cmd spring-boot:run"
  elseif vim.fn.filereadable("mvnw") == 1 then
    return "./mvnw spring-boot:run"
  elseif vim.fn.filereadable("gradlew.bat") == 1 then
    return "gradlew.bat bootRun"
  elseif vim.fn.filereadable("gradlew") == 1 then
    return "./gradlew bootRun"
  else
    return "mvn spring-boot:run"
  end
end

-- =========================
-- Check if job is alive (REAL SOURCE OF TRUTH)
-- =========================
local function is_job_alive(job)
  if not job then return false end
  return vim.fn.jobwait({ job }, 0)[1] == -1
end

local function has_active_command_process(job)
  if not job then return false end

  local pid = vim.fn.jobpid(job)
  if not pid or pid <= 0 then return false end

  if vim.fn.has("win32") == 0 then
    return is_job_alive(job)
  end

  local shell_names = {
    ["cmd.exe"] = true,
    ["conhost.exe"] = true,
    ["openconsole.exe"] = true,
    ["powershell.exe"] = true,
    ["pwsh.exe"] = true,
    ["windowsterminal.exe"] = true,
  }

  local script = ([=[
    $target = %d
    $shellNames = @("cmd.exe", "conhost.exe", "openconsole.exe", "powershell.exe", "pwsh.exe", "windowsterminal.exe")
    $procs = @(Get-CimInstance Win32_Process | Select-Object ProcessId, ParentProcessId, Name)
    $queue = [System.Collections.Generic.Queue[int]]::new()
    $queue.Enqueue($target)
    $seen = @{}

    while ($queue.Count -gt 0) {
      $parent = $queue.Dequeue()
      if ($seen.ContainsKey($parent)) { continue }
      $seen[$parent] = $true

      foreach ($proc in $procs) {
        if ([int]$proc.ParentProcessId -eq $parent) {
          $name = ([string]$proc.Name).ToLowerInvariant()
          if ($shellNames -notcontains $name) {
            Write-Output "true"
            exit 0
          }
          $queue.Enqueue([int]$proc.ProcessId)
        }
      }
    }

    Write-Output "false"
  ]=]):format(pid)

  local result = vim.fn.system({ "pwsh", "-NoProfile", "-Command", script })

  if vim.v.shell_error ~= 0 then
    return is_job_alive(job)
  end

  return vim.trim(result) == "true"
end

local function refresh_run_state()
  if not is_running then
    return false
  end

  if not is_job_alive(job_id) then
    is_running = false
    job_id = nil
    return false
  end

  if not has_active_command_process(job_id) then
    is_running = false
    return false
  end

  return true
end

-- =========================
-- Create / Get singleton terminal
-- =========================
local function get_or_create_terminal()
  if spring and spring.bufnr and vim.api.nvim_buf_is_valid(spring.bufnr) then
    return spring
  end

  spring = Terminal:new({
    hidden = true,
    direction = "horizontal",
    count = 99,
    close_on_exit = false,

    on_open = function(term)
      job_id = term.job_id
      vim.bo[term.bufnr].filetype = "spring-terminal"
      vim.bo[term.bufnr].buflisted = false

      if is_job_alive(job_id) then
        vim.cmd("startinsert!")
      else
        vim.cmd("stopinsert")
      end
    end,

    on_exit = function()
      is_running = false
      job_id = nil
    end,
  })

  return spring
end

-- =========================
-- Cleanup terminal (hard reset)
-- =========================
local function cleanup_terminal()
  if not spring then return end

  local buf = spring.bufnr

  if spring:is_open() then
    spring:close()
  end

  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end

  spring = nil
  job_id = nil
  is_running = false
end

-- =========================
-- Find terminal window
-- =========================
local function find_terminal_window(term)
  if not term or not term.bufnr then return nil end

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == term.bufnr then
      return win
    end
  end

  return nil
end

local function focus_editor_window()
  return layout.focus_main_window()
end

local function prepare_terminal_buffer(term)
  if not term.bufnr or not vim.api.nvim_buf_is_valid(term.bufnr) then
    term:spawn()
  end

  job_id = term.job_id

  if term.bufnr and vim.api.nvim_buf_is_valid(term.bufnr) then
    vim.bo[term.bufnr].filetype = "spring-terminal"
    vim.bo[term.bufnr].buflisted = false
  end
end

-- =========================
-- Focus or open terminal
-- =========================
local function focus_or_open(term)
  local win = find_terminal_window(term)

  if win then
    vim.api.nvim_set_current_win(win)
    return
  end

  focus_editor_window()
  prepare_terminal_buffer(term)

  local placed = layout.place_buffer_below_main(term.bufnr, 15)

  if placed and vim.api.nvim_win_is_valid(placed) then
    vim.api.nvim_set_current_win(placed)

    if is_job_alive(job_id) then
      vim.cmd("startinsert!")
    else
      vim.cmd("stopinsert")
    end
  end
end

local function hide_terminal(term)
  local win = find_terminal_window(term)

  if win and vim.api.nvim_win_is_valid(win) then
    local current = vim.api.nvim_get_current_win()

    if current == win then
      focus_editor_window()
    end

    pcall(vim.api.nvim_win_close, win, true)
    return true
  end

  if term:is_open() then
    term:close()
    return true
  end

  return false
end

-- =========================
-- Force terminal to NORMAL mode (safe)
-- =========================
local function force_terminal_normal(term)
  if not term or not term.bufnr then return end
  if not vim.api.nvim_buf_is_valid(term.bufnr) then return end

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == term.bufnr then
      vim.api.nvim_set_current_win(win)

      local keys = vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true)
      vim.api.nvim_feedkeys(keys, "n", false)

      return
    end
  end
end

-- =========================
-- RUN
-- =========================
function _SPRING_RUN()
  local term = get_or_create_terminal()

  -- already running and alive
  if refresh_run_state() then
    focus_or_open(term)
    vim.notify("There is already app running", vim.log.levels.INFO)
    return
  end

  -- 🔥 CRITICAL: recreate if job is dead
  if not is_job_alive(job_id) then
    cleanup_terminal()
    term = get_or_create_terminal()
  end

  focus_or_open(term)

  term:send(get_spring_cmd(), true)

  is_running = true
end

-- =========================
-- TOGGLE (UI only)
-- =========================
function _SPRING_TOGGLE()
  local term = get_or_create_terminal()

  if find_terminal_window(term) or term:is_open() then
    hide_terminal(term)
  else
    focus_or_open(term)
  end

  -- ensure dead terminal is safe
  if not is_job_alive(job_id) then
    vim.schedule(function()
      force_terminal_normal(term)
    end)
  end
end

-- =========================
-- STOP
-- =========================
function _SPRING_STOP()
  if not refresh_run_state() then
    vim.notify("There is no app running", vim.log.levels.WARN)
    return
  end

  local term = get_or_create_terminal()
  local term_buf = term.bufnr
  local current_buf = vim.api.nvim_get_current_buf()

  -- leave terminal safely
  if term_buf and current_buf == term_buf then
    vim.cmd("wincmd p")
  end

  focus_or_open(term)

  -- stop process
  vim.fn.jobstop(job_id)

  -- fallback kill
  vim.defer_fn(function()
    if is_job_alive(job_id) then
      vim.fn.jobstop(job_id)
    end
  end, 800)

  -- make terminal non-interactive
  vim.defer_fn(function()
    force_terminal_normal(term)
  end, 50)

  vim.notify("Spring Boot stopped (logs preserved)", vim.log.levels.INFO)

  is_running = false
end

-- =========================
-- RESTART
-- =========================
function _SPRING_RESTART()
  local was_running = refresh_run_state()

  if was_running then
    _SPRING_STOP()

    vim.defer_fn(function()
      _SPRING_RUN()
    end, 900)
    return
  end

  _SPRING_RUN()
end

-- =========================
-- Safety: prevent insert mode in dead terminal
-- =========================
vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    if spring and vim.api.nvim_get_current_buf() == spring.bufnr then
      if not is_job_alive(job_id) then
        vim.cmd("stopinsert")
      end
    end
  end,
})
