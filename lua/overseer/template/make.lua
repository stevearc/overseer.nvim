---@param opts overseer.SearchParams
---@return nil|string
local function get_makefile(opts)
  return vim.fs.find("Makefile", { upward = true, type = "file", path = opts.dir })[1]
end

---@type overseer.TemplateFileProvider
local provider = {
  cache_key = function(opts)
    return get_makefile(opts)
  end,
  condition = {
    callback = function(opts)
      if vim.fn.executable("make") == 0 then
        return false, 'Command "make" not found'
      end
      if not get_makefile(opts) then
        return false, "No Makefile found"
      end
      return true
    end,
  },
  generator = function(opts, cb)
    local makefile = assert(get_makefile(opts))
    local cwd = vim.fs.dirname(makefile)

    local ret = {}
    vim.system(
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
          return cb({})
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
return provider
