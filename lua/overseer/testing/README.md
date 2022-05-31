# TODO

- View results inline (popup preview window of error/stacktrace/details)
- Signs in the test files
- Parse stdout/stderr

## Test window

- Rerun group of tests
- Collapsing
- Filter by status
- Panel for _file_ tests
- parse and display duration

## Commands

- OverseerTestLast
- rerun failed tests (set limit on number of concurrent jobs)
- Populate workspace tests (crawl directory)

## Future

- Show running status when test is in progress
- Maybe put the test result resetting logic into an on_init component
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
