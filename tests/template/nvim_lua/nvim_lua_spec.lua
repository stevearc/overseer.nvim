local nvim_lua = require("overseer.template.nvim_lua")
local parser = require("overseer.parser")

describe("nvim_lua", function()
  it("can parse test failures", function()
    local p = parser.new(nvim_lua.plenary_busted_test_parser)
    p:ingest(vim.split(
      [[Starting...Scheduling: tests/template/nvim_lua/nvim_lua_spec.lua

========================================
Testing:        /home/stevearc/dotfiles/vimplugins/overseer.nvim/tests/template/nvim_lua/nvim_lua_spec.lua
Fail    ||      lua can parse test failures
            .../overseer.nvim/tests/template/nvim_lua/nvim_lua_spec.lua:17: Expected objects to be the same.
            Passed in:
            (table: 0x7f0d8a8f2c90) { }
            Expected:
            (table: 0x7f0d8a8f3cc8) {
             *[1] = {
                [filename] = 'my_test.go'
                [lnum] = 7
                [text] = 'Expected 'Something' received 'Nothing'' } }

            stack traceback:
                ...dotfiles/vimplugins/overseer.nvim/tests/lua/lua_spec.lua:17: in function <...dotfiles/vimplugins/overseer.nvim/tests/lua/lua_spec.lua:5>

]],
      "\n"
    ))
    local result = p:get_result()
    local expected = {
      {
        filename = "tests/template/nvim_lua/nvim_lua_spec.lua",
        lnum = 17,
        text = [[Expected objects to be the same.
Passed in:
(table: 0x7f0d8a8f2c90) { }
Expected:
(table: 0x7f0d8a8f3cc8) {
 *[1] = {
    [filename] = 'my_test.go'
    [lnum] = 7
    [text] = 'Expected 'Something' received 'Nothing'' } }]],
      },
    }
    assert.are.same(expected, result)
  end)
end)
