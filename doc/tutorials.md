# Tutorials

Guided introduction to working with overseer.nvim

If you're simply looking for the easiest way to define custom tasks, overseer supports [most of VS Code's `tasks.json`](guides.md#vs-code-tasks) format. There are tons of resources online for that, just search!

<!-- TOC -->

- [Build a C++ file](#build-a-c-file)
- [Run a file on save](#run-a-file-on-save)

<!-- /TOC -->

## Build a C++ file

In this tutorial, you will create a custom task that builds a C++ file.

First, change your call to `setup()` to include the following option:

```lua
require("overseer").setup({
  templates = { "builtin", "user.cpp_build" },
})
```

Next, create the file `lua/overseer/template/user/cpp_build.lua` inside your neovim config directory (`:echo stdpath('config')`). Add the following content:

```lua
-- /home/stevearc/.config/nvim/lua/overseer/template/user/cpp_build.lua
return {
  name = "g++ build",
  builder = function()
    -- Full path to current file (see :help expand())
    local file = vim.fn.expand("%:p")
    return {
      cmd = { "g++" },
      args = { file },
      components = { { "on_output_quickfix", open = true }, "default" },
    }
  end,
  condition = {
    filetype = { "cpp" },
  },
}
```

Now when you are editing a cpp file, you can run `:OverseerRun` and select "g++ build". This will build your file and, if there are errors, display the output in quickfix.

![Screenshot from 2022-09-04 13-50-01](https://user-images.githubusercontent.com/506791/188332938-4c8d84b0-d69e-4299-9202-0a857fd833ab.png)

## Run a file on save

In this tutorial, you will create a task that re-runs a script every time it's saved, and view the output in a split. If there are errors, they will be displayed inline.

First, change your call to `setup()` to include the following option:

```lua
require("overseer").setup({
  templates = { "builtin", "user.run_script" },
})
```

Next, create the file `lua/overseer/template/user/run_script.lua` inside your neovim config directory (`:echo stdpath('config')`). Add the following content:

```lua
-- /home/stevearc/.config/nvim/lua/overseer/template/user/run_script.lua
return {
  name = "run script",
  builder = function()
    local file = vim.fn.expand("%:p")
    local cmd = { file }
    if vim.bo.filetype == "go" then
      cmd = { "go", "run", file }
    end
    return {
      cmd = cmd,
      components = {
        { "on_output_quickfix", set_diagnostics = true },
        "on_result_diagnostics",
        "default",
      },
    }
  end,
  condition = {
    filetype = { "sh", "python", "go" },
  },
}
```

Now open up a shell script or go file and run `:OverseerRun`. Select "run script".

If you want a test file to use, try the following go script:

```go
// test.go
package main

import "fmt"

func main() {
	fmt.Println("Hello world")
}
```

or a bash file:

```bash
#!/bin/bash
set -e

echo "Hello world"
```

The next step is to display the output in a vertical split. For that, we are going to use [actions](guides.md#actions). Run `:OverseerQuickAction` and select "open vsplit". This will open the output in a vertical split next to your file.

![Screenshot from 2022-09-04 12-40-04](https://user-images.githubusercontent.com/506791/188330767-d680d200-0938-48d1-86ab-8e993745551d.png)

Try changing your script to have an error, then restart the task. The output should be updated, and you should see inline diagnostics for the error (see `:help vim.diagnostic`).

![Screenshot from 2022-09-04 12-41-51](https://user-images.githubusercontent.com/506791/188330827-d54af448-aedb-4652-a5f2-8d3d94e1cb31.png)

Lastly, we would like to restart this task every time we save the file. Once more use `:OverseerQuickAction` and this time select "watch". It will prompt you for a path to watch, you should enter the path to the file. Now every time you `:w` the file it should re-run and update the output!

Finally, you can create a custom command to do all of these steps at once:

```lua
vim.api.nvim_create_user_command("WatchRun", function()
  local overseer = require("overseer")
  overseer.run_template({ name = "run script" }, function(task)
    if task then
      task:add_component({ "restart_on_save", paths = {vim.fn.expand("%:p")} })
      local main_win = vim.api.nvim_get_current_win()
      overseer.run_action(task, "open vsplit")
      vim.api.nvim_set_current_win(main_win)
    else
      vim.notify("WatchRun not supported for filetype " .. vim.bo.filetype, vim.log.levels.ERROR)
    end
  end)
end, {})
```

Now you can do `:WatchRun` on any supported file and it will run the file, open the output in a split, and re-run on save.

Final note: to stop watching the file use the "dispose" action from `:OverseerQuickAction`.
