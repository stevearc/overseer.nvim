local parser = require("overseer.parser")
local STATUS = parser.STATUS

describe("skip_until", function()
  it("skips lines that do not match", function()
    local node = parser.skip_until({ skip_matching_line = false }, "apple")
    assert.equals(STATUS.RUNNING, node:ingest("foo"))
    assert.equals(STATUS.RUNNING, node:ingest("bar"))
    assert.equals(STATUS.SUCCESS, node:ingest("pineapple"))
  end)

  it("can match multiple patterns", function()
    local node = parser.skip_until({ skip_matching_line = false }, "foo", "bar")
    assert.equals(STATUS.RUNNING, node:ingest("baz"))
    assert.equals(STATUS.SUCCESS, node:ingest("foo"))
    assert.equals(STATUS.SUCCESS, node:ingest("bar"))
  end)

  it("skips the matching line by default", function()
    local node = parser.skip_until("apple")
    assert.equals(STATUS.RUNNING, node:ingest("foo"))
    assert.equals(STATUS.RUNNING, node:ingest("bar"))
    assert.equals(STATUS.RUNNING, node:ingest("pineapple"))
    assert.equals(STATUS.SUCCESS, node:ingest(""))
  end)
end)

describe("skip_lines", function()
  it("skips lines until count is met", function()
    local node = parser.skip_lines(2)
    assert.equals(STATUS.RUNNING, node:ingest("foo"))
    assert.equals(STATUS.RUNNING, node:ingest("bar"))
    assert.equals(STATUS.SUCCESS, node:ingest("pineapple"))
    assert.equals(STATUS.SUCCESS, node:ingest(""))
  end)

  it("resets", function()
    local node = parser.skip_lines(2)
    assert.equals(STATUS.RUNNING, node:ingest("foo"))
    assert.equals(STATUS.RUNNING, node:ingest("bar"))
    assert.equals(STATUS.SUCCESS, node:ingest("pineapple"))
    node:reset()
    assert.equals(STATUS.RUNNING, node:ingest("pineapple"))
  end)
end)

describe("extract", function()
  it("extracts nothing when no match", function()
    local node = parser.extract("hello (.+)", "name")
    local ctx = { item = {} }
    assert.equals(STATUS.FAILURE, node:ingest("foo", ctx))
    assert.is_true(vim.tbl_isempty(ctx.item))
  end)

  it("extracts fields when they match", function()
    local node = parser.extract("(.+) (.+)", "action", "name")
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.RUNNING, node:ingest("hello world", ctx))
    assert.is_true(vim.tbl_isempty(ctx.item))
    assert.are.same({ { action = "hello", name = "world" } }, ctx.results)
    assert.equals(STATUS.SUCCESS, node:ingest("next", ctx))
  end)

  it("can extract via vim regex", function()
    local node = parser.extract({ regex = true }, "\\v(\\d+):(a|b)$", "lnum", "char")
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.RUNNING, node:ingest("123:b", ctx))
    assert.is_true(vim.tbl_isempty(ctx.item))
    assert.are.same({ { lnum = 123, char = "b" } }, ctx.results)
    assert.equals(STATUS.SUCCESS, node:ingest("next", ctx))
  end)

  it("converts extracted integers by default", function()
    local node = parser.extract("(.+):(%d+)", "file", "lnum")
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.RUNNING, node:ingest("/tmp:123", ctx))
    assert.is_true(vim.tbl_isempty(ctx.item))
    assert.are.same({ { file = "/tmp", lnum = 123 } }, ctx.results)
  end)

  it("returns success if consume = false", function()
    local node = parser.extract({ consume = false }, "(.+) (.+)", "action", "name")
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.SUCCESS, node:ingest("hello world", ctx))
  end)

  it("modifies item in-place if append = false", function()
    local node = parser.extract({ append = false }, "(.+) (.+)", "action", "name")
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.RUNNING, node:ingest("hello world", ctx))
    assert.are.same({ action = "hello", name = "world" }, ctx.item)
  end)

  it("can use a list of strings match", function()
    local node = parser.extract({ consume = false, append = false }, {
      "^(a.+)$",
      "^(z.+)$",
    }, "word")
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.FAILURE, node:ingest("something", ctx))
    node:reset()
    assert.equals(STATUS.SUCCESS, node:ingest("apple", ctx))
    assert.equals("apple", ctx.item.word)
    node:reset()
    assert.equals(STATUS.SUCCESS, node:ingest("zero", ctx))
    assert.equals("zero", ctx.item.word)
  end)

  it("can use a function match", function()
    local node = parser.extract({ append = false }, function()
      return "greetings", "Paul"
    end, "action", "name")
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.RUNNING, node:ingest("hello world", ctx))
    assert.are.same({ action = "greetings", name = "Paul" }, ctx.item)
  end)

  it("can use a list of functions match", function()
    local node = parser.extract({ consume = false, append = false }, {
      function(line)
        if line:match("^a") then
          return "alpha"
        end
      end,
      function(line)
        if line:match("^z") then
          return "zeta"
        end
      end,
    }, "type")
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.FAILURE, node:ingest("something", ctx))
    node:reset()
    assert.equals(STATUS.SUCCESS, node:ingest("apple", ctx))
    assert.equals("alpha", ctx.item.type)
    node:reset()
    assert.equals(STATUS.SUCCESS, node:ingest("zero", ctx))
    assert.equals("zeta", ctx.item.type)
  end)

  it("can postprocess item", function()
    local node = parser.extract({
      postprocess = function(item)
        item.extra = true
      end,
    }, "(.+) (.+)", "action", "name")
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.RUNNING, node:ingest("hello world", ctx))
    assert.are.same({ { action = "hello", name = "world", extra = true } }, ctx.results)
  end)

  it("can use a function to append", function()
    local node = parser.extract({
      append = function(results, item)
        results.single = item
      end,
    }, "(.+) (.+)", "action", "name")
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.RUNNING, node:ingest("hello world", ctx))
    assert.is_true(vim.tbl_isempty(ctx.item))
    assert.are.same({ action = "hello", name = "world" }, ctx.results.single)
  end)
end)

describe("extract_multiline", function()
  it("extracts lines into a single field until no match", function()
    local node = parser.extract_multiline("^.+$", "text")
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.RUNNING, node:ingest("hello", ctx))
    assert.equals(STATUS.RUNNING, node:ingest("world", ctx))
    assert.equals(STATUS.SUCCESS, node:ingest("", ctx))
    assert.are.same({ { text = "hello\nworld" } }, ctx.results)
  end)

  it("returns FAILURE when no lines match", function()
    local node = parser.extract_multiline("^.+$", "text")
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.FAILURE, node:ingest("", ctx))
  end)

  it("modifies item in-place if append = false", function()
    local node = parser.extract_multiline({ append = false }, "^.+$", "text")
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.RUNNING, node:ingest("hello", ctx))
    assert.equals(STATUS.RUNNING, node:ingest("world", ctx))
    assert.equals(STATUS.SUCCESS, node:ingest("", ctx))
    assert.are.same({ text = "hello\nworld" }, ctx.item)
    assert.are.same({}, ctx.results)
  end)
end)

describe("extract_nested", function()
  it("extracts children into a nested key", function()
    local node = parser.extract_nested(
      "child",
      parser.sequence(parser.extract("(%a+)", "word"), parser.extract("(%d+)", "num"))
    )
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.RUNNING, node:ingest("hello 123", ctx))
    assert.equals(STATUS.RUNNING, node:ingest("world 456", ctx))
    assert.equals(STATUS.SUCCESS, node:ingest("", ctx))
    assert.are.same({ { child = { { word = "hello" }, { num = 456 } } } }, ctx.results)
  end)

  it("returns FAILURE when no children match", function()
    local node = parser.extract_nested("child", parser.extract("(%d+)", "num"))
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.FAILURE, node:ingest("hello", ctx))
  end)

  it("can return SUCCESS even when no children match", function()
    local node =
      parser.extract_nested({ fail_on_empty = false }, "child", parser.extract("(%d+)", "num"))
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.SUCCESS, node:ingest("hello", ctx))
    assert.are.same({ { child = {} } }, ctx.results)
  end)

  it("modifies item in-place if append = false", function()
    local node = parser.extract_nested({ append = false }, "child", parser.extract("(%d+)", "num"))
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.RUNNING, node:ingest("123", ctx))
    assert.equals(STATUS.SUCCESS, node:ingest("", ctx))
    assert.are.same({}, ctx.results)
    assert.are.same({ child = { { num = 123 } } }, ctx.item)
  end)
end)

describe("extract_json", function()
  it("extracts json values", function()
    local node = parser.extract_json()
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.RUNNING, node:ingest('{"msg": "hello"}', ctx))
    assert.are.same({ { msg = "hello" } }, ctx.results)
    assert.equals(STATUS.SUCCESS, node:ingest("next", ctx))
  end)

  it("modifies item in-place if append = false", function()
    local node = parser.extract_json({ append = false })
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.RUNNING, node:ingest('{"msg": "hello"}', ctx))
    assert.are.same({ msg = "hello" }, ctx.item)
  end)

  it("can use a function to append", function()
    local node = parser.extract_json({
      append = function(results, item)
        results.single = item
      end,
    })
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.RUNNING, node:ingest('{"msg": "hello"}', ctx))
    assert.are.same({ single = { msg = "hello" } }, ctx.results)
  end)

  it("can test the values before appending", function()
    local node = parser.extract_json({
      test = function(values)
        return values.action == "pass"
      end,
    })
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.RUNNING, node:ingest('{"action": "pass", "msg": "hello"}', ctx))
    node:reset()
    assert.equals(STATUS.FAILURE, node:ingest('{"action": "fail", "msg": "bye"}', ctx))
    assert.are.same({ { action = "pass", msg = "hello" } }, ctx.results)
  end)

  it("can postprocess item", function()
    local node = parser.extract_json({
      postprocess = function(item)
        item.extra = true
      end,
    })
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.RUNNING, node:ingest('{"msg": "hello"}', ctx))
    assert.are.same({ { msg = "hello", extra = true } }, ctx.results)
  end)
end)

describe("test", function()
  it("returns FAILURE when no match", function()
    local node = parser.test("hello (.+)")
    assert.equals(STATUS.FAILURE, node:ingest("foo"))
  end)

  it("returns SUCCESS when it matches", function()
    local node = parser.test("(.+) (.+)")
    assert.equals(STATUS.SUCCESS, node:ingest("hello world"))
  end)

  it("can use a list of strings match", function()
    local node = parser.test({
      "^(a.+)$",
      "^(z.+)$",
    })
    assert.equals(STATUS.FAILURE, node:ingest("something"))
    node:reset()
    assert.equals(STATUS.SUCCESS, node:ingest("apple"))
    node:reset()
    assert.equals(STATUS.SUCCESS, node:ingest("zero"))
  end)

  it("can use a function match", function()
    local node = parser.test(function()
      return true
    end)
    assert.equals(STATUS.SUCCESS, node:ingest("hello world"))
  end)

  it("can use a list of functions match", function()
    local node = parser.test({
      function(line)
        return line:match("^a")
      end,
      function(line)
        return line:match("^z")
      end,
    })
    assert.equals(STATUS.FAILURE, node:ingest("something"))
    node:reset()
    assert.equals(STATUS.SUCCESS, node:ingest("apple"))
    node:reset()
    assert.equals(STATUS.SUCCESS, node:ingest("zero"))
  end)
end)

describe("append", function()
  it("appends item to the results", function()
    local node = parser.append()
    local ctx = { item = { foo = "bar" }, results = {} }
    assert.equals(STATUS.SUCCESS, node:ingest("foo", ctx))
    assert.are.same({ { foo = "bar" } }, ctx.results)
    assert.is_true(vim.tbl_isempty(ctx.item))
  end)
end)

describe("set_defaults", function()
  it("sets default values for parsed items", function()
    local node = parser.set_defaults({ values = { foo = "bar" } }, parser.extract("(.+)", "word"))
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.RUNNING, node:ingest("foo", ctx))
    assert.are.same({ { foo = "bar", word = "foo" } }, ctx.results)
  end)

  it("sets hoists current item into default values", function()
    local node = parser.set_defaults(parser.loop(parser.extract("(.+)", "word")))
    local ctx = { item = { foo = "bar" }, results = {} }
    assert.equals(STATUS.RUNNING, node:ingest("foo", ctx))
    assert.equals(STATUS.RUNNING, node:ingest("bar", ctx))
    assert.are.same({ { foo = "bar", word = "foo" }, { foo = "bar", word = "bar" } }, ctx.results)
  end)
end)

describe("loop", function()
  it("can propagate failures", function()
    local node = parser.loop(parser.extract("^a.*", "word"))
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.RUNNING, node:ingest("apple", ctx))
    assert.equals(STATUS.FAILURE, node:ingest("foo", ctx))
  end)

  it("can ignore failures", function()
    local node = parser.loop({ ignore_failure = true }, parser.extract("^a.*", "word"))
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.RUNNING, node:ingest("foo", ctx))
    assert.equals(STATUS.RUNNING, node:ingest("apple", ctx))
    assert.equals(STATUS.RUNNING, node:ingest("foo", ctx))
    assert.equals(STATUS.RUNNING, node:ingest("antlers", ctx))
    assert.are.same({ { word = "apple" }, { word = "antlers" } }, ctx.results)
  end)

  it("can loop a specific number of times", function()
    local node = parser.loop({ repetitions = 2 }, parser.skip_lines(1))
    assert.equals(STATUS.RUNNING, node:ingest("apple"))
    assert.equals(STATUS.RUNNING, node:ingest("foo"))
    assert.equals(STATUS.SUCCESS, node:ingest("bar"))
  end)

  it("can short-circuit if stuck in infinite loop", function()
    local node = parser.loop(parser.test(".*"))
    assert.equals(STATUS.RUNNING, node:ingest("apple"))
  end)
end)

describe("sequence", function()
  it("runs child nodes in succession", function()
    local node = parser.sequence(parser.extract("^(.+) ", "word"), parser.extract(" (.+)$", "word"))
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.RUNNING, node:ingest("hello there", ctx))
    assert.equals(STATUS.RUNNING, node:ingest("seal party", ctx))
    assert.equals(STATUS.SUCCESS, node:ingest("", ctx))
    assert.are.same({ { word = "hello" }, { word = "party" } }, ctx.results)
  end)

  it("stops running on first failure", function()
    local node = parser.sequence(parser.extract("^(.+) ", "word"), parser.extract(" (.+)$", "word"))
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.RUNNING, node:ingest("hello there", ctx))
    assert.equals(STATUS.FAILURE, node:ingest("Kansas", ctx))
    assert.are.same({ { word = "hello" } }, ctx.results)
  end)

  it("has option to ignore failure", function()
    local node = parser.sequence(
      { break_on_first_failure = false },
      parser.extract("^(.+) ", "word"),
      parser.extract(" (.+)$", "word"),
      parser.extract("(.+)$", "word")
    )
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.RUNNING, node:ingest("hello there", ctx))
    assert.equals(STATUS.RUNNING, node:ingest("Kansas", ctx))
    assert.equals(STATUS.FAILURE, node:ingest("", ctx))
    assert.are.same({ { word = "hello" }, { word = "Kansas" } }, ctx.results)
  end)

  it("has option to finish on first success", function()
    local node = parser.sequence(
      { break_on_first_failure = false, break_on_first_success = true },
      parser.extract("^(.+) ", "word"),
      parser.extract("^%d+$", "word"),
      parser.extract("(.+)$", "word")
    )
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.RUNNING, node:ingest("123", ctx))
    assert.equals(STATUS.SUCCESS, node:ingest("Kansas", ctx))
    assert.are.same({ { word = 123 } }, ctx.results)
  end)
end)

describe("parallel", function()
  it("runs children in parallel", function()
    local node = parser.parallel(parser.extract("%a+", "word"), parser.extract("%d+", "num"))
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.RUNNING, node:ingest("hello123", ctx))
    assert.equals(STATUS.SUCCESS, node:ingest("", ctx))
    assert.are.same({ { word = "hello" }, { num = 123 } }, ctx.results)
  end)

  it("stops running on first failure", function()
    local node = parser.parallel(parser.extract("%d+", "num"), parser.extract("%a+", "word"))
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.FAILURE, node:ingest("hello", ctx))
    assert.is_true(vim.tbl_isempty(ctx.results))
  end)

  it("has option to ignore failure", function()
    local node = parser.parallel(
      { break_on_first_failure = false },
      parser.extract("%d+", "num"),
      parser.extract("%a+", "word")
    )
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.RUNNING, node:ingest("hello", ctx))
    assert.equals(STATUS.FAILURE, node:ingest("", ctx))
    assert.are.same({ { word = "hello" } }, ctx.results)
  end)

  it("has option to finish on first success", function()
    local node = parser.parallel(
      { break_on_first_failure = false, break_on_first_success = true },
      parser.extract("%a+", "word"),
      parser.extract("%d+", "num")
    )
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.RUNNING, node:ingest("hello", ctx))
    assert.equals(STATUS.SUCCESS, node:ingest("", ctx))
    assert.are.same({ { word = "hello" } }, ctx.results)
  end)

  it("has option to restart children on each run", function()
    local node = parser.parallel(
      { restart_children = true },
      parser.sequence(parser.extract("%a+", "word"), parser.extract("%d+", "word"))
    )
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.RUNNING, node:ingest("hello123", ctx))
    assert.equals(STATUS.RUNNING, node:ingest("hello123", ctx))
    assert.equals(STATUS.RUNNING, node:ingest("hello123", ctx))
    assert.are.same({ { word = "hello" }, { word = "hello" }, { word = "hello" } }, ctx.results)
  end)
end)

describe("always", function()
  it("turns FAILURE into SUCCESS", function()
    local node = parser.always(parser.test("^a"))
    assert.equals(STATUS.SUCCESS, node:ingest("apple"))
    assert.equals(STATUS.SUCCESS, node:ingest("foobar"))
  end)

  it("propagates RUNNING", function()
    local node = parser.always(parser.extract("^(a.*)", "word"))
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.RUNNING, node:ingest("apple", ctx))
  end)
end)

describe("inline", function()
  it("Returns callback results", function()
    local node = parser.inline(function()
      return STATUS.SUCCESS
    end)
    assert.equals(STATUS.SUCCESS, node:ingest("hello"))
  end)

  it("Calls reset callback", function()
    local count = 0
    local node = parser.inline(function()
      count = count + 1
      return count >= 2 and STATUS.SUCCESS or STATUS.RUNNING
    end, function()
      count = 0
    end)
    assert.equals(STATUS.RUNNING, node:ingest("hello"))
    assert.equals(STATUS.SUCCESS, node:ingest("hello"))
    node:reset()
    assert.equals(STATUS.RUNNING, node:ingest("hello"))
    assert.equals(STATUS.SUCCESS, node:ingest("hello"))
    assert.equals(STATUS.SUCCESS, node:ingest("hello"))
  end)
end)

describe("invert", function()
  it("Turns a failure into a success", function()
    local node = parser.invert(parser.extract({ consume = false }, "apple", "fruit"))
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.SUCCESS, node:ingest("bees", ctx))
  end)

  it("Turns a success into a failure", function()
    local node = parser.invert(parser.extract({ consume = false }, "apple", "fruit"))
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.FAILURE, node:ingest("apple", ctx))
  end)

  it("Passes RUNNING through unchanged", function()
    local node = parser.invert(parser.extract("apple", "fruit"))
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.RUNNING, node:ingest("apple", ctx))
  end)
end)

describe("until", function()
  it("returns RUNNING until child succeeds", function()
    local node = parser.ensure(parser.extract({ consume = false }, "apple", "fruit"))
    local ctx = { item = {}, results = {} }
    assert.equals(STATUS.RUNNING, node:ingest("bees", ctx))
    assert.equals(STATUS.RUNNING, node:ingest("Stanley", ctx))
    assert.equals(STATUS.SUCCESS, node:ingest("apple", ctx))
  end)
end)

describe("parser", function()
  it("parses simple lines into a list", function()
    local p = parser.new({
      parser.extract("^(.+):(%d+)", "filename", "lnum"),
    })
    p:ingest({
      "foo",
      "/file.lua:23",
      "/other.cpp:128",
      "bar",
    })
    local result = p:get_result()
    assert.are.same({
      { filename = "/file.lua", lnum = 23 },
      { filename = "/other.cpp", lnum = 128 },
    }, result)
  end)

  it("creates namespaced results for map-like args", function()
    local p = parser.new({
      lnums = { parser.extract("(%d+)", "lnum") },
      filenames = { parser.extract("([/%a%.]+)", "filename") },
    })
    p:ingest({
      "/file.lua:23",
      "/other.cpp:128",
    })
    local result = p:get_result()
    assert.are.same({
      filenames = { { filename = "/file.lua" }, { filename = "/other.cpp" } },
      lnums = { { lnum = 23 }, { lnum = 128 } },
    }, result)
  end)
end)
