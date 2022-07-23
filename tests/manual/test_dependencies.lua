local overseer = require("overseer")

overseer.run_template(
  { name = "shell", autostart = false, params = { cmd = "ls -l" } },
  function(task)
    if task then
      task:add_component({
        "dependencies",
        task_names = { { "shell", cmd = "sleep 5" } },
      })
      task:start()
    end
  end
)
