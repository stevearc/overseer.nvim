local constants = require("overseer.constants")
local files = require("overseer.files")
local log = require("overseer.log")
local overseer = require("overseer")
local TAG = constants.TAG

local make_targets = [[
(rule (targets) @name)

(rule (targets) @phony (#eq? @phony ".PHONY")
  normal: (prerequisites
    (word) @name)
)
]]

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

local function ts_parse_make_targets(parser, content, cwd, ret)
  local query = vim.treesitter.parse_query("make", make_targets)
  local root = parser:parse()[1]:root()
  pcall(vim.tbl_add_reverse_lookup, query.captures)
  local targets = {}
  local default_target
  for _, match in query:iter_matches(root, content) do
    local name = vim.treesitter.get_node_text(match[query.captures.name], content)
    targets[name] = true
    if not default_target and not match[query.captures.phony] then
      default_target = name
    end
  end

  for k in pairs(targets) do
    local override = { name = string.format("make %s", k) }
    if k == default_target then
      override.priority = 55
    end
    table.insert(ret, overseer.wrap_template(tmpl, override, { args = { k }, cwd = cwd }))
  end
  return ret
end

local function parse_make_output(cwd, ret, cb)
  local jid = vim.fn.jobstart({ "make", "-rRpq" }, {
    cwd = cwd,
    stdout_buffered = true,
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
            local target = line:sub(1, idx - 1)
            local override = { name = string.format("make %s", target) }
            table.insert(
              ret,
              overseer.wrap_template(tmpl, override, { args = { target }, cwd = cwd })
            )
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

return {
  condition = {
    callback = function(opts)
      return vim.fn.findfile("Makefile", opts.dir .. ";") ~= "" and vim.fn.executable("make") == 1
    end,
  },
  generator = function(opts, cb)
    local makefile = vim.fn.findfile("Makefile", opts.dir .. ";")
    local cwd = vim.fn.fnamemodify(makefile, ":h")
    local content = files.read_file(makefile)

    local ret = { overseer.wrap_template(tmpl, nil, { cwd = cwd }) }
    local ok, parser = pcall(vim.treesitter.get_string_parser, content, "make", {})
    if ok then
      ts_parse_make_targets(parser, content, cwd, ret)
      return ret
    else
      parse_make_output(cwd, ret, cb)
    end
  end,
}
