return {
  desc = "Call a callback when task completes",
  params = {
    callback = {
      desc = "Callback that will be called when task completes",
      type = "opaque",
    },
  },
  serialize = "exclude",
  constructor = function(params)
    return {
      on_complete = function(self, task, status)
        params.callback(task, status)
      end,
    }
  end,
}
