local dms_theme = vim.fn.filereadable(vim.fn.stdpath("config") .. "/colors/dms.lua") == 1

return {
  {
    "AvengeMedia/base46",
    lazy = false,
    opts = {},
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = dms_theme and "dms" or "tokyonight",
    },
  },
}
