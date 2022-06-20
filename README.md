# overseer.nvim

A task runner and job management plugin for Neovim

Will be updated & history overwritten if it's ever ready for release

TODO screenshots

- [ ] Add more comments
- [ ] Refactor config window options
- [ ] Dynamic window sizing for task editor
- [ ] _maybe_ support other run strategies besides terminal
- [ ] Basic Readme
- [ ] Vim help docs
- [ ] Architecture doc (Template / Task / Component / Actions)
- [ ] Extension doc (how to make your own template/component)
- [ ] Guide for common functionality

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
- [Highlight](#highlight)
- [VS Code tasks](#vs-code-tasks)

## Features

TODO brief overview of features and use cases

- VS Code tasks
- Auto-detection of common targets (e.g. npm, make, tox)
- etc

## Requirements

- Neovim 0.7+
- (optional) patches for `vim.ui` (e.g. [dressing.nvim](https://github.com/stevearc/dressing.nvim)). Provides nicer UI for input and selection.
- (optional) [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim). When used with [dressing.nvim](https://github.com/stevearc/dressing.nvim) provides best selection UI.

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
  sidebar = {
    -- Default detail level for tasks. Can be 1-3.
    default_detail = 1,
    -- max_width = {100, 0.2} means "the lesser of 100 columns or 20% of total"
    max_width = { 100, 0.2 },
    -- min_width = {40, 0.1} means "the greater of 40 columns or 10% of total"
    min_width = { 40, 0.1 },
    -- String the separates tasks
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
    min_width = 80,
    max_width = 0.9,
    min_height = 10,
    max_height = 0.9,
    winblend = 10,
  },
  -- Configuration for task and test result floating windows
  float_win = {
    padding = 2,
    border = "rounded",
    winblend = 10,
  },
  -- Aliases for bundles of components. Redefine the builtins, or create your own.
  component_aliases = {
    -- Most tasks are initialized with the default components
    default = {
      "on_output_summarize",
      "result_exit_code",
      "on_result_notify",
      "on_rerun_handler",
      "dispose_delay",
    },
    -- Used for templates that define a task that should remain running and
    -- restart on failure (e.g. a server or file-watching build process)
    default_persist = {
      "on_output_summarize",
      "result_exit_code",
      "on_result_notify",
      "on_rerun_handler",
      "on_result_rerun",
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

| Command                | arg           | description                             |
| ---------------------- | ------------- | --------------------------------------- |
| `OverseerOpen`         |               | Open the overseer window                |
| `OverseerClose`        |               | Close the overseer window               |
| `OverseerToggle`       |               | Open or close the overseer window       |
| `OverseerSaveBundle`   | `[name]`      | Serialize the current tasks to disk     |
| `OverseerLoadBundle`   | `[name]`      | Load tasks that were serialized to disk |
| `OverseerDeleteBundle` | `[name]`      | Delete a saved task bundle              |
| `OverseerRunCmd`       | `[command]`   | Run a raw shell command                 |
| `OverseerRun`          | `[name/tags]` | Run a task from a template              |
| `OverseerBuild`        |               | Open the task builder                   |
| `OverseerQuickAction`  | `[name]`      | Run an action on the most recent task   |
| `OverseerTaskAction`   |               | Select a task to run an action on       |

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

Overseer can read [VS Code's task file](https://code.visualstudio.com/docs/editor/tasks). By default, VS Code tasks will show up when you `:OverseerRun`. Overseer is _nearly_ at feature parity, but it's not quite (nor will it ever be) at 100%.

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
- [Output behavior](https://code.visualstudio.com/docs/editor/tasks#_output-behavior) (probably not going to support this)
- [Run behavior](https://code.visualstudio.com/docs/editor/tasks#_run-behavior) (probably not going to support this)
