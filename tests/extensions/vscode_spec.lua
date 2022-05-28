local constants = require("overseer.constants")
local vscode = require("overseer.extensions.vscode")

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

  it("interpolates variables in command and args", function()
    local tmpl = vscode.convert_vscode_task({
      label = "task",
      type = "shell",
      command = "${workspaceFolder}/script",
      args = { "${execPath}" },
    })
    local task = tmpl:builder({})
    local dir = vim.fn.getcwd(0)
    assert.equals(string.format("%s/script 'code'", dir), task.cmd)
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
end)
