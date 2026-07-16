local component = require("overseer.component")

describe("on_output_parse", function()
  local root

  before_each(function()
    root = vim.fn.tempname()
    vim.fn.mkdir(root, "p")
  end)

  after_each(function()
    vim.fn.delete(root, "rf")
  end)

  it("resolves relative filenames against relative_file_root, not vim's real cwd", function()
    assert.are_not.same(root, vim.fn.getcwd())

    local comps = component.load(
      { { "on_output_parse", errorformat = "%f:%l: %m" } },
      { relative_file_root = root }
    )
    local comp = comps[1]
    -- task.cwd is deliberately different from relative_file_root, and never
    -- used as a real directory, to prove relative_file_root takes priority.
    local task = { cwd = "/some/unrelated/task/cwd" }

    comp:on_output_lines(task, { "pkg/foo.go:10: some error" })
    local result = comp:on_pre_result(task)

    local diag = result.diagnostics[1]
    assert.are.same(vim.fs.joinpath(root, "pkg/foo.go"), vim.api.nvim_buf_get_name(diag.bufnr))
  end)

  it("falls back to task.cwd when relative_file_root is not set", function()
    local comps = component.load({ { "on_output_parse", errorformat = "%f:%l: %m" } }, {})
    local comp = comps[1]
    local task = { cwd = root }

    comp:on_output_lines(task, { "pkg/bar.go:5: another error" })
    local result = comp:on_pre_result(task)

    local diag = result.diagnostics[1]
    assert.are.same(vim.fs.joinpath(root, "pkg/bar.go"), vim.api.nvim_buf_get_name(diag.bufnr))
  end)
end)
