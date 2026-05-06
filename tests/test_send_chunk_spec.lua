local assert = require("luassert")
local stub = require("luassert.stub")
local test_utils = require("./utils")

describe("source_lines language wrapping", function()
    local send = require("r.send")
    local config = require("r.config")
    local captured_cmd
    local cmd_stub
    local orig_source_file
    local orig_max_paste_lines
    local orig_bracketed_paste
    local orig_source_args

    before_each(function()
        -- Save and override config fields (send.lua holds the same table reference)
        orig_source_file = config.source_file
        orig_max_paste_lines = config.max_paste_lines
        orig_bracketed_paste = config.bracketed_paste
        orig_source_args = config.source_args

        config.source_file = "/tmp/R.nvim-test/Rsource-test"
        config.max_paste_lines = 20
        config.bracketed_paste = false
        config.source_args = ""

        -- Stub M.cmd to capture what would be sent to R
        captured_cmd = nil
        cmd_stub = stub(send, "cmd", function(cmd_str)
            captured_cmd = cmd_str
            return true
        end)
    end)

    after_each(function()
        cmd_stub:revert()
        -- Restore original config
        config.source_file = orig_source_file
        config.max_paste_lines = orig_max_paste_lines
        config.bracketed_paste = orig_bracketed_paste
        config.source_args = orig_source_args
    end)

    it("wraps short bash code with wrap_inline", function()
        local lines = { 'echo "hello"', "ls" }
        local lang_cfg = {
            dedent = true,
            wrap_inline = function(code)
                return 'system2("bash", c("-c", shQuote(r"---(' .. code .. ')---")))'
            end,
        }
        send.source_lines(lines, nil, lang_cfg)
        assert.truthy(captured_cmd:match('system2%("bash"'), "Expected system2 wrapping for bash")
    end)

    it("wraps long bash code with wrap_file", function()
        -- Build 22 lines to exceed max_paste_lines=20
        local lines = {}
        for i = 1, 22 do
            table.insert(lines, "ls > /dev/null")
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
            captured_cmd:match('system2%("bash"'),
            "Expected system2 wrap_file for long bash, got: " .. tostring(captured_cmd)
        )
    end)

    it("falls back to Rnvim.source for long R code without lang_cfg", function()
        local lines = {}
        for i = 1, 22 do
            table.insert(lines, "x <- " .. i)
        end
        send.source_lines(lines, nil, nil)
        assert.truthy(
            captured_cmd:match("Rnvim%.source%("),
            "Expected Rnvim.source for long R code, got: " .. tostring(captured_cmd)
        )
    end)

    it("falls back to Rnvim.chunk when what is set but no wrap_file", function()
        local lines = {}
        for i = 1, 22 do
            table.insert(lines, "x <- " .. i)
        end
        send.source_lines(lines, "chunk", nil)
        assert.truthy(
            captured_cmd:match("Rnvim%.chunk%("),
            "Expected Rnvim.chunk for long R code with what='chunk', got: "
                .. tostring(captured_cmd)
        )
    end)
end)

describe("send_chunk_line forwards wrap_file for long bash code", function()
    local send = require("r.send")
    local config = require("r.config")
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

    it("uses wrap_file when sending long bash chunk via send.line()", function()
        local bufnr = test_utils.create_r_buffer_from_file("tests/fixtures/send_chunks.qmd")
        vim.api.nvim_set_current_buf(bufnr)
        -- Position cursor inside the long bash chunk body (line 15 = inside the if block)
        vim.api.nvim_win_set_cursor(0, { 15, 0 })

        -- Verify language detection works
        local lang = require("r.utils").get_lang()
        assert.same("bash", lang, "Expected to be in a bash chunk")

        -- Call send.line which internally calls send_chunk_line
        send.line("stay")

        -- The command should use system2 bash wrapping, NOT Rnvim.source
        assert.truthy(
            captured_cmd and captured_cmd:match('system2%("bash"'),
            "Expected system2('bash', ...) wrapping for long bash chunk, got: "
                .. tostring(captured_cmd)
        )
        assert.falsy(
            captured_cmd and captured_cmd:match("Rnvim%.source"),
            "Should NOT use Rnvim.source for bash code"
        )
    end)
end)
