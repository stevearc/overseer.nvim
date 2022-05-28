local constants = require("overseer.constants")
local parser = require("overseer.parser")
local vscode = require("overseer.extensions.vscode")
local problem_matcher = require("overseer.extensions.vscode.problem_matcher")

describe("vscode", function()
  it("parses process command and args", function()
    local cmd = vscode.get_cmd({ type = "process", command = "ls", args = { "foo", "bar" } })
    assert.are.same({ "ls", "foo", "bar" }, cmd)
  end)

  it("parses shell command and args", function()
    local cmd = vscode.get_cmd({
      type = "shell",
      command = "ls",
      args = { "foo", { value = "bar", quoting = "escape" } },
    })
    assert.are.same("ls 'foo' 'bar'", cmd)
  end)

  it("strong quotes the command if it has spaces", function()
    local cmd = vscode.get_cmd({
      type = "shell",
      command = "space command",
    })
    assert.are.same("'space command'", cmd)
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
    local task = tmpl:builder({})
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
      inputs = { { id = "word", type = "pickString", description = "A word" } },
    })
    local task = tmpl:builder({ word = "hello" })
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
  end)
end)
