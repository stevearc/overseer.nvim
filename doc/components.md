# Overview

TODO available methods
TODO params
TODO shape of result object

# Built-in components

### [on_output_summarize](../lua/overseer/component/on_output_summarize.lua)

Summarize stdout/stderr in the sidebar
**max_lines**:  (default `4`)

### [on_output_write_file](../lua/overseer/component/on_output_write_file.lua)

Write task output to a file
***filename**: 

### [on_rerun_handler](../lua/overseer/component/on_rerun_handler.lua)

Ability to rerun the task
**delay**: How long to wait (in ms) post-result before triggering rerun (default `500`)
**interrupt**: If true, a rerun will cancel a currently running task (default `false`)

### [on_result_diagnostics](../lua/overseer/component/on_result_diagnostics.lua)

Display the result diagnostics
**remove_during_rerun**?: Remove diagnostics while task is rerunning
**signs**?: 
**underline**?: 
**virtual_text**?: 

### [on_result_diagnostics_quickfix](../lua/overseer/component/on_result_diagnostics_quickfix.lua)

Put result diagnostics into the quickfix
**use_loclist**?: 

### [on_result_notify](../lua/overseer/component/on_result_notify.lua)

vim.notify on result
**statuses**: What statuses to notify on (default `["FAILURE", "SUCCESS"]`)

### [on_result_notify_red_green](../lua/overseer/component/on_result_notify_red_green.lua)

notify when task fails, or when it goes from failing to success

### [on_result_notify_system](../lua/overseer/component/on_result_notify_system.lua)

send a system notification when task completes
**statuses**: What statuses to notify on (default `["FAILURE", "SUCCESS"]`)

### [on_result_rerun](../lua/overseer/component/on_result_rerun.lua)

Rerun when task ends
**statuses**: What statuses will trigger a rerun (default `["FAILURE"]`)

### [on_result_stacktrace_quickfix](../lua/overseer/component/on_result_stacktrace_quickfix.lua)

Put result stacktrace into the quickfix

### [on_status_run_task](../lua/overseer/component/on_status_run_task.lua)

run another task on status change
**once**: When true, only trigger task once then remove self (default `true`)
**sequence**?: When true, tasks run one after another
**status**: What status to trigger on (default `"SUCCESS"`)
***task_names**: Names of the task templates to trigger

### [rerun_on_save](../lua/overseer/component/rerun_on_save.lua)

Rerun on any buffer :write
**delay**: How long to wait (in ms) post-result before triggering rerun (default `500`)
**dir**?: Only rerun when writing files in this directory

### [result_exit_code](../lua/overseer/component/result_exit_code.lua)

Sets status based on exit code
**parser**?: 
**success_codes**?: Additional exit codes to consider as success

### [timeout](../lua/overseer/component/timeout.lua)

Cancel task if it exceeds a timeout
**timeout**: Time to wait (in seconds) before canceling (default `120`)

# Custom components

TODO creating custom components
