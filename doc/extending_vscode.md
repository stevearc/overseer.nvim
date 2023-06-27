# Extending VS Code tasks

VS Code extensions can add new task types, problem matchers, and patterns. This document explains how you can do the same with overseer.

## Task types

To define a custom task type, simply add a new module to the neovim path. For a new type called "cowsay", you would add it to `lua/overseer/template/vscode/provider/cowsay.lua`. The format of the module is as follows:

```lua
-- lua/overseer/template/vscode/provider/cowsay.lua
local M = {}

---@param defn table This is the decoded JSON data for the task
---@return table
M.get_task_opts = function(defn)
  return {
    -- cmd is required. It can be a string or list of strings.
    cmd = vim.list_extend({"cowsay"}, defn.words)
    -- Optional working directory for task
    cwd = nil,
    -- Optionally specify environment variables for the task
    env = nil,
    -- Can override the problem matcher in the task definition
    problem_matcher = nil,
  }
end

return M
```

You can see how the existing task types were implemented in the [overseer/template/vscode/provider](../lua/overseer/template/vscode/provider) folder.

## Problem matchers and patterns

See the [VSCode docs for defining a problem matcher](https://code.visualstudio.com/docs/editor/tasks#_defining-a-problem-matcher). These can be defined in your provider module as well.

```lua
-- lua/overseer/template/vscode/provider/cowsay.lua
local M = {}

M.get_task_opts = function(defn)
  -- ...
end

M.problem_patterns = {
  -- This will provide the problem matcher pattern '$my-pat'
  ["$my-pat"] = {
    -- Note that the regexp is a vim-flavored regex with "very magic" enabled (:help magic)
    regexp = "^\\s*(.*):(\\d+) (.+)$",
    -- You can alternately specify an explicit vim-flavored regex
    vim_regexp = "\\v^\\s*(.*):(\\d+) (.+)$",
    kind = "location",
    file = 1,
    line = 2,
    message = 3,
  }
}

M.problem_matchers = {
  -- This will provide the problem matcher '$my-match'
  ["$my-match"] = {
    fileLocation = { "relative", "${cwd}" },
    pattern = "$my-pat",
  }
}

return M
```

You can see the existing patterns and problem matchers in [problem_matcher.lua](../lua/overseer/template/vscode/problem_matcher.lua)
