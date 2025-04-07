local overseer = require("overseer")
---@param opts overseer.SearchParams
---@return nil|string
local function get_makefile(opts)
  return vim.fs.find("Makefile", { upward = true, type = "file", path = opts.dir })[1]
end

---@type overseer.TemplateFileProvider
return {
  cache_key = function(opts)
    return get_makefile(opts)
  end,
  generator = function(opts, cb)
    if vim.fn.executable("make") == 0 then
      return 'Command "make" not found'
    end
    local makefile = get_makefile(opts)
    if not makefile then
      return "No Makefile found"
    end
    local cwd = vim.fs.dirname(makefile)

    local ret = {}
    overseer.builtin.system(
      { "make", "-rRpq" },
      {
        cwd = cwd,
        text = true,
        env = {
          ["LANG"] = "C.UTF-8",
        },
      },
      vim.schedule_wrap(function(out)
        if out.code ~= 0 and out.code ~= 1 then
          return cb(out.stderr or out.stdout or "Error running 'make'")
        end

        local parsing = false
        local prev_line = ""
        for line in vim.gsplit(out.stdout, "\n") do
          if line:find("# Files") == 1 then
            parsing = true
          elseif line:find("# Finished Make") == 1 then
            break
          elseif parsing then
            if line:match("^[^%.#%s]") and prev_line:find("# Not a target") ~= 1 then
              local idx = line:find(":")
              if idx then
                local target = line:sub(1, idx - 1)
                table.insert(ret, {
                  name = string.format("make %s", target),
                  builder = function(params)
                    return {
                      cmd = { "make", target },
                      args = params.args,
                      cwd = cwd,
                    }
                  end,
                })
              end
            end
          end
          prev_line = line
        end

        cb(ret)
      end)
    )
  end,
}
