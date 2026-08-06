return {
  "stevearc/oil.nvim",
  config = function()
    local oil = require("oil")
    oil.setup({
      view_options = {
        show_hidden = true,
      },
    })
    vim.keymap.set("n", "-", oil.toggle_float, { desc = "Oil: toggle float" })
    vim.keymap.set("n", "<leader>-", oil.toggle_hidden, { desc = "Oil: toggle hidden" })
    vim.keymap.set("n", "<leader>e", oil.toggle_float, { desc = "Explorer (Oil)" })
  end,
}
