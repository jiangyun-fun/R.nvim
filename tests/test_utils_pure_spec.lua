local assert = require("luassert")

describe("utils.dedent", function()
    local utils = require("r.utils")

    it("removes uniform leading spaces", function()
        assert.same("hello\nworld", utils.dedent("  hello\n  world"))
    end)

    it("removes only the minimum indentation", function()
        assert.same("hello\n  indented", utils.dedent("  hello\n    indented"))
    end)

    it("returns unchanged text with no indentation", function()
        assert.same("hello\nworld", utils.dedent("hello\nworld"))
    end)

    it("returns unchanged text with empty string", function()
        assert.same("", utils.dedent(""))
    end)

    it("handles single line with indentation", function()
        assert.same("hello", utils.dedent("  hello"))
    end)

    it("handles single line without indentation", function()
        assert.same("hello", utils.dedent("hello"))
    end)

    it("preserves relative indentation", function()
        local input = "    if true;\n      echo hello\n    fi"
        local expected = "if true;\n  echo hello\nfi"
        assert.same(expected, utils.dedent(input))
    end)

    it("skips blank lines when computing minimum indent", function()
        local input = "  hello\n\n  world"
        assert.same("hello\n\nworld", utils.dedent(input))
    end)

    it("handles mixed indent levels with zero-indent line", function()
        local input = "  hello\nworld\n  foo"
        -- min indent is 0, so nothing is removed
        assert.same(input, utils.dedent(input))
    end)
end)

describe("utils.msg_join", function()
    local utils = require("r.utils")

    it("joins two items with default separators", function()
        assert.same('"apple", and "banana"', utils.msg_join({ "apple", "banana" }))
    end)

    it("joins three items with default separators", function()
        assert.same(
            '"apple", "banana", and "cherry"',
            utils.msg_join({ "apple", "banana", "cherry" })
        )
    end)

    it("joins single item", function()
        assert.same('"apple"', utils.msg_join({ "apple" }))
    end)

    it("uses custom separators", function()
        assert.same(
            "'a' + 'b' + 'c'",
            utils.msg_join({ "a", "b", "c" }, " + ", " + ")
        )
    end)

    it("uses custom quote character", function()
        assert.same("`a`, `b`", utils.msg_join({ "a", "b" }, ", ", " and ", "`"))
    end)
end)
