local overseer = require("overseer")

local task = overseer.new_task({
  name = "Compound task",
  strategy = {
    "orchestrator",
    tasks = {
      { "shell", cmd = "sleep 4" },
      {
        { "shell", cmd = "sleep 2" },
        { "shell", cmd = "sleep 5" },
      },
      { "shell", cmd = "ls -l" },
    },
  },
})
task:start()
overseer.run_action(task, "open float")
