local overseer = require("overseer")

local schema = {
  required_str = { description = "This is a required param" },
  optional_str = { description = "This is an optional param", type = "string", optional = true },
  default_str = { description = "This has a default", type = "string", default = "foobar" },
  required_num = { description = "This is a required number param", type = "number" },
  optional_num = {
    description = "This is an optional number param",
    type = "number",
    optional = true,
  },
  required_list = { description = "This is a required number param", type = "list" },
  optional_list = {
    description = "This is an optional number param",
    type = "list",
    optional = true,
  },
  required_bool = { description = "This is a required number param", type = "bool" },
  optional_bool = {
    description = "This is an optional number param",
    type = "bool",
    optional = true,
  },
}

overseer.form.show("Test form", schema, {}, function(params)
  vim.notify(vim.inspect(params))
end)
