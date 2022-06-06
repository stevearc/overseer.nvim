local files = require("overseer.files")
local integration = require("overseer.testing.javascript.jest")
local parser = require("overseer.parser")

describe("javascript_jest", function()
  it("parses test failures", function()
    local output = [[
{
  "numFailedTestSuites": 1,
  "numFailedTests": 3,
  "numPassedTestSuites": 1,
  "numPassedTests": 1,
  "numPendingTestSuites": 0,
  "numPendingTests": 1,
  "numRuntimeErrorTestSuites": 0,
  "numTodoTests": 0,
  "numTotalTestSuites": 2,
  "numTotalTests": 5,
  "openHandles": [],
  "snapshot": {
    "added": 0,
    "didUpdate": false,
    "failure": false,
    "filesAdded": 0,
    "filesRemoved": 0,
    "filesRemovedList": [],
    "filesUnmatched": 0,
    "filesUpdated": 0,
    "matched": 0,
    "total": 0,
    "unchecked": 0,
    "uncheckedKeysByFile": [],
    "unmatched": 0,
    "updated": 0
  },
  "startTime": 1654527206254,
  "success": false,
  "testResults": [
    {
      "assertionResults": [
        {
          "ancestorTitles": ["more jest tests", "that are nested"],
          "duration": 208,
          "failureMessages": [
            "Error: \u001b[2mexpect(\u001b[22m\u001b[31mreceived\u001b[39m\u001b[2m).\u001b[22mtoBe\u001b[2m(\u001b[22m\u001b[32mexpected\u001b[39m\u001b[2m) // Object.is equality\u001b[22m\n\nExpected: \u001b[32m3\u001b[39m\nReceived: \u001b[31m1\u001b[39m\n    at Object.toBe (/home/stevearc/ws/overseer-test-frameworks/javascript/jest/other_sample.test.js:21:17)"
          ],
          "fullName": "more jest tests that are nested should show test output",
          "location": null,
          "status": "failed",
          "title": "should show test output"
        },
        {
          "ancestorTitles": ["more jest tests", "other nested"],
          "duration": 200,
          "failureMessages": [
            "ReferenceError: baz is not defined\n    at baz (/home/stevearc/ws/overseer-test-frameworks/javascript/jest/other_sample.test.js:8:3)\n    at bar (/home/stevearc/ws/overseer-test-frameworks/javascript/jest/other_sample.test.js:12:3)\n    at Object.foo (/home/stevearc/ws/overseer-test-frameworks/javascript/jest/other_sample.test.js:27:7)"
          ],
          "fullName": "more jest tests other nested should error",
          "location": null,
          "status": "failed",
          "title": "should error"
        },
        {
          "ancestorTitles": ["more jest tests"],
          "duration": 201,
          "failureMessages": [
            "Error: \u001b[2mexpect(\u001b[22m\u001b[31mreceived\u001b[39m\u001b[2m).\u001b[22mtoBe\u001b[2m(\u001b[22m\u001b[32mexpected\u001b[39m\u001b[2m) // Object.is equality\u001b[22m\n\nExpected: \u001b[32m3\u001b[39m\nReceived: \u001b[31m1\u001b[39m\n    at Object.toBe (/home/stevearc/ws/overseer-test-frameworks/javascript/jest/other_sample.test.js:32:15)"
          ],
          "fullName": "more jest tests should fail",
          "location": null,
          "status": "failed",
          "title": "should fail"
        }
      ],
      "endTime": 1654527207070,
      "message": "\u001b[1m\u001b[31m  \u001b[1m● \u001b[22m\u001b[1mmore jest tests › that are nested › should show test output\u001b[39m\u001b[22m\n\n    \u001b[2mexpect(\u001b[22m\u001b[31mreceived\u001b[39m\u001b[2m).\u001b[22mtoBe\u001b[2m(\u001b[22m\u001b[32mexpected\u001b[39m\u001b[2m) // Object.is equality\u001b[22m\n\n    Expected: \u001b[32m3\u001b[39m\n    Received: \u001b[31m1\u001b[39m\n\u001b[2m\u001b[22m\n\u001b[2m    \u001b[0m \u001b[90m 19 |\u001b[39m       console\u001b[33m.\u001b[39merror(\u001b[32m\"This is err output\"\u001b[39m)\u001b[33m;\u001b[39m\u001b[0m\u001b[22m\n\u001b[2m    \u001b[0m \u001b[90m 20 |\u001b[39m       \u001b[36mawait\u001b[39m sleep(\u001b[35m200\u001b[39m)\u001b[33m;\u001b[39m\u001b[0m\u001b[22m\n\u001b[2m    \u001b[0m\u001b[31m\u001b[1m>\u001b[22m\u001b[2m\u001b[39m\u001b[90m 21 |\u001b[39m       expect(\u001b[35m1\u001b[39m)\u001b[33m.\u001b[39mtoBe(\u001b[35m3\u001b[39m)\u001b[33m;\u001b[39m\u001b[0m\u001b[22m\n\u001b[2m    \u001b[0m \u001b[90m    |\u001b[39m                 \u001b[31m\u001b[1m^\u001b[22m\u001b[2m\u001b[39m\u001b[0m\u001b[22m\n\u001b[2m    \u001b[0m \u001b[90m 22 |\u001b[39m     })\u001b[33m;\u001b[39m\u001b[0m\u001b[22m\n\u001b[2m    \u001b[0m \u001b[90m 23 |\u001b[39m   })\u001b[33m;\u001b[39m\u001b[0m\u001b[22m\n\u001b[2m    \u001b[0m \u001b[90m 24 |\u001b[39m   describe(\u001b[32m\"other nested\"\u001b[39m\u001b[33m,\u001b[39m () \u001b[33m=>\u001b[39m {\u001b[0m\u001b[22m\n\u001b[2m\u001b[22m\n\u001b[2m      \u001b[2mat Object.toBe (\u001b[22m\u001b[2m\u001b[0m\u001b[36mother_sample.test.js\u001b[39m\u001b[0m\u001b[2m:21:17)\u001b[22m\u001b[2m\u001b[22m\n\n\u001b[1m\u001b[31m  \u001b[1m● \u001b[22m\u001b[1mmore jest tests › other nested › should error\u001b[39m\u001b[22m\n\n    ReferenceError: baz is not defined\n\u001b[2m\u001b[22m\n\u001b[2m    \u001b[0m \u001b[90m  6 |\u001b[39m\u001b[0m\u001b[22m\n\u001b[2m    \u001b[0m \u001b[90m  7 |\u001b[39m \u001b[36mfunction\u001b[39m bar() {\u001b[0m\u001b[22m\n\u001b[2m    \u001b[0m\u001b[31m\u001b[1m>\u001b[22m\u001b[2m\u001b[39m\u001b[90m  8 |\u001b[39m   baz()\u001b[33m;\u001b[39m\u001b[0m\u001b[22m\n\u001b[2m    \u001b[0m \u001b[90m    |\u001b[39m   \u001b[31m\u001b[1m^\u001b[22m\u001b[2m\u001b[39m\u001b[0m\u001b[22m\n\u001b[2m    \u001b[0m \u001b[90m  9 |\u001b[39m }\u001b[0m\u001b[22m\n\u001b[2m    \u001b[0m \u001b[90m 10 |\u001b[39m\u001b[0m\u001b[22m\n\u001b[2m    \u001b[0m \u001b[90m 11 |\u001b[39m \u001b[36mfunction\u001b[39m foo() {\u001b[0m\u001b[22m\n\u001b[2m\u001b[22m\n\u001b[2m      \u001b[2mat baz (\u001b[22m\u001b[2m\u001b[0m\u001b[36mother_sample.test.js\u001b[39m\u001b[0m\u001b[2m:8:3)\u001b[22m\u001b[2m\u001b[22m\n\u001b[2m      \u001b[2mat bar (\u001b[22m\u001b[2m\u001b[0m\u001b[36mother_sample.test.js\u001b[39m\u001b[0m\u001b[2m:12:3)\u001b[22m\u001b[2m\u001b[22m\n\u001b[2m      \u001b[2mat Object.foo (\u001b[22m\u001b[2m\u001b[0m\u001b[36mother_sample.test.js\u001b[39m\u001b[0m\u001b[2m:27:7)\u001b[22m\u001b[2m\u001b[22m\n\n\u001b[1m\u001b[31m  \u001b[1m● \u001b[22m\u001b[1mmore jest tests › should fail\u001b[39m\u001b[22m\n\n    \u001b[2mexpect(\u001b[22m\u001b[31mreceived\u001b[39m\u001b[2m).\u001b[22mtoBe\u001b[2m(\u001b[22m\u001b[32mexpected\u001b[39m\u001b[2m) // Object.is equality\u001b[22m\n\n    Expected: \u001b[32m3\u001b[39m\n    Received: \u001b[31m1\u001b[39m\n\u001b[2m\u001b[22m\n\u001b[2m    \u001b[0m \u001b[90m 30 |\u001b[39m   test(\u001b[32m\"should fail\"\u001b[39m\u001b[33m,\u001b[39m \u001b[36masync\u001b[39m () \u001b[33m=>\u001b[39m {\u001b[0m\u001b[22m\n\u001b[2m    \u001b[0m \u001b[90m 31 |\u001b[39m     \u001b[36mawait\u001b[39m sleep(\u001b[35m200\u001b[39m)\u001b[33m;\u001b[39m\u001b[0m\u001b[22m\n\u001b[2m    \u001b[0m\u001b[31m\u001b[1m>\u001b[22m\u001b[2m\u001b[39m\u001b[90m 32 |\u001b[39m     expect(\u001b[35m1\u001b[39m)\u001b[33m.\u001b[39mtoBe(\u001b[35m3\u001b[39m)\u001b[33m;\u001b[39m\u001b[0m\u001b[22m\n\u001b[2m    \u001b[0m \u001b[90m    |\u001b[39m               \u001b[31m\u001b[1m^\u001b[22m\u001b[2m\u001b[39m\u001b[0m\u001b[22m\n\u001b[2m    \u001b[0m \u001b[90m 33 |\u001b[39m   })\u001b[33m;\u001b[39m\u001b[0m\u001b[22m\n\u001b[2m    \u001b[0m \u001b[90m 34 |\u001b[39m })\u001b[33m;\u001b[39m\u001b[0m\u001b[22m\n\u001b[2m    \u001b[0m \u001b[90m 35 |\u001b[39m\u001b[0m\u001b[22m\n\u001b[2m\u001b[22m\n\u001b[2m      \u001b[2mat Object.toBe (\u001b[22m\u001b[2m\u001b[0m\u001b[36mother_sample.test.js\u001b[39m\u001b[0m\u001b[2m:32:15)\u001b[22m\u001b[2m\u001b[22m\n",
      "name": "/home/stevearc/ws/overseer-test-frameworks/javascript/jest/other_sample.test.js",
      "startTime": 1654527206282,
      "status": "failed",
      "summary": ""
    },
    {
      "assertionResults": [
        {
          "ancestorTitles": ["jest tests"],
          "duration": 201,
          "failureMessages": [],
          "fullName": "jest tests should succeed",
          "location": null,
          "status": "passed",
          "title": "should succeed"
        },
        {
          "ancestorTitles": ["jest tests"],
          "duration": null,
          "failureMessages": [],
          "fullName": "jest tests should skip",
          "location": null,
          "status": "pending",
          "title": "should skip"
        }
      ],
      "endTime": 1654527207365,
      "message": "",
      "name": "/home/stevearc/ws/overseer-test-frameworks/javascript/jest/sample.test.js",
      "startTime": 1654527207096,
      "status": "passed",
      "summary": ""
    }
  ],
  "wasInterrupted": false
}
]]
    local filename = files.gen_random_filename("cache", "test_jest_spec_%d.json")
    local fake_task = { metadata = { output_file = filename } }
    files.write_file(filename, output)

    local defn = integration.parser(fake_task)
    local p = parser.new(defn)
    local results = p:get_result()

    assert.are.same({
      tests = {
        {
          diagnostics = {
            {
              col = 17,
              filename = "/home/stevearc/ws/overseer-test-frameworks/javascript/jest/other_sample.test.js",
              lnum = 21,
              text = "Expected: 3\nReceived: 1",
            },
          },
          duration = 0.208,
          filename = "/home/stevearc/ws/overseer-test-frameworks/javascript/jest/other_sample.test.js",
          id = "more jest tests that are nested should show test output",
          name = "should show test output",
          path = { "more jest tests", "that are nested" },
          status = "FAILURE",
          text = "Error: expect(received).toBe(expected) // Object.is equality\n\nExpected: 3\nReceived: 1\n    at Object.toBe (/home/stevearc/ws/overseer-test-frameworks/javascript/jest/other_sample.test.js:21:17)",
        },
        {
          duration = 0.2,
          filename = "/home/stevearc/ws/overseer-test-frameworks/javascript/jest/other_sample.test.js",
          id = "more jest tests other nested should error",
          name = "should error",
          path = { "more jest tests", "other nested" },
          stacktrace = {
            {
              col = 3,
              filename = "/home/stevearc/ws/overseer-test-frameworks/javascript/jest/other_sample.test.js",
              lnum = 8,
              text = "ReferenceError: baz is not defined",
            },
            {
              col = 3,
              filename = "/home/stevearc/ws/overseer-test-frameworks/javascript/jest/other_sample.test.js",
              lnum = 12,
              text = "at bar",
            },
            {
              col = 7,
              filename = "/home/stevearc/ws/overseer-test-frameworks/javascript/jest/other_sample.test.js",
              lnum = 27,
              text = "at Object.foo",
            },
          },
          status = "FAILURE",
          text = "ReferenceError: baz is not defined\n    at baz (/home/stevearc/ws/overseer-test-frameworks/javascript/jest/other_sample.test.js:8:3)\n    at bar (/home/stevearc/ws/overseer-test-frameworks/javascript/jest/other_sample.test.js:12:3)\n    at Object.foo (/home/stevearc/ws/overseer-test-frameworks/javascript/jest/other_sample.test.js:27:7)",
        },
        {
          diagnostics = {
            {
              col = 15,
              filename = "/home/stevearc/ws/overseer-test-frameworks/javascript/jest/other_sample.test.js",
              lnum = 32,
              text = "Expected: 3\nReceived: 1",
            },
          },
          duration = 0.201,
          filename = "/home/stevearc/ws/overseer-test-frameworks/javascript/jest/other_sample.test.js",
          id = "more jest tests should fail",
          name = "should fail",
          path = { "more jest tests" },
          status = "FAILURE",
          text = "Error: expect(received).toBe(expected) // Object.is equality\n\nExpected: 3\nReceived: 1\n    at Object.toBe (/home/stevearc/ws/overseer-test-frameworks/javascript/jest/other_sample.test.js:32:15)",
        },
        {
          duration = 0.201,
          filename = "/home/stevearc/ws/overseer-test-frameworks/javascript/jest/sample.test.js",
          id = "jest tests should succeed",
          name = "should succeed",
          path = { "jest tests" },
          status = "SUCCESS",
          text = "",
        },
        {
          filename = "/home/stevearc/ws/overseer-test-frameworks/javascript/jest/sample.test.js",
          id = "jest tests should skip",
          name = "should skip",
          path = { "jest tests" },
          status = "SKIPPED",
          text = "",
        },
      },
    }, results)
  end)
end)
