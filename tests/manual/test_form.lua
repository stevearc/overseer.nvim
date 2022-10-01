local overseer = require("overseer")

local schema = {
  required_str = { desc = "This is a required param" },
  optional_str = { desc = "This is an optional param", type = "string", optional = true },
  default_str = { desc = "This has a default", type = "string", default = "foobar" },
  required_num = { desc = "This is a required number param", type = "number" },
  optional_num = {
    desc = "This is an optional number param",
    type = "number",
    optional = true,
  },
  required_list = { desc = "This is a required number param", type = "list" },
  optional_list = {
    desc = "This is an optional number param",
    type = "list",
    optional = true,
  },
  required_bool = { desc = "This is a required number param", type = "boolean" },
  optional_bool = {
    desc = "This is an optional number param",
    type = "boolean",
    optional = true,
  },
}

overseer.form.open("Test template builder", schema, {}, function(params)
  vim.notify(vim.inspect(params))
end)
