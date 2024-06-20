local function pwd()
    local info = debug.getinfo(1, "S")
    local path = info.source:match("@(.*)")
    local dir = path:match("(.*[/\\])") or "./"
    return dir
end

package.path = pwd() .. "lib/?.lua;" .. package.path
local utils = require "utils"
local documentfinder = require "documentfinder"
local examplefinder = require "examplefinder"
local exoptfinder = require "examplewithoptionfinder"
local examplesfinder = require "examplesfinder"

local DEBUG = false

if DEBUG then
    local luarocks_path = os.getenv("HOME") .. "/.luarocks/share/lua/5.3/?.lua"
    package.path = package.path .. ";" .. luarocks_path
    print("package.path: " .. package.path)
    local tostring = require "ml".tstring
    print("example_grammar:", examplefinder)
    print("example_grammar:", tostring(examplefinder))
end

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

-- Extract code exmples from documentation
for n = 1, #arg - 1 do
    utils.walk(arg[n], arg[#arg], documentfinder)
end

-- Extract code exmples from string parameter passed to the example function
for n = 1, #arg - 1 do
    utils.walk(arg[n], arg[#arg], examplefinder)
end

-- Extract code exmples from table parameter passed to the example function
for n = 1, #arg - 1 do
    utils.walk(arg[n], arg[#arg], exoptfinder)
end

-- Extract code exmples from examples being assigned as a table
for n = 1, #arg - 1 do
    utils.walk(arg[n], arg[#arg], examplesfinder)
end

-- utils.walk("/Users/hchar/tmp/from", "/Users/hchar/tmp/mwe", exoptfinder)
os.exit(0)
