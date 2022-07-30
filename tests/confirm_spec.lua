require("plenary.async").tests.add_to_env()
local channel = a.control.channel

local function feedkeys(actions, timestep)
  timestep = timestep or 10
  a.util.sleep(timestep)
  for _, action in ipairs(actions) do
    a.util.sleep(timestep)
    local escaped = vim.api.nvim_replace_termcodes(action, true, false, true)
    vim.api.nvim_feedkeys(escaped, "m", true)
  end
  a.util.sleep(timestep)
  -- process pending keys until the queue is empty.
  -- Note that this will exit insert mode.
  vim.api.nvim_feedkeys("", "x", true)
  a.util.sleep(timestep)
end

local function run_confirm(keys, opts)
  opts = opts or {}
  local tx, rx = channel.oneshot()
  require("overseer.confirm")(opts, tx)
  feedkeys(keys)
  if opts.after_fn then
    opts.after_fn()
  end
  return rx()
end

a.describe("confirm modal", function()
  after_each(function()
    -- Clean up all floating windows so one test failure doesn't cascade
    for _, winid in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_config(winid).relative ~= "" then
        vim.api.nvim_win_close(winid, true)
      end
    end
  end)

  a.it("Confirms choices", function()
    local ret = run_confirm({ "o" }, {
      message = "Message",
    })
    assert(ret == 1)
  end)

  a.it("Can cancel choice", function()
    local ret = run_confirm({ "<Esc>" }, {
      message = "Message",
    })
    assert(ret == 0)
  end)

  a.it("Can specify choices", function()
    local ret = run_confirm({ "C" }, {
      message = "Message",
      choices = { "&Hello", "&Cancel" },
    })
    assert(ret == 2)
  end)

  a.it("Uses first letter of choice by default", function()
    local ret = run_confirm({ "C" }, {
      message = "Message",
      choices = { "Hello", "Cancel" },
    })
    assert(ret == 2)
  end)

  a.it("Can specify choice letters that are not at the start", function()
    local ret = run_confirm({ "n" }, {
      message = "Message",
      choices = { "Hello", "Ca&ncel" },
    })
    assert(ret == 2)
  end)

  a.it("Returns the default value on enter", function()
    local ret = run_confirm({ "<CR>" }, {
      message = "Message",
      choices = { "Hello", "Cancel" },
      default = 2,
    })
    assert(ret == 2)
  end)
end)
