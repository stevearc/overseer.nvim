local json = require("overseer.json")

describe("json", function()
  it("parses normal json", function()
    local ret = json.decode('{"foo": "bar", "baz": 3}')
    assert.are.same({ foo = "bar", baz = 3 }, ret)
  end)

  it("parses json with linewise comments", function()
    local ret = json.decode([[{"foo": "bar",
    // This is a comment
    "baz": 3}]])
    assert.are.same({ foo = "bar", baz = 3 }, ret)
  end)

  it("parses json with linewise comments at the end", function()
    local ret = json.decode([[{"foo": "bar",
    "baz": 3}
    // This is a comment]])
    assert.are.same({ foo = "bar", baz = 3 }, ret)
  end)

  it("parses json with multiple linewise comments", function()
    local ret = json.decode([[{"foo": // comment
// comment
    "bar",
    "baz" // comment
    : 3 // comment }
  }
    // comment]])
    assert.are.same({ foo = "bar", baz = 3 }, ret)
  end)

  it("parses json with trailing commas", function()
    local ret = json.decode([[{"foo": "bar", "baz": 3,}]])
    assert.are.same({ foo = "bar", baz = 3 }, ret)
  end)

  it("parses json with trailing commas and whitespace", function()
    local ret = json.decode([[{"foo": "bar", "baz": 3 ,   
  }]])
    assert.are.same({ foo = "bar", baz = 3 }, ret)
  end)

  it("decodes null as nil", function()
    local ret = json.decode([[{"foo": null}]])
    assert.are.same({}, ret)
  end)
end)
