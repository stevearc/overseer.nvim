# TODO

- Filter test panel by status

## Future

- More test integrations
  - python pytest
  - ruby rspec
  - rust cargotest
  - js mocha
  - js jest
  - java junit?
  - csharp dotnettest
  - another go framework?
- Run after build
- Test playlists
- Debug test integration
- Code coverage integration
- Panel for _file_ tests
- Rerun group for test frameworks don't support it
- Document all properties of:
  - integration
    - name
    - is_filename_test
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
    - text
    - stacktrace
    - diagnostics
- bug: Rerun via action menu in test panel clears diagnostics
- python unittest tests sometimes get stuck in running status
- Defines a (customizable) way to find a test file from a file (integrate with vim-projectionist?)
