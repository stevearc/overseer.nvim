local util = require("overseer.util")
local M = {}

M.render_field = function(schema, prefix, name, value)
  if value == nil then
    value = ""
  end
  if type(value) == "table" then
    value = table.concat(value, " ")
  end

  return string.format("%s%s: %s", prefix, name, value)
end

M.validate_field = function(schema, value)
  local ptype = schema.type or "string"
  if value == nil then
    return schema.optional
  elseif ptype == "list" then
    return type(value) == "table" and vim.tbl_islist(value)
  elseif ptype == "number" then
    return type(value) == "number"
  elseif ptype == "bool" then
    return type(value) == "boolean"
  elseif ptype == "string" then
    return true
  else
    vim.notify(string.format("Unknown param type '%s'", ptype), vim.log.levels.WARN)
  end
end

M.parse_field = function(schema, prefix, name, line)
  local label = string.format("%s%s: ", prefix, name)
  if string.sub(line, 1, string.len(label)) ~= label then
    return false
  end
  local value = string.sub(line, string.len(label) + 1)
  return M.parse_value(schema, value)
end

M.parse_value = function(schema, value)
  if value == "" then
    return true, nil
  end
  if schema.type == "list" then
    -- TODO escaping? configurable delimiter? quoting?
    return true, vim.split(value, "%s+")
  elseif schema.type == "number" then
    local num = tonumber(value)
    -- If the number ends with '.' or '.0' don't parse it yet, because that will
    -- truncate it and cause problems for input.
    if num and not string.match(value, "%.$") and not string.match(value, "%.%d*0+$") then
      return true, num
    end
  elseif schema.type == "bool" then
    if string.match(value, "^ye?s?") or string.match(value, "^tr?u?e?") then
      return true, true
    elseif string.match(value, "^no?") or string.match(value, "^fa?l?s?e?") then
      return true, false
    end
  end
  return true, value
end

M.new_label = function(opts)
  opts = opts or {}
  vim.validate({
    text = { opts.text, "s" },
    align = { opts.align, "s", true },
    nofocus = { opts.nofocus, "b", true },
  })
  opts.align = opts.align or "left"
  return {
    adjust_cursor = function(self, cur)
      if opts.nofocus then
        return { cur[1] + 1, 1000 }
      end
    end,
    render = function(self, ctx)
      local width = vim.api.nvim_win_get_width(0)
      if opts.align == "left" then
        return opts.text
      elseif opts.align == "right" then
        local padding = width - string.len(opts.text)
        return string.rep(" ", padding) .. opts.text
      else
        local padding = math.floor((width - string.len(opts.text)) / 2)
        return string.rep(" ", padding) .. opts.text
      end
    end,
  }
end

M.new_input = function(opts, schema)
  vim.validate({
    id = { opts.id, "s" },
    label = { opts.label, "s" },
  })
  local label = opts.label
  if not schema.optional then
    label = "*" .. label
  end
  return {
    focused = false,
    ever_focused = false,
    render = function(self, ctx)
      local value = ctx.params[opts.id]
      return M.render_field(schema, "", label, value)
    end,
    set_focus = function(self, focus)
      if self.focused and not focus then
        self.ever_focused = true
      end
      self.focused = focus
    end,
    get_vtext = function(self, ctx)
      if schema.description then
        return schema.description, "Comment"
      end
    end,
    get_hl = function(self, ctx)
      if not self:is_valid(ctx.params) and (ctx.ever_submitted or self.ever_focused) then
        return "DiagnosticError", 0, string.len(label)
      end
    end,
    adjust_cursor = function(self, cur)
      if cur[2] < string.len(label) + 1 then
        return { cur[1], string.len(label) + 1 }
      end
    end,
    is_valid = function(self, params)
      local value = params[opts.id]
      return M.validate_field(schema, value)
    end,
    parse = function(self, line, params)
      local parsed, val = M.parse_field(schema, "", label, line)
      if parsed then
        params[opts.id] = val
      end
    end,
  }
end

M.open_form_win = function(bufnr, opts)
  opts = opts or {}
  vim.validate({
    autocmds = { opts.autocmds, "t", true },
    on_resize = { opts.on_resize, "f", true },
  })
  opts.autocmds = opts.autocmds or {}
  local function calc_layout()
    local max_width = vim.o.columns
    local max_height = vim.o.lines - vim.o.cmdheight
    local win_opts = {
      relative = "editor",
      border = "rounded",
      zindex = 150,
      width = math.min(max_width, 100),
      height = math.min(max_height, 10),
    }
    win_opts.col = math.floor((max_width - win_opts.width) / 2)
    win_opts.row = math.floor((max_height - win_opts.height) / 2)
    return win_opts
  end

  local winopt = calc_layout()
  winopt.style = "minimal"
  local winid = vim.api.nvim_open_win(bufnr, true, winopt)
  vim.api.nvim_win_set_option(winid, "winblend", 10)

  local function layout()
    vim.api.nvim_win_set_config(winid, calc_layout())
  end

  local winwidth = vim.api.nvim_win_get_width(winid)
  local function on_win_scrolled()
    local new_width = vim.api.nvim_win_get_width(winid)
    if winwidth ~= new_width then
      winwidth = new_width
      opts.on_resize()
    end
  end

  if opts.on_resize then
    table.insert(
      opts.autocmds,
      vim.api.nvim_create_autocmd("WinScrolled", {
        desc = "Rerender on window resize",
        pattern = tostring(winid),
        nested = true,
        callback = on_win_scrolled,
      })
    )
  end
  table.insert(
    opts.autocmds,
    vim.api.nvim_create_autocmd("VimResized", {
      desc = "Rerender on vim resize",
      nested = true,
      callback = layout,
    })
  )
  -- This is a little bit of a hack. We force the cursor to be *after the ': '
  -- of the fields, but if the user enters insert mode with "i", the cursor will
  -- now be before the space. If they type, the parsing will misbehave. So we
  -- detect that and just...nudge them forwards a bit.
  table.insert(
    opts.autocmds,
    vim.api.nvim_create_autocmd("InsertCharPre", {
      desc = "Move cursor to end of line when inserting",
      buffer = bufnr,
      nested = true,
      callback = function()
        local cur = vim.api.nvim_win_get_cursor(0)
        local lnum = cur[1]
        local line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, true)[1]
        local rem = string.sub(line, cur[2] + 1)
        if rem:match("%s+") then
          vim.api.nvim_win_set_cursor(0, { lnum, string.len(line) })
        end
      end,
    })
  )

  local function cleanup()
    for _, id in ipairs(opts.autocmds) do
      vim.api.nvim_del_autocmd(id)
    end
    util.leave_insert()
    vim.api.nvim_win_close(winid, true)
  end
  return cleanup
end

M.show = function(title, schema, params, callback)
  if vim.tbl_isempty(schema) then
    callback(params)
    return
  end

  local fields = {
    M.new_label({ text = title, align = "center", nofocus = true }),
  }
  local keys = vim.tbl_keys(schema)
  -- Sort the params by required, then if they have no value, then by name
  table.sort(keys, function(a, b)
    local aparam = schema[a]
    local bparam = schema[b]
    if (aparam.optional == true) ~= (bparam.optional == true) then
      return bparam.optional
    end
    local ahas_value = params[a] ~= nil or aparam.default ~= nil
    local bhas_value = params[b] ~= nil or bparam.default ~= nil
    if ahas_value ~= bhas_value then
      return not ahas_value
    end
    local aname = aparam.name or a
    local bname = bparam.name or b
    return aname < bname
  end)
  for _, k in ipairs(keys) do
    local param = schema[k]
    if params[k] == nil then
      params[k] = param.default
    end
    table.insert(fields, M.new_input({ id = k, label = param.name or k }, param))
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")

  local function line_len(lnum)
    return string.len(vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, true)[1])
  end

  local ns = vim.api.nvim_create_namespace("overseer")
  local ever_submitted = false
  local function on_cursor_move()
    local ctx = {
      params = params,
      ever_submitted = ever_submitted,
    }
    local cur = vim.api.nvim_win_get_cursor(0)
    local lnum = cur[1]
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    local field = fields[lnum]
    -- When we first enter the window the cursor may not have updated, and we
    -- can be off the end of the list
    if not field then
      return
    end
    -- This logic suuuuuucks but it works
    local original_cur = cur
    local new_cur = field:adjust_cursor(cur)
    while new_cur and (new_cur[1] ~= cur[1] or new_cur[2] ~= cur[2]) do
      if new_cur[1] > #fields then
        new_cur[1] = 1
      end
      cur = new_cur
      field = fields[new_cur[1]]
      new_cur = field:adjust_cursor(cur)
    end
    if cur and (cur[1] ~= original_cur[1] or cur[2] ~= original_cur[2]) then
      vim.api.nvim_win_set_cursor(0, cur)
    end

    for i, v in ipairs(fields) do
      if v.set_focus then
        v:set_focus(i == cur[1])
      end
      if v.get_hl then
        local group, col_start, col_end = v:get_hl(ctx)
        if group then
          vim.api.nvim_buf_add_highlight(bufnr, ns, group, i - 1, col_start, col_end)
        end
      end
    end

    if field.get_vtext then
      local text, hl = field:get_vtext(ctx)
      if text then
        vim.api.nvim_buf_set_extmark(bufnr, ns, cur[1] - 1, 0, {
          virt_text = { { text, hl } },
        })
      end
    end
  end

  local function render()
    local ctx = {
      params = params,
    }
    local lines = {}
    for _, field in ipairs(fields) do
      table.insert(lines, field:render(ctx))
    end
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
    on_cursor_move()
  end

  render()

  local autocmds = {}
  local cleanup = M.open_form_win(bufnr, { autocmds = autocmds, on_resize = render })
  vim.api.nvim_buf_set_option(bufnr, "filetype", "OverseerForm")

  local function parse()
    local buflines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
    if #buflines ~= #fields then
      render()
      return
    end
    for i, line in ipairs(buflines) do
      local field = fields[i]
      if field.parse then
        field:parse(line, params)
      end
    end
    render()
  end

  table.insert(
    autocmds,
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
      desc = "Update form on change",
      buffer = bufnr,
      nested = true,
      callback = parse,
    })
  )
  table.insert(
    autocmds,
    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
      desc = "Update form on move cursor",
      buffer = bufnr,
      nested = true,
      callback = on_cursor_move,
    })
  )
  local function cancel()
    cleanup()
    callback(nil)
  end

  local function submit()
    ever_submitted = true
    for i, field in ipairs(fields) do
      if field.is_valid and not field:is_valid(params) then
        if vim.api.nvim_win_get_cursor(0)[1] ~= i then
          vim.api.nvim_win_set_cursor(0, { i, line_len(i) })
        else
          on_cursor_move()
        end
        return
      end
    end
    cleanup()
    callback(params)
  end

  local function next_field()
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    if lnum == #fields then
      return false
    else
      vim.api.nvim_win_set_cursor(0, { lnum + 1, line_len(lnum + 1) })
      return true
    end
  end

  local function prev_field()
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    if lnum == 1 then
      return false
    else
      vim.api.nvim_win_set_cursor(0, { lnum - 1, line_len(lnum - 1) })
    end
  end

  local function confirm()
    if not next_field() then
      submit()
    end
  end

  vim.keymap.set({ "n", "i" }, "<CR>", confirm, { buffer = bufnr })
  vim.keymap.set({ "n", "i" }, "<C-r>", submit, { buffer = bufnr })
  vim.keymap.set({ "n", "i" }, "<C-s>", submit, { buffer = bufnr })
  vim.keymap.set({ "n", "i" }, "<Tab>", next_field, { buffer = bufnr })
  vim.keymap.set({ "n", "i" }, "<S-Tab>", prev_field, { buffer = bufnr })
  -- Some shenanigans to make <C-u> behave the way we expect
  vim.keymap.set("i", "<C-u>", function()
    local cur = vim.api.nvim_win_get_cursor(0)
    local field = fields[cur[1]]
    if field and field.parse_value then
      local line = vim.api.nvim_buf_get_lines(bufnr, cur[1] - 1, cur[1], true)[1]
      local rem = string.sub(line, cur[2] + 1)
      field:parse_value(rem, params)
      vim.api.nvim_win_set_cursor(0, { cur[1], 0 })
      render()
    end
  end, { buffer = bufnr })

  table.insert(
    autocmds,
    vim.api.nvim_create_autocmd("BufLeave", {
      desc = "Close float on BufLeave",
      buffer = bufnr,
      once = true,
      nested = true,
      callback = cancel,
    })
  )
  vim.defer_fn(function()
    vim.cmd([[startinsert!]])
  end, 5)
end

return M
