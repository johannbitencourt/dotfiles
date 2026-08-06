return {
  {
    "Mathijs-Bakker/godotdev.nvim",
    dependencies = {
      { "mfussenegger/nvim-dap", lazy = false },
      { "nvim-neotest/nvim-nio", lazy = false },
      { "rcarriga/nvim-dap-ui", lazy = false, opts = {} },
      "nvim-treesitter/nvim-treesitter",
    },
    opts = {
      csharp = false,
    },
  },
}
