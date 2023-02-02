# Recipes

Have a cool recipe to share? Open a pull request and add it to this doc!

<!-- TOC -->

- [Restart last task](#restart-last-task)
- [Run shell scripts in the current directory](#run-shell-scripts-in-the-current-directory)
- [Directory-local tasks with nvim-config-local](#directory-local-tasks-with-nvim-config-local)
- [:Make similar to vim-dispatch](#make-similar-to-vim-dispatch)
- [Asynchronous :Grep command](#asynchronous-grep-command)

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

## Run shell scripts in the current directory

This template will find all shell scripts in the current directory and create tasks for them

```lua
local files = require("overseer.files")

return {
  generator = function(opts, cb)
    local scripts = vim.tbl_filter(function(filename)
      return filename:match("%.sh$")
    end, files.list_files(opts.dir))
    local ret = {}
    for _, filename in ipairs(scripts) do
      table.insert(ret, {
        name = filename,
        params = {
          args = { optional = true, type = "list", delimiter = " " },
        },
        builder = function(params)
          return {
            cmd = { files.join(opts.dir, filename) },
            args = params.args,
          }
        end,
      })
    end

    cb(ret)
  end,
}
```

## Directory-local tasks with nvim-config-local

If you have [nvim-config-local](https://github.com/klen/nvim-config-local) installed, you can add directory-local tasks like so:

```lua
-- /path/to/dir/.vimrc.lua

require("overseer").register_template({
  name = "My project task",
  params = {},
  condition = {
    -- This makes the template only available in the current directory
    dir = vim.fn.getcwd(),
  },
  builder = function()
    return {
      cmd = {"echo"},
      args = {"Hello", "world"},
    }
  end,
})
```

## :Make similar to vim-dispatch

The venerable vim-dispatch provides several commands, but the main `:Make` command can be mimicked fairly easily:

```lua
vim.api.nvim_create_user_command("Make", function(params)
  local task = require("overseer").new_task({
    cmd = vim.split(vim.o.makeprg, "%s+"),
    args = params.fargs,
    components = {
      { "on_output_quickfix", open = not params.bang, open_height = 8 },
      "default",
    },
  })
  task:start()
end, {
  desc = "",
  nargs = "*",
  bang = true,
})
```

## Asynchronous :Grep command

We can run `:grep` asynchronously, similar to what we did with `:make` in the example above:

```lua
vim.api.nvim_create_user_command("Grep", function(params)
  local args = vim.fn.expandcmd(params.args)
  -- Insert args at the '$*' in the grepprg
  local cmd, num_subs = vim.o.grepprg:gsub("%$%*", args)
  if num_subs == 0 then
    cmd = cmd .. " " .. args
  end
  local task = overseer.new_task({
    cmd = cmd,
    name = "grep " .. args,
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
end, { nargs = "*", bang = true })
```
