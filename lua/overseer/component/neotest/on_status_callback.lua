return {
  description = "Call a callback when complete",
  editable = false,
  serialize = "fail",
  params = {
    callback = { type = "opaque" },
  },
  constructor = function(params)
    return {
      on_result = function(self, task, status)
        if task:is_complete() then
          params.callback(status)
        end
      end,
    }
  end,
}
