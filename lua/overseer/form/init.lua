local form_utils = require("overseer.form.utils")
local util = require("overseer.util")

local M = {}

local Form = {}

local function line_len(bufnr, lnum)
  return string.len(vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, true)[1])
end

function Form.new(title, schema, params, callback)
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
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].buftype = "acwrite"
  vim.api.nvim_buf_set_name(bufnr, "Overseer form")

  local form
  local cleanup, layout = form_utils.open_form_win(bufnr, {
    on_resize = function()
      form:render()
    end,
    get_preferred_dim = function()
      local max_len = 1
      for k, v in pairs(schema) do
        local len = string.len(k .. tostring(form_utils.render_value(v, params[k]))) + 2
        if v.required then
          len = len + 1
        end
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
  vim.api.nvim_create_autocmd("BufEnter", {
    desc = "Reset disable_close_on_leave",
    buffer = bufnr,
    nested = true,
    callback = function()
      form.disable_close_on_leave = false
    end,
  })
  vim.bo[bufnr].filetype = "OverseerForm"
  local called_callback = false
  local function cb(...)
    if not called_callback then
      callback(...)
      called_callback = true
    end
  end

  form = setmetatable({
    disable_close_on_leave = false,
    cur_line = nil,
    title = title,
    schema_keys = keys,
    schema = schema,
    params = params,
    callback = cb,
    cleanup = cleanup,
    layout = layout,
    bufnr = bufnr,
    fields_focused = {},
    fields_ever_focused = {},
    ext_id_to_schema_field_name = {},
    ever_submitted = false,
  }, { __index = Form })
  form:init_autocmds()

  vim.keymap.set({ "i", "n" }, "<C-c>", function()
    form:cancel()
  end, { buffer = bufnr })
  vim.keymap.set("n", "q", function()
    form:cancel()
  end, { buffer = bufnr })
  vim.keymap.set("i", "<CR>", function()
    form:confirm()
  end, { buffer = bufnr })
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    desc = "Submit on buffer write",
    buffer = bufnr,
    callback = function()
      form:submit()
    end,
  })
  return form
end

function Form:init_autocmds()
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    desc = "Update form on change",
    buffer = self.bufnr,
    nested = true,
    callback = function()
      local lnum = vim.api.nvim_win_get_cursor(0)[1]
      local line = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, true)[1]
      self.cur_line = { lnum, line }
      self:parse()
      vim.bo[self.bufnr].modified = false
    end,
  })
  vim.api.nvim_create_autocmd("InsertLeave", {
    desc = "Rerender form",
    buffer = self.bufnr,
    callback = function()
      self:render()
    end,
  })
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    desc = "Update form on move cursor",
    buffer = self.bufnr,
    nested = true,
    callback = function()
      self:on_cursor_move()
    end,
  })
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
end

function Form:render()
  local title_ns = vim.api.nvim_create_namespace("overseer_title")
  vim.api.nvim_buf_clear_namespace(self.bufnr, title_ns, 0, -1)
  local lines = { util.align(self.title, vim.api.nvim_win_get_width(0), "center") }
  local extmarks = {}
  table.insert(extmarks, {
    0,
    0,
    { hl_group = "OverseerTask", end_col = #lines[1] },
  })
  local extmark_idx_to_name = {}
  for _, name in ipairs(self.schema_keys) do
    local prefix = self.schema[name].optional and "" or "*"
    local schema = self.schema[name]
    local field_hl = "OverseerField"
    if
      (self.fields_ever_focused[name] or self.ever_submitted)
      and not form_utils.validate_field(self.schema[name], self.params[name])
    then
      field_hl = "DiagnosticError"
    end
    table.insert(extmarks, {
      #lines,
      0,
      {
        virt_text = { { prefix, "NormalFloat" }, { name, field_hl }, { ": ", "NormalFloat" } },
        virt_text_pos = "inline",
        undo_restore = false,
        invalidate = true,
      },
    })
    extmark_idx_to_name[#extmarks] = name
    table.insert(lines, tostring(form_utils.render_value(schema, self.params[name])))
    if schema.conceal then
      local length = #lines[#lines]
      -- Because conceallevel replaces every concealed _block_ with a single character, we have to
      -- create 1-width conceal blocks, one for each character
      for i = 0, length do
        table.insert(extmarks, {
          #lines - 1,
          i,
          {
            undo_restore = false,
            strict = false,
            conceal = "*",
            end_col = i + 1,
          },
        })
      end
    end
  end
  if self.cur_line and vim.api.nvim_get_mode().mode == "i" then
    local lnum = self.cur_line[1]
    local line = self.cur_line[2]
    lines[lnum] = line
  end
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, true, lines)
  self.ext_id_to_schema_field_name = {}
  for i, mark in ipairs(extmarks) do
    local line, col, opts = unpack(mark)
    local ext_id = vim.api.nvim_buf_set_extmark(self.bufnr, title_ns, line, col, opts)
    self.ext_id_to_schema_field_name[ext_id] = extmark_idx_to_name[i]
  end
  self:on_cursor_move()
end

function Form:on_cursor_move()
  local cur = vim.api.nvim_win_get_cursor(0)
  if self.cur_line and self.cur_line[1] ~= cur[1] then
    self.cur_line = nil
    self:render()
    return
  end
  local ns = vim.api.nvim_create_namespace("overseer")
  vim.api.nvim_buf_clear_namespace(self.bufnr, ns, 0, -1)
  local num_lines = vim.api.nvim_buf_line_count(self.bufnr)

  -- Top line is title
  if cur[1] == 1 and num_lines > 1 then
    vim.schedule_wrap(vim.api.nvim_win_set_cursor)(0, { 2, 0 })
    return
  end

  local buflines = vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, true)
  local lnum_to_field_name = self:get_lnum_to_field_name()
  for i, line in ipairs(buflines) do
    local name = lnum_to_field_name[i]
    if name and self.schema[name] then
      local focused = i == cur[1]
      if focused then
        local schema = self.schema[name]
        local vtext = {}
        if schema.type == "namedEnum" then
          local value = schema.choices[line]
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
    end
  end
end

---@private
---@return table<integer, string>
function Form:get_lnum_to_field_name()
  local title_ns = vim.api.nvim_create_namespace("overseer_title")
  local extmarks =
    vim.api.nvim_buf_get_extmarks(self.bufnr, title_ns, 0, -1, { type = "virt_text" })
  local lnum_to_field_name = {}
  for _, extmark in ipairs(extmarks) do
    local ext_id, row = extmark[1], extmark[2]
    local field_name = self.ext_id_to_schema_field_name[ext_id]
    if field_name then
      lnum_to_field_name[row + 1] = field_name
    end
  end
  return lnum_to_field_name
end

function Form:parse()
  local buflines = vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, true)
  local lnum_to_field_name = self:get_lnum_to_field_name()
  for i, line in ipairs(buflines) do
    local name = lnum_to_field_name[i]
    if name and self.schema[name] then
      local parsed, value = form_utils.parse_value(self.schema[name], line)
      if parsed then
        self.params[name] = value
      end
    end
  end
  self.layout()
  self:render()
end

function Form:cancel()
  self.callback(nil)
  self.cleanup()
end

function Form:submit()
  local first_submit = not self.ever_submitted
  self.ever_submitted = true
  for i, name in pairs(self.schema_keys) do
    if not form_utils.validate_field(self.schema[name], self.params[name]) then
      if first_submit then
        self:render()
      end
      local lnum = i + 1
      if vim.api.nvim_win_get_cursor(0)[1] ~= lnum then
        vim.api.nvim_win_set_cursor(0, { lnum, line_len(self.bufnr, lnum) })
      else
        self:on_cursor_move()
      end
      return
    end
  end
  self.callback(self.params)
  self.cleanup()
end

function Form:next_field()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  if lnum == vim.api.nvim_buf_line_count(0) then
    return false
  else
    vim.api.nvim_win_set_cursor(0, { lnum + 1, line_len(self.bufnr, lnum + 1) })
    return true
  end
end

function Form:prev_field()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  if lnum == 1 then
    return false
  else
    vim.api.nvim_win_set_cursor(0, { lnum - 1, line_len(self.bufnr, lnum - 1) })
  end
end

function Form:confirm()
  if not self:next_field() then
    self:submit()
  end
end

---@generic T: table
---@param title string
---@param schema table
---@param params T
---@param callback fun(params: nil|T)
M.open = function(title, schema, params, callback)
  form_utils.validate_params(schema)
  if vim.tbl_isempty(schema) then
    callback(params)
    return
  end
  local form = Form.new(title, schema, params, callback)
  form:render()

  vim.defer_fn(function()
    vim.cmd([[startinsert!]])
  end, 5)
end

return M
