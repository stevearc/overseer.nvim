# Extending VS Code tasks

VS Code extensions can add new task types, problem matchers, and patterns. This document explains how you can do the same with overseer.

## Task types

To define a custom task type, simply add a new module to the neovim path. For a new type called "cowsay", you would add it to `lua/overseer/template/vscode/provider/cowsay.lua`. The format of the module is as follows:

```lua
-- lua/overseer/template/vscode/provider/cowsay.lua
local M = {}

---@param defn table This is the decoded JSON data for the task
---@return string[] The shell command to run
M.get_cmd = function(defn)
  return vim.list_extend({"cowsay"}, defn.words)
end

return M
```

You can see how the existing task types were implemented in the [overseer/template/vscode/provider](../lua/overseer/template/vscode/provider) folder.

## Problem matchers and patterns

See the [VSCode docs for defining a problem matcher](https://code.visualstudio.com/docs/editor/tasks#_defining-a-problem-matcher). To add a new matcher or pattern you will need to call the appropriate register method.

```lua
local problem_matcher = require("overseer.template.vscode.problem_matcher")

problem_matcher.register_pattern("$mypat", {
  -- Note that the regexp is a vim-flavored regex with "very magic" enabled (:help magic)
  regexp = "^\\s*(.*):(\\d+) (.+)$",
  kind = "location",
  file = 1,
  line = 2,
  message = 3,
})

problem_matcher.register_problem_matcher('$mymatch', {
  fileLocation = { "relative", "${cwd}" },
  pattern = "$mypat",
})
```

You can see the existing patterns and problem matchers in [problem_matcher.lua](../lua/overseer/template/vscode/problem_matcher.lua)
