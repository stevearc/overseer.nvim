local neotest = require("neotest")

return {
  desc = "Link task to neotest runs",
  params = {},
  editable = false,
  constructor = function(params)
    local has_reset = false
    return {
      on_pre_start = function(self, task)
        if has_reset then
          vim.schedule(function()
            neotest.overseer.rerun_task_group(task.metadata.neotest_group_id)
          end)
          return false
        end
      end,
      on_reset = function(self, task)
        has_reset = true
      end,
    }
  end,
}
