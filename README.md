# overseer.nvim

A task runner and job management plugin for Neovim

<!-- TOC -->

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Tutorials](#tutorials)
  - [Build a C++ file](doc/tutorials.md#build-a-c-file)
  - [Run a file on save](doc/tutorials.md#run-a-file-on-save)
- [Guides](#guides)
  - [Custom tasks](doc/guides.md#custom-tasks)
  - [Actions](doc/guides.md#actions)
  - [Custom components](doc/guides.md#custom-components)
  - [Customizing built-in tasks](doc/guides.md#customizing-built-in-tasks)
  - [Parsing output](doc/guides.md#parsing-output)
  - [Running tasks sequentially](doc/guides.md#running-tasks-sequentially)
  - [VS Code tasks](doc/guides.md#vs-code-tasks)
- [Explanation](#explanation)
  - [Architecture](doc/explanation.md#architecture)
  - [Task list](doc/explanation.md#task-list)
  - [Task editor](doc/explanation.md#task-editor)
  - [Alternatives](doc/explanation.md#alternatives)
  - [FAQ](doc/explanation.md#faq)
- [Third-party integrations](#third-party-integrations)
  - [Lualine](doc/third_party.md#lualine)
  - [Heirline](doc/third_party.md#heirline)
  - [Neotest](doc/third_party.md#neotest)
  - [DAP](doc/third_party.md#dap)
  - [Session managers](doc/third_party.md#session-managers)
- [Recipes](#recipes)
  - [Run a quick command like with `:!` or `:term`](doc/recipes.md#run-a-quick-command-like-with--or-term)
  - [Restart last task](doc/recipes.md#restart-last-task)
  - [Run shell scripts in the current directory](doc/recipes.md#run-shell-scripts-in-the-current-directory)
  - [Directory-local tasks with exrc](doc/recipes.md#directory-local-tasks-with-exrc)
  - [Asynchronous :Make similar to vim-dispatch](doc/recipes.md#asynchronous-make-similar-to-vim-dispatch)
  - [Asynchronous :Grep command](doc/recipes.md#asynchronous-grep-command)
  - [Create a window that displays the most recent task output](doc/recipes.md#create-a-window-that-displays-the-most-recent-task-output)
- [Reference](#reference)
  - [Setup options](doc/reference.md#setup-options)
  - [Commands](doc/reference.md#commands)
  - [Highlight groups](doc/reference.md#highlight-groups)
  - [Lua API](doc/reference.md#lua-api)
  - [Components](doc/reference.md#components)
  - [Strategies](doc/reference.md#strategies)
  - [Parameters](doc/reference.md#parameters)
- [Screenshots](#screenshots)

<!-- /TOC -->

## Features

- Built-in support for many task frameworks (make, npm, cargo, `.vscode/tasks.json`, etc)
- Simple integration with `vim.diagnostic` and quickfix
- UI for viewing and managing tasks
- Quick controls for common actions (restart task, rerun on save, or user-defined functions)
- Extreme customizability. Very easy to attach custom logic to tasks
- Define and run complex multi-stage workflows
- Support for `preLaunchTask` when used with [nvim-dap](https://github.com/mfussenegger/nvim-dap)

## Requirements

- Neovim 0.11+ (for older versions, use a [nvim-0.x branch](https://github.com/stevearc/overseer.nvim/branches))

## Installation

overseer supports all the usual plugin managers

<details>
  <summary>lazy.nvim</summary>

```lua
{
  'stevearc/overseer.nvim',
  ---@module 'overseer'
  ---@type overseer.SetupOpts
  opts = {},
}
```

</details>

<details>
  <summary>Packer</summary>

```lua
require("packer").startup(function()
  use({
    "stevearc/overseer.nvim",
    config = function()
      require("overseer").setup()
    end,
  })
end)
```

</details>

<details>
  <summary>Paq</summary>

```lua
require("paq")({
  { "stevearc/overseer.nvim" },
})
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

## Quick start

Add the following to your init.lua

```lua
require("overseer").setup()
```

To get started, all you need to know is `:OverseerRun` to select and start a task, and `:OverseerToggle` to open the task list.

https://user-images.githubusercontent.com/506791/189036898-05edcd62-42e7-4bbb-ace2-746b7c8c567b.mp4

If you don't see any tasks from `:OverseerRun`, it might mean that your task runner is not yet supported. There is currently support for VS Code tasks, make, npm, cargo, and some others.

If you want to define custom tasks for your project, I'd recommend starting with [the tutorials](doc/tutorials.md).

## Tutorials

- [Build a C++ file](doc/tutorials.md#build-a-c-file)
- [Run a file on save](doc/tutorials.md#run-a-file-on-save)

## Guides

- [Custom tasks](doc/guides.md#custom-tasks)
  - [Template definition](doc/guides.md#template-definition)
  - [Template providers](doc/guides.md#template-providers)
- [Actions](doc/guides.md#actions)
- [Custom components](doc/guides.md#custom-components)
  - [Component aliases](doc/guides.md#component-aliases)
  - [Task result](doc/guides.md#task-result)
- [Customizing built-in tasks](doc/guides.md#customizing-built-in-tasks)
- [Parsing output](doc/guides.md#parsing-output)
- [Running tasks sequentially](doc/guides.md#running-tasks-sequentially)
- [VS Code tasks](doc/guides.md#vs-code-tasks)

## Explanation

- [Architecture](doc/explanation.md#architecture)
  - [Tasks](doc/explanation.md#tasks)
  - [Components](doc/explanation.md#components)
  - [Templates](doc/explanation.md#templates)
- [Task list](doc/explanation.md#task-list)
- [Task editor](doc/explanation.md#task-editor)
- [Alternatives](doc/explanation.md#alternatives)
- [FAQ](doc/explanation.md#faq)

## Third-party integrations

- [Lualine](doc/third_party.md#lualine)
- [Heirline](doc/third_party.md#heirline)
- [Neotest](doc/third_party.md#neotest)
- [DAP](doc/third_party.md#dap)
- [Session managers](doc/third_party.md#session-managers)
  - [resession.nvim](doc/third_party.md#resessionnvim)
  - [Other session managers](doc/third_party.md#other-session-managers)

## Recipes

- [Run a quick command like with `:!` or `:term`](doc/recipes.md#run-a-quick-command-like-with--or-term)
- [Restart last task](doc/recipes.md#restart-last-task)
- [Run shell scripts in the current directory](doc/recipes.md#run-shell-scripts-in-the-current-directory)
- [Directory-local tasks with exrc](doc/recipes.md#directory-local-tasks-with-exrc)
- [Asynchronous :Make similar to vim-dispatch](doc/recipes.md#asynchronous-make-similar-to-vim-dispatch)
- [Asynchronous :Grep command](doc/recipes.md#asynchronous-grep-command)
- [Create a window that displays the most recent task output](doc/recipes.md#create-a-window-that-displays-the-most-recent-task-output)

## Reference

- [Setup options](doc/reference.md#setup-options)
- [Commands](doc/reference.md#commands)
- [Highlight groups](doc/reference.md#highlight-groups)
- [Lua API](doc/reference.md#lua-api)
  - [setup(opts)](doc/reference.md#setupopts)
  - [new_task(opts)](doc/reference.md#new_taskopts)
  - [toggle(opts)](doc/reference.md#toggleopts)
  - [open(opts)](doc/reference.md#openopts)
  - [close()](doc/reference.md#close)
  - [list_tasks(opts)](doc/reference.md#list_tasksopts)
  - [run_task(opts, callback)](doc/reference.md#run_taskopts-callback)
  - [preload_task_cache(opts, cb)](doc/reference.md#preload_task_cacheopts-cb)
  - [clear_task_cache(opts)](doc/reference.md#clear_task_cacheopts)
  - [run_action(task, name)](doc/reference.md#run_actiontask-name)
  - [add_template_hook(opts, hook)](doc/reference.md#add_template_hookopts-hook)
  - [remove_template_hook(opts, hook)](doc/reference.md#remove_template_hookopts-hook)
  - [register_template(defn)](doc/reference.md#register_templatedefn)
  - [register_alias(name, components, override)](doc/reference.md#register_aliasname-components-override)
  - [create_task_output_view(winid, opts)](doc/reference.md#create_task_output_viewwinid-opts)
- [Components](doc/reference.md#components)
- [Strategies](doc/reference.md#strategies)
- [Parameters](doc/reference.md#parameters)

## Screenshots

https://user-images.githubusercontent.com/506791/180620617-2b1bb0a8-5f39-4936-97c2-04c92f1e2974.mp4
