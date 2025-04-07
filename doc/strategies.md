# Strategies

The strategy is what controls how a task is actually run. The default, `terminal`, takes the task `cmd` and passes it to `vim.fn.termopen()`. Other strategies can act as a drop-in replacement for the `terminal` strategy with different features (e.g. `jobstart`), and some can change the behavior of the task entirely (e.g. `orchestrator`).

<!-- TOC -->

- [jobstart(opts)](#jobstartopts)
- [orchestrator(opts)](#orchestratoropts)
- [system(opts)](#systemopts)
- [test()](#test)

<!-- /TOC -->

<!-- API -->

## jobstart(opts)

`jobstart(opts): overseer.Strategy` \
Run tasks using jobstart()

| Param            | Type                                 | Desc                                                                                                                                             |
| ---------------- | ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| opts             | `nil\|overseer.JobstartStrategyOpts` |                                                                                                                                                  |
| >preserve_output | `nil\|boolean`                       | If true, don't clear the buffer when tasks restart                                                                                               |
| >use_terminal    | `nil\|boolean`                       | If false, use a normal non-terminal buffer to store the output. This may produce unwanted results if the task outputs terminal escape sequences. |
| >wrap_opts       | `nil\|table`                         | Opts that were passed to jobstart(). We should wrap them                                                                                         |

## orchestrator(opts)

`orchestrator(opts): overseer.Strategy` \
Strategy for a meta-task that manage a sequence of other tasks

| Param  | Type    | Desc                                                                                  |
| ------ | ------- | ------------------------------------------------------------------------------------- |
| opts   | `table` |                                                                                       |
| >tasks | `table` | A list of task definitions to run. Can include sub-lists that will be run in parallel |

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

## system(opts)

`system(opts): overseer.Strategy`

| Param      | Type                                 | Desc                                                       |
| ---------- | ------------------------------------ | ---------------------------------------------------------- |
| opts       | `nil\|overseer.SystemStrategyOpts`   |                                                            |
| >wrap_opts | `nil\|vim.SystemOpts`                | Opts that were passed to vim.system(). We should wrap them |
| >wrap_exit | `nil\|fun(out: vim.SystemCompleted)` |                                                            |

## test()

`test(): overseer.Strategy` \
Strategy used for unit testing



<!-- /API -->
