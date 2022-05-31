local parser = require("overseer.parser")
local TEST_STATUS = require("overseer.testing.data").TEST_STATUS

local function run_parser(name, output)
  local defn = require("overseer.parsers.python")[name]()
  local p = parser.new(defn)
  p:ingest(vim.split(output, "\n"))
  return p:get_result()
end

describe("python_unittest", function()
  it("parses test failures", function()
    local output = [[test_color (tests.test_objects.TestGDObjects)
Test for Color ... ok
test_node_path (tests.test_objects.TestGDObjects)
Test for NodePath ... ok
test_sub_resource (tests.test_objects.TestGDObjects)
Test for SubResource ... FAIL

Stdout:
Hello world

Stderr:
This is error
test_vector2 (tests.test_objects.TestGDObjects)
Test for Vector2 ... ok

======================================================================
FAIL: test_sub_resource (tests.test_objects.TestGDObjects)
Test for SubResource
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/home/stevearc/ws/godot_parser/tests/test_objects.py", line 100, in test_sub_resource
    self.assertEqual(r.id, 3)
AssertionError: 2 != 3

Stdout:
Hello world

Stderr:
This is error

----------------------------------------------------------------------
Ran 7 tests in 0.001s]]
    local results = run_parser("python_unittest", output)
    assert.are.same({
      tests = {
        {
          id = "tests.test_objects.TestGDObjects.test_color",
          path = { "tests", "test_objects", "TestGDObjects" },
          name = "test_color",
          status = TEST_STATUS.SUCCESS,
        },
        {
          id = "tests.test_objects.TestGDObjects.test_node_path",
          path = { "tests", "test_objects", "TestGDObjects" },
          name = "test_node_path",
          status = TEST_STATUS.SUCCESS,
        },
        {
          id = "tests.test_objects.TestGDObjects.test_vector2",
          path = { "tests", "test_objects", "TestGDObjects" },
          name = "test_vector2",
          status = TEST_STATUS.SUCCESS,
        },
        {
          id = "tests.test_objects.TestGDObjects.test_sub_resource",
          path = { "tests", "test_objects", "TestGDObjects" },
          name = "test_sub_resource",
          status = TEST_STATUS.FAILURE,
          stacktrace = {
            {
              filename = "/home/stevearc/ws/godot_parser/tests/test_objects.py",
              lnum = 100,
            },
          },
        },
      },
      diagnostics = {
        {
          filename = "/home/stevearc/ws/godot_parser/tests/test_objects.py",
          lnum = 100,
          text = "AssertionError: 2 != 3",
        },
      },
    }, results)
  end)
end)
