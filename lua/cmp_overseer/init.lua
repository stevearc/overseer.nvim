local source = {}

function source.new()
  return setmetatable({}, { __index = source })
end

function source:is_available()
  return vim.bo.filetype == "OverseerForm"
end

source.get_position_encoding_kind = function()
  return "utf-8"
end

function source:get_keyword_pattern()
  return [[\w*]]
end

function source:complete(request, callback)
  local items = {}
  local ok, choices = pcall(vim.api.nvim_buf_get_var, 0, "overseer_choices")
  if ok and choices then
    for _, choice in ipairs(choices) do
      table.insert(items, {
        label = choice,
        kind = require("cmp").lsp.CompletionItemKind.Keyword,
      })
    end
  end
  callback({ items = items, isIncomplete = false })
end

return source
