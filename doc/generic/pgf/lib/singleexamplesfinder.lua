local UNIT_TESTING = false
local function pwd()
    local info = debug.getinfo(1, "S")
    local path = info.source:match("@(.*)")
    local dir = path:match("(.*[/\\])") or "./"
    return dir
end
package.path = pwd() .. "?.lua;" .. package.path

if UNIT_TESTING then
    local luarocks_path = os.getenv("HOME") .. "/.luarocks/share/lua/5.3/?.lua"
    package.path = package.path .. ";" .. luarocks_path
end

local lpeg = require("lpeg")
local loc = lpeg.locale()
local u = require("utils")
local SP = u.SP
local str = require("stringmatcher")
local Ct, P, V = lpeg.Ct, lpeg.P, lpeg.V

local finder = {}

local function peek(...)
    -- print("peek/captured: ", tostring(...))
    return ...
end

-- Grammar to extract code from function call to "examples" with a string parameter
finder.grammar =
    P {
    "examples",
    examples = V "anything" * Ct(V "codeexample") / peek,
    codeexample = V "begincodeexample" * str,
    begincodeexample = (loc.space + lpeg.P "\r") ^ 1 * "examples" * SP * "=" * SP,
    anything = (1 - V "codeexample") ^ 0
}

function finder.get_options(_)
    return {}
end

function finder.get_content(s)
    assert(type(s) == "string")
    return u.get_string(s)
end

function finder.get_name()
    return "single"
end

if not UNIT_TESTING then
    return finder
end

local test_case1 = [=[
  examples = [["
    example code
  "]]
]=]

do
    local matches = finder.grammar:match(test_case1)
    assert(#matches == 1)
    assert(u.strip(u.get_string(matches[1])) == "example code")
end

local test_case2 =
    [=[
  examples = [["
    \begin{tikzpicture}
      \graph [simple necklace layout,  node distance=1cm, node sep=0pt,
              nodes={draw,circle,as=.}]
      {
        1 -- 2 [minimum size=2cm] -- 3 --
        4 -- 5 -- 6 -- 7 --[orient=up] 8
      };
      \draw [red,|-|] (1.center) -- ++(0:1cm);
      \draw [red,|-|] (5.center) -- ++(180:1cm);
    \end{tikzpicture}
  "]]
]=]

do
    local matches = finder.grammar:match(test_case2)
    assert(#matches == 1)
    assert(
        u.strip(u.get_string(matches[1])) ==
            [[\begin{tikzpicture}
      \graph [simple necklace layout,  node distance=1cm, node sep=0pt,
              nodes={draw,circle,as=.}]
      {
        1 -- 2 [minimum size=2cm] -- 3 --
        4 -- 5 -- 6 -- 7 --[orient=up] 8
      };
      \draw [red,|-|] (1.center) -- ++(0:1cm);
      \draw [red,|-|] (5.center) -- ++(180:1cm);
    \end{tikzpicture}]]
    )
end

return finder
