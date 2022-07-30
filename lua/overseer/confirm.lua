local config = require("overseer.config")
local layout = require("overseer.layout")

---Create the shortcut letter highlight group if not present
local function create_letter_highlight()
  if not pcall(vim.api.nvim_get_hl_by_name, "OverseerConfirmShortcut", false) then
    local keyword = vim.api.nvim_get_hl_by_name("Keyword", true)
    keyword.underline = true
    keyword.bold = true
    vim.api.nvim_set_hl(0, "OverseerConfirmShortcut", keyword)
  end
end

local icons = {
  Generic = nil,
  Info = " ",
  Warn = " ",
  Error = " ",
  Question = " ",
}

local type_map = {
  G = "Generic",
  I = "Info",
  W = "Warn",
  E = "Error",
  Q = "Question",
}

local default_hl_map = {
  Generic = "Normal",
  Info = "DiagnosticInfo",
  Warn = "DiagnosticWarn",
  Error = "DiagnosticError",
  Question = "DiagnosticInfo",
}

for _, v in pairs(type_map) do
  vim.cmd(string.format("hi default link OverseerConfirm%s %s", v, default_hl_map[v]))
  vim.cmd(string.format("hi default link OverseerConfirmBorder%s %s", v, default_hl_map[v]))
end

return function(opts, callback)
  vim.validate({
    message = { opts.message, "s" },
    choices = { opts.choices, "t", true },
    default = { opts.default, "n", true },
    type = { opts.type, "s", true },
    callback = { callback, "f" },
  })
  if not opts.choices then
    opts.choices = { "&OK" }
  end
  if not opts.default then
    opts.default = 1
  end
  if not opts.type then
    opts.type = "Generic"
  else
    opts.type = type_map[string.sub(opts.type, 1, 1)] or "Generic"
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(bufnr, "buflisted", false)
  vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
  local winid

  local function choose(idx)
    local cb = callback
    callback = function(_) end
    if winid then
      vim.api.nvim_win_close(winid, true)
    end
    cb(idx)
  end
  local function cancel()
    choose(0)
  end

  local clean_choices = {}
  local total_width = 0
  local choice_shortcut_idx = {}
  for i, choice in ipairs(opts.choices) do
    local idx = choice:find("&")
    local key
    if idx and idx < string.len(choice) then
      table.insert(clean_choices, choice:sub(1, idx - 1) .. choice:sub(idx + 1))
      key = choice:sub(idx + 1, idx + 1)
      table.insert(choice_shortcut_idx, idx)
    else
      key = choice:sub(1, 1)
      table.insert(clean_choices, choice)
      table.insert(choice_shortcut_idx, 1)
    end
    total_width = total_width + vim.api.nvim_strwidth(clean_choices[#clean_choices])
    vim.keymap.set("n", key:lower(), function()
      choose(i)
    end, { buffer = bufnr })
    if key:lower() ~= key:upper() then
      vim.keymap.set("n", key:upper(), function()
        choose(i)
      end, { buffer = bufnr })
    end
  end
  vim.keymap.set("n", "<C-c>", cancel, { buffer = bufnr })
  vim.keymap.set("n", "<Esc>", cancel, { buffer = bufnr })
  vim.keymap.set("n", "<CR>", function()
    choose(opts.default)
  end, { buffer = bufnr })

  local message = opts.message
  local icon = icons[opts.type]
  if icon then
    message = string.format("%s %s", icon, message)
  end
  local lines = vim.split(message, "\n")
  local highlights = { { string.format("OverseerConfirm%s", opts.type), #lines, 0, -1 } }
  table.insert(lines, "")

  local desired_width = 1
  for _, line in ipairs(lines) do
    local len = string.len(line)
    if len > desired_width then
      desired_width = len
    end
  end
  local width = layout.calculate_width(desired_width, config.confirm)

  create_letter_highlight()
  -- If all the options can fit on a single line, do that.
  if #clean_choices + total_width <= width then
    local hl_start = 0
    local pieces = {}
    local rem = width - total_width
    for i, choice in ipairs(clean_choices) do
      local col_start = hl_start + choice_shortcut_idx[i] - 1
      table.insert(pieces, choice)
      table.insert(highlights, { "OverseerConfirmShortcut", #lines + 1, col_start, col_start + 1 })
      hl_start = hl_start + vim.api.nvim_strwidth(choice)
      -- Calculate how much spacing to put between options
      local space = math.ceil(rem / (#clean_choices - i))
      rem = rem - space
      table.insert(pieces, string.rep(" ", space))
      hl_start = hl_start + space
    end
    table.insert(lines, table.concat(pieces, ""))
  else
    for i, choice in ipairs(clean_choices) do
      table.insert(lines, choice)
      local col_start = choice_shortcut_idx[i] - 1
      table.insert(highlights, { "OverseerConfirmShortcut", #lines, col_start, col_start + 1 })
    end
  end
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
  local ns = vim.api.nvim_create_namespace("confirm")
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(bufnr, ns, hl[1], hl[2] - 1, hl[3], hl[4])
  end

  local height = layout.calculate_height(#lines, config.confirm)
  winid = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    border = config.confirm.border,
    zindex = config.confirm.zindex,
    style = "minimal",
    width = width,
    height = height,
    col = math.floor((layout.get_editor_width() - width) / 2),
    row = math.floor((layout.get_editor_height() - height) / 2),
  })
  for k, v in pairs(config.confirm.win_opts) do
    vim.api.nvim_win_set_option(winid, k, v)
  end
  local win_hl = vim.api.nvim_win_get_option(winid, "winhighlight")
  local border_hl = string.format("FloatBorder:OverseerConfirmBorder%s", opts.type)
  win_hl = win_hl == "" and border_hl or string.format("%s,%s", win_hl, border_hl)
  vim.api.nvim_win_set_option(winid, "winhighlight", win_hl)

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = bufnr,
    callback = cancel,
    once = true,
    nested = true,
  })
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
end
