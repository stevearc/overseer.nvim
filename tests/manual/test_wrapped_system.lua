vim.system({ "sleep", "10" }, {}, function(out)
  vim.notify("Job exited with code: " .. out.code)
end)

vim.system({ "echo", "hihihiihihihi" }, {
  stdout = function(err, data)
    vim.notify(string.format("Job stdout: %s", data))
  end,
})

vim.system({ "echo", "hello world" }, {}, function(out)
  vim.notify("Job stdout: " .. out.stdout)
end)

local proc = vim.system({ "echo", "hello world" }, {})
local out = proc:wait()
vim.notify("Job stdout: " .. out.stdout)
