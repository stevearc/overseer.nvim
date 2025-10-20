local files = require("overseer.files")

---@type overseer.TemplateFileProvider
return {
  generator = function(opts)
    if vim.fn.executable("composer") == 0 then
      return "executable composer not found"
    end
    local package =
      vim.fs.find("composer.json", { upward = true, type = "file", path = opts.dir })[1]
    if not package then
      return "No composer.json file found"
    end
    local data = files.load_json_file(package)
    local ret = {}
    local scripts = data.scripts
    if not scripts or vim.tbl_isempty(scripts) then
      return "No scripts in composer.json"
    end
    local cwd = vim.fs.dirname(package)

    for k in pairs(scripts) do
      table.insert(ret, {
        name = string.format("composer %s", k),
        builder = function()
          return {
            cmd = { "composer", "run-script", k },
            cwd = cwd,
          }
        end,
      })
    end
    return ret
  end,
}
