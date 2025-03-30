local overseer = require("overseer")

local task = overseer.new_task({
  cmd = { "echo", "hello", "world" },
})

require("overseer.task_editor").open(task)
