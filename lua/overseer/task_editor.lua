local binding_util = require("overseer.binding_util")
local component = require("overseer.component")
local config = require("overseer.config")
local form = require("overseer.form")
local Task = require("overseer.task")
local util = require("overseer.util")
local M = {}

local bindings = {
  {
    desc = "Show default key bindings",
    plug = "<Plug>OverseerLauncher:ShowHelp",
    rhs = function(editor)
      editor.disable_close_on_leave = true
      binding_util.show_bindings("OverseerLauncher:")
    end,
  },
  {
    desc = "Submit the task",
    plug = "<Plug>OverseerLauncher:Submit",
    rhs = function(editor)
      editor:submit()
    end,
  },
  {
    desc = "Cancel editing the task",
    plug = "<Plug>OverseerLauncher:Cancel",
    rhs = function(editor)
      editor:cancel()
    end,
  },
}

-- Telescope-specific settings for picking a new component
local function get_telescope_new_component(options)
  local has_telescope = pcall(require, "telescope")
  if not has_telescope then
    return
  end

  local themes = require("telescope.themes")
  local finders = require("telescope.finders")
  local entry_display = require("telescope.pickers.entry_display")
  local picker_opts = themes.get_dropdown()

  local width = vim.api.nvim_win_get_width(0) - 2
  local height = vim.api.nvim_win_get_height(0) - 2
  picker_opts.layout_config.width = function(_, max_columns, _)
    return math.min(max_columns, width)
  end
  picker_opts.layout_config.height = function(_, _, max_lines)
    return math.min(max_lines, height)
  end

  local max_name = 1
  for _, name in ipairs(options) do
    local len = string.len(name)
    if len > max_name then
      max_name = len
    end
  end

  local displayer = entry_display.create({
    separator = " ",
    items = {
      { width = max_name },
      { remaining = true },
    },
  })

  local function make_display(entry)
    local columns = {
      entry.value,
    }
    if entry.desc then
      table.insert(columns, { entry.desc, "Comment" })
    end
    return displayer(columns)
  end
  picker_opts.finder = finders.new_table({
    results = options,
    entry_maker = function(item)
      local comp = component.get(item)
      local ordinal = item
      local description
      if comp then
        description = comp.desc
      else
        description = component.stringify_alias(item)
      end
      if description then
        ordinal = ordinal .. " " .. comp.desc
      end
      return {
        display = make_display,
        ordinal = ordinal,
        desc = comp.desc,
        value = item,
      }
    end,
  })
  return picker_opts
end

local Editor = {}

function Editor.new(task, task_cb)
  task:inc_reference()
  local function callback(...)
    task:dec_reference()
    if task_cb then
      task_cb(...)
    end
  end
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(bufnr, "buftype", "acwrite")
  vim.api.nvim_buf_set_name(bufnr, "Overseer task editor")

  local components = {}
  for _, comp in ipairs(task.components) do
    table.insert(components, vim.deepcopy(comp.params))
  end
  local task_data = {}
  for k in pairs(Task.params) do
    task_data[k] = vim.deepcopy(task[k])
  end

  local autocmds = {}
  local cleanup, layout = form.open_form_win(bufnr, {
    autocmds = autocmds,
    get_preferred_dim = function()
      -- TODO this is causing a lot of jumping
    end,
  })
  vim.api.nvim_buf_set_option(bufnr, "filetype", "OverseerForm")
  local editor = setmetatable({
    cur_line = nil,
    task = task,
    callback = callback,
    bufnr = bufnr,
    components = components,
    task_name = task.name,
    task_data = task_data,
    line_to_comp = {},
    disable_close_on_leave = false,
    layout = layout,
    cleanup = cleanup,
    autocmds = autocmds,
  }, { __index = Editor })

  binding_util.create_plug_bindings(bufnr, bindings, editor)
  for mode, user_bindings in pairs(config.task_launcher.bindings) do
    binding_util.create_bindings_to_plug(bufnr, mode, user_bindings, "OverseerLauncher:")
  end
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    desc = "Submit on buffer write",
    buffer = bufnr,
    callback = function()
      editor:submit()
    end,
  })

  table.insert(
    editor.autocmds,
    vim.api.nvim_create_autocmd("BufLeave", {
      desc = "Close float on BufLeave",
      buffer = bufnr,
      nested = true,
      callback = function()
        if not editor.disable_close_on_leave then
          editor:cancel()
        end
      end,
    })
  )
  table.insert(
    editor.autocmds,
    vim.api.nvim_create_autocmd("BufEnter", {
      desc = "Reset disable_close_on_leave",
      buffer = bufnr,
      nested = true,
      callback = function()
        editor.disable_close_on_leave = false
      end,
    })
  )
  table.insert(
    editor.autocmds,
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
      desc = "Update form on change",
      buffer = bufnr,
      nested = true,
      callback = function()
        local lnum = vim.api.nvim_win_get_cursor(0)[1]
        local line = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, true)[1]
        editor.cur_line = { lnum, line }
        editor:parse()
      end,
    })
  )
  table.insert(
    editor.autocmds,
    vim.api.nvim_create_autocmd("InsertLeave", {
      desc = "Rerender form",
      buffer = bufnr,
      callback = function()
        editor:render()
      end,
    })
  )
  table.insert(
    editor.autocmds,
    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
      desc = "Update form on move cursor",
      buffer = bufnr,
      nested = true,
      callback = function()
        editor:on_cursor_move()
      end,
    })
  )
  return editor
end

function Editor:on_cursor_move()
  if vim.api.nvim_get_mode().mode == "i" then
    return
  end
  local cur = vim.api.nvim_win_get_cursor(0)
  if self.cur_line and self.cur_line[1] ~= cur[1] then
    self.cur_line = nil
    self:render()
    return
  end
  local original_cur = vim.deepcopy(cur)
  local vtext_ns = vim.api.nvim_create_namespace("overseer_vtext")
  vim.api.nvim_buf_clear_namespace(self.bufnr, vtext_ns, 0, -1)

  -- First line is task name, successive lines are task params
  -- If cursor is on the task params, make sure it's past the label
  if cur[1] > 1 and cur[1] <= #Task.ordered_params + 1 then
    local param_name = Task.ordered_params[cur[1] - 1]
    local schema = Task.params[param_name]
    local label = form.render_field(schema, "", param_name, "")
    if cur[2] < string.len(label) then
      cur[2] = string.len(label)
      vim.api.nvim_win_set_cursor(0, cur)
    end
    return
  end

  if not self.line_to_comp[cur[1]] then
    return
  end
  local comp, param_name = unpack(self.line_to_comp[cur[1]])

  if param_name then
    local schema = comp.params[param_name]
    local label = form.render_field(schema, "  ", param_name, "")
    if cur[2] < string.len(label) then
      cur[2] = string.len(label)
    end
    if schema.desc then
      vim.api.nvim_buf_set_extmark(self.bufnr, vtext_ns, cur[1] - 1, 0, {
        virt_text = { { schema.desc, "Comment" } },
      })
    end
    if schema.subtype then
      vim.api.nvim_buf_set_var(0, "overseer_choices", schema.subtype.choices)
    else
      vim.api.nvim_buf_set_var(0, "overseer_choices", schema.choices)
    end
  end
  if cur[1] ~= original_cur[1] or cur[2] ~= original_cur[2] then
    vim.api.nvim_win_set_cursor(0, cur)
  end
end

function Editor:render()
  local ns = vim.api.nvim_create_namespace("overseer")
  vim.api.nvim_buf_clear_namespace(self.bufnr, ns, 0, -1)
  self.line_to_comp = {}
  local lines = { self.task_name }
  local highlights = { { "OverseerTask", 1, 0, -1 } }

  for _, k in ipairs(Task.ordered_params) do
    local schema = Task.params[k]
    local value = self.task_data[k]
    table.insert(lines, form.render_field(schema, "", k, value))
    if form.validate_field(schema, value) then
      table.insert(highlights, { "OverseerField", #lines, 0, string.len(k) })
    else
      table.insert(highlights, { "DiagnosticError", #lines, 0, string.len(k) })
    end
  end

  for _, params in ipairs(self.components) do
    local comp = component.get(params[1])
    local line = comp.name
    table.insert(highlights, { "OverseerComponent", #lines + 1, 0, string.len(comp.name) })
    if comp.desc then
      local prev_len = string.len(line)
      line = string.format("%s (%s)", line, comp.desc)
      table.insert(highlights, { "Comment", #lines + 1, prev_len + 1, -1 })
    end
    table.insert(lines, line)
    self.line_to_comp[#lines] = { comp, nil }

    local schema = comp.params
    for k, param_schema in pairs(schema) do
      local value = params[k]
      table.insert(lines, form.render_field(param_schema, "  ", k, value))
      if form.validate_field(param_schema, value) then
        table.insert(highlights, { "OverseerField", #lines, 0, 2 + string.len(k) })
      else
        table.insert(highlights, { "DiagnosticError", #lines, 0, 2 + string.len(k) })
      end
      self.line_to_comp[#lines] = { comp, k }
    end
  end
  if self.cur_line and vim.api.nvim_get_mode().mode == "i" then
    local lnum, line = unpack(self.cur_line)
    lines[lnum] = line
  end

  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, true, lines)
  util.add_highlights(self.bufnr, ns, highlights)
  if self.task_name:match("^%s*$") then
    vim.api.nvim_buf_set_extmark(self.bufnr, ns, 0, 0, {
      virt_text = { { "Task name is required", "DiagnosticError" } },
    })
  end
  self:on_cursor_move()
end

function Editor:add_new_component(insert_position)
  self.disable_close_on_leave = true
  self.cur_line = nil
  -- Telescope doesn't work if we open it in insert mode, so we have to <esc>
  if vim.api.nvim_get_mode().mode == "i" then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<ESC>", true, true, true), "n", false)
  end

  local options = {}
  local existing = {}
  for _, comp in ipairs(self.components) do
    existing[comp[1]] = true
  end
  for _, v in ipairs(component.list_editable()) do
    if not existing[v] then
      table.insert(options, v)
    end
  end
  for _, v in ipairs(component.list_aliases()) do
    if not v:match("^default") then
      table.insert(options, v)
    end
  end
  table.sort(options)

  vim.ui.select(options, {
    prompt = "New component",
    kind = "overseer_new_component",
    format_item = function(item)
      local comp = component.get(item)
      if comp then
        if comp.desc then
          return string.format("%s - %s", item, comp.desc)
        else
          return item
        end
      else
        return string.format("%s [%s]", item, component.stringify_alias(item))
      end
    end,
    telescope = get_telescope_new_component(options),
  }, function(result)
    self.disable_close_on_leave = false
    if result then
      local alias = component.get_alias(result)
      if alias then
        for i, v in ipairs(component.resolve({ result }, self.components)) do
          table.insert(self.components, insert_position - 1 + i, component.create_params(v))
        end
      else
        local params = component.create_params(result)
        table.insert(self.components, insert_position, params)
      end
    end
    self:render()
  end)
end

function Editor:parse()
  self.task_name = vim.api.nvim_buf_get_lines(self.bufnr, 0, 1, true)[1]
  local offset = 1
  local buflines = vim.api.nvim_buf_get_lines(self.bufnr, offset, -1, true)
  local comp_map = {}
  local comp_idx = {}
  for i, v in ipairs(self.components) do
    comp_map[v[1]] = v
    comp_idx[v[1]] = i
  end

  local insert_position = #self.components + 1
  for i, line in ipairs(buflines) do
    if line:match("^%s*$") then
      local comp = self.line_to_comp[i + offset]
      if comp then
        insert_position = comp_idx[comp[1].name]
      elseif i < #buflines / 2 then
        insert_position = 1
      end
      self:add_new_component(insert_position)
      return
    end
  end

  local seen_comps = {}
  local comp
  local last_idx = 0
  for _, line in ipairs(buflines) do
    local prefix, name, text = line:match("^(%s*)([^%s]+): ?(.*)$")
    if name and comp and prefix == "  " then
      local param_schema = comp.params[name]
      if param_schema then
        local parsed, value = form.parse_value(param_schema, text)
        if parsed then
          comp_map[comp.name][name] = value
        end
      end
    elseif name and prefix == "" then
      local param_schema = Task.params[name]
      if param_schema then
        local parsed, value = form.parse_value(param_schema, text)
        if parsed then
          self.task_data[name] = value
        end
      end
    else
      local comp_name = line:match("^([^%s]+) ")
      if comp_name then
        comp = component.get(comp_name)
        if comp then
          if not comp_map[comp_name] then
            -- This is a new component we need to insert
            last_idx = last_idx + 1
            local params = component.create_params(comp_name)
            comp_map[comp_name] = params
            comp_idx[comp_name] = last_idx
            table.insert(self.components, last_idx, params)
          else
            last_idx = comp_idx[comp_name]
          end
          seen_comps[comp_name] = true
        end
      end
    end
  end

  -- Remove all the components that we didn't see
  local to_remove = {}
  for i, v in ipairs(self.components) do
    if not seen_comps[v[1]] then
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
    local comp = component.get(params[1])

    local schema = comp.params
    for k, param_schema in pairs(schema) do
      local value = params[k]
      if not form.validate_field(param_schema, value) then
        return
      end
    end
  end
  local seen = util.list_to_map(vim.tbl_map(function(c)
    return c[1]
  end, self.components))
  local to_remove = {}
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
