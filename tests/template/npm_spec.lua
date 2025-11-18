-- Test the npm template through its generator function
local npm_template = require("overseer.template.npm")

describe("npm template workspace glob patterns", function()
  local function create_package_json(path, data)
    vim.fn.mkdir(path, "p")
    local json_path = vim.fs.joinpath(path, "package.json")
    local json_str = vim.fn.json_encode(data or {})
    vim.fn.writefile(vim.split(json_str, "\n"), json_path)
  end

  it("loads the npm template successfully", function()
    assert.is_not_nil(npm_template)
    assert.is_not_nil(npm_template.generator)
  end)

  it("handles literal workspace paths", function()
    local temp_dir = vim.fn.tempname()
    vim.fn.mkdir(temp_dir, "p")

    -- Create directory structure: packages/core/package.json
    create_package_json(vim.fs.joinpath(temp_dir, "packages", "core"), {
      name = "core",
      scripts = { test = "echo test" },
    })

    -- Create root package.json with literal workspace path
    create_package_json(temp_dir, {
      name = "root",
      scripts = { build = "echo build" },
      workspaces = { "packages/core" },
    })

    local opts = {
      dir = temp_dir,
      filename = vim.fs.joinpath(temp_dir, "package.json"),
    }

    local tasks = npm_template.generator(opts)
    assert.is_table(tasks)
    -- Should have at least the root build task
    assert.is_true(#tasks > 0)

    vim.fn.delete(temp_dir, "rf")
  end)

  it("handles single-level glob patterns (packages/*)", function()
    local temp_dir = vim.fn.tempname()
    vim.fn.mkdir(temp_dir, "p")

    -- Create directory structure:
    -- packages/core/package.json
    -- packages/ui/package.json
    create_package_json(vim.fs.joinpath(temp_dir, "packages", "core"), {
      name = "core",
      scripts = { test = "echo test core" },
    })

    create_package_json(vim.fs.joinpath(temp_dir, "packages", "ui"), {
      name = "ui",
      scripts = { test = "echo test ui" },
    })

    -- Create root package.json with glob workspace pattern
    create_package_json(temp_dir, {
      name = "root",
      scripts = { build = "echo build" },
      workspaces = { "packages/*" },
    })

    local opts = {
      dir = temp_dir,
      filename = vim.fs.joinpath(temp_dir, "package.json"),
    }

    local tasks = npm_template.generator(opts)
    assert.is_table(tasks)
    -- Should have root build task + core test + ui test
    assert.is_true(#tasks >= 3)

    vim.fn.delete(temp_dir, "rf")
  end)

  it("handles nested glob patterns (workspaces/**)", function()
    local temp_dir = vim.fn.tempname()
    vim.fn.mkdir(temp_dir, "p")

    -- Create directory structure:
    -- ws1/api/package.json
    -- ws1/client/package.json
    -- ws2/lib/package.json
    create_package_json(vim.fs.joinpath(temp_dir, "ws1", "api"), {
      name = "api",
      scripts = { start = "echo start api" },
    })

    create_package_json(vim.fs.joinpath(temp_dir, "ws1", "client"), {
      name = "client",
      scripts = { start = "echo start client" },
    })

    create_package_json(vim.fs.joinpath(temp_dir, "ws2", "lib"), {
      name = "lib",
      scripts = { start = "echo start lib" },
    })

    -- Create root package.json with nested glob workspace pattern
    create_package_json(temp_dir, {
      name = "root",
      scripts = { build = "echo build" },
      workspaces = { "**" },
    })

    local opts = {
      dir = temp_dir,
      filename = vim.fs.joinpath(temp_dir, "package.json"),
    }

    local tasks = npm_template.generator(opts)
    assert.is_table(tasks)
    -- Should have root build task + 3 workspace start tasks
    assert.is_true(#tasks >= 4)

    vim.fn.delete(temp_dir, "rf")
  end)

  it("handles multiple workspace patterns", function()
    local temp_dir = vim.fn.tempname()
    vim.fn.mkdir(temp_dir, "p")

    -- Create directory structure:
    -- packages/core/package.json
    -- libs/util/package.json
    create_package_json(vim.fs.joinpath(temp_dir, "packages", "core"), {
      name = "core",
      scripts = { test = "echo test core" },
    })

    create_package_json(vim.fs.joinpath(temp_dir, "libs", "util"), {
      name = "util",
      scripts = { test = "echo test util" },
    })

    -- Create root package.json with multiple workspace patterns
    create_package_json(temp_dir, {
      name = "root",
      scripts = { build = "echo build" },
      workspaces = { "packages/*", "libs/*" },
    })

    local opts = {
      dir = temp_dir,
      filename = vim.fs.joinpath(temp_dir, "package.json"),
    }

    local tasks = npm_template.generator(opts)
    assert.is_table(tasks)
    -- Should have root build task + core test + util test
    assert.is_true(#tasks >= 3)

    vim.fn.delete(temp_dir, "rf")
  end)

  it("handles Yarn v1 workspaces.packages format", function()
    local temp_dir = vim.fn.tempname()
    vim.fn.mkdir(temp_dir, "p")

    -- Create directory structure:
    -- packages/core/package.json
    -- packages/ui/package.json
    create_package_json(vim.fs.joinpath(temp_dir, "packages", "core"), {
      name = "core",
      scripts = { test = "echo test core" },
    })

    create_package_json(vim.fs.joinpath(temp_dir, "packages", "ui"), {
      name = "ui",
      scripts = { test = "echo test ui" },
    })

    -- Create root package.json with Yarn v1 workspaces.packages format
    create_package_json(temp_dir, {
      name = "root",
      scripts = { build = "echo build" },
      workspaces = {
        packages = { "packages/*" },
      },
    })

    local opts = {
      dir = temp_dir,
      filename = vim.fs.joinpath(temp_dir, "package.json"),
    }

    local tasks = npm_template.generator(opts)
    assert.is_table(tasks)
    -- Should have root build task + core test + ui test
    assert.is_true(#tasks >= 3)

    vim.fn.delete(temp_dir, "rf")
  end)
end)
