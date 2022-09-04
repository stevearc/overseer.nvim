# Explanation

<!-- TOC -->

- [Architecture](#architecture)
- [Tasks](#tasks)
- [Components](#components)
- [Templates](#templates)
- [Task list](#task-list)
- [Task editor](#task-editor)
- [Alternatives](#alternatives)
- [FAQ](#faq)

<!-- /TOC -->

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

## Task list

![Screenshot from 2022-07-22 08-44-37](https://user-images.githubusercontent.com/506791/180475623-1e9a9612-5a93-4520-a9bc-4e12b0496411.png)

Control the task list with `:OverseerOpen`, `:OverseerClose`, and `:OverseerToggle`.

The task list displays all tasks that have been created. It shows the task status, name, and a
summary of the task output (controlled by the `on_output_summarize` component). You can show more or
less detail for a single task with `<C-l>` and `<C-h>` (by default), or for all tasks with `L` and
`H`.

`?` will show you a list of all the keybindings, and `<CR>` will open up a menu of all
[actions](#actions) that you can perform on the selected task.

When a task is disposed, it will be removed from the task list. By default, tasks will be disposed 5
minutes after they finish running (controlled by the `on_complete_dispose` component).

## Task editor

<img width="515" alt="Screen Shot 2022-07-16 at 9 57 43 AM" src="https://user-images.githubusercontent.com/506791/179364674-526c8cbc-0cd8-48b0-ad68-3140c10178eb.png">

The task editor allows you to change the components on a task by hand. You shouldn't need to do this
often (if you find yourself frequently making the same edits, consider turning that into an
[action](#actions)), but it can be useful for experimentation and tweaking values on the fly.

There are two ways to get to the task editor: `:OverseerBuild` will open it on a new task, and for
existing tasks (that are not running) you can use the `edit` action.

For the most part you can edit the values like a normal buffer, but there is a lot of magic involved
to produce a "form-like" experience. For enum fields, you can autocomplete the possible values with
omnicomplete (`<C-x><C-o>`). To delete a component, just delete its name (`dd` works fine). To add a
new component, create a blank line (I typically use `o`)

## Alternatives

There are several other job/task plugins in the neovim ecosystem. To me, the main differentiating features that overseer offers are **unparalleled extensibility** and the **most complete support for VS Code's `tasks.json`** format. If you're still shopping around, these are the others that I'm aware of:

- [asynctasks.vim](https://github.com/skywind3000/asynctasks.vim) - Modern Task System for Project Building, Testing and Deploying
- [async.vim](https://github.com/prabirshrestha/async.vim) - normalize async job control api for vim and neovim
- [vim-dispatch](https://github.com/tpope/vim-dispatch) - Asynchronous build and test dispatcher
- [yabs.nvim](https://github.com/pianocomposer321/yabs.nvim) - Yet Another Build System/Code Runner for Neovim
- [toggletasks.nvim](https://github.com/jedrzejboczar/toggletasks.nvim) - Neovim task runner: JSON/YAML + toggleterm.nvim + telescope.nvim
- [vs-tasks.nvim](https://github.com/EthanJWright/vs-tasks.nvim) - A telescope plugin that runs tasks similar to VS Code's task implementation
- [tasks.nvim](https://github.com/GustavoKatel/tasks.nvim) - Yet another task runner/manager for Neovim
- [tasks.nvim](https://github.com/mg979/tasks.vim) - Async jobs and tasks

## FAQ

**Q: Why do my tasks disappear after a while?**

The default behavior is for completed tasks to get _disposed_ after a 5 minute timeout. This frees their resources and removes them from the task list. You can change this by editing the `component_aliases` definition to tweak the timeout (`{"on_complete_dispose", timeout = 900}`), only dispose succeeded/failed tasks (`{"on_complete_dispose", statuses = {"SUCCESS"}}`), or delete the "on_complete_dispose" component entirely. In that case, tasks will stick around until manually disposed.

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

**Q: Can I use this to asynchronously lint my files on save?**

You absolutely can. All the pieces are here to build something like ALE, it just needs the configs for different lint tools. Personally, I think that the existing plugin ecosystem has solved this sufficiently well and I don't see a value add from building _another_ on top of overseer. I'm using [null-ls](https://github.com/jose-elias-alvarez/null-ls.nvim) in my own config and think it's great.
