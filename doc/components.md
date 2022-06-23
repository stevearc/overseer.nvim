# Components

- [ ] TODO params

Components are units of behavior that are attached to a Task. They define certain methods that will be called during the Task lifecycle, and can interact with the Task object. They can be passed in to the Task constructor (e.g. `Task.new({..., components = {'component_1', 'component_2'}})`) or added dynamically (though as a user you generally shouldn't need to do so).

When referencing a component, you can use just the string name (e.g. `"timeout"`), or you can pass a table with parameters (e.g. `{"timeout", timeout = 10}`).

See below for how to create your own [custom components](#custom-components).

## Built-in components

### [on_output_summarize](../lua/overseer/component/on_output_summarize.lua)

Summarize stdout/stderr in the sidebar \
**max_lines**[int]: (default `4`)

### [on_output_write_file](../lua/overseer/component/on_output_write_file.lua)

Write task output to a file \
\***filename**[string]:

### [on_rerun_handler](../lua/overseer/component/on_rerun_handler.lua)

Ability to rerun the task \
**delay**[number]: How long to wait (in ms) post-result before triggering rerun (default `500`) \
**interrupt**[bool]: If true, a rerun will cancel a currently running task (default `false`)

### [on_result_diagnostics](../lua/overseer/component/on_result_diagnostics.lua)

Display the result diagnostics \
**remove_during_rerun**[bool]: Remove diagnostics while task is rerunning \
**signs**[bool]: \
**underline**[bool]: \
**virtual_text**[bool]:

### [on_result_diagnostics_quickfix](../lua/overseer/component/on_result_diagnostics_quickfix.lua)

Put result diagnostics into the quickfix \
**use_loclist**[bool]:

### [on_result_notify](../lua/overseer/component/on_result_notify.lua)

vim.notify on result \
**statuses**[list]: What statuses to notify on (default `["FAILURE", "SUCCESS"]`)

### [on_result_notify_red_green](../lua/overseer/component/on_result_notify_red_green.lua)

notify when task fails, or when it goes from failing to success

### [on_result_notify_system](../lua/overseer/component/on_result_notify_system.lua)

send a system notification when task completes \
**statuses**[list]: What statuses to notify on (default `["FAILURE", "SUCCESS"]`)

### [on_result_rerun](../lua/overseer/component/on_result_rerun.lua)

Rerun when task ends \
**statuses**[list]: What statuses will trigger a rerun (default `["FAILURE"]`)

### [on_status_run_task](../lua/overseer/component/on_status_run_task.lua)

run another task on status change \
**once**[bool]: When true, only trigger task once then remove self (default `true`) \
**sequence**[bool]: When true, tasks run one after another \
**status**[enum]: What status to trigger on (default `"SUCCESS"`) \
\***task_names**[list]: Names of the task templates to trigger

### [rerun_on_save](../lua/overseer/component/rerun_on_save.lua)

Rerun on any buffer :write \
**delay**[number]: How long to wait (in ms) post-result before triggering rerun (default `500`) \
**dir**[string]: Only rerun when writing files in this directory

### [result_exit_code](../lua/overseer/component/result_exit_code.lua)

Sets status based on exit code \
**parser**[string]: \
**success_codes**[list]: Additional exit codes to consider as success

### [timeout](../lua/overseer/component/timeout.lua)

Cancel task if it exceeds a timeout \
**timeout**[int]: Time to wait (in seconds) before canceling (default `120`)

## Custom components

Components are lazy-loaded via requiring in the `overseer.component` namespace. For example, the `timeout` component is loaded from `lua/overseer/component/timeout.lua`. It is recommended that for plugins or personal use, you namespace your own components behind an additional directory. For example, place your component in `lua/overseer/component/myplugin/mycomponent.lua`, and reference it as `myplugin.mycomponent`.

The component definition should look like the following example:

```lua
return {
  description = "Include a description of your component",
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
      ---@param task overseer.Task
      on_init = function(self, task)
        -- Called when the task is created
        -- This is a good place to initialize resources, if needed
      end,
      ---@param task overseer.Task
      on_start = function(self, task)
        -- Called when the task is started
      end,
      ---@param task overseer.Task
      ---@param soft boolean When true, the components are being reset but the *task* is not. This is used to support commands that are watching the filesystem and rerunning themselves on file change.
      on_reset = function(self, task, soft)
        -- Called when the task is reset to run again
      end,
      ---@param task overseer.Task
      ---@param status overseer.Status Can be RUNNING (we can set results without completing the task), CANCELED, FAILURE, or SUCCESS
      ---@param result table A result table.
      on_result = function(self, task, status, result)
        -- Called when a component has results to set. Usually this is after the command has completed, but certain types of tasks may wish to set a result while still running.
      end,
      ---@param task overseer.Task
      ---@param status overseer.Status Can be CANCELED, FAILURE, or SUCCESS
      ---@param result table A result table.
      on_complete = function(self, task, status, result)
        -- Called when the task has reached a completed state.
      end,
      ---@param task overseer.Task
      ---@param data string[] Output of process. See :help channel-lines
      on_output = function(self, task, data)
        -- Called when there is output from the task
      end,
      ---@param task overseer.Task
      ---@param lines string[] Completed lines of output, with ansi codes removed.
      on_output_lines = function(self, task, lines)
        -- Called when there is output from the task
        -- Usually easier to deal with than using on_output directly.
      end,
      ---@param task overseer.Task
      on_request_rerun = function(self, task)
        -- Called when an action requests that the task be restarted
      end,
      ---@param task overseer.Task
      ---@param code number The process exit code
      on_exit = function(self, task, code)
        -- Called when the task command has completed
      end,
      ---@param task overseer.Task
      on_dispose = function(self, task)
        -- Called when the task is disposed
        -- Will be called IFF on_init was called, and will be called exactly once.
        -- This is a good place to free resources (e.g. timers, files, etc)
      end,
      ---@param task overseer.Task
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

A note on the Task result table. There is technically no schema for it, as the only things that interact with it are components and actions. However, there are a couple of built-in uses for specific keys of the table:

**diagnostics**: This key is used for diagnostics. It should be a list of quickfix items (see `:help setqflist`)
