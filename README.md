# overseer.nvim

A task runner and job management plugin for Neovim

**PRE-ALPHA**

History will be overwritten once it's ready for release

TODO screenshots

- [ ] Notification component that uses system notif IFF vim is not focused
- [ ] Notification components should maybe use on_complete?
- [ ] Custom positioning of task list (right, left, float)
- [ ] Somewhere in config to add/change keybinds for task list
- [ ] Dynamic window sizing for task editor
- [ ] support other run strategies besides terminal
- [ ] Finish guide.md
- [ ] Finish components.md
- [ ] Document parsers & parser debugging
- [ ] Document parser on result_exit_code
- [ ] Remaining README todos
- [ ] Extension doc (how to make your own template/component)
- [ ] Vim help docs
- [ ] vim.fn.confirm/vim.ui.confirm
- [ ] Comparison to alternatives?
  - [yabs](https://github.com/pianocomposer321/yabs.nvim)
  - [toggletasks](https://github.com/jedrzejboczar/toggletasks.nvim)
  - [vs-tasks](https://github.com/EthanJWright/vs-tasks.nvim)

---

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Setup](#setup)
- [Commands](#commands)
- [Task list](#task-list)
- [Third-party integrations](#third-party-integrations)
  - [Lualine](#lualine)
  - [Neotest](#neotest)
- [Architecture](#architecture)
- [Highlight](#highlight)
- [VS Code tasks](#vs-code-tasks)

## Features

Overseer was built to address two generic needs:

1. I want a way to easily run and manage commands relevant to my current project
1. I want to be able to integrate the results of those commands with neovim

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
  },
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
})
```

## Commands

| Command                | arg           | description                                                                  |
| ---------------------- | ------------- | ---------------------------------------------------------------------------- |
| `OverseerOpen[!]`      |               | Open the overseer window. With `[!]` cursor stays in current window          |
| `OverseerClose`        |               | Close the overseer window                                                    |
| `OverseerToggle[!]`    |               | Open or close the overseer window. With `[!]` cursor stays in current window |
| `OverseerSaveBundle`   | `[name]`      | Serialize the current tasks to disk                                          |
| `OverseerLoadBundle`   | `[name]`      | Load tasks that were serialized to disk                                      |
| `OverseerDeleteBundle` | `[name]`      | Delete a saved task bundle                                                   |
| `OverseerRunCmd`       | `[command]`   | Run a raw shell command                                                      |
| `OverseerRun`          | `[name/tags]` | Run a task from a template                                                   |
| `OverseerBuild`        |               | Open the task builder                                                        |
| `OverseerQuickAction`  | `[name]`      | Run an action on the most recent task                                        |
| `OverseerTaskAction`   |               | Select a task to run an action on                                            |

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

TODO

## Architecture

### Tasks

Tasks represent a single command that is run. They appear in the [task list](#task-list), where you can manage them (start/stop/restart/edit/open terminal). You can create them directly, either with `OverseerBuild` or via the API `require('overseer.task').new()`.

Most of the time, however, you will find it most convenient to create them using [templates](#templates).

### Components

Tasks are built using an [entity component system](https://en.wikipedia.org/wiki/Entity_component_system). By itself, all a task does is run a command in a terminal. Components are used to add more functionality. There are components to display a summary of the output in the [task list](#task-list), to show a notification when the task finishes running, and to set the task results into neovim diagnostics.

Components are designed to be easy to remove, customize, or replace. If you want to customize some aspect or behavior of a task, it's likely that it will be done through components.

See [components](doc/components.md) for more information on built-in components and how to create your own.

### Templates

TODO

## Highlight

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

- task types: gulp, grunt, and jake
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
