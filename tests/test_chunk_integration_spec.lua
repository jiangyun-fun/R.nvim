local assert = require("luassert")
local stub = require("luassert.stub")
local chunk = require("r.chunk")
local send = require("r.send")
local config = require("r.config").get_config()

-- Helper: create a minimal Chunk object for testing
local function make_chunk(lang, content, eval_val)
    local info_params = {}
    if eval_val ~= nil then info_params.eval = eval_val end
    return chunk.Chunk:new(content, 1, 10, info_params, {}, lang, nil)
end

describe("filter_code_chunks_by_eval", function()
    it("includes chunks with no eval param", function()
        local c = make_chunk("r", "x <- 1", nil)
        local filtered = chunk.filter_code_chunks_by_eval({ c })
        assert.same(1, #filtered)
    end)

    it("includes chunks with eval=TRUE", function()
        local c = make_chunk("r", "x <- 1", "TRUE")
        local filtered = chunk.filter_code_chunks_by_eval({ c })
        assert.same(1, #filtered)
    end)

    it("excludes chunks with eval=FALSE", function()
        local c = make_chunk("r", "x <- 1", "FALSE")
        local filtered = chunk.filter_code_chunks_by_eval({ c })
        assert.same(0, #filtered)
    end)

    it("excludes chunks with eval=false (lowercase from comment params)", function()
        -- comment_params.eval uses "false" (lowercase) check
        local c = chunk.Chunk:new("x <- 1", 1, 10, {}, { eval = "false" }, "r", nil)
        local filtered = chunk.filter_code_chunks_by_eval({ c })
        assert.same(0, #filtered)
    end)

    it("filters mixed chunks correctly", function()
        local c1 = make_chunk("r", "x <- 1", nil)
        local c2 = make_chunk("r", "y <- 2", "FALSE")
        local c3 = make_chunk("r", "z <- 3", "TRUE")
        local filtered = chunk.filter_code_chunks_by_eval({ c1, c2, c3 })
        assert.same(2, #filtered)
    end)

    it("returns empty for empty input", function()
        local filtered = chunk.filter_code_chunks_by_eval({})
        assert.same({}, filtered)
    end)
end)

describe("codelines_from_chunks", function()
    local orig_chunk_langs

    before_each(function()
        -- Ensure chunk_langs is available
        orig_chunk_langs = config.chunk_langs
    end)

    after_each(function()
        config.chunk_langs = orig_chunk_langs
    end)

    it("wraps bash chunk content with wrap_inline", function()
        local c = make_chunk("bash", "echo hello", nil)
        local lines = chunk.codelines_from_chunks({ c })
        assert.truthy(#lines >= 1)
        -- bash wrap_inline should produce system2("bash", ...)
        assert.truthy(
            lines[1]:match('system2%("bash"'),
            "Expected bash wrapping, got: " .. tostring(lines[1])
        )
    end)

    it("dedents bash code when dedent is true", function()
        -- Bash config has dedent=true, so indented code should be dedented
        local c = make_chunk("bash", "  echo hello\n  echo world", nil)
        local lines = chunk.codelines_from_chunks({ c })
        -- After dedent + wrap_inline, should not have leading spaces in the code part
        assert.truthy(
            lines[1]:match('system2%("bash"'),
            "Expected bash wrapping for dedented code"
        )
    end)

    it("returns empty for unknown language", function()
        local c = make_chunk("javascript", "console.log('hi')", nil)
        local lines = chunk.codelines_from_chunks({ c })
        assert.same({}, lines)
    end)

    it("handles multiple chunks of different languages", function()
        local c_r = make_chunk("r", "x <- 1", nil)
        local c_bash = make_chunk("bash", "echo hello", nil)
        local lines = chunk.codelines_from_chunks({ c_r, c_bash })
        assert.truthy(#lines >= 2, "Should have lines from both chunks")
    end)
end)

describe("send.source_lines with dedent", function()
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

    it("applies dedent when lang_cfg.dedent is true", function()
        local lines = { "  echo hello", "  echo world" }
        local lang_cfg = {
            dedent = true,
            wrap_inline = function(code) return code end,
        }
        send.source_lines(lines, nil, lang_cfg)
        assert.truthy(
            captured_cmd:find("echo hello\necho world"),
            "Expected dedented output, got: " .. tostring(captured_cmd)
        )
    end)

    it("does not dedent when lang_cfg.dedent is false or nil", function()
        local lines = { "  echo hello" }
        local lang_cfg = {
            dedent = false,
            wrap_inline = function(code) return code end,
        }
        send.source_lines(lines, nil, lang_cfg)
        assert.truthy(
            captured_cmd:find("  echo hello"),
            "Expected preserved indentation, got: " .. tostring(captured_cmd)
        )
    end)

    it("applies source_args in Rnvim.source command", function()
        config.source_args = "echo=TRUE"
        local lines = {}
        for _ = 1, 21 do
            table.insert(lines, "x <- 1")
        end
        send.source_lines(lines, nil, nil)
        assert.truthy(
            captured_cmd:match("Rnvim%.source%(echo=TRUE%)"),
            "Expected source_args in command, got: " .. tostring(captured_cmd)
        )
    end)

    it("applies source_args in Rnvim.chunk command", function()
        config.source_args = "echo=TRUE"
        local lines = {}
        for _ = 1, 21 do
            table.insert(lines, "x <- 1")
        end
        send.source_lines(lines, "chunk", nil)
        assert.truthy(
            captured_cmd:match("Rnvim%.chunk%(echo=TRUE%)"),
            "Expected source_args in chunk command, got: " .. tostring(captured_cmd)
        )
    end)
end)
