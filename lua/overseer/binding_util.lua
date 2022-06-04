local layout = require("overseer.layout")
local util = require("overseer.util")
local M = {}

M.create_bindings = function(bufnr, bindings, ...)
  local args = util.pack(...)
  for _, binding in ipairs(bindings) do
    local rhs = binding.rhs
    if type(binding.rhs) == "function" then
      rhs = function()
        binding.rhs(unpack(args))
      end
    end
    if binding.plug then
      vim.keymap.set(binding.mode, binding.plug, rhs, { buffer = bufnr, desc = binding.desc })
    end
    for _, lhs in util.iter_as_list(binding.lhs) do
      if binding.plug then
        vim.keymap.set(binding.mode, lhs, binding.plug, { buffer = bufnr, remap = true })
      else
        vim.keymap.set(binding.mode, lhs, rhs, { buffer = bufnr, desc = binding.desc })
      end
    end
  end
end

M.show_bindings = function(bindings)
  local lhs = {}
  local rhs = {}
  local max_left = 1
  for _, binding in ipairs(bindings) do
    local keystr = binding.lhs
    if type(binding.lhs) == "table" then
      keystr = table.concat(binding.lhs, "/")
    end
    max_left = math.max(max_left, vim.api.nvim_strwidth(keystr))
    table.insert(lhs, keystr)
    table.insert(rhs, binding.desc)
  end

  local lines = {}
  local max_line = 1
  for i = 1, #lhs do
    local left = lhs[i]
    local right = rhs[i]
    local line = string.format(" %s   %s", util.ljust(left, max_left), right)
    max_line = math.max(max_line, vim.api.nvim_strwidth(line))
    table.insert(lines, line)
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
  local ns = vim.api.nvim_create_namespace("overseer")
  for i = 1, #lhs do
    vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, 0, {
      end_col = max_left + 1,
      hl_group = "Special",
    })
  end
  vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = bufnr })
  vim.keymap.set("n", "<c-c>", "<cmd>close<CR>", { buffer = bufnr })
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")

  local width = layout.calculate_width(max_line + 1, { min_width = 20 })
  local height = layout.calculate_height(#lines, { min_height = 10 })
  vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    row = math.floor((layout.get_editor_height() - height) / 2),
    col = math.floor((layout.get_editor_width() - width) / 2),
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
  })
end

return M
