local binding_util = require("overseer.binding_util")
local config = require("overseer.config")
local form_utils = require("overseer.form.utils")
local util = require("overseer.util")

local M = {}

local bindings = {
  {
    desc = "Show default key bindings",
    plug = "<Plug>OverseerTaskEditor:ShowHelp",
    rhs = function(builder)
      builder.disable_close_on_leave = true
      binding_util.show_bindings("OverseerTaskEditor:")
    end,
  },
  {
    desc = "Move to next form field, or submit the task if on the last field",
    plug = "<Plug>OverseerTaskEditor:NextOrSubmit",
    rhs = function(builder)
      builder:confirm()
    end,
  },
  {
    desc = "Submit the task",
    plug = "<Plug>OverseerTaskEditor:Submit",
    rhs = function(builder)
      builder:submit()
    end,
  },
  {
    desc = "Cancel the task",
    plug = "<Plug>OverseerTaskEditor:Cancel",
    rhs = function(builder)
      builder:cancel()
    end,
  },
  {
    desc = "Move to the next field",
    plug = "<Plug>OverseerTaskEditor:Next",
    rhs = function(builder)
      builder:next_field()
    end,
  },
  {
    desc = "Move to the previous field",
    plug = "<Plug>OverseerTaskEditor:Prev",
    rhs = function(builder)
      builder:prev_field()
    end,
  },
}

local Builder = {}

local function line_len(bufnr, lnum)
  return string.len(vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, true)[1])
end
local function parse_line(line)
  return line:match("^%*?([^%s]+): ?(.*)$")
end

function Builder.new(title, schema, params, callback)
  -- Filter out the opaque types
  local keys = vim.tbl_filter(function(key)
    return schema[key].type ~= "opaque"
  end, vim.tbl_keys(schema))
  -- Sort the params by required, then if they have no value, then by name
  table.sort(keys, function(a, b)
    local aparam = schema[a]
    local bparam = schema[b]
    if aparam.order then
      if not bparam.order then
        return true
      elseif aparam.order ~= bparam.order then
        return aparam.order < bparam.order
      end
    elseif bparam.order then
      return false
    end
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
      params[k] = vim.deepcopy(v.default)
    end
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(bufnr, "buftype", "acwrite")
  vim.api.nvim_buf_set_name(bufnr, "Overseer task builder")

  local autocmds = {}
  local builder
  local cleanup, layout = form_utils.open_form_win(bufnr, {
    autocmds = autocmds,
    on_resize = function()
      builder:render()
    end,
    get_preferred_dim = function()
      local max_len = 1
      for k, v in pairs(schema) do
        local len = string.len(form_utils.render_field(v, " ", k, params[k]))
        if v.desc then
          len = len + 1 + string.len(v.desc)
        end
        if len > max_len then
          max_len = len
        end
      end
      return max_len, #keys + 1
    end,
  })
  table.insert(
    autocmds,
    vim.api.nvim_create_autocmd("BufEnter", {
      desc = "Reset disable_close_on_leave",
      buffer = bufnr,
      nested = true,
      callback = function()
        builder.disable_close_on_leave = false
      end,
    })
  )
  vim.api.nvim_buf_set_option(bufnr, "filetype", "OverseerForm")

  builder = setmetatable({
    disable_close_on_leave = false,
    cur_line = nil,
    title = title,
    schema_keys = keys,
    schema = schema,
    params = params,
    callback = callback,
    cleanup = cleanup,
    layout = layout,
    autocmds = autocmds,
    bufnr = bufnr,
    fields_focused = {},
    fields_ever_focused = {},
    ever_submitted = false,
  }, { __index = Builder })
  builder:init_autocmds()
  builder:init_keymaps()
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    desc = "Submit on buffer write",
    buffer = bufnr,
    callback = function()
      builder:submit()
    end,
  })
  return builder
end

function Builder:init_autocmds()
  table.insert(
    self.autocmds,
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
      desc = "Update form on change",
      buffer = self.bufnr,
      nested = true,
      callback = function()
        local lnum = vim.api.nvim_win_get_cursor(0)[1]
        local line = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, true)[1]
        self.cur_line = { lnum, line }
        self:parse()
      end,
    })
  )
  table.insert(
    self.autocmds,
    vim.api.nvim_create_autocmd("InsertLeave", {
      desc = "Rerender form",
      buffer = self.bufnr,
      callback = function()
        self:render()
      end,
    })
  )
  table.insert(
    self.autocmds,
    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
      desc = "Update form on move cursor",
      buffer = self.bufnr,
      nested = true,
      callback = function()
        self:on_cursor_move()
      end,
    })
  )
  table.insert(
    self.autocmds,
    vim.api.nvim_create_autocmd("BufLeave", {
      desc = "Close float on BufLeave",
      buffer = self.bufnr,
      nested = true,
      callback = function()
        if not self.disable_close_on_leave then
          self:cancel()
        end
      end,
    })
  )
end

function Builder:init_keymaps()
  binding_util.create_plug_bindings(self.bufnr, bindings, self)
  for mode, user_bindings in pairs(config.task_editor.bindings) do
    binding_util.create_bindings_to_plug(self.bufnr, mode, user_bindings, "OverseerTaskEditor:")
  end

  -- Some shenanigans to make <C-u> behave the way we expect
  vim.keymap.set("i", "<C-u>", function()
    local cur = vim.api.nvim_win_get_cursor(0)
    local line = vim.api.nvim_buf_get_lines(self.bufnr, cur[1] - 1, cur[1], true)[1]
    local name = line:match("^[^%s]+: ")
    if name then
      local rem = string.sub(line, cur[2] + 1)
      vim.api.nvim_buf_set_lines(
        self.bufnr,
        cur[1] - 1,
        cur[1],
        true,
        { string.format("%s%s", name, rem) }
      )
      self:parse()
      vim.api.nvim_win_set_cursor(0, { cur[1], 0 })
    end
  end, { buffer = self.bufnr })
end

function Builder:render()
  local title_ns = vim.api.nvim_create_namespace("overseer_title")
  vim.api.nvim_buf_clear_namespace(self.bufnr, title_ns, 0, -1)
  local lines = { util.align(self.title, vim.api.nvim_win_get_width(0), "center") }
  local highlights = { { "OverseerTask", 1, 0, -1 } }
  local extmarks = {}
  for _, name in ipairs(self.schema_keys) do
    local prefix = self.schema[name].optional and "" or "*"
    local schema = self.schema[name]
    table.insert(lines, form_utils.render_field(schema, prefix, name, self.params[name]))
    if schema.conceal then
      local start_col = (prefix .. name):len() + 1
      local length = #lines[#lines] - start_col
      -- Because conceallevel replaces every concealed _block_ with a single character, we have to
      -- create 1-width conceal blocks, one for each character
      for i = 1, length do
        table.insert(extmarks, {
          #lines - 1,
          start_col + i,
          {
            right_gravity = false,
            strict = false,
            conceal = "*",
            end_col = start_col + i + 2,
          },
        })
      end
    end
  end
  if self.cur_line and vim.api.nvim_get_mode().mode == "i" then
    local lnum, line = unpack(self.cur_line)
    lines[lnum] = line
  end
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, true, lines)
  util.add_highlights(self.bufnr, title_ns, highlights)
  for _, mark in ipairs(extmarks) do
    local line, col, opts = unpack(mark)
    vim.api.nvim_buf_set_extmark(self.bufnr, title_ns, line, col, opts)
  end
  self:on_cursor_move()
end

function Builder:on_cursor_move()
  local cur = vim.api.nvim_win_get_cursor(0)
  if self.cur_line and self.cur_line[1] ~= cur[1] then
    self.cur_line = nil
    self:render()
    return
  end
  local original_cur = vim.deepcopy(cur)
  local ns = vim.api.nvim_create_namespace("overseer")
  vim.api.nvim_buf_clear_namespace(self.bufnr, ns, 0, -1)
  local num_lines = vim.api.nvim_buf_line_count(self.bufnr)

  -- Top line is title
  if cur[1] == 1 and num_lines > 1 then
    cur[1] = 2
  end

  local buflines = vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, true)
  for i, line in ipairs(buflines) do
    local name, text = parse_line(line)
    if name and self.schema[name] then
      local focused = i == cur[1]
      local name_end = string.len(line) - string.len(text)
      -- Move cursor to input section of field
      if focused then
        if cur[2] < name_end then
          cur[2] = name_end
        end
        local schema = self.schema[name]
        local vtext = {}
        if schema.type == "namedEnum" then
          local value = schema.choices[text]
          if value then
            table.insert(vtext, { string.format("[%s] ", value), "Comment" })
          end
        end
        if schema.desc then
          table.insert(vtext, { schema.desc, "Comment" })
        end
        if not vim.tbl_isempty(vtext) then
          vim.api.nvim_buf_set_extmark(self.bufnr, ns, cur[1] - 1, 0, {
            virt_text = vtext,
          })
        end
        local completion_schema = schema.subtype and schema.subtype or schema
        local choices = (completion_schema.type == "boolean" and { "true", "false" })
          or (completion_schema.type == "namedEnum" and vim.tbl_keys(completion_schema.choices))
          or completion_schema.choices
        vim.api.nvim_buf_set_var(0, "overseer_choices", choices)
      end

      -- Track historical focus for showing errors
      if focused then
        self.fields_focused[name] = true
      elseif self.fields_focused[name] then
        self.fields_ever_focused[name] = true
      end

      local group = "OverseerField"
      if
        (self.fields_ever_focused[name] or self.ever_submitted)
        and not form_utils.validate_field(self.schema[name], self.params[name])
      then
        group = "DiagnosticError"
      end
      vim.api.nvim_buf_add_highlight(self.bufnr, ns, group, i - 1, 0, name_end)
    end
  end

  if cur and (cur[1] ~= original_cur[1] or cur[2] ~= original_cur[2]) then
    vim.api.nvim_win_set_cursor(0, cur)
  end
end

function Builder:parse()
  local buflines = vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, true)
  for _, line in ipairs(buflines) do
    local name, text = parse_line(line)
    if name and self.schema[name] then
      local parsed, value = form_utils.parse_value(self.schema[name], text)
      if parsed then
        self.params[name] = value
      end
    end
  end
  self.layout()
  self:render()
end

function Builder:cancel()
  self.cleanup()
  self.callback(nil)
end

function Builder:submit()
  self.ever_submitted = true
  for i, name in pairs(self.schema_keys) do
    if not form_utils.validate_field(self.schema[name], self.params[name]) then
      local lnum = i + 1
      if vim.api.nvim_win_get_cursor(0)[1] ~= lnum then
        vim.api.nvim_win_set_cursor(0, { lnum, line_len(self.bufnr, lnum) })
      else
        self:on_cursor_move()
      end
      return
    end
  end
  self.cleanup()
  self.callback(self.params)
end

function Builder:next_field()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  if lnum == vim.api.nvim_buf_line_count(0) then
    return false
  else
    vim.api.nvim_win_set_cursor(0, { lnum + 1, line_len(self.bufnr, lnum + 1) })
    return true
  end
end

function Builder:prev_field()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  if lnum == 1 then
    return false
  else
    vim.api.nvim_win_set_cursor(0, { lnum - 1, line_len(self.bufnr, lnum - 1) })
  end
end

function Builder:confirm()
  if not self:next_field() then
    self:submit()
  end
end

M.open = function(title, schema, params, callback)
  form_utils.validate_params(schema)
  if vim.tbl_isempty(schema) then
    callback(params)
    return
  end
  local builder = Builder.new(title, schema, params, callback)
  builder:render()

  vim.defer_fn(function()
    vim.cmd([[startinsert!]])
  end, 5)
end

return M
