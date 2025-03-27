---@type overseer.TemplateFileProvider
return {
  generator = function(opts)
    if vim.fn.executable("cargo-make") == 0 then
      return 'Command "cargo-make" not found'
    end
    local cargo_make_file =
      vim.fs.find("Makefile.toml", { upward = true, type = "file", path = opts.dir })[1]
    if not cargo_make_file then
      return 'No "Makefile.toml" file found'
    end
    local ret = {}

    local cargo_make_file_dir = vim.fs.dirname(cargo_make_file)

    local file = io.open(cargo_make_file, "r")
    if not file then
      return "Failed to read Makefile.toml file"
    end

    for s in file:lines() do
      local _, _, task_name = string.find(s, "^%[tasks%.(.+)%]$")
      if task_name ~= nil then
        table.insert(ret, {
          name = string.format("cargo-make %s", task_name),
          builder = function()
            return {
              cmd = { "cargo-make", "make", task_name },
              cwd = cargo_make_file_dir,
            }
          end,
        })
      end
    end
    file:close()

    return ret
  end,
}
