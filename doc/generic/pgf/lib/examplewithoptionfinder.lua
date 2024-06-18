local UNIT_TESTING = false

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
-- print("package.path: " .. package.path)
-- local tostring = require "ml".tstring
end

local lpeg = require("lpeg")
local loc = lpeg.locale()
local u = require("utils")
local str = require("stringmatcher")
local C, Ct, P, V = lpeg.C, lpeg.Ct, lpeg.P, lpeg.V

local t = {}
local SP = loc.space ^ 0

-- local function sanitize(matches)
--     if type(matches) == "table" then
--         return matches
--     else
--         return {}
--     end
-- end

-- local I =
--     lpeg.P(
--     function(_, i)
--         print("I:", i)
--         return true
--     end
-- )

-- Grammar to extract code from function call to "example" with a table parameter
t.grammar =
    P {
    "examplewithoptions",
    -- examplewithoptions = V "anything" * V "example" ^ 0 * V "anything" / sanitize,
    examplewithoptions = V "anything" * (V "example") ^ 1 * V "anything",
    example = V "example_begin" * V "content" * V "example_end",
    example_begin = P "\n" ^ -1 * "example({" * SP,
    example_end = "\n})" * SP,
    -- content = C((1 - V "example_end") ^ 0),
    content = Ct(lpeg.Cf(Ct "" * V "options" ^ -1 * V "code", u.set)),
    anything = (1 - V "example") ^ 0,
    options = SP * (V "optionskv") ^ -1 * (P ",") ^ -1,
    optionskv = lpeg.Cg(C("options") * SP * "=" * str),
    code = SP * V "codekv",
    codekv = lpeg.Cg(C("code") * SP * "=" * str)
}

local function preamble(options)
    local p = SP * P "preamble" * SP * "=" * SP * C(P(1) ^ 1)
    local matches = p:match(options)
    local table = {}
    if matches then
        table.preamble = matches
    end
    return table
end

function t.get_options(e)
    return preamble(e.options)
end

function t.get_content(e)
    return e.code or ""
end

function t.get_name()
    return "exopt"
end

if UNIT_TESTING then
    local tostring = require "ml".tstring
    local test_options = [[ preamble=\usetikzlibrary{graphs,graphdrawing} \usegdlibrary{layered} ]]
    local p = SP * P "preamble" * SP * "=" * SP * C(P(1) ^ 1)
    local matches = p:match(test_options)
    assert(matches == [[\usetikzlibrary{graphs,graphdrawing} \usegdlibrary{layered} ]])
    -- os.exit()

    -- local tostring = require "ml".tstring
    --     local mini_test_case = [=[]
    -- example({
    --   options = [[ foo ]],
    --   code = [[
    --     bar
    --   ]]
    -- })
    -- ]=]
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
    matches = t.grammar:match(test_case)
    -- local result = t.grammar:match(mini_test_case)
    -- print("captured:", captured)
    -- print("tostring(result): ", tostring(matches[1]))
    assert(#matches == 1)
    local e = matches[1]
    assert(tostring(t.get_options(e)) == [[{preamble="\\usetikzlibrary{graphs,graphdrawing} \\usegdlibrary{layered"}]])
    -- print("t.get_content(matches):", t.get_content(e))
    assert(
        u.strip(t.get_content(e)) ==
            u.strip(
                [[
   \begin{tikzpicture}
      \draw [help lines] (0,0) grid (2,2);

      \graph [layered layout, edges=rounded corners]
        { a -- {b, c [anchor here] } -- d -- a};
    \end{tikzpicture
]]
            )
    )

    -- print("captured.options:", captured.options)
    -- print("captured.code:", captured.code)
    -- print("result.options:", result.options)
    -- print("result.code:", result.code)
    os.exit()
end

return t
