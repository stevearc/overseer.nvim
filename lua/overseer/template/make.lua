local constants = require("overseer.constants")
local log = require("overseer.log")
local overseer = require("overseer")
local TAG = constants.TAG

---@type overseer.TemplateFileDefinition
local tmpl = {
  name = "make",
  priority = 60,
  tags = { TAG.BUILD },
  params = {
    args = { optional = true, type = "list", delimiter = " " },
    cwd = { optional = true },
  },
  builder = function(params)
    return {
      cmd = { "make" },
      args = params.args,
      cwd = params.cwd,
    }
  end,
}

local function parse_make_output(cwd, ret, cb)
  local jid = vim.fn.jobstart({ "make", "-rRpq" }, {
    cwd = cwd,
    stdout_buffered = true,
    env = {
      ["LANG"] = "C.UTF-8",
    },
    on_stdout = vim.schedule_wrap(function(j, output)
      local parsing = false
      local prev_line = ""
      for _, line in ipairs(output) do
        if line:find("# Files") == 1 then
          parsing = true
        elseif line:find("# Finished Make") == 1 then
          break
        elseif parsing then
          if line:match("^[^%.#%s]") and prev_line:find("# Not a target") ~= 1 then
            local idx = line:find(":")
            if idx then
              local target = line:sub(1, idx - 1)
              local override = { name = string.format("make %s", target) }
              table.insert(
                ret,
                overseer.wrap_template(tmpl, override, { args = { target }, cwd = cwd })
              )
            end
          end
        end
        prev_line = line
      end

      cb(ret)
    end),
  })
  if jid == 0 then
    log:error("Passed invalid arguments to 'make'")
    cb(ret)
  elseif jid == -1 then
    log:error("'make' is not executable")
    cb(ret)
  end
end

---@param opts overseer.SearchParams
---@return nil|string
local function get_makefile(opts)
  return vim.fs.find("Makefile", { upward = true, type = "file", path = opts.dir })[1]
end

---@type overseer.TemplateFileProvider
local provider = {
  cache_key = function(opts)
    return get_makefile(opts)
  end,
  condition = {
    callback = function(opts)
      if vim.fn.executable("make") == 0 then
        return false, 'Command "make" not found'
      end
      if not get_makefile(opts) then
        return false, "No Makefile found"
      end
      return true
    end,
  },
  generator = function(opts, cb)
    local makefile = assert(get_makefile(opts))
    local cwd = vim.fs.dirname(makefile)

    local ret = { overseer.wrap_template(tmpl, nil, { cwd = cwd }) }
    parse_make_output(cwd, ret, cb)
  end,
}
return provider
