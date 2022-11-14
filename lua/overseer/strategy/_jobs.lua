local log = require("overseer.log")

local M = {}

local cleanup_autocmd
local all_channels = {}

M.register = function(job_id)
  if not cleanup_autocmd then
    -- Neovim will send a SIGHUP to PTY processes on exit. Unfortunately, some programs handle
    -- SIGHUP (for a legitimate purpose) and do not terminate, which leaves orphaned processes after
    -- Neovim exits. To avoid this, we need to explicitly call jobstop(), which will send a SIGHUP,
    -- wait (controlled by KILL_TIMEOUT_MS in process.c, 2000ms at the time of writing), then send a
    -- SIGTERM (possibly also a SIGKILL if that is insufficient).
    cleanup_autocmd = vim.api.nvim_create_autocmd("VimLeavePre", {
      desc = "Clean up running overseer tasks on exit",
      callback = function()
        local job_ids = vim.tbl_keys(all_channels)
        log:debug("VimLeavePre clean up terminal tasks %s", job_ids)
        for _, chan_id in ipairs(job_ids) do
          vim.fn.jobstop(chan_id)
        end
        local start_wait = vim.loop.hrtime()
        -- This makes sure Neovim doesn't exit until it has successfully killed all child processes.
        vim.fn.jobwait(job_ids)
        local elapsed = (vim.loop.hrtime() - start_wait) / 1e6
        if elapsed > 1000 then
          log:warn(
            "Killing running tasks took %dms. One or more processes likely did not terminate on SIGHUP. See https://github.com/stevearc/overseer.nvim/issues/46",
            elapsed
          )
        end
      end,
    })
  end
  all_channels[job_id] = true
end

M.unregister = function(job_id)
  all_channels[job_id] = nil
end

return M
