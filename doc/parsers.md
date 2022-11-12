# Parsers

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

# Writing parsers

Writing a complicated parser can be tricky. To help, there is an interactive tool for iterating on a parser and debugging its logic. You can open the tool with `:lua require('overseer.parser.debug').start_debug_session()`. This should open up a view that looks like this:

![parser debugger](https://user-images.githubusercontent.com/506791/180116805-bc230406-b99c-4bb7-a78c-3e4bb9458629.png)

The upper left window contains the parser definition, the lower left window contains the sample output that we want to try to parse, and the right window contains the debug view. Paste your sample output into the lower left window, and start making changes to the parser definition. As you save the new parser, it should recalculate the debug results in the right window.

If you focus the example output window, the debug window will display the state of the parser tree after it ingests that particular line. When you move your cursor around, it should live update to show the new state. This allows you to effectively step through the execution of the parser while inspecting the internal state at every point.

https://user-images.githubusercontent.com/506791/180116685-eaee5876-8692-4834-9916-647c2a1ae98d.mp4

# Parser nodes

This is a list of the parser nodes that are built-in to overseer. They can be found in [lua/overseer/parser](../lua/overseer/parser)

- [always](#always)
- [append](#append)
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

## [always](../lua/overseer/parser/always.lua)

A decorator that always returns SUCCESS \

```lua
{"always", child}
{"always", succeed, child}
```

**succeed**[`boolean`]: Set to false to always return FAILURE (default `true`) \
**child**[`parser`]: The child parser node \

### Examples

An extract node that returns SUCCESS even when it fails

```lua
{"always",
  {"extract", "^([^%s].+):(%d+): (.+)$", "filename", "lnum", "text" }
}
```


## [append](../lua/overseer/parser/append.lua)

Append the current item to the results list \

```lua
{"append"}
{"append", opts}
```

**opts**[`object`]: Configuration options \
&nbsp;&nbsp;&nbsp;&nbsp;**postprocess**[`function`]: Call this function to do post-extraction processing on the values \

## [ensure](../lua/overseer/parser/ensure.lua)

Decorator that runs a child until it succeeds \

```lua
{"ensure", child}
{"ensure", succeed, child}
```

**succeed**[`boolean`]: Set to false to run child until failure (default `true`) \
**child**[`parser`]: The child parser node \

### Examples

An extract node that runs until it successfully parses

```lua
{"ensure",
  {"extract", "^([^%s].+):(%d+): (.+)$", "filename", "lnum", "text" }
}
```


## [extract](../lua/overseer/parser/extract.lua)

Parse a line into an object and append it to the results \

```lua
{"extract", pattern, field...}
{"extract", opts, pattern, field...}
```

**opts**[`object`]: Configuration options \
&nbsp;&nbsp;&nbsp;&nbsp;**consume**[`boolean`]: Consumes the line of input, blocking execution until the next line is fed in (default `true`) \
&nbsp;&nbsp;&nbsp;&nbsp;**append**[`boolean`]: After parsing, append the item to the results list. When false, the pending item will stick around. (default `true`) \
&nbsp;&nbsp;&nbsp;&nbsp;**regex**[`boolean`]: Use vim regex instead of lua pattern (see :help pattern) (default `false`) \
&nbsp;&nbsp;&nbsp;&nbsp;**postprocess**[`function`]: Call this function to do post-extraction processing on the values \
**pattern**[`string|function`]: The lua pattern to use for matching. Must have the same number of capture groups as there are field arguments. \
    Can also be a list of strings/functions and it will try matching against all of them \
**field**[`string`]: The name of the extracted capture group. Use `"_"` to discard. \

### Examples

Convert a line in the format of `/path/to/file.txt:123: This is a message` into an item `{filename = "/path/to/file.txt", lnum = 123, text = "This is a message"}`

```lua
{"extract", "^([^%s].+):(%d+): (.+)$", "filename", "lnum", "text" }
```

The same logic, but using a vim regex

```lua
{"extract", {regex = true}, "\\v^([^:space:].+):(\\d+): (.+)$", "filename", "lnum", "text" }
```


## [extract_efm](../lua/overseer/parser/extract_efm.lua)

Parse a line using vim's errorformat and append it to the results \

```lua
{"extract_efm"}
{"extract_efm", opts}
```

**opts**[`object`]: Configuration options \
&nbsp;&nbsp;&nbsp;&nbsp;**efm**[`string`]: The errorformat string to use. Defaults to current option value. \
&nbsp;&nbsp;&nbsp;&nbsp;**consume**[`boolean`]: Consumes the line of input, blocking execution until the next line is fed in (default `true`) \
&nbsp;&nbsp;&nbsp;&nbsp;**append**[`boolean`]: After parsing, append the item to the results list. When false, the pending item will stick around. (default `true`) \
&nbsp;&nbsp;&nbsp;&nbsp;**test**[`function`]: A function that operates on the parsed value and returns true/false for SUCCESS/FAILURE \
&nbsp;&nbsp;&nbsp;&nbsp;**postprocess**[`function`]: Call this function to do post-extraction processing on the values \

## [extract_json](../lua/overseer/parser/extract_json.lua)

Parse a line as json and append it to the results \

```lua
{"extract_json"}
{"extract_json", opts}
```

**opts**[`object`]: Configuration options \
&nbsp;&nbsp;&nbsp;&nbsp;**consume**[`boolean`]: Consumes the line of input, blocking execution until the next line is fed in (default `true`) \
&nbsp;&nbsp;&nbsp;&nbsp;**append**[`boolean`]: After parsing, append the item to the results list. When false, the pending item will stick around. (default `true`) \
&nbsp;&nbsp;&nbsp;&nbsp;**test**[`function`]: A function that operates on the parsed value and returns true/false for SUCCESS/FAILURE \
&nbsp;&nbsp;&nbsp;&nbsp;**postprocess**[`function`]: Call this function to do post-extraction processing on the values \

## [extract_multiline](../lua/overseer/parser/extract_multiline.lua)

Extract a multiline string as a single field on an item \

```lua
{"extract_multiline", pattern, field}
{"extract_multiline", opts, pattern, field}
```

**opts**[`object`]: Configuration options \
&nbsp;&nbsp;&nbsp;&nbsp;**append**[`boolean`]: After parsing, append the item to the results list. When false, the pending item will stick around. (default `true`) \
**pattern**[`string|function`]: The lua pattern to use for matching. As long as the pattern matches, lines will continue to be appended to the field. \
**field**[`string`]: The name of the field to add to the item \

### Examples

Extract all indented lines as a message

```lua
{"extract_multiline", "^(    .+)", "message"}
```


## [extract_nested](../lua/overseer/parser/extract_nested.lua)

Run a subparser and put the extracted results on the field of an item \

```lua
{"extract_nested", field, child}
{"extract_nested", opts, field, child}
```

**opts**[`object`]: Configuration options \
&nbsp;&nbsp;&nbsp;&nbsp;**append**[`boolean`]: After parsing, append the item to the results list. When false, the pending item will stick around. (default `true`) \
&nbsp;&nbsp;&nbsp;&nbsp;**fail_on_empty**[`boolean`]: Return FAILURE if there are no results from the child (default `true`) \
**field**[`string`]: The name of the field to add to the item \
**child**[`parser`]: The child parser node \

### Examples

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


## [invert](../lua/overseer/parser/invert.lua)

A decorator that inverts the child's return value \

```lua
{"invert", child}
```

**child**[`parser`]: The child parser node \

### Examples

An extract node that returns SUCCESS when it fails, and vice-versa

```lua
{"invert",
  {"extract", "^([^%s].+):(%d+): (.+)$", "filename", "lnum", "text" }
}
```


## [loop](../lua/overseer/parser/loop.lua)

A decorator that repeats the child \

```lua
{"loop", child}
{"loop", opts, child}
```

**opts**[`object`]: Configuration options \
&nbsp;&nbsp;&nbsp;&nbsp;**ignore_failure**[`boolean`]: Keep looping even when the child fails (default `false`) \
&nbsp;&nbsp;&nbsp;&nbsp;**repetitions**[`integer`]: When set, loop a set number of times then return SUCCESS \
**child**[`parser`]: The child parser node \

## [parallel](../lua/overseer/parser/parallel.lua)

Run the child nodes in parallel \

```lua
{"parallel", child...}
{"parallel", opts, child...}
```

**opts**[`object`]: Configuration options \
&nbsp;&nbsp;&nbsp;&nbsp;**break_on_first_failure**[`boolean`]: Stop executing as soon as a child returns FAILURE (default `true`) \
&nbsp;&nbsp;&nbsp;&nbsp;**break_on_first_success**[`boolean`]: Stop executing as soon as a child returns SUCCESS (default `false`) \
&nbsp;&nbsp;&nbsp;&nbsp;**reset_children**[`boolean`]: Reset all children at the beginning of each iteration (default `false`) \
**child**[`parser`]: The child parser nodes. Can be passed in as varargs or as a list. \

## [sequence](../lua/overseer/parser/sequence.lua)

Run the child nodes sequentially \

```lua
{"sequence", child...}
{"sequence", opts, child...}
```

**opts**[`object`]: Configuration options \
&nbsp;&nbsp;&nbsp;&nbsp;**break_on_first_failure**[`boolean`]: Stop executing as soon as a child returns FAILURE (default `true`) \
&nbsp;&nbsp;&nbsp;&nbsp;**break_on_first_success**[`boolean`]: Stop executing as soon as a child returns SUCCESS (default `false`) \
**child**[`parser`]: The child parser nodes. Can be passed in as varargs or as a list. \

### Examples

Extract the message text from one line, then the filename and lnum from the next line

```lua
{"sequence",
  {"extract", { append = false }, { "^(.+)%(.*%)$", "^created by (.+)$" }, "text"},
  {"extract", "^%s+([^:]+.go):([0-9]+)", "filename", "lnum"}
}
```


## [set_defaults](../lua/overseer/parser/set_defaults.lua)

A decorator that adds values to any items extracted by the child \

```lua
{"set_defaults", child}
{"set_defaults", opts, child}
```

**opts**[`object`]: Configuration options \
&nbsp;&nbsp;&nbsp;&nbsp;**values**[`object`]: Hardcoded key-value pairs to set as default values \
&nbsp;&nbsp;&nbsp;&nbsp;**hoist_item**[`boolean`]: Take the current pending item, and use its fields as the default key-value pairs (default `true`) \
**child**[`parser`]: The child parser node \

### Examples

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


## [skip_lines](../lua/overseer/parser/skip_lines.lua)

Skip over a set number of lines \

```lua
{"skip_lines", count}
```

**count**[`integer`]: How many lines to skip \

## [skip_until](../lua/overseer/parser/skip_until.lua)

Skip over lines until one matches \

```lua
{"skip_until", pattern...}
{"skip_until", opts, pattern...}
```

**opts**[`object`]: Configuration options \
&nbsp;&nbsp;&nbsp;&nbsp;**skip_matching_line**[`boolean`]: Consumes the line that matches. Later nodes will only see the next line. (default `true`) \
**pattern**[`string`]: The lua pattern to use for matching. The node succeeds if any of these patterns match. \

### Examples

Skip input until we see "Error" or "Warning"

```lua
{"skip_until", "^Error:", "^Warning:"}
```


## [test](../lua/overseer/parser/test.lua)

Returns SUCCESS when the line matches the pattern \

```lua
{"test", pattern}
{"test", opts, pattern}
```

**opts**[`object`]: Configuration options \
&nbsp;&nbsp;&nbsp;&nbsp;**regex**[`boolean`]: Use vim regex instead of lua pattern (see :help pattern) (default `true`) \
**pattern**[`string`]: The lua pattern to use for matching \

### Examples

Fail until a line starts with "panic:"

```lua
{"test", "^panic:"}
```
