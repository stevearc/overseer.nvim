# Built-in components

## [dependencies](../lua/overseer/component/dependencies.lua)

Set dependencies for task \
**sequential**[boolean]: (default `false`) \
\***task_names**[list[string]]: Names of dependency task templates

## [on_complete_dispose](../lua/overseer/component/on_complete_dispose.lua)

After task is completed, dispose it after a timeout \
**statuses**[list[enum]]: Tasks with one of these statuses will be disposed (default `["SUCCESS", "FAILURE", "CANCELED"]`) \
**timeout**[number]: Time to wait (in seconds) before disposing (default `300`)

## [on_complete_notify](../lua/overseer/component/on_complete_notify.lua)

vim.notify when task is completed \
**on_change**[boolean]: Only notify when task status changes from previous value (default `false`) \
    This is mostly used when a task is going to be restarted, and you want notifications only when \
    it goes from SUCCESS to FAILURE, or vice-versa \
**statuses**[list[enum]]: List of statuses to notify on (default `["FAILURE", "SUCCESS"]`) \
**system**[enum]: When to send a system notification (default `"never"`)

## [on_complete_restart](../lua/overseer/component/on_complete_restart.lua)

Restart task when it completes \
**statuses**[list[enum]]: What statuses will trigger a restart (default `["FAILURE"]`)

## [on_exit_set_status](../lua/overseer/component/on_exit_set_status.lua)

Sets final task status based on exit code \
**success_codes**[list[integer]]: Additional exit codes to consider as success

## [on_output_parse](../lua/overseer/component/on_output_parse.lua)

Parses task output and sets task result \
\***parser**[opaque]: Parser definition to extract values from output

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
**close**[boolean]: If true, close the quickfix when there are no diagnostics (default `false`) \
**open**[boolean]: If true, open the quickfix when there are diagnostics (default `false`) \
**set_empty_results**[boolean]: If true, overwrite the quickfix even if there are no diagnostics (default `false`) \
**use_loclist**[boolean]: If true, use the loclist instead of quickfix (default `false`)

## [restart_on_save](../lua/overseer/component/restart_on_save.lua)

Restart on any buffer :write \
**delay**[number]: How long to wait (in ms) post-result before triggering restart (default `500`) \
**dir**[string]: Only restart when writing files in this directory

## [timeout](../lua/overseer/component/timeout.lua)

Cancel task if it exceeds a timeout \
**timeout**[integer]: Time to wait (in seconds) before canceling (default `120`)

