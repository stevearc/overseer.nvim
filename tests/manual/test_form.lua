local form = require("overseer.form")

local schema = {
  required_str = { desc = "This is a required param" },
  optional_str = { desc = "This is an optional param", type = "string", optional = true },
  password_str = {
    desc = "This is a concealed param",
    type = "string",
    optional = true,
    conceal = true,
  },
  default_str = { desc = "This has a default", type = "string", default = "foobar" },
  required_num = { desc = "This is a required number param", type = "number" },
  optional_num = {
    desc = "This is an optional number param",
    type = "number",
    optional = true,
  },
  required_list = { desc = "This is a required list param", type = "list" },
  optional_list = {
    desc = "This is an optional list param",
    type = "list",
    optional = true,
  },
  required_bool = { desc = "This is a required boolean param", type = "boolean" },
  optional_bool = {
    desc = "This is an optional boolean param",
    type = "boolean",
    optional = true,
  },
  optional_enum = {
    desc = "This is an optional enum param",
    type = "enum",
    optional = true,
    choices = { "first", "second", "third" },
  },
}

form.open("Test form", schema, {}, function(params)
  vim.notify(vim.inspect(params))
end)
