local M = {}

M.yaml = function()
    vim.treesitter.query.set(
        "r",
        "injections",
        [[
; extends
((comment) @injection.content
  (#match? @injection.content "^#\\|")
  (#set! injection.language "yaml")
  ;; Strip the "#|" from the start so YAML only sees the content
  (#set! injection.include-children)
  (#offset! @injection.content 0 2 0 0))
]]
    )

    if vim.bo.filetype == "rnoweb" then return end

    vim.treesitter.query.set(
        "python",
        "injections",
        [[
; extends
((comment) @injection.content
  (#match? @injection.content "^#\\|")
  (#set! injection.language "yaml")
  ;; Strip the "#|" from the start so YAML only sees the content
  (#set! injection.include-children)
  (#offset! @injection.content 0 2 0 0))
]]
    )
end

vim.treesitter.query.set(
    "r",
    "highlights",
    [[
; extends
; Cell delimiter for Jupyter
((comment) @content (#match? @content "^\\# ?\\%\\%")) @string.special
]]
)

vim.treesitter.query.set(
    "python",
    "highlights",
    [[
; extends
; Cell delimiter for Jupyter
((comment) @content (#match? @content "^\\# ?\\%\\%")) @class.outer @string.special
]]
)

return M
