return {
  "folke/noice.nvim",
  event = "VeryLazy",
  dependencies = {
    "MunifTanjim/nui.nvim",
  },
  opts = {
    cmdline = {
      enabled = true,
      view = "cmdline_popup",
      format = {
        cmdline = { pattern = "^:", icon = ":" },
        search_down = { kind = "search", pattern = "^/", icon = "/" },
        search_up = { kind = "search", pattern = "^%?", icon = "?" },
      },
    },
    popupmenu = {
      enabled = true,
      backend = "nui",
    },
    notify = {
      enabled = false,
    },
    messages = {
      enabled = true,
    },
    lsp = {
      progress = {
        enabled = false,
      },
    },
    presets = {
      bottom_search = false,
      command_palette = true,
      long_message_to_split = true,
      inc_rename = false,
      lsp_doc_border = false,
    },
  },
}
