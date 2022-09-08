# Recipes

Have a cool recipe to share? Open a pull request and add it to this doc!

<!-- TOC -->

- [Restart last task](#restart-last-task)

<!-- /TOC -->

## Restart last task

This command restarts the most recent overseer task

```lua
vim.api.nvim_create_user_command("OverseerRestartLast", function()
  local overseer = require("overseer")
  local tasks = overseer.list_tasks({ recent_first = true })
  if vim.tbl_isempty(tasks) then
    vim.notify("No tasks found", vim.log.levels.WARN)
  else
    overseer.run_action(tasks[1], "restart")
  end
end, {})
```
