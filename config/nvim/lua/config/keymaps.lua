-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

map("n", "<leader>fn", function()
  require("telescope.builtin").find_files({ cwd = vim.fn.stdpath("config") })
end, { desc = "Find Neovim config" })
