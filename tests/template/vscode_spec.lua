require("plenary.async").tests.add_to_env()
local overseer = require("overseer")
local constants = require("overseer.constants")
local files = require("overseer.files")
local parser = require("overseer.parser")
local vscode = require("overseer.template.vscode")
local problem_matcher = require("overseer.template.vscode.problem_matcher")

describe("vscode", function()
  it("parses process command and args", function()
    local provider = vscode.get_provider("process")
    local opts =
      provider.get_task_opts({ type = "process", command = "ls", args = { "foo", "bar" } })
    assert.are.same({ "ls", "foo", "bar" }, opts.cmd)
  end)

  it("parses shell command and args", function()
    local provider = vscode.get_provider("shell")
    local opts = provider.get_task_opts({
      type = "shell",
      command = "ls",
      args = { "foo", { value = "bar", quoting = "escape" } },
    })
    assert.are.same("ls 'foo' 'bar'", opts.cmd)
  end)

  it("strong quotes the args", function()
    local provider = vscode.get_provider("shell")
    local opts = provider.get_task_opts({
      type = "shell",
      command = "ls",
      args = { "foo bar", "baz" },
    })
    assert.are.same("ls 'foo bar' 'baz'", opts.cmd)
  end)

  it("interpolates variables in command, args, and opts", function()
    local tmpl = vscode.convert_vscode_task({
      label = "task",
      type = "shell",
      command = "${workspaceFolder}/script",
      args = { "${execPath}" },
      options = {
        cwd = "${cwd}",
        env = {
          FOO = "${execPath}",
        },
      },
    })
    local task = tmpl.builder({})
    local dir = vim.fn.getcwd(0)
    assert.equals(string.format("%s/script 'code'", dir), task.cmd)
    assert.equals(dir, task.cwd)
    assert.are.same({ FOO = "code" }, task.env)
  end)

  it("interpolates input variables in command", function()
    local tmpl = vscode.convert_vscode_task({
      label = "task",
      type = "shell",
      command = "echo",
      args = { "${input:word}" },
      inputs = {
        {
          id = "word",
          type = "pickString",
          desc = "A word",
          options = { "first", "second" },
        },
      },
    })
    local task = tmpl.builder({ word = "hello" })
    assert.equals("echo 'hello'", task.cmd)
  end)

  it("uses the task label", function()
    local tmpl = vscode.convert_vscode_task({
      type = "shell",
      command = "ls",
      label = "my task",
    })
    assert.equals("my task", tmpl.name)
  end)

  it("sets the tag from the group", function()
    local tmpl = vscode.convert_vscode_task({
      label = "task",
      type = "shell",
      command = "ls",
      group = "test",
    })
    assert.are.same({ constants.TAG.TEST }, tmpl.tags)
  end)

  it("sets the tag from group object", function()
    local tmpl = vscode.convert_vscode_task({
      label = "task",
      type = "shell",
      command = "ls",
      group = { kind = "build", isDefault = true },
    })
    assert.are.same({ constants.TAG.BUILD }, tmpl.tags)
  end)

  describe("problem matcher", function()
    it("can parse simple line output", function()
      local parse = parser.new(problem_matcher.get_parser_from_problem_matcher({
        pattern = {
          regexp = "^(.*):(\\d+):(\\d+):\\s+(warning|error):\\s+(.*)$",
          file = 1,
          line = 2,
          column = 3,
          severity = 4,
          message = 5,
        },
      }))
      parse:ingest({ "helloWorld.c:5:3: warning: implicit declaration of function 'prinft'" })
      local results = parse:get_result()
      assert.are.same({
        {
          lnum = 5,
          col = 3,
          filename = "helloWorld.c",
          text = "implicit declaration of function 'prinft'",
          type = "W",
        },
      }, results)
    end)

    it("can set the default severity level", function()
      local parse = parser.new(problem_matcher.get_parser_from_problem_matcher({
        severity = "warning",
        pattern = {
          regexp = "^(.*):(\\d+):(\\d+):\\s+(.*)$",
          file = 1,
          line = 2,
          column = 3,
          message = 4,
        },
      }))
      parse:ingest({ "helloWorld.c:5:3: implicit declaration of function 'prinft'" })
      local results = parse:get_result()
      assert.are.same({
        {
          lnum = 5,
          col = 3,
          filename = "helloWorld.c",
          text = "implicit declaration of function 'prinft'",
          type = "W",
        },
      }, results)
    end)

    it("can parse a file location", function()
      local parse = parser.new(problem_matcher.get_parser_from_problem_matcher({
        pattern = {
          regexp = "^(.*):([0-9,]+):\\s+(.*)$",
          file = 1,
          location = 2,
          message = 3,
        },
      }))
      parse:ingest({ "helloWorld.c:5,3,5,8: implicit declaration of function 'prinft'" })
      local results = parse:get_result()
      assert.are.same({
        {
          lnum = 5,
          col = 3,
          end_lnum = 5,
          end_col = 8,
          filename = "helloWorld.c",
          text = "implicit declaration of function 'prinft'",
        },
      }, results)
    end)

    it("uses full line as message by default", function()
      local parse = parser.new(problem_matcher.get_parser_from_problem_matcher({
        pattern = {
          regexp = "^(.*):(\\d+):.*$",
          file = 1,
          location = 2,
        },
      }))
      parse:ingest({ "helloWorld.c:5: implicit declaration of function 'prinft'" })
      local results = parse:get_result()
      assert.are.same({
        {
          lnum = 5,
          filename = "helloWorld.c",
          text = "helloWorld.c:5: implicit declaration of function 'prinft'",
        },
      }, results)
    end)

    it("can match multiline patterns", function()
      local parse = parser.new(problem_matcher.get_parser_from_problem_matcher({
        pattern = {
          {
            regexp = "^([^\\s].*)$",
            file = 1,
          },
          {
            regexp = "^\\s+(\\d+):(\\d+)\\s+(error|warning|info)\\s+(.*)$",
            line = 1,
            column = 2,
            severity = 3,
            message = 4,
          },
        },
      }))
      parse:ingest({
        { "test.js" },
        { '  1:0   error  Missing "use strict" statement' },
      })
      assert.are.same({
        {
          filename = "test.js",
          lnum = 1,
          col = 0,
          type = "E",
          text = 'Missing "use strict" statement',
        },
      }, parse:get_result())
    end)

    it("can match repeating multiline patterns", function()
      local parse = parser.new(problem_matcher.get_parser_from_problem_matcher({
        pattern = {
          {
            regexp = "^([^\\s].*)$",
            file = 1,
          },
          {
            regexp = "^\\s+(\\d+):(\\d+)\\s+(error|warning|info)\\s+(.*)$",
            line = 1,
            column = 2,
            severity = 3,
            message = 4,
            loop = true,
          },
        },
      }))
      parse:ingest({
        { "test.js" },
        { '  1:0   error    Missing "use strict" statement' },
        { "  1:9   warning  foo is defined but never used" },
      })
      assert.are.same({
        {
          filename = "test.js",
          lnum = 1,
          col = 0,
          type = "E",
          text = 'Missing "use strict" statement',
        },
        {
          filename = "test.js",
          lnum = 1,
          col = 9,
          type = "W",
          text = "foo is defined but never used",
        },
      }, parse:get_result())
    end)

    it("can use built in parsers", function()
      local parse = parser.new(problem_matcher.get_parser_from_problem_matcher({
        pattern = "$go",
      }))
      parse:ingest({ "my_test.go:307: Expected 'Something' received 'Nothing'" })
      local results = parse:get_result()
      assert.are.same({
        {
          lnum = 307,
          filename = "my_test.go",
          text = "Expected 'Something' received 'Nothing'",
        },
      }, results)
    end)
  end)
end)

describe("vscode integration tests", function()
  local vs_util = require("overseer.template.vscode.vs_util")
  local _orig_load_tasks_file = vs_util.load_tasks_file
  local task_file
  local test_hook = function(task_defn, util)
    task_defn.strategy = "test"
  end
  before_each(function()
    vs_util.load_tasks_file = function()
      return task_file
    end
    overseer.add_template_hook({ module = "vscode" }, test_hook)
  end)
  after_each(function()
    vs_util.load_tasks_file = _orig_load_tasks_file
    overseer.remove_template_hook({ module = "vscode" }, test_hook)
  end)

  a.it("parses tsc --watch diagnostics", function()
    task_file = {
      version = "2.0.0",
      tasks = {
        {
          type = "process",
          label = "tsc watch",
          command = "yarn tsc --watch",
          problemMatcher = "$tsc-watch",
        },
      },
    }

    local task, err = a.wrap(overseer.run_template, 2)({ name = "tsc watch" })
    assert.is_nil(err)
    task.strategy:send_output([[
yarn run v1.22.10
[7:48:49 AM] Starting compilation in watch mode...

src/index.ts:3:1 - error TS1435: Unknown keyword or identifier. Did you mean 'import'?

3 mport './entry';
  ~~~~~

]])
    -- No results have been set yet
    assert.is_nil(task.result)

    -- After end pattern is seen, results should be set
    task.strategy:send_output([[[7:48:54 AM] Found 1 error. Watching for file changes.
]])
    assert.are.same({
      diagnostics = {
        {
          filename = files.join(task.cwd, "src/index.ts"),
          lnum = 3,
          col = 1,
          type = "E",
          code = 1435,
          text = "Unknown keyword or identifier. Did you mean 'import'?",
        },
      },
    }, task.result)

    -- Send the start pattern, it should reset the results
    task.strategy:send_output({
      "[7:48:57 AM] File change detected. Starting incremental compilation...",
      "",
    })
    assert.are.same({
      diagnostics = {},
    }, task.result)

    -- We should be able to parse new results after the reset
    task.strategy:send_output([[
src/index.ts:3:1 - error TS1435: Unknown keyword or identifier. Did you mean 'import'?

3 mport './entry';
  ~~~~~

[7:48:54 AM] Found 1 error. Watching for file changes.
]])
    assert.are.same({
      diagnostics = {
        {
          filename = files.join(task.cwd, "src/index.ts"),
          lnum = 3,
          col = 1,
          type = "E",
          code = 1435,
          text = "Unknown keyword or identifier. Did you mean 'import'?",
        },
      },
    }, task.result)
    task:dispose(true)
  end)
end)
