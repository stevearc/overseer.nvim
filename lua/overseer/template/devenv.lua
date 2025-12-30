local overseer = require("overseer")

---@param opts overseer.SearchParams
---@return nil|string
local function get_devenv_file(opts)
  local devenv_nix = { "devenv.nix" }
  return vim.fs.find(devenv_nix, { upward = true, type = "file", path = opts.dir })[1]
end

return {
  cache_key = function(opts)
    return get_devenv_file(opts)
  end,
  generator = function(opts, cb)
    if vim.fn.executable("devenv") == 0 then
      return 'Command "devenv" not found'
    end
    local devenv = get_devenv_file(opts)
    if not devenv then
      return "No devenv.nix file found"
    end
    local devenv_dir = vim.fs.dirname(devenv)
    local ret = {}
    overseer.builtin.system(
      { "devenv", "shell", "echo $DEVENV_TASKS" },
      { cwd = devenv_dir, text = true },
      vim.schedule_wrap(function(out)
        local ok, data = pcall(vim.json.decode, out.stdout, { luanil = { object = true } })

        if not ok then
          cb(data)
          return
        end

        for _, task in ipairs(data) do
          table.insert(ret, {
            name = string.format("devenv %s", task.name),
            builder = function()
              return {
                cwd = devenv_dir,
                cmd = { "devenv", "tasks", "run", task.name },
              }
            end,
          })
        end

        cb(ret)
      end)
    )
  end,
}
