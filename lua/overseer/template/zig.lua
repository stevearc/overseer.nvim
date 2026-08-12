local constants = require("overseer.constants")
local TAG = constants.TAG

---@param opts overseer.SearchParams
---@return nil|string
local function get_build_file(opts)
  return vim.fs.find("build.zig", { upward = true, type = "file", path = opts.dir })[1]
end

-- `zig build` runs the build runner against build.zig. "run" and "test" are the
-- conventional steps that `zig init` generates, so they are present in most projects.
local commands = {
  { args = { "build" }, tags = { TAG.BUILD } },
  { args = { "build", "run" }, tags = { TAG.RUN } },
  { args = { "build", "test" }, tags = { TAG.TEST } },
}

---@type overseer.TemplateFileProvider
return {
  cache_key = function(opts)
    return get_build_file(opts)
  end,
  generator = function(opts)
    if vim.fn.executable("zig") == 0 then
      return 'Command "zig" not found'
    end
    local build_file = get_build_file(opts)
    if not build_file then
      return "No build.zig file found"
    end
    local cwd = vim.fs.dirname(build_file)
    local ret = {}
    for _, command in ipairs(commands) do
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
    return ret
  end,
}
