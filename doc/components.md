# Built-in components

<!-- TOC -->

- [dependencies](#dependencies)
- [display_duration](#display_duration)
- [on_complete_dispose](#on_complete_dispose)
- [on_complete_notify](#on_complete_notify)
- [on_complete_restart](#on_complete_restart)
- [on_exit_set_status](#on_exit_set_status)
- [on_output_parse](#on_output_parse)
- [on_output_quickfix](#on_output_quickfix)
- [on_output_summarize](#on_output_summarize)
- [on_output_write_file](#on_output_write_file)
- [on_result_diagnostics](#on_result_diagnostics)
- [on_result_diagnostics_quickfix](#on_result_diagnostics_quickfix)
- [on_result_notify](#on_result_notify)
- [restart_on_save](#restart_on_save)
- [run_after](#run_after)
- [timeout](#timeout)
- [unique](#unique)

<!-- /TOC -->

## dependencies

[dependencies.lua](../lua/overseer/component/dependencies.lua)

Set dependencies for task

| Param       | Type           | Default | Desc                               |
| ----------- | -------------- | ------- | ---------------------------------- |
| *task_names | `list[string]` |         | Names of dependency task templates |
| sequential  | `boolean`      | `false` |                                    |

- **task_names:** This can be a list of strings (template names, e.g. {"cargo build"}), tables (name with params, e.g. {"shell", cmd = "sleep 10"}), or tables (raw task params, e.g. {cmd = "sleep 10"})

## display_duration

[display_duration.lua](../lua/overseer/component/display_duration.lua)

Display the run duration

| Param        | Type      | Default | Desc                                   |
| ------------ | --------- | ------- | -------------------------------------- |
| detail_level | `integer` | `1`     | Show the duration at this detail level |

## on_complete_dispose

[on_complete_dispose.lua](../lua/overseer/component/on_complete_dispose.lua)

After task is completed, dispose it after a timeout

| Param    | Type         | Default                              | Desc                                              |
| -------- | ------------ | ------------------------------------ | ------------------------------------------------- |
| statuses | `list[enum]` | `["SUCCESS", "FAILURE", "CANCELED"]` | Tasks with one of these statuses will be disposed |
| timeout  | `number`     | `300`                                | Time to wait (in seconds) before disposing        |

## on_complete_notify

[on_complete_notify.lua](../lua/overseer/component/on_complete_notify.lua)

vim.notify when task is completed

| Param     | Type         | Default                  | Desc                                                                  |
| --------- | ------------ | ------------------------ | --------------------------------------------------------------------- |
| on_change | `boolean`    | `false`                  | Only notify when task status changes from previous value              |
| statuses  | `list[enum]` | `["FAILURE", "SUCCESS"]` | List of statuses to notify on                                         |
| system    | `enum`       | `"never"`                | When to send a system notification (`"always"\|"never"\|"unfocused"`) |

- **on_change:** This is mostly used when a task is going to be restarted, and you want notifications only when it goes from SUCCESS to FAILURE, or vice-versa

## on_complete_restart

[on_complete_restart.lua](../lua/overseer/component/on_complete_restart.lua)

Restart task when it completes

| Param    | Type         | Default       | Desc                                                           |
| -------- | ------------ | ------------- | -------------------------------------------------------------- |
| delay    | `number`     | `500`         | How long to wait (in ms) post-result before triggering restart |
| statuses | `list[enum]` | `["FAILURE"]` | What statuses will trigger a restart                           |

## on_exit_set_status

[on_exit_set_status.lua](../lua/overseer/component/on_exit_set_status.lua)

Sets final task status based on exit code

| Param         | Type            | Desc                                         |
| ------------- | --------------- | -------------------------------------------- |
| success_codes | `list[integer]` | Additional exit codes to consider as success |

## on_output_parse

[on_output_parse.lua](../lua/overseer/component/on_output_parse.lua)

Parses task output and sets task result

| Param              | Type     | Desc                                                                 |
| ------------------ | -------- | -------------------------------------------------------------------- |
| parser             | `opaque` | Parser definition to extract values from output                      |
| problem_matcher    | `opaque` | VS Code-style problem matcher                                        |
| relative_file_root | `string` | Relative filepaths will be joined to this root (instead of task cwd) |
| precalculated_vars | `opaque` | Precalculated VS Code task variables                                 |

- **precalculated_vars:** Tasks that are started from the VS Code provider precalculate certain interpolated variables (e.g. ${workspaceFolder}). We pass those in as params so they will remain stable even if Neovim's state changes in between creating and running (or restarting) the task.

## on_output_quickfix

[on_output_quickfix.lua](../lua/overseer/component/on_output_quickfix.lua)

Set all task output into the quickfix (on complete)

| Param              | Type      | Default   | Desc                                                                                    |
| ------------------ | --------- | --------- | --------------------------------------------------------------------------------------- |
| close              | `boolean` | `false`   | Close the quickfix on completion if no errorformat matches                              |
| errorformat        | `string`  |           | See :help errorformat                                                                   |
| items_only         | `boolean` | `false`   | Only show lines that match the errorformat                                              |
| open               | `boolean` | `false`   | Open the quickfix on output                                                             |
| open_height        | `integer` |           | The height of the quickfix when opened                                                  |
| open_on_exit       | `enum`    | `"never"` | Open the quickfix when the command exits (`"never"\|"failure"\|"always"`)               |
| open_on_match      | `boolean` | `false`   | Open the quickfix when the errorformat finds a match                                    |
| relative_file_root | `string`  |           | Relative filepaths will be joined to this root (instead of task cwd)                    |
| set_diagnostics    | `boolean` | `false`   | Add the matching items to vim.diagnostics                                               |
| tail               | `boolean` | `true`    | Update the quickfix with task output as it happens, instead of waiting until completion |

- **tail:** This may cause unexpected results for commands that produce "fancy" output using terminal escape codes (e.g. animated progress indicators)

## on_output_summarize

[on_output_summarize.lua](../lua/overseer/component/on_output_summarize.lua)

Summarize task output in the task list

| Param     | Type      | Default | Desc                                              |
| --------- | --------- | ------- | ------------------------------------------------- |
| max_lines | `integer` | `4`     | Number of lines of output to show when detail > 1 |

## on_output_write_file

[on_output_write_file.lua](../lua/overseer/component/on_output_write_file.lua)

Write task output to a file

| Param     | Type     | Desc                            |
| --------- | -------- | ------------------------------- |
| *filename | `string` | Name of file to write output to |

## on_result_diagnostics

[on_result_diagnostics.lua](../lua/overseer/component/on_result_diagnostics.lua)

If task result contains diagnostics, display them

| Param             | Type      | Desc                                                  |
| ----------------- | --------- | ----------------------------------------------------- |
| remove_on_restart | `boolean` | Remove diagnostics when task restarts                 |
| signs             | `boolean` | Override the default diagnostics.signs setting        |
| underline         | `boolean` | Override the default diagnostics.underline setting    |
| virtual_text      | `boolean` | Override the default diagnostics.virtual_text setting |

## on_result_diagnostics_quickfix

[on_result_diagnostics_quickfix.lua](../lua/overseer/component/on_result_diagnostics_quickfix.lua)

If task result contains diagnostics, add them to the quickfix

| Param             | Type      | Default | Desc                                                                     |
| ----------------- | --------- | ------- | ------------------------------------------------------------------------ |
| close             | `boolean` | `false` | If true, close the quickfix when there are no diagnostics                |
| open              | `boolean` | `false` | If true, open the quickfix when there are diagnostics                    |
| set_empty_results | `boolean` | `false` | If true, overwrite the current quickfix even if there are no diagnostics |
| use_loclist       | `boolean` | `false` | If true, use the loclist instead of quickfix                             |

## on_result_notify

[on_result_notify.lua](../lua/overseer/component/on_result_notify.lua)

vim.notify when task receives results

Normally you will want to use on_complete_notify. If you have a long-running watch task (e.g. `tsc
--watch`) that produces new results periodically, then this is the component you want.

| Param                         | Type      | Default   | Desc                                                                          |
| ----------------------------- | --------- | --------- | ----------------------------------------------------------------------------- |
| infer_status_from_diagnostics | `boolean` | `true`    | Notification level will be error/info depending on if diagnostics are present |
| on_change                     | `boolean` | `true`    | Only notify when status changes from previous value                           |
| system                        | `enum`    | `"never"` | When to send a system notification (`"always"\|"never"\|"unfocused"`)         |

- **on_change:** This only works when infer_status_from_diagnostics = true

## restart_on_save

[restart_on_save.lua](../lua/overseer/component/restart_on_save.lua)

Restart on any buffer :write

| Param     | Type           | Default     | Desc                                                                      |
| --------- | -------------- | ----------- | ------------------------------------------------------------------------- |
| delay     | `number`       | `500`       | How long to wait (in ms) before triggering restart                        |
| interrupt | `boolean`      | `true`      | Interrupt running tasks                                                   |
| mode      | `enum`         | `"autocmd"` | How to watch the paths (`"autocmd"\|"uv"`)                                |
| paths     | `list[string]` |             | Only restart when writing files in these paths (can be directory or file) |

- **mode:** 'autocmd' will set autocmds on BufWritePost. 'uv' will use a libuv file watcher (recursive watching may not be supported on all platforms).

## run_after

[run_after.lua](../lua/overseer/component/run_after.lua)

Run other tasks after this task completes

| Param       | Type           | Default       | Desc                                                          |
| ----------- | -------------- | ------------- | ------------------------------------------------------------- |
| *task_names | `list[string]` |               | Names of dependency task templates                            |
| detach      | `boolean`      | `false`       | Tasks created will not be linked to the parent task           |
| statuses    | `list[enum]`   | `["SUCCESS"]` | Only run successive tasks if the final status is in this list |

- **task_names:** This can be a list of strings (template names, e.g. {"cargo build"}), tables (name with params, e.g. {"shell", cmd = "sleep 10"}), or tables (raw task params, e.g. {cmd = "sleep 10"})
- **detach:** This means they will not restart when the parent restarts, and will not be disposed when the parent is disposed

## timeout

[timeout.lua](../lua/overseer/component/timeout.lua)

Cancel task if it exceeds a timeout

| Param   | Type      | Default | Desc                                       |
| ------- | --------- | ------- | ------------------------------------------ |
| timeout | `integer` | `120`   | Time to wait (in seconds) before canceling |

## unique

[unique.lua](../lua/overseer/component/unique.lua)

Ensure that this task does not have any duplicates

| Param              | Type      | Default | Desc                                                                                                        |
| ------------------ | --------- | ------- | ----------------------------------------------------------------------------------------------------------- |
| replace            | `boolean` | `true`  | If a prior task exists, replace it. When false, will restart the existing task and dispose the current task |
| restart_interrupts | `boolean` | `true`  | When replace = false, should restarting the existing task interrupt it                                      |

- **replace:** Note that when this is false a new task that is created will restart the existing one and _dispose itself_. This can lead to unexpected behavior if you are creating a task and then trying to use that reference (to run actions on it, use it as a dependency, etc)

