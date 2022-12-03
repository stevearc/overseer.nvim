# Third-party integrations

<!-- TOC -->

- [Lualine](#lualine)
- [Neotest](#neotest)
- [DAP](#dap)
- [Session managers](#session-managers)
  - [resession.nvim](#resessionnvim)
  - [Other session managers](#other-session-managers)

<!-- /TOC -->

## Lualine

There is a drop-in lualine component available. Use like:

```lua
require("lualine").setup({
  sections = {
    lualine_x = { "overseer" },
  },
})
```

Or with options:

```lua
require("lualine").setup({
  sections = {
    lualine_x = { {
      "overseer",
      label = '',     -- Prefix for task counts
      colored = true, -- Color the task icons and counts
      symbols = {
        [overseer.STATUS.FAILURE] = "F:",
        [overseer.STATUS.CANCELED] = "C:",
        [overseer.STATUS.SUCCESS] = "S:",
        [overseer.STATUS.RUNNING] = "R:",
      },
      unique = false,     -- Unique-ify non-running task count by name
      name = nil,         -- List of task names to search for
      name_not = false,   -- When true, invert the name search
      status = nil,       -- List of task statuses to display
      status_not = false, -- When true, invert the status search
    } },
  },
})
```

## Neotest

To run all neotest processes using overseer, add it as a custom consumer:

```lua
require('neotest').setup({
  consumers = {
    overseer = require("neotest.consumers.overseer"),
  },
})
```

This will automatically hook `neotest.run` and force it to use overseer to run tests wherever possible. If you would instead like to only use the overseer consumer explicitly, you can disable the monkey patching:

```lua
require('neotest').setup({
  consumers = {
    overseer = require("neotest.consumers.overseer"),
  },
  overseer = {
    enabled = true,
    -- When this is true (the default), it will replace all neotest.run.* commands
    force_default = false,
  },
})

-- Now neotest.run is unchanged; to run tests with overseer use:
neotest.overseer.run({})
```

You can customize the default components of neotest tasks by setting the `default_neotest` component alias (when unset it maps to `default`).

```lua
require('overseer').setup({
  component_aliases = {
    default_neotest = {
      "on_output_summarize",
      "on_exit_set_status",
      "on_complete_notify",
      "on_complete_dispose",
    },
  }
})
```

## DAP

If you have both overseer and [nvim-dap](https://github.com/mfussenegger/nvim-dap) installed, overseer will automatically run the `preLaunchTask` and `postDebugTask` when present in a debug configuration.

## ToggleTerm

If you use [toggleterm](https://github.com/akinsho/toggleterm.nvim), you can use the built-in "toggleterm" strategy to allow your tasks to be in a terminal buffer owned by toggleterm. You can use your existing toggleterm keybinds to pull up long-running tasks started with overseer. You can set it up with defaults using:

```lua
require('overseer').setup({
  strategy = "toggleterm",
})
```

You can also configure the behavior a bit more:

```lua
require('overseer').setup({
  strategy = {
    "toggleterm",
    -- load your default shell before starting the task
    use_shell = false,
    -- overwrite the default toggleterm "direction" parameter
    direction = nil,
    -- overwrite the default toggleterm "dir" parameter
    dir = nil,
    -- overwrite the default toggleterm "highlights" parameter
    highlights = nil,
    -- overwrite the default toggleterm "auto_scroll" parameter
    auto_scroll = nil,
    -- have the toggleterm window close automatically after the task exits
    close_on_exit = false,
    -- open the toggleterm window when a task starts
    open_on_start = true,
    -- mirrors the toggleterm "hidden" parameter, and keeps the task from
    -- being rendered in the toggleable window
    hidden = false,
  }
})
```

## Session managers

### resession.nvim

Overseer has built-in support for [resession.nvim](https://github.com/stevearc/resession.nvim).

```lua
require('resession').setup({
  extensions = {
    overseer = {
      -- customize here
    }
  }
})
```

The configuration options will be passed to [list_tasks](reference.md#list_tasksopts), and determine which tasks will be saved when saving a session.

### Other session managers

For other session managers, task bundles should make it convenient to load/save tasks. These are exposed to the user with the commands `:OverseerSaveBundle` and `:OverseerLoadBundle`, but you can use the lua API directly for a nicer integration. You essentially just need to get the session name and add some hooks using your plugin's API to handle overseer tasks on session save/restore.

For example, to integrate with [auto-session](https://github.com/rmagatti/auto-session)

```lua
-- Convert the cwd to a simple file name
local function get_cwd_as_name()
  local dir = vim.fn.getcwd(0)
  return dir:gsub("[^A-Za-z0-9]", "_")
end
local overseer = require("overseer")
require("auto-session").setup({
  pre_save_cmds = {
    function()
      overseer.save_task_bundle(
        get_cwd_as_name(),
        -- Passing nil will use config.opts.save_task_opts. You can call list_tasks() explicitly and
        -- pass in the results if you want to save specific tasks.
        nil,
        { on_conflict = "overwrite" } -- Overwrite existing bundle, if any
      )
    end,
  },
  post_restore_cmds = {
    function()
      overseer.load_task_bundle(get_cwd_as_name(), { ignore_missing = true })
    end,
  },
})
```
