local files = require("overseer.files")
local Notifier = { focused = true }

---@class overseer.NotifierParams
---@field desktop "always"|"never"|"unfocused"

---@param opts? overseer.NotifierParams
function Notifier.new(opts)
  opts = vim.tbl_deep_extend("keep", opts or {}, {
    desktop = "never",
  })

  return setmetatable(opts, { __index = Notifier })
end

local function desktop_notify(message, level)
  if files.is_windows then
    -- TODO
  elseif files.is_mac then
    vim.fn.jobstart({
      "reattach-to-user-namespace",
      "osascript",
      "-e",
      string.format('display notification "%s" with title "%s"', "Overseer task complete", message),
    }, {
      stdin = "null",
    })
  else
    local urgency = level == vim.log.levels.INFO and "normal" or "critical"
    vim.fn.jobstart({
      "notify-send",
      "-u",
      urgency,
      "Overseer task complete",
      message,
    }, {
      stdin = "null",
    })
  end
end

---@param message string
---@param level string
function Notifier:notify(message, level)
  vim.notify(message, level)
  if self.desktop == "always" or (self.desktop == "unfocused" and not self.focused) then
    desktop_notify(message, level)
  end
end

return Notifier
