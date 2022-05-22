local form = require("overseer.form")
local util = require("overseer.util")

local M = {}

M.open = function(title, schema, params, callback)
  if vim.tbl_isempty(schema) then
    callback(params)
    return
  end

  local fields_focused = {}
  local fields_ever_focused = {}
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
  for k, v in pairs(schema) do
    if params[k] == nil then
      params[k] = v.default
    end
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")

  local function line_len(lnum)
    return string.len(vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, true)[1])
  end
  local function parse_line(line)
    return line:match("^%*?([^%s]+): ?(.*)$")
  end

  local ns = vim.api.nvim_create_namespace("overseer")
  local ever_submitted = false
  local function on_cursor_move()
    local cur = vim.api.nvim_win_get_cursor(0)
    local original_cur = vim.deepcopy(cur)
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    local num_lines = vim.api.nvim_buf_line_count(bufnr)

    -- Top line is title
    if cur[1] == 1 and num_lines > 1 then
      cur[1] = 2
    end

    local buflines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
    for i, line in ipairs(buflines) do
      local name, text = parse_line(line)
      if name and schema[name] then
        local focused = i == cur[1]
        local name_end = string.len(line) - string.len(text)
        -- Move cursor to input section of field
        if focused then
          if cur[2] < name_end then
            cur[2] = name_end
          end
          if schema[name].description then
            vim.api.nvim_buf_set_extmark(bufnr, ns, cur[1] - 1, 0, {
              virt_text = { { schema[name].description, "Comment" } },
            })
          end
        end

        -- Track historical focus for showing errors
        if focused then
          fields_focused[name] = true
        elseif fields_focused[name] then
          fields_ever_focused[name] = true
        end

        local group = "OverseerField"
        if
          (fields_ever_focused[name] or ever_submitted)
          and not form.validate_field(schema[name], params[name])
        then
          group = "DiagnosticError"
        end
        vim.api.nvim_buf_add_highlight(bufnr, ns, group, i - 1, 0, name_end)
      end
    end

    if cur and (cur[1] ~= original_cur[1] or cur[2] ~= original_cur[2]) then
      vim.api.nvim_win_set_cursor(0, cur)
    end
  end

  local title_ns = vim.api.nvim_create_namespace("overseer_title")
  local function render()
    local lines = { util.align(title, vim.api.nvim_win_get_width(0), "center") }
    local highlights = { { "OverseerTask", 1, 0, -1 } }
    for _, name in ipairs(keys) do
      local prefix = schema[name].optional and "" or "*"
      table.insert(lines, form.render_field(schema[name], prefix, name, params[name]))
    end
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
    util.add_highlights(bufnr, title_ns, highlights)
    on_cursor_move()
  end

  local autocmds = {}
  local cleanup, layout = form.open_form_win(bufnr, {
    autocmds = autocmds,
    on_resize = render,
    get_preferred_dim = function()
      local max_len = 1
      for k, v in pairs(schema) do
        local len = string.len(form.render_field(v, " ", k, params[k]))
        if v.description then
          len = len + string.len(v.description)
        end
        if len > max_len then
          max_len = len
        end
      end
      return max_len, #keys + 1
    end,
  })
  vim.api.nvim_buf_set_option(bufnr, "filetype", "OverseerForm")

  render()

  local function parse()
    local buflines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
    for _, line in ipairs(buflines) do
      local name, text = parse_line(line)
      if name and schema[name] then
        local parsed, value = form.parse_value(schema[name], text)
        if parsed then
          params[name] = value
        end
      end
    end
    layout()
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
    for i, name in pairs(keys) do
      if not form.validate_field(schema[name], params[name]) then
        local lnum = i + 1
        if vim.api.nvim_win_get_cursor(0)[1] ~= lnum then
          vim.api.nvim_win_set_cursor(0, { lnum, line_len(lnum) })
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
    if lnum == vim.api.nvim_buf_line_count(0) then
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
    local line = vim.api.nvim_buf_get_lines(bufnr, cur[1] - 1, cur[1], true)[1]
    local name = line:match("^[^%s]+: ")
    if name then
      local rem = string.sub(line, cur[2] + 1)
      vim.api.nvim_buf_set_lines(
        bufnr,
        cur[1] - 1,
        cur[1],
        true,
        { string.format("%s%s", name, rem) }
      )
      parse()
      vim.api.nvim_win_set_cursor(0, { cur[1], 0 })
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
