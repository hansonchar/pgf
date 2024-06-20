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

local tostring = UNIT_TESTING and require "ml".tstring or nil

local finder = {}

-- Reorganize the captured result into a nicer form
local function reorg(result, ...)
  local options = select(1, ...) == "options" and u.strip(select(2, ...)) or nil
  for _, item in ipairs({...}) do
    if type(item) == "table" then
      for i, code in ipairs(item) do
        result[i] = {
          options = options,
          code = code
        }
      end
    end
  end
  return result
end

local function peek(...)
  -- print("peek/captured: ", tostring(...))
  return ...
end

local function flatten(captured)
  local result = {}
  for _, examples in ipairs(captured) do
    for _, example in ipairs(examples) do
      result[#result + 1] = example
    end
  end
  return result
end

-- Grammar to extract code examples as a list of string parameters
-- in a table assignment to "examples"
finder.grammar =
  P {
  "examples",
  examples = V "anything" * Ct(V "pattern" * (V "anything" * V "pattern") ^ 0) / flatten,
  anything = (1 - V "pattern") ^ 0,
  pattern = SP * "examples" * SP * "=" * SP * "{" * SP * V "content" * SP * "}" / peek,
  content = Cf(Ct "" * Cg(V("options") ^ -1 * Ct(V("exentry") ^ 1)), reorg),
  options = V "optionskv" * P(",") ^ -1,
  optionskv = Cg(C("options") * SP * "=" * SP * str),
  exentry = str * P(",") ^ -1,
}

-- local function preamble(options)
--   local p = SP * P "preamble" * SP * "=" * SP * C(P(1) ^ 1)
--   local matches = p:match(u.get_string(options))
--   local table = {}
--   if matches then
--     table.preamble = matches
--   end
--   return table
-- end

function finder.get_options(_)
  -- return e.options and preamble(e.options) or {}
  return {}
end

function finder.get_content(e)
  return e.code and u.get_string(e.code) or ""
end

function finder.get_name()
  return "excas"
end

if not UNIT_TESTING then
  return finder
end

-- Unit tests and debugging
local test_case1 =
  [=[
  examples = {
    [[ code example 1 ]],
    [[ code example 2 ]]
  }
]=]

do
  local matches = finder.grammar:match(test_case1)
  print(tostring(matches))
  -- assert(#matches == 2)
  -- assert(u.strip(matches[1].code) == "first entry code")
  -- assert(u.strip(matches[1].options) == "first entry options")
  -- assert(u.strip(matches[2].code) == "second entry code")
  -- assert(not matches[2].options)
end

local test_case2 = [=[
  examples = {[["
    \tikz \graph [simple necklace layout, node distance=0cm, nodes={circle,draw}]
      { 1--2--3--4--5--1 };
  "]],[["
    \tikz \graph [simple necklace layout, node distance=0cm, node sep=0mm,
                  nodes={circle,draw}]
      { 1--2--3[node pre sep=5mm]--4--5[node pre sep=1mm]--1 };
  "]]
  }
]=]
return finder
