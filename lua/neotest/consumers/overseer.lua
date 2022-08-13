local async = require("neotest.async")
local config = require("neotest.config")
local lib = require("neotest.lib")
local strategy = require("neotest.client.strategies.overseer")

local neotest = {}
neotest.overseer = {}

local client
local last_group_id = 0
local task_groups = {}

function neotest.overseer.run(args)
  args = args or {}
  if type(args) == "string" then
    args = { args }
  end

  if args.strategy and args.strategy ~= "overseer" then
    return neotest.run.run(args)
  else
    args.strategy = "overseer"
  end
  async.run(function()
    local tree = neotest.run.get_tree_from_args(args, true)
    if not tree then
      lib.notify("No tests found")
      return
    end
    last_group_id = last_group_id + 1
    args.overseer_group_id = last_group_id
    strategy.set_group_id(last_group_id)

    task_groups[last_group_id] = { args = args, position_id = tree:data().id }
    client:run_tree(tree, args)
  end)
end

---@private
function neotest.overseer.rerun_task_group(group_id)
  strategy.recycle_group(group_id)
  strategy.set_group_id(group_id)
  local group = task_groups[group_id]
  async.run(function()
    local tree = client:get_position(group.position_id, group.args)
    if not tree then
      lib.notify("Prior test could not be found")
      return
    end
    client:run_tree(tree, group.args)
  end)
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
  __call = function(_, client_)
    client = client_
    neotest.run = require("neotest.consumers.run")(client)
    if not config.overseer or config.overseer.force_default ~= false then
      require("neotest").run = neotest.overseer
    end
    return neotest.overseer
  end,
})

return neotest.overseer
