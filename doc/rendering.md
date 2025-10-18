# Rendering

These are some built-in task formatting functions and a library of useful pieces that you can use to build your own formats.

<!-- TOC -->

- [format_standard(task)](#format_standardtask)
- [format_compact(task)](#format_compacttask)
- [format_verbose(task)](#format_verbosetask)
- [status(task)](#statustask)
- [name(task)](#nametask)
- [status_and_name(task)](#status_and_nametask)
- [cmd(task)](#cmdtask)
- [result_lines(task, opts)](#result_linestask-opts)
- [duration(task, opts)](#durationtask-opts)
- [time_since_completed(task, opts)](#time_since_completedtask-opts)
- [output_lines(task, opts)](#output_linestask-opts)
- [source_lines(task, opts)](#source_linestask-opts)
- [join(a, b, sep)](#joina-b-sep)
- [remove_empty_lines(lines)](#remove_empty_lineslines)

<!-- /TOC -->

<!-- render.API -->

## format_standard(task)

`format_standard(task): overseer.TextChunk[]` \
The default format for tasks in the task list

| Param | Type            | Desc |
| ----- | --------------- | ---- |
| task  | `overseer.Task` |      |

Returns:

| Type                 | Desc |
| -------------------- | ---- |
| overseer.TextChunk[] | []   |

**Examples:**
```lua
require("overseer").setup({
  task_list = {
    render = function(task)
      return require("overseer.render").format_standard(task)
    end,
  },
})
```

## format_compact(task)

`format_compact(task): overseer.TextChunk[]` \
A more compact format for tasks

| Param | Type            | Desc |
| ----- | --------------- | ---- |
| task  | `overseer.Task` |      |

Returns:

| Type                 | Desc |
| -------------------- | ---- |
| overseer.TextChunk[] | []   |

**Examples:**
```lua
require("overseer").setup({
  task_list = {
    render = function(task)
      return require("overseer.render").format_compact(task)
    end,
  },
})
```

## format_verbose(task)

`format_verbose(task): overseer.TextChunk[]` \
A more verbose format for tasks

| Param | Type            | Desc |
| ----- | --------------- | ---- |
| task  | `overseer.Task` |      |

Returns:

| Type                 | Desc |
| -------------------- | ---- |
| overseer.TextChunk[] | []   |

**Examples:**
```lua
require("overseer").setup({
  task_list = {
    render = function(task)
      return require("overseer.render").format_verbose(task)
    end,
  },
})
```

## status(task)

`status(task): overseer.TextChunk[]` \
Text chunks that display the status of a task

| Param | Type            | Desc |
| ----- | --------------- | ---- |
| task  | `overseer.Task` |      |

**Examples:**
```lua
require("overseer").setup({
  task_list = {
    render = function(task)
      local render = require("overseer.render")
      return {
        render.status(task),
        { { task.name, "OverseerTask" } },
      }
    end,
  },
})
```

## name(task)

`name(task): overseer.TextChunk[]` \
Text chunks that display the name of a task

| Param | Type            | Desc |
| ----- | --------------- | ---- |
| task  | `overseer.Task` |      |

**Examples:**
```lua
require("overseer").setup({
  task_list = {
    render = function(task)
      local render = require("overseer.render")
      return {
        render.name(task),
      }
    end,
  },
})
```

## status_and_name(task)

`status_and_name(task): overseer.TextChunk[]` \
Text chunks that display the status and name of a task

| Param | Type            | Desc |
| ----- | --------------- | ---- |
| task  | `overseer.Task` |      |

**Examples:**
```lua
require("overseer").setup({
  task_list = {
    render = function(task)
      local render = require("overseer.render")
      return {
        render.status_and_name(task),
      }
    end,
  },
})
```

## cmd(task)

`cmd(task): overseer.TextChunk[]` \
Text chunks that display the command that was run

| Param | Type            | Desc |
| ----- | --------------- | ---- |
| task  | `overseer.Task` |      |

**Examples:**
```lua
require("overseer").setup({
  task_list = {
    render = function(task)
      local render = require("overseer.render")
      return {
        { { task.name, "OverseerTask" } },
        render.cmd(task),
      }
    end,
  },
})
```

## result_lines(task, opts)

`result_lines(task, opts): overseer.TextChunk[]` \
Lines that display the result of a task

| Param | Type                       | Desc |
| ----- | -------------------------- | ---- |
| task  | `overseer.Task`            |      |
| opts  | `nil\|{oneline?: boolean}` |      |

Returns:

| Type                 | Desc |
| -------------------- | ---- |
| overseer.TextChunk[] | []   |

**Examples:**
```lua
require("overseer").setup({
  task_list = {
    render = function(task)
      local render = require("overseer.render")
      return vim.list_extend({
        { { task.name, "OverseerTask" } },
      }, render.result_lines(task, { oneline = false }))
    end,
  },
})
```

## duration(task, opts)

`duration(task, opts): overseer.TextChunk[]` \
Text chunks that display how long a task has been running / ran for

| Param | Type                       | Desc |
| ----- | -------------------------- | ---- |
| task  | `overseer.Task`            |      |
| opts  | `nil\|{hl_group?: string}` |      |

**Examples:**
```lua
require("overseer").setup({
  task_list = {
    render = function(task)
      local render = require("overseer.render")
      return {
        { { task.name, "OverseerTask" } },
        render.duration(task),
      }
    end,
  },
})
```

## time_since_completed(task, opts)

`time_since_completed(task, opts): overseer.TextChunk[]` \
Text chunks that display the time since a task was completed

| Param | Type                       | Desc |
| ----- | -------------------------- | ---- |
| task  | `overseer.Task`            |      |
| opts  | `nil\|{hl_group?: string}` |      |

**Examples:**
```lua
require("overseer").setup({
  task_list = {
    render = function(task)
      local render = require("overseer.render")
      return {
        { { task.name, "OverseerTask" } },
        render.time_since_completed(task),
      }
    end,
  },
})
```

## output_lines(task, opts)

`output_lines(task, opts): overseer.TextChunk[]` \
Lines that display the last few lines of output from a task

| Param | Type                                                                    | Desc |
| ----- | ----------------------------------------------------------------------- | ---- |
| task  | `overseer.Task`                                                         |      |
| opts  | `nil\|{num_lines?: integer, prefix?: string, prefix_hl_group?: string}` |      |

Returns:

| Type                 | Desc |
| -------------------- | ---- |
| overseer.TextChunk[] | []   |

**Examples:**
```lua
require("overseer").setup({
  task_list = {
    render = function(task)
      local render = require("overseer.render")
      return vim.list_extend({
        { { task.name, "OverseerTask" } },
      }, render.output_lines(task, { num_lines = 3, prefix = "$ " }))
    end,
  },
})
```

## source_lines(task, opts)

`source_lines(task, opts): overseer.TextChunk[]` \
Lines that display the source of a wrapped vim.system or vim.fn.jobstart task

| Param | Type                       | Desc |
| ----- | -------------------------- | ---- |
| task  | `overseer.Task`            |      |
| opts  | `nil\|{hl_group?: string}` |      |

Returns:

| Type                 | Desc |
| -------------------- | ---- |
| overseer.TextChunk[] | []   |

**Examples:**
```lua
require("overseer").setup({
  task_list = {
    render = function(task)
      local render = require("overseer.render")
      return vim.list_extend({
        { { task.name, "OverseerTask" } },
      }, render.source_lines(task, { num_lines = 3, prefix = "$ " }))
    end,
  },
})
```

## join(a, b, sep)

`join(a, b, sep): overseer.TextChunk[]` \
Join two lists of text chunks together with a separator

| Param | Type                              | Desc |
| ----- | --------------------------------- | ---- |
| a     | `overseer.TextChunk[]`            |      |
| b     | `overseer.TextChunk[]`            |      |
| sep   | `nil\|string\|overseer.TextChunk` |      |

**Examples:**
```lua
require("overseer").setup({
  task_list = {
    render = function(task)
      local render = require("overseer.render")
      return {
        render.join(render.status(task), render.name(task), ": "),
      }
    end,
  },
})
```

## remove_empty_lines(lines)

`remove_empty_lines(lines): overseer.TextChunk[]` \
Removes empty lines from a list of lines (each line is a list of text chunks)

| Param | Type                   | Desc |
| ----- | ---------------------- | ---- |
| lines | `overseer.TextChunk[]` | []   |

Returns:

| Type                 | Desc |
| -------------------- | ---- |
| overseer.TextChunk[] | []   |

**Examples:**
```lua
require("overseer").setup({
  task_list = {
    render = function(task)
      local render = require("overseer.render")
      local ret = vim.list_extend({
        { { task.name, "OverseerTask" } },
      }, render.output_lines(task, { num_lines = 3, prefix = "$ " }))
      return render.remove_empty_lines(ret)
    end,
  },
})
```


<!-- /render.API -->
