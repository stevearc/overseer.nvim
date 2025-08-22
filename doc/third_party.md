# Third-party integrations

<!-- TOC -->

- [Lualine](#lualine)
- [Heirline](#heirline)
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
    lualine_x = {
      {
        "overseer",
        label = "", -- Prefix for task counts
        colored = true, -- Color the task icons and counts
        symbols = {
          [overseer.STATUS.FAILURE] = "F:",
          [overseer.STATUS.CANCELED] = "C:",
          [overseer.STATUS.SUCCESS] = "S:",
          [overseer.STATUS.RUNNING] = "R:",
        },
        unique = false, -- Unique-ify non-running task count by name
        status = nil, -- List of task statuses to display
        filter = nil, -- Function to filter out tasks you don't wish to display
      },
    },
  },
})
```

## Heirline

Here is a recipe for using Overseer with heirline

```lua
local Spacer = { provider = " " }
local function rpad(child)
  return {
    condition = child.condition,
    child,
    Spacer,
  }
end
local function OverseerTasksForStatus(status)
  return {
    condition = function(self)
      return self.tasks[status]
    end,
    provider = function(self)
      return string.format("%s%d", self.symbols[status], #self.tasks[status])
    end,
    hl = function(self)
      return {
        fg = utils.get_highlight(string.format("Overseer%s", status)).fg,
      }
    end,
  }
end

local Overseer = {
  condition = function()
    return package.loaded.overseer
  end,
  init = function(self)
    local tasks = require("overseer.task_list").list_tasks({ unique = true, include_ephemeral = true })
    local tasks_by_status = require("overseer.util").tbl_group_by(tasks, "status")
    self.tasks = tasks_by_status
  end,
  static = {
    symbols = {
      ["CANCELED"] = " ",
      ["FAILURE"] = "󰅚 ",
      ["SUCCESS"] = "󰄴 ",
      ["RUNNING"] = "󰑮 ",
    },
  },

  rpad(OverseerTasksForStatus("CANCELED")),
  rpad(OverseerTasksForStatus("RUNNING")),
  rpad(OverseerTasksForStatus("SUCCESS")),
  rpad(OverseerTasksForStatus("FAILURE")),
}
```

## Neotest

To run all neotest processes using overseer, add it as a custom consumer:

```lua
require("neotest").setup({
  consumers = {
    overseer = require("neotest.consumers.overseer"),
  },
})
```

This will automatically hook `neotest.run` and force it to use overseer to run tests wherever possible. If you would instead like to only use the overseer consumer explicitly, you can disable the monkey patching:

```lua
require("neotest").setup({
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
require("overseer").setup({
  component_aliases = {
    default_neotest = {
      "on_exit_set_status",
      "on_complete_notify",
      "on_complete_dispose",
    },
  },
})
```

You can also customize the components by passing them in to the strategy spec for neotest. This can be a normal list of components, or a function that returns a list of components like so:

```lua
require("neotest").setup({
  strategies = {
    overseer = {
      components = function(run_spec)
        return {
          { "dependencies", tasks = {
            { cmd = "sleep 4" },
          } },
          "default_neotest",
        }
      end,
    },
  },
})
```

## DAP

If you have both overseer and [nvim-dap](https://github.com/mfussenegger/nvim-dap) installed, overseer will automatically run the `preLaunchTask` and `postDebugTask` when present in a debug configuration. No special configuration or action is needed.

For lazy-loading, you may wish to avoid loading `nvim-dap` when overseer is loaded. If so, you can disable DAP support initially:

```lua
require("overseer").setup({
  dap = false,
})
```

And enable the integration manually later, such as when `nvim-dap` is loaded:

```lua
require("overseer").enable_dap()
```

## Session managers

### resession.nvim

Overseer has built-in support for [resession.nvim](https://github.com/stevearc/resession.nvim).

```lua
require("resession").setup({
  extensions = {
    overseer = {
      -- customize here
    },
  },
})
```

The configuration options will be passed to [list_tasks](reference.md#list_tasksopts), and determine which tasks will be saved when saving a session.

### Other session managers

For other session managers, the API allows you to list and serialize tasks. As long as your session
manager has some way to store auxiliary data, you can use this to save and restore tasks.

For example, to integrate with [auto-session](https://github.com/rmagatti/auto-session)

```lua
require("auto-session").setup({
  pre_save_cmds = {
    function()
      local tasks = require("overseer.task_list").list_tasks()
      local cmds = {}
      for _, task in ipairs(tasks) do
        local json = vim.json.encode(task:serialize())
        -- For some reason, vim.json.encode encodes / as \/.
        json = string.gsub(json, "\\/", "/")
        -- Escape single quotes so we can put this inside single quotes
        json = string.gsub(json, "'", "\\'")
        table.insert(cmds, string.format("lua require('overseer').new_task(vim.json.decode('%s')):start()", json))
      end
      return cmds
    end,
  },
  -- Optionally get rid of all previous tasks when restoring a session
  pre_restore_cmds = {
    function()
      for _, task in ipairs(require("overseer").list_tasks({})) do
        task:dispose(true)
      end
    end,
  },
})
```
