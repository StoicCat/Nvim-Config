vim.api.nvim_create_autocmd("BufNewFile", {
  callback = function()
    vim.schedule(function()
      local buf = vim.api.nvim_get_current_buf()
      local name = vim.api.nvim_buf_get_name(buf)
      local ft = vim.bo[buf].filetype

      -- ignore weird buffers
      if name == "" or ft == "neo-tree" then
        return
      end

      -- 🔥 remove useless [No Name] buffers
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        local bname = vim.api.nvim_buf_get_name(b)
        local bft = vim.bo[b].filetype
        local bt = vim.bo[b].buftype

        if bname == "" and bft == "" and bt == "" then
          if vim.api.nvim_buf_is_valid(b) then
            vim.api.nvim_buf_delete(b, { force = true })
          end
        end
      end
    end)
  end,
})

vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    vim.schedule(function()
      local has_real = false

      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) then
          local name = vim.api.nvim_buf_get_name(buf)
          local ft = vim.bo[buf].filetype
          local bt = vim.bo[buf].buftype

          if name ~= "" and ft ~= "alpha" and ft ~= "neo-tree" and bt == "" then
            has_real = true
            break
          end
        end
      end

      -- If no real buffers → clean junk buffers
      if not has_real then
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_is_valid(buf) then
            local name = vim.api.nvim_buf_get_name(buf)
            local ft = vim.bo[buf].filetype
            local bt = vim.bo[buf].buftype

            if name == "" and ft == "" and bt == "" then
              vim.api.nvim_buf_delete(buf, { force = true })
            end
          end
        end
      end
    end)
  end,
})
