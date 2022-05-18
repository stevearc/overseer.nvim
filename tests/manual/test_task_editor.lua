local overseer = require("overseer")

local task = overseer.new_task({
  cmd = { "echo", "hello", "world" },
})

overseer.task_editor.open(task)
