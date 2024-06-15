local function pwd()
    local info = debug.getinfo(1, "S")
    local path = info.source:match("@(.*)")
    local dir = path:match("(.*[/\\])") or "./"
    return dir
end

package.path = pwd() .. "lib/?.lua;" .. package.path
local utils = require "utils"
local document_grammar = require "document_grammar"

--[[
    Sample Usage:

    time texlua ~/github.com/pgf/doc/generic/pgf/extract.lua \
                ~/github.com/pgf/tex \
                ~/github.com/pgf/doc \
                ~/tmp/mwe
]]
-- Main loop
-- luacheck:ignore 113 (Accessing an undefined global variable: arg)
if #arg < 2 then
    print("Usage: " .. arg[-1] .. " " .. arg[0] .. " <source-dirs...> <target-dir>")
    os.exit(1)
end

for n = 1, #arg - 1 do
    utils.walk(arg[n], arg[#arg], document_grammar)
end

os.exit(0)
