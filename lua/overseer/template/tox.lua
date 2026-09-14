---@type overseer.TemplateFileProvider
local function expand_factors(target)
  local prefix, factors, suffix = target:match("^(.-){([^{}]+)}(.*)$")
  if not prefix then
    return { target }
  end

  local expanded = {}
  for factor in factors:gmatch("[^,]+") do
    for _, value in ipairs(expand_factors(prefix .. factor:match("^%s*(.-)%s*$") .. suffix)) do
      table.insert(expanded, value)
    end
  end
  return expanded
end

local function add_targets(envlist, targets)
  local target = ""
  local depth = 0
  local function add_target()
    for _, expanded in ipairs(expand_factors(target)) do
      if expanded:match("^[a-zA-Z0-9_.%-]+$") then
        targets[expanded] = true
      end
    end
    target = ""
  end

  for char in envlist:gmatch(".") do
    if char == "{" then
      depth = depth + 1
    elseif char == "}" then
      depth = depth - 1
    end
    if depth == 0 and (char == "," or char:match("%s")) then
      add_target()
    else
      target = target .. char
    end
  end
  add_target()
end

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
    local envlist = nil
    for line in file:lines() do
      local value = line:match("^envlist%s*=%s*(.*)$")
      if value then
        envlist = value
      elseif envlist and line:match("^%s+") then
        envlist = envlist .. " " .. line
      elseif envlist then
        add_targets(envlist, targets)
        envlist = nil
      end

      local name = line:match("^%[testenv:([a-zA-Z0-9_.%-]+)%]")
      if name then
        targets[name] = true
      end
    end
    if envlist then
      add_targets(envlist, targets)
    end
    file:close()

    local ret = {}
    local cwd = vim.fs.dirname(tox_file)
    table.insert(ret, {
      name = "tox",
      builder = function()
        return {
          cmd = { "tox" },
          cwd = cwd,
        }
      end,
    })
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
