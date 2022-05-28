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
    local item = {}
    assert.equals(STATUS.FAILURE, node:ingest("foo", item))
    assert.is_true(vim.tbl_isempty(item))
  end)

  it("extracts fields when they match", function()
    local node = parser.extract("(.+) (.+)", "action", "name")
    local item = {}
    local results = {}
    assert.equals(STATUS.RUNNING, node:ingest("hello world", item, results))
    assert.is_true(vim.tbl_isempty(item))
    assert.equals(1, vim.tbl_count(results))
    assert.equals("hello", results[1].action)
    assert.equals("world", results[1].name)
    assert.equals(STATUS.SUCCESS, node:ingest("next", item, results))
  end)

  it("can extract via vim regex", function()
    local node = parser.extract({ regex = true }, "\\v(\\d+):(a|b)$", "lnum", "char")
    local item = {}
    local results = {}
    assert.equals(STATUS.RUNNING, node:ingest("123:b", item, results))
    assert.is_true(vim.tbl_isempty(item))
    assert.are.same({ { lnum = 123, char = "b" } }, results)
    assert.equals(STATUS.SUCCESS, node:ingest("next", item, results))
  end)

  it("converts extracted integers by default", function()
    local node = parser.extract("(.+):(%d+)", "file", "lnum")
    local item = {}
    local results = {}
    assert.equals(STATUS.RUNNING, node:ingest("/tmp:123", item, results))
    assert.is_true(vim.tbl_isempty(item))
    assert.are.same({ { file = "/tmp", lnum = 123 } }, results)
  end)

  it("returns success if consume = false", function()
    local node = parser.extract({ consume = false }, "(.+) (.+)", "action", "name")
    assert.equals(STATUS.SUCCESS, node:ingest("hello world", {}, {}))
  end)

  it("modifies item in-place if append = false", function()
    local node = parser.extract({ append = false }, "(.+) (.+)", "action", "name")
    local item = {}
    assert.equals(STATUS.RUNNING, node:ingest("hello world", item))
    assert.equals("hello", item.action)
    assert.equals("world", item.name)
  end)

  it("can use a list of strings match", function()
    local node = parser.extract({ consume = false, append = false }, {
      "^(a.+)$",
      "^(z.+)$",
    }, "word")
    local item = {}
    assert.equals(STATUS.FAILURE, node:ingest("something", item))
    node:reset()
    assert.equals(STATUS.SUCCESS, node:ingest("apple", item))
    assert.equals("apple", item.word)
    node:reset()
    assert.equals(STATUS.SUCCESS, node:ingest("zero", item))
    assert.equals("zero", item.word)
  end)

  it("can use a function match", function()
    local node = parser.extract({ append = false }, function()
      return "greetings", "Paul"
    end, "action", "name")
    local item = {}
    assert.equals(STATUS.RUNNING, node:ingest("hello world", item))
    assert.equals("greetings", item.action)
    assert.equals("Paul", item.name)
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
    local item = {}
    assert.equals(STATUS.FAILURE, node:ingest("something", item))
    node:reset()
    assert.equals(STATUS.SUCCESS, node:ingest("apple", item))
    assert.equals("alpha", item.type)
    node:reset()
    assert.equals(STATUS.SUCCESS, node:ingest("zero", item))
    assert.equals("zeta", item.type)
  end)

  it("can use a function to append", function()
    local node = parser.extract({
      append = function(results, item)
        results.single = item
      end,
    }, "(.+) (.+)", "action", "name")
    local item = {}
    local results = {}
    assert.equals(STATUS.RUNNING, node:ingest("hello world", item, results))
    assert.is_true(vim.tbl_isempty(item))
    assert.equals("hello", results.single.action)
    assert.equals("world", results.single.name)
  end)
end)

describe("extract_multiline", function()
  it("extracts lines into a single field until no match", function()
    local node = parser.extract_multiline("^.+$", "text")
    local results = {}
    local item = {}
    assert.equals(STATUS.RUNNING, node:ingest("hello", item, results))
    assert.equals(STATUS.RUNNING, node:ingest("world", item, results))
    assert.equals(STATUS.SUCCESS, node:ingest("", item, results))
    assert.are.same({ { text = "hello\nworld" } }, results)
  end)

  it("returns FAILURE when no lines match", function()
    local node = parser.extract_multiline("^.+$", "text")
    local results = {}
    local item = {}
    assert.equals(STATUS.FAILURE, node:ingest("", item, results))
  end)

  it("modifies item in-place if append = false", function()
    local node = parser.extract_multiline({ append = false }, "^.+$", "text")
    local results = {}
    local item = {}
    assert.equals(STATUS.RUNNING, node:ingest("hello", item, results))
    assert.equals(STATUS.RUNNING, node:ingest("world", item, results))
    assert.equals(STATUS.SUCCESS, node:ingest("", item, results))
    assert.are.same({ text = "hello\nworld" }, item)
    assert.are.same({}, results)
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
    local item = { foo = "bar" }
    local results = {}
    assert.equals(STATUS.SUCCESS, node:ingest("foo", item, results))
    assert.equals(1, vim.tbl_count(results))
    assert.equals("bar", results[1].foo)
    assert.is_true(vim.tbl_isempty(item))
  end)
end)

describe("loop", function()
  it("repeats the child, ignoring failures", function()
    local node = parser.loop(parser.extract("^a.*", "word"))
    local results = {}
    local item = {}
    assert.equals(STATUS.RUNNING, node:ingest("foo", item, results))
    assert.equals(STATUS.RUNNING, node:ingest("apple", item, results))
    assert.equals(STATUS.RUNNING, node:ingest("foo", item, results))
    assert.equals(STATUS.RUNNING, node:ingest("antlers", item, results))
    assert.equals(2, vim.tbl_count(results))
    assert.equals("apple", results[1].word)
    assert.equals("antlers", results[2].word)
  end)

  it("can propagate failures", function()
    local node = parser.loop({ ignore_failure = false }, parser.extract("^a.*", "word"))
    local results = {}
    local item = {}
    assert.equals(STATUS.RUNNING, node:ingest("apple", item, results))
    assert.equals(STATUS.FAILURE, node:ingest("foo", item, results))
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
    local results = {}
    local item = {}
    assert.equals(STATUS.RUNNING, node:ingest("hello there", item, results))
    assert.equals(STATUS.RUNNING, node:ingest("seal party", item, results))
    assert.equals(STATUS.SUCCESS, node:ingest("", item, results))
    assert.are.same({ { word = "hello" }, { word = "party" } }, results)
  end)

  it("stops running on first failure", function()
    local node = parser.sequence(parser.extract("^(.+) ", "word"), parser.extract(" (.+)$", "word"))
    local results = {}
    local item = {}
    assert.equals(STATUS.RUNNING, node:ingest("hello there", item, results))
    assert.equals(STATUS.FAILURE, node:ingest("Kansas", item, results))
    assert.are.same({ { word = "hello" } }, results)
  end)

  it("has option to ignore failure", function()
    local node = parser.sequence(
      { break_on_first_failure = false },
      parser.extract("^(.+) ", "word"),
      parser.extract(" (.+)$", "word"),
      parser.extract("(.+)$", "word")
    )
    local results = {}
    local item = {}
    assert.equals(STATUS.RUNNING, node:ingest("hello there", item, results))
    assert.equals(STATUS.RUNNING, node:ingest("Kansas", item, results))
    assert.equals(STATUS.FAILURE, node:ingest("", item, results))
    assert.are.same({ { word = "hello" }, { word = "Kansas" } }, results)
  end)

  it("has option to finish on first success", function()
    local node = parser.sequence(
      { break_on_first_failure = false, break_on_first_success = true },
      parser.extract("^(.+) ", "word"),
      parser.extract("^%d+$", "word"),
      parser.extract("(.+)$", "word")
    )
    local results = {}
    local item = {}
    assert.equals(STATUS.RUNNING, node:ingest("123", item, results))
    assert.equals(STATUS.SUCCESS, node:ingest("Kansas", item, results))
    assert.equals(1, vim.tbl_count(results))
    assert.equals(123, results[1].word)
  end)
end)

describe("parallel", function()
  it("runs children in parallel", function()
    local node = parser.parallel(parser.extract("%a+", "word"), parser.extract("%d+", "num"))
    local results = {}
    local item = {}
    assert.equals(STATUS.RUNNING, node:ingest("hello123", item, results))
    assert.equals(STATUS.SUCCESS, node:ingest("", item, results))
    assert.equals(2, vim.tbl_count(results))
    assert.equals("hello", results[1].word)
    assert.equals(123, results[2].num)
  end)

  it("stops running on first failure", function()
    local node = parser.parallel(parser.extract("%d+", "num"), parser.extract("%a+", "word"))
    local results = {}
    local item = {}
    assert.equals(STATUS.FAILURE, node:ingest("hello", item, results))
    assert.is_true(vim.tbl_isempty(results))
  end)

  it("has option to ignore failure", function()
    local node = parser.parallel(
      { break_on_first_failure = false },
      parser.extract("%d+", "num"),
      parser.extract("%a+", "word")
    )
    local results = {}
    local item = {}
    assert.equals(STATUS.RUNNING, node:ingest("hello", item, results))
    assert.equals(STATUS.FAILURE, node:ingest("", item, results))
    assert.equals(1, vim.tbl_count(results))
    assert.equals("hello", results[1].word)
  end)

  it("has option to finish on first success", function()
    local node = parser.parallel(
      { break_on_first_failure = false, break_on_first_success = true },
      parser.extract("%a+", "word"),
      parser.extract("%d+", "num")
    )
    local results = {}
    local item = {}
    assert.equals(STATUS.RUNNING, node:ingest("hello", item, results))
    assert.equals(STATUS.SUCCESS, node:ingest("", item, results))
    assert.equals(1, vim.tbl_count(results))
    assert.equals("hello", results[1].word)
  end)

  it("has option to restart children on each run", function()
    local node = parser.parallel(
      { restart_children = true },
      parser.sequence(parser.extract("%a+", "word"), parser.extract("%d+", "word"))
    )
    local results = {}
    local item = {}
    assert.equals(STATUS.RUNNING, node:ingest("hello123", item, results))
    assert.equals(STATUS.RUNNING, node:ingest("hello123", item, results))
    assert.equals(STATUS.RUNNING, node:ingest("hello123", item, results))
    assert.are.same({ { word = "hello" }, { word = "hello" }, { word = "hello" } }, results)
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
    assert.equals(STATUS.RUNNING, node:ingest("apple", {}, {}))
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
    assert.equals(STATUS.SUCCESS, node:ingest("bees", {}, {}))
  end)

  it("Turns a success into a failure", function()
    local node = parser.invert(parser.extract({ consume = false }, "apple", "fruit"))
    assert.equals(STATUS.FAILURE, node:ingest("apple", {}, {}))
  end)

  it("Passes RUNNING through unchanged", function()
    local node = parser.invert(parser.extract("apple", "fruit"))
    assert.equals(STATUS.RUNNING, node:ingest("apple", {}, {}))
  end)
end)

describe("until", function()
  it("returns RUNNING until child succeeds", function()
    local node = parser.ensure(parser.extract({ consume = false }, "apple", "fruit"))
    assert.equals(STATUS.RUNNING, node:ingest("bees", {}, {}))
    assert.equals(STATUS.RUNNING, node:ingest("Stanley", {}, {}))
    assert.equals(STATUS.SUCCESS, node:ingest("apple", {}, {}))
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
