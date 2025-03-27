local overseer = require("overseer")

local task = overseer.new_task({
  cmd = "ls -l",
  components = {
    "default",
    {
      "dependencies",
      tasks = { { cmd = "sleep 5" } },
    },
  },
})

task:start()
