local files = require("overseer.files")
local log = require("overseer.log")
local Notifier = { focused = true }

---@class overseer.NotifierParams
---@field system "always"|"never"|"unfocused"

---@param opts? overseer.NotifierParams
function Notifier.new(opts)
  opts = vim.tbl_deep_extend("keep", opts or {}, {
    system = "never",
  })

  return setmetatable(opts, { __index = Notifier })
end

local function system_notify(message, level)
  local job_id
  if files.is_windows then
    -- TODO
    log:warn("System notifications are not supported on Windows yet")
    return
  elseif files.is_mac then
    job_id = vim.fn.jobstart({
      "reattach-to-user-namespace",
      "osascript",
      "-e",
      string.format('display notification "%s" with title "%s"', "Overseer task complete", message),
    }, {
      stdin = "null",
    })
  else
    local urgency = level == vim.log.levels.INFO and "normal" or "critical"
    job_id = vim.fn.jobstart({
      "notify-send",
      "-u",
      urgency,
      "Overseer task complete",
      message,
    }, {
      stdin = "null",
    })
  end
  if job_id <= 0 then
    log:warn("Error performing system notification")
  end
end

---@param message string
---@param level string
function Notifier:notify(message, level)
  vim.notify(message, level)
  if self.system == "always" or (self.system == "unfocused" and not self.focused) then
    system_notify(message, level)
  end
end

return Notifier
