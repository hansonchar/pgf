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
end

local lpeg = require("lpeg")
local u = require("utils")
local SP = u.SP
local str = require("stringmatcher")
local C, P, V, Ct, Cf, Cg = lpeg.C, lpeg.P, lpeg.V, lpeg.Ct, lpeg.Cf, lpeg.Cg

local finder = {}

-- Grammar to extract code from function call to "example" with a table parameter
finder.grammar =
    P {
    "examplewithoptions",
    examplewithoptions = V "anything" * (V "example") ^ 1 * V "anything",
    example = V "example_begin" * V "content" * V "example_end",
    example_begin = P "\n" ^ -1 * "example({" * SP,
    example_end = "\n})" * SP,
    content = Ct(Cf(Ct "" * V "options" ^ -1 * V "code", u.set)),
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
    return preamble(e.options)
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

local tostring = require "ml".tstring
local test_options = [[ preamble=\usetikzlibrary{graphs,graphdrawing} \usegdlibrary{layered} ]]
local p = SP * P "preamble" * SP * "=" * SP * C(P(1) ^ 1)
local matches = p:match(test_options)
assert(matches == [[\usetikzlibrary{graphs,graphdrawing} \usegdlibrary{layered} ]])

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
matches = finder.grammar:match(test_case)
assert(#matches == 1)
local e = matches[1]
assert(tostring(finder.get_options(e)) == [[{preamble="\\usetikzlibrary{graphs,graphdrawing} \\usegdlibrary{layered"}]])
assert(
    u.strip(finder.get_content(e)) ==
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
