# TODO

- Filter test panel by status

## Future

- More test integrations
  - python pytest
  - rust cargotest
  - js mocha
  - java junit?
  - csharp dotnettest
  - another go framework?
- How to handle multiple integrations on a workspace/buffer? (e.g. lua busted & plenary busted)
- Test playlists
- Show which integrations are active for (dir/buffer)
- Debug test integration
- Code coverage integration
- Panel for _file_ tests, panel for workspace directory tests
- Document all properties of:
  - integration
    - id
    - name
    - is_workspace_match
    - get_cmd (recommended)
    - run_test_dir
    - run_test_file
    - run_single_test
    - run_test_group (optional)
    - find_tests
    - parser
  - test result
    - filename: optional; enables jumping to test
    - lnum, col, end_lnum, end_col
    - name
    - path
    - id
    - status
    - duration
    - text
    - stacktrace
    - diagnostics
- bug: Rerun via action menu in test panel clears diagnostics
- Defines a (customizable) way to find a test file from a file (integrate with vim-projectionist?)
