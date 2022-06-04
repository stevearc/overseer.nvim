# TODO

- Parse duration of python tests
- More test integrations (and figure out how to simplify)
- diagnostics get cleared on run. They're not stored per-test.

## Test window

- Collapsing
- Filter by status
- actions
  - set stacktrace (and open quickfix)
  - jump to test
  - rerun test
  - display result in preview window
  - open result in new window
- perform quick action on test cursor is inside (e.g. view output)

## Future

- Command to show test details for current cursor test
- OverseerTestLast
- Track previous tasks and dispose them
- Show running status when test is in progress
- Only process result deltas so we don't have to re-render ALL signs and ALL test statuses
- Maybe put the test result resetting logic into an on_init component
- Fall back to vim-test if integration not found
- Run after build
- Test playlists
- Debug test integration
- Code coverage integration
- command to rerun failed tests (set limit on number of concurrent jobs)
- smart-detect a green color to use for the success icon
- Panel for _file_ tests

### Open questions

- As a user, how do I disable/force enable a test integration for a project?
- As a user, how can I customize the test command being run? (do run in vagrant, virtualenv, or whatever else)
- As a user, how do I define a _default_ test command for a project?
- How to handle multiple test frameworks matching a file/dir?
- How to handle integration not supporting testing a file/dir/nearest?
- How is this going to integrate with the overseer templates & tags?
- Defines a (customizable) way to find a test file from a file (integrate with vim-projectionist?)
- If multiple integrations match a test run, do we run all of them? the first one? User configurable?
