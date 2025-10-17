# Recipes

Have a cool recipe to share? Open a pull request and add it to this doc!

<!-- TOC -->

- [Run a quick command like with `:!` or `:term`](#run-a-quick-command-like-with--or-term)
- [Restart last task](#restart-last-task)
- [Run shell scripts in the current directory](#run-shell-scripts-in-the-current-directory)
- [Directory-local tasks with exrc](#directory-local-tasks-with-exrc)
- [Asynchronous :Make similar to vim-dispatch](#asynchronous-make-similar-to-vim-dispatch)
- [Asynchronous :Grep command](#asynchronous-grep-command)
- [Create a window that displays the most recent task output](#create-a-window-that-displays-the-most-recent-task-output)

<!-- /TOC -->

## Run a quick command like with `:!` or `:term`

The `:OverseerShell` command allows you to run a shell command as an overseer task. It's a bit much to type, so we can create an abbreviation for that:

```lua
vim.cmd.cnoreabbrev("OS OverseerShell")
```

Now you can easily start a new task by simply typing `:OS <command to run>`

## Restart last task

This command restarts the most recent overseer task

```lua
vim.api.nvim_create_user_command("OverseerRestartLast", function()
  local overseer = require("overseer")
  local tasks = overseer.list_tasks({ status = {
    overseer.STATUS.SUCCESS,
    overseer.STATUS.FAILURE,
    overseer.STATUS.CANCELED,
  }})
  if vim.tbl_isempty(tasks) then
    vim.notify("No tasks found", vim.log.levels.WARN)
  else
    local most_recent = tasks[1]
    for _, task in ipairs(tasks) do
      if task.time_end > most_recent then
        most_recent = task
      end
    end
      overseer.run_action(most_recent, "restart")
  end
end, {})
```

## Run shell scripts in the current directory

This template will find all shell scripts in the current directory and create tasks for them

```lua
local files = require("overseer.files")

---@type overseer.TemplateFileProvider
return {
  generator = function(opts)
    local scripts = vim.tbl_filter(function(filename)
      return filename:match("%.sh$")
    end, files.list_files(opts.dir))
    local ret = {}
    for _, filename in ipairs(scripts) do
      table.insert(ret, {
        name = filename,
        builder = function(params)
          return {
            cmd = { vim.fs.joinpath(opts.dir, filename) },
          }
        end,
      })
    end

    return ret
  end,
}
```

## Directory-local tasks with exrc

You can add directory-local tasks by setting the exrc option (`vim.o.exrc = true`) and creating a file in the directory:

```lua
-- /path/to/dir/.nvim.lua
require("overseer").register_template({
  name = "My project task",
  condition = {
    -- This makes the template only available in the current directory
    -- In case you :cd out later
    dir = vim.fn.getcwd(),
  },
  builder = function()
    return {
      cmd = { "echo" },
      args = { "Hello", "world" },
    }
  end,
})
```

## Asynchronous :Make similar to vim-dispatch

The venerable vim-dispatch provides several commands, but the main `:Make` command can be mimicked fairly easily:

```lua
vim.api.nvim_create_user_command("Make", function(params)
  -- Insert args at the '$*' in the makeprg
  local cmd, num_subs = vim.o.makeprg:gsub("%$%*", params.args)
  if num_subs == 0 then
    cmd = cmd .. " " .. params.args
  end
  local task = require("overseer").new_task({
    cmd = vim.fn.expandcmd(cmd),
    components = {
      { "on_output_quickfix", open = not params.bang, open_height = 8 },
      "default",
    },
  })
  task:start()
end, {
  desc = "Run your makeprg as an Overseer task",
  nargs = "*",
  bang = true,
})
```

## Asynchronous :Grep command

We can run `:grep` asynchronously, similar to what we did with `:make` in the example above:

```lua
vim.api.nvim_create_user_command("Grep", function(params)
  -- Insert args at the '$*' in the grepprg
  local cmd, num_subs = vim.o.grepprg:gsub("%$%*", params.args)
  if num_subs == 0 then
    cmd = cmd .. " " .. params.args
  end
  local task = overseer.new_task({
    cmd = vim.fn.expandcmd(cmd),
    components = {
      {
        "on_output_quickfix",
        errorformat = vim.o.grepformat,
        open = not params.bang,
        open_height = 8,
        items_only = true,
      },
      -- We don't care to keep this around as long as most tasks
      { "on_complete_dispose", timeout = 30 },
      "default",
    },
  })
  task:start()
end, { nargs = "*", bang = true, complete = "file" })
```

## Create a window that displays the most recent task output

You can use `overseer.create_task_output_view` to create a dynamic view of task output based on any
criteria. This example will show the output of the most recently started task.

```lua
overseer.create_task_output_view(0, {
  list_task_opts = {
    filter = function(task)
      return task.time_start ~= nil
    end,
  }
  select = function(self, tasks, task_under_cursor)
    table.sort(tasks, function(a, b)
      return a.time_start > b.time_start
    end)
    return tasks[1]
  end,
})
```
