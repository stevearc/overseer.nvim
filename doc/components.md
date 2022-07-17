# Built-in components

## [dependencies](../lua/overseer/component/dependencies.lua)

Set dependencies for task \
**sequential**[boolean]: (default `false`) \
\***task_names**[list[string]]: Names of dependency task templates

## [on_output_parse_diagnostics](../lua/overseer/component/on_output_parse_diagnostics.lua)

Parses task output and sets diagnostics \
**parser**[opaque]: Parser definition to extract diagnostics from output

## [on_output_summarize](../lua/overseer/component/on_output_summarize.lua)

Summarize task output in the task list \
**max_lines**[integer]: Number of lines of output to show when detail > 1 (default `4`)

## [on_output_write_file](../lua/overseer/component/on_output_write_file.lua)

Write task output to a file \
\***filename**[string]: Name of file to write output to

## [on_restart_handler](../lua/overseer/component/on_restart_handler.lua)

Allows task to be restarted \
**delay**[number]: How long to wait (in ms) post-result before triggering restart (default `500`) \
**interrupt**[boolean]: If true, a restart will cancel a currently running task (default `false`)

## [on_result_diagnostics](../lua/overseer/component/on_result_diagnostics.lua)

If task result contains diagnostics, display them \
**remove_on_restart**[boolean]: Remove diagnostics when task restarts \
**signs**[boolean]: Override the default diagnostics.signs setting \
**underline**[boolean]: Override the default diagnostics.underline setting \
**virtual_text**[boolean]: Override the default diagnostics.virtual_text setting

## [on_result_diagnostics_quickfix](../lua/overseer/component/on_result_diagnostics_quickfix.lua)

If task result contains diagnostics, add them to the quickfix \
**use_loclist**[boolean]: If true, use the loclist instead of quickfix

## [on_result_notify](../lua/overseer/component/on_result_notify.lua)

vim.notify on task result \
**desktop**[enum]: When to use a desktop notification (default `"never"`) \
**statuses**[list[enum]]: List of statuses to notify on (default `["FAILURE", "SUCCESS"]`)

## [on_result_notify_red_green](../lua/overseer/component/on_result_notify_red_green.lua)

vim.notify when task fails, or when it goes from failing to success \
**desktop**[enum]: When to use a desktop notification (default `"never"`)

## [on_result_restart](../lua/overseer/component/on_result_restart.lua)

Restart task when it completes \
**statuses**[list[enum]]: What statuses will trigger a restart (default `["FAILURE"]`)

## [restart_on_save](../lua/overseer/component/restart_on_save.lua)

Restart on any buffer :write \
**delay**[number]: How long to wait (in ms) post-result before triggering restart (default `500`) \
**dir**[string]: Only restart when writing files in this directory

## [result_exit_code](../lua/overseer/component/result_exit_code.lua)

Sets final task status based on exit code \
**success_codes**[list[integer]]: Additional exit codes to consider as success

## [timeout](../lua/overseer/component/timeout.lua)

Cancel task if it exceeds a timeout \
**timeout**[integer]: Time to wait (in seconds) before canceling (default `120`)

