local parselib = require("overseer.parselib")

---@param obj vim.quickfix.entry
---@return vim.quickfix.entry
local function make_qf_item(obj)
  return vim.tbl_extend("keep", obj, {
    bufnr = -1,
    col = 0,
    end_col = 0,
    end_lnum = 0,
    lnum = 0,
    module = "",
    nr = -1,
    pattern = "",
    text = "",
    type = "",
    valid = 1,
    vcol = 0,
  })
end

describe("parselib", function()
  describe("make_match_fn", function()
    it("matches lua patterns", function()
      local match = parselib.make_lua_match_fn("(%w+) (.*)$")
      local ret = match("hello world")
      assert.are.same({ "hello", "world" }, ret)
    end)

    it("lua pattern returns nil if no match", function()
      local match = parselib.make_lua_match_fn("(%w+) (.*)$")
      local ret = match("helloworld")
      assert.is_nil(ret)
    end)

    it("matches vim regex", function()
      local match = parselib.make_regex_match_fn("\\v^(\\S+) (.*)$")
      local ret = match("hello world")
      assert.are.same({ "hello", "world" }, ret)
    end)

    it("vim regex returns nil if no match", function()
      local match = parselib.make_regex_match_fn("\\v^(\\S+) (.*)$")
      local ret = match("helloworld")
      assert.is_nil(ret)
    end)
  end)

  describe("make_parse_fn", function()
    it("returns nil when no match", function()
      local match = parselib.make_lua_match_fn("foo")
      local parse = parselib.make_parse_fn(match, { "text" })
      local ret = parse("hello")
      assert.is_nil(ret)
    end)

    it("returns item when match", function()
      local match = parselib.make_lua_match_fn(".*")
      local parse = parselib.make_parse_fn(match, { "text" })
      local ret = parse("hello")
      assert.are.same({ text = "hello" }, ret)
    end)

    it("automatically converts numbers", function()
      local match = parselib.make_lua_match_fn(".*")
      local parse = parselib.make_parse_fn(match, { "text" })
      local ret = parse("44")
      assert.are.same({ text = 44 }, ret)
    end)

    it("automatically converts quickfix type", function()
      local match = parselib.make_lua_match_fn(".*")
      local parse = parselib.make_parse_fn(match, { "type" })
      local ret = parse("error")
      assert.are.same({ type = "E" }, ret)
    end)

    it("skips fields labeled '_'", function()
      local match = parselib.make_lua_match_fn("(%w+) (%w+) (%w+)")
      local parse = parselib.make_parse_fn(match, { "first", "_", "last" })
      local ret = parse("hello there world")
      assert.are.same({ first = "hello", last = "world" }, ret)
    end)

    it("fields can pass a postprocess function", function()
      local match = parselib.make_lua_match_fn(".*")
      local parse = parselib.make_parse_fn(match, {
        {
          "text",
          function(v)
            return v:upper()
          end,
        },
      })
      local ret = parse("hello")
      assert.are.same({ text = "HELLO" }, ret)
    end)
  end)

  describe("parser_from_errorformat", function()
    it("returns empty results when no match", function()
      local parser = parselib.parser_from_errorformat("%f:%l")
      parser:parse("_____")
      assert.are.same({ diagnostics = {} }, parser:get_result())
    end)

    it("matches lines", function()
      local parser = parselib.parser_from_errorformat("%f:%l")
      parser:parse("foo:22")
      assert.are.same({
        diagnostics = {
          make_qf_item({
            bufnr = vim.fn.bufadd("foo"),
            lnum = 22,
          }),
        },
      }, parser:get_result())
    end)

    it("handles multiline matches", function()
      local parser = parselib.parser_from_errorformat("%A%f:%l,%Z%m")
      parser:parse("foo:10")
      assert.are.same({
        diagnostics = {
          make_qf_item({
            bufnr = vim.fn.bufadd("foo"),
            lnum = 10,
          }),
        },
      }, parser:get_result())
      parser:parse("errmsg")
      assert.are.same({
        diagnostics = {
          make_qf_item({
            bufnr = vim.fn.bufadd("foo"),
            text = "\nerrmsg",
            lnum = 10,
          }),
        },
      }, parser:get_result())

      parser:parse("bar:11")
      assert.are.same({
        diagnostics = {
          make_qf_item({
            bufnr = vim.fn.bufadd("foo"),
            text = "\nerrmsg",
            lnum = 10,
          }),
          make_qf_item({
            bufnr = vim.fn.bufadd("bar"),
            lnum = 11,
          }),
        },
      }, parser:get_result())
    end)
  end)

  describe("make_parser", function()
    it("matches and resets", function()
      local match = parselib.make_lua_match_fn("^(%w+)$")
      local parse = parselib.make_parse_fn(match, { "word" })
      local parser = parselib.make_parser(parse)
      -- non-matching lines
      parser:parse("hello world")
      parser:parse("multiple words")
      assert.are.same({ diagnostics = {} }, parser:get_result())

      -- some lines match
      parser:parse("hello")
      parser:parse("multiple words")
      parser:parse("world")
      assert.are.same(
        { diagnostics = {
          { word = "hello" },
          { word = "world" },
        } },
        parser:get_result()
      )

      -- reset clears results
      parser:reset()
      assert.are.same({ diagnostics = {} }, parser:get_result())
    end)
  end)

  describe("combine_parsers", function()
    it("combines results", function()
      local match1 = parselib.make_lua_match_fn("^(%w+)")
      local parse1 = parselib.make_parse_fn(match1, { "first" })
      local parser1 = parselib.make_parser(parse1)
      local match2 = parselib.make_lua_match_fn("(%w+)$")
      local parse2 = parselib.make_parse_fn(match2, { "last" })
      local parser2 = parselib.make_parser(parse2)
      local parser = parselib.combine_parsers({ parser1, parser2 })

      -- non-matching lines
      parser:parse("^^^&$&$&&$*")
      assert.are.same({ diagnostics = {} }, parser:get_result())

      -- some lines match
      parser:parse("hello there world")
      parser:parse("*nonmatch present")
      parser:parse("present nonmatch*")
      assert.are.same({
        diagnostics = {
          { first = "hello" },
          { first = "present" },
          { last = "world" },
          { last = "present" },
        },
      }, parser:get_result())

      -- reset clears results
      parser:reset()
      assert.are.same({ diagnostics = {} }, parser:get_result())
    end)
  end)

  describe("wrap_background_parser", function()
    it("parses lines between start/end patterns", function()
      local test_start = parselib.match_to_test_fn(parselib.make_lua_match_fn("^start$"))
      local test_end = parselib.match_to_test_fn(parselib.make_lua_match_fn("^end$"))
      local match = parselib.make_lua_match_fn("^(%w+)$")
      local parse = parselib.make_parse_fn(match, { "word" })
      local parser = parselib.make_parser(parse)

      local bg =
        parselib.wrap_background_parser(parser, { start_fn = test_start, end_fn = test_end })

      -- not parsing yet
      bg:parse("foo")
      assert.are.same({ diagnostics = {} }, bg:get_result())
      assert.equal(0, bg.result_version)

      -- parse some values
      bg:parse("start")
      bg:parse("foo")
      bg:parse("bar")
      assert.are.same({ diagnostics = { { word = "foo" }, { word = "bar" } } }, bg:get_result())
      assert.equal(0, bg.result_version)

      -- end will stop parsing
      bg:parse("end")
      bg:parse("foo")
      assert.are.same({ diagnostics = { { word = "foo" }, { word = "bar" } } }, bg:get_result())
      assert.equal(1, bg.result_version)

      -- start pattern will reset
      bg:parse("start")
      assert.are.same({ diagnostics = {} }, bg:get_result())
      assert.equal(2, bg.result_version)

      -- will resume parsing again
      bg:parse("foo")
      assert.are.same({ diagnostics = { { word = "foo" } } }, bg:get_result())
      assert.equal(2, bg.result_version)

      -- resets
      bg:reset()
      assert.are.same({ diagnostics = {} }, bg:get_result())
      assert.equal(0, bg.result_version)

      -- not parsing yet after reset
      bg:parse("foo")
      assert.are.same({ diagnostics = {} }, bg:get_result())
      assert.equal(0, bg.result_version)
    end)

    it("can set active_on_start", function()
      local test_start = parselib.match_to_test_fn(parselib.make_lua_match_fn("^start$"))
      local test_end = parselib.match_to_test_fn(parselib.make_lua_match_fn("^end$"))
      local match = parselib.make_lua_match_fn("^(%w+)$")
      local parse = parselib.make_parse_fn(match, { "word" })
      local parser = parselib.make_parser(parse)

      local bg = parselib.wrap_background_parser(
        parser,
        { start_fn = test_start, end_fn = test_end, active_on_start = true }
      )

      -- starts parsing immediately
      bg:parse("foo")
      bg:parse("bar")
      assert.are.same({ diagnostics = { { word = "foo" }, { word = "bar" } } }, bg:get_result())
      assert.equal(0, bg.result_version)

      -- end will stop parsing
      bg:parse("end")
      bg:parse("foo")
      assert.are.same({ diagnostics = { { word = "foo" }, { word = "bar" } } }, bg:get_result())
      assert.equal(1, bg.result_version)
    end)

    it("functions with no end_fn", function()
      local test_start = parselib.match_to_test_fn(parselib.make_lua_match_fn("^start$"))
      local match = parselib.make_lua_match_fn("^(%w+)$")
      local parse = parselib.make_parse_fn(match, { "word" })
      local parser = parselib.make_parser(parse)

      local bg = parselib.wrap_background_parser(parser, { start_fn = test_start })

      -- not parsing yet
      bg:parse("foo")
      assert.are.same({ diagnostics = {} }, bg:get_result())
      assert.equal(0, bg.result_version)

      -- parse some values
      bg:parse("start")
      bg:parse("foo")
      bg:parse("bar")
      assert.are.same({ diagnostics = { { word = "foo" }, { word = "bar" } } }, bg:get_result())
      assert.equal(0, bg.result_version)

      -- resets
      bg:reset()
      assert.are.same({ diagnostics = {} }, bg:get_result())
      assert.equal(0, bg.result_version)
    end)

    it("functions with no start_fn", function()
      local test_end = parselib.match_to_test_fn(parselib.make_lua_match_fn("^end$"))
      local match = parselib.make_lua_match_fn("^(%w+)$")
      local parse = parselib.make_parse_fn(match, { "word" })
      local parser = parselib.make_parser(parse)

      local bg =
        parselib.wrap_background_parser(parser, { end_fn = test_end, active_on_start = true })

      -- parse some values
      bg:parse("foo")
      bg:parse("bar")
      assert.are.same({ diagnostics = { { word = "foo" }, { word = "bar" } } }, bg:get_result())
      assert.equal(0, bg.result_version)

      -- end will stop parsing
      bg:parse("end")
      bg:parse("foo")
      assert.are.same({ diagnostics = { { word = "foo" }, { word = "bar" } } }, bg:get_result())
      assert.equal(1, bg.result_version)

      -- resets
      bg:reset()
      assert.are.same({ diagnostics = {} }, bg:get_result())
      assert.equal(0, bg.result_version)

      -- parses again after reset
      bg:parse("foo")
      assert.are.same({ diagnostics = { { word = "foo" } } }, bg:get_result())
      assert.equal(0, bg.result_version)
    end)
  end)
end)
