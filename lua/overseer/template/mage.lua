-- A make/rake-like build tool using Go
-- https://magefile.org/

local log = require("overseer.log")
local overseer = require("overseer")

---@param opts overseer.SearchParams
---@return nil|string
local function get_magefile(opts)
  -- mage works with any file names using Go's "mage" build tag.
  -- "magefile.go" is just a common convention.
  return vim.fs.find("magefile.go", { upward = true, type = "file", path = opts.dir })[1]
end

---@param opts overseer.SearchParams
---@return nil|string
local function get_magedir(opts)
  -- mage works with any directory names specified with `-d` argument.
  -- "magefiles" is inferred if nothing is specified in the command line.
  return vim.fs.find("magefiles", { upward = true, type = "directory", path = opts.dir })[1]
end

---@type overseer.TemplateDefinition
local template = {
  name = "mage",
  params = {
    ---@type overseer.StringParam
    target = { optional = false, type = "string", desc = "target" },
    ---@type overseer.ListParam
    args = { optional = true, type = "list", delimiter = " " },
  },
  builder = function(params)
    local cmd = { "mage" }
    if params.target then
      table.insert(cmd, params.target)
    end

    ---@type overseer.TaskDefinition
    local task = { cmd = cmd }

    if params.args then
      task.args = params.args
    end
    return task
  end,
}

---@type overseer.TemplateFileProvider
local provider = {
  cache_key = function(opts)
    local magefile = get_magefile(opts)
    return magefile ~= nil and magefile or get_magedir(opts)
  end,
  condition = {
    callback = function(opts)
      if vim.fn.executable("mage") == 0 then
        return false, 'Command "mage" not found'
      end
      if not (get_magedir(opts) or get_magefile(opts)) then
        return false, "No magefile.go file or magefiles directory found"
      end
      return true
    end,
  },
  generator = function(opts, cb)
    local ret = {}
    local magefile, magedir = get_magefile(opts), get_magedir(opts)
    local jid = vim.fn.jobstart({
      "mage",
      "-l",
    }, {
      env = { MAGEFILE_ENABLE_COLOR = "false" },
      cwd = magefile ~= nil and vim.fs.dirname(magefile)
        or (magedir ~= nil and vim.fs.dirname(magedir) or opts.dir),
      stdout_buffered = true,
      on_stdout = vim.schedule_wrap(function(_, output)
        for _, line in ipairs(output) do
          if #line > 0 then
            local task_name, asterick, description = line:match("^  ([%w:]+)(%*?)%s+(.*)")
            if task_name ~= nil then
              local override = {
                name = string.format("mage %s", task_name),
                desc = #description > 0 and description or nil,
              }
              table.insert(ret, overseer.wrap_template(template, override, { target = task_name }))
            end
          end
        end
        cb(ret)
      end),
    })
    if jid == 0 then
      log.error("Passed invalid arguments to 'mage'")
      cb(ret)
    elseif jid == -1 then
      log.error("'mage' is not executable")
      cb(ret)
    end
  end,
}

return provider
