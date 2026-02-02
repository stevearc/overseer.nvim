# Parsers

<!-- TOC -->

- [Errorformat](#errorformat)
- [Function](#function)
- [Parser](#parser)
- [make_lua_match_fn(pattern)](#make_lua_match_fnpattern)
- [make_lua_test_fn(pattern)](#make_lua_test_fnpattern)
- [make_regex_match_fn(pattern)](#make_regex_match_fnpattern)
- [match_to_test_fn(match)](#match_to_test_fnmatch)
- [make_parse_fn(match, fields)](#make_parse_fnmatch-fields)
- [parser_from_errorformat(errorformat)](#parser_from_errorformaterrorformat)
- [make_parser(parse_fn, results_key)](#make_parserparse_fn-results_key)
- [combine_parsers(parsers)](#combine_parsersparsers)
- [wrap_background_parser(parser, opts)](#wrap_background_parserparser-opts)
- [Problem matchers](#problem-matchers)
- [Built-in problem matchers](#built-in-problem-matchers)

<!-- /TOC -->

## Errorformat

Vim has its own custom format for defining how to parse diagnostics from output. See `:help errorformat` for very thorough and complete documentation. A simple example is below:

```lua
-- Match lines that look like
-- foo/bar/baz.c:28: this is an error
{ "on_output_parse", errorformat = "%f:%l: %m" }
```

Note that this is only useful if you don't want the result to be put in the quickfix. If you plan to put them in the quickfix, you should just use the [on_output_quickfix](components.md#on_output_quickfix) component. Pasting errors from your tasks into an AI chatbot like Gemini or ChatGPT might be the quickest way to create an errorformat that matches your errors, especially if you have multiline errors.

## Function

For simple single-line formats, you can pass in a function to do the parsing.

```lua
{ "on_output_parse", parser = function(line)
  local fname, lnum, msg = line:match("^(.*):(%d+): (.*)$")
  -- Return a table in the format of :help setqflist-what
  -- or return nil if no match
  if fname then
    return {
      filename = fname,
      lnum = tonumber(lnum),
      text = msg
    }
  end
end }
```

## Parser

The most complex type of custom parser you can create with the most control is the `overseer.OutputParser` class. If a simple function can't handle your use case, this should be able to.

```lua
local parser = {
  _result = {},
  ---Parse a single line of output
  ---@param line string
  parse = function(self, line)
    local fname, lnum, msg = line:match("^(.*):(%d+): (.*)$")
    if fname
      table.insert(self._result, {
        filename = fname,
        lnum = tonumber(lnum),
        text = msg
      })
    end
  end,
  ---Get the results for the task
  ---@return table<string, any>
  get_result = function(self)
    -- The task result is an arbitrary key-value table, but most of the time for output parsing
    -- you will want to set the `diagnostics` key. This is the special key that interacts with
    -- all of the diagnostics-related components.
    -- Note that the other parser types (function, problem matcher, errorformat) automatically put
    -- their results in the `diagnostics` key.
    return { diagnostics = self._result }
  end,
  ---This is called when the task is reset
  reset = function(self)
    self._result = {}
  end,
}
```

If you want to build and use custom parsers, there are some helpful methods available in [overseer.parselib](../lua/overseer/parselib.lua).

<!-- parselib.API -->

## make_lua_match_fn(pattern)

`make_lua_match_fn(pattern): overseer.MatchFn` \
Create a match function from a lua pattern

| Param   | Type     | Desc        |
| ------- | -------- | ----------- |
| pattern | `string` | lua pattern |

**Examples:**
```lua
local match_fn = parselib.make_lua_match_fn("^(%S+):(%d+):(%d+): (.+)$")
local parse_fn = parselib.make_parse_fn(match_fn, {"filename", "lnum", "col", "text"})
local parser = parselib.make_parser(parse_fn)
```

## make_lua_test_fn(pattern)

`make_lua_test_fn(pattern): overseer.TestFn` \
Create a test function (returns true/false) from a lua pattern

| Param   | Type     | Desc        |
| ------- | -------- | ----------- |
| pattern | `string` | lua pattern |

**Examples:**
```lua
local test_fn = parselib.make_lua_test_fn("^File change detected")
```

## make_regex_match_fn(pattern)

`make_regex_match_fn(pattern): overseer.MatchFn` \
Create a match function from a vim regex

| Param   | Type     | Desc                                  |
| ------- | -------- | ------------------------------------- |
| pattern | `string` | vim regex, passed to vim.fn.matchlist |

**Examples:**
```lua
local match_fn = parselib.make_regex_match_fn("\\v^(\\S+):(\\d+):(\\d+): (.+)$")
local parse_fn = parselib.make_parse_fn(match_fn, {"filename", "lnum", "col", "text"})
local parser = parselib.make_parser(parse_fn)
```

## match_to_test_fn(match)

`match_to_test_fn(match): overseer.TestFn` \
Create a test function (returns true/false) from a match function

| Param | Type               | Desc                                              |
| ----- | ------------------ | ------------------------------------------------- |
| match | `overseer.MatchFn` | function that parses a line into a list of values |

**Examples:**
```lua
local match_fn = parselib.make_lua_match_fn("^(%S+):(%d+):(%d+): (.+)$")
local test_fn = parselib.match_to_test_fn(match_fn)
```

## make_parse_fn(match, fields)

`make_parse_fn(match, fields): overseer.ParseFn` \
Create a function that parses a line into a quickfix entry

| Param  | Type                    | Desc                                                        |
| ------ | ----------------------- | ----------------------------------------------------------- |
| match  | `overseer.MatchFn`      | function that parses a line into a list of values           |
| fields | `overseer.ParseField[]` | list of field names, or {field_name, postprocess_fn} tuples |

**Examples:**
```lua
local match_fn = parselib.make_lua_match_fn("^(%S+):(%d+):(%d+): (.+)$")
local parse_fn = parselib.make_parse_fn(match_fn, {"filename", "lnum", "col", "text"})
local parser = parselib.make_parser(parse_fn)
```

## parser_from_errorformat(errorformat)

`parser_from_errorformat(errorformat): overseer.OutputParser` \
Create a parser from a vim errorformat

| Param       | Type     | Desc                   |
| ----------- | -------- | ---------------------- |
| errorformat | `string` | vim errorformat string |

**Examples:**
```lua
local parser = parselib.parser_from_errorformat("%f:%l: %m")
```

## make_parser(parse_fn, results_key)

`make_parser(parse_fn, results_key): overseer.OutputParser` \
Create a parser from a parse function

| Param       | Type               | Desc                                                                   |
| ----------- | ------------------ | ---------------------------------------------------------------------- |
| parse_fn    | `overseer.ParseFn` | function that parses a line into a quickfix entry                      |
| results_key | `nil\|string`      | The key to put matches in the results table. defaults to "diagnostics" |

**Examples:**
```lua
local match_fn = parselib.make_lua_match_fn("^(%S+):(%d+):(%d+): (.+)$")
local parse_fn = parselib.make_parse_fn(match_fn, {"filename", "lnum", "col", "text"})
local parser = parselib.make_parser(parse_fn)
```

## combine_parsers(parsers)

`combine_parsers(parsers): overseer.OutputParser` \
Combine multiple parsers into a single one (will merge the results)

| Param   | Type                      | Desc |
| ------- | ------------------------- | ---- |
| parsers | `overseer.OutputParser[]` |      |

**Examples:**
```lua
local match_fn = parselib.make_lua_match_fn("^(%S+):(%d+):(%d+): (.+)$")
local parse_fn = parselib.make_parse_fn(match_fn, {"filename", "lnum", "col", "text"})
local parser1 = parselib.make_parser(parse_fn)
local parser2 = parselib.parser_from_errorformat("%f:%l: %m")
local combined_parser = parselib.combine_parsers({parser1, parser2})
```

## wrap_background_parser(parser, opts)

`wrap_background_parser(parser, opts): overseer.OutputParser` \
Wrap a parser and only activate it in between a matching start and end lines

| Param            | Type                                                   | Desc                                                                                                                                         |
| ---------------- | ------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------- |
| parser           | `overseer.OutputParser`                                |                                                                                                                                              |
| >parse           | `fun(self: overseer.OutputParser, line: string)`       | Called repeatedly with each line of output                                                                                                   |
| >get_result      | `fun(self: overseer.OutputParser): table<string, any>` | Mapping of result keys to parsed values. Usually contains a "diagnostics" key with a list of quickfix entries.                               |
| >reset           | `fun(self: overseer.OutputParser)`                     | Reset the parser to its initial state                                                                                                        |
| >result_version  | `nil\|number`                                          | For background parsers only, this number should be bumped to indicate that the task should set the result while the process is still running |
| opts             | `overseer.BackgroundParserOpts`                        |                                                                                                                                              |
| >active_on_start | `nil\|boolean`                                         | Whether the parser should be active immediately or wait for the start_fn to begin parsing                                                    |
| >start_fn        | `nil\|overseer.TestFn`                                 | Function that tests whether to start parsing                                                                                                 |
| >end_fn          | `nil\|overseer.TestFn`                                 | Function that tests whether to stop parsing                                                                                                  |

**Examples:**
```lua
local base_parser = parselib.parser_from_errorformat("%f:%l: %m")
local parser = parselib.wrap_background_parser(base_parser, {
  start_fn = parselib.make_lua_test_fn("^Starting analysis...$"),
  end_fn = parselib.make_lua_test_fn("^Analysis complete.$"),
})
```


<!-- /parselib.API -->

## Problem matchers

Since Overseer supports VS Code's task format, it also has support for parsing output using a [VS Code problem matcher](https://code.visualstudio.com/Docs/editor/tasks#_defining-a-problem-matcher). You can pass these in to the same [on_output_parse](components.md#on_output_parse) component.

```lua
{"on_output_parse", problem_matcher = {
  owner = 'typescript',
  fileLocation = { "relative", "${cwd}" },
  pattern = {
    regexp = "^([^\\s].*)[\\(:](\\d+)[,:](\\d+)(?:\\):\\s+|\\s+-\\s+)(error|warning|info)\\s+TS(\\d+)\\s*:\\s*(.*)$",
    -- It is recommended to specify either vim_regexp or lua_pat because vim doesn't fully support javascript regex format
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

Note that the structure of the problem matcher is the same as the VS Code definition, with the exception that it supports a `vim_regexp` key and/or a `lua_pat` key. Because JS regexes are slightly different from vim regexes (e.g. vim regex uses `%()` for non-capturing groups instead of `(?:)`), sometimes the regex from the VS Code definition will not work. The fix for this is to rewrite it as a vim-compatible regex or as a lua pattern. When either of these two keys are present, overseer will use them to perform the matching. If not, it will attempt to convert the `regexp` into a vim-compatible regex and use that, which might work some of the time.

For convenience, you can also use the built-in problem matcher definitions in `on_output_parse`:

```lua
{"on_output_parse", problem_matcher = "$tsc-watch"}
```

## Built-in problem matchers

Problem matchers:

<!-- problem_matchers -->

- `$eslint-compact`
- `$eslint-stylish`
- `$gcc`
- `$go`
- `$gulp-tsc`
- `$jshint`
- `$jshint-stylish`
- `$lessCompile`
- `$lessc`
- `$msCompile`
- `$node-sass`
- `$nvcc`
- `$tsc`
- `$tsc-watch`
<!-- /problem_matchers -->

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
