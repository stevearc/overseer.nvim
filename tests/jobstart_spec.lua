local overseer = require("overseer")

describe("jobstart strategy", function()
  it("renders output when restarted from a floating task list", function()
    overseer.setup({ dap = false })

    local task = overseer.new_task({
      cmd = { "sh", "-c", "printf first; sleep 1; printf second" },
      components = { "on_exit_set_status" },
    })
    task:start()
    assert.is_true(vim.wait(2000, function()
      return task:is_complete()
    end, 10))

    task:reset()
    local list_bufnr = require("overseer.task_list").get_or_create_bufnr()
    local list_winid = vim.api.nvim_open_win(list_bufnr, true, {
      relative = "editor",
      row = 1,
      col = 1,
      width = 20,
      height = 5,
    })
    vim.bo[list_bufnr].filetype = "OverseerList"
    task:start()

    local output_bufnr = assert(task:get_bufnr())
    assert.is_true(vim.wait(500, function()
      return task:is_running()
        and vim.tbl_contains(vim.api.nvim_buf_get_lines(output_bufnr, 0, -1, true), "first")
    end, 10))

    vim.api.nvim_win_close(list_winid, true)
    task:stop()
  end)
end)
