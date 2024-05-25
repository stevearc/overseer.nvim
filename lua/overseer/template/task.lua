-- A task runner / simpler Make alternative written in Go
-- https://taskfile.dev/

local log = require("overseer.log")
local overseer = require("overseer")

local taskfiles = {
  "Taskfile.yml",
  "Taskfile.yaml",
  "Taskfile.dist.yml",
  "Taskfile.dist.yaml",
}

---@param opts overseer.SearchParams
---@return nil|string
local function find_taskfile(opts)
  return vim.fs.find(taskfiles, { upward = true, type = "file", path = opts.dir })[1]
end

---@type overseer.TemplateDefinition
local template = {
  name = "task",
  desc = "default target",
  priority = 60,
  params = {
    ---@type overseer.StringParam
    target = { optional = false, type = "string", desc = "target" },
    ---@type overseer.ListParam
    args = { optional = true, type = "list", delimiter = " " },
    ---@type overseer.StringParam
    cwd = { optional = true },
  },
  builder = function(params)
    local cmd = { "task" }
    if params.target then
      table.insert(cmd, params.target)
    end

    ---@type overseer.TaskDefinition
    local task = {
      cmd = cmd,
      cwd = params.cwd,
    }

    if params.args then
      task.args = vim.list_extend({ "--" }, params.args)
    end
    return task
  end,
}

---@type overseer.TemplateProvider
local provider = {
  name = "task",
  cache_key = function(opts)
    return find_taskfile(opts)
  end,
  condition = {
    callback = function(opts)
      if vim.fn.executable("task") == 0 then
        return false, 'Command "task" not found'
      end
      if not find_taskfile(opts) then
        return false, "No Taskfile found"
      end
      return true
    end,
  },
  generator = function(opts, cb)
    local ret = {}
    local cmd = { "task", "--list-all", "--json" }
    local jid = vim.fn.jobstart(cmd, {
      cwd = opts.dir,
      stdout_buffered = true,
      on_stdout = vim.schedule_wrap(function(_, output)
        local ok, data =
          pcall(vim.json.decode, table.concat(output, "\n"), { luanil = { object = true } })
        if not ok then
          log:error("Task produced invalid json: %s\n%s", data, output)
          cb(ret)
          return
        end
        assert(data)
        for _, target in ipairs(data.tasks) do
          ---@type overseer.TemplateDefinition
          local override = {
            name = string.format("task %s", target.name),
            desc = target.desc,
          }
          if target.name == "default" then
            override.priority = 55
          end
          table.insert(
            ret,
            overseer.wrap_template(template, override, { target = target.name, cwd = opts.dir })
          )
        end
        cb(ret)
      end),
    })
    if jid == 0 then
      log:error("Passed invalid arguments to 'task'")
      cb(ret)
    elseif jid == -1 then
      log:error("'task' is not executable")
      cb(ret)
    end
  end,
}

return provider
