local assert = require("luassert")
local stub = require("luassert.stub")
local test_utils = require("./utils")

-- Fixture layout (cursor_motion.qmd):
--  1: ---
--  2: title: "Cursor Motion"
--  3: ---
--  4: (blank)
--  5: # First section
--  6: (blank)
--  7: ```{r}               <- chunk_one header  (start_row=7)
--  8: #| label: chunk_one
--  9: x <- 1
-- 10: y <- 2
-- 11: ```                   <- chunk_one end     (end_row=11)
-- 12: (blank)
-- 13: Some markdown text.
-- 14: (blank)
-- 15: ```{r, eval=FALSE}   <- chunk_two header  (start_row=15, eval=false, FILTERED)
-- 16: z <- 3
-- 17: ```                   <- chunk_two end     (end_row=17)
-- 18: (blank)
-- 19: ```{bash}             <- bash chunk header (start_row=19, SUPPORTED)
-- 20: echo "hello"
-- 21: ```                   <- bash chunk end    (end_row=21)
-- 22: (blank)
-- 23: ## Second section
-- 24: (blank)
-- 25: ```{r}               <- chunk_three header (start_row=25)
-- 26: #| label: chunk_three
-- 27: a <- 10
-- 28: b <- 20
-- 29: c <- 30
-- 30: ```                   <- chunk_three end   (end_row=30)
-- 31: (blank)
--
-- Supported chunks (eval'd + supported lang): chunk_one (R), bash, chunk_three (R)
-- chunk_two is filtered out (eval=FALSE). bash IS supported.

local function get_cursor()
    return { vim.api.nvim_win_get_cursor(0)[1], vim.api.nvim_win_get_cursor(0)[2] }
end

------------------------------------------------------------------------
-- next_chunk: forward navigation
------------------------------------------------------------------------
describe("next_chunk cursor movement", function()
    local rmd = require("r.rmd")
    local bufnr

    before_each(function()
        bufnr = test_utils.create_r_buffer_from_file("tests/fixtures/cursor_motion.qmd")
        vim.api.nvim_set_current_buf(bufnr)
    end)

    it("from markdown text lands on next supported chunk body", function()
        vim.api.nvim_win_set_cursor(0, { 13, 0 }) -- "Some markdown text."
        rmd.next_chunk()
        -- Next supported+eval chunk is bash (start_row=19); not on header → start_row+1=20
        assert.same({ 20, 0 }, get_cursor())
    end)

    it("from chunk header lands on next chunk header (start_row)", function()
        vim.api.nvim_win_set_cursor(0, { 7, 0 }) -- chunk_one header
        rmd.next_chunk()
        -- On header → next chunk's start_row = bash header at 19
        assert.same({ 19, 0 }, get_cursor())
    end)

    it("from chunk body lands on next chunk body (start_row+1)", function()
        vim.api.nvim_win_set_cursor(0, { 9, 0 }) -- inside chunk_one body
        rmd.next_chunk()
        -- Not on header → next chunk's start_row+1 = bash body at 20
        assert.same({ 20, 0 }, get_cursor())
    end)

    it("from chunk end line stays still (no next chunk)", function()
        vim.api.nvim_win_set_cursor(0, { 30, 0 }) -- chunk_three end ``` line
        rmd.next_chunk()
        -- No more chunks after chunk_three — cursor should not move
        assert.same({ 30, 0 }, get_cursor())
    end)

    it("from bash chunk body goes to next chunk body", function()
        vim.api.nvim_win_set_cursor(0, { 20, 0 }) -- inside bash chunk
        rmd.next_chunk()
        -- Next is chunk_three (start_row=25); not on header → 26
        assert.same({ 26, 0 }, get_cursor())
    end)

    it("from before first chunk goes to first chunk body", function()
        vim.api.nvim_win_set_cursor(0, { 6, 0 }) -- before chunk_one
        rmd.next_chunk()
        -- First supported+eval chunk is chunk_one (start_row=7); not on header → 8
        assert.same({ 8, 0 }, get_cursor())
    end)

    it("from chunk_three body finds no further chunk", function()
        vim.api.nvim_win_set_cursor(0, { 28, 0 }) -- inside chunk_three
        rmd.next_chunk()
        assert.same({ 28, 0 }, get_cursor()) -- no movement
    end)
end)

------------------------------------------------------------------------
-- previous_chunk: backward navigation
------------------------------------------------------------------------
describe("previous_chunk cursor movement", function()
    local rmd = require("r.rmd")
    local bufnr

    before_each(function()
        bufnr = test_utils.create_r_buffer_from_file("tests/fixtures/cursor_motion.qmd")
        vim.api.nvim_set_current_buf(bufnr)
    end)

    it("from chunk_three body goes to bash body", function()
        vim.api.nvim_win_set_cursor(0, { 27, 0 }) -- inside chunk_three
        rmd.previous_chunk()
        -- Previous eval'd supported chunk is bash (start_row=19); start_row+1=20
        assert.same({ 20, 0 }, get_cursor())
    end)

    it("from chunk_one body finds no previous chunk", function()
        vim.api.nvim_win_set_cursor(0, { 9, 0 }) -- inside chunk_one
        rmd.previous_chunk()
        -- No previous eval'd supported chunk above row 7
        assert.same({ 9, 0 }, get_cursor()) -- stays put
    end)

    it("from bash chunk body goes to chunk_one body", function()
        vim.api.nvim_win_set_cursor(0, { 20, 0 }) -- inside bash chunk
        rmd.previous_chunk()
        -- Previous is chunk_one (start_row=7); start_row+1=8
        assert.same({ 8, 0 }, get_cursor())
    end)

    it("from markdown text goes to bash body", function()
        vim.api.nvim_win_set_cursor(0, { 23, 0 }) -- "## Second section"
        rmd.previous_chunk()
        -- Previous eval'd supported chunk is bash (start_row=19); start_row+1=20
        assert.same({ 20, 0 }, get_cursor())
    end)
end)

------------------------------------------------------------------------
-- chunk section detection: get_chunk_section_at_cursor
------------------------------------------------------------------------
describe("chunk section detection at cursor", function()
    local chunk = require("r.chunk")
    local bufnr

    before_each(function()
        bufnr = test_utils.create_r_buffer_from_file("tests/fixtures/cursor_motion.qmd")
        vim.api.nvim_set_current_buf(bufnr)
    end)

    it("returns chunk_header on the ```{r} line", function()
        vim.api.nvim_win_set_cursor(0, { 7, 0 })
        local c = chunk.get_current_code_chunk(vim.api.nvim_get_current_buf())
        assert.truthy(c, "Should find a chunk")
        assert.same("chunk_header", c:get_chunk_section_at_cursor())
    end)

    it("returns chunk_body inside the code", function()
        vim.api.nvim_win_set_cursor(0, { 9, 0 }) -- "x <- 1"
        local c = chunk.get_current_code_chunk(vim.api.nvim_get_current_buf())
        assert.truthy(c, "Should find a chunk")
        assert.same("chunk_body", c:get_chunk_section_at_cursor())
    end)

    it("returns chunk_end on the closing ``` line", function()
        vim.api.nvim_win_set_cursor(0, { 11, 0 })
        local c = chunk.get_current_code_chunk(vim.api.nvim_get_current_buf())
        assert.truthy(c, "Should find a chunk")
        assert.same("chunk_end", c:get_chunk_section_at_cursor())
    end)

    it("returns chunk_body on comment lines inside chunk", function()
        vim.api.nvim_win_set_cursor(0, { 8, 0 }) -- "#| label: chunk_one"
        local c = chunk.get_current_code_chunk(vim.api.nvim_get_current_buf())
        assert.truthy(c, "Should find a chunk")
        assert.same("chunk_body", c:get_chunk_section_at_cursor())
    end)
end)

------------------------------------------------------------------------
-- move_next_line: skipping blanks and chunk boundaries
------------------------------------------------------------------------
describe("move_next_line cursor movement", function()
    local cursor = require("r.cursor")
    local bufnr

    before_each(function()
        bufnr = test_utils.create_r_buffer_from_file("tests/fixtures/cursor_motion.qmd")
        vim.api.nvim_set_current_buf(bufnr)
    end)

    it("detects chunk end fence and calls next_chunk", function()
        vim.api.nvim_win_set_cursor(0, { 11, 0 }) -- chunk_one end ```
        cursor.move_next_line()
        -- ``` is detected as chunk end fence → next_chunk() → bash body at 20
        assert.same({ 20, 0 }, get_cursor())
    end)

    it("lands on next line when no blank in between", function()
        vim.api.nvim_win_set_cursor(0, { 8, 0 }) -- "#| label: chunk_one"
        cursor.move_next_line()
        assert.same({ 9, 0 }, get_cursor()) -- "x <- 1"
    end)

    it("stays on last line if already at end", function()
        vim.api.nvim_win_set_cursor(0, { 31, 0 }) -- last line
        cursor.move_next_line()
        assert.same({ 31, 0 }, get_cursor()) -- no movement
    end)

    it("detects chunk end fence on eval=false chunk end", function()
        vim.api.nvim_win_set_cursor(0, { 17, 0 }) -- chunk_two end ```
        -- move_next_line detects ``` fence → next_chunk() → bash body at 20
        cursor.move_next_line()
        assert.same({ 20, 0 }, get_cursor())
    end)
end)

------------------------------------------------------------------------
-- move_next_paragraph: paragraph navigation
------------------------------------------------------------------------
describe("move_next_paragraph cursor movement", function()
    local cursor = require("r.cursor")
    local bufnr

    before_each(function()
        bufnr = test_utils.create_r_buffer_from_file("tests/fixtures/cursor_motion.qmd")
        vim.api.nvim_set_current_buf(bufnr)
    end)

    it("moves from first line of paragraph to next paragraph", function()
        vim.api.nvim_win_set_cursor(0, { 5, 0 }) -- "# First section"
        cursor.move_next_paragraph()
        -- Next paragraph after blank at line 6 starts at chunk_one header line 7
        assert.same({ 7, 0 }, get_cursor())
    end)

    it("stays on last line when at last paragraph", function()
        vim.api.nvim_win_set_cursor(0, { 29, 0 }) -- "c <- 30" (last paragraph)
        cursor.move_next_paragraph()
        -- No next paragraph — should land on last line
        local last_line = vim.api.nvim_buf_line_count(0)
        assert.same(last_line, get_cursor()[1])
    end)
end)

------------------------------------------------------------------------
-- send.line with "move" mode: cursor after sending
------------------------------------------------------------------------
describe("send.line cursor after sending with move mode", function()
    local send = require("r.send")
    local config = require("r.config").get_config()
    local bufnr
    local cmd_stub
    local orig_source_file
    local orig_max_paste_lines
    local orig_bracketed_paste
    local orig_source_args

    before_each(function()
        bufnr = test_utils.create_r_buffer_from_file("tests/fixtures/cursor_motion.qmd")
        vim.api.nvim_set_current_buf(bufnr)

        -- Stub cmd to avoid needing a running R session
        cmd_stub = stub(send, "cmd", function()
            return true
        end)

        orig_source_file = config.source_file
        orig_max_paste_lines = config.max_paste_lines
        orig_bracketed_paste = config.bracketed_paste
        orig_source_args = config.source_args

        config.source_file = "/tmp/R.nvim-test/Rsource-test"
        vim.fn.mkdir("/tmp/R.nvim-test", "p")
        config.max_paste_lines = 20
        config.bracketed_paste = false
        config.source_args = ""
    end)

    after_each(function()
        cmd_stub:revert()
        config.source_file = orig_source_file
        config.max_paste_lines = orig_max_paste_lines
        config.bracketed_paste = orig_bracketed_paste
        config.source_args = orig_source_args
    end)

    it("on chunk end ``` moves to next chunk with move mode", function()
        vim.api.nvim_win_set_cursor(0, { 11, 0 }) -- chunk_one end ```
        send.line("move")
        -- chunk_end + move -> next_chunk() -> bash body (20)
        assert.same({ 20, 0 }, get_cursor())
    end)

    it("on chunk end ``` stays with stay mode", function()
        vim.api.nvim_win_set_cursor(0, { 11, 0 }) -- chunk_one end ```
        send.line("stay")
        assert.same({ 11, 0 }, get_cursor()) -- no movement
    end)

    it("on chunk header sends whole chunk and moves", function()
        vim.api.nvim_win_set_cursor(0, { 7, 0 }) -- chunk_one header ```{r}
        send.line("move")
        -- chunk_header -> send_current_chunk(true) -> next_chunk()
        -- After sending chunk_one, next_chunk → bash header (was on header → start_row)
        assert.same({ 19, 0 }, get_cursor()) -- bash header
    end)

    it("on chunk header stays with stay mode", function()
        vim.api.nvim_win_set_cursor(0, { 7, 0 }) -- chunk_one header
        send.line("stay")
        -- send_current_chunk(false) does not move cursor
        assert.same({ 7, 0 }, get_cursor())
    end)

    it("inside chunk body stays with stay mode", function()
        vim.api.nvim_win_set_cursor(0, { 9, 0 }) -- "x <- 1" inside chunk_one
        send.line("stay")
        assert.same({ 9, 0 }, get_cursor()) -- no movement
    end)
end)

------------------------------------------------------------------------
-- send.line on last chunk: no next chunk to move to
------------------------------------------------------------------------
describe("send.line at document boundaries", function()
    local send = require("r.send")
    local config = require("r.config").get_config()
    local bufnr
    local cmd_stub
    local orig_source_file
    local orig_max_paste_lines
    local orig_bracketed_paste
    local orig_source_args

    before_each(function()
        bufnr = test_utils.create_r_buffer_from_file("tests/fixtures/cursor_motion.qmd")
        vim.api.nvim_set_current_buf(bufnr)

        cmd_stub = stub(send, "cmd", function()
            return true
        end)

        orig_source_file = config.source_file
        orig_max_paste_lines = config.max_paste_lines
        orig_bracketed_paste = config.bracketed_paste
        orig_source_args = config.source_args

        config.source_file = "/tmp/R.nvim-test/Rsource-test"
        vim.fn.mkdir("/tmp/R.nvim-test", "p")
        config.max_paste_lines = 20
        config.bracketed_paste = false
        config.source_args = ""
    end)

    after_each(function()
        cmd_stub:revert()
        config.source_file = orig_source_file
        config.max_paste_lines = orig_max_paste_lines
        config.bracketed_paste = orig_bracketed_paste
        config.source_args = orig_source_args
    end)

    it("on last chunk end with move stays put (no next chunk)", function()
        vim.api.nvim_win_set_cursor(0, { 30, 0 }) -- chunk_three end ```
        send.line("move")
        -- No chunk after chunk_three, cursor stays
        assert.same({ 30, 0 }, get_cursor())
    end)

    it("on last chunk header with move stays put after send", function()
        vim.api.nvim_win_set_cursor(0, { 25, 0 }) -- chunk_three header
        send.line("move")
        -- send_current_chunk(true) -> next_chunk -> no more chunks
        assert.same({ 25, 0 }, get_cursor()) -- stays on header
    end)
end)
