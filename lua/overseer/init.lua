local config = require("overseer.config")
local Task = require("overseer.task")
local window = require("overseer.window")
local M = {}

-- TODO
-- * View task output
--
-- WISHLIST
-- * Run a test (file/suite/line) and notify. Can inspect all output.
-- * Run a test (file/suite/line) every time you save a file (debounce).
-- * :make every time you save a file (debounce).
-- * Save task templates somehow
-- * Load VSCode task definitions
-- * Store recent commands in history per-directory
--   * Can select & run task from recent history
-- * Add tests
-- * add names & debugging helpers for capabilities

-- Extract pass/fail
-- Capture stdout/stderr
-- Processors for stdout/stderr
-- Callback when complete
-- Can be re-invoked once complete (doing so while running will queue the re-invoke)

M.setup = function(opts)
  config.setup(opts)
end

M.new_task = function(opts)
  return Task.new(opts)
end

M.toggle = window.toggle
M.open = window.open
M.close = window.close

setmetatable(M, {
  __index = function(_, key)
    local ok, val = pcall(require, string.format("overseer.%s", key))
    if ok then
      return val
    else
      error(val)
    end
  end,
})

return M
