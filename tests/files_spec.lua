local files = require("overseer.files")

describe("files", function()
  describe("is_subpath", function()
    it("returns false if candidate is empty", function()
      assert.falsy(files.is_subpath("/", ""))
    end)

    it("returns true when both are absolute paths", function()
      assert.truthy(files.is_subpath("/foo/bar", "/foo/bar/baz"))
    end)

    it("returns false when both are absolute paths", function()
      assert.falsy(files.is_subpath("/foo/bar", "/foo/baz/bar"))
    end)

    it("returns true when root is absolute path", function()
      local root = vim.fn.getcwd()
      assert.truthy(files.is_subpath(root .. "/foo", "foo/bar"))
    end)

    it("returns false when root is absolute path", function()
      local root = vim.fn.getcwd()
      assert.falsy(files.is_subpath(root .. "/foo", "bar/foo"))
    end)

    it("returns true when candidate is absolute path", function()
      local root = vim.fn.getcwd()
      assert.truthy(files.is_subpath(".", root .. "/foo/bar"))
    end)

    it("returns false when candidate is absolute path", function()
      assert.falsy(files.is_subpath(".", "/bar/foo"))
    end)

    it("returns true when both are relative paths", function()
      assert.truthy(files.is_subpath("foo", "foo/bar"))
    end)

    it("returns false when both are relative paths", function()
      assert.falsy(files.is_subpath("foo", "/bar/foo"))
    end)

    it("returns false if substring is not subpath", function()
      assert.falsy(files.is_subpath("foo.c", "foo.cpp"))
    end)
  end)
end)
