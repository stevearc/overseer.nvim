# TODO

## Data structure and API

- Defines output parser (stacktrace, error line, individual test status, duration)

## Test window

- Summary of results at the top
- Filter by status
- View results inline (popup preview window of error/stacktrace/details)
- Probably need 2 modes:

1. show me the tests in this file. Run them, or some subset of them.
2. run the tests for this _project_. Maybe show them? Definitely show the results.
   Do I want to have a test explorer like VS Code? For whole project, or just file?

## Commands

- OverseerTestLast

## Future

- Fall back to vim-test if integration not found
- Run after build
- Test playlists
- Debug test integration
- Code coverage integration

### Open questions

- As a user, how do I disable/force enable a test integration for a project?
- As a user, how can I customize the test command being run? (do run in vagrant, virtualenv, or whatever else)
- As a user, how do I define a _default_ test command for a project?
- How to handle multiple test frameworks matching a file/dir?
- How to handle integration not supporting testing a file/dir/nearest?
- How is this going to integrate with the overseer templates & tags?
- Defines a (customizable) way to find a test file from a file (integrate with vim-projectionist?)
- If multiple integrations match a test run, do we run all of them? the first one? User configurable?
