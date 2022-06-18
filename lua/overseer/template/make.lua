local constants = require("overseer.constants")
local files = require("overseer.files")
local TAG = constants.TAG

local make_targets = [[
(rule (targets) @name)

(rule (targets) @phony (#eq? @phony ".PHONY")
  normal: (prerequisites
    (word) @name)
)
]]

return {
  priority = 60,
  tags = { TAG.BUILD },
  params = {
    args = { optional = true, type = "list", delimiter = " " },
  },
  condition = {
    callback = function(self, opts)
      return files.exists(files.join(opts.dir, "Makefile"))
    end,
  },
  metagen = function(self, opts)
    local content = files.read_file(files.join(opts.dir, "Makefile"))

    local parser = vim.treesitter.get_string_parser(content, "make", {})
    if not parser then
      return { self }
    end
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

    local ret = { self }
    for k in pairs(targets) do
      local override = { name = string.format("make %s", k) }
      if k == default_target then
        override.priority = 55
      end
      table.insert(ret, self:wrap(override, { args = { k } }))
    end
    return ret
  end,
  builder = function(self, params)
    local cmd = { "make" }
    if params.args then
      cmd = vim.list_extend(cmd, params.args)
    end
    return {
      cmd = cmd,
    }
  end,
}
