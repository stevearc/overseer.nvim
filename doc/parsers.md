# Parsers

<!-- TOC -->

- [Errorformat](#errorformat)
- [Function](#function)
- [Parser](#parser)
- [make_lua_match_fn(pattern)](#make_lua_match_fnpattern)
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

Note that this is only useful if you don't want the result to be put in the quickfix. If you plan to put them in the quickfix, you should just use the [on_output_quickfix](components.md#on_output_quickfix) component.

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
      lnum = lnum,
      text = msg
    }
  end
end }
```

## Parser

The most complex type of custom parser you can create with the most control is the `overseer.OutputParser` class. If a simple function can't handle your use case, this should be able to.

```lua
local parser = {
  ---Parse a single line of output
  ---@param line string
  parse = function(self, line)
    -- parse one line of output and store the result
  end,
  ---Get the results for the task
  ---@return table<string, any>
  get_result = function(self)
    -- The other methods automatically set the 'diagnostics' key, but this value is merged in to the
    -- task result directly, so you will usually want to set 'diagnostics' here.
    return { diagnostics = {} }
  end,
  ---This is called when the task is reset
  reset = function(self)
    -- clear state
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

## make_regex_match_fn(pattern)

`make_regex_match_fn(pattern): overseer.MatchFn` \
Create a match function from a vim regex

| Param   | Type     | Desc                                  |
| ------- | -------- | ------------------------------------- |
| pattern | `string` | vim regex, passed to vim.fn.matchlist |

## match_to_test_fn(match)

`match_to_test_fn(match): overseer.TestFn` \
Create a test function (returns true/false) from a match function

| Param | Type               | Desc |
| ----- | ------------------ | ---- |
| match | `overseer.MatchFn` |      |

## make_parse_fn(match, fields)

`make_parse_fn(match, fields): overseer.ParseFn` \
Create a function that parses a line into a quickfix entry

| Param  | Type                    | Desc                                                        |
| ------ | ----------------------- | ----------------------------------------------------------- |
| match  | `overseer.MatchFn`      |                                                             |
| fields | `overseer.ParseField[]` | list of field names, or {field_name, postprocess_fn} tuples |

## parser_from_errorformat(errorformat)

`parser_from_errorformat(errorformat): overseer.OutputParser` \
Create a parser from a vim errorformat

| Param       | Type     | Desc |
| ----------- | -------- | ---- |
| errorformat | `string` |      |

## make_parser(parse_fn, results_key)

`make_parser(parse_fn, results_key): overseer.OutputParser` \
Create a parser from a parse function

| Param       | Type               | Desc                                                                   |
| ----------- | ------------------ | ---------------------------------------------------------------------- |
| parse_fn    | `overseer.ParseFn` |                                                                        |
| results_key | `nil\|string`      | The key to put matches in the results table. defaults to "diagnostics" |

## combine_parsers(parsers)

`combine_parsers(parsers): overseer.OutputParser` \
Combine multiple parsers into a single one (will merge the results)

| Param   | Type                      | Desc |
| ------- | ------------------------- | ---- |
| parsers | `overseer.OutputParser[]` |      |

## wrap_background_parser(parser, opts)

`wrap_background_parser(parser, opts): overseer.OutputParser` \
Wrap a parser and only activate it in between a matching start and end lines

| Param           | Type                                                                                | Desc                                                                                                                                         |
| --------------- | ----------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| parser          | `overseer.OutputParser`                                                             |                                                                                                                                              |
| >parse          | `fun(self: overseer.OutputParser, line: string)`                                    |                                                                                                                                              |
| >get_result     | `fun(self: overseer.OutputParser): table<string, any>`                              |                                                                                                                                              |
| >reset          | `fun(self: overseer.OutputParser)`                                                  |                                                                                                                                              |
| >result_version | `nil\|number`                                                                       | For background parsers only, this number should be bumped to indicate that the task should set the result while the process is still running |
| opts            | `{active_on_start?: boolean, start_fn?: overseer.TestFn, end_fn?: overseer.TestFn}` |                                                                                                                                              |


<!-- /parselib.API -->

## Problem matchers

Since Overseer supports VS Code's task format, it also has support for parsing output using a [VS Code problem matcher](https://code.visualstudio.com/Docs/editor/tasks#_defining-a-problem-matcher). You can pass these in to the same [on_output_parse](components.md#on_output_parse) component.

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

Note that the structure of the problem matcher is the same as the VS Code definition, with the exception that it supports a `vim_regexp` key and/or a `lua_pat` key. Because JS regexes are slightly different from vim regexes (e.g. vim regex uses `%()` for non-capturing groups instead of `(?:)`), sometimes the regex from the VS Code definition will not work. The fix for this is to rewrite it as a vim-compatible regex or as a lua pattern. When either of these two keys are present, overseer will use them to perform the matching. If not, it will attempt to convert the `regexp` into a vim-compatible regex and use that, which might work some of the time.

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
