local files = require("overseer.files")

---@type overseer.TemplateFileProvider
return {
  generator = function(opts)
    if vim.fn.executable("deno") == 0 then
      return "executable deno not found"
    end
    local deno_json = { "deno.json", "deno.jsonc" }
    local package = vim.fs.find(deno_json, { upward = true, type = "file", path = opts.dir })[1]
    if not package then
      return "No deno.{json,jsonc} file found"
    end
    local package_dir = vim.fs.dirname(package)
    local data = files.load_json_file(package)
    local ret = {}
    local tasks = data.tasks
    if not tasks or vim.tbl_isempty(tasks) then
      return "no tasks found in deno json file"
    end
    for k in pairs(tasks) do
      table.insert(ret, {
        name = string.format("deno %s", k),
        builder = function()
          return {
            cmd = { "deno", "task", k },
            cwd = package_dir,
          }
        end,
      })
    end
    return ret
  end,
}
