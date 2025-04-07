local jid = vim.fn.jobstart("sleep 10", {
  on_exit = function(_, code)
    vim.notify("Job exited with code: " .. code)
  end,
})
print("sleep jid", jid)

jid = vim.fn.jobstart("echo hihihiihihihi", {
  on_stdout = function(_, data)
    vim.notify("Job stdout: " .. vim.inspect(data))
  end,
})
print("echo jid", jid)
