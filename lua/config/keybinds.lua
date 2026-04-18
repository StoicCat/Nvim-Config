local layout = require("config.layout")
local neotree_resize = require("config.neotree_resize")
local project_tree = require("config.project_tree")

local function go_to_declaration_or_definition()
  local params = vim.lsp.util.make_position_params()
  local current_buf = vim.api.nvim_get_current_buf()
  local current_win = vim.api.nvim_get_current_win()
  local current_pos = vim.api.nvim_win_get_cursor(current_win)
  local clients = vim.lsp.get_clients({ bufnr = current_buf })
  local supports_declaration = false

  for _, client in ipairs(clients) do
    if client:supports_method("textDocument/declaration") then
      supports_declaration = true
      break
    end
  end

  if not supports_declaration then
    vim.lsp.buf.definition()
    return
  end

  vim.lsp.buf_request_all(current_buf, "textDocument/declaration", params, function(results)
    local locations = {}

    for _, result in pairs(results or {}) do
      if result.result then
        if vim.islist(result.result) then
          vim.list_extend(locations, result.result)
        else
          table.insert(locations, result.result)
        end
      end
    end

    if #locations > 0 then
      local first = locations[1]
      vim.lsp.util.show_document(first, "utf-8", { reuse_win = true })

      local new_win = vim.api.nvim_get_current_win()
      local new_pos = vim.api.nvim_win_get_cursor(new_win)

      if new_win ~= current_win or new_pos[1] ~= current_pos[1] or new_pos[2] ~= current_pos[2] then
        return
      end
    end

    vim.lsp.buf.definition()
  end)
end

vim.keymap.set("n", "<leader>cd", vim.cmd.Ex)
vim.keymap.set("n", "gd", go_to_declaration_or_definition, { desc = "Go to declaration" })
vim.keymap.set("n", "gt", vim.lsp.buf.type_definition, { desc = "Go to type definition" })
vim.keymap.set("n", "gi", vim.lsp.buf.implementation, { desc = "Go to implementation" })

-- NeoTree
vim.keymap.set("n", "<leader>e", function()
  vim.cmd("Neotree toggle")
end)
vim.keymap.set("n", "<leader>em", project_tree.focus_project_root,
  { desc = "Neo-tree focus nearest project root" })
vim.keymap.set("n", "<leader>er", project_tree.focus_repo_root,
  { desc = "Neo-tree focus repository root" })
vim.keymap.set("n", "<leader>ew", neotree_resize.widen,
  { desc = "Neo-tree toggle wide width" })
vim.keymap.set("n", "<leader>e=", neotree_resize.increase,
  { desc = "Neo-tree increase width" })
vim.keymap.set("n", "<leader>e-", neotree_resize.decrease,
  { desc = "Neo-tree decrease width" })
vim.keymap.set("n", "<leader>e0", neotree_resize.reset,
  { desc = "Neo-tree reset width" })
vim.keymap.set("n", "<C-h>", "<C-w>h")
vim.keymap.set("n", "<C-j>", "<C-w>j")
vim.keymap.set("n", "<C-k>", "<C-w>k")
vim.keymap.set("n", "<C-l>", "<C-w>l")

-- Bufferline
vim.keymap.set("n", "<Tab>", "<cmd>bnext<CR>", { desc = "Next buffer" })
vim.keymap.set("n", "<S-Tab>", "<cmd>bprevious<CR>", { desc = "Previous buffer" })

vim.keymap.set("n", "<leader>bd", function()
  local current = vim.api.nvim_get_current_buf()
  local bufs = vim.fn.getbufinfo({ buflisted = 1 })
  local ft = vim.bo[current].filetype
  local bt = vim.bo[current].buftype

  if ft == "neo-tree" or ft == "alpha" or bt ~= "" then
    return
  end

  local real_bufs = {}
  local alpha_buf = nil

  for _, buf in ipairs(bufs) do
    local bft = vim.bo[buf.bufnr].filetype

    if bft == "alpha" then
      alpha_buf = buf.bufnr
    elseif bft ~= "neo-tree" then
      table.insert(real_bufs, buf.bufnr)
    end
  end

  if #real_bufs <= 1 then
    if alpha_buf and vim.api.nvim_buf_is_valid(alpha_buf) then
      vim.api.nvim_set_current_buf(alpha_buf)
    else
      layout.show_dashboard()
    end

    if vim.api.nvim_buf_is_valid(current) then
      vim.api.nvim_buf_delete(current, { force = true })
    end
  else
    pcall(vim.cmd, "b#")

    if vim.api.nvim_buf_is_valid(current) then
      vim.api.nvim_buf_delete(current, { force = true })
    end
  end
end, { desc = "Close buffer smart" })

local function focus_real_window()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local ft = vim.bo[buf].filetype

    if ft ~= "neo-tree" and ft ~= "spring-terminal" then
      vim.api.nvim_set_current_win(win)
      return
    end
  end
end

local function focus_main_window()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local ft = vim.bo[buf].filetype

    if ft ~= "neo-tree" and ft ~= "spring-terminal" then
      vim.api.nvim_set_current_win(win)
      return true
    end
  end
  return false
end

vim.keymap.set("n", "<leader>bo", "<cmd>BufferLineCloseOthers<CR>")
vim.keymap.set("n", "<leader>br", "<cmd>BufferLineCloseRight<CR>")
vim.keymap.set("n", "<leader>bl", "<cmd>BufferLineCloseLeft<CR>")
vim.keymap.set("n", "<leader>ba", function()
  local bufs = vim.fn.getbufinfo({ buflisted = 1 })
  local real_bufs = {}
  local alpha_buf = nil

  local current = vim.api.nvim_get_current_buf()
  local cft = vim.bo[current].filetype

  -- collect buffers
  for _, buf in ipairs(bufs) do
    local ft = vim.bo[buf.bufnr].filetype
    local bt = vim.bo[buf.bufnr].buftype

    if ft == "alpha" then
      alpha_buf = buf.bufnr
    elseif bt == "" and ft ~= "neo-tree" then
      table.insert(real_bufs, buf.bufnr)
    end
  end

  if #real_bufs == 0 then
    return
  end

  -- 🔥 STEP 1: move to SAFE window BEFORE anything
  local target_win = nil

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local ft = vim.bo[buf].filetype

    if ft ~= "neo-tree" and ft ~= "spring-terminal" then
      target_win = win
      break
    end
  end

  if target_win then
    vim.api.nvim_set_current_win(target_win)
  end

  -- 🔥 STEP 2: open Alpha FIRST (this stabilizes layout)
  if alpha_buf and vim.api.nvim_buf_is_valid(alpha_buf) then
    vim.api.nvim_set_current_buf(alpha_buf)
  else
    layout.show_dashboard()
  end

  -- 🔥 STEP 3: NOW delete file buffers
  for _, buf in ipairs(real_bufs) do
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
end, { desc = "Close all buffers (smart)" })

vim.keymap.set("n", "<leader>1", "<cmd>BufferLineGoToBuffer 1<CR>")
vim.keymap.set("n", "<leader>2", "<cmd>BufferLineGoToBuffer 2<CR>")
vim.keymap.set("n", "<leader>3", "<cmd>BufferLineGoToBuffer 3<CR>")
vim.keymap.set("n", "<leader>4", "<cmd>BufferLineGoToBuffer 4<CR>")

vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    vim.defer_fn(function()
      local buf = vim.api.nvim_get_current_buf()

      if not vim.api.nvim_buf_is_valid(buf) then
        return
      end

      local name = vim.api.nvim_buf_get_name(buf)
      local ft = vim.bo[buf].filetype
      local bt = vim.bo[buf].buftype

      if bt == "terminal" or ft == "toggleterm" then
        return
      end

      -- ignore special UI buffers completely
      if bt ~= "" or ft == "neo-tree" or ft == "harpoon" or ft == "trouble" then
        return
      end

      -- 🔥 ONLY act on REAL FILE buffers
      local is_real_file =
          ft ~= "alpha" and
          name ~= "" and
          bt == ""

      -- 🔥 CASE 1: Remove alpha ONLY for real file
      if is_real_file then
        for _, b in ipairs(vim.api.nvim_list_bufs()) do
          if vim.bo[b].filetype == "alpha" then
            if vim.api.nvim_buf_is_valid(b) then
              vim.api.nvim_buf_delete(b, { force = true })
            end
          end
        end
      end

      -- ignore empty buffers
      if name == "" then
        return
      end

      -- 🔥 CASE 2: Remove deleted file buffer
      local stat = vim.loop.fs_stat(name)

      if stat == nil then
        pcall(vim.cmd, "b#")

        if vim.api.nvim_buf_is_valid(buf) then
          vim.api.nvim_buf_delete(buf, { force = true })
        end
      end
    end, 50)
  end,
})


-- Toggleterm
vim.keymap.set("t", "<esc>", [[<c-\><c-n>]])
vim.keymap.set("t", "<leader>t", [[<c-\><c-n><cmd>ToggleTerm<CR>]])


-- Spring boot
vim.keymap.set("n", "<leader>r", _SPRING_RUN)
vim.keymap.set("n", "<leader>rr", _SPRING_RESTART)
vim.keymap.set("n", "<leader>rs", _SPRING_STOP)
vim.keymap.set("n", "<leader>rt", _SPRING_TOGGLE)


-- Copy to clipboard
vim.keymap.set("n", "<leader>y", '"+y')
vim.keymap.set("v", "<leader>y", '"+y')


-- Escape to JJ
vim.keymap.set("i", "jj", "<Esc>")
