return {
  desc = "Call a callback when task completes",
  params = {
    on_complete = {
      desc = "Callback that will be called when task completes",
      type = "opaque",
      optional = true,
    },
    on_result = {
      desc = "Callback that will be called when task gets results",
      type = "opaque",
      optional = true,
    },
  },
  serialize = "exclude",
  constructor = function(params)
    return {
      on_complete = function(self, task, status)
        if params.on_complete then
          params.on_complete(task, status)
        end
      end,
      on_result = function(self, task, result)
        if params.on_result then
          params.on_result(task, result)
        end
      end,
    }
  end,
}
