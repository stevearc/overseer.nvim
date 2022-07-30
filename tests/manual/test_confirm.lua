require("overseer.confirm")({
  message = "Please confirm",
  choices = {
    "Stove",
    "O&ven",
    "Gril&l",
  },
  default = 3,
  type = "W",
}, function(index)
  vim.notify(string.format("Chose: %s", index))
end)
