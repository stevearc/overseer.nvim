local files = require("overseer.files")

return {
  desc = "Rerun on any buffer :write",
  params = {
    dir = {
      name = "directory",
      desc = "Only rerun when writing files in this directory",
      optional = true,
      validate = function(v)
        return files.exists(v)
      end,
    },
    delay = {
      desc = "How long to wait (in ms) post-result before triggering rerun",
      type = "number",
      default = 500,
      validate = function(v)
        return v > 0
      end,
    },
  },
  constructor = function(opts)
    vim.validate({
      delay = { opts.delay, "n" },
      dir = { opts.dir, "s", true },
    })

    return {
      id = nil,
      on_init = function(self, task)
        task:inc_reference()
        self.id = vim.api.nvim_create_autocmd("BufWritePost", {
          pattern = "*",
          desc = string.format("Rerun task %s on save", task.name),
          callback = function(params)
            -- Only care about normal files
            if vim.api.nvim_buf_get_option(params.buf, "buftype") == "" then
              local bufname = vim.api.nvim_buf_get_name(params.buf)
              if not opts.dir or files.is_subpath(opts.dir, bufname) then
                task:rerun()
              end
            end
          end,
        })
      end,
      on_dispose = function(self, task)
        task:dec_reference()
        vim.api.nvim_del_autocmd(self.id)
        self.id = nil
      end,
    }
  end,
}
