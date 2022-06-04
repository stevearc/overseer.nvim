local binding_util = require("overseer.binding_util")
local M
M = {
  {
    lhs = "?",
    mode = "n",
    desc = "Show default key bindings",
    plug = "<Plug>OverseerTask:ShowHelp",
    rhs = function()
      binding_util.show_bindings(M)
    end,
  },
  {
    lhs = "<CR>",
    mode = "n",
    desc = "Open task action menu",
    plug = "<Plug>OverseerTask:RunAction",
    rhs = function(sidebar)
      sidebar:run_action()
    end,
  },
  {
    lhs = "<C-e>",
    mode = "n",
    desc = "Edit task",
    plug = "<Plug>OverseerTask:Edit",
    rhs = function(sidebar)
      sidebar:run_action("edit")
    end,
  },
  {
    lhs = "o",
    mode = "n",
    desc = "Open task terminal in current window",
    plug = "<Plug>OverseerTask:Open",
    rhs = function(sidebar)
      sidebar:run_action("open")
    end,
  },
  {
    lhs = "<C-v>",
    mode = "n",
    desc = "Open task terminal in a vsplit",
    plug = "<Plug>OverseerTask:OpenVsplit",
    rhs = function(sidebar)
      sidebar:run_action("open vsplit")
    end,
  },
  {
    lhs = "<C-f>",
    mode = "n",
    desc = "Open task terminal in a floating window",
    plug = "<Plug>OverseerTask:OpenFloat",
    rhs = function(sidebar)
      sidebar:run_action("open float")
    end,
  },
  {
    lhs = "p",
    mode = "n",
    desc = "Toggle task terminal in a preview window",
    plug = "<Plug>OverseerTask:TogglePreview",
    rhs = function(sidebar)
      sidebar:toggle_preview()
    end,
  },
  {
    lhs = "<C-l>",
    mode = "n",
    desc = "Increase task detail level",
    plug = "<Plug>OverseerTask:IncreaseDetail",
    rhs = function(sidebar)
      sidebar:change_task_detail(1)
    end,
  },
  {
    lhs = "<C-h>",
    mode = "n",
    desc = "Decrease task detail level",
    plug = "<Plug>OverseerTask:DecreaseDetail",
    rhs = function(sidebar)
      sidebar:change_task_detail(-1)
    end,
  },
  {
    lhs = "L",
    mode = "n",
    desc = "Increase all task detail levels",
    plug = "<Plug>OverseerTask:IncreaseAllDetail",
    rhs = function(sidebar)
      sidebar:change_default_detail(1)
    end,
  },
  {
    lhs = "H",
    mode = "n",
    desc = "Decrease all task detail levels",
    plug = "<Plug>OverseerTask:DecreaseAllDetail",
    rhs = function(sidebar)
      sidebar:change_default_detail(-1)
    end,
  },
  {
    lhs = "[",
    mode = "n",
    desc = "Decrease window width",
    plug = "<Plug>OverseerTask:DecreaseWidth",
    rhs = function()
      local width = vim.api.nvim_win_get_width(0)
      vim.api.nvim_win_set_width(0, math.max(10, width - 10))
    end,
  },
  {
    lhs = "]",
    mode = "n",
    desc = "Increase window width",
    plug = "<Plug>OverseerTask:IncreaseWidth",
    rhs = function()
      local width = vim.api.nvim_win_get_width(0)
      vim.api.nvim_win_set_width(0, math.max(10, width + 10))
    end,
  },
  {
    lhs = "{",
    mode = { "n", "v" },
    desc = "Jump to previous task",
    plug = "<Plug>OverseerTask:PrevTask",
    rhs = function(sidebar)
      sidebar:jump(-1)
    end,
  },
  {
    lhs = "}",
    mode = { "n", "v" },
    desc = "Jump to next task",
    plug = "<Plug>OverseerTask:NextTask",
    rhs = function(sidebar)
      sidebar:jump(1)
    end,
  },
}
return M
