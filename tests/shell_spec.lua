local shell = require("overseer.shell")

describe("shell", function()
  describe("bash", function()
    it("Escapes special characters", function()
      local tests = {
        { "a space", "a\\ space" },
        { "has'quote", "has\\'quote" },
        { "has'\" quotes", "has\\'\\\"\\ quotes" },
      }
      for _, test in ipairs(tests) do
        local got = shell.escape(test[1], "escape", "/bin/bash")
        assert.equals(test[2], got)
      end
    end)

    it("Strong quotes value", function()
      local tests = {
        { "a space", "'a space'" },
        { "has'quote", "'has'\"'\"'quote'" },
        { "has'\" quotes", "'has'\"'\"'\" quotes'" },
      }
      for _, test in ipairs(tests) do
        local got = shell.escape(test[1], "strong", "/bin/bash")
        assert.equals(test[2], got)
      end
    end)

    it("Weak quotes value", function()
      local tests = {
        { "a space", '"a space"' },
        { "has'quote", '"has\'quote"' },
        { "has'\" quotes", '"has\'\\" quotes"' },
      }
      for _, test in ipairs(tests) do
        local got = shell.escape(test[1], "weak", "/bin/bash")
        assert.equals(test[2], got)
      end
    end)
  end)

  describe("windows", function()
    describe("powershell", function()
      it("Escapes special characters", function()
        local tests = {
          { "a space", "a` space" },
          { "has'quote", "has`'quote" },
          { "has'\" quotes", "has`'`\"` quotes" },
          { "has(parens)", "has`(parens`)" },
        }
        for _, test in ipairs(tests) do
          local got = shell.escape(test[1], "escape", "powershell")
          assert.equals(test[2], got)
        end
      end)

      it("Strong quotes value", function()
        local tests = {
          { "a space", "'a space'" },
          { "has' quote", "'has'' quote'" },
          { "has'\" quotes", "'has''\" quotes'" },
        }
        for _, test in ipairs(tests) do
          local got = shell.escape(test[1], "strong", "powershell")
          assert.equals(test[2], got)
        end
      end)

      it("Weak quotes value", function()
        local tests = {
          { "a space", '"a space"' },
          { "has' quote", '"has\' quote"' },
          { "has'\" quotes", '"has\'`" quotes"' },
        }
        for _, test in ipairs(tests) do
          local got = shell.escape(test[1], "weak", "powershell")
          assert.equals(test[2], got)
        end
      end)

      it("Uses call operator for quoted commands", function()
        local got = shell.escape_cmd({ "foo bar" }, "strong", "pwsh")
        assert.equals("& 'foo bar'", got)
      end)

      it("Doesn't use call operator for unquoted commands", function()
        local got = shell.escape_cmd({ "foo", "bar" }, "strong", "pwsh")
        assert.equals("foo bar", got)
      end)
    end)

    describe("cmd.exe", function()
      it("can't escape special characters", function()
        local tests = {
          { "a space", "a space" },
          { "has'quote", "has'quote" },
          { "has'\"quotes", "has'\"quotes" },
        }
        for _, test in ipairs(tests) do
          local got = shell.escape(test[1], "escape", "cmd.exe")
          assert.equals(test[2], got)
        end
      end)

      it("Strong quotes value", function()
        local tests = {
          { "a space", '"a space"' },
          { "has'quote", '"has\'quote"' },
          { "has'\"quotes", '"has\'"quotes"' },
        }
        for _, test in ipairs(tests) do
          local got = shell.escape(test[1], "strong", "cmd.exe")
          assert.equals(test[2], got)
        end
      end)

      it("can't weak quote value", function()
        local tests = {
          { "a space", "a space" },
          { "has'quote", "has'quote" },
          { "has'\"quotes", "has'\"quotes" },
        }
        for _, test in ipairs(tests) do
          local got = shell.escape(test[1], "weak", "cmd.exe")
          assert.equals(test[2], got)
        end
      end)

      it("Quotes entire line if cmd and args are quoted", function()
        local got = shell.escape_cmd({ "foo bar", "baz qux" }, "strong", "cmd.exe")
        assert.equals('""foo bar" "baz qux""', got)
      end)

      it("Doesn't quote entire line if args are not quoted", function()
        local got = shell.escape_cmd({ "foo", "baz qux" }, "strong", "cmd.exe")
        assert.equals('foo "baz qux"', got)
      end)
    end)
  end)
end)
