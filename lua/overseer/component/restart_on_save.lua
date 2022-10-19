local files = require("overseer.files")

return {
  desc = "Restart on any buffer :write",
  params = {
    path = {
      desc = "DEPRECATED: use 'paths' instead",
      optional = true,
      validate = function(v)
        return files.exists(v)
      end,
    },
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
    dir = {
      name = "directory",
      desc = "DEPRECATED: use 'path' instead",
      optional = true,
      validate = function(v)
        return files.exists(v)
      end,
    },
    delay = {
      desc = "How long to wait (in ms) post-result before triggering restart",
      type = "number",
      default = 500,
      validate = function(v)
        return v > 0
      end,
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
      path = { opts.path, "s", true },
    })
    if opts.dir then
      vim.notify_once(
        "Overseer[restart_on_save]: dir param is deprecated. Use 'path'",
        vim.log.levels.WARN
      )
      opts.paths = { opts.dir }
    end
    if opts.path then
      vim.notify_once(
        "Overseer[restart_on_save]: path param is deprecated. Use 'paths'",
        vim.log.levels.WARN
      )
      opts.paths = { opts.path }
    end

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

    return {
      id = nil,
      restart_after_complete = false,
      on_init = function(self, task)
        -- This means that the task cannot be auto-disposed while this component
        -- is attached
        task:inc_reference()
        self.id = vim.api.nvim_create_autocmd("BufWritePost", {
          pattern = "*",
          desc = string.format("Restart task %s on save", task.name),
          callback = function(params)
            -- Only care about normal files
            if vim.api.nvim_buf_get_option(params.buf, "buftype") == "" then
              local bufname = vim.api.nvim_buf_get_name(params.buf)
              if is_watching_file(bufname) then
                if not task:restart(opts.interrupt) then
                  self.restart_after_complete = true
                end
              end
            end
          end,
        })
      end,
      on_reset = function(self, task)
        self.restart_after_complete = false
      end,
      on_complete = function(self, task, status)
        if self.restart_after_complete then
          vim.schedule(function()
            task:restart(opts.interrupt)
          end)
        end
      end,
      on_dispose = function(self, task)
        task:dec_reference()
        vim.api.nvim_del_autocmd(self.id)
        self.id = nil
      end,
    }
  end,
}
