local component = require("overseer.component")
local form = require("overseer.form")
local util = require("overseer.util")
local M = {}

M.open = function(task)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")

  local components = {}
  for _, comp in ipairs(task.components) do
    table.insert(components, vim.deepcopy(comp.params))
  end

  local ns = vim.api.nvim_create_namespace("overseer")
  local vtext_ns = vim.api.nvim_create_namespace("overseer_vtext")
  local line_to_comp = {}

  local function on_cursor_move()
    local cur = vim.api.nvim_win_get_cursor(0)
    local original_cur = vim.deepcopy(cur)
    vim.api.nvim_buf_clear_namespace(bufnr, vtext_ns, 0, -1)
    if not line_to_comp[cur[1]] then
      cur[1] = next(line_to_comp)
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
    local lines = { task.name }
    local highlights = {}
    for _, params in ipairs(components) do
      local comp = component.get(params[1])
      if comp.description then
        table.insert(lines, string.format("%s (%s)", comp.name, comp.description))
        table.insert(highlights, { "Comment", #lines, string.len(comp.name) + 1, -1 })
      else
        table.insert(lines, comp.name)
      end
      table.insert(highlights, { "Constant", #lines, 0, string.len(comp.name) })
      line_to_comp[#lines] = { comp, nil }

      local schema = comp.params
      for k, param_schema in pairs(schema) do
        local value = params[k]
        table.insert(lines, form.render_field(param_schema, "  ", k, value))
        if form.validate_field(param_schema, value) then
          table.insert(highlights, { "Keyword", #lines, 0, 2 + string.len(k) })
        else
          table.insert(highlights, { "DiagnosticError", #lines, 0, 2 + string.len(k) })
        end
        line_to_comp[#lines] = { comp, k }
      end
    end

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
    for _, hl in ipairs(highlights) do
      local group, row, col_start, col_end = unpack(hl)
      vim.api.nvim_buf_add_highlight(bufnr, ns, group, row - 1, col_start, col_end)
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

  local function parse()
    local buflines = vim.api.nvim_buf_get_lines(bufnr, 1, -1, true)
    local comp_map = {}
    local comp_idx = {}
    for i, v in ipairs(components) do
      comp_map[v[1]] = v
      comp_idx[v[1]] = i
    end

    local insert_position = #components
    for i, line in ipairs(buflines) do
      if line:match("^%s*$") then
        is_adding_component = true
        insert_position = 1 + comp_idx[line_to_comp[i][1].name]
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
      local name, text = line:match("^%s+([^%s]+): ?(.*)$")
      if name and comp then
        local param_schema = comp.params[name]
        if param_schema then
          local parsed, value = form.parse_value(param_schema, text)
          if parsed then
            comp_map[comp.name][name] = value
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

    render()
  end

  local autocmds = {}

  local cleanup = form.open_form_win(bufnr, { autocmds = autocmds })
  vim.api.nvim_buf_set_option(bufnr, "filetype", "OverseerTask")

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

  table.insert(
    autocmds,
    vim.api.nvim_create_autocmd("BufLeave", {
      desc = "Close float on BufLeave",
      buffer = bufnr,
      once = true,
      nested = true,
      callback = function()
        if not is_adding_component then
          cleanup()
        end
      end,
    })
  )
end

return M
