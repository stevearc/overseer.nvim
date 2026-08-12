local constants = require("overseer.constants")
local TAG = constants.TAG

---@param opts overseer.SearchParams
---@return nil|string
local function get_build_file(opts)
  return vim.fs.find("build.zig", { upward = true, type = "file", path = opts.dir })[1]
end

-- `zig build` runs the build runner against build.zig. "run" and "test" are the
-- conventional steps that `zig init` generates, so they are present in most projects.
local build_commands = {
  { args = { "build" }, tags = { TAG.BUILD } },
  { args = { "build", "run" }, tags = { TAG.RUN } },
  { args = { "build", "test" }, tags = { TAG.TEST } },
}

-- Single-file commands operate on the current buffer's .zig file.
local file_commands = {
  { args = { "run" }, tags = { TAG.RUN } },
  { args = { "test" }, tags = { TAG.TEST } },
  { args = { "fmt" } },
}

---@type overseer.TemplateFileProvider
return {
  -- No cache_key: the single-file tasks depend on the current buffer, so results
  -- must be regenerated each time to stay correct.
  generator = function(opts)
    if vim.fn.executable("zig") == 0 then
      return 'Command "zig" not found'
    end
    local ret = {}

    local build_file = get_build_file(opts)
    if build_file then
      local cwd = vim.fs.dirname(build_file)
      for _, command in ipairs(build_commands) do
        table.insert(ret, {
          name = string.format("zig %s", table.concat(command.args, " ")),
          tags = command.tags,
          builder = function()
            return {
              cmd = vim.list_extend({ "zig" }, command.args),
              cwd = cwd,
            }
          end,
        })
      end
    end

    local bufname = vim.api.nvim_buf_get_name(0)
    if bufname:match("%.zig$") then
      local cwd = vim.fs.dirname(bufname)
      for _, command in ipairs(file_commands) do
        table.insert(ret, {
          name = string.format("zig %s (current file)", command.args[1]),
          tags = command.tags,
          builder = function()
            local cmd = vim.list_extend({ "zig" }, command.args)
            table.insert(cmd, bufname)
            return {
              cmd = cmd,
              cwd = cwd,
            }
          end,
        })
      end
    end

    if vim.tbl_isempty(ret) then
      return "No build.zig file found"
    end
    return ret
  end,
}
