return {
  {
    "stevearc/oil.nvim",
    opts = {
      view_options = { show_hidden = true },
    },
    keys = {
      { "-", "<cmd>Oil --float<cr>", desc = "Oil: toggle float" },
      { "<leader>e", "<cmd>Oil --float<cr>", desc = "Explorer (Oil)" },
    },
  },
  { "nvim-neo-tree/neo-tree.nvim", enabled = false },
}
