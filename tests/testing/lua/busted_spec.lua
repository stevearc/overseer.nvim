local integration = require("overseer.testing.lua.busted")
local test_utils = require("tests.testing.integration_test_utils")

describe("plenary_busted", function()
  it("parses test output", function()
    local output = [[
{
  "successes": [
    {
      "name": "Busted should run tests should succeed test",
      "trace": {
        "message": "should succeed test",
        "traceback": "\nstack traceback:\n\t./test_spec.lua:11: in function <./test_spec.lua:10>\n",
        "source": "@./test_spec.lua",
        "what": "Lua",
        "currentline": 11,
        "lastlinedefined": 31,
        "linedefined": 10,
        "short_src": "./test_spec.lua"
      },
      "element": {
        "starttime": 1654450154.0754,
        "duration": 5.8958990848623e-5,
        "descriptor": "it",
        "endtick": 100220.83345126,
        "starttick": 100220.8333923,
        "name": "should succeed test",
        "trace": {
          "message": "should succeed test",
          "traceback": "\nstack traceback:\n\t./test_spec.lua:11: in function <./test_spec.lua:10>\n",
          "source": "@./test_spec.lua",
          "what": "Lua",
          "currentline": 11,
          "lastlinedefined": 31,
          "linedefined": 10,
          "short_src": "./test_spec.lua"
        },
        "attributes": [],
        "endtime": 1654450154.0754
      }
    }
  ],
  "errors": [
    {
      "message": "./test_spec.lua:2: attempt to call global 'this' (a nil value)",
      "name": "Busted should run tests should show failure stacktrace",
      "isError": true,
      "trace": {
        "message": "./test_spec.lua:2: attempt to call global 'this' (a nil value)",
        "traceback": "\nstack traceback:\n\t./test_spec.lua:2: in function 'foo'\n\t./test_spec.lua:6: in function 'bar'\n\t./test_spec.lua:29: in function <./test_spec.lua:28>\n",
        "source": "@./test_spec.lua",
        "what": "Lua",
        "currentline": 2,
        "lastlinedefined": 3,
        "linedefined": 1,
        "short_src": "./test_spec.lua"
      },
      "element": {
        "starttime": 1654450154.076,
        "attributes": [],
        "starttick": 100220.83406446,
        "trace": {
          "message": "should show failure stacktrace",
          "traceback": "\nstack traceback:\n\t./test_spec.lua:28: in function <./test_spec.lua:10>\n",
          "source": "@./test_spec.lua",
          "what": "Lua",
          "currentline": 28,
          "lastlinedefined": 31,
          "linedefined": 10,
          "short_src": "./test_spec.lua"
        },
        "name": "should show failure stacktrace",
        "descriptor": "it"
      }
    }
  ],
  "pendings": [
    {
      "message": "./test_spec.lua:24: This is pending",
      "name": "Busted should run tests should skip test",
      "trace": {
        "message": { "message": "This is pending" },
        "traceback": "\nstack traceback:\n\t./test_spec.lua:24: in function <./test_spec.lua:23>\n",
        "source": "@./test_spec.lua",
        "what": "Lua",
        "currentline": 24,
        "lastlinedefined": 26,
        "linedefined": 23,
        "short_src": "./test_spec.lua"
      },
      "element": {
        "starttime": 1654450154.0759,
        "duration": 6.1792001361027e-5,
        "descriptor": "it",
        "endtick": 100220.83402177,
        "starttick": 100220.83395998,
        "name": "should skip test",
        "trace": {
          "message": "should skip test",
          "traceback": "\nstack traceback:\n\t./test_spec.lua:23: in function <./test_spec.lua:10>\n",
          "source": "@./test_spec.lua",
          "what": "Lua",
          "currentline": 23,
          "lastlinedefined": 31,
          "linedefined": 10,
          "short_src": "./test_spec.lua"
        },
        "attributes": [],
        "endtime": 1654450154.076
      }
    }
  ],
  "duration": 0.001430837000953,
  "failures": [
    {
      "message": "./test_spec.lua:16: Expected to be truthy, but value was:\n(boolean) false",
      "name": "Busted should run tests should fail test",
      "trace": {
        "message": {
          "message": "./test_spec.lua:16: Expected to be truthy, but value was:\n(boolean) false"
        },
        "traceback": "\nstack traceback:\n\t./test_spec.lua:16: in function <./test_spec.lua:15>\n",
        "source": "@./test_spec.lua",
        "what": "Lua",
        "currentline": 16,
        "lastlinedefined": 17,
        "linedefined": 15,
        "short_src": "./test_spec.lua"
      },
      "element": {
        "starttime": 1654450154.0755,
        "attributes": [],
        "starttick": 100220.83354567,
        "trace": {
          "message": "should fail test",
          "traceback": "\nstack traceback:\n\t./test_spec.lua:15: in function <./test_spec.lua:10>\n",
          "source": "@./test_spec.lua",
          "what": "Lua",
          "currentline": 15,
          "lastlinedefined": 31,
          "linedefined": 10,
          "short_src": "./test_spec.lua"
        },
        "name": "should fail test",
        "descriptor": "it"
      }
    },
    {
      "message": "./test_spec.lua:20: Expected objects to be the same.\nPassed in:\n(table: 0x55b593bb0dc0) {\n  [a] = 1\n *[b] = 4\n  [c] = 3\n  [d] = 4 }\nExpected:\n(table: 0x55b593b22430) {\n  [a] = 1\n *[b] = 2\n  [c] = 3\n  [d] = 4 }",
      "name": "Busted should run tests should show output",
      "trace": {
        "message": {
          "message": "./test_spec.lua:20: Expected objects to be the same.\nPassed in:\n(table: 0x55b593bb0dc0) {\n  [a] = 1\n *[b] = 4\n  [c] = 3\n  [d] = 4 }\nExpected:\n(table: 0x55b593b22430) {\n  [a] = 1\n *[b] = 2\n  [c] = 3\n  [d] = 4 }"
        },
        "traceback": "\nstack traceback:\n\t./test_spec.lua:20: in function <./test_spec.lua:19>\n",
        "source": "@./test_spec.lua",
        "what": "Lua",
        "currentline": 20,
        "lastlinedefined": 21,
        "linedefined": 19,
        "short_src": "./test_spec.lua"
      },
      "element": {
        "starttime": 1654450154.0758,
        "attributes": [],
        "starttick": 100220.83378507,
        "trace": {
          "message": "should show output",
          "traceback": "\nstack traceback:\n\t./test_spec.lua:19: in function <./test_spec.lua:10>\n",
          "source": "@./test_spec.lua",
          "what": "Lua",
          "currentline": 19,
          "lastlinedefined": 31,
          "linedefined": 10,
          "short_src": "./test_spec.lua"
        },
        "name": "should show output",
        "descriptor": "it"
      }
    }
  ]
}
]]
    local results = test_utils.run_parser(integration, output)
    assert.are.same({
      tests = {
        {
          duration = 5.8958990848623e-05,
          filename = "/home/stevearc/dotfiles/vimplugins/overseer.nvim/test_spec.lua",
          id = "/home/stevearc/dotfiles/vimplugins/overseer.nvim/test_spec.lua:Busted should run tests should succeed test",
          name = "should succeed test",
          path = { "Busted should run tests" },
          status = "SUCCESS",
        },
        {
          duration = 6.1792001361027e-05,
          filename = "/home/stevearc/dotfiles/vimplugins/overseer.nvim/test_spec.lua",
          id = "/home/stevearc/dotfiles/vimplugins/overseer.nvim/test_spec.lua:Busted should run tests should skip test",
          name = "should skip test",
          path = { "Busted should run tests" },
          status = "SKIPPED",
          text = "This is pending",
        },
        {
          diagnostics = {
            {
              filename = "./test_spec.lua",
              lnum = "16",
              text = "Expected to be truthy, but value was:\n(boolean) false",
            },
          },
          filename = "/home/stevearc/dotfiles/vimplugins/overseer.nvim/test_spec.lua",
          id = "/home/stevearc/dotfiles/vimplugins/overseer.nvim/test_spec.lua:Busted should run tests should fail test",
          name = "should fail test",
          path = { "Busted should run tests" },
          status = "FAILURE",
          text = "./test_spec.lua:16: Expected to be truthy, but value was:\n(boolean) false",
        },
        {
          diagnostics = {
            {
              filename = "./test_spec.lua",
              lnum = "20",
              text = "Expected objects to be the same.\nPassed in:\n(table: 0x55b593bb0dc0) {\n  [a] = 1\n *[b] = 4\n  [c] = 3\n  [d] = 4 }\nExpected:\n(table: 0x55b593b22430) {\n  [a] = 1\n *[b] = 2\n  [c] = 3\n  [d] = 4 }",
            },
          },
          filename = "/home/stevearc/dotfiles/vimplugins/overseer.nvim/test_spec.lua",
          id = "/home/stevearc/dotfiles/vimplugins/overseer.nvim/test_spec.lua:Busted should run tests should show output",
          name = "should show output",
          path = { "Busted should run tests" },
          status = "FAILURE",
          text = "./test_spec.lua:20: Expected objects to be the same.\nPassed in:\n(table: 0x55b593bb0dc0) {\n  [a] = 1\n *[b] = 4\n  [c] = 3\n  [d] = 4 }\nExpected:\n(table: 0x55b593b22430) {\n  [a] = 1\n *[b] = 2\n  [c] = 3\n  [d] = 4 }",
        },
        {
          diagnostics = {
            {
              filename = "./test_spec.lua",
              lnum = "2",
              text = "attempt to call global 'this' (a nil value)",
            },
          },
          filename = "/home/stevearc/dotfiles/vimplugins/overseer.nvim/test_spec.lua",
          id = "/home/stevearc/dotfiles/vimplugins/overseer.nvim/test_spec.lua:Busted should run tests should show failure stacktrace",
          name = "should show failure stacktrace",
          path = { "Busted should run tests" },
          stacktrace = {
            {
              filename = "\t./test_spec.lua",
              lnum = "2",
              text = "in function 'foo'",
            },
            {
              filename = "\t./test_spec.lua",
              lnum = "6",
              text = "in function 'bar'",
            },
            {
              filename = "\t./test_spec.lua",
              lnum = "29",
              text = "in function <./test_spec.lua:28>",
            },
          },
          status = "FAILURE",
          text = "./test_spec.lua:2: attempt to call global 'this' (a nil value)",
        },
      },
    }, results)
  end)
end)
