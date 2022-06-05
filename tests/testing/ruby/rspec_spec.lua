local integration = require("overseer.testing.ruby.rspec")
local test_utils = require("tests.testing.integration_test_utils")

describe("ruby_rspec", function()
  it("parses test failures", function()
    local output = [[
{  "version": "3.11.0",  "examples": [    {      "id": "./spec/rspec_test_spec.rb[1:1]",      "description": "should succeed",      "full_description": "RspecTest should succeed",      "status": "passed",      "file_path": "./spec/rspec_test_spec.rb",      "line_number": 12,      "run_time": 1.001458319,      "pending_message": null    },    {      "id": "./spec/rspec_test_spec.rb[1:2]",      "description": "should fail",      "full_description": "RspecTest should fail",      "status": "failed",      "file_path": "./spec/rspec_test_spec.rb",      "line_number": 16,      "run_time": 1.032808515,      "pending_message": null,      "exception": {        "class": "RSpec::Expectations::ExpectationNotMetError",        "message": "\nexpected: true\n     got: false\n\n(compared using ==)\n\nDiff:\u001b[0m\n\u001b[0m\u001b[34m@@ -1 +1 @@\n\u001b[0m\u001b[31m-true\n\u001b[0m\u001b[32m+false\n\u001b[0m",        "backtrace": [          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-support-3.11.0/lib/rspec/support.rb:102:in `block in <module:Support>'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-support-3.11.0/lib/rspec/support.rb:111:in `notify_failure'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-expectations-3.11.0/lib/rspec/expectations/fail_with.rb:35:in `fail_with'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-expectations-3.11.0/lib/rspec/expectations/handler.rb:38:in `handle_failure'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-expectations-3.11.0/lib/rspec/expectations/handler.rb:56:in `block in handle_matcher'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-expectations-3.11.0/lib/rspec/expectations/handler.rb:27:in `with_matcher'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-expectations-3.11.0/lib/rspec/expectations/handler.rb:48:in `handle_matcher'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-expectations-3.11.0/lib/rspec/expectations/expectation_target.rb:65:in `to'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-expectations-3.11.0/lib/rspec/expectations/expectation_target.rb:101:in `to'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/spec/rspec_test_spec.rb:18:in `block (2 levels) in <top (required)>'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/example.rb:263:in `instance_exec'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/example.rb:263:in `block in run'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/example.rb:511:in `block in with_around_and_singleton_context_hooks'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/example.rb:468:in `block in with_around_example_hooks'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/hooks.rb:486:in `block in run'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/hooks.rb:624:in `run_around_example_hooks_for'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/hooks.rb:486:in `run'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/example.rb:468:in `with_around_example_hooks'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/example.rb:511:in `with_around_and_singleton_context_hooks'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/example.rb:259:in `run'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/example_group.rb:646:in `block in run_examples'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/example_group.rb:642:in `map'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/example_group.rb:642:in `run_examples'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/example_group.rb:607:in `run'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/runner.rb:121:in `block (3 levels) in run_specs'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/runner.rb:121:in `map'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/runner.rb:121:in `block (2 levels) in run_specs'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/configuration.rb:2068:in `with_suite_hooks'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/runner.rb:116:in `block in run_specs'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/reporter.rb:74:in `report'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/runner.rb:115:in `run_specs'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/runner.rb:89:in `run'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/runner.rb:71:in `run'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/runner.rb:45:in `invoke'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/exe/rspec:4:in `<top (required)>'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/bin/rspec:23:in `load'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/bin/rspec:23:in `<main>'"        ]      }    },    {      "id": "./spec/rspec_test_spec.rb[1:3]",      "description": "should error",      "full_description": "RspecTest should error",      "status": "failed",      "file_path": "./spec/rspec_test_spec.rb",      "line_number": 21,      "run_time": 1.000697017,      "pending_message": null,      "exception": {        "class": "NameError",        "message": "undefined local variable or method `baz' for #<RSpec::ExampleGroups::RspecTest:0x000055c87befb228>\nDid you mean?  bar",        "backtrace": [          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-expectations-3.11.0/lib/rspec/matchers.rb:965:in `method_missing'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/example_group.rb:767:in `method_missing'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/spec/rspec_test_spec.rb:8:in `bar'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/spec/rspec_test_spec.rb:4:in `foo'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/spec/rspec_test_spec.rb:23:in `block (2 levels) in <top (required)>'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/example.rb:263:in `instance_exec'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/example.rb:263:in `block in run'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/example.rb:511:in `block in with_around_and_singleton_context_hooks'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/example.rb:468:in `block in with_around_example_hooks'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/hooks.rb:486:in `block in run'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/hooks.rb:624:in `run_around_example_hooks_for'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/hooks.rb:486:in `run'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/example.rb:468:in `with_around_example_hooks'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/example.rb:511:in `with_around_and_singleton_context_hooks'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/example.rb:259:in `run'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/example_group.rb:646:in `block in run_examples'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/example_group.rb:642:in `map'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/example_group.rb:642:in `run_examples'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/example_group.rb:607:in `run'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/runner.rb:121:in `block (3 levels) in run_specs'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/runner.rb:121:in `map'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/runner.rb:121:in `block (2 levels) in run_specs'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/configuration.rb:2068:in `with_suite_hooks'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/runner.rb:116:in `block in run_specs'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/reporter.rb:74:in `report'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/runner.rb:115:in `run_specs'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/runner.rb:89:in `run'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/runner.rb:71:in `run'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/runner.rb:45:in `invoke'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/exe/rspec:4:in `<top (required)>'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/bin/rspec:23:in `load'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/bin/rspec:23:in `<main>'"        ]      }    },    {      "id": "./spec/rspec_test_spec.rb[1:4]",      "description": "should skip",      "full_description": "RspecTest should skip",      "status": "pending",      "file_path": "./spec/rspec_test_spec.rb",      "line_number": 26,      "run_time": 1.001530495,      "pending_message": "No reason given"    },    {      "id": "./spec/rspec_test_spec.rb[1:5]",      "description": "should show test output",      "full_description": "RspecTest should show test output",      "status": "failed",      "file_path": "./spec/rspec_test_spec.rb",      "line_number": 31,      "run_time": 1.002393734,      "pending_message": null,      "exception": {        "class": "RSpec::Expectations::ExpectationNotMetError",        "message": "\nexpected: true\n     got: false\n\n(compared using ==)\n\nDiff:\u001b[0m\n\u001b[0m\u001b[34m@@ -1 +1 @@\n\u001b[0m\u001b[31m-true\n\u001b[0m\u001b[32m+false\n\u001b[0m",        "backtrace": [          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-support-3.11.0/lib/rspec/support.rb:102:in `block in <module:Support>'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-support-3.11.0/lib/rspec/support.rb:111:in `notify_failure'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-expectations-3.11.0/lib/rspec/expectations/fail_with.rb:35:in `fail_with'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-expectations-3.11.0/lib/rspec/expectations/handler.rb:38:in `handle_failure'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-expectations-3.11.0/lib/rspec/expectations/handler.rb:56:in `block in handle_matcher'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-expectations-3.11.0/lib/rspec/expectations/handler.rb:27:in `with_matcher'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-expectations-3.11.0/lib/rspec/expectations/handler.rb:48:in `handle_matcher'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-expectations-3.11.0/lib/rspec/expectations/expectation_target.rb:65:in `to'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-expectations-3.11.0/lib/rspec/expectations/expectation_target.rb:101:in `to'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/spec/rspec_test_spec.rb:34:in `block (2 levels) in <top (required)>'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/example.rb:263:in `instance_exec'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/example.rb:263:in `block in run'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/example.rb:511:in `block in with_around_and_singleton_context_hooks'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/example.rb:468:in `block in with_around_example_hooks'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/hooks.rb:486:in `block in run'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/hooks.rb:624:in `run_around_example_hooks_for'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/hooks.rb:486:in `run'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/example.rb:468:in `with_around_example_hooks'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/example.rb:511:in `with_around_and_singleton_context_hooks'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/example.rb:259:in `run'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/example_group.rb:646:in `block in run_examples'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/example_group.rb:642:in `map'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/example_group.rb:642:in `run_examples'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/example_group.rb:607:in `run'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/runner.rb:121:in `block (3 levels) in run_specs'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/runner.rb:121:in `map'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/runner.rb:121:in `block (2 levels) in run_specs'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/configuration.rb:2068:in `with_suite_hooks'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/runner.rb:116:in `block in run_specs'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/reporter.rb:74:in `report'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/runner.rb:115:in `run_specs'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/runner.rb:89:in `run'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/runner.rb:71:in `run'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/lib/rspec/core/runner.rb:45:in `invoke'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/gems/rspec-core-3.11.0/exe/rspec:4:in `<top (required)>'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/bin/rspec:23:in `load'",          "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/bin/rspec:23:in `<main>'"        ]      }    }  ],  "summary": {    "duration": 5.040541935,    "example_count": 5,    "failure_count": 3,    "pending_count": 1,    "errors_outside_of_examples_count": 0  },  "summary_line": "5 examples, 3 failures, 1 pending"}
]]
    local results = test_utils.run_parser(integration, output)

    assert.are.same({
      tests = {
        {
          duration = 1.001458319,
          filename = "./spec/rspec_test_spec.rb",
          id = "RspecTest should succeed",
          lnum = 12,
          name = "should succeed",
          path = { "RspecTest" },
          status = "SUCCESS",
        },
        {
          duration = 1.032808515,
          filename = "./spec/rspec_test_spec.rb",
          id = "RspecTest should fail",
          lnum = 16,
          name = "should fail",
          path = { "RspecTest" },
          stacktrace = {
            {
              filename = "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/spec/rspec_test_spec.rb",
              lnum = "18",
              text = "in `block (2 levels) in <top (required)>'",
            },
            {
              filename = "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/bin/rspec",
              lnum = "23",
              text = "in `load'",
            },
            {
              filename = "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/bin/rspec",
              lnum = "23",
              text = "in `<main>'",
            },
          },
          status = "FAILURE",
          text = "RSpec::Expectations::ExpectationNotMetError\n\nexpected: true\n     got: false\n\n(compared using ==)\n\nDiff:\n@@ -1 +1 @@\n-true\n+false\n",
        },
        {
          duration = 1.000697017,
          filename = "./spec/rspec_test_spec.rb",
          id = "RspecTest should error",
          lnum = 21,
          name = "should error",
          path = { "RspecTest" },
          stacktrace = {
            {
              filename = "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/spec/rspec_test_spec.rb",
              lnum = "8",
              text = "in `bar'",
            },
            {
              filename = "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/spec/rspec_test_spec.rb",
              lnum = "4",
              text = "in `foo'",
            },
            {
              filename = "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/spec/rspec_test_spec.rb",
              lnum = "23",
              text = "in `block (2 levels) in <top (required)>'",
            },
            {
              filename = "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/bin/rspec",
              lnum = "23",
              text = "in `load'",
            },
            {
              filename = "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/bin/rspec",
              lnum = "23",
              text = "in `<main>'",
            },
          },
          status = "FAILURE",
          text = "NameError\nundefined local variable or method `baz' for #<RSpec::ExampleGroups::RspecTest:0x000055c87befb228>\nDid you mean?  bar",
        },
        {
          duration = 1.001530495,
          filename = "./spec/rspec_test_spec.rb",
          id = "RspecTest should skip",
          lnum = 26,
          name = "should skip",
          path = { "RspecTest" },
          status = "SKIPPED",
          text = "No reason given",
        },
        {
          duration = 1.002393734,
          filename = "./spec/rspec_test_spec.rb",
          id = "RspecTest should show test output",
          lnum = 31,
          name = "should show test output",
          path = { "RspecTest" },
          stacktrace = {
            {
              filename = "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/spec/rspec_test_spec.rb",
              lnum = "34",
              text = "in `block (2 levels) in <top (required)>'",
            },
            {
              filename = "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/bin/rspec",
              lnum = "23",
              text = "in `load'",
            },
            {
              filename = "/home/stevearc/ws/overseer-test-frameworks/ruby/rspec/bundle/ruby/2.7.0/bin/rspec",
              lnum = "23",
              text = "in `<main>'",
            },
          },
          status = "FAILURE",
          text = "RSpec::Expectations::ExpectationNotMetError\n\nexpected: true\n     got: false\n\n(compared using ==)\n\nDiff:\n@@ -1 +1 @@\n-true\n+false\n",
        },
      },
    }, results)
  end)
end)
