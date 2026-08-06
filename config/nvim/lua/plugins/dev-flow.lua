return {
  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnostics (Trouble)" },
      { "<leader>xq", "<cmd>Trouble qflist toggle<cr>", desc = "Quickfix (Trouble)" },
    },
    opts = {},
  },

  {
    "lewis6991/gitsigns.nvim",
    opts = {
      current_line_blame = true,
    },
  },

  {
    "nvim-telescope/telescope.nvim",
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find files" },
      { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Live grep" },
      { "<leader>fr", "<cmd>Telescope oldfiles<cr>", desc = "Recent files" },
      { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Buffers" },
    },
  },

  {
    "stevearc/aerial.nvim",
    opts = {},
    keys = {
      { "<leader>cs", "<cmd>AerialToggle!<cr>", desc = "Symbols outline" },
    },
  },

  {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = function()
      local function map(lhs, rhs, desc)
        return { lhs, rhs, desc = desc }
      end

      return {
        map("<leader>ha", function()
          require("harpoon"):list():add()
        end, "Harpoon add file"),
        map("<leader>hh", function()
          require("harpoon").ui:toggle_quick_menu(require("harpoon"):list())
        end, "Harpoon menu"),
        map("<leader>h1", function()
          require("harpoon"):list():select(1)
        end, "Harpoon file 1"),
        map("<leader>h2", function()
          require("harpoon"):list():select(2)
        end, "Harpoon file 2"),
        map("<leader>h3", function()
          require("harpoon"):list():select(3)
        end, "Harpoon file 3"),
        map("<leader>h4", function()
          require("harpoon"):list():select(4)
        end, "Harpoon file 4"),
      }
    end,
  },

  {
    "folke/todo-comments.nvim",
    opts = {},
    keys = {
      { "]t", function() require("todo-comments").jump_next() end, desc = "Next todo" },
      { "[t", function() require("todo-comments").jump_prev() end, desc = "Previous todo" },
      { "<leader>xt", "<cmd>TodoTrouble<cr>", desc = "Todo (Trouble)" },
      { "<leader>xT", "<cmd>TodoTelescope<cr>", desc = "Todo (Telescope)" },
    },
  },

  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {},
  },

  {
    "mbbill/undotree",
    keys = {
      { "<leader>uD", "<cmd>UndotreeToggle<cr>", desc = "Undo tree" },
    },
  },

  {
    "pmizio/typescript-tools.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
    ft = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
    opts = {},
  },

  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        tsserver = false,
      },
    },
  },

  {
    "rest-nvim/rest.nvim",
    ft = { "http" },
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {},
  },
}
