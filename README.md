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
  - [Neotest](doc/third_party.md#neotest)
  - [DAP](doc/third_party.md#dap)
  - [Session managers](doc/third_party.md#session-managers)
- [Recipes](#recipes)
  - [Restart last task](doc/recipes.md#restart-last-task)
  - [Run shell scripts in the current directory](doc/recipes.md#run-shell-scripts-in-the-current-directory)
  - [Directory-local tasks with nvim-config-local](doc/recipes.md#directory-local-tasks-with-nvim-config-local)
  - [:Make similar to vim-dispatch](doc/recipes.md#make-similar-to-vim-dispatch)
- [Reference](#reference)
  - [Setup options](doc/reference.md#setup-options)
  - [Commands](doc/reference.md#commands)
  - [Highlight groups](doc/reference.md#highlight-groups)
  - [Lua API](doc/reference.md#lua-api)
  - [Components](doc/reference.md#components)
  - [Parsers](doc/reference.md#parsers)
  - [Parameters](doc/reference.md#parameters)
- [Screenshots](#screenshots)

<!-- /TOC -->

## Features

- Built-in support for many task frameworks (make, npm, cargo, `.vscode/tasks.json`, etc)
- Simple integration with vim.diagnostics and quickfix
- UI for viewing and managing tasks
- Quick controls for common actions (restart task, rerun on save, or user-defined functions)
- Extreme customizability. Very easy to attach custom logic to tasks
- Define and run complex multi-stage workflows
- Support for `preLaunchTask` when used with [nvim-dap](https://github.com/mfussenegger/nvim-dap)

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

## Quick start

Add the following to your init.lua

```lua
require('overseer').setup()
```

To get started, all you need to know is `:OverseerRun` to select and start a task, and `:OverseerToggle` to open the task list.

https://user-images.githubusercontent.com/506791/189036898-05edcd62-42e7-4bbb-ace2-746b7c8c567b.mp4

If you don't see any tasks from `:OverseerRun`, it might mean that your task runner is not yet supported. There is currently support for VS Code tasks, make, npm, cargo, and some others. If yours is not supported, ([request support here](https://github.com/stevearc/overseer.nvim/issues/new/choose)).

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
- [Neotest](doc/third_party.md#neotest)
- [DAP](doc/third_party.md#dap)
- [Session managers](doc/third_party.md#session-managers)
  - [resession.nvim](doc/third_party.md#resessionnvim)
  - [Other session managers](doc/third_party.md#other-session-managers)

## Recipes

- [Restart last task](doc/recipes.md#restart-last-task)
- [Run shell scripts in the current directory](doc/recipes.md#run-shell-scripts-in-the-current-directory)
- [Directory-local tasks with nvim-config-local](doc/recipes.md#directory-local-tasks-with-nvim-config-local)
- [:Make similar to vim-dispatch](doc/recipes.md#make-similar-to-vim-dispatch)

## Reference

- [Setup options](doc/reference.md#setup-options)
- [Commands](doc/reference.md#commands)
- [Highlight groups](doc/reference.md#highlight-groups)
- [Lua API](doc/reference.md#lua-api)
  - [setup(opts)](doc/reference.md#setupopts)
  - [on_setup(callback)](doc/reference.md#on_setupcallback)
  - [new_task(opts)](doc/reference.md#new_taskopts)
  - [toggle(opts)](doc/reference.md#toggleopts)
  - [open(opts)](doc/reference.md#openopts)
  - [close()](doc/reference.md#close)
  - [list_task_bundles()](doc/reference.md#list_task_bundles)
  - [load_task_bundle(name, opts)](doc/reference.md#load_task_bundlename-opts)
  - [save_task_bundle(name, tasks, opts)](doc/reference.md#save_task_bundlename-tasks-opts)
  - [delete_task_bundle(name)](doc/reference.md#delete_task_bundlename)
  - [list_tasks(opts)](doc/reference.md#list_tasksopts)
  - [run_template(opts, callback)](doc/reference.md#run_templateopts-callback)
  - [preload_task_cache(opts, cb)](doc/reference.md#preload_task_cacheopts-cb)
  - [clear_task_cache(opts)](doc/reference.md#clear_task_cacheopts)
  - [run_action(task, name)](doc/reference.md#run_actiontask-name)
  - [wrap_template(base, override, default_params)](doc/reference.md#wrap_templatebase-override-default_params)
  - [add_template_hook(opts, hook)](doc/reference.md#add_template_hookopts-hook)
  - [remove_template_hook(opts, hook)](doc/reference.md#remove_template_hookopts-hook)
  - [register_template(defn)](doc/reference.md#register_templatedefn)
  - [load_template(name)](doc/reference.md#load_templatename)
- [Components](doc/reference.md#components)
- [Parsers](doc/reference.md#parsers)
- [Parameters](doc/reference.md#parameters)

## Screenshots

https://user-images.githubusercontent.com/506791/180620617-2b1bb0a8-5f39-4936-97c2-04c92f1e2974.mp4
