# TODO

- customize test integration dirs post-setup() (for machine-local config)
- Filter test panel by status

## Future

- More test integrations
- Run after build
- Test playlists
- Debug test integration
- Code coverage integration
- command to rerun failed tests (set limit on number of concurrent jobs)
- Panel for _file_ tests
- Document all properties of:
  - integration
    - name
    - is_filename_test
    - is_workspace_match
    - cmd (recommended)
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