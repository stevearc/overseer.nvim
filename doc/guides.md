# Guides

<!-- TOC -->

- [Custom tasks](#custom-tasks)
  - [Template definition](#template-definition)
  - [Template providers](#template-providers)
- [Actions](#actions)
- [Custom components](#custom-components)
  - [Component aliases](#component-aliases)
  - [Task result](#task-result)
- [Task events](#task-events)
- [Customizing built-in tasks](#customizing-built-in-tasks)
- [Customizing the task appearance in the task list](#customizing-the-task-appearance-in-the-task-list)
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

Similar to [custom components](#custom-components), templates can be lazy-loaded from a module in the `overseer.template` namespace. So if you put a task inside `<runtimepath>/lua/overseer/template/first_task.lua`, overseer will automatically detect and load it.

### Template definition

The definition of a template looks like this:

```lua
---@type overseer.TemplateFileDefinition
return {
  -- Required fields
  name = "Some Task",
  builder = function(params)
    -- This must return an overseer.TaskDefinition
    return {
      -- cmd is the only required field. It can be a list or a string.
      cmd = { "echo", "hello", "world" },
      -- additional arguments for the cmd (usually only useful if cmd is a string)
      args = {},
      -- the name of the task (defaults to the cmd of the task)
      name = "Greet",
      -- set the working directory for the task
      cwd = "/tmp",
      -- additional environment variables
      env = {
        VAR = "FOO",
      },
      -- the list of components or component aliases to add to the task
      components = { "my_custom_component", "default" },
      -- arbitrary table of data for your own personal use
      metadata = {
        foo = "bar",
      },
    }
  end,
  -- Optional fields
  desc = "Optional description of task",
  -- Tags can be used in overseer.run_task()
  tags = {overseer.TAG.BUILD},
  params = {
    -- See :help overseer-params
  },
  -- Add requirements for this template. If they are not met, the template will not be visible.
  -- All fields are optional.
  condition = {
    -- A string or list of strings
    -- Only matches when current buffer is one of the listed filetypes
    filetype = { "c", "cpp" },
    -- A string or list of strings
    -- Only matches when cwd is inside one of the listed dirs
    dir = "/home/user/my_project",
  },
}
```

### Template providers

Template providers are used to generate multiple templates dynamically. The main use case is
generating one task per target (e.g. for a makefile), but can be used for any situation where you
want the templates themselves to be generated at runtime.

Providers are created the same way templates are (with `overseer.register_template`, or by putting
them in a lua file). The structure is as follows:

```lua
---@type overseer.TemplateFileProvider
return {
  generator = function(search)
    if not is_task_available() then
      return "Task is not available for reason X"
    end
    -- return a list of tasks
    return {...}
  end,
  -- Optional. Same as template.condition
  condition = {
    filetype = { "c" },
  },
  -- Optional. Some task generators may be slow and thus you may want to cache the results.
  -- By providing a cache key (usually a config file or root directory), overseer will automatically
  -- cache results from slow providers and will clear the cache when that file is written.
  cache_key = function(opts)
    return vim.fs.find("Makefile", { upward = true, type = "file", path = opts.dir })[1]
  end,
}
```

If you want to do some asynchronous work while listing tasks (such as running a command with
`vim.system`), you can use the `callback` argument to the generator function.

```lua
---@type overseer.TemplateFileProvider
return {
  generator = function(search, callback)
    do_some_work(function(err)
      if err then
        callback(err)
        return
      end
      -- Pass a list of tasks to the callback
      callback({...})
    end)
  end,
}
```

## Actions

Actions can be performed on tasks by using the `keymap.run_action` keybinding in the task list, or
by the `OverseerTaskAction` command. Actions are simply custom functions that will do something to
or with a task.

Browse the set of built-in actions at [lua/overseer/task_list/actions.lua](../lua/overseer/task_list/actions.lua).

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
    keymaps = {
      ["P"] = { "keymap.run_action", opts = { action = "my action" }, desc = "Do something cool" },
    },
  },
})
```

## Custom components

When components are passed as an argument, they can be specified as either a raw string (e.g. `"on_complete_dispose"`) or a table with configuration parameters (e.g. `{"on_complete_dispose", timeout = 10}`).

Components are lazy-loaded via requiring in the `overseer.component` namespace. For example, the `timeout` component is loaded from `lua/overseer/component/timeout.lua`. It is _recommended_ that for plugins or personal use, you namespace your own components behind an additional directory. For example, place your component in `lua/overseer/component/myplugin/mycomponent.lua`, and reference it as `myplugin.mycomponent`.

Paths given are all relative to any runtimepath (`:help rtp`), so in practice it's probably easiest to put it in `~/.config/nvim`. The full path to your custom component would then become `~/.config/nvim/lua/overseer/component/myplugin/mycomponent.lua`.

The component definition should look like the following example:

```lua
---@type overseer.ComponentFileDefinition
return {
  desc = "Include a description of your component",
  -- Define parameters that can be passed in to the component
  params = {
    -- See :help overseer-params
  },
  -- Optional, default true. Set to false to disallow editing this component in the task editor
  editable = true,
  -- Optional, default true. When false, don't serialize this component when saving a task to disk
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
      on_reset = function(self, task)
        -- Called when the task is reset to run again
      end,
      ---@return table
      on_pre_result = function(self, task)
        -- Called when the task is finalizing.
        -- Return a map-like table value here to merge it into the task result.
        return { foo = { "bar", "baz" } }
      end,
      ---@param result table A result table.
      on_preprocess_result = function(self, task, result)
        -- Called right before on_result. Intended for logic that needs to preprocess the result table and update it in-place.
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
    }
  end,
}
```

### Component aliases

A component alias is just a simple string you can use as a component that resolves to a list of components. These are configured via the [component_aliases](./reference.md#setup-options) option in `setup()`. The two built-in aliases are `default`, which is used for all tasks when no components are specified, and `default_vscode` which is the same but for tasks specifically from the VS Code task integration. You can define and use your own component aliases using the same format. Aliases _can_ include other aliases; for example the `default_vscode` alias includes the `default` alias in addition to some other components.

**NOTE**: When components are added to a task, it will be a no-op if the component already exists on the task. This is meaningful if you intend to change the parameters on a component that is in the `default` alias. As a best practice, always list any component aliases _after_ specific components.

```lua
local task = require("overseer").new_task({
    cmd = "g++ " .. vim.fn.expand("%"),
    components = {
        -- Add on_complete_notify first with a customized 'statuses' parameter
        { "on_complete_notify", statuses = { "SUCCESS" } },
        -- The default group also adds on_complete_notify,
        -- but since it appears second it will be ignored.
        "default"
    }
})
```

### Task result

A note on the Task result table: there is technically no schema for it, as the only things that interact with it are components and actions. However, there are a couple of built-in uses for specific keys of the table:

**diagnostics**: This key is used for diagnostics. It should be a list of quickfix items (see `:help setqflist`) \
**error**: This key will be set when there is an internal overseer error when running the task

## Task events

A lighter-weight alternative to custom components is directly subscribing to task events. Once you create a task you can call `task:subscribe("event", function() ... end)` to process the same events that get handled by components. For example, to run a function when a task completes:

```lua
local task = overseer.new_task({ cmd = {"echo", "hello", "world"} })
-- on_complete gets called with the same arguments as it does for components
task:subscribe("on_complete", function(_task, status, result)
  print("Task", task.name, "finished with status", status)
end)
task:start()
```

To unsubscribe from an event, you can either pass the same function in to `task:unsubscribe()` or you can return a truthy value from the function.

```lua
local task = overseer.new_task({ cmd = { "build_and_serve.sh" } })
task:subscribe("on_output_lines", function(_task, lines)
  for _, line in ipairs(lines) do
    local address = line:match("^Serving at (http.*)")
    if address then
      vim.ui.open(address)
      return true
    end
  end
end)
task:start()
```

Note that when a task is serialized it cannot save the subscriptions.

## Customizing built-in tasks

You may wish to customize the built-in task definitions, or tasks from another plugin. The simplest way to do this is using the [add_template_hook](reference.md#add_template_hookopts-hook) function. This allows you to run a function on the task definition (the arguments passed to [new_task](reference.md#new_taskopts)) and process it however you like. A common use case would be to add a component or modify the environment variables while in a specific project:

```lua
overseer.add_template_hook({
  dir = "/path/to/my/project",
  module = "^cargo$",
}, function(task_defn, util)
  -- The `util` parameter is just a namespace that exposes some useful functions
  -- for mutating a task definition
  util.add_component(task_defn, { "on_output_quickfix", open = true })
  util.remove_component(task_defn, "on_complete_dispose")
  if util.has_component(task_defn, "timeout") then
    -- ...
  end
end)
```

## Customizing the task appearance in the task list

The task appearance can be customized via the `task_list.render` function in the [config](reference.md#setupopts). The render function is just a function that takes a task and returns a list of lines, where each line is a list of `[text, hl_group]` "chunks" (`:help nvim_echo` uses the same format).

```lua
require("overseer").setup({
  task_list = {
    render = function(task)
      -- There are a few different built-in format functions
      -- return require("overseer.render").format_compact(task)
      -- return require("overseer.render").format_verbose(task)
      return require("overseer.render").format_standard(task)
    end,
  },
})
```


See more detailed documentation about rendering in [the rendering doc](rendering.md).

## Parsing output

The primary way of parsing output with overseer is the [on_output_parse](components.md#on_output_parse) component. This can use a VS Code-style problem matcher, a function, or a vim errorformat to parse the output.

```lua
-- Using vim errorformat
{ "on_output_parse", errorformat = "%f:%l: %m" }

-- Using VSCode problem matcher
{ "on_output_parse", problem_matcher = "$tsc" }

-- Using a function
{ "on_output_parse", parser = function(line)
  local fname, lnum, msg = line:match("^(.*):(%d+): (.*)$")
  if fname then
    return {
      filename = fname,
      lnum = tonumber(lnum),
      text = msg
    }
  end
end }
```

See more detailed documentation about parsers and `on_output_parse` in [the parsers doc](parsers.md).

You can also create your own components to parse output leveraging the `on_output` or `on_output_lines` methods. The integration should be straightforward; see [on_output_parse.lua](../lua/overseer/component/on_output_parse.lua) to see how the built-in component leverages these methods.

## Running tasks sequentially

There are currently two ways to get tasks to run sequentially. The first is by using the [dependencies](components.md#dependencies) component. For example, if you wanted to create a `npm serve` task that runs `npm build` first, you could create it like so:

```lua
overseer.run_task({ name = "npm serve", autostart = false }, function(task)
  if task then
    task:add_component({
      "dependencies",
      tasks = {
        "npm build",
        -- You can also pass in a task object
        { cmd = "sleep 10" },
      },
      sequential = true,
    })
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
      { -- Step 2: build js and css in parallel
        "npm build",
        { cmd = { "lessc", "styles.less", "styles.css" },
      },
      "npm serve", -- Step 3: serve
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
- [Built-in library](parsers.md#built-in-problem-matchers) of problem matchers and patterns (e.g. `$tsc` and `$jshint-stylish`)
- [Compound tasks](https://code.visualstudio.com/docs/editor/tasks#_compound-tasks) (including `dependsOrder = sequence`)
- [Background tasks](https://code.visualstudio.com/docs/editor/tasks#_background-watching-tasks)
- `group` (sets template tag; supports `BUILD`, `RUN`, `TEST`, and `CLEAN`) and `isDefault` (sets priority)
- [Operating system specific properties](https://code.visualstudio.com/docs/editor/tasks#_operating-system-specific-properties)
- Integration with [launch.json](https://code.visualstudio.com/docs/editor/debugging#_launchjson-attributes) (see [DAP](third_party.md#dap))
- [Output behavior](https://code.visualstudio.com/docs/editor/tasks#_output-behavior) (with some tweaked defaults)

Unsupported features:

- task types: gulp, grunt, jake
- Specifying a custom shell to use
- `${workspacefolder:*}` variables
- `${config:*}` variables
- `${command:*}` variables
- The `${defaultBuildTask}` variable
- Custom problem matcher patterns may fail due to differences between JS and vim regex (notably vim regex uses a different syntax for non-capturing groups `(?:.*)` and doesn't support character classes inside of brackets `[\d\s]`). Built-in matchers have already been translated.
- [Run behavior](https://code.visualstudio.com/docs/editor/tasks#_run-behavior) (probably not going to support this)
