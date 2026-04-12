return {
  { -- Git Plugin
    'tpope/vim-fugitive',
  },
  { -- Show CSS Colors
    'brenoprata10/nvim-highlight-colors',
    config = function()
      require('nvim-highlight-colors').setup({})
    end
  },
  {
    "karb94/neoscroll.nvim",
    opts = {
      easing_function = "cubic",
      hide_cursor = true,
      stop_eof = true,
    },
  },
  {
    "sphamba/smear-cursor.nvim", opts = {}
  },
  {
    'j-hui/fidget.nvim',
    opts = {
      progress = {
        suppress_on_insert = false,
        ignore_empty_message = false,
        display = {
          render_limit = 8,
          done_ttl = 4,
          progress_ttl = math.huge,
          done_icon = 'OK',
          progress_icon = { 'dots' },
          group_style = 'Title',
          icon_style = 'Question',
        },
      },
      notification = {
        window = {
          border = 'rounded',
          winblend = 0,
          x_padding = 2,
          y_padding = 1,
        },
      },
    },
  },
}
