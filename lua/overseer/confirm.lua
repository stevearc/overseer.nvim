local config = require("overseer.config")
local layout = require("overseer.layout")

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
  -- TODO this doesn't do anything yet
  if not opts.type then
    opts.type = "G"
  else
    opts.type = string.sub(opts.type, 1, 2)
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
    vim.keymap.set("n", key:lower(), function()
      choose(i)
    end, { buffer = bufnr })
    vim.keymap.set("n", key:upper(), function()
      choose(i)
    end, { buffer = bufnr })
  end
  vim.keymap.set("n", "<C-c>", cancel, { buffer = bufnr })
  vim.keymap.set("n", "<Esc>", cancel, { buffer = bufnr })
  -- TODO also allow <CR> to select an option

  local lines = vim.split(opts.message, "\n")
  local highlights = {}
  table.insert(lines, "")

  -- TODO maybe detect if this can fit on a single line
  for i, choice in ipairs(clean_choices) do
    table.insert(lines, choice)
    table.insert(highlights, { "Keyword", #lines, choice_shortcut_idx[i] })
  end
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
  local ns = vim.api.nvim_create_namespace("confirm")
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(bufnr, ns, hl[1], hl[2] - 1, hl[3] - 1, hl[3])
  end

  local desired_width = 1
  for _, line in ipairs(lines) do
    local len = string.len(line)
    if len > desired_width then
      desired_width = len
    end
  end

  local width = layout.calculate_width(desired_width, config.form)
  local height = layout.calculate_height(#lines, config.form)
  winid = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    border = "rounded",
    style = "minimal",
    width = width,
    height = height,
    col = math.floor((layout.get_editor_width() - width) / 2),
    row = math.floor((layout.get_editor_height() - height) / 2),
  })

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = bufnr,
    callback = cancel,
    once = true,
    nested = true,
  })
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
end
