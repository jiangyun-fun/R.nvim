local assert = require("luassert")
local send = require("r.send")
local config = require("r.config").get_config()

describe("send.get_source_args", function()
    local orig_source_args

    before_each(function()
        orig_source_args = config.source_args
    end)

    after_each(function()
        config.source_args = orig_source_args
    end)

    it("returns empty string when source_args is empty", function()
        config.source_args = ""
        assert.same("", send.get_source_args())
    end)

    it("returns prefixed args when source_args is set", function()
        config.source_args = "echo=TRUE"
        assert.same(", echo=TRUE", send.get_source_args())
    end)

    it("returns prefixed args with multiple args", function()
        config.source_args = "echo=TRUE, eval=FALSE"
        assert.same(", echo=TRUE, eval=FALSE", send.get_source_args())
    end)
end)
