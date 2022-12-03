# Strategies

The strategy is what controls how a task is actually run. The default, `terminal`, takes the task `cmd` and passes it to `vim.fn.termopen()`. Other strategies can act as a drop-in replacement for the `terminal` strategy with different features (e.g. `jobstart`), and some can change the behavior of the task entirely (e.g. `orchestrator`).

<!-- TOC -->

- [terminal()](#terminal)
- [jobstart(opts)](#jobstartopts)
- [orchestrator(opts)](#orchestratoropts)
- [test()](#test)

<!-- /TOC -->

<!-- API -->

## terminal()

`terminal(): overseer.Strategy` \
Run tasks using termopen()


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
        { "shell", cmd = "lessc styles.less styles.css" },
      },
      "npm serve",  -- Step 3: serve
    },
  },
})
```

## test()

`test(): overseer.Strategy` \
Strategy used for unit testing



<!-- /API -->
