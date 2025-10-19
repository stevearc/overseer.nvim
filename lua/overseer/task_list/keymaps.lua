local M = {}

---@return overseer.Sidebar
local function get_sidebar()
  return assert(require("overseer.task_list.sidebar").get())
end

M.show_help = {
  desc = "Show default keymaps",
  callback = function()
    local config = require("overseer.config")
    require("overseer.keymap_util").show_help(config.task_list.keymaps)
  end,
}

M.run_action = {
  desc = "Run an action on the current task",
  callback = function(opts)
    opts = opts or {}
    local sb = get_sidebar()
    sb:run_action(opts.action)
  end,
  parameters = {
    action = {
      type = "string",
      desc = "Run an action on the current task",
    },
  },
}

M.open = {
  desc = "Open task output",
  callback = function(opts)
    opts = opts or {}
    local sb = get_sidebar()
    if opts.dir == "split" then
      sb:run_action("open hsplit")
    elseif opts.dir == "vsplit" then
      sb:run_action("open vsplit")
    elseif opts.dir == "tab" then
      sb:run_action("open tab")
    elseif opts.dir == "float" then
      sb:run_action("open float")
    else
      sb:run_action("open")
    end
  end,
  parameters = {
    dir = {
      type = '"split"|"vsplit"|"tab"|"float"',
      desc = "type of window to open the task output in",
    },
  },
}

M.prev_task = {
  desc = "Jump to previous task",
  callback = function()
    local sb = get_sidebar()
    sb:jump(-1)
  end,
}

M.next_task = {
  desc = "Jump to next task",
  callback = function()
    local sb = get_sidebar()
    sb:jump(1)
  end,
}

M.scroll_output_up = {
  desc = "Scroll up in the task output window",
  callback = function()
    local sb = get_sidebar()
    sb:scroll_output(-1)
  end,
}

M.scroll_output_down = {
  desc = "Scroll down in the task output window",
  callback = function()
    local sb = get_sidebar()
    sb:scroll_output(1)
  end,
}

M.toggle_preview = {
  desc = "Toggle task output in a preview floating window",
  callback = function()
    local sb = get_sidebar()
    sb:toggle_preview()
  end,
}

M.toggle_show_wrapped = {
  desc = "Toggle showing wrapped builtin jobstart/vim.system tasks",
  callback = function()
    local sb = get_sidebar()
    sb:toggle_show_wrapped()
  end,
}

---List keymaps for documentation generation
---@private
M._get_keymaps = function()
  local ret = {}
  for name, keymap in pairs(M) do
    if type(keymap) == "table" and keymap.desc then
      table.insert(ret, {
        name = name,
        desc = keymap.desc,
        deprecated = keymap.deprecated,
        parameters = keymap.parameters,
      })
    end
  end
  return ret
end

return M
