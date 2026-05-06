local assert = require("luassert")
local browser = require("r.browser")

-- Note: browser.get_name calls add_backticks internally, so these tests
-- exercise the backtick logic through the public API.
-- Line format in the Object Browser:
--   Top-level: "    :#object_name\t..."
--   The # position (idx) determines nesting depth. idx==5 means top-level.

describe("browser.get_name top-level parsing", function()
    local bufnr

    before_each(function()
        bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_current_buf(bufnr)
    end)

    after_each(function()
        vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("returns plain object name for normal R name", function()
        -- idx==5 means the # is at position 5 (top-level)
        local line = "    :#myvar\t"
        local name = browser.get_name(3, line)
        assert.same("myvar", name)
    end)

    it("backtick-escapes names starting with digits", function()
        local line = "    :#123var\t"
        local name = browser.get_name(3, line)
        assert.same("`123var`", name)
    end)

    it("backtick-escapes names starting with underscore", function()
        local line = "    :#_private\t"
        local name = browser.get_name(3, line)
        assert.same("`_private`", name)
    end)

    it("backtick-escapes names with spaces", function()
        local line = "    :#my name\t"
        local name = browser.get_name(3, line)
        assert.same("`my name`", name)
    end)

    it("backtick-escapes R reserved words", function()
        local line = "    :#if\t"
        local name = browser.get_name(3, line)
        assert.same("`if`", name)
    end)

    it("backtick-escapes NULL", function()
        local line = "    :#NULL\t"
        local name = browser.get_name(3, line)
        assert.same("`NULL`", name)
    end)

    it("passes through unnamed list element [[1]]", function()
        local line = "    :#[[1]]\t"
        local name = browser.get_name(3, line)
        assert.same("[[1]]", name)
    end)

    it("returns empty for lines before row 3", function()
        local line = "    :#myvar\t"
        local name = browser.get_name(1, line)
        assert.same("", name)
    end)
end)
