local provider = require("overseer.template.make")

-- These tests target Linux: filename precedence requires a case-sensitive filesystem
-- where "makefile" and "Makefile" can exist as separate files.
describe("make template", function()
  local root

  before_each(function()
    root = vim.fn.tempname()
    vim.fn.mkdir(root, "p")
  end)

  after_each(function()
    vim.fn.delete(root, "rf")
  end)

  local function write_makefile(dir, filename, target)
    vim.fn.writefile({ target .. ":", "\t@touch recipe-ran" }, vim.fs.joinpath(dir, filename))
  end

  local function discover(dir)
    local result
    local immediate = provider.generator({ dir = dir }, function(templates)
      result = templates
    end)
    if immediate then
      result = immediate
    end
    assert.is_true(vim.wait(5000, function()
      return result ~= nil
    end))
    assert.is_table(result)
    return result
  end

  for _, filename in ipairs({ "GNUmakefile", "makefile", "Makefile" }) do
    it("discovers targets from " .. filename, function()
      write_makefile(root, filename, "build")
      assert.equals(vim.fs.joinpath(root, filename), provider.cache_key({ dir = root }))
      local templates = discover(root)
      assert.equals(1, #templates)
      assert.equals("make build", templates[1].name)
      local task = templates[1].builder({})
      assert.are.same({ "make", "build" }, task.cmd)
      assert.equals(root, task.cwd)
      assert.is_nil(vim.uv.fs_stat(vim.fs.joinpath(root, "recipe-ran")))
    end)
  end

  it("prefers GNUmakefile when all default names exist", function()
    write_makefile(root, "GNUmakefile", "gnu")
    write_makefile(root, "makefile", "lowercase")
    write_makefile(root, "Makefile", "uppercase")
    assert.equals(vim.fs.joinpath(root, "GNUmakefile"), provider.cache_key({ dir = root }))
    local templates = discover(root)
    assert.equals(1, #templates)
    assert.equals("make gnu", templates[1].name)
  end)

  it("prefers makefile over Makefile", function()
    write_makefile(root, "makefile", "lowercase")
    write_makefile(root, "Makefile", "uppercase")
    assert.equals(vim.fs.joinpath(root, "makefile"), provider.cache_key({ dir = root }))
    local templates = discover(root)
    assert.equals(1, #templates)
    assert.equals("make lowercase", templates[1].name)
  end)

  it("finds the closest makefile when searching upward", function()
    local project = vim.fs.joinpath(root, "project")
    local subdir = vim.fs.joinpath(project, "src")
    vim.fn.mkdir(subdir, "p")
    write_makefile(root, "GNUmakefile", "parent")
    write_makefile(project, "makefile", "build")
    assert.equals(vim.fs.joinpath(project, "makefile"), provider.cache_key({ dir = subdir }))
    local templates = discover(subdir)
    assert.equals(1, #templates)
    assert.equals("make build", templates[1].name)
    assert.equals(project, templates[1].builder({}).cwd)
  end)

  it("reports when no makefile exists", function()
    assert.is_nil(provider.cache_key({ dir = root }))
    assert.equals("No Makefile found", provider.generator({ dir = root }, function() end))
  end)
end)
