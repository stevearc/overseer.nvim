local data = require("overseer.testing.data")
local TEST_STATUS = data.TEST_STATUS
local M = {}

M.on_init_reset_tests = {
  name = "on_init_reset_tests",
  description = "Reset test status on init",
  params = {
    dirname = { optional = true },
    group = { type = "list", optional = true },
    tests = { type = "opaque", optional = true },
  },
  constructor = function(params)
    local function do_reset(task)
      local integration = task.metadata.test_integration
      if params.dirname then
        data.reset_dir_results(params.dirname, TEST_STATUS.RUNNING)
      elseif params.group then
        data.reset_group_status(integration, params.group, TEST_STATUS.RUNNING)
      elseif params.tests then
        for _, test in ipairs(params.tests) do
          data.reset_test_status(integration, test, TEST_STATUS.RUNNING)
        end
      end
      data.touch()
    end
    return {
      on_init = function(self, task)
        do_reset(task)
      end,
      on_reset = function(self, task)
        do_reset(task)
      end,
    }
  end,
}

M.on_result_report_tests = {
  name = "on_result_report_tests",
  description = "Report all test results",
  params = {},
  constructor = function(params)
    return {
      on_stream_result = function(self, task, key, result)
        local integration_name = task.metadata.test_integration
        require("overseer.testing.data").add_test_result(integration_name, key, result)
      end,
      on_result = function(self, task, status, result)
        local integration_name = task.metadata.test_integration
        require("overseer.testing.data").set_test_results(integration_name, result)
      end,
    }
  end,
}

return M
