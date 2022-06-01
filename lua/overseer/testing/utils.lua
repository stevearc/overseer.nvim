local M = {}

local query_cache = {}
local function clear_path(path, lnum)
  for i = #path, 1, -1 do
    local entry = path[i]
    if entry.lnum_end < lnum then
      table.remove(path, i)
    else
      return
    end
  end
end
M.get_tests_from_ts_query = function(bufnr, lang, queryname, query_str)
  local parser = vim.treesitter.get_parser(bufnr, "python")
  local tests = {}
  if not parser then
    return tests
  end
  local syntax_tree = parser:parse()[1]
  if not syntax_tree then
    return tests
  end
  local query = query_cache[queryname]
  if not query then
    query = vim.treesitter.parse_query(lang, query_str)
    query_cache[queryname] = query
    vim.tbl_add_reverse_lookup(query.captures)
  end
  local get_node_text = vim.treesitter.query.get_node_text
  local path = {}
  for _, match in query:iter_matches(syntax_tree:root(), bufnr) do
    local name_node = match[query.captures.name]
    local name = get_node_text(name_node, bufnr)
    if match[query.captures.group] then
      local lnum_start, _, lnum_end, _ = match[query.captures.group]:range()
      clear_path(path, lnum_start)
      table.insert(path, {
        name = name,
        lnum_start = lnum_start,
        lnum_end = lnum_end,
      })
    else
      local lnum_start, col_start, lnum_end, col_end = match[query.captures.test]:range()
      clear_path(path, lnum_start)
      table.insert(tests, {
        name = name,
        path = vim.tbl_map(function(p)
          return p.name
        end, path),
        lnum = lnum_start,
        col = col_start,
        lnum_end = lnum_end,
        col_end = col_end,
      })
    end
  end
  return tests
end

M.find_nearest_test = function(tests, lnum)
  for _, test in ipairs(tests) do
    if test.lnum <= lnum and test.lnum_end >= lnum then
      return test
    end
  end
end

return M
