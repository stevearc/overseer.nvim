---@type overseer.TemplateFileProvider
return {
  generator = function(opts)
    local tox_file = vim.fs.find("tox.ini", { upward = true, type = "file", path = opts.dir })[1]
    if not tox_file then
      return "No tox.ini file found"
    end
    local file = io.open(tox_file, "r")
    if not file then
      return "Failed to read tox.ini file"
    end
    local targets = {}
    for line in file:lines() do
      local envlist = line:match("^envlist%s*=%s*(.+)$")
      if envlist then
        for t in vim.gsplit(envlist, "%s*,%s*") do
          if t:match("^[a-zA-Z0-9_%-]+$") then
            targets[t] = true
          end
        end
      end

      local name = line:match("^%[testenv:([a-zA-Z0-9_%-]+)%]")
      if name then
        targets[name] = true
      end
    end

    local ret = {}
    local cwd = vim.fs.dirname(tox_file)
    for k in pairs(targets) do
      table.insert(ret, {
        name = string.format("tox %s", k),
        builder = function()
          return {
            cmd = { "tox", "-e", k },
            cwd = cwd,
          }
        end,
      })
    end
    return ret
  end,
}
