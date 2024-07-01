local config = require("overseer.config")
local layout = require("overseer.layout")
local util = require("overseer.util")
local M = {}

---@diagnostic disable: undefined-field

M.create_plug_bindings = function(bufnr, plug_bindings, ...)
  local args = vim.F.pack_len(...)
  for _, binding in ipairs(plug_bindings) do
    local rhs = binding.rhs
    if type(binding.rhs) == "function" then
      rhs = function()
        binding.rhs(vim.F.unpack_len(args))
      end
    end
    vim.keymap.set("", binding.plug, rhs, { buffer = bufnr, desc = binding.desc })
  end
end

---@param bufnr number
---@param mode string
---@param bindings table<string, string|false>
---@param prefix string
M.create_bindings_to_plug = function(bufnr, mode, bindings, prefix)
  local maps
  if mode == "i" then
    maps = vim.api.nvim_buf_get_keymap(bufnr, "")
  end
  for lhs, rhs in pairs(bindings) do
    -- Prefix with <Plug> unless this is a <Cmd> or :Cmd mapping
    if rhs then
      if type(rhs) == "string" and not rhs:match("[<:]") then
        rhs = "<Plug>" .. prefix .. rhs
      end
      if mode == "i" then
        -- HACK for some reason I can't get plug mappings to work in insert mode
        for _, map in ipairs(maps) do
          if map.lhs == rhs then
            ---@diagnostic disable-next-line: cast-local-type
            rhs = map.callback or map.rhs
            break
          end
        end
      end
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, remap = true })
    end
  end
end

---@param prefix string
M.show_bindings = function(prefix)
  prefix = "<Plug>" .. prefix
  local plug_to_bindings = {}
  local descriptions = {}
  local max_left = 1
  for _, keymap in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
    if vim.startswith(keymap.lhs, prefix) then
      descriptions[keymap.lhs] = keymap.desc
    elseif keymap.rhs and vim.startswith(keymap.rhs, prefix) then
      max_left = math.max(max_left, vim.api.nvim_strwidth(keymap.lhs))
      local bindings = plug_to_bindings[keymap.rhs]
      if not bindings then
        bindings = {}
        plug_to_bindings[keymap.rhs] = bindings
      end
      table.insert(bindings, keymap.lhs)
      table.sort(bindings)
    end
  end

  local bindings_to_plug = {}
  local highlights = {}
  for plug, bindings in pairs(plug_to_bindings) do
    local binding_str = table.concat(bindings, "/")
    bindings_to_plug[binding_str] = plug
    local hl = {}
    highlights[binding_str] = hl
    local col_start = 0
    for _, binding in ipairs(bindings) do
      local col_end = col_start + binding:len() + 1
      table.insert(hl, { col_start, col_end })
      col_start = col_end + 1
    end
  end

  local lhs = vim.tbl_keys(bindings_to_plug)
  table.sort(lhs)

  local lines = {}
  local max_line = 1
  for _, left in ipairs(lhs) do
    local right = descriptions[bindings_to_plug[left]]
    local line = string.format(" %s   %s", util.ljust(left, max_left), right)
    max_line = math.max(max_line, vim.api.nvim_strwidth(line))
    table.insert(lines, line)
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
  local ns = vim.api.nvim_create_namespace("overseer")
  for i, left in ipairs(lhs) do
    for _, hl in ipairs(highlights[left]) do
      local start_col, end_col = unpack(hl)
      vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, start_col, {
        end_col = end_col,
        hl_group = "Special",
      })
    end
  end
  vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = bufnr })
  vim.keymap.set("n", "<c-c>", "<cmd>close<CR>", { buffer = bufnr })
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].bufhidden = "wipe"

  local width = layout.calculate_width(max_line + 1, { min_width = 20 })
  local height = layout.calculate_height(#lines, { min_height = 10 })
  local win = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    row = math.floor((layout.get_editor_height() - height) / 2),
    col = math.floor((layout.get_editor_width() - width) / 2),
    width = width,
    height = height,
    style = "minimal",
    border = config.help_win.border,
    zindex = config.help_win.zindex,
  })
  for opt, value in pairs(config.help_win.win_opts or {}) do
    vim.wo[win][opt] = value
  end
end

return M
