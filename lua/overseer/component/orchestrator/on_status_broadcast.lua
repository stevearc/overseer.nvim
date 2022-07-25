return {
  desc = "Broadcast this task when the status changes",
  -- We don't allow customization of event name or params now because it's not
  -- needed. If another need arises, we can add it then.
  params = {},
  -- Don't allow serializing/saving child tasks. The orchestrator task will recreate them if needed.
  serialize = "fail",
  constructor = function()
    return {
      on_status = function(self, task, status)
        task:broadcast("on_other_task_status", task)
      end,
    }
  end,
}
