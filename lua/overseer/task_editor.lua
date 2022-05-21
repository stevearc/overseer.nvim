local component = require("overseer.component")
local form = require("overseer.form")
local M = {}

M.open = function(task)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")

  local function calc_layout()
    local max_width = vim.o.columns
    local max_height = vim.o.lines - vim.o.cmdheight
    local opts = {
      relative = "editor",
      border = "rounded",
      zindex = 150,
      width = math.min(max_width, 80),
      height = math.min(max_height, 20),
    }
    opts.col = math.floor((max_width - opts.width) / 2)
    opts.row = math.floor((max_height - opts.height) / 2)
    return opts
  end

  local winopt = calc_layout()
  winopt.style = "minimal"
  local winid = vim.api.nvim_open_win(bufnr, true, winopt)
  vim.api.nvim_win_set_option(winid, "winblend", 10)
  vim.api.nvim_buf_set_option(bufnr, "filetype", "OverseerTask")

  local components = {}
  for _, comp in ipairs(task.components) do
    table.insert(components, vim.deepcopy(comp.params))
  end

  local ns = vim.api.nvim_create_namespace("overseer")
  local function render()
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
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

      local schema = comp.params
      for k, param_schema in pairs(schema) do
        local value = params[k]
        table.insert(lines, form.render_field(param_schema, "  ", k, value))
        if not form.validate_field(param_schema, value) then
          table.insert(highlights, { "DiagnosticError", #lines, 0, 2 + string.len(k) })
        end
      end
    end

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
    for _, hl in ipairs(highlights) do
      local group, row, col_start, col_end = unpack(hl)
      vim.api.nvim_buf_add_highlight(bufnr, ns, group, row - 1, col_start, col_end)
    end
  end

  render()

  local function parse()
    local buflines = vim.api.nvim_buf_get_lines(bufnr, 1, -1, true)
    local comp
    for _, line in ipairs(buflines) do
      local prefix, name, text = line:match("^(  )([^%s]+): ?(.*)$")
      if name and comp then
        local param_schema = comp.params[name]
        if param_schema then
          local parsed, value = form.parse_field(param_schema, prefix, name, line)
          if parsed then
            -- TODO clean this up
            for _, v in ipairs(components) do
              if v[1] == comp.name then
                v[name] = value
                break
              end
            end
          end
        end
      else
        local comp_name = line:match("^([^%s]+) ")
        if comp_name then
          comp = component.get(comp_name)
        end
      end
    end
    render()
  end

  local autocmds = {}
  table.insert(
    autocmds,
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
      desc = "Update form on change",
      buffer = bufnr,
      nested = true,
      callback = parse,
    })
  )

  local function cleanup()
    for _, id in ipairs(autocmds) do
      vim.api.nvim_del_autocmd(id)
    end
    if vim.api.nvim_get_mode().mode:match("^i") then
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<ESC>", true, true, true), "n", false)
    end
    vim.api.nvim_win_close(winid, true)
  end

  table.insert(
    autocmds,
    vim.api.nvim_create_autocmd("BufLeave", {
      desc = "Close float on BufLeave",
      buffer = bufnr,
      once = true,
      nested = true,
      callback = cleanup,
    })
  )
end

return M
