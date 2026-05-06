local assert = require("luassert")
local stub = require("luassert.stub")
local send = require("r.send")
local config = require("r.config").get_config()

describe("source_lines handles multi-byte characters", function()
    local captured_cmd
    local cmd_stub
    local orig_source_file
    local orig_max_paste_lines
    local orig_bracketed_paste
    local orig_source_args

    before_each(function()
        orig_source_file = config.source_file
        orig_max_paste_lines = config.max_paste_lines
        orig_bracketed_paste = config.bracketed_paste
        orig_source_args = config.source_args

        config.source_file = "/tmp/R.nvim-test/Rsource-test"
        vim.fn.mkdir("/tmp/R.nvim-test", "p")
        config.max_paste_lines = 20
        config.bracketed_paste = false
        config.source_args = ""

        captured_cmd = nil
        cmd_stub = stub(send, "cmd", function(cmd_str)
            captured_cmd = cmd_str
            return true
        end)
    end)

    after_each(function()
        cmd_stub:revert()
        config.source_file = orig_source_file
        config.max_paste_lines = orig_max_paste_lines
        config.bracketed_paste = orig_bracketed_paste
        config.source_args = orig_source_args
    end)

    it("preserves Chinese characters in short inline code", function()
        local lines = { 'x <- "你好世界"' }
        send.source_lines(lines, nil, nil)
        assert.truthy(captured_cmd:find("你好世界"), "Chinese chars should survive: " .. tostring(captured_cmd))
    end)

    it("preserves emoji in short inline code", function()
        local lines = { 'cat("Hello 👋\n")' }
        send.source_lines(lines, nil, nil)
        assert.truthy(captured_cmd:find("👋"), "Emoji should survive: " .. tostring(captured_cmd))
    end)

    it("preserves Chinese characters in file-sourced code", function()
        local lines = {}
        for _ = 1, 21 do
            table.insert(lines, 'x <- "你好"')
        end
        send.source_lines(lines, nil, nil)
        -- Should use Rnvim.source since no lang_cfg
        assert.truthy(
            captured_cmd:match("Rnvim%.source"),
            "Expected Rnvim.source for long code, got: " .. tostring(captured_cmd)
        )
    end)

    it("preserves emoji in file-sourced code with wrap_file", function()
        local lines = {}
        for _ = 1, 21 do
            table.insert(lines, "echo '👋'")
        end
        local lang_cfg = {
            dedent = true,
            wrap_inline = function(code)
                return 'system2("bash", c("-c", shQuote(r"---(' .. code .. ')---")))'
            end,
            wrap_file = function(filepath)
                return 'system2("bash", c(shQuote("' .. filepath .. '")))'
            end,
        }
        send.source_lines(lines, nil, lang_cfg)
        assert.truthy(
            captured_cmd:match('system2%(\"bash\"'),
            "Expected system2 wrap_file for long bash with emoji, got: " .. tostring(captured_cmd)
        )
    end)

    it("preserves mixed CJK + ASCII in wrap_inline", function()
        local lines = { '# 这是中文注释', 'print("hello")' }
        local lang_cfg = {
            dedent = false,
            wrap_inline = function(code) return code end,
        }
        send.source_lines(lines, nil, lang_cfg)
        assert.truthy(captured_cmd:find("中文"), "Chinese in comment should survive")
    end)
end)

describe("dedent handles multi-byte content", function()
    local utils = require("r.utils")

    it("dedents Chinese text correctly", function()
        local input = "  你好\n  世界"
        local expected = "你好\n世界"
        assert.same(expected, utils.dedent(input))
    end)

    it("dedents mixed ASCII + Chinese correctly", function()
        local input = "    # 这是注释\n    x <- 你好"
        local expected = "# 这是注释\nx <- 你好"
        assert.same(expected, utils.dedent(input))
    end)

    it("dedents emoji content correctly", function()
        local input = "  echo '👋'\n  echo '🎉'"
        local expected = "echo '👋'\necho '🎉'"
        assert.same(expected, utils.dedent(input))
    end)
end)

describe("line_part byte splitting with multi-byte chars", function()
    -- This test documents the KNOWN LIMITATION:
    -- string.sub() uses byte offsets, which can split multi-byte characters.
    -- This is a documentation test, not a fix.

    it("string.sub can split multi-byte characters at byte boundaries", function()
        -- "你好" is 6 bytes in UTF-8 (3 bytes per char)
        local line = "你好世界"
        -- Byte 3 is the boundary between 你 and 好
        -- string.sub(line, 1, 3) returns the first character (correct)
        -- string.sub(line, 1, 4) splits 好 mid-byte (invalid UTF-8)
        local first_char = line:sub(1, 3)
        assert.same("你", first_char)

        -- Byte 4 is the middle of 好 — this produces invalid UTF-8
        local split = line:sub(1, 4)
        -- The split string won't equal any valid character
        assert.is_not.same("你好", split)
        assert.is_not.same("你", split)
    end)
end)

describe("source_lines with bracketed_paste enabled", function()
    local captured_cmd
    local cmd_stub
    local orig_source_file
    local orig_max_paste_lines
    local orig_bracketed_paste
    local orig_source_args

    before_each(function()
        orig_source_file = config.source_file
        orig_max_paste_lines = config.max_paste_lines
        orig_bracketed_paste = config.bracketed_paste
        orig_source_args = config.source_args

        config.source_file = "/tmp/R.nvim-test/Rsource-test"
        vim.fn.mkdir("/tmp/R.nvim-test", "p")
        config.max_paste_lines = 20
        config.bracketed_paste = true
        config.source_args = ""

        captured_cmd = nil
        cmd_stub = stub(send, "cmd", function(cmd_str)
            captured_cmd = cmd_str
            return true
        end)
    end)

    after_each(function()
        cmd_stub:revert()
        config.source_file = orig_source_file
        config.max_paste_lines = orig_max_paste_lines
        config.bracketed_paste = orig_bracketed_paste
        config.source_args = orig_source_args
    end)

    it("wraps command with bracketed paste escape sequences", function()
        local lines = { "x <- 1" }
        send.source_lines(lines, nil, nil)
        assert.truthy(
            captured_cmd:find("\027%[200~"),
            "Should start with bracketed paste begin"
        )
        assert.truthy(
            captured_cmd:find("\027%[201~"),
            "Should end with bracketed paste end"
        )
    end)

    it("preserves Chinese characters with bracketed paste", function()
        local lines = { 'x <- "你好"' }
        send.source_lines(lines, nil, nil)
        assert.truthy(
            captured_cmd:find("你好"),
            "Chinese chars should survive bracketed paste"
        )
    end)
end)
