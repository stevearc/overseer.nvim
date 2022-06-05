local files = require("overseer.files")
local parser = require("overseer.parser")
local M = {}

local source_buf
local output_buf
local input_buf

local function get_filepath(filename)
  return files.join(vim.fn.stdpath("cache"), "overseer", filename)
end

local function load_parser()
  local bufnr = source_buf
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
  local text = table.concat(lines, "\n")
  parser.trace(true)
  local builder = loadstring(text)
  local ok, ret = pcall(builder)
  if ok and ret.ingest then
    return ret
  end
end

local function render_node(lines, highlights, node, depth, trace)
  local name = string.format("%s%s", string.rep("  ", depth), node.name)
  if trace[node.id] then
    local col = string.len(name) + 1
    for _, status in ipairs(trace[node.id]) do
      table.insert(
        highlights,
        { string.format("Overseer%s", status), #lines + 1, col, col + string.len(status) }
      )
      col = col + string.len(status) + 1
    end
    name = name .. " " .. table.concat(trace[node.id], " ")
  end
  table.insert(lines, name)
  if node.child then
    render_node(lines, highlights, node.child, depth + 1, trace)
  elseif node.children then
    for _, child in ipairs(node.children) do
      render_node(lines, highlights, child, depth + 1, trace)
    end
  end
end

local function render_parser(input_lnum)
  local bufnr = output_buf
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  local p = load_parser()
  if not p then
    return
  end
  p:ingest(vim.api.nvim_buf_get_lines(input_buf, 0, input_lnum or -1, true))
  local trace = parser.get_trace()
  local lines = {}
  local highlights = {}
  if p.tree then
    render_node(lines, highlights, p.tree, 0, trace)
  elseif p.children then
    for k, v in pairs(p.children) do
      table.insert(lines, string.format("%s:", k))
      render_node(lines, highlights, v, 1, trace)
    end
  end

  local rem = p:get_remainder()
  if rem then
    table.insert(lines, "ITEM:")
    vim.list_extend(lines, vim.split(vim.inspect(rem), "\n"))
  end
  table.insert(lines, "RESULT:")
  local results = p:get_result()
  vim.list_extend(lines, vim.split(vim.inspect(results), "\n"))

  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
  local ns = vim.api.nvim_create_namespace("OverseerParser")
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  for _, hl in ipairs(highlights) do
    local group, lnum, col_start, col_end = unpack(hl)
    vim.api.nvim_buf_add_highlight(bufnr, ns, group, lnum - 1, col_start, col_end)
  end
end

local function create_source_bufnr()
  local file = get_filepath("debug_parser_source.lua")
  vim.cmd(string.format("edit %s", file))
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.api.nvim_buf_line_count(bufnr) == 1 then
    local lines = {
      'local parser = require("overseer.parser")',
      "return parser.new({",
      '  parser.extract("(.*)", "text")',
      "})",
    }
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
    vim.cmd([[noautocmd write]])
  end
  source_buf = bufnr
  vim.api.nvim_create_autocmd("BufWritePost", {
    desc = "update parser debug view on write",
    callback = function()
      render_parser()
    end,
    buffer = bufnr,
  })
end

local function create_output_buf(bufnr)
  if not bufnr then
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(0, bufnr)
  end
  output_buf = bufnr
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
end

local function create_input_buf()
  local file = get_filepath("debug_parser_input.txt")
  vim.cmd(string.format("edit %s", file))
  local bufnr = vim.api.nvim_get_current_buf()
  input_buf = bufnr
  if vim.api.nvim_buf_line_count(bufnr) == 1 then
    local lines = { "foo.lua:234: Sample input line" }
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
    vim.cmd([[noautocmd write]])
  end
  vim.api.nvim_create_autocmd("CursorMoved", {
    desc = "Rerun parser when cursor moves",
    buffer = bufnr,
    callback = function()
      local lnum = vim.api.nvim_win_get_cursor(0)[1]
      render_parser(lnum)
    end,
  })
end

M.start_debug_session = function()
  for _, buf in ipairs({ source_buf, output_buf, input_buf }) do
    if buf and vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
  vim.cmd([[tabnew]])
  create_source_bufnr()
  local source_win = vim.api.nvim_get_current_win()
  vim.cmd([[vsplit]])
  create_output_buf()
  vim.api.nvim_set_current_win(source_win)
  vim.cmd([[split]])
  create_input_buf()
  vim.api.nvim_set_current_win(source_win)
  render_parser()
end

return M
