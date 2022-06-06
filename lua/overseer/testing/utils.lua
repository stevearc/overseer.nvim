local config = require("overseer.config")
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
M.get_tests_from_ts_query = function(bufnr, lang, queryname, query_str, id_func)
  local parsers = require("nvim-treesitter.parsers")
  local parser = parsers.get_parser(bufnr)
  local tests = {}
  if not parser or parser:lang() ~= lang then
    return tests
  end
  local filename = vim.api.nvim_buf_get_name(bufnr)
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
      local test = {
        name = name,
        filename = filename,
        path = vim.tbl_map(function(p)
          return p.name
        end, path),
        lnum = lnum_start + 1,
        col = col_start,
        lnum_end = lnum_end + 1,
        col_end = col_end,
      }
      test.id = id_func(test)
      table.insert(tests, test)
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

M.create_test_result_buffer = function(result, bufnr)
  if not bufnr then
    bufnr = vim.api.nvim_create_buf(false, true)
  end
  local lines = {}
  local highlights = {}
  local icon = config.testing.icons[result.status]
  table.insert(lines, string.format("%s%s", icon, result.name))
  table.insert(highlights, {
    string.format("OverseerTest%s", result.status),
    #lines,
    0,
    string.len(icon),
  })

  if result.text then
    for line in vim.gsplit(result.text, "\n") do
      table.insert(lines, line)
    end
  end
  if result.stacktrace then
    table.insert(lines, "")
    table.insert(lines, "Stacktrace:")
    for _, item in ipairs(result.stacktrace) do
      table.insert(lines, string.format("%s:%s %s", item.filename, item.lnum, item.text))
    end
  end

  local ns = vim.api.nvim_create_namespace("OverseerTest")
  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
  for _, hl in ipairs(highlights) do
    local group, lnum, col_start, col_end = unpack(hl)
    vim.api.nvim_buf_add_highlight(bufnr, ns, group, lnum - 1, col_start, col_end)
  end

  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
  vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
  vim.api.nvim_buf_set_option(bufnr, "filetype", "OverseerTest")
  vim.api.nvim_buf_set_var(bufnr, "test_id", result.id)
  return bufnr
end

return M
