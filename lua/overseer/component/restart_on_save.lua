local files = require("overseer.files")
local log = require("overseer.log")

return {
  desc = "Restart on any buffer :write",
  params = {
    paths = {
      desc = "Only restart when writing files in these paths (can be directory or file)",
      type = "list",
      optional = true,
      subtype = {
        validate = function(v)
          return files.exists(v)
        end,
      },
    },
    delay = {
      desc = "How long to wait (in ms) before triggering restart",
      type = "number",
      default = 500,
      validate = function(v)
        return v > 0
      end,
    },
    mode = {
      desc = "How to watch the paths",
      type = "enum",
      choices = { "autocmd", "uv" },
      default = "autocmd",
      long_desc = "'autocmd' will set autocmds on BufWritePost. 'uv' will use a libuv file watcher (recursive watching may not be supported on all platforms).",
    },
    interrupt = {
      desc = "Interrupt running tasks",
      type = "boolean",
      default = true,
    },
  },
  constructor = function(opts)
    vim.validate({
      delay = { opts.delay, "n" },
    })

    local function is_watching_file(path)
      if not opts.paths then
        return true
      end
      for _, watch_path in ipairs(opts.paths) do
        if files.is_subpath(watch_path, path) then
          return true
        end
      end
      return false
    end

    local restart_after_complete = false
    local restarting = false
    local version = 1
    local function trigger_restart(task)
      local trigger_version = version
      if not restarting then
        restarting = true
        vim.defer_fn(function()
          restarting = false
          -- Only perform the restart if the version hasn't been bumped
          if version == trigger_version then
            if not task:restart(opts.interrupt) then
              -- If we couldn't restart the task, it's because it is currently running and we won't
              -- interrupt it. Flag to restart once task is complete.
              restart_after_complete = true
            end
          end
        end, opts.delay)
      end
    end

    return {
      autocmd_id = nil,
      fs_events = {},
      on_init = function(self, task)
        -- This means that the task cannot be auto-disposed while this component
        -- is attached
        task:inc_reference()
        if opts.mode == "autocmd" then
          self.autocmd_id = vim.api.nvim_create_autocmd("BufWritePost", {
            pattern = "*",
            desc = string.format("Restart task %s on save", task.name),
            callback = function(params)
              -- Only care about normal files
              if vim.bo[params.buf].buftype == "" then
                local bufname = vim.api.nvim_buf_get_name(params.buf)
                if is_watching_file(bufname) then
                  trigger_restart(task)
                end
              end
            end,
          })
        elseif opts.mode == "uv" then
          for _, path in ipairs(opts.paths) do
            local fs_event = vim.loop.new_fs_event()
            fs_event:start(
              path,
              { recursive = true },
              vim.schedule_wrap(function(err, filename, events)
                if err then
                  log:warn("Overseer[restart_on_save] watch error: %s", err)
                else
                  trigger_restart(task)
                end
              end)
            )
            table.insert(self.fs_events, fs_event)
          end
        end
      end,
      on_reset = function(self, task)
        -- Bump the version to invalidate any pending restarts
        version = version + 1
        restarting = false
        restart_after_complete = false
      end,
      on_complete = function(self, task, status)
        if restart_after_complete then
          trigger_restart(task)
        end
      end,
      on_dispose = function(self, task)
        -- Bump the version to invalidate any pending restarts
        version = version + 1
        task:dec_reference()
        if self.autocmd_id then
          vim.api.nvim_del_autocmd(self.autocmd_id)
          self.autocmd_id = nil
        end
        for _, fs_event in ipairs(self.fs_events) do
          fs_event:stop()
        end
        self.fs_events = {}
      end,
    }
  end,
}
