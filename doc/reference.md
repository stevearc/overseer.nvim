# Reference

<!-- TOC -->

- [Setup options](#setup-options)
- [Commands](#commands)
- [Highlight groups](#highlight-groups)
- [Lua API](#lua-api)
  - [setup(opts)](#setupopts)
  - [on_setup(callback)](#on_setupcallback)
  - [new_task(opts)](#new_taskopts)
  - [toggle(opts)](#toggleopts)
  - [open(opts)](#openopts)
  - [close()](#close)
  - [list_task_bundles()](#list_task_bundles)
  - [load_task_bundle(name, opts)](#load_task_bundlename-opts)
  - [save_task_bundle(name, tasks, opts)](#save_task_bundlename-tasks-opts)
  - [delete_task_bundle(name)](#delete_task_bundlename)
  - [list_tasks(opts)](#list_tasksopts)
  - [run_template(opts, callback)](#run_templateopts-callback)
  - [run_action(task, name)](#run_actiontask-name)
  - [wrap_template(base, override, default_params)](#wrap_templatebase-override-default_params)
  - [add_template_hook(opts, hook)](#add_template_hookopts-hook)
  - [remove_template_hook(opts, hook)](#remove_template_hookopts-hook)
  - [register_template(defn)](#register_templatedefn)
  - [load_template(name)](#load_templatename)
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
  -- A list of components to preload on setup.
  -- Only matters if you want them to show up in the task editor.
  preload_components = {},
  -- Controls when the parameter prompt is shown when running a template
  --   always    Show when template has any params
  --   missing   Show when template has any params not explicitly passed in
  --   allow     Only show when a required param is missing
  --   never     Never show prompt (error if required param missing)
  default_template_prompt = "allow",
  -- For async template generators, how long to wait (in ms) before timing out
  template_timeout = 1000,
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
- [Components](explanation.md#components), including names and parameters
- [Commands](#commands)
- [Parsers](guides.md#parsing-output), including names and parameters

<!-- API -->

### setup(opts)

`setup(opts)` \
Initialize overseer
| Param | Type                   | Desc                  |
| ---- | ---------------------- | --------------------- |
| opts | `overseer.Config\|nil` | Configuration options |

### on_setup(callback)

`on_setup(callback)` \
Add a callback to run after overseer lazy setup
| Param    | Type    | Desc |
| -------- | ------- | - |
| callback | `fun()` |   |

### new_task(opts)

`new_task(opts): overseer.Task` \
Create a new Task
| Param | Type                      | Desc                         |                                                         |
| ---- | ------------------------- | ---------------------------- | ------------------------------------------------------- |
| opts | `overseer.TaskDefinition` |                              |                                                         |
|      | cmd                       | `string\|string[]`           | Command to run                                          |
|      | args                      | `nil\|string[]`              | Arguments to pass to the command                        |
|      | name                      | `nil\|string`                | Name of the task. Defaults to the cmd                   |
|      | cwd                       | `nil\|string`                | Working directory to run in                             |
|      | env                       | `nil\|table<string, string>` | Additional environment variables                        |
|      | strategy                  | `nil\|overseer.Serialized`   | Definition for a run Strategy                           |
|      | metadata                  | `nil\|table`                 | Arbitrary metadata for your own use                     |
|      | default_component_params  | `nil\|table`                 | Default values for component params                     |
|      | components                | `nil\|overseer.Serialized[]` | List of components to attach. Defaults to `{'default'}` |

**Examples:**
```lua
local task = overseer.new_task({
  cmd = {'./build.sh'},
  args = {'all'},
  components = {{'on_output_quickfix', open=true}, 'default'}
})
task:start()
```

### toggle(opts)

`toggle(opts)` \
Open or close the task list
| Param | Type                       | Desc                   |                                                |
| ---- | -------------------------- | ---------------------- | ---------------------------------------------- |
| opts | `overseer.WindowOpts\|nil` |                        |                                                |
|      | enter                      | `boolean\|nil`         | If false, stay in current window. Default true |
|      | direction                  | `nil\|"left"\|"right"` | Which direction to open the task list          |

### open(opts)

`open(opts)` \
Open the task list
| Param | Type                       | Desc                   |                                                |
| ---- | -------------------------- | ---------------------- | ---------------------------------------------- |
| opts | `overseer.WindowOpts\|nil` |                        |                                                |
|      | enter                      | `boolean\|nil`         | If false, stay in current window. Default true |
|      | direction                  | `nil\|"left"\|"right"` | Which direction to open the task list          |

### close()

`close()` \
Close the task list

### list_task_bundles()

`list_task_bundles(): string[]` \
Get the list of saved task bundles

Returns:
| Type     | Desc                  |
| -------- | --------------------- |
| string[] | Names of task bundles |

### load_task_bundle(name, opts)

`load_task_bundle(name, opts)` \
Load tasks from a saved bundle
| Param | Type           | Desc           |                                                 |
| ---- | -------------- | -------------- | ----------------------------------------------- |
| name | `string\|nil`  |                |                                                 |
| opts | `table\|nil`   |                |                                                 |
|      | ignore_missing | `boolean\|nil` | When true, don't notify if bundle doesn't exist |

### save_task_bundle(name, tasks, opts)

`save_task_bundle(name, tasks, opts)` \
Save tasks to a bundle on disk
| Param | Type                   | Desc                                             |   |
| ----- | ---------------------- | ------------------------------------------------ | - |
| name  | `string\|nil`          | Name of bundle. If nil, will prompt user.        |   |
| tasks | `nil\|overseer.Task[]` | Specific tasks to save. If nil, saves all tasks. |   |
| opts  | `table\|nil`           |                                                  |   |
|       | on_conflict            | `nil\|"overwrite"\|"append"\|"cancel"`           |   |

### delete_task_bundle(name)

`delete_task_bundle(name)` \
Delete a saved task bundle
| Param | Type          | Desc |
| ---- | ------------- | - |
| name | `string\|nil` |   |

### list_tasks(opts)

`list_tasks(opts): overseer.Task[]` \
List all tasks
| Param | Type                         | Desc                                      |                                                     |
| ---- | ---------------------------- | ----------------------------------------- | --------------------------------------------------- |
| opts | `overseer.ListTaskOpts\|nil` |                                           |                                                     |
|      | unique                       | `boolean\|nil`                            | Deduplicates non-running tasks by name              |
|      | name                         | `nil\|string\|string[]`                   | Only list tasks with this name or names             |
|      | name_not                     | `nil\|boolean`                            | Invert the name search (tasks *without* that name)  |
|      | status                       | `nil\|overseer.Status\|overseer.Status[]` | Only list tasks with this status or statuses        |
|      | status_not                   | `nil\|boolean`                            | Invert the status search                            |
|      | recent_first                 | `nil\|boolean`                            | The most recent tasks are first in the list         |
|      | bundleable                   | `nil\|boolean`                            | Only list tasks that should be included in a bundle |
|      | filter                       | `nil\|fun(task: overseer.Task): boolean`  |                                                     |

### run_template(opts, callback)

`run_template(opts, callback)` \
Run a task from a template
| Param    | Type                                                   | Desc                                         |                                                                                                                                     |
| -------- | ------------------------------------------------------ | -------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| opts     | `overseer.TemplateRunOpts`                             |                                              |                                                                                                                                     |
|          | name                                                   | `nil\|string`                                | The name of the template to run                                                                                                     |
|          | tags                                                   | `nil\|string[]`                              | List of tags used to filter when searching for template                                                                             |
|          | autostart                                              | `nil\|boolean`                               | When true, start the task after creating it (default true)                                                                          |
|          | first                                                  | `nil\|boolean`                               | When true, take first result and never show the task picker. Default behavior will auto-set this based on presence of name and tags |
|          | prompt                                                 | `nil\|"always"\|"missing"\|"allow"\|"never"` | Controls when to prompt user for parameter input                                                                                    |
|          | params                                                 | `nil\|table`                                 | Parameters to pass to template                                                                                                      |
|          | cwd                                                    | `nil\|string`                                | Working directory for the task                                                                                                      |
|          | env                                                    | `nil\|table<string, string>`                 | Additional environment variables for the task                                                                                       |
| callback | `nil\|fun(task: overseer.Task\|nil, err: string\|nil)` |                                              |                                                                                                                                     |

**Note:**
<pre>
The prompt option will control when the user is presented a popup dialog to input template
parameters. The possible values are:
   always    Show when template has any params
   missing   Show when template has any params not explicitly passed in
   allow     Only show when a required param is missing
   never     Never show prompt (error if required param missing)
The default is controlled by the default_template_prompt config option.
</pre>

**Examples:**
```lua
-- Run the task named "make all"
-- equivalent to :OverseerRun make all
overseer.run_template({name = "make all"})
-- Run the default "build" task
-- equivalent to :OverseerRun BUILD
overseer.run_template({tags = {overseer.TAG.BUILD}})
-- Run the task named "serve" with some default parameters
overseer.run_template({name = "serve", params = {port = 8080}})
-- Create a task but do not start it
overseer.run_template({name = "make", autostart = false}, function(task)
  -- do something with the task
end)
-- Run a task and immediately open the floating window
overseer.run_template({name = "make"}, function(task)
  if task then
    overseer.run_action(task, 'open float')
  end
end)
-- Run a task and always show the parameter prompt
overseer.run_template({name = "npm watch", prompt = "always"})
```

### run_action(task, name)

`run_action(task, name)` \
Run an action on a task
| Param | Type            | Desc                                               |
| ---- | --------------- | -------------------------------------------------- |
| task | `overseer.Task` |                                                    |
| name | `string\|nil`   | Name of action. When omitted, prompt user to pick. |

### wrap_template(base, override, default_params)

`wrap_template(base, override, default_params): overseer.TemplateDefinition` \
Create a new template by overriding fields on another
| Param          | Type                          | Desc                                                  |
| -------------- | ----------------------------- | ----------------------------------------------------- |
| base           | `overseer.TemplateDefinition` | The base template definition to wrap                  |
| override       | `nil\|table<string, any>`     | Override any fields on the base                       |
| default_params | `nil\|table<string, any>`     | Provide default values for any parameters on the base |

**Note:**
<pre>
This is typically used for a TemplateProvider, to define the task a single time and generate
multiple templates based on the available args.
</pre>

**Examples:**
```lua
local tmpl = {
  params = {
    args = { type = 'list', delimiter = ' ' }
  },
  builder = function(params)
  return {
    cmd = { 'make' },
    args = params.args,
  }
}
local template_provider = {
  generator = function(opts)
    return {
      overseer.wrap_template(tmpl, nil, { args = { 'all' } }),
      overseer.wrap_template(tmpl, {name = 'make clean'}, { args = { 'clean' } }),
    }
  end
}
```

### add_template_hook(opts, hook)

`add_template_hook(opts, hook)` \
Add a hook that runs on a TaskDefinition before the task is created
| Param | Type                                                               | Desc                                    |                                                                           |
| ---- | ------------------------------------------------------------------ | --------------------------------------- | ------------------------------------------------------------------------- |
| opts | `nil\|overseer.HookOptions`                                        | When nil, run the hook on all templates |                                                                           |
|      | name                                                               | `nil\|string`                           | Only run if the template name matches this pattern (using string.match)   |
|      | module                                                             | `nil\|string`                           | Only run if the template module matches this pattern (using string.match) |
|      | filetype                                                           | `nil\|string\|string[]`                 | Only run if the current file is one of these filetypes                    |
|      | dir                                                                | `nil\|string\|string[]`                 | Only run if inside one of these directories                               |
| hook | `fun(task_defn: overseer.TaskDefinition, util: overseer.TaskUtil)` |                                         |                                                                           |

**Examples:**
```lua
-- Add on_output_quickfix component to all "cargo" templates
overseer.add_template_hook({ module = "^cargo$" }, function(task_defn, util)
  util.add_component(task_defn, { "on_output_quickfix", open = true })
end)
-- Remove the on_complete_notify component from "cargo clean" task
overseer.add_template_hook({ name = "cargo clean" }, function(task_defn, util)
  util.remove_component(task_defn, "on_complete_notify")
end)
-- Add an environment variable for all go tasks in a specific dir
overseer.add_template_hook({ name = "^go .*", dir = "/path/to/project" }, function(task_defn, util)
  task_defn.env = vim.tbl_extend('force', task_defn.env or {}, {
    GO111MODULE = "on"
  })
end)
```

### remove_template_hook(opts, hook)

`remove_template_hook(opts, hook)` \
Remove a hook that was added with add_template_hook
| Param | Type                                                               | Desc                          |
| ---- | ------------------------------------------------------------------ | ----------------------------- |
| opts | `nil\|overseer.HookOptions`                                        | Same as for add_template_hook |
| hook | `fun(task_defn: overseer.TaskDefinition, util: overseer.TaskUtil)` |                               |

**Examples:**
```lua
local opts = {module = "cargo"}
local hook = function(task_defn, util)
  util.add_component(task_defn, { "on_output_quickfix", open = true })
end
overseer.add_template_hook(opts, hook)
-- Remove should pass in the same opts as add
overseer.remove_template_hook(opts, hook)
```

### register_template(defn)

`register_template(defn)` \
Directly register an overseer template
| Param | Type                                                     | Desc |
| ---- | -------------------------------------------------------- | - |
| defn | `overseer.TemplateDefinition\|overseer.TemplateProvider` |   |

### load_template(name)

`load_template(name)` \
Load a template definition from its module location
| Param | Type     | Desc |
| ---- | -------- | - |
| name | `string` |   |

**Examples:**
```lua
-- This will load the template in lua/overseer/template/mytask.lua
overseer.load_template('mytask')
```


<!-- /API -->

## Parameters

Parameters are a schema-defined set of options. They are used by both [components](explanation.md#components) and [templates](explanation.md#templates) to expose customization options.

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
    -- For component params only.
    -- When true, will default to the value in the task's default_component_params
    default_from_task = true,
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
