return {
  {
    "Mathijs-Bakker/godotdev.nvim",
    ft = { "gdscript", "gdshader", "gdresource" },
    dependencies = {
      "mfussenegger/nvim-dap",
      "nvim-neotest/nvim-nio",
      { "rcarriga/nvim-dap-ui", opts = {} },
      "nvim-treesitter/nvim-treesitter",
    },
    opts = { csharp = false },
  },
}
