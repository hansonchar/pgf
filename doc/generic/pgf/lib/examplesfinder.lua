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
end

local lpeg = require("lpeg")
local u = require("utils")
local SP = u.SP
local str = require("stringmatcher")
local C, P, V, Ct, Cf, Cg = lpeg.C, lpeg.P, lpeg.V, lpeg.Ct, lpeg.Cf, lpeg.Cg
-- local I =
--   lpeg.P(
--   function(_, i)
--     print("I:", i)
--     return true
--   end
-- )

local finder = {}

-- Reorganize the captured result into a nicer form
local function reorg(result, ...)
  local fallback_options = select(1, ...) == "options" and u.strip(select(2, ...)) or nil
  for _, item in ipairs({...}) do
    if type(item) == "table" then
      for i, entry in ipairs(item) do
        result[i] = {
          options = entry.options or fallback_options,
          code = entry.code
        }
      end
    end
  end
  return result
end

local tostring = require "ml".tstring

-- local function peek(x)
--   print("peek: ", tostring(x))
--   return x
-- end

-- Grammar to extract code from a table assignment to "examples"
finder.grammar =
  P {
  "examples",
  examples = V "anything" * Ct(V "pattern" * (V "anything" * V "pattern") ^ 0),
  anything = (1 - V "pattern") ^ 0,
  pattern = SP * "examples" * SP * "=" * SP * "{" * SP * V "content" * SP * "}",
  -- content = Cf(Ct "" * Cg(V("options") ^ -1 * Ct(V("exentry") ^ 1)), reorg) / peek,
  content = Cf(Ct "" * Cg(V("options") ^ -1 * Ct(V("exentry") ^ 1)), reorg),
  options = V "optionskv" * P(",") ^ -1,
  optionskv = Cg(C("options") * SP * "=" * SP * str),
  exentry = SP * "{" * SP * V "excontent" * SP * "}" * P(",") ^ -1,
  excontent = Cf(Ct "" * V("options") ^ -1 * V "code", u.set),
  code = SP * V "codekv",
  codekv = Cg(C("code") * SP * "=" * SP * str)
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

function finder.get_options(e, matches)
  return e.options and preamble(e.options) or matches.options and preamble(matches.options) or {}
end

function finder.get_content(e)
  return e.code or ""
end

function finder.get_name()
  return "examples"
end

if not UNIT_TESTING then
  return finder
end

-- Unit tests and debugging

local test_case1 =
  [=[
  examples = {
    options = [[ top level options ]],
    {
      options = [[ first entry options ]],
      code = [[ first entry code ]]
    },
    {
      code = [[ second entry code]]
    }
  }
]=]
local test_case2 =
  [=[
  examples = {
    {
      options = [[ first entry options ]],
      code = [[ first entry code ]]
    },
    {
      code = [[ second entry code]]
    }
  }
]=]

local matches = finder.grammar:match(test_case1)
print(tostring(matches))
os.exit()
assert(#matches == 1)
local e = matches[1]
assert(e.options == "top level options")
assert(u.strip(e[1].options) == "first entry options")
assert(u.strip(e[1].code) == "first entry code")
assert(not e[2].options)
assert(u.strip(e[2].code) == "second entry code")
-- local p = SP * P"examples" * SP * P"=" * SP *
--     P"{" * SP * (P"options" * SP * P"=" * SP * str) ^ -1 * SP * P(",")^-1 * SP * I * P"}"
-- local matches = p:match(test_case)
-- print(tostring(matches))

-- assert(#matches == 1)
-- local e = matches[1]
-- assert(tostring(finder.get_options(e)) == [[{preamble="\\usetikzlibrary{graphs,graphdrawing} \\usegdlibrary{layered"}]])
-- assert(
--     u.strip(finder.get_content(e)) ==
--         u.strip(
--             [[
--    \begin{tikzpicture}
--       \draw [help lines] (0,0) grid (2,2);

--       \graph [layered layout, edges=rounded corners]
--         { a -- {b, c [anchor here] } -- d -- a};
--     \end{tikzpicture
-- ]]
--         )
-- )

return finder
