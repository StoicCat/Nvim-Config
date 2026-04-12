vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

require('config.options')
require('config.lazy')
require('config.layout')
require('config.terminal')
require('config.keybinds')
require('config.autocmds')
