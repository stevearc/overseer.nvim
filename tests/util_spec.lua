local util = require("overseer.util")

describe("util", function()
  describe("get_stdout_line_iter", function()
    it("iterates over lines", function()
      local stdout_iter = util.get_stdout_line_iter()
      local ret = stdout_iter({ "first", "second", "" })
      assert.are.same({ "first", "second" }, ret)
    end)
    it("line can be split over multiple calls", function()
      local stdout_iter = util.get_stdout_line_iter()
      local ret = stdout_iter({ "foo" })
      vim.list_extend(ret, stdout_iter({ "bar" }))
      vim.list_extend(ret, stdout_iter({ "" }))
      assert.are.same({ "foobar" }, ret)
    end)
    it("line can have a break immediately after", function()
      local stdout_iter = util.get_stdout_line_iter()
      local ret = stdout_iter({ "foo", "" })
      vim.list_extend(ret, stdout_iter({ "bar" }))
      vim.list_extend(ret, stdout_iter({ "" }))
      assert.are.same({ "foo", "bar" }, ret)
    end)
    it("line can have a break on the next set of data", function()
      local stdout_iter = util.get_stdout_line_iter()
      local ret = stdout_iter({ "foo" })
      vim.list_extend(ret, stdout_iter({ "", "bar" }))
      vim.list_extend(ret, stdout_iter({ "" }))
      assert.are.same({ "foo", "bar" }, ret)
    end)
    it("line can split over calls", function()
      local stdout_iter = util.get_stdout_line_iter()
      local ret = stdout_iter({ "fo" })
      vim.list_extend(ret, stdout_iter({ "o", "bar" }))
      vim.list_extend(ret, stdout_iter({ "" }))
      assert.are.same({ "foo", "bar" }, ret)
    end)
    it("removes carriage returns", function()
      local stdout_iter = util.get_stdout_line_iter()
      local ret = stdout_iter({ "foobar\r" })
      vim.list_extend(ret, stdout_iter({ "" }))
      assert.are.same({ "foobar" }, ret)
    end)
  end)

  describe("decode_json", function()
    it("parses normal json", function()
      local ret = util.decode_json('{"foo": "bar", "baz": 3}')
      assert.are.same({ foo = "bar", baz = 3 }, ret)
    end)

    it("parses json with linewise comments", function()
      local ret = util.decode_json([[{"foo": "bar",
      // This is a comment
      "baz": 3}]])
      assert.are.same({ foo = "bar", baz = 3 }, ret)
    end)

    it("parses json with linewise comments at the end", function()
      local ret = util.decode_json([[{"foo": "bar",
      "baz": 3}
      // This is a comment]])
      assert.are.same({ foo = "bar", baz = 3 }, ret)
    end)

    it("parses json with multiple linewise comments", function()
      local ret = util.decode_json([[{"foo": // comment
// comment
      "bar",
      "baz" // comment
      : 3 // comment }
    }
      // comment]])
      assert.are.same({ foo = "bar", baz = 3 }, ret)
    end)

    it("parses json with trailing commas", function()
      local ret = util.decode_json([[{"foo": "bar", "baz": 3,}]])
      assert.are.same({ foo = "bar", baz = 3 }, ret)
    end)

    it("parses json with trailing commas and whitespace", function()
      local ret = util.decode_json([[{"foo": "bar", "baz": 3 ,   
    }]])
      assert.are.same({ foo = "bar", baz = 3 }, ret)
    end)

    it("decodes null as nil", function()
      local ret = util.decode_json([[{"foo": null}]])
      assert.are.same({}, ret)
    end)
  end)
end)
