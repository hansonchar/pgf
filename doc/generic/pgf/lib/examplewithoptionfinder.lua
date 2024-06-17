local UNIT_TESTING = true

if UNIT_TESTING then
    local function pwd()
        local info = debug.getinfo(1, "S")
        local path = info.source:match("@(.*)")
        local dir = path:match("(.*[/\\])") or "./"
        return dir
    end
    package.path = pwd() .. "?.lua;" .. package.path
    local luarocks_path = os.getenv("HOME") .. "/.luarocks/share/lua/5.3/?.lua"
    package.path = package.path .. ";" .. luarocks_path
    print("package.path: " .. package.path)
-- local tostring = require "ml".tstring
end

local lpeg = require("lpeg")
local loc = lpeg.locale()
-- local u = require("utils")
local str = require("stringmatcher")
local C, Ct, P, V = lpeg.C, lpeg.Ct, lpeg.P, lpeg.V

local t = {}
local SP = loc.space ^ 0

local result = {}
local function keyval(key, val)
    result[key] = val
    return result
end

-- Grammar to extract code from function call to "example" with a table parameter
t.grammar =
    P {
    "examplewithoptions",
    examplewithoptions = V "anything" * V "example" ^ 0 * V "anything",
    example = V "example_begin" * V "content" * V "example_end",
    example_begin = P "\n" ^ -1 * "example({" * SP,
    example_end = "\n})" * SP,
    -- content = C((1 - V "example_end") ^ 0),
    content = V "options" ^ -1 * V "code",
    anything = (1 - V "example") ^ 0,
    options = SP * C("options") * SP * "=" * str ^ -1 * (P ",") ^ -1 / keyval,
    code = SP * C("code") * SP * "=" * str / keyval
}

function t.get_options(_)
    return {}
end

function t.get_content(e)
    return e[1]
end

function t.get_name()
    return "exopt"
end

if UNIT_TESTING then
    local tostring = require "ml".tstring
    local mini_test_case =
        [=[]
example({
  options = [[ foo ]],
  code = [[
    bar
  ]]
})
]=]
    local test_case =
        [=[
example({
  options = [[ preamble=\usetikzlibrary{graphs,graphdrawing} \usegdlibrary{layered} ]],
  code = [[
    \begin{tikzpicture}
      \draw [help lines] (0,0) grid (2,2);

      \graph [layered layout, edges=rounded corners]
        { a -- {b, c [anchor here] } -- d -- a};
    \end{tikzpicture}
  ]]
})
]=]
    local captured = t.grammar:match(test_case)
    -- local result = t.grammar:match(mini_test_case)
    print("captured:", captured)
    -- print("tostring(result): ", tostring(captured))
    print("captured.options:", captured.options)
    print("captured.code:", captured.code)
    print("result.options:", result.options)
    print("result.code:", result.code)
    os.exit()
end

return t
