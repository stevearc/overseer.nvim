local overseer = require("overseer")
-- A make/rake-like build tool using Go
-- https://magefile.org/

---@param opts overseer.SearchParams
---@return nil|string
local function get_magefile(opts)
  -- mage works with any file names using Go's "mage" build tag.
  -- "magefile.go" is just a common convention.
  return vim.fs.find("magefile.go", { upward = true, type = "file", path = opts.dir })[1]
end

---@param opts overseer.SearchParams
---@return nil|string
local function get_magedir(opts)
  -- mage works with any directory names specified with `-d` argument.
  -- "magefiles" is inferred if nothing is specified in the command line.
  return vim.fs.find("magefiles", { upward = true, type = "directory", path = opts.dir })[1]
end

---@type overseer.TemplateFileProvider
return {
  cache_key = function(opts)
    local magefile = get_magefile(opts)
    return magefile ~= nil and magefile or get_magedir(opts)
  end,
  generator = function(opts, cb)
    if vim.fn.executable("mage") == 0 then
      return 'Command "mage" not found'
    end
    local magefile, magedir = get_magefile(opts), get_magedir(opts)
    if not (magedir or magefile) then
      return "No magefile.go file or magefiles directory found"
    end
    local cwd = magefile ~= nil and vim.fs.dirname(magefile)
      or (magedir ~= nil and vim.fs.dirname(magedir) or opts.dir)
    local ret = {}
    overseer.builtin.system(
      { "mage", "-l" },
      {
        env = { MAGEFILE_ENABLE_COLOR = "false" },
        cwd = cwd,
        text = true,
      },
      vim.schedule_wrap(function(out)
        if out.code ~= 0 then
          return cb(out.stderr or out.stdout or "Error running 'mage -l'")
        end
        for line in vim.gsplit(out.stdout, "\n") do
          if line ~= "" then
            local task_name, _, description = line:match("^  ([%w:]+)(%*?)%s+(.*)")
            if task_name ~= nil then
              table.insert(ret, {
                name = string.format("mage %s", task_name),
                desc = #description > 0 and description or nil,
                builder = function()
                  return {
                    cmd = { "mage", task_name },
                    cwd = cwd,
                  }
                end,
              })
            end
          end
        end
        cb(ret)
      end)
    )
  end,
}
