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
local C, Cf, Cg, Ct, P, S, V = lpeg.C, lpeg.Cf, lpeg.Cg, lpeg.Ct, lpeg.P, lpeg.S, lpeg.V
local u = require("utils")

local function strip_dashdash(s)
    return s and s:gsub("\n%-%-", "\n"):gsub("^%-%-", "") or s
end

local finder = {}

-- Grammar to extract code examples from document
finder.grammar =
    P {
    "document",
    name = C((1 - S ",]=") ^ 1),
    pair = Cg(V "name" * (u.lit "=" * (V "braces" + V "name")) ^ 0) * u.lit "," ^ -1,
    list = Cf(Ct "" * V "pair" ^ 0, u.set),
    balanced = "{" * ((1 - S "{}") + V "balanced") ^ 0 * "}",
    braces = C(V "balanced"),
    optarg = u.lit "[" * V "list" * u.lit "]",
    begincodeexample = P "\\begin{codeexample}" * V "optarg",
    endcodeexample = P "\\end{codeexample}",
    content = C((1 - V "endcodeexample") ^ 0),
    codeexample = Ct(V "begincodeexample" * V "content" * V "endcodeexample"),
    anything = (1 - V "codeexample") ^ 0,
    document = V "anything" * Ct(V "codeexample" * (V "anything" * V "codeexample") ^ 0) * V "anything"
}

function finder.get_options(e)
    local options = e[1]
    if options and options["preamble"] then
        options["preamble"] = strip_dashdash(options["preamble"])
    end
    return e[1]
end

function finder.get_content(e)
    return strip_dashdash(e[2])
end

function finder.get_name()
    return "document"
end

if not UNIT_TESTING then
    return finder
end

-- local tostring = UNIT_TESTING and require "ml".tstring or nil

local testcase_1 =
    [=[
        \begin{codeexample}[preamble={\usetikzlibrary{graphs,graphdrawing}
    \usegdlibrary{trees}}]
        \tikz \graph [tree layout, nodes={draw}, component sep=0pt,
                      component packing=rectangular]
          { a -- long text, longer text -- b};
        \end{codeexample}
]=]

do
    local matches = finder.grammar:match(testcase_1)
    assert(#matches == 1)
    assert(
        finder.get_options(matches[1]).preamble == [[
\usetikzlibrary{graphs,graphdrawing}
    \usegdlibrary{trees}]]
    )
    assert(
        u.strip(finder.get_content(matches[1])) ==
            [[
\tikz \graph [tree layout, nodes={draw}, component sep=0pt,
                      component packing=rectangular]
          { a -- long text, longer text -- b};]]
    )
end

local testcase_2 =
    [=[
\begin{codeexample}[code only]
\graph {
  % The nodes:
  a, b, c, d;

  % The edges:
  {[hyper] a,b,c};
  {[hyper] b,c,d};
  {[hyper] a,c};
  {[hyper] d}
};
\end{codeexample}
]=]
do
    local matches = finder.grammar:match(testcase_2)
    assert(#matches == 1)
    assert(finder.get_options(matches[1])["code only"] == u.invalid)
    assert(
        u.strip(finder.get_content(matches[1])) ==
            [[
\graph {
  % The nodes:
  a, b, c, d;

  % The edges:
  {[hyper] a,b,c};
  {[hyper] b,c,d};
  {[hyper] a,c};
  {[hyper] d}
};]]
    )
end

local test_case_3 = [[
-- This is a comment
-- Another comment line
-- Yet another comment
]]

do
    local output = strip_dashdash(test_case_3)
    assert(output == [[
 This is a comment
 Another comment line
 Yet another comment
]])
    assert(not strip_dashdash(nil))
end

return finder
