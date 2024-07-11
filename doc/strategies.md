# Strategies

The strategy is what controls how a task is actually run. The default, `terminal`, takes the task `cmd` and passes it to `vim.fn.termopen()`. Other strategies can act as a drop-in replacement for the `terminal` strategy with different features (e.g. `jobstart`), and some can change the behavior of the task entirely (e.g. `orchestrator`).

<!-- TOC -->

- [jobstart(opts)](#jobstartopts)
- [orchestrator(opts)](#orchestratoropts)
- [terminal()](#terminal)
- [test()](#test)
- [toggleterm(opts)](#toggletermopts)

<!-- /TOC -->

<!-- API -->

## jobstart(opts)

`jobstart(opts): overseer.Strategy` \
Run tasks using jobstart()

| Param | Type            | Desc      |                                                                                                                                                  |
| ----- | --------------- | --------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| opts  | `nil\|table`    |           |                                                                                                                                                  |
|       | preserve_output | `boolean` | If true, don't clear the buffer when tasks restart                                                                                               |
|       | use_terminal    | `boolean` | If false, use a normal non-terminal buffer to store the output. This may produce unwanted results if the task outputs terminal escape sequences. |

## orchestrator(opts)

`orchestrator(opts): overseer.Strategy` \
Strategy for a meta-task that manage a sequence of other tasks

| Param | Type    | Desc    |                                                                                       |
| ----- | ------- | ------- | ------------------------------------------------------------------------------------- |
| opts  | `table` |         |                                                                                       |
|       | tasks   | `table` | A list of task definitions to run. Can include sub-lists that will be run in parallel |

**Examples:**
```lua
overseer.new_task({
  name = "Build and serve app",
  strategy = {
    "orchestrator",
    tasks = {
      "make clean", -- Step 1: clean
      {             -- Step 2: build js and css in parallel
         "npm build",
        { cmd = {"lessc", "styles.less", "styles.css"} },
      },
      "npm serve",  -- Step 3: serve
    },
  },
})
```

## terminal()

`terminal(): overseer.Strategy` \
Run tasks using termopen()


## test()

`test(): overseer.Strategy` \
Strategy used for unit testing


## toggleterm(opts)

`toggleterm(opts): overseer.Strategy` \
Run tasks using the toggleterm plugin

| Param | Type                                    | Desc                                            |                                                                          |
| ----- | --------------------------------------- | ----------------------------------------------- | ------------------------------------------------------------------------ |
| opts  | `nil\|overseeer.ToggleTermStrategyOpts` |                                                 |                                                                          |
|       | use_shell                               | `nil\|boolean`                                  | load user shell before running task                                      |
|       | size                                    | `nil\|number`                                   | the size of the split if direction is vertical or horizontal             |
|       | direction                               | `nil\|"vertical"\|"horizontal"\|"tab"\|"float"` |                                                                          |
|       | highlights                              | `nil\|table`                                    | map to a highlight group name and a table of it's values                 |
|       | auto_scroll                             | `nil\|boolean`                                  | automatically scroll to the bottom on task output                        |
|       | close_on_exit                           | `nil\|boolean`                                  | close the terminal and delete terminal buffer (if open) after task exits |
|       | quit_on_exit                            | `nil\|"never"\|"always"\|"success"`             | close the terminal window (if open) after task exits                     |
|       | open_on_start                           | `nil\|boolean`                                  | toggle open the terminal automatically when task starts                  |
|       | hidden                                  | `nil\|boolean`                                  | cannot be toggled with normal ToggleTerm commands                        |
|       | on_create                               | `nil\|fun(term: table)`                         | function to execute on terminal creation                                 |


<!-- /API -->
