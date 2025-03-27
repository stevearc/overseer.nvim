local overseer = require("overseer")

local task = overseer.new_task({
  name = "Go to space",
  strategy = {
    "orchestrator",
    tasks = {
      {
        name = "Assemble rocket",
        cmd = "echo mining ore && sleep 2 && echo bribing gremlins && sleep 2 && echo assembled!",
      },
      {
        { name = "Fuel rocket", cmd = "echo fueling && sleep 2 && echo tanked up!" },
        {
          name = "Preflight checklist",
          cmd = "echo checking nose cone && sleep 1 && echo checking fins && sleep 1 && echo checking heat shield && sleep 1 && echo checking payload && sleep 1 && echo checklist passed!",
        },
      },
      { name = "Launch", cmd = [[echo FWOOOOSH && sleep 2 && echo "we're in space"]] },
    },
  },
})
task:start()
overseer.run_action(task, "open float")
