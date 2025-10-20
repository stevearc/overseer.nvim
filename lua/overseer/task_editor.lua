local component = require("overseer.component")
local form_utils = require("overseer.form.utils")
local util = require("overseer.util")
local M = {}

local task_editable_params = { "cmd", "cwd" }
---@type overseer.Params
local task_builtin_params = {
  -- It's kind of a hack to specify a delimiter without type = 'list'. This is
  -- so the task editor displays nicely if the value is a list OR a string
  cmd = { delimiter = " " },
  cwd = {
    optional = true,
  },
}

---@class overseer.TaskEditor
---@field cur_line? {[1]: number, [2]: string}
---@field bufnr integer
---@field private components overseer.ComponentDefinition[]
---@field private ext_id_to_comp_idx_and_schema_field_name table<integer, {[1]: integer?, [2]: string?}>
---@field private task overseer.Task
---@field private task_data table<string, any>
---@field private callback fun(task?: overseer.Task)
---@field layout fun()
---@field cleanup fun()
local Editor = {}

function Editor.new(task, task_cb)
  -- Make sure the task doesn't get disposed while we're editing it
  task:inc_reference()
  local function callback(...)
    task:dec_reference()
    if task_cb then
      task_cb(...)
    end
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].buftype = "acwrite"
  vim.api.nvim_buf_set_name(bufnr, "Overseer task editor")

  local components = {}
  for _, comp in ipairs(task.components) do
    table.insert(components, vim.deepcopy(comp.params))
  end
  local task_data = {}
  for k in pairs(task_builtin_params) do
    task_data[k] = vim.deepcopy(task[k])
  end

  local cleanup, layout = form_utils.open_form_win(bufnr, {})
  vim.bo[bufnr].filetype = "OverseerForm"
  local self = setmetatable({
    cur_line = nil,
    task = task,
    callback = callback,
    bufnr = bufnr,
    components = components,
    task_name = task.name,
    task_data = task_data,
    disable_close_on_leave = false,
    ext_id_to_comp_idx_and_schema_field_name = {},
    layout = layout,
    cleanup = cleanup,
  }, { __index = Editor })

  vim.keymap.set({ "i", "n" }, "<C-c>", function()
    self:cancel()
  end, { buffer = bufnr })
  vim.keymap.set("n", "q", function()
    self:cancel()
  end, { buffer = bufnr })
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    desc = "Submit on buffer write",
    buffer = bufnr,
    callback = function()
      self:submit()
    end,
  })

  vim.api.nvim_create_autocmd("BufLeave", {
    desc = "Close float on BufLeave",
    buffer = bufnr,
    nested = true,
    callback = function()
      if not self.disable_close_on_leave then
        self:cancel()
      end
    end,
  })
  vim.api.nvim_create_autocmd("BufEnter", {
    desc = "Reset disable_close_on_leave",
    buffer = bufnr,
    nested = true,
    callback = function()
      self.disable_close_on_leave = false
    end,
  })
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    desc = "Update form on change",
    buffer = bufnr,
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
    buffer = bufnr,
    callback = function()
      self:render()
    end,
  })
  vim.api.nvim_create_autocmd({ "CursorMoved" }, {
    desc = "Update form on move cursor",
    buffer = bufnr,
    nested = true,
    callback = function()
      self:on_cursor_move()
    end,
  })
  return self
end

---@private
---@return table<integer, {[1]: integer?, [2]: string}>
function Editor:get_lnum_to_comp_idx_and_field()
  local ns = vim.api.nvim_create_namespace("overseer")
  local extmarks = vim.api.nvim_buf_get_extmarks(self.bufnr, ns, 0, -1, { type = "virt_text" })
  local lnum_to_field_name = {}
  for _, extmark in ipairs(extmarks) do
    local ext_id, row = extmark[1], extmark[2]
    local comp_and_field = self.ext_id_to_comp_idx_and_schema_field_name[ext_id]
    if comp_and_field then
      lnum_to_field_name[row + 1] = comp_and_field
    end
  end
  return lnum_to_field_name
end

function Editor:on_cursor_move()
  if vim.api.nvim_get_mode().mode == "i" then
    return
  end
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  if self.cur_line and self.cur_line[1] ~= lnum then
    self.cur_line = nil
    self:render()
    return
  end
  local vtext_ns = vim.api.nvim_create_namespace("overseer_vtext")
  vim.api.nvim_buf_clear_namespace(self.bufnr, vtext_ns, 0, -1)
  local lnum_to_comp_and_field = self:get_lnum_to_comp_idx_and_field()

  local comp_and_field = lnum_to_comp_and_field[lnum]
  if not comp_and_field then
    return
  end
  local comp_idx, field_name = comp_and_field[1], comp_and_field[2]

  if comp_idx and field_name then
    local comp = assert(component.get(self.components[comp_idx][1]))
    local schema = comp.params[field_name]
    if schema.desc then
      vim.api.nvim_buf_set_extmark(self.bufnr, vtext_ns, lnum - 1, 0, {
        virt_text = { { schema.desc, "Comment" } },
      })
    end
    local completion_schema = schema.subtype and schema.subtype or schema
    local choices = completion_schema.type == "boolean" and { "true", "false" }
      or completion_schema.choices
    vim.api.nvim_buf_set_var(0, "overseer_choices", choices)
  end
end

function Editor:render()
  local ns = vim.api.nvim_create_namespace("overseer")
  vim.api.nvim_buf_clear_namespace(self.bufnr, ns, 0, -1)
  local lines = { self.task_name }
  local ext_idx_to_comp_and_schema_field_name = {}
  local extmarks = {}
  table.insert(extmarks, {
    1,
    0,
    { hl_group = "OverseerTask", end_col = #lines[1] },
  })

  for _, k in ipairs(task_editable_params) do
    local schema = task_builtin_params[k]
    local value = self.task_data[k]
    table.insert(lines, tostring(form_utils.render_value(schema, value)))
    local hl = form_utils.validate_field(schema, value) and "OverseerField" or "DiagnosticError"
    table.insert(extmarks, {
      #lines,
      0,
      {
        virt_text = { { k, hl }, { ": ", "NormalFloat" } },
        virt_text_pos = "inline",
        undo_restore = false,
        invalidate = true,
      },
    })
    ext_idx_to_comp_and_schema_field_name[#extmarks] = { nil, k }
  end

  for i, params in ipairs(self.components) do
    local comp = assert(component.get(params[1]))
    table.insert(lines, "")
    local desc
    if comp.desc then
      desc = { string.format(" (%s)", comp.desc), "Comment" }
    end
    table.insert(extmarks, {
      #lines,
      0,
      {
        virt_text = { { comp.name, "OverseerComponent" }, desc },
        virt_text_pos = "overlay",
        invalidate = true,
        undo_restore = false,
      },
    })
    ext_idx_to_comp_and_schema_field_name[#extmarks] = { i, nil }

    local schema = comp.params
    if schema then
      for k, param_schema in pairs(schema) do
        local value = params[k]
        table.insert(lines, tostring(form_utils.render_value(param_schema, value)))
        local field_hl = "OverseerField"
        if not form_utils.validate_field(param_schema, value) then
          field_hl = "DiagnosticError"
        end
        table.insert(extmarks, {
          #lines,
          0,
          {
            virt_text = { { "  " .. k, field_hl }, { ": ", "NormalFloat" } },
            virt_text_pos = "inline",
            undo_restore = false,
            invalidate = true,
          },
        })
        ext_idx_to_comp_and_schema_field_name[#extmarks] = { i, k }
      end
    end
  end

  -- When in insert mode, don't overwrite whatever in-progress value the user is typing
  if self.cur_line and vim.api.nvim_get_mode().mode == "i" then
    local lnum, line = unpack(self.cur_line)
    lines[lnum] = line
  end

  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, true, lines)
  if self.task_name:match("^%s*$") then
    vim.api.nvim_buf_set_extmark(self.bufnr, ns, 0, 0, {
      virt_text = { { "Task name is required", "DiagnosticError" } },
    })
  end
  for i, mark in ipairs(extmarks) do
    local lnum, col, opts = unpack(mark)
    local ext_id = vim.api.nvim_buf_set_extmark(self.bufnr, ns, lnum - 1, col, opts)
    self.ext_id_to_comp_idx_and_schema_field_name[ext_id] = ext_idx_to_comp_and_schema_field_name[i]
  end
  self:on_cursor_move()
end

---@param insert_position integer
function Editor:add_new_component(insert_position)
  self.disable_close_on_leave = true
  self.cur_line = nil
  -- Telescope doesn't work if we open it in insert mode, so we have to <esc>
  if vim.api.nvim_get_mode().mode == "i" then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<ESC>", true, true, true), "n", false)
  end

  local options = {}
  local longest_option = 1
  local existing = {}
  for _, comp in ipairs(self.components) do
    existing[comp[1]] = true
  end
  for _, v in ipairs(component.list_editable()) do
    if not existing[v] then
      table.insert(options, v)
      longest_option = math.max(longest_option, vim.api.nvim_strwidth(v))
    end
  end
  for _, v in ipairs(component.list_aliases()) do
    if not v:match("^default") then
      table.insert(options, v)
      longest_option = math.max(longest_option, vim.api.nvim_strwidth(v))
    end
  end
  table.sort(options)

  vim.schedule_wrap(vim.ui.select)(options, {
    prompt = "New component",
    kind = "overseer_new_component",
    format_item = function(item)
      local name = util.align(item, longest_option, "left")
      local comp = component.get(item)
      if comp then
        if comp.desc then
          return string.format("%s %s", name, comp.desc)
        else
          return item
        end
      else
        return string.format("%s [%s]", name, component.stringify_alias(item))
      end
    end,
  }, function(result)
    self.disable_close_on_leave = false
    if result then
      local alias = component.get_alias(result)
      if alias then
        for i, v in ipairs(component.resolve({ result }, self.components)) do
          local compdef
          if type(v) == "string" then
            compdef = component.create_default_params(v)
          else
            compdef = vim.tbl_deep_extend("force", component.create_default_params(v[1]), v)
          end
          table.insert(self.components, insert_position + i, compdef)
        end
      else
        local params = component.create_default_params(result)
        table.insert(self.components, insert_position, params)
      end
    end
    self:render()
  end)
end

function Editor:parse()
  local lines = vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, true)
  self.task_name = lines[1]
  local lnum_to_comp_and_field = self:get_lnum_to_comp_idx_and_field()
  if vim.tbl_isempty(lnum_to_comp_and_field) then
    -- user may have done an "undo" and removed all the extmarks
    self:render()
    return
  end

  local new_comp_insert_pos = 1
  local seen_components = {}
  -- Skip the first line, which is the task name
  for i = 2, #lines do
    local line = lines[i]
    local comp_and_field = lnum_to_comp_and_field[i]
    -- If this line doesn't map to a task param, component name, or component field, then it is a
    -- new blank line and we should insert a new component
    if not comp_and_field then
      self:add_new_component(new_comp_insert_pos)
      return
    end
    local comp_idx, field_name = comp_and_field[1], comp_and_field[2]

    if not comp_idx and field_name then
      -- This is a task param
      local param_schema = task_builtin_params[field_name]
      local parsed, value = form_utils.parse_value(param_schema, line)
      if parsed then
        self.task_data[field_name] = value
      end
    elseif comp_idx and not field_name then
      local comp_name = self.components[comp_idx][1]
      new_comp_insert_pos = new_comp_insert_pos + 1
      seen_components[comp_name] = true
    elseif comp_idx and field_name then
      local comp_data = self.components[comp_idx]
      local comp = assert(component.get(comp_data[1]))
      local param_schema = comp.params[field_name]
      local parsed, value = form_utils.parse_value(param_schema, line)
      if parsed then
        comp_data[field_name] = value
      end
    end
  end

  -- Remove all the components that we didn't see
  local to_remove = {}
  for i, v in ipairs(self.components) do
    if not seen_components[v[1]] then
      table.insert(to_remove, 1, i)
    end
  end
  for _, idx in ipairs(to_remove) do
    table.remove(self.components, idx)
  end

  self:layout()
  self:render()
end

function Editor:submit()
  if self.task_name:match("^%s*$") then
    return
  end
  for _, params in ipairs(self.components) do
    local comp = assert(component.get(params[1]))

    local schema = comp.params
    if schema then
      for k, param_schema in pairs(schema) do
        local value = params[k]
        if not form_utils.validate_field(param_schema, value) then
          return
        end
      end
    end
  end
  local seen = util.list_to_map(vim.tbl_map(function(c)
    return c[1]
  end, self.components))
  local to_remove = {}
  ---@diagnostic disable-next-line: invisible
  for _, v in ipairs(self.task.components) do
    if not seen[v.name] then
      table.insert(to_remove, v.name)
    end
  end
  self.task:remove_components(to_remove)
  self.task:set_components(self.components)
  for k, v in pairs(self.task_data) do
    self.task[k] = v
  end
  -- This was causing problems if the original task we're editing was a string and had quoted args
  -- (e.g. "sleep '10'"). I think it's fine if the task editor always returns the cmd as a string,
  -- so let's do that for now.
  -- if not util.is_shell_cmd(self.task_data.cmd) then
  --   self.task.cmd = vim.split(self.task_data.cmd, "%s+")
  -- end
  if not self.task_name:match("^%s*$") then
    self.task.name = self.task_name
  end
  self.cleanup()
  self.callback(self.task)
end

function Editor:cancel()
  self.cleanup()
  self.callback()
end

M.open = function(task, task_cb)
  local editor = Editor.new(task, task_cb)
  editor:render()
end

return M
