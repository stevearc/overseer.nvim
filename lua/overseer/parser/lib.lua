local M = {}

---Create a list of nodes that will parse repeating "watch" command output (e.g. tsc --watch)
---@param start_pat string|table Pattern or {opts, pattern} table that matches when we should start extracting
---@param end_pat string Pattern or {opts, pattern} table that matches when we should finish extracting
---@param opts table
---    wrap boolean If true, wrap the resulting parser in a loop->sequence
---    active_on_start boolean When false, require start_pat to match before parsing errors
---    only_clear_results_key boolean When true, only clear the current results key
---@return table
M.watcher_output = function(start_pat, end_pat, extraction, opts)
  opts = vim.tbl_extend("keep", opts or {}, {
    wrap = false,
    active_on_start = true,
    only_clear_results_key = false,
  })
  local end_test
  if type(end_pat) == "table" then
    end_test = { "test", unpack(end_pat) }
  else
    end_test = { "test", end_pat }
  end
  local skip_until_start
  if type(start_pat) == "table" then
    local start_opts, pat = unpack(start_pat)
    start_opts.skip_matching_line = true
    skip_until_start = { "skip_until", start_opts, pat }
  else
    skip_until_start = { "skip_until", { skip_matching_line = true }, start_pat }
  end
  local seq = {
    {
      "always", -- When the loop exits, proceed to the next node
      {
        "loop", -- Extract errors until exit
        {
          "parallel",
          {
            "invert", -- Exit the loop when we detect the end of the output
            end_test,
          },
          {
            "always", -- Don't exit the loop if extraction fails
            extraction,
          },
          -- Prevent spin-looping when extraction fails
          { "skip_lines", 1 },
        },
      },
    },
    { "dispatch", "set_results" },
  }
  local reset_seq = {
    skip_until_start,
    { "dispatch", "clear_results", opts.only_clear_results_key },
  }
  if opts.active_on_start then
    vim.list_extend(seq, reset_seq)
  else
    vim.list_extend(reset_seq, seq)
    seq = reset_seq
  end

  if opts.wrap then
    table.insert(seq, 1, "sequence")
    seq = { "loop", seq }
  end
  return seq
end

return M
