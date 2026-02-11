local files = require("overseer.files")
local log = require("overseer.log")
local overseer = require("overseer")

---@class overseer.Notifier
---@field private system "always"|"never"|"unfocused"
---@field private system_notify? fun(message: string, level: integer): boolean?
local Notifier = { focused = true }

---@class overseer.NotifierParams
---@field system "always"|"never"|"unfocused"
---@field system_notify? fun(message: string, level: integer): boolean? Custom function for system notifications. Return `false` to fall back to built-in system notifier.

local initialized = false
local function create_autocmds()
  if initialized then
    return
  end
  initialized = true
  local aug = vim.api.nvim_create_augroup("Overseer", { clear = false })
  vim.api.nvim_create_autocmd("FocusGained", {
    desc = "Track editor focus for overseer",
    group = aug,
    callback = function()
      Notifier.focused = true
    end,
  })
  vim.api.nvim_create_autocmd("FocusLost", {
    desc = "Track editor focus for overseer",
    group = aug,
    callback = function()
      Notifier.focused = false
    end,
  })
end

---@param opts? overseer.NotifierParams
function Notifier.new(opts)
  create_autocmds()
  opts = opts or {}

  ---@type overseer.Notifier
  return setmetatable({
    system = opts.system or "never",
    system_notify = opts.system_notify,
  }, { __index = Notifier })
end

local function system_notify(message, level)
  if files.is_windows then
    -- TODO
    log.warn("System notifications are not supported on Windows yet")
    return
  elseif files.is_mac then
    local cmd = {
      "osascript",
      "-e",
      string.format('display notification "Overseer task complete" with title "%s"', message),
    }
    if vim.fn.executable("reattach-to-user-namespace") == 1 then
      table.insert(cmd, 1, "reattach-to-user-namespace")
    end
    overseer.builtin.system(cmd, {})
  else
    local urgency = level == vim.log.levels.INFO and "normal" or "critical"
    overseer.builtin.system({
      "notify-send",
      "-u",
      urgency,
      "Overseer task complete",
      message,
    }, {})
  end
end

---@param message string
---@param level integer
function Notifier:notify(message, level)
  vim.notify(message, level)
  if self.system == "always" or (self.system == "unfocused" and not self.focused) then
    if not self.system_notify or self.system_notify(message, level) == false then
      system_notify(message, level)
    end
  end
end

return Notifier
