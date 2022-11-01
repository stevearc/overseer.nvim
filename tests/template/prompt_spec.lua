local template = require("overseer.template")

describe("template should prompt", function()
  it("always returns false if schema is empty", function()
    local show_prompt, err = template._should_prompt("always", {}, {})
    assert.is_false(show_prompt)
    assert.is_nil(err)
  end)

  it("always returns true if prompt = 'always'", function()
    local show_prompt, err = template._should_prompt("always", {
      foo = {
        optional = true,
        default = "hi",
      },
    }, { foo = "hihi" })
    assert.is_true(show_prompt)
    assert.is_nil(err)
  end)

  it("always returns true if prompt = 'always'", function()
    local show_prompt, err = template._should_prompt("always", {
      foo = {
        optional = true,
        default = "hi",
      },
    }, { foo = "hihi" })
    assert.is_true(show_prompt)
    assert.is_nil(err)
  end)

  it("returns false if prompt = 'never' and all params have default", function()
    local show_prompt, err = template._should_prompt("never", {
      foo = {
        default = "hi",
      },
    }, {})
    assert.is_false(show_prompt)
    assert.is_nil(err)
  end)

  it("returns false if prompt = 'never' and all params were passed a value", function()
    local show_prompt, err = template._should_prompt("never", {
      foo = {},
    }, { foo = "hi" })
    assert.is_false(show_prompt)
    assert.is_nil(err)
  end)

  it(
    "returns error if prompt = 'never' and any non-optional, non-default param is missing a value",
    function()
      local show_prompt, err = template._should_prompt("never", {
        foo = {},
      }, {})
      assert.is_nil(show_prompt)
      assert.not_nil(err)
    end
  )

  it("returns true if prompt = 'allow' and any non-optional param is missing a value", function()
    local show_prompt, err = template._should_prompt("allow", {
      foo = {},
    }, {})
    assert.is_true(show_prompt)
    assert.is_nil(err)
  end)

  it(
    "returns true if prompt = 'allow' and any param is non-optional with missing value, even if default",
    function()
      local show_prompt, err = template._should_prompt("allow", {
        foo = {
          default = "hi",
        },
      }, {})
      assert.is_true(show_prompt)
      assert.is_nil(err)
    end
  )

  it("returns false if prompt = 'allow' and all params are optional", function()
    local show_prompt, err = template._should_prompt("allow", {
      foo = {
        optional = true,
      },
    }, {})
    assert.is_false(show_prompt)
    assert.is_nil(err)
  end)

  it("returns false if prompt = 'allow' and all params have a supplied value", function()
    local show_prompt, err = template._should_prompt("allow", {
      foo = {},
    }, { foo = "hi" })
    assert.is_false(show_prompt)
    assert.is_nil(err)
  end)

  it("returns true if prompt = 'missing' and any non-optional param is missing a value", function()
    local show_prompt, err = template._should_prompt("missing", {
      foo = {},
    }, {})
    assert.is_true(show_prompt)
    assert.is_nil(err)
  end)

  it(
    "returns true if prompt = 'missing' and any param is non-optional with missing value, even if default",
    function()
      local show_prompt, err = template._should_prompt("missing", {
        foo = {
          default = "hi",
        },
      }, {})
      assert.is_true(show_prompt)
      assert.is_nil(err)
    end
  )

  it("returns true if prompt = 'missing' and all params are optional", function()
    local show_prompt, err = template._should_prompt("missing", {
      foo = {
        optional = true,
      },
    }, {})
    assert.is_true(show_prompt)
    assert.is_nil(err)
  end)

  it("returns false if prompt = 'missing' and all params have a supplied value", function()
    local show_prompt, err = template._should_prompt("missing", {
      foo = {},
    }, { foo = "hi" })
    assert.is_false(show_prompt)
    assert.is_nil(err)
  end)

  it("returns true if prompt = 'avoid' and any non-optional param is missing a value", function()
    local show_prompt, err = template._should_prompt("avoid", {
      foo = {},
    }, {})
    assert.is_true(show_prompt)
    assert.is_nil(err)
  end)

  it(
    "returns false if prompt = 'avoid' and any param is non-optional with missing value, but has a default",
    function()
      local show_prompt, err = template._should_prompt("avoid", {
        foo = {
          default = "hi",
        },
      }, {})
      assert.is_false(show_prompt)
      assert.is_nil(err)
    end
  )

  it("returns false if prompt = 'avoid' and all params are optional", function()
    local show_prompt, err = template._should_prompt("avoid", {
      foo = {
        optional = true,
      },
    }, {})
    assert.is_false(show_prompt)
    assert.is_nil(err)
  end)

  it("returns false if prompt = 'avoid' and all params have a supplied value", function()
    local show_prompt, err = template._should_prompt("avoid", {
      foo = {},
    }, { foo = "hi" })
    assert.is_false(show_prompt)
    assert.is_nil(err)
  end)
end)
