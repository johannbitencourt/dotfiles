-- Aura is the Dracula palette (#282a36 / #f8f8f2 / #8be9fd), so nvim uses
-- Dracula rather than tokyonight — the other two themes' choice.
return {
  {
    "Mofiqul/dracula.nvim",
    name = "dracula",
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "dracula",
    },
  },
}
