---@param opts overseer.SearchParams
---@return nil|string
local function get_mix_file(opts)
  return vim.fs.find("mix.exs", { upward = true, type = "file", path = opts.dir })[1]
end

---@type overseer.TemplateFileProvider
return {
  cache_key = function(opts)
    return get_mix_file(opts)
  end,
  generator = function(opts, cb)
    -- mix will not return all the tasks unless you invoke it in the mix.exs folder
    local mix_file = get_mix_file(opts)
    if not mix_file then
      return "No mix.exs file found"
    end
    local mix_folder = vim.fs.dirname(mix_file)
    local ret = {}
    vim.system(
      { "mix", "help" },
      {
        cwd = mix_folder,
        text = true,
      },
      vim.schedule_wrap(function(out)
        if out.code ~= 0 then
          return cb(out.stderr or out.stdout or "Error running 'mix help'")
        end
        for line in vim.gsplit(out.stdout, "\n") do
          local task_name = line:match("mix (%S+)%s")
          table.insert(ret, {
            name = string.format("mix %s", task_name),
            builder = function()
              return {
                cmd = { "mix", task_name },
              }
            end,
          })
        end
      end)
    )
  end,
}
