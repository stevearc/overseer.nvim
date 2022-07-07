# Guide for common customizations

TODO

- [Custom tasks](#custom-tasks)
- changing default components (dispose, timeout, or params)
- disabling built-in templates
- link to creating custom components
- run the default build/test/clean task
- [Actions](#actions)

## Custom tasks

TODO

### Project-specific tasks

TODO

### Filetype-specific tasks

TODO

## Actions

Actions can be performed on tasks by using the `RunAction` keybinding in the task list, or by the `OverseerQuickAction` and `OverseerTaskAction` commands. They are simply a custom function that will do something to or with a task.

Browse the set of built-in actions at [lua/overseer/task_list/actions.lua](../lua/overseer/task_list/actions.lua)

You can define your own or disable any of the built-in actions in the call to setup():

```lua
require("overseer").setup({
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
