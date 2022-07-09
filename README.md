# overseer.nvim

A task runner and job management plugin for Neovim

**PRE-ALPHA**

History will be overwritten once it's ready for release

TODO screenshots

- [ ] Integration with launch.json preLaunchTask for dap/dap-ui
- [ ] More task providers: cmake, rake, jake, cargo
- [ ] Allow declaring parsers with pure data
- [ ] Customize keymaps in forms

Documentation TODOs

- [ ] Documentation for parsers & parser debugging
- [ ] Documentation for parser on result_exit_code
- [ ] Remaining README todos
- [ ] Vim help docs
- [ ] Document different ways to do task dependencies

---

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Setup](#setup)
- [Commands](#commands)
- [Running tasks](#running-tasks)
- [Task list](#task-list)
- [Third-party integrations](#third-party-integrations)
  - [Lualine](#lualine)
  - [Neotest](#neotest)
- [Architecture](#architecture)
- [Customization](#customization)
  - [Custom tasks](#custom-tasks)
  - [Actions](#actions)
  - [Custom components](#custom-components)
  - [Parameters](#parameters)
  - [Highlights](#highlights)
- [VS Code tasks](#vs-code-tasks)
- [Alternatives](#alternatives)
- [FAQ](#faq)

```json
{
  "version": "2.0.0",
  "configurations": [
    {
      "name": "Attach to Node Functions",
      "type": "node",
      "request": "attach",
      "port": 9230,
      "preLaunchTask": "func: host start"
    }
  ]
}
```

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "type": "func",
      "command": "host start",
      "problemMatcher": "$func-node-watch",
      "isBackground": true,
      "dependsOn": "npm build (functions)"
    },
    {
      "type": "shell",
      "label": "npm build (functions)",
      "command": "npm run build",
      "dependsOn": "npm install (functions)",
      "problemMatcher": "$tsc"
    },
    {
      "type": "shell",
      "label": "npm install (functions)",
      "command": "npm install"
    }
  ]
}
```

## Features

Overseer was built to address two generic needs:

1. Easily run and manage commands relevant to my current project
1. Easily integrate the results of those commands with neovim

To address point 1, overseer has the following features:

- auto-detect targets for common build systems (e.g. make, npm, tox)
- define your own custom tasks (can make them per-directory and/or per-filetype)
- can read and run tasks from [VS Code's tasks.json file](https://code.visualstudio.com/docs/editor/tasks)

To address point 2, overseer

- has built-in methods of parsing command output and loading it into neovim diagnostics, quickfix, or loclist.
- is _extremely_ customizable and extensible. It should be straightforward and simple to get the functionality you need.

Some examples of what overseer was built to do:

- Quickly run the relevant build command for a project (e.g. `make`)
- Run a web server in the background. Restart it on failure.
- Run a build process. Re-run it every time I make a change. If there are errors, show them in neovim diagnostics (and optionally load them into the quickfix)

## Requirements

- Neovim 0.7+
- (optional) patches for `vim.ui` (e.g. [dressing.nvim](https://github.com/stevearc/dressing.nvim)). Provides nicer UI for input and selection.
- (optional) [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim). When used with [dressing.nvim](https://github.com/stevearc/dressing.nvim) provides best selection UI.
- (optional) [nvim-notify](https://github.com/rcarriga/nvim-notify) a nice UI for `vim.notify`

## Installation

overseer supports all the usual plugin managers

<details>
  <summary>Packer</summary>

```lua
require('packer').startup(function()
    use {
      'stevearc/overseer.nvim',
      config = function() require('overseer').setup() end
    }
end)
```

</details>

<details>
  <summary>Paq</summary>

```lua
require "paq" {
    {'stevearc/overseer.nvim'};
}
```

</details>

<details>
  <summary>vim-plug</summary>

```vim
Plug 'stevearc/overseer.nvim'
```

</details>

<details>
  <summary>dein</summary>

```vim
call dein#add('stevearc/overseer.nvim')
```

</details>

<details>
  <summary>Pathogen</summary>

```sh
git clone --depth=1 https://github.com/stevearc/overseer.nvim.git ~/.vim/bundle/
```

</details>

<details>
  <summary>Neovim native package</summary>

```sh
git clone --depth=1 https://github.com/stevearc/overseer.nvim.git \
  "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/pack/overseer/start/overseer.nvim
```

</details>

## Setup

Somewhere in your init.lua you will need to call `overseer.setup()`.

```lua
require("overseer").setup({
  -- Default task strategy
  strategy = "terminal",
  -- Template modules to load
  templates = { "builtin" },
  -- When true, tries to detect a green color from your colorscheme to use for success highlight
  auto_detect_success_color = true,
  -- Configure the task list
  task_list = {
    -- Default detail level for tasks. Can be 1-3.
    default_detail = 1,
    -- max_width = {100, 0.2} means "the lesser of 100 columns or 20% of total"
    max_width = { 100, 0.2 },
    -- min_width = {40, 0.1} means "the greater of 40 columns or 10% of total"
    min_width = { 40, 0.1 },
    -- String that separates tasks
    separator = "────────────────────────────────────────",
    -- Default direction. Can be "left" or "right"
    direction = "left",
    bindings = {
      ["?"] = "ShowHelp",
      ["<CR>"] = "RunAction",
      ["<C-e>"] = "Edit",
      ["o"] = "Open",
      ["<C-v>"] = "OpenVsplit",
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
  -- TODO: explain these
  actions = {},
  -- Configure the floating window used for task templates that require input
  -- and the floating window used for editing tasks
  form = {
    border = "rounded",
    zindex = 40,
    min_width = 80,
    max_width = 0.9,
    min_height = 10,
    max_height = 0.9,
    -- Set any window options here (e.g. winhighlight)
    win_opts = {
      winblend = 10,
    },
  },
  -- Configure the floating window used for confirmation prompts
  confirm = {
    border = "rounded",
    zindex = 40,
    min_width = 80,
    max_width = 0.5,
    min_height = 10,
    max_height = 0.9,
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
      "result_exit_code",
      "on_result_notify",
      "on_restart_handler",
      "dispose_delay",
    },
    -- Used for templates that define a task that should remain running and
    -- restart on failure (e.g. a server or file-watching build process)
    default_persist = {
      "on_output_summarize",
      "result_exit_code",
      "on_result_notify",
      "on_restart_handler",
      "on_result_restart",
    },
    -- Used for tasks generated from the VS Code integration (tasks.json)
    default_vscode = {
      "default",
      "on_result_diagnostics",
      "on_result_diagnostics_quickfix",
    },
  },
  -- A list of components to preload on setup.
  -- Only matters if you want them to show up in the task editor.
  preload_components = {},
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

| Command                | arg              | description                                                         |
| ---------------------- | ---------------- | ------------------------------------------------------------------- |
| `OverseerOpen[!]`      | `left` | `right` | Open the overseer window. With `!` cursor stays in current window   |
| `OverseerClose`        |                  | Close the overseer window                                           |
| `OverseerToggle[!]`    | `left` | `right` | Toggle the overseer window. With `!` cursor stays in current window |
| `OverseerSaveBundle`   | `[name]`         | Serialize and save the current tasks to disk                        |
| `OverseerLoadBundle`   | `[name]`         | Load tasks that were saved to disk                                  |
| `OverseerDeleteBundle` | `[name]`         | Delete a saved task bundle                                          |
| `OverseerRunCmd`       | `[command]`      | Run a raw shell command                                             |
| `OverseerRun`          | `[name/tags]`    | Run a task from a template                                          |
| `OverseerBuild`        |                  | Open the task builder                                               |
| `OverseerQuickAction`  | `[action]`       | Run an action on the most recent task                               |
| `OverseerTaskAction`   |                  | Select a task to run an action on                                   |

## Running tasks

The easiest way to select and run a task is `:OverseerRun`. This will open a `vim.ui.select` dialog and allow the user to select a task. Once selected, if the task requires any [parameters](#parameters), it will prompt the user for input. Once all inputs are satisfied, the task is started.

If you want to customize how the tasks are searched, selected, or run, you can call `overseer.run_template` directly. Some examples:

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
overseer.run_template({name = "make", nostart = true}, function(task)
  -- do something with the task
end)
-- Run a task and immediately open the floating window
overseer.run_template({name = "make", action = 'open float'})
-- Run a task and always show the parameter prompt
overseer.run_template({name = "npm watch", prompt = "always"})
```

## Task list

TODO

## Third-party integrations

### Lualine

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
      unique = false,     -- Unique-ify task count by name
      name = nil,         -- List of task names to search for
      name_not = false,   -- When true, invert the name search
      status = nil,       -- List of task statuses to display
      status_not = false, -- When true, invert the status search
    } },
  },
})
```

### Neotest

There is a neotest strategy that functions the same as the default "integrated" strategy. To use it, simply pass it into your run options:

```lua
  neotest.run.run({ suite = true, strategy = "overseer" })
```

This will run the tests like usual, but the job running the tests will be managed by overseer.

You can customize the default components by setting the `default_neotest` component alias (when unset it maps to `default`).

```lua
require('overseer').setup({
  component_aliases = {
    default_neotest = {
      "on_output_summarize",
      "result_exit_code",
      "on_result_notify",
      "dispose_delay",
    },
  }
})
```

**Note**: Restarting the overseer task will rerun the tests, but the results will not be reported to neotest. This is due to technical limitations, and will hopefully be fixed in the future.

## Architecture

### Tasks

Tasks represent a single command that is run. They appear in the [task list](#task-list), where you can manage them (start/stop/restart/edit/open terminal). You can create them directly, either with `:OverseerBuild` or via the API `require('overseer.task').new()`.

Most of the time, however, you will find it most convenient to create them using [templates](#templates).

### Components

Tasks are built using an [entity component system](https://en.wikipedia.org/wiki/Entity_component_system). By itself, all a task does is run a command in a terminal. Components are used to add more functionality. There are components to display a summary of the output in the [task list](#task-list), to show a notification when the task finishes running, and to set the task results into neovim diagnostics.

Components are designed to be easy to remove, customize, or replace. If you want to customize some aspect or behavior of a task, it's likely that it will be done through components.

See [custom components](#custom-components) for how to customize them or define your own, and [components](doc/components.md) for a list of built-in components.

**Note**: both tasks and components are designed to be serializable. They avoid putting things like functions in their constructors, and as a result can easily be serialized and saved to disk.

### Templates

Templates provide a way to construct a task, along with other metadata that aid in selecting and starting that task. They are the primary way to define tasks for overseer, and they are what appears when you use the command `:OverseerRun`.

When you want to add custom tasks that you can run, templates are the way to go. See [custom tasks](#custom-tasks) for more.

## Customization

### Custom tasks

There are two ways to define a task for overseer.

**1) directly registering**

```lua
overseer.register_template({
  -- Template definition (see below)
})
```

**2) as a module**

Similar to [custom components](#custom-components), templates can be lazy-loaded from a module in the `overseer.template` namespace. It is recommended that you namespace your tasks inside of a folder (e.g. `overseer/template/myplugin/first_task.lua`, referenced as `myplugin.first_task`). To load them, you would pass the require path in setup:

```lua
overseer.setup({
  templates = { "builtin", "myplugin.first_task" },
})
```

If you have multiple templates that you would like to expose as a bundle, you can create an alias module. For example, put the following into `overseer/template/myplugin/init.lua`:

```lua
return { "first_task", "second_task" }
```

This is how `builtin` references all of the different built-in templates.

#### Template definition

The definition of a template looks like this:

```lua
{
  -- Required fields
  name = "Some Task",
  builder = function(params)
    -- This must return an overseer.TaskDefinition
    return {
      cmd = {'echo', 'hello', 'world'}
    }
  end,
  -- Optional fields
  desc = "Optional description of task",
  -- Tags can be used in overseer.run_template()
  tags = {overseer.TAG.BUILD},
  params = {
    -- TODO
  },
  -- Determines sort order when choosing tasks. Lower comes first.
  priority = 50,
  -- Add requirements for this template. If they are not met, the template will not be visible.
  -- All fields are optional.
  condition = {
    -- A string or list of strings
    -- Only matches when current buffer is one of the listed filetypes
    filetype = {"c", "cpp"},
    -- A string or list of strings
    -- Only matches when cwd is inside one of the listed dirs
    dir = "/home/user/my_project",
    -- Arbitrary logic for determining if task is available
    callback = function(search)
      print(vim.inspect(search))
      return true
    end,
  },
}
```

#### Template providers

Template providers are used to generate multiple templates dynamically. The main use case is generating one task per target (e.g. for a makefile), but can be used for any situation where you want the templates themselves to be generated at runtime.

Providers are created the same way templates are (with `overseer.register_template`, or by putting them in a module). The structure is as follows:

```lua
{
  generator = function(search)
    -- Return a list of templates
    -- See the built-in providers for make or npm for an example
    return {...}
  end,
  -- Optional. Same as template.condition
  condition = function(search)
    return true
  end,
}
```

### Actions

Actions can be performed on tasks by using the `RunAction` keybinding in the task list, or by the `OverseerQuickAction` and `OverseerTaskAction` commands. They are simply a custom function that will do something to or with a task.

Browse the set of built-in actions at [lua/overseer/task_list/actions.lua](../lua/overseer/task_list/actions.lua)

You can define your own or disable any of the built-in actions in the call to setup():

```lua
overseer.setup({
  actions = {
    ["My custom action"] = {
      desc = "This is an optional description. It may be omitted.",
      -- Optional function that will determine when this action is available
      condition = function(task)
        if task.name == "foobar" then
          return true
        else
          return false
        end
      end,
      run = function(task)
        -- Your custom logic here
      end,
    },

    -- Disable built-in actions by setting them to 'false'
    watch = false,
  },
})
```

### Custom components

When components are passed to a task (either from a template or a component alias), they can be specified as either a raw string (e.g. `"dispose_delay"`) or a table with configuration parameters (e.g. `{"dispose_delay", timeout = 10}`).

Components are lazy-loaded via requiring in the `overseer.component` namespace. For example, the `timeout` component is loaded from `lua/overseer/component/timeout.lua`. It is recommended that for plugins or personal use, you namespace your own components behind an additional directory. For example, place your component in `lua/overseer/component/myplugin/mycomponent.lua`, and reference it as `myplugin.mycomponent`.

The component definition should look like the following example:

```lua
return {
  desc = "Include a description of your component",
  -- Define parameters that can be passed in to the component
  params = {
    -- TODO
  },
  -- Optional, default true. Set to false to disallow editing this component in the task editor
  editable = true,
  -- Controls the serialization behavior when saving a task to disk.
  -- "exclude" will allow task to be serialized, but this component will be excluded.
  -- "fail" will prevent task from being serialized.
  serialize = nil,
  -- The params passed in will match the params defined above
  constructor = function(params)
    -- You may optionally define any of the methods below
    return {
      on_init = function(self, task)
        -- Called when the task is created
        -- This is a good place to initialize resources, if needed
      end,
      ---@return nil|boolean
      on_pre_start = function(self, task)
        -- Return false to prevent task from starting
      end,
      on_start = function(self, task)
        -- Called when the task is started
      end,
      ---@param soft boolean When true, the components are being reset but the *task* is not. This is used to support commands that are watching the filesystem and rerunning themselves on file change.
      on_reset = function(self, task, soft)
        -- Called when the task is reset to run again
      end,
      ---@param status overseer.Status Can be RUNNING (we can set results without completing the task), CANCELED, FAILURE, or SUCCESS
      ---@param result table A result table.
      on_result = function(self, task, status, result)
        -- Called when a component has results to set. Usually this is after the command has completed, but certain types of tasks may wish to set a result while still running.
      end,
      ---@param status overseer.Status Can be CANCELED, FAILURE, or SUCCESS
      ---@param result table A result table.
      on_complete = function(self, task, status, result)
        -- Called when the task has reached a completed state.
      end,
      ---@param status overseer.Status Can be RUNNING (we can set results without completing the task), CANCELED, FAILURE, or SUCCESS
      on_status = function(self, task, status)
        -- Called when the task status changes
      end,
      ---@param data string[] Output of process. See :help channel-lines
      on_output = function(self, task, data)
        -- Called when there is output from the task
      end,
      ---@param lines string[] Completed lines of output, with ansi codes removed.
      on_output_lines = function(self, task, lines)
        -- Called when there is output from the task
        -- Usually easier to deal with than using on_output directly.
      end,
      on_request_restart = function(self, task)
        -- Called when an action requests that the task be restarted
      end,
      ---@param code number The process exit code
      on_exit = function(self, task, code)
        -- Called when the task command has completed
      end,
      on_dispose = function(self, task)
        -- Called when the task is disposed
        -- Will be called IFF on_init was called, and will be called exactly once.
        -- This is a good place to free resources (e.g. timers, files, etc)
      end,
      ---@param lines string[] The list of lines to render into
      ---@param highlights table[] List of highlights to apply after rendering
      ---@param detail number The detail level of the task. Ranges from 1 to 3.
      render = function(self, task, lines, highlights, detail)
        -- Called from the task list. This can be used to display information there.
        table.insert(lines, "Here is a line of output")
        -- The format is {highlight_group, lnum, col_start, col_end}
        table.insert(highlights, {'Title', #lines, 0, -1})
      end,
    }
  end,
}
```

#### Task result

A note on the Task result table: there is technically no schema for it, as the only things that interact with it are components and actions. However, there are a couple of built-in uses for specific keys of the table:

**diagnostics**: This key is used for diagnostics. It should be a list of quickfix items (see `:help setqflist`) \
**error**: This key will be set when there is an internal overseer error when running the task

### Parameters

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

### Highlights

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

## VS Code tasks

Overseer can read [VS Code's tasks.json file](https://code.visualstudio.com/docs/editor/tasks). By default, VS Code tasks will show up when you `:OverseerRun`. Overseer is _nearly_ at feature parity, but it's not quite (nor will it ever be) at 100%.

Supported features:

- Task types: process, shell, typescript, node
- [Standard variables](https://code.visualstudio.com/docs/editor/tasks#_variable-substitution)
- [Input variables](https://code.visualstudio.com/docs/editor/variables-reference#_input-variables) (e.g. `${input:variableID}`)
- [Problem matchers](https://code.visualstudio.com/docs/editor/tasks#_processing-task-output-with-problem-matchers)
- Built-in library of problem matchers and patterns (e.g. `$tsc` and `$jshint-stylish`)
- [Compound tasks](https://code.visualstudio.com/docs/editor/tasks#_compound-tasks) (including `dependsOrder = sequence`)
- [Background tasks](https://code.visualstudio.com/docs/editor/tasks#_background-watching-tasks)
- `group` (sets template tag; supports `BUILD`, `TEST`, and `CLEAN`) and `isDefault` (sets priority)
- [Operating system specific properties](https://code.visualstudio.com/docs/editor/tasks#_operating-system-specific-properties)

Unsupported features:

- task types: gulp, grunt, jake
- shell-specific quoting
- Specifying a custom shell to use
- `problemMatcher.fileLocation`
- `${workspacefolder:*}` variables
- `${config:*}` variables
- `${command:*}` variables
- The `${defaultBuildTask}` variable
- Custom problem matcher patterns may fail due to differences between JS and vim regex (notably vim regex doesn't support non-capturing groups `(?:.*)` or character classes inside of brackets `[\d\s]`)
- [Output behavior](https://code.visualstudio.com/docs/editor/tasks#_output-behavior) (probably not going to support this)
- [Run behavior](https://code.visualstudio.com/docs/editor/tasks#_run-behavior) (probably not going to support this)

## Alternatives

TODO

- [yabs.nvim](https://github.com/pianocomposer321/yabs.nvim)
- [toggletasks.nvim](https://github.com/jedrzejboczar/toggletasks.nvim)
- [vs-tasks.nvim](https://github.com/EthanJWright/vs-tasks.nvim)
- [tasks.nvim](https://github.com/GustavoKatel/tasks.nvim)
- [tasks.nvim](https://github.com/mg979/tasks.vim)

## FAQ

**Q: Why do my tasks disappear after a while?**

The default behavior is for completed tasks to get _disposed_ after a 5 minute timeout. This frees their resources and removes them from the task list. You can change this by editing the `component_aliases` definition to either tweak the timeout (`{"dispose_delay", timeout = 900}`), or delete the "dispose_delay" component entirely. In that case, tasks will stick around until manually disposed.

**Q: How can I debug when something goes wrong?**

The `overseer.log` file can be found at `:echo stdpath('log')` or `:echo stdpath('cache')`. If you need, you can crank up the detail of the logs by adjusting the level:

```lua
overseer.setup({
  log = {
    {
      type = "file",
      filename = "overseer.log",
      level = vim.log.levels.DEBUG, -- or TRACE for max verbosity
    },
  },
})
```
