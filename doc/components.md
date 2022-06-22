# Built-in components

### on_output_summarize

Summarize stdout/stderr in the sidebar
**max_lines**:  (default `4`)

### on_output_write_file

Write task output to a file
***filename**: 

### on_rerun_handler

Ability to rerun the task
**delay**: How long to wait (in ms) post-result before triggering rerun (default `500`)
**interrupt**: If true, a rerun will cancel a currently running task (default `false`)

### on_result_diagnostics

Display the result diagnostics
**signs**?: 
**underline**?: 
**remove_during_rerun**?: Remove diagnostics while task is rerunning
**virtual_text**?: 

### on_result_diagnostics_quickfix

Put result diagnostics into the quickfix
**use_loclist**?: 

### on_result_notify

vim.notify on result
**statuses**: What statuses to notify on (default `["FAILURE", "SUCCESS"]`)

### on_result_notify_red_green

notify when task fails, or when it goes from failing to success

### on_result_notify_system

send a system notification when task completes
**statuses**: What statuses to notify on (default `["FAILURE", "SUCCESS"]`)

### on_result_rerun

Rerun when task ends
**statuses**: What statuses will trigger a rerun (default `["FAILURE"]`)

### on_result_stacktrace_quickfix

Put result stacktrace into the quickfix

### on_status_run_task

run another task on status change
***task_names**: Names of the task templates to trigger
**status**: What status to trigger on (default `"SUCCESS"`)
**sequence**?: When true, tasks run one after another
**once**: When true, only trigger task once then remove self (default `true`)

### rerun_on_save

Rerun on any buffer :write
**delay**: How long to wait (in ms) post-result before triggering rerun (default `500`)
**dir**?: Only rerun when writing files in this directory

### result_exit_code

Sets status based on exit code
**success_codes**?: Additional exit codes to consider as success
**parser**?: 

### timeout

Cancel task if it exceeds a timeout
**timeout**: Time to wait (in seconds) before canceling (default `120`)

# Custom components

TODO creating custom components
