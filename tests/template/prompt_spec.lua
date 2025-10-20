local template = require("overseer.template")

describe("template should prompt", function()
  it("returns false if disallow_prompt=true and all params have default", function()
    local show_prompt, err = template._should_prompt(true, {
      foo = {
        default = "hi",
      },
    }, {})
    assert.is_false(show_prompt)
    assert.is_nil(err)
  end)

  it("returns false if disallow_prompt=true and all params were passed a value", function()
    local show_prompt, err = template._should_prompt(true, {
      foo = {},
    }, { foo = "hi" })
    assert.is_false(show_prompt)
    assert.is_nil(err)
  end)

  it(
    "returns error if disallow_prompt=true and any non-optional, non-default param is missing a value",
    function()
      local show_prompt, err = template._should_prompt(true, {
        foo = {},
      }, {})
      assert.is_nil(show_prompt)
      assert.not_nil(err)
    end
  )

  it("returns true if any non-optional param is missing a value", function()
    local show_prompt, err = template._should_prompt(nil, {
      foo = {},
    }, {})
    assert.is_true(show_prompt)
    assert.is_nil(err)
  end)

  it("returns false if any param is non-optional with missing value, but has a default", function()
    local show_prompt, err = template._should_prompt(nil, {
      foo = {
        default = "hi",
      },
    }, {})
    assert.is_false(show_prompt)
    assert.is_nil(err)
  end)

  it("returns false if all params are optional", function()
    local show_prompt, err = template._should_prompt(nil, {
      foo = {
        optional = true,
      },
    }, {})
    assert.is_false(show_prompt)
    assert.is_nil(err)
  end)

  it("returns false if all params have a supplied value", function()
    local show_prompt, err = template._should_prompt(nil, {
      foo = {},
    }, { foo = "hi" })
    assert.is_false(show_prompt)
    assert.is_nil(err)
  end)
end)
