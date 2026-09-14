local tox = require("overseer.template.tox")

local function task_names(tasks)
  local names = {}
  for _, task in ipairs(tasks) do
    table.insert(names, task.name)
  end
  table.sort(names)
  return names
end

describe("tox template", function()
  local dir

  before_each(function()
    dir = vim.fn.tempname()
    assert.equals(1, vim.fn.mkdir(dir, "p"))
  end)

  after_each(function()
    vim.fn.delete(dir, "rf")
  end)

  it("parses multiline envlists and expands factors", function()
    vim.fn.writefile({
      "[tox]",
      "envlist =",
      "    lint",
      "    py{3.14, 3.13}",
      "    build",
      "",
      "[testenv:docs]",
    }, dir .. "/tox.ini")

    local tasks = tox.generator({ dir = dir })
    assert.are.same(
      { "tox build", "tox docs", "tox lint", "tox py3.13", "tox py3.14" },
      task_names(tasks)
    )
  end)

  it("uses the tox file directory as the task cwd", function()
    vim.fn.writefile({ "[tox]", "envlist = lint" }, dir .. "/tox.ini")

    local tasks = tox.generator({ dir = dir })
    local task = assert(tasks[1])
    assert.are.same({ "tox", "-e", "lint" }, task.builder().cmd)
    assert.equals(dir, task.builder().cwd)
  end)
end)
