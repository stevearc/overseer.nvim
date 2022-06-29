local constants = require("overseer.constants")
local files = require("overseer.files")
local template = require("overseer.template")
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
  },
  builder = function(params)
    local cmd = { "make" }
    if params.args then
      cmd = vim.list_extend(cmd, params.args)
    end
    return {
      cmd = cmd,
    }
  end,
}

return {
  condition = {
    callback = function(opts)
      return files.exists(files.join(opts.dir, "Makefile"))
    end,
  },
  generator = function(opts)
    local content = files.read_file(files.join(opts.dir, "Makefile"))
    local ret = { tmpl }

    local parser = vim.treesitter.get_string_parser(content, "make", {})
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
      table.insert(ret, template.wrap(tmpl, override, { args = { k } }))
    end
    return ret
  end,
}
