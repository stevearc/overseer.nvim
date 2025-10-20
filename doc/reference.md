# Reference

<!-- TOC -->

- [Setup options](#setup-options)
- [Commands](#commands)
- [Highlight groups](#highlight-groups)
- [Lua API](#lua-api)
  - [setup(opts)](#setupopts)
  - [new_task(opts)](#new_taskopts)
  - [toggle(opts)](#toggleopts)
  - [open(opts)](#openopts)
  - [close()](#close)
  - [list_tasks(opts)](#list_tasksopts)
  - [run_task(opts, callback)](#run_taskopts-callback)
  - [preload_task_cache(opts, cb)](#preload_task_cacheopts-cb)
  - [clear_task_cache(opts)](#clear_task_cacheopts)
  - [run_action(task, name)](#run_actiontask-name)
  - [add_template_hook(opts, hook)](#add_template_hookopts-hook)
  - [remove_template_hook(opts, hook)](#remove_template_hookopts-hook)
  - [register_template(defn)](#register_templatedefn)
  - [debug_parser()](#debug_parser)
  - [register_alias(name, components)](#register_aliasname-components)
- [Components](#components)
  - [dependencies](components.md#dependencies)
  - [on_complete_dispose](components.md#on_complete_dispose)
  - [on_complete_notify](components.md#on_complete_notify)
  - [on_complete_restart](components.md#on_complete_restart)
  - [on_exit_set_status](components.md#on_exit_set_status)
  - [on_output_notify](components.md#on_output_notify)
  - [on_output_parse](components.md#on_output_parse)
  - [on_output_quickfix](components.md#on_output_quickfix)
  - [on_output_write_file](components.md#on_output_write_file)
  - [on_result_diagnostics](components.md#on_result_diagnostics)
  - [on_result_diagnostics_quickfix](components.md#on_result_diagnostics_quickfix)
  - [on_result_diagnostics_trouble](components.md#on_result_diagnostics_trouble)
  - [on_result_notify](components.md#on_result_notify)
  - [open_output](components.md#open_output)
  - [restart_on_save](components.md#restart_on_save)
  - [run_after](components.md#run_after)
  - [timeout](components.md#timeout)
  - [unique](components.md#unique)
- [Strategies](#strategies)
  - [jobstart(opts)](strategies.md#jobstartopts)
  - [orchestrator(opts)](strategies.md#orchestratoropts)
  - [test()](strategies.md#test)
- [Parsers](#parsers)
    - [always](parsers.md#always)
    - [append](parsers.md#append)
    - [dispatch](parsers.md#dispatch)
    - [ensure](parsers.md#ensure)
    - [extract](parsers.md#extract)
    - [extract_efm](parsers.md#extract_efm)
    - [extract_json](parsers.md#extract_json)
    - [extract_multiline](parsers.md#extract_multiline)
    - [extract_nested](parsers.md#extract_nested)
    - [invert](parsers.md#invert)
    - [loop](parsers.md#loop)
    - [parallel](parsers.md#parallel)
    - [sequence](parsers.md#sequence)
    - [set_defaults](parsers.md#set_defaults)
    - [skip_lines](parsers.md#skip_lines)
    - [skip_until](parsers.md#skip_until)
    - [test](parsers.md#test)
- [Parameters](#parameters)

<!-- /TOC -->

## Setup options

For speed tweakers: don't worry about lazy loading; overseer lazy-loads itself!

```lua
require("overseer").setup({
  -- Patch nvim-dap to support preLaunchTask and postDebugTask
  dap = true,
  -- Configure the task list
  task_list = {
    -- Width dimensions can be integers or a float between 0 and 1 (e.g. 0.4 for 40%)
    -- min_width and max_width can be a single value or a list of mixed integer/float types.
    -- max_width = {100, 0.2} means "the lesser of 100 columns or 20% of total"
    max_width = { 100, 0.2 },
    -- min_width = {40, 0.1} means "the greater of 40 columns or 10% of total"
    min_width = { 40, 0.1 },
    -- optionally define an integer/float for the exact width of the task list
    width = nil,
    max_height = { 20, 0.1 },
    min_height = 8,
    height = nil,
    -- String that separates tasks
    separator = "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
    -- Indentation for child tasks
    child_indent = { "┃ ", "┣━", "┗━" },
    -- Function that renders tasks. See lua/overseer/render.lua for built-in options
    -- and for useful functions if you want to build your own.
    render = function(task)
      return require("overseer.render").format_standard(task)
    end,
    -- Default direction. Can be "left", "right", or "bottom"
    direction = "bottom",
    -- Set keymap to false to remove default behavior
    -- You can add custom keymaps here as well (anything vim.keymap.set accepts)
    bindings = {
      ["?"] = "ShowHelp",
      ["g?"] = "ShowHelp",
      ["<CR>"] = "RunAction",
      ["<C-e>"] = "Edit",
      ["o"] = "Open",
      ["<C-v>"] = "OpenVsplit",
      ["<C-s>"] = "OpenSplit",
      ["<C-f>"] = "OpenFloat",
      ["<C-q>"] = "OpenQuickFix",
      ["p"] = "TogglePreview",
      ["["] = "DecreaseWidth",
      ["]"] = "IncreaseWidth",
      ["{"] = "PrevTask",
      ["}"] = "NextTask",
      ["<C-k>"] = "ScrollOutputUp",
      ["<C-j>"] = "ScrollOutputDown",
      ["q"] = "Close",
    },
  },
  -- See :help overseer-actions
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
      winblend = 0,
    },
  },
  task_launcher = {
    -- Set keymap to false to remove default behavior
    -- You can add custom keymaps here as well (anything vim.keymap.set accepts)
    bindings = {
      i = {
        ["<C-s>"] = "Submit",
        ["<C-c>"] = "Cancel",
      },
      n = {
        ["<CR>"] = "Submit",
        ["<C-s>"] = "Submit",
        ["q"] = "Cancel",
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
        ["<C-c>"] = "Cancel",
      },
      n = {
        ["<CR>"] = "NextOrSubmit",
        ["<C-s>"] = "Submit",
        ["<Tab>"] = "Next",
        ["<S-Tab>"] = "Prev",
        ["q"] = "Cancel",
        ["?"] = "ShowHelp",
      },
    },
  },
  -- Configuration for task floating windows
  task_win = {
    -- How much space to leave around the floating window
    padding = 2,
    border = "rounded",
    -- Set any window options here (e.g. winhighlight)
    win_opts = {
      winblend = 0,
    },
  },
  -- Configuration for mapping help floating windows
  help_win = {
    border = "rounded",
    win_opts = {},
  },
  -- Aliases for bundles of components. Redefine the builtins, or create your own.
  component_aliases = {
    -- Most tasks are initialized with the default components
    default = {
      "on_exit_set_status",
      "on_complete_notify",
      { "on_complete_dispose", require_view = { "SUCCESS", "FAILURE" } },
    },
    -- Tasks from tasks.json use these components
    default_vscode = {
      "default",
      "on_result_diagnostics",
    },
  },
  -- List of other directories to search for task templates.
  -- This will search under the runtimepath, so for example
  -- "foo/bar" will search "<runtimepath>/lua/foo/bar/*"
  template_dirs = {},
  -- For template providers, how long to wait (in ms) before timing out.
  -- Set to 0 to wait forever.
  template_timeout = 3000,
  -- Cache template provider results if the provider takes longer than this to run.
  -- Time is in ms. Set to 0 to disable caching.
  template_cache_threshold = 200,
  log_level = vim.log.levels.WARN,
})
```

## Commands

| Command               | Args                | Description                                                         |
| --------------------- | ------------------- | ------------------------------------------------------------------- |
| `OverseerOpen[!]`     | `left/right/bottom` | Open the overseer window. With `!` cursor stays in current window   |
| `OverseerClose`       |                     | Close the overseer window                                           |
| `OverseerToggle[!]`   | `left/right/bottom` | Toggle the overseer window. With `!` cursor stays in current window |
| `OverseerRun`         | `[name/tags]`       | Run a task from a template                                          |
| `OverseerQuickAction` | `[action]`          | Run an action on the most recent task, or the task under the cursor |
| `OverseerTaskAction`  |                     | Select a task to run an action on                                   |
| `OverseerClearCache`  |                     | Clear the task cache                                                |

## Highlight groups

Overseer defines the following highlights. Override them to customize the colors.

| Group                | Description                                             |
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
| ----- | ---------------------- | --------------------- |
| opts  | `overseer.Config\|nil` | Configuration options |

### new_task(opts)

`new_task(opts): overseer.Task` \
Create a new Task

| Param                     | Type                         | Desc                                                                             |
| ------------------------- | ---------------------------- | -------------------------------------------------------------------------------- |
| opts                      | `overseer.TaskDefinition`    |                                                                                  |
| >cmd                      | `string\|string[]`           | Command to run. If it's a string it is run in the shell; a table is run directly |
| >args                     | `nil\|string[]`              | Arguments to pass to the command                                                 |
| >name                     | `nil\|string`                | Name of the task. Defaults to the cmd                                            |
| >cwd                      | `nil\|string`                | Working directory to run in                                                      |
| >env                      | `nil\|table<string, string>` | Additional environment variables                                                 |
| >strategy                 | `nil\|overseer.Serialized`   | Definition for a run Strategy                                                    |
| >metadata                 | `nil\|table`                 | Arbitrary metadata for your own use                                              |
| >default_component_params | `nil\|table<string, any>`    | Default values for component params                                              |
| >components               | `nil\|overseer.Serialized[]` | List of components to attach. Defaults to `{"default"}`                          |

**Examples:**
```lua
local task = overseer.new_task({
  cmd = { "./build.sh", "all" },
  components = { { "on_output_quickfix", open = true }, "default" }
})
task:start()
```

### toggle(opts)

`toggle(opts)` \
Open or close the task list

| Param          | Type                             | Desc                                                     |
| -------------- | -------------------------------- | -------------------------------------------------------- |
| opts           | `nil\|overseer.WindowOpts`       |                                                          |
| >enter         | `nil\|boolean`                   |                                                          |
| >direction     | `nil\|"left"\|"right"\|"bottom"` |                                                          |
| >winid         | `nil\|integer`                   | Use this existing window instead of opening a new window |
| >focus_task_id | `nil\|integer`                   | After opening, focus this task                           |

### open(opts)

`open(opts)` \
Open the task list

| Param      | Type                       | Desc                                           |
| ---------- | -------------------------- | ---------------------------------------------- |
| opts       | `nil\|overseer.WindowOpts` |                                                |
| >enter     | `boolean\|nil`             | If false, stay in current window. Default true |
| >direction | `nil\|"left"\|"right"`     | Which direction to open the task list          |

### close()

`close()` \
Close the task list


### list_tasks(opts)

`list_tasks(opts): overseer.Task[]` \
List all tasks

| Param         | Type                                      | Desc                                                |
| ------------- | ----------------------------------------- | --------------------------------------------------- |
| opts          | `nil\|overseer.ListTaskOpts`              |                                                     |
| >unique       | `nil\|boolean`                            | Deduplicates non-running tasks by name              |
| >status       | `nil\|overseer.Status\|overseer.Status[]` | Only list tasks with this status or statuses        |
| >recent_first | `nil\|boolean`                            | The most recent tasks are first in the list         |
| >bundleable   | `nil\|boolean`                            | Only list tasks that should be included in a bundle |
| >filter       | `nil\|fun(task: overseer.Task): boolean`  |                                                     |

### run_task(opts, callback)

`run_task(opts, callback)` \
Run a task from a template

| Param            | Type                                                                    | Desc                                                                                                                                |
| ---------------- | ----------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| opts             | `overseer.TemplateRunOpts`                                              |                                                                                                                                     |
| >name            | `nil\|string`                                                           | The name of the template to run                                                                                                     |
| >tags            | `nil\|string[]`                                                         | List of tags used to filter when searching for template                                                                             |
| >autostart       | `nil\|boolean`                                                          | When true, start the task after creating it (default true)                                                                          |
| >first           | `nil\|boolean`                                                          | When true, take first result and never show the task picker. Default behavior will auto-set this based on presence of name and tags |
| >params          | `nil\|table`                                                            | Parameters to pass to template                                                                                                      |
| >cwd             | `nil\|string`                                                           | Working directory for the task                                                                                                      |
| >env             | `nil\|table<string, string>`                                            | Additional environment variables for the task                                                                                       |
| >disallow_prompt | `nil\|boolean`                                                          | When true, if any required parameters are missing return an error instead of prompting the user for them                            |
| >on_build        | `nil\|fun(task_defn: overseer.TaskDefinition, util: overseer.TaskUtil)` | callback that is called after the task definition is built but before the task is created.                                          |
| callback         | `nil\|fun(task: overseer.Task\|nil, err: string\|nil)`                  |                                                                                                                                     |

**Examples:**
```lua
-- Run the task named "make all"
-- equivalent to :OverseerRun make\ all
overseer.run_task({name = "make all"})
-- Run the default "build" task
-- equivalent to :OverseerRun BUILD
overseer.run_task({tags = {overseer.TAG.BUILD}})
-- Run the task named "serve" with some default parameters
overseer.run_task({name = "serve", params = {port = 8080}})
-- Create a task but do not start it
overseer.run_task({name = "make", autostart = false}, function(task)
  -- do something with the task
end)
-- Run a task and immediately open the floating window
overseer.run_task({name = "make"}, function(task)
  if task then
    overseer.run_action(task, 'open float')
  end
end)
```

### preload_task_cache(opts, cb)

`preload_task_cache(opts, cb)` \
Preload templates for run_task

| Param | Type          | Desc                               |
| ----- | ------------- | ---------------------------------- |
| opts  | `nil\|table`  |                                    |
| >dir  | `string`      |                                    |
| >ft   | `nil\|string` |                                    |
| cb    | `nil\|fun()`  | Called when preloading is complete |

**Note:**
<pre>
Typically this would be done to prevent a long wait time for :OverseerRun when using a slow
template provider.
</pre>

**Examples:**
```lua
-- Automatically preload templates for the current directory
vim.api.nvim_create_autocmd({"VimEnter", "DirChanged"}, {
  local cwd = vim.v.cwd or vim.fn.getcwd()
  require("overseer").preload_task_cache({ dir = cwd })
})
```

### clear_task_cache(opts)

`clear_task_cache(opts)` \
Clear cached templates for run_task

| Param | Type                         | Desc |
| ----- | ---------------------------- | ---- |
| opts  | `nil\|overseer.SearchParams` |      |
| >dir  | `string`                     |      |
| >ft   | `nil\|string`                |      |

### run_action(task, name)

`run_action(task, name)` \
Run an action on a task

| Param | Type            | Desc                                               |
| ----- | --------------- | -------------------------------------------------- |
| task  | `overseer.Task` |                                                    |
| name  | `string\|nil`   | Name of action. When omitted, prompt user to pick. |

### add_template_hook(opts, hook)

`add_template_hook(opts, hook)` \
Add a hook that runs on a TaskDefinition before the task is created

| Param     | Type                                                               | Desc                                                                      |
| --------- | ------------------------------------------------------------------ | ------------------------------------------------------------------------- |
| opts      | `nil\|overseer.HookOptions`                                        | When nil, run the hook on all templates                                   |
| >name     | `nil\|string`                                                      | Only run if the template name matches this pattern (using string.match)   |
| >module   | `nil\|string`                                                      | Only run if the template module matches this pattern (using string.match) |
| >filetype | `nil\|string\|string[]`                                            | Only run if the current file is one of these filetypes                    |
| >dir      | `nil\|string\|string[]`                                            | Only run if inside one of these directories                               |
| hook      | `fun(task_defn: overseer.TaskDefinition, util: overseer.TaskUtil)` |                                                                           |

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

| Param   | Type                                                               | Desc                          |
| ------- | ------------------------------------------------------------------ | ----------------------------- |
| opts    | `nil\|overseer.HookOptions`                                        | Same as for add_template_hook |
| >module | `nil\|string`                                                      |                               |
| >name   | `nil\|string`                                                      |                               |
| hook    | `fun(task_defn: overseer.TaskDefinition, util: overseer.TaskUtil)` |                               |

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
| ----- | -------------------------------------------------------- | ---- |
| defn  | `overseer.TemplateDefinition\|overseer.TemplateProvider` |      |

**Examples:**
```lua
overseer.register_template({
  name = "My Task",
  builder = function(params)
    return {
      cmd = { "echo", "Hello", "world" },
    }
  end,
})
```

### debug_parser()

`debug_parser()` \
Open a tab with windows laid out for debugging a parser


### register_alias(name, components)

`register_alias(name, components)` \
Register a new component alias.

| Param      | Type                    | Desc |
| ---------- | ----------------------- | ---- |
| name       | `string`                |      |
| components | `overseer.Serialized[]` |      |

**Note:**
<pre>
This is intended to be used by plugin authors that wish to build on top of overseer. They do not
have control over the call to overseer.setup(), so this provides an alternative method of
setting a component alias that they can then use when creating tasks.
</pre>

**Examples:**
```lua
require("overseer").register_alias("my_plugin", { "default", "on_output_quickfix" })
```


<!-- /API -->

## Components

<!-- TOC.components -->

- [dependencies](components.md#dependencies)
- [on_complete_dispose](components.md#on_complete_dispose)
- [on_complete_notify](components.md#on_complete_notify)
- [on_complete_restart](components.md#on_complete_restart)
- [on_exit_set_status](components.md#on_exit_set_status)
- [on_output_notify](components.md#on_output_notify)
- [on_output_parse](components.md#on_output_parse)
- [on_output_quickfix](components.md#on_output_quickfix)
- [on_output_write_file](components.md#on_output_write_file)
- [on_result_diagnostics](components.md#on_result_diagnostics)
- [on_result_diagnostics_quickfix](components.md#on_result_diagnostics_quickfix)
- [on_result_diagnostics_trouble](components.md#on_result_diagnostics_trouble)
- [on_result_notify](components.md#on_result_notify)
- [open_output](components.md#open_output)
- [restart_on_save](components.md#restart_on_save)
- [run_after](components.md#run_after)
- [timeout](components.md#timeout)
- [unique](components.md#unique)

<!-- /TOC.components -->

## Strategies

<!-- TOC.strategies -->

- [jobstart(opts)](strategies.md#jobstartopts)
- [orchestrator(opts)](strategies.md#orchestratoropts)
- [test()](strategies.md#test)

<!-- /TOC.strategies -->

## Parsers

<!-- TOC.parsers -->

  - [always](parsers.md#always)
  - [append](parsers.md#append)
  - [dispatch](parsers.md#dispatch)
  - [ensure](parsers.md#ensure)
  - [extract](parsers.md#extract)
  - [extract_efm](parsers.md#extract_efm)
  - [extract_json](parsers.md#extract_json)
  - [extract_multiline](parsers.md#extract_multiline)
  - [extract_nested](parsers.md#extract_nested)
  - [invert](parsers.md#invert)
  - [loop](parsers.md#loop)
  - [parallel](parsers.md#parallel)
  - [sequence](parsers.md#sequence)
  - [set_defaults](parsers.md#set_defaults)
  - [skip_lines](parsers.md#skip_lines)
  - [skip_until](parsers.md#skip_until)
  - [test](parsers.md#test)

<!-- /TOC.parsers -->

## Parameters

Parameters are a schema-defined set of options. They are used by both [components](explanation.md#components) and [templates](explanation.md#templates) to expose customization options.

```lua
local params = {
  my_var = {
    type = "string",
    -- Optional fields that are available on any type
    name = "More readable name",
    desc = "A detailed description",
    order = 1, -- determines order of parameters in the UI
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

Templates can define params to be a function, to dynamically generate the params.

```lua
require("overseer").register_template({
  name = "Git checkout",
  params = function()
    local stdout = vim.system({ "git", "branch", "--format=%(refname:short)" }):wait().stdout
    local branches = vim.split(stdout, "\n", { trimempty = true })
    return {
      branch = {
        desc = "Branch to checkout",
        type = "enum",
        choices = branches,
      },
    }
  end,
  builder = function(params)
    return {
      cmd = { "git", "checkout", params.branch },
    }
  end,
})
```
