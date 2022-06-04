# TODO

## Test window

- Collapsing
- Filter by status
- actions
  - jump to test
  - open result in vsplit
  - open result in float

## Future

- Maybe put test reset logic into component (so task rerunning functions as intended)
- More test integrations (and figure out how to simplify)
- Track previous tasks and dispose them
- Run after build
- Test playlists
- Debug test integration
- Code coverage integration
- command to rerun failed tests (set limit on number of concurrent jobs)
- smart-detect a green color to use for the success icon
- Panel for _file_ tests
- Document all properties of: integration, test result
- On new results, live update test result buffers
- bug: Rerun via action menu in test panel clears diagnostics
- python unittest tests sometimes get stuck in running status

### Open questions

- How is this going to integrate with the overseer templates & tags?
- Defines a (customizable) way to find a test file from a file (integrate with vim-projectionist?)
