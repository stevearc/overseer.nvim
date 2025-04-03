local binding_util = require("overseer.binding_util")
local M
M = {
  {
    desc = "Show default key bindings",
    plug = "<Plug>OverseerTask:ShowHelp",
    rhs = function()
      binding_util.show_bindings("OverseerTask:")
    end,
  },
  {
    desc = "Open task action menu",
    plug = "<Plug>OverseerTask:RunAction",
    rhs = function(sidebar)
      sidebar:run_action()
    end,
  },
  {
    desc = "Edit task",
    plug = "<Plug>OverseerTask:Edit",
    rhs = function(sidebar)
      sidebar:run_action("edit")
    end,
  },
  {
    desc = "Open task terminal in current window",
    plug = "<Plug>OverseerTask:Open",
    rhs = function(sidebar)
      sidebar:run_action("open")
    end,
  },
  {
    desc = "Open task terminal in a split",
    plug = "<Plug>OverseerTask:OpenSplit",
    rhs = function(sidebar)
      sidebar:run_action("open hsplit")
    end,
  },
  {
    desc = "Open task terminal in a vsplit",
    plug = "<Plug>OverseerTask:OpenVsplit",
    rhs = function(sidebar)
      sidebar:run_action("open vsplit")
    end,
  },
  {
    desc = "Open task terminal in a floating window",
    plug = "<Plug>OverseerTask:OpenFloat",
    rhs = function(sidebar)
      sidebar:run_action("open float")
    end,
  },
  {
    desc = "Open task output in a quickfix window",
    plug = "<Plug>OverseerTask:OpenQuickFix",
    rhs = function(sidebar)
      sidebar:run_action("open output in quickfix")
    end,
  },
  {
    desc = "Toggle task terminal in a preview window",
    plug = "<Plug>OverseerTask:TogglePreview",
    rhs = function(sidebar)
      sidebar:toggle_preview()
    end,
  },
  {
    desc = "Decrease window width",
    plug = "<Plug>OverseerTask:DecreaseWidth",
    rhs = function()
      local width = vim.api.nvim_win_get_width(0)
      vim.api.nvim_win_set_width(0, math.max(10, width - 10))
    end,
  },
  {
    desc = "Increase window width",
    plug = "<Plug>OverseerTask:IncreaseWidth",
    rhs = function()
      local width = vim.api.nvim_win_get_width(0)
      vim.api.nvim_win_set_width(0, math.max(10, width + 10))
    end,
  },
  {
    desc = "Jump to previous task",
    plug = "<Plug>OverseerTask:PrevTask",
    rhs = function(sidebar)
      sidebar:jump(-1)
    end,
  },
  {
    desc = "Jump to next task",
    plug = "<Plug>OverseerTask:NextTask",
    rhs = function(sidebar)
      sidebar:jump(1)
    end,
  },
  {
    desc = "Scroll up in the task output window",
    plug = "<Plug>OverseerTask:ScrollOutputUp",
    rhs = function(sidebar)
      sidebar:scroll_output(-1)
    end,
  },
  {
    desc = "Scroll down in the task output window",
    plug = "<Plug>OverseerTask:ScrollOutputDown",
    rhs = function(sidebar)
      sidebar:scroll_output(1)
    end,
  },
  {
    desc = "Close window",
    plug = "<Plug>OverseerTask:Close",
    rhs = function()
      vim.cmd("close")
    end,
  },
  {
    desc = "Dispose task",
    plug = "<Plug>OverseerTask:Dispose",
    rhs = function(sidebar)
      sidebar:run_action("dispose")
    end,
  },
  {
    desc = "Stop task",
    plug = "<Plug>OverseerTask:Stop",
    rhs = function(sidebar)
      sidebar:run_action("stop")
    end,
  },
}
return M
