# Guides

<!-- TOC -->

- [Custom tasks](#custom-tasks)
  - [Template definition](#template-definition)
  - [Template providers](#template-providers)
- [Actions](#actions)
- [Custom components](#custom-components)
  - [Task result](#task-result)
- [Customizing built-in tasks](#customizing-built-in-tasks)
- [Parsing output](#parsing-output)
- [Running tasks sequentially](#running-tasks-sequentially)
- [VS Code tasks](#vs-code-tasks)

<!-- /TOC -->

## Custom tasks

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
-- You can also load them separately from setup
overseer.load_template("myplugin.second_task")
```

If you have multiple templates that you would like to expose as a bundle, you can create an alias module. For example, put the following into `overseer/template/myplugin/init.lua`:

```lua
return { "first_task", "second_task" }
```

This is how `builtin` references all of the different built-in templates.

### Template definition

The definition of a template looks like this:

```lua
{
  -- Required fields
  name = "Some Task",
  builder = function(params)
    -- This must return an overseer.TaskDefinition
    return {
      -- cmd is the only required field
      cmd = {'echo'},
      -- additional arguments for the cmd
      args = {"hello", "world"},
      -- the name of the task (defaults to the cmd of the task)
      name = "Greet",
      -- set the working directory for the task
      cwd = "/tmp",
      -- additional environment variables
      env = {
        VAR = "FOO",
      },
      -- the list of components or component aliases to add to the task
      components = {"my_custom_component", "default"},
      -- arbitrary table of data for your own personal use
      metadata = {
        foo = "bar",
      },
    }
  end,
  -- Optional fields
  desc = "Optional description of task",
  -- Tags can be used in overseer.run_template()
  tags = {overseer.TAG.BUILD},
  params = {
    -- See :help overseer.params
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

### Template providers

Template providers are used to generate multiple templates dynamically. The main use case is generating one task per target (e.g. for a makefile), but can be used for any situation where you want the templates themselves to be generated at runtime.

Providers are created the same way templates are (with `overseer.register_template`, or by putting them in a module). The structure is as follows:

```lua
{
  generator = function(search, cb)
    -- Pass a list of templates to the callback
    -- See the built-in providers for make or npm for an example
    cb({...})
  end,
  -- Optional. Same as template.condition
  condition = function(search)
    return true
  end,
}
```

## Actions

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
  -- You can optionally add keymaps to run your action in the task list
  -- It will always be available in the "RunAction" menu, but it may be
  -- worth mapping it directly if you use it often.
  task_list = {
    bindings = {
      ['P'] = '<CMD>OverseerQuickAction My custom action<CR>',
    }
  }
})
```

## Custom components

When components are passed to a task (either from a template or a component alias), they can be specified as either a raw string (e.g. `"on_complete_dispose"`) or a table with configuration parameters (e.g. `{"on_complete_dispose", timeout = 10}`).

Components are lazy-loaded via requiring in the `overseer.component` namespace. For example, the `timeout` component is loaded from `lua/overseer/component/timeout.lua`. It is _recommended_ that for plugins or personal use, you namespace your own components behind an additional directory. For example, place your component in `lua/overseer/component/myplugin/mycomponent.lua`, and reference it as `myplugin.mycomponent`.

Paths given are all relative to any runtimepath (`:help rtp`), so in practice it's probably easiest to put it in `~/.config/nvim`. The full path to your custom component would then become `~/.config/nvim/lua/overseer/component/myplugin/mycomponent.lua`.

The component definition should look like the following example:

```lua
return {
  desc = "Include a description of your component",
  -- Define parameters that can be passed in to the component
  params = {
    -- See :help overseer.params
  },
  -- Optional, default true. Set to false to disallow editing this component in the task editor
  editable = true,
  -- When false, don't serialize this component when saving a task to disk
  serializable = true,
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
      ---@return table
      on_pre_result = function(self, task)
        -- Called when the task is finalizing.
        -- Return a map-like table value here to merge it into the task result.
        return {foo = {"bar", "baz"}}
      end,
      ---@param result table A result table.
      on_result = function(self, task, result)
        -- Called when a component has results to set. Usually this is after the command has completed, but certain types of tasks may wish to set a result while still running.
      end,
      ---@param status overseer.Status Can be CANCELED, FAILURE, or SUCCESS
      ---@param result table A result table.
      on_complete = function(self, task, status, result)
        -- Called when the task has reached a completed state.
      end,
      ---@param status overseer.Status
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

### Task result

A note on the Task result table: there is technically no schema for it, as the only things that interact with it are components and actions. However, there are a couple of built-in uses for specific keys of the table:

**diagnostics**: This key is used for diagnostics. It should be a list of quickfix items (see `:help setqflist`) \
**error**: This key will be set when there is an internal overseer error when running the task

## Customizing built-in tasks

You may wish to customize the built-in task definitions, or tasks from another plugin. The simplest way to do this is using the [add_template_hook](reference.md#add_template_hookopts-hook) function. This allows you to run a function on the task definition (the arguments passed to [new_task](reference.md#new_taskopts)) and process it however you like. A common use case would be to add a component or modify the environment variables while in a specific project:

```lua
overseer.add_template_hook({
  dir = "/path/to/my/project",
  module = "^cargo$",
}, function(task_defn, util)
  util.add_component(task_defn, { "on_output_quickfix", open = true })
end)
```

## Parsing output

The primary way of parsing output with overseer is the `on_output_parse` component.

```lua
-- Definition of a component that parses output in the form of:
-- /path/to/file.txt:123: This is a message
-- You would typically use this in the components list of a task definition returned by a template
{"on_output_parse", parser = {
  -- Put the parser results into the 'diagnostics' field on the task result
  diagnostics = {
    -- Extract fields using lua patterns
    { "extract", "^([^%s].+):(%d+): (.+)$", "filename", "lnum", "text" },
  }
}}
```

This is a simple example, but the parser library is flexible enough to parse nearly any output format. See more detailed documentation in [the parsers doc](parsers.md).

You can of course create your own components to parse output leveraging the `on_output` or `on_output_lines` methods. The integration should be straightforward; see [on_output_parse.lua](../lua/overseer/component/on_output_parse.lua) to see how the built-in component leverages these methods.

## Running tasks sequentially

There are currently two ways to get tasks to run sequentially. The first is by using the [dependencies](components.md#dependencies) component. For example, if you wanted to create a `npm serve` task that runs `npm build` first, you could create it like so:

```lua
overseer.run_template({name = 'npm serve', autostart = false}, function(task)
  if task then
    task:add_component({'dependencies', task_names = {
      'npm build',
      -- You can also pass in params to the task
      {'shell', cmd = 'sleep 10'},
    }, sequential = true})
    task:start()
  end
end)
```

Another approach to running tasks in a specific order is to use the [orchestrator](../lua/overseer/strategy/orchestrator.lua) strategy. This creates a single "orchestration" task that is responsible for running the other tasks in the correct order. You can create it like so:

```lua
local task = overseer.new_task({
  name = "Build and serve app",
  strategy = {
    "orchestrator",
    tasks = {
      "make clean", -- Step 1: clean
      {             -- Step 2: build js and css in parallel
         "npm build",
        { "shell", cmd = "lessc styles.less styles.css" },
      },
      "npm serve",  -- Step 3: serve
    },
  },
})
task:start()
```

Lastly, you can always leverage the `.vscode/tasks.json` format to specify task dependencies using the `dependsOn` keyword. It will use one of the two above methods under the hood.

## VS Code tasks

Overseer can read [VS Code's tasks.json file](https://code.visualstudio.com/docs/editor/tasks). By default, VS Code tasks will show up when you `:OverseerRun`. Overseer is _nearly_ at feature parity, but it's not quite (nor will it ever be) at 100%.

Some VS Code extensions add additional tasks, task types, or problem matchers. You can't install those extensions for neovim, but there are ways to similarly extend the functionality of overseer. See [Extending VS Code tasks](extending_vscode.md) for more information.

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
- Integration with [launch.json](https://code.visualstudio.com/docs/editor/debugging#_launchjson-attributes) (see [DAP](third_party.md#dap))

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
