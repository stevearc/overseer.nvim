local config = require("neotest.config")
local lib = require("neotest.lib")
local strategy = require("neotest.client.strategies.overseer")

local neotest = {}
neotest.overseer = {}

local last_group_id = 0
local args_by_group = {}

function neotest.overseer.run(args)
  args = args or {}
  if args.strategy and args.strategy ~= "overseer" then
    return neotest.run.run(args)
  else
    args.strategy = "overseer"
  end
  last_group_id = last_group_id + 1
  args.overseer_group_id = last_group_id
  args_by_group[last_group_id] = args
  strategy.set_group_id(last_group_id)
  return neotest.run.run(args)
end

---@private
function neotest.overseer.rerun_task_group(group_id)
  strategy.recycle_group(group_id)
  strategy.set_group_id(group_id)
  neotest.run.run(args_by_group[group_id])
end

function neotest.overseer.run_last(args)
  args = args or {}
  if args.strategy and args.strategy ~= "overseer" then
    return neotest.run.run_last(args)
  end
  if last_group_id == 0 then
    lib.notify("No tests run yet")
    return
  end
  neotest.overseer.rerun_task_group(last_group_id)
end

setmetatable(neotest.overseer, {
  __index = function(_, key)
    return neotest.run[key]
  end,
})

neotest.overseer = setmetatable(neotest.overseer, {
  __call = function(_, client)
    neotest.run = require("neotest.consumers.run")(client)
    if not config.overseer or config.overseer.force_default ~= false then
      require("neotest").run = neotest.overseer
    end
    return neotest.overseer
  end,
})

return neotest.overseer
