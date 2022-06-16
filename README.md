# overseer.nvim

WIP

Will be updated & history overwritten if it's ever ready for release

TODO

- [ ] Extension names could collide. Namespace internal & external extensions separately
- [ ] Figure out how people can best wrap/customize templates
- [ ] Add more tests
- [ ] Add more comments
- [ ] Dynamic window sizing for task editor
- [ ] _maybe_ support other run strategies besides terminal
- [ ] Basic Readme
- [ ] Vim help docs
- [ ] Architecture doc (Template / Task / Component)
- [ ] Extension doc (how to make your own template/component)

VS Code Tasks features

- [x] Task types: process, shell, typescript, node
- [x] [Standard variables](https://code.visualstudio.com/docs/editor/tasks#_variable-substitution)
- [x] [Input variables](https://code.visualstudio.com/docs/editor/variables-reference#_input-variables) (e.g. `${input:variableID}`)
- [x] [Problem matchers](https://code.visualstudio.com/docs/editor/tasks#_processing-task-output-with-problem-matchers)
- [x] Built-in library of problem matchers and patterns (e.g. `$tsc` and `$jshint-stylish`)
- [x] [Compound tasks](https://code.visualstudio.com/docs/editor/tasks#_compound-tasks) (including `dependsOrder = sequence`)
- [x] [Background tasks](https://code.visualstudio.com/docs/editor/tasks#_background-watching-tasks)
- [x] `group` (sets template tag; supports `BUILD`, `TEST`, and `CLEAN`) and `isDefault` (sets priority)
- [x] [Operating system specific properties](https://code.visualstudio.com/docs/editor/tasks#_operating-system-specific-properties)
- [ ] task types: gulp, grunt, and jake
- [ ] shell-specific quoting
- [ ] Specifying a custom shell to use
- [ ] `problemMatcher.fileLocation`
- [ ] `${workspacefolder:*}` variables
- [ ] `${config:*}` variables
- [ ] `${command:*}` variables
- [ ] The `${defaultBuildTask}` variable
- [ ] [Output behavior](https://code.visualstudio.com/docs/editor/tasks#_output-behavior) (probably not going to support this)
- [ ] [Run behavior](https://code.visualstudio.com/docs/editor/tasks#_run-behavior) (probably not going to support this)
