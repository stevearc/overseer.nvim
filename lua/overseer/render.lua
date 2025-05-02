local util = require("overseer.util")

local M = {}

---@alias overseer.TextChunk {[1]: string, [2]: nil|string}
---@alias overseer.RenderFunc fun(task: overseer.Task): overseer.TextChunk[][]

---@param task overseer.Task
---@return overseer.TextChunk[]
M.status = function(task)
  return { { task.status, "Overseer" .. task.status } }
end

---@param task overseer.Task
---@return overseer.TextChunk[]
M.name = function(task)
  return { { task.name, "OverseerTask" } }
end

---@param task overseer.Task
---@return overseer.TextChunk[]
M.status_and_name = function(task)
  return M.join(M.status(task), M.name(task), ": ")
end

---@param task overseer.Task
---@return overseer.TextChunk[]
M.cmd = function(task)
  local cmd = task.cmd
  if not cmd then
    return {}
  elseif type(cmd) == "string" then
    return { { cmd } }
  else
    return { { table.concat(cmd, " ") } }
  end
end

local function stringify_result(res)
  if type(res) == "table" then
    if vim.tbl_isempty(res) then
      return "{}"
    else
      return string.format("{<%d items>}", vim.tbl_count(res))
    end
  else
    return string.format("%s", res)
  end
end

---@param task overseer.Task
---@param opts? {oneline?: boolean}
---@return overseer.TextChunk[][]
M.result_lines = function(task, opts)
  ---@type {oneline: boolean}
  opts = vim.tbl_extend("keep", opts or {}, { oneline = false })
  if not task.result or vim.tbl_isempty(task.result) then
    return {}
  end
  local ret = {}
  if opts.oneline then
    local pieces = {}
    for k, v in pairs(task.result) do
      table.insert(pieces, string.format("%s=%s", k, stringify_result(v)))
    end
    table.insert(ret, { { "Result: " }, { table.concat(pieces, ", ") } })
  else
    table.insert(ret, { { "Result: " } })
    for k, v in pairs(task.result) do
      table.insert(ret, { { string.format("  %s = %s", k, stringify_result(v)) } })
    end
  end
  return ret
end

---@param task overseer.Task
---@param opts? {hl_group?: string}
---@return overseer.TextChunk[]
M.duration = function(task, opts)
  opts = opts or {}
  if not task.time_start then
    return {}
  end
  local duration
  if task.time_end then
    duration = task.time_end - task.time_start
  else
    duration = os.time() - task.time_start
  end
  return { { util.format_duration(duration), opts.hl_group } }
end

---@param task overseer.Task
---@param opts? {hl_group?: string}
---@return overseer.TextChunk[]
M.time_since_completed = function(task, opts)
  opts = opts or {}
  if not task.time_end then
    return {}
  end
  return { { util.format_relative_timestamp(task.time_end), opts.hl_group } }
end

---@param task overseer.Task
---@param opts? {num_lines?: integer, prefix?: string, prefix_hl_group?: string}
---@return overseer.TextChunk[][]
M.output_lines = function(task, opts)
  ---@type {num_lines: integer, prefix: string, prefix_hl_group: string}
  opts = vim.tbl_extend(
    "keep",
    opts or {},
    { num_lines = 1, prefix = "> ", prefix_hl_group = "Comment" }
  )
  local bufnr = task:get_bufnr()
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return {}
  end
  local lines = util.get_last_output_lines(bufnr, opts.num_lines)
  local ret = {}
  for _, line in ipairs(lines) do
    table.insert(ret, { { opts.prefix, opts.prefix_hl_group }, { line, "OverseerOutput" } })
  end
  return ret
end

---@param task overseer.Task
---@param opts? {hl_group?: string}
---@return overseer.TextChunk[][]
M.source = function(task, opts)
  ---@type {hl_group: string}
  opts = vim.tbl_extend("keep", opts or {}, { hl_group = "Comment" })
  local ret = {}
  if task.source and task.source.module then
    table.insert(ret, { { task.source.module, opts.hl_group } })
  end
  return ret
end

---The default format for tasks in the task list
---@type overseer.RenderFunc
M.format_standard = function(task)
  local ret = {
    M.status_and_name(task),
  }
  vim.list_extend(ret, M.source(task))
  table.insert(
    ret,
    M.join(M.duration(task), M.time_since_completed(task, { hl_group = "Comment" }))
  )
  vim.list_extend(ret, M.result_lines(task, { oneline = true }))
  vim.list_extend(ret, M.output_lines(task, { num_lines = 1 }))
  return M.remove_empty_lines(ret)
end

---A more compact format for tasks
---@type overseer.RenderFunc
M.format_compact = function(task)
  return {
    M.status_and_name(task),
    M.join(M.duration(task), M.time_since_completed(task, { hl_group = "Comment" })),
  }
end

---A more verbose format for tasks
---@type overseer.RenderFunc
M.format_verbose = function(task)
  local ret = {
    M.status_and_name(task),
    M.join(M.duration(task), M.time_since_completed(task, { hl_group = "Comment" })),
  }
  vim.list_extend(ret, M.result_lines(task, { oneline = true }))
  vim.list_extend(ret, M.output_lines(task, { num_lines = 4 }))
  return M.remove_empty_lines(ret)
end

---@param a overseer.TextChunk[]
---@param b overseer.TextChunk[]
---@param sep? string|overseer.TextChunk
---@return overseer.TextChunk[]
M.join = function(a, b, sep)
  if not sep then
    sep = " "
  end
  local ret = {}
  for _, v in ipairs(a) do
    table.insert(ret, v)
  end
  -- Only add the separator if there was anything in "a"
  if #ret > 0 then
    if type(sep) == "string" then
      table.insert(ret, { sep })
    else
      table.insert(ret, sep)
    end
  end
  for _, v in ipairs(b) do
    table.insert(ret, v)
  end
  return ret
end

---@param lines overseer.TextChunk[][]
---@return overseer.TextChunk[][]
M.remove_empty_lines = function(lines)
  local i = 1
  while i <= #lines do
    if vim.tbl_isempty(lines[i]) then
      table.remove(lines, i)
    else
      i = i + 1
    end
  end
  return lines
end

return M
