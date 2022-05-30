local component = require("overseer.component")
local form = require("overseer.form")
local Task = require("overseer.task")
local util = require("overseer.util")
local M = {}

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
    if entry.description then
      table.insert(columns, { entry.description, "Comment" })
    end
    return displayer(columns)
  end
  picker_opts.finder = finders.new_table({
    results = options,
    entry_maker = function(item)
      local comp = component.get(item)
      local ordinal = item
      if comp.description then
        ordinal = ordinal .. " " .. comp.description
      end
      return {
        display = make_display,
        ordinal = ordinal,
        description = comp.description,
        value = item,
      }
    end,
  })
  return picker_opts
end

M.open = function(task, task_cb)
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
  vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")

  local components = {}
  for _, comp in ipairs(task.components) do
    table.insert(components, vim.deepcopy(comp.params))
  end
  local task_data = {}
  for k in pairs(Task.params) do
    task_data[k] = vim.deepcopy(task[k])
  end
  local task_name = task.name

  local ns = vim.api.nvim_create_namespace("overseer")
  local vtext_ns = vim.api.nvim_create_namespace("overseer_vtext")
  local line_to_comp = {}

  local function on_cursor_move()
    local cur = vim.api.nvim_win_get_cursor(0)
    local original_cur = vim.deepcopy(cur)
    vim.api.nvim_buf_clear_namespace(bufnr, vtext_ns, 0, -1)

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

    if not line_to_comp[cur[1]] then
      return
    end
    local comp, param_name = unpack(line_to_comp[cur[1]])

    if param_name then
      local schema = comp.params[param_name]
      local label = form.render_field(schema, "  ", param_name, "")
      if cur[2] < string.len(label) then
        cur[2] = string.len(label)
      end
      if schema.description then
        vim.api.nvim_buf_set_extmark(bufnr, vtext_ns, cur[1] - 1, 0, {
          virt_text = { { schema.description, "Comment" } },
        })
      end
    end
    if cur[1] ~= original_cur[1] or cur[2] ~= original_cur[2] then
      vim.api.nvim_win_set_cursor(0, cur)
    end
  end

  local function render()
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    line_to_comp = {}
    local lines = { task_name }
    local highlights = { { "OverseerTask", 1, 0, -1 } }

    for _, k in ipairs(Task.ordered_params) do
      local schema = Task.params[k]
      local value = task_data[k]
      table.insert(lines, form.render_field(schema, "", k, value))
      if form.validate_field(schema, value) then
        table.insert(highlights, { "OverseerField", #lines, 0, string.len(k) })
      else
        table.insert(highlights, { "DiagnosticError", #lines, 0, string.len(k) })
      end
    end

    for _, params in ipairs(components) do
      local comp = component.get(params[1])
      local line = comp.name
      table.insert(highlights, { "OverseerComponent", #lines + 1, 0, string.len(comp.name) })
      if comp.description then
        local prev_len = string.len(line)
        line = string.format("%s (%s)", line, comp.description)
        table.insert(highlights, { "Comment", #lines + 1, prev_len + 1, -1 })
      end
      table.insert(lines, line)
      line_to_comp[#lines] = { comp, nil }

      local schema = comp.params
      for k, param_schema in pairs(schema) do
        local value = params[k]
        table.insert(lines, form.render_field(param_schema, "  ", k, value))
        if form.validate_field(param_schema, value) then
          table.insert(highlights, { "OverseerField", #lines, 0, 2 + string.len(k) })
        else
          table.insert(highlights, { "DiagnosticError", #lines, 0, 2 + string.len(k) })
        end
        line_to_comp[#lines] = { comp, k }
      end
    end

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
    util.add_highlights(bufnr, ns, highlights)
    if task_name:match("^%s*$") then
      vim.api.nvim_buf_set_extmark(bufnr, ns, 0, 0, {
        virt_text = { { "Task name is required", "DiagnosticError" } },
      })
    end
    on_cursor_move()
  end

  render()

  local is_adding_component = false

  local function add_new_component(insert_position)
    local options = {}
    local existing = {}
    for _, comp in ipairs(components) do
      existing[comp[1]] = true
    end
    for _, v in ipairs(component.list()) do
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
          if comp.description then
            return string.format("%s - %s", item, comp.description)
          else
            return item
          end
        else
          return string.format("%s [%s]", item, component.stringify_alias(item))
        end
      end,
      telescope = get_telescope_new_component(options),
    }, function(result)
      is_adding_component = false
      if result then
        local alias = component.get_alias(result)
        if alias then
          for i, v in ipairs(component.resolve({ result }, components)) do
            table.insert(components, insert_position - 1 + i, component.create_params(v))
          end
        else
          local params = component.create_params(result)
          table.insert(components, insert_position, params)
        end
      end
      render()
    end)
  end

  local autocmds = {}

  local cleanup, layout = form.open_form_win(bufnr, {
    autocmds = autocmds,
    get_preferred_dim = function()
      -- TODO this is causing a lot of jumping
    end,
  })
  vim.api.nvim_buf_set_option(bufnr, "filetype", "OverseerTask")

  local function parse()
    task_name = vim.api.nvim_buf_get_lines(bufnr, 0, 1, true)[1]
    local offset = 1
    local buflines = vim.api.nvim_buf_get_lines(bufnr, offset, -1, true)
    local comp_map = {}
    local comp_idx = {}
    for i, v in ipairs(components) do
      comp_map[v[1]] = v
      comp_idx[v[1]] = i
    end

    local insert_position = #components + 1
    for i, line in ipairs(buflines) do
      if line:match("^%s*$") then
        local comp = line_to_comp[i + offset]
        if comp then
          insert_position = comp_idx[comp[1].name]
        elseif i < #buflines / 2 then
          insert_position = 1
        end
        is_adding_component = true
        break
      end
    end
    if is_adding_component then
      add_new_component(insert_position)
      return
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
            task_data[name] = value
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
              table.insert(components, last_idx, params)
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
    for i, v in ipairs(components) do
      if not seen_comps[v[1]] then
        table.insert(to_remove, 1, i)
      end
    end
    for _, idx in ipairs(to_remove) do
      table.remove(components, idx)
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

  local function submit()
    if task_name:match("^%s*$") then
      return
    end
    for _, params in ipairs(components) do
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
    end, components))
    local to_remove = {}
    for _, v in ipairs(task.components) do
      if not seen[v.name] then
        table.insert(to_remove, v.name)
      end
    end
    task:remove_components(to_remove)
    task:set_components(components)
    for k, v in pairs(task_data) do
      task[k] = v
    end
    if not util.is_shell_cmd(task_data.cmd) then
      task.cmd = vim.split(task_data.cmd, "%s+")
    end
    if not task_name:match("^%s*$") then
      task.name = task_name
    end
    cleanup()
    if callback then
      callback(task)
    end
  end

  local function cancel()
    cleanup()
    if callback then
      callback()
    end
  end

  vim.keymap.set("n", "<CR>", submit, { buffer = bufnr })
  vim.keymap.set({ "n", "i" }, "<C-r>", submit, { buffer = bufnr })
  vim.keymap.set({ "n", "i" }, "<C-s>", submit, { buffer = bufnr })

  table.insert(
    autocmds,
    vim.api.nvim_create_autocmd("BufLeave", {
      desc = "Close float on BufLeave",
      buffer = bufnr,
      nested = true,
      callback = function()
        if not is_adding_component then
          cancel()
        end
      end,
    })
  )
end

return M
