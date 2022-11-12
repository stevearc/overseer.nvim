local M = {}

---Create a list of nodes that will parse repeating "watch" command output (e.g. tsc --watch)
---@param start_pat string Pattern that matches when we should start extracting
---@param end_pat string Pattern that matches when we should finish extracting
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
  local seq = {
    {
      "always", -- When the loop exits, proceed to the next node
      {
        "loop", -- Extract errors until exit
        {
          "parallel",
          {
            "invert", -- Exit the loop when we detect the end of the output
            { "test", end_pat },
          },
          {
            "always", -- Don't exit the loop if extraction fails
            extraction,
          },
          -- Prevent spin-looping when extraction fails
          { "skip_until", end_pat },
        },
      },
    },
    { "dispatch", "set_results" },
  }
  local reset_seq = {
    {
      "skip_until", -- Ignore output until we see that the command has restarted
      { skip_matching_line = true },
      start_pat,
    },
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
