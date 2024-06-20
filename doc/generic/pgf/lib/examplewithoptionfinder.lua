local UNIT_TESTING = false

if UNIT_TESTING then
    local luarocks_path = os.getenv("HOME") .. "/.luarocks/share/lua/5.3/?.lua"
    package.path = package.path .. ";" .. luarocks_path
end

local function pwd()
    local info = debug.getinfo(1, "S")
    local path = info.source:match("@(.*)")
    local dir = path:match("(.*[/\\])") or "./"
    return dir
end
package.path = pwd() .. "?.lua;" .. package.path

local lpeg = require("lpeg")
local u = require("utils")
local SP = u.SP
local str = require("stringmatcher")
local C, P, V, Ct, Cf, Cg = lpeg.C, lpeg.P, lpeg.V, lpeg.Ct, lpeg.Cf, lpeg.Cg

local finder = {}

-- local function peek(...)
--     return ...
-- end

local function flatten(captured)
    local result = {}
    for _, examples in ipairs(captured) do
        for _, example in ipairs(examples) do
            result[#result + 1] = example
        end
    end
    return result
end

local function set(t, k, v)
    -- strip whitespace from keys
    k = u.strip(k)
    -- if the value is empty, set it to invalid character
    -- v = v and u.strip_braces(v) or u.invalid
    return rawset(t, k, v)
end

-- Grammar to extract code from function call to "example" with a table parameter
finder.grammar =
    P {
    "examplewithoptions",
    examplewithoptions = Ct((V "anything" * (V "example")) ^ 1) / flatten,
    example = V "example_begin" * V "content" * V "example_end",
    example_begin = P "\n" ^ -1 * "example({" * SP,
    example_end = "\n})" * SP,
    content = Ct(Cf(Ct "" * V "options" ^ -1 * V "code", set)),
    anything = (1 - V "example") ^ 0,
    options = SP * (V "optionskv") ^ -1 * (P ",") ^ -1,
    optionskv = Cg(C("options") * SP * "=" * str),
    code = SP * V "codekv",
    codekv = Cg(C("code") * SP * "=" * str)
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

function finder.get_options(e)
    return e.options and preamble(e.options) or {}
end

function finder.get_content(e)
    return e.code or ""
end

function finder.get_name()
    return "exopt"
end

if not UNIT_TESTING then
    return finder
end

-- Unit tests and debugging

-- local tostring = UNIT_TESTING and require "ml".tstring or nil

local test_case1 =
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

do
    local matches = finder.grammar:match(test_case1)
    assert(#matches == 1)
    local e = matches[1]
    -- print("tostring(e.options)", tostring(e.options))
    assert(u.strip(finder.get_options(e).preamble) == [[\usetikzlibrary{graphs,graphdrawing} \usegdlibrary{layered}]])
    assert(
        u.strip(finder.get_content(e)) ==
            [[\begin{tikzpicture}
      \draw [help lines] (0,0) grid (2,2);

      \graph [layered layout, edges=rounded corners]
        { a -- {b, c [anchor here] } -- d -- a};
    \end{tikzpicture}]]
    )
end

local test_case2 =
    [=[
example({
  options = [[ preamble=first example preamble ]],
  code = [[ first example code ]]
})

example({
  code = [[ second example code ]]
})
]=]

do
    local matches = finder.grammar:match(test_case2)
    print("#matches:", #matches)
    assert(u.strip(finder.get_options(matches[1]).preamble) == [[first example preamble]])
    assert(u.strip(finder.get_content(matches[1])) == [[first example code]])
    assert(not finder.get_options(matches[2]).preamble)
    assert(u.strip(finder.get_content(matches[2])) == [[second example code]])
end

return finder
