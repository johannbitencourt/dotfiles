return {
  {
    "folke/which-key.nvim",
    opts = {
      preset = "modern",
      delay = 200,
      plugins = {
        spelling = true,
      },
    },
  },

  {
    "rcarriga/nvim-notify",
    opts = {
      timeout = 2500,
      fps = 60,
      max_height = function()
        return math.floor(vim.o.lines * 0.75)
      end,
      max_width = function()
        return math.floor(vim.o.columns * 0.4)
      end,
    },
  },

  {
    "folke/noice.nvim",
    opts = {
      lsp = {
        progress = {
          enabled = false,
        },
      },
      presets = {
        lsp_doc_border = true,
      },
    },
    keys = {
      { "<leader>sn", "<cmd>Noice telescope<cr>", desc = "Noice history" },
    },
  },

  {
    "AckslD/nvim-neoclip.lua",
    dependencies = {
      "nvim-telescope/telescope.nvim",
      "kkharji/sqlite.lua",
    },
    opts = {
      history = 300,
      enable_persistent_history = true,
      default_register = '"',
    },
    keys = {
      {
        "<leader>fy",
        function()
          require("telescope").extensions.neoclip.default()
        end,
        desc = "Clipboard history",
      },
    },
    config = function(_, opts)
      require("neoclip").setup(opts)
      pcall(require("telescope").load_extension, "neoclip")
    end,
  },

  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = {},
    keys = {
      {
        "<leader>qs",
        function()
          require("persistence").load()
        end,
        desc = "Restore session",
      },
      {
        "<leader>qS",
        function()
          require("persistence").select()
        end,
        desc = "Select session",
      },
      {
        "<leader>ql",
        function()
          require("persistence").load({ last = true })
        end,
        desc = "Restore last session",
      },
      {
        "<leader>qd",
        function()
          require("persistence").stop()
        end,
        desc = "Disable session save",
      },
    },
  },

  {
    "j-hui/fidget.nvim",
    event = "LspAttach",
    opts = {
      progress = {
        display = {
          done_ttl = 1,
        },
      },
      notification = {
        window = {
          winblend = 0,
        },
      },
    },
  },

  {
    "nvim-pack/nvim-spectre",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      {
        "<leader>sr",
        function()
          require("spectre").toggle()
        end,
        desc = "Search and replace",
      },
      {
        "<leader>sw",
        function()
          require("spectre").open_visual({ select_word = true })
        end,
        desc = "Search current word",
      },
    },
  },

  {
    "stevearc/dressing.nvim",
    event = "VeryLazy",
    opts = {},
  },
}
