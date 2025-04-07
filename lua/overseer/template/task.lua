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

---@type overseer.TemplateFileProvider
return {
  cache_key = function(opts)
    return find_taskfile(opts)
  end,
  generator = function(opts, cb)
    if vim.fn.executable("task") == 0 then
      return 'Command "task" not found'
    end
    local taskfile = find_taskfile(opts)
    if not taskfile then
      return "No Taskfile found"
    end
    local cwd = vim.fs.dirname(taskfile)
    local ret = {}
    overseer.builtin.system(
      { "task", "--list-all", "--json" },
      {
        cwd = cwd,
        text = true,
      },
      vim.schedule_wrap(function(out)
        if out.code ~= 0 then
          return cb(out.stderr or out.stdout or "Error running 'task'")
        end
        local ok, data = pcall(vim.json.decode, out.stdout, { luanil = { object = true } })
        if not ok then
          log.error("Task produced invalid json: %s", out.stdout)
          return cb(data)
        end
        assert(data)
        for _, target in ipairs(data.tasks) do
          table.insert(ret, {
            name = string.format("task %s", target.name),
            desc = target.desc,
            builder = function()
              return {
                cmd = { "task", target },
                cwd = cwd,
              }
            end,
          })
        end
        cb(ret)
      end)
    )
  end,
}
