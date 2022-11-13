# Parsers

<!-- TOC -->

- [Writing parsers](#writing-parsers)
- [Problem matchers](#problem-matchers)
- [Built-in problem matchers](#built-in-problem-matchers)
- [Parser nodes](#parser-nodes)
  - [always](#always)
  - [append](#append)
  - [dispatch](#dispatch)
  - [ensure](#ensure)
  - [extract](#extract)
  - [extract_efm](#extract_efm)
  - [extract_json](#extract_json)
  - [extract_multiline](#extract_multiline)
  - [extract_nested](#extract_nested)
  - [invert](#invert)
  - [loop](#loop)
  - [parallel](#parallel)
  - [sequence](#sequence)
  - [set_defaults](#set_defaults)
  - [skip_lines](#skip_lines)
  - [skip_until](#skip_until)
  - [test](#test)

<!-- /TOC -->

The parser library is designed to be a flexible way of parsing many different output formats. The
structure of it is largely inspired by the design of [behavior
trees](<https://en.wikipedia.org/wiki/Behavior_tree_(artificial_intelligence,_robotics_and_control)>)
for game AI. This allows for composition of trees of logic that can handle more complex output
formats than a pure line-by-line parser. For example, here is a a component that parses Go stack
traces:

```lua
{"on_output_parse", parser = {
  stacktrace = {
    -- Skip lines until we hit panic:
    {"test", "^panic:"},
    -- Skip lines until we hit goroutine
    {"skip_until", "^goroutine%s"},
    -- Repeat this parsing sequence
    {"loop",
      {"sequence",
        -- First extract the text of the item, but don't append it to the results yet
        {"extract", { append = false }, { "^(.+)%(.*%)$", "^created by (.+)$" }, "text"},
        -- Extract the filename and lnum, add to the existing item, then append it to the results
        {"extract", "^%s+([^:]+.go):([0-9]+)", "filename", "lnum"}
      }
    }
  }
}}
```

## Writing parsers

Writing a complicated parser can be tricky. To help, there is an interactive tool for iterating on a parser and debugging its logic. You can open the tool with `:lua require('overseer').debug_parser()`. This should open up a view that looks like this:

![parser debugger](https://user-images.githubusercontent.com/506791/180116805-bc230406-b99c-4bb7-a78c-3e4bb9458629.png)

The upper left window contains the parser definition, the lower left window contains the sample output that we want to try to parse, and the right window contains the debug view. Paste your sample output into the lower left window, and start making changes to the parser definition. As you save the new parser, it should recalculate the debug results in the right window.

If you focus the example output window, the debug window will display the state of the parser tree after it ingests that particular line. When you move your cursor around, it should live update to show the new state. This allows you to effectively step through the execution of the parser while inspecting the internal state at every point.

https://user-images.githubusercontent.com/506791/180116685-eaee5876-8692-4834-9916-647c2a1ae98d.mp4

## Problem matchers

Since Overseer supports VS Code's task format, it also has support for parsing output using a [VS Code problem matcher](https://code.visualstudio.com/Docs/editor/tasks#_defining-a-problem-matcher). You can pass these in to the same `on_output_parse` component.

```lua
{"on_output_parse", problem_matcher = {
  owner = 'typescript',
  fileLocation = { "relative", "${cwd}" },
  pattern = {
    regexp = "^([^\\s].*)[\\(:](\\d+)[,:](\\d+)(?:\\):\\s+|\\s+-\\s+)(error|warning|info)\\s+TS(\\d+)\\s*:\\s*(.*)$",
    -- Optionally specify a vim-compatible regex for matching:
    vim_regexp = "\\v^([^[:space:]].*)[\\(:](\\d+)[,:](\\d+)(\\):\\s+|\\s+-\\s+)(error|warning|info)\\s+TS(\\d+)\\s*:\\s*(.*)$",
    -- Optionally specify a lua pattern for matching:
    lua_pat = "^([^%s].*)[\\(:](%d+)[,:](%d+)[^%a]*(%a+)%s+TS(%d+)%s*:%s*(.*)$",
    file = 1,
    line = 2,
    column = 3,
    severity = 5,
    code = 6,
    message = 7,
  },
}}
```

Note that the structure of the problem matcher is the same as the VS Code definition, with the exception that it supports a `vim_regexp` key and/or a `lua_pat` key. Because JS regexes are slightly different from vim regexes (e.g. vim regex doesn't support non-capturing groups `(?:text)`), sometimes the regex from the VS Code definition will not work. The fix for this is to rewrite it as a vim-compatible regex or as a lua pattern. When either of these two keys are present, overseer will use them to perform the matching. If not, it will attempt to convert the `regexp` into a vim-compatible regex and use that.

For convenience, you can also use the built-in problem matcher definitions in `on_output_parse`:

```lua
{"on_output_parse", problem_matcher = "$tsc-watch"}
```

## Built-in problem matchers

Patterns:

<!-- problem_matcher_patterns -->

- `$cpp`
- `$csc`
- `$eslint-compact`
- `$eslint-stylish`
- `$go`
- `$gulp-tsc`
- `$jshint`
- `$jshint-stylish`
- `$lessCompile`
- `$msCompile`
- `$nvcc-location`
- `$tsc`
- `$vb`
<!-- /problem_matcher_patterns -->

Problem matchers:

<!-- problem_matchers -->

- `$gcc`
- `$lessc`
- `$node-sass`
- `$nvcc`
- `$tsc`
- `$tsc-watch`
<!-- /problem_matchers -->

## Parser nodes

This is a list of the parser nodes that are built-in to overseer. They can be found in [lua/overseer/parser](../lua/overseer/parser)

### always

[always.lua](../lua/overseer/parser/always.lua)

A decorator that always returns SUCCESS

```lua
{"always", child}
{"always", succeed, child}
```

| Param   | Type      | Desc                                                 |
| ------- | --------- | ---------------------------------------------------- |
| succeed | `boolean` | Set to false to always return FAILURE (default true) |
| child   | `parser`  | The child parser node                                |

#### Examples

An extract node that returns SUCCESS even when it fails

```lua
{"always",
  {"extract", "^([^%s].+):(%d+): (.+)$", "filename", "lnum", "text" }
}
```

### append

[append.lua](../lua/overseer/parser/append.lua)

Append the current item to the results list

```lua
{"append"}
{"append", opts}
```

| Param | Type        | Desc                  |                                                                   |
| ----- | ----------- | --------------------- | ----------------------------------------------------------------- |
| opts  | `object`    | Configuration options |                                                                   |
|       | postprocess | `function`            | Call this function to do post-extraction processing on the values |

### dispatch

[dispatch.lua](../lua/overseer/parser/dispatch.lua)

Dispatch an event

```lua
{"dispatch", name, arg...}
```

| Param | Type         | Desc                                                               |
| ----- | ------------ | ------------------------------------------------------------------ |
| name  | `string`     | Event name                                                         |
| arg   | `any\|fun()` | A value to send with the event, or a function that creates a value |

#### Examples

clear_results will clear all current results from the parser. Pass `true` to only clear the results under the current key

```lua
{"dispatch", "clear_results"}
```

set_results is used by the on_output_parse component to immediately set the current results on the task

```lua
{"dispatch", "set_results"}
```

### ensure

[ensure.lua](../lua/overseer/parser/ensure.lua)

Decorator that runs a child until it succeeds

```lua
{"ensure", child}
{"ensure", succeed, child}
```

| Param   | Type      | Desc                                                   |
| ------- | --------- | ------------------------------------------------------ |
| succeed | `boolean` | Set to false to run child until failure (default true) |
| child   | `parser`  | The child parser node                                  |

#### Examples

An extract node that runs until it successfully parses

```lua
{"ensure",
  {"extract", "^([^%s].+):(%d+): (.+)$", "filename", "lnum", "text" }
}
```

### extract

[extract.lua](../lua/overseer/parser/extract.lua)

Parse a line into an object and append it to the results

```lua
{"extract", pattern, field...}
{"extract", opts, pattern, field...}
```

| Param   | Type                         | Desc                                                                                                           |                                                                                                                    |
| ------- | ---------------------------- | -------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| opts    | `object`                     | Configuration options                                                                                          |                                                                                                                    |
|         | consume                      | `boolean`                                                                                                      | Consumes the line of input, blocking execution until the next line is fed in (default true)                        |
|         | append                       | `boolean`                                                                                                      | After parsing, append the item to the results list. When false, the pending item will stick around. (default true) |
|         | regex                        | `boolean`                                                                                                      | Use vim regex instead of lua pattern (see :help pattern) (default false)                                           |
|         | postprocess                  | `function`                                                                                                     | Call this function to do post-extraction processing on the values                                                  |
| pattern | `string\|function\|string[]` | The lua pattern to use for matching. Must have the same number of capture groups as there are field arguments. |                                                                                                                    |
| field   | `string`                     | The name of the extracted capture group. Use `"_"` to discard.                                                 |                                                                                                                    |

#### Examples

Convert a line in the format of `/path/to/file.txt:123: This is a message` into an item `{filename = "/path/to/file.txt", lnum = 123, text = "This is a message"}`

```lua
{"extract", "^([^%s].+):(%d+): (.+)$", "filename", "lnum", "text" }
```

The same logic, but using a vim regex

```lua
{"extract", {regex = true}, "\\v^([^:space:].+):(\\d+): (.+)$", "filename", "lnum", "text" }
```

### extract_efm

[extract_efm.lua](../lua/overseer/parser/extract_efm.lua)

Parse a line using vim's errorformat and append it to the results

```lua
{"extract_efm"}
{"extract_efm", opts}
```

| Param | Type        | Desc                  |                                                                                                                    |
| ----- | ----------- | --------------------- | ------------------------------------------------------------------------------------------------------------------ |
| opts  | `object`    | Configuration options |                                                                                                                    |
|       | efm         | `string`              | The errorformat string to use. Defaults to current option value.                                                   |
|       | consume     | `boolean`             | Consumes the line of input, blocking execution until the next line is fed in (default true)                        |
|       | append      | `boolean`             | After parsing, append the item to the results list. When false, the pending item will stick around. (default true) |
|       | test        | `function`            | A function that operates on the parsed value and returns true/false for SUCCESS/FAILURE                            |
|       | postprocess | `function`            | Call this function to do post-extraction processing on the values                                                  |

### extract_json

[extract_json.lua](../lua/overseer/parser/extract_json.lua)

Parse a line as json and append it to the results

```lua
{"extract_json"}
{"extract_json", opts}
```

| Param | Type        | Desc                  |                                                                                                                    |
| ----- | ----------- | --------------------- | ------------------------------------------------------------------------------------------------------------------ |
| opts  | `object`    | Configuration options |                                                                                                                    |
|       | consume     | `boolean`             | Consumes the line of input, blocking execution until the next line is fed in (default true)                        |
|       | append      | `boolean`             | After parsing, append the item to the results list. When false, the pending item will stick around. (default true) |
|       | test        | `function`            | A function that operates on the parsed value and returns true/false for SUCCESS/FAILURE                            |
|       | postprocess | `function`            | Call this function to do post-extraction processing on the values                                                  |

### extract_multiline

[extract_multiline.lua](../lua/overseer/parser/extract_multiline.lua)

Extract a multiline string as a single field on an item

```lua
{"extract_multiline", pattern, field}
{"extract_multiline", opts, pattern, field}
```

| Param   | Type               | Desc                                                                                                                  |                                                                                                                    |
| ------- | ------------------ | --------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| opts    | `object`           | Configuration options                                                                                                 |                                                                                                                    |
|         | append             | `boolean`                                                                                                             | After parsing, append the item to the results list. When false, the pending item will stick around. (default true) |
| pattern | `string\|function` | The lua pattern to use for matching. As long as the pattern matches, lines will continue to be appended to the field. |                                                                                                                    |
| field   | `string`           | The name of the field to add to the item                                                                              |                                                                                                                    |

#### Examples

Extract all indented lines as a message

```lua
{"extract_multiline", "^(    .+)", "message"}
```

### extract_nested

[extract_nested.lua](../lua/overseer/parser/extract_nested.lua)

Run a subparser and put the extracted results on the field of an item

```lua
{"extract_nested", field, child}
{"extract_nested", opts, field, child}
```

| Param | Type          | Desc                                     |                                                                                                                    |
| ----- | ------------- | ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| opts  | `object`      | Configuration options                    |                                                                                                                    |
|       | append        | `boolean`                                | After parsing, append the item to the results list. When false, the pending item will stick around. (default true) |
|       | fail_on_empty | `boolean`                                | Return FAILURE if there are no results from the child (default true)                                               |
| field | `string`      | The name of the field to add to the item |                                                                                                                    |
| child | `parser`      | The child parser node                    |                                                                                                                    |

#### Examples

Extract a golang test failure, then add the stacktrace to it (if present)

```lua
{"extract",
  {
    regex = true,
    append = false,
  },
  "\\v^--- (FAIL|PASS|SKIP): ([^[:space:] ]+) \\(([0-9\\.]+)s\\)",
  "status",
  "name",
  "duration",
},
{"always",
  {"sequence",
    {"test", "^panic:"},
    {"skip_until", "^goroutine%s"},
    {"extract_nested",
      { append = false },
      "stacktrace",
      {"loop",
        {"sequence",
          {"extract",{ append = false }, { "^(.+)%(.*%)$", "^created by (.+)$" }, "text"},
          {"extract","^%s+([^:]+.go):([0-9]+)", "filename", "lnum"}
        }
      }
    }
  }
}
```

### invert

[invert.lua](../lua/overseer/parser/invert.lua)

A decorator that inverts the child's return value

```lua
{"invert", child}
```

| Param | Type     | Desc                  |
| ----- | -------- | --------------------- |
| child | `parser` | The child parser node |

#### Examples

An extract node that returns SUCCESS when it fails, and vice-versa

```lua
{"invert",
  {"extract", "^([^%s].+):(%d+): (.+)$", "filename", "lnum", "text" }
}
```

### loop

[loop.lua](../lua/overseer/parser/loop.lua)

A decorator that repeats the child

```lua
{"loop", child}
{"loop", opts, child}
```

| Param | Type           | Desc                  |                                                          |
| ----- | -------------- | --------------------- | -------------------------------------------------------- |
| opts  | `object`       | Configuration options |                                                          |
|       | ignore_failure | `boolean`             | Keep looping even when the child fails (default false)   |
|       | repetitions    | `integer`             | When set, loop a set number of times then return SUCCESS |
| child | `parser`       | The child parser node |                                                          |

### parallel

[parallel.lua](../lua/overseer/parser/parallel.lua)

Run the child nodes in parallel

```lua
{"parallel", child...}
{"parallel", opts, child...}
```

| Param | Type                   | Desc                                                              |                                                                       |
| ----- | ---------------------- | ----------------------------------------------------------------- | --------------------------------------------------------------------- |
| opts  | `object`               | Configuration options                                             |                                                                       |
|       | break_on_first_failure | `boolean`                                                         | Stop executing as soon as a child returns FAILURE (default true)      |
|       | break_on_first_success | `boolean`                                                         | Stop executing as soon as a child returns SUCCESS (default false)     |
|       | reset_children         | `boolean`                                                         | Reset all children at the beginning of each iteration (default false) |
| child | `parser`               | The child parser nodes. Can be passed in as varargs or as a list. |                                                                       |

### sequence

[sequence.lua](../lua/overseer/parser/sequence.lua)

Run the child nodes sequentially

```lua
{"sequence", child...}
{"sequence", opts, child...}
```

| Param | Type                   | Desc                                                              |                                                                   |
| ----- | ---------------------- | ----------------------------------------------------------------- | ----------------------------------------------------------------- |
| opts  | `object`               | Configuration options                                             |                                                                   |
|       | break_on_first_failure | `boolean`                                                         | Stop executing as soon as a child returns FAILURE (default true)  |
|       | break_on_first_success | `boolean`                                                         | Stop executing as soon as a child returns SUCCESS (default false) |
| child | `parser`               | The child parser nodes. Can be passed in as varargs or as a list. |                                                                   |

#### Examples

Extract the message text from one line, then the filename and lnum from the next line

```lua
{"sequence",
  {"extract", { append = false }, { "^(.+)%(.*%)$", "^created by (.+)$" }, "text"},
  {"extract", "^%s+([^:]+.go):([0-9]+)", "filename", "lnum"}
}
```

### set_defaults

[set_defaults.lua](../lua/overseer/parser/set_defaults.lua)

A decorator that adds values to any items extracted by the child

```lua
{"set_defaults", child}
{"set_defaults", opts, child}
```

| Param | Type       | Desc                  |                                                                                                 |
| ----- | ---------- | --------------------- | ----------------------------------------------------------------------------------------------- |
| opts  | `object`   | Configuration options |                                                                                                 |
|       | values     | `object`              | Hardcoded key-value pairs to set as default values                                              |
|       | hoist_item | `boolean`             | Take the current pending item, and use its fields as the default key-value pairs (default true) |
| child | `parser`   | The child parser node |                                                                                                 |

#### Examples

Extract the filename from a header line, then for each line of output beneath it parse the test name + status, and also add the filename to each item

```lua
{"sequence",
  {"extract", {append = false}, "^Test result (.+)$", "filename"}
  {"set_defaults",
    {"loop",
      {"extract", "^Test (.+): (.+)$", "test_name", "status"}
    }
  }
}
```

### skip_lines

[skip_lines.lua](../lua/overseer/parser/skip_lines.lua)

Skip over a set number of lines

```lua
{"skip_lines", count}
```

| Param | Type      | Desc                   |
| ----- | --------- | ---------------------- |
| count | `integer` | How many lines to skip |

### skip_until

[skip_until.lua](../lua/overseer/parser/skip_until.lua)

Skip over lines until one matches

```lua
{"skip_until", pattern...}
{"skip_until", opts, pattern...}
```

| Param   | Type                                          | Desc                                                                                   |                                                                                         |
| ------- | --------------------------------------------- | -------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| opts    | `object`                                      | Configuration options                                                                  |                                                                                         |
|         | skip_matching_line                            | `boolean`                                                                              | Consumes the line that matches. Later nodes will only see the next line. (default true) |
|         | regex                                         | `boolean`                                                                              | Use vim regex instead of lua pattern (see :help pattern) (default true)                 |
| pattern | `string\|string[]\|fun(line: string): string` | The lua pattern to use for matching. The node succeeds if any of these patterns match. |                                                                                         |

#### Examples

Skip input until we see "Error" or "Warning"

```lua
{"skip_until", "^Error:", "^Warning:"}
```

### test

[test.lua](../lua/overseer/parser/test.lua)

Returns SUCCESS when the line matches the pattern

```lua
{"test", pattern}
{"test", opts, pattern}
```

| Param   | Type                                | Desc                                                  |                                                                         |
| ------- | ----------------------------------- | ----------------------------------------------------- | ----------------------------------------------------------------------- |
| opts    | `object`                            | Configuration options                                 |                                                                         |
|         | regex                               | `boolean`                                             | Use vim regex instead of lua pattern (see :help pattern) (default true) |
| pattern | `string\|fun(line: string): string` | The lua pattern to use for matching, or test function |                                                                         |

#### Examples

Fail until a line starts with "panic:"

```lua
{"test", "^panic:"}
```
