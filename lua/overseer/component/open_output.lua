local constants = require("overseer.constants")
local STATUS = constants.STATUS

---@param task overseer.Task
---@param direction "dock"|"float"|"tab"|"vertical"|"horizontal"
---@param focus boolean
local function open_output(task, direction, focus)
  if direction == "dock" then
    local window = require("overseer.window")
    window.open({
      direction = "bottom",
      enter = focus,
      focus_task_id = task.id,
    })
  else
    local winid = vim.api.nvim_get_current_win()
    ---@cast direction "float"|"tab"|"vertical"|"horizontal"
    task:open_output(direction)
    if not focus then
      vim.api.nvim_set_current_win(winid)
    end
  end
end

---@type overseer.ComponentFileDefinition
return {
  desc = "Open task output",
  params = {
    on_start = {
      desc = "Open the output when the task starts",
      type = "enum",
      choices = { "always", "never", "if_no_on_output_quickfix" },
      default = "if_no_on_output_quickfix",
      long_desc = "The 'if_no_on_output_quickfix' option will open the task output on start unless the task has the 'on_output_quickfix' component attached.",
    },
    on_complete = {
      desc = "Open the output when the task completes",
      type = "enum",
      choices = { "always", "never", "success", "failure" },
      default = "never",
    },
    on_result = {
      desc = "Open the output when the task produces a result",
      type = "enum",
      choices = { "always", "never", "if_diagnostics" },
      default = "never",
    },
    direction = {
      desc = "Where to open the task output",
      type = "enum",
      choices = { "dock", "float", "tab", "vertical", "horizontal" },
      default = "dock",
      long_desc = "The 'dock' option will open the output docked to the bottom next to the task list.",
    },
    focus = {
      desc = "Focus the output window when it is opened",
      type = "boolean",
      default = false,
    },
    close_on_reset = {
      desc = "Delete the output buffer when the task is reset",
      type = "boolean",
      default = false,
    },
  },
  constructor = function(params)
    -- backwards compatibility
    if params.on_start == true then
      params.on_start = "always"
    elseif params.on_start == false then
      params.on_start = "never"
    end
    ---@type overseer.ComponentSkeleton
    local methods = {}
    local bufnr

    if params.on_start ~= "never" then
      methods.on_start = function(_, task)
        if
          params.on_start == "always"
          or (
            params.on_start == "if_no_on_output_quickfix"
            and not task:has_component("on_output_quickfix")
          )
        then
          open_output(task, params.direction, params.focus)
        end
      end
    end

    if params.on_result ~= "never" then
      methods.on_result = function(_, task, result)
        if
          params.on_result == "always"
          or (
            params.on_result == "if_diagnostics" and not vim.tbl_isempty(result.diagnostics or {})
          )
        then
          open_output(task, params.direction, params.focus)
        end
      end
    end

    if params.on_complete ~= "never" then
      methods.on_complete = function(_, task, status)
        if
          params.on_complete == "always"
          or (params.on_complete == "success" and status == STATUS.SUCCESS)
          or (params.on_complete == "failure" and status == STATUS.FAILURE)
        then
          open_output(task, params.direction, params.focus)
        end
      end
    end

    if params.close_on_reset then
      methods.on_exit = function(_, task)
        bufnr = task:get_bufnr()
      end

      methods.on_reset = function()
        if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
          vim.api.nvim_buf_delete(bufnr, { force = true })
        end
        bufnr = nil
      end
    end

    return methods
  end,
}
