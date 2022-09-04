# Reference

<!-- TOC -->

- [Setup options](#setup-options)
- [Commands](#commands)
- [Highlight groups](#highlight-groups)
- [Lua API](#lua-api)
- [Parameters](#parameters)

<!-- /TOC -->

## Setup options

For speed tweakers: don't worry about lazy loading; overseer lazy-loads itself!

```lua
require("overseer").setup({
  -- Default task strategy
  strategy = "terminal",
  -- Template modules to load
  templates = { "builtin" },
  -- When true, tries to detect a green color from your colorscheme to use for success highlight
  auto_detect_success_color = true,
  -- Patch nvim-dap to support preLaunchTask and postDebugTask
  dap = true,
  -- Configure the task list
  task_list = {
    -- Default detail level for tasks. Can be 1-3.
    default_detail = 1,
    -- Width dimensions can be integers or a float between 0 and 1 (e.g. 0.4 for 40%)
    -- min_width and max_width can be a single value or a list of mixed integer/float types.
    -- max_width = {100, 0.2} means "the lesser of 100 columns or 20% of total"
    max_width = { 100, 0.2 },
    -- min_width = {40, 0.1} means "the greater of 40 columns or 10% of total"
    min_width = { 40, 0.1 },
    -- optionally define an integer/float for the exact width of the task list
    width = nil,
    -- String that separates tasks
    separator = "────────────────────────────────────────",
    -- Default direction. Can be "left" or "right"
    direction = "left",
    -- Set keymap to false to remove default behavior
    -- You can add custom keymaps here as well (anything vim.keymap.set accepts)
    bindings = {
      ["?"] = "ShowHelp",
      ["<CR>"] = "RunAction",
      ["<C-e>"] = "Edit",
      ["o"] = "Open",
      ["<C-v>"] = "OpenVsplit",
      ["<C-s>"] = "OpenSplit",
      ["<C-f>"] = "OpenFloat",
      ["p"] = "TogglePreview",
      ["<C-l>"] = "IncreaseDetail",
      ["<C-h>"] = "DecreaseDetail",
      ["L"] = "IncreaseAllDetail",
      ["H"] = "DecreaseAllDetail",
      ["["] = "DecreaseWidth",
      ["]"] = "IncreaseWidth",
      ["{"] = "PrevTask",
      ["}"] = "NextTask",
    },
  },
  -- See :help overseer.actions
  actions = {},
  -- Configure the floating window used for task templates that require input
  -- and the floating window used for editing tasks
  form = {
    border = "rounded",
    zindex = 40,
    -- Dimensions can be integers or a float between 0 and 1 (e.g. 0.4 for 40%)
    -- min_X and max_X can be a single value or a list of mixed integer/float types.
    min_width = 80,
    max_width = 0.9,
    width = nil,
    min_height = 10,
    max_height = 0.9,
    height = nil,
    -- Set any window options here (e.g. winhighlight)
    win_opts = {
      winblend = 10,
    },
  },
  task_launcher = {
    -- Set keymap to false to remove default behavior
    -- You can add custom keymaps here as well (anything vim.keymap.set accepts)
    bindings = {
      i = {
        ["<C-s>"] = "Submit",
      },
      n = {
        ["<CR>"] = "Submit",
        ["<C-s>"] = "Submit",
        ["?"] = "ShowHelp",
      },
    },
  },
  task_editor = {
    -- Set keymap to false to remove default behavior
    -- You can add custom keymaps here as well (anything vim.keymap.set accepts)
    bindings = {
      i = {
        ["<CR>"] = "NextOrSubmit",
        ["<C-s>"] = "Submit",
        ["<Tab>"] = "Next",
        ["<S-Tab>"] = "Prev",
      },
      n = {
        ["<CR>"] = "NextOrSubmit",
        ["<C-s>"] = "Submit",
        ["<Tab>"] = "Next",
        ["<S-Tab>"] = "Prev",
        ["?"] = "ShowHelp",
      },
    },
  },
  -- Configure the floating window used for confirmation prompts
  confirm = {
    border = "rounded",
    zindex = 40,
    -- Dimensions can be integers or a float between 0 and 1 (e.g. 0.4 for 40%)
    -- min_X and max_X can be a single value or a list of mixed integer/float types.
    min_width = 80,
    max_width = 0.5,
    width = nil,
    min_height = 10,
    max_height = 0.9,
    height = nil,
    -- Set any window options here (e.g. winhighlight)
    win_opts = {
      winblend = 10,
    },
  },
  -- Configuration for task floating windows
  task_win = {
    -- How much space to leave around the floating window
    padding = 2,
    border = "rounded",
    -- Set any window options here (e.g. winhighlight)
    win_opts = {
      winblend = 10,
    },
  },
  -- Aliases for bundles of components. Redefine the builtins, or create your own.
  component_aliases = {
    -- Most tasks are initialized with the default components
    default = {
      "on_output_summarize",
      "on_exit_set_status",
      "on_complete_notify",
      "on_complete_dispose",
    },
    -- Tasks from tasks.json use these components
    default_vscode = {
      "default",
      "on_result_diagnostics",
      "on_result_diagnostics_quickfix",
    },
  },
  -- This is run before creating tasks from a template
  pre_task_hook = function(task_defn, util)
    -- util.add_component(task_defn, "on_result_diagnostics", {"timeout", timeout = 20})
    -- util.remove_component(task_defn, "on_complete_dispose")
    -- task_defn.env = { MY_VAR = 'value' }
  end,
  -- A list of components to preload on setup.
  -- Only matters if you want them to show up in the task editor.
  preload_components = {},
  -- Controls when the parameter prompt is shown when running a template
  --   always    Show when template has any params
  --   missing   Show when template has any params not explicitly passed in
  --   allow     Only show when a required param is missing
  --   never     Never show prompt (error if required param missing)
  default_template_prompt = "allow",
  -- Configure where the logs go and what level to use
  -- Types are "echo", "notify", and "file"
  log = {
    {
      type = "echo",
      level = vim.log.levels.WARN,
    },
    {
      type = "file",
      filename = "overseer.log",
      level = vim.log.levels.WARN,
    },
  },
})
```

## Commands

| Command                | Args          | Description                                                         |
| ---------------------- | ------------- | ------------------------------------------------------------------- |
| `OverseerOpen[!]`      | `left/right`  | Open the overseer window. With `!` cursor stays in current window   |
| `OverseerClose`        |               | Close the overseer window                                           |
| `OverseerToggle[!]`    | `left/right`  | Toggle the overseer window. With `!` cursor stays in current window |
| `OverseerSaveBundle`   | `[name]`      | Serialize and save the current tasks to disk                        |
| `OverseerLoadBundle`   | `[name]`      | Load tasks that were saved to disk                                  |
| `OverseerDeleteBundle` | `[name]`      | Delete a saved task bundle                                          |
| `OverseerRunCmd`       | `[command]`   | Run a raw shell command                                             |
| `OverseerRun`          | `[name/tags]` | Run a task from a template                                          |
| `OverseerBuild`        |               | Open the task builder                                               |
| `OverseerQuickAction`  | `[action]`    | Run an action on the most recent task, or the task under the cursor |
| `OverseerTaskAction`   |               | Select a task to run an action on                                   |

## Highlight groups

Overseer defines the following highlights override them to customize the colors.

| Group                | description                                             |
| -------------------- | ------------------------------------------------------- |
| `OverseerPENDING`    | Pending tasks                                           |
| `OverseerRUNNING`    | Running tasks                                           |
| `OverseerSUCCESS`    | Succeeded tasks                                         |
| `OverseerCANCELED`   | Canceled tasks                                          |
| `OverseerFAILURE`    | Failed tasks                                            |
| `OverseerTask`       | Used to render the name of a task or template           |
| `OverseerTaskBorder` | The separator in the task list                          |
| `OverseerOutput`     | The output summary in the task list                     |
| `OverseerComponent`  | The name of a component in the task list or task editor |
| `OverseerField`      | The name of a field in the task or template editor      |

## Lua API

As overseer is in beta status, the API is not completely solidified. Breaking change _may_ be made if necessary to improve the plugin, but they _will not_ be made unless absolutely necessary. Wherever possible, functions will be gracefully deprecated with clear migration messages.

The official API surface includes:

- All functions exposed in [overseer/init.lua](../lua/overseer/init.lua)
- Config options passed to `setup()`
- [Components](#components), including names and parameters FIXME fix link
- [Commands](#commands)
- [Parsers](#parsing-output), including names and parameters FIXME fix link

FIXME generate API docs

## Parameters

Parameters are a schema-defined set of options. They are used by both [components](#components) and [templates](#templates) to expose customization options.

```lua
local params = {
  my_var = {
    type = "string",
    -- Optional fields that are available on any type
    name = "More readable name",
    desc = "A detailed description",
    validate = function(value)
      return true,
    end,
    optional = true,
    default = "foobar",
  }
}
```

The following types are available:

```lua
{
  type = "string"
}
{
  type = "boolean"
}
{
  type = "number"
}
{
  type = "integer"
}
{
  type = "list",
  subtype = {
    type = "string"
  },
  delimiter = ",",
}
{
  type = "enum",
  choices = {"ONE", "TWO", "THREE"},
}
{
  -- This is used when the value is too complex to be represented or edited by the user in the task editor.
  -- It should generally only be used by components (which are usually configured programmatically)
  -- and not templates (which usually prompt the user for their parameters)
  type = "opaque"
}
```
