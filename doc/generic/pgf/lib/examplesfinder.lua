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
  -- return table.unpack(result)
  -- print("reorg/tostring(result):", tostring(result))
  -- print("reorg/table.unpack(result):", table.unpack(result))
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

-- Grammar to extract code from a table assignment to "examples"
finder.grammar =
  P {
  "examples",
  examples = V "anything" * Ct(V "pattern" * (V "anything" * V "pattern") ^ 0) / flatten,
  anything = (1 - V "pattern") ^ 0,
  pattern = SP * "examples" * SP * "=" * SP * "{" * SP * V "content" * SP * "}" / peek,
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

function finder.get_options(e)
  return e.options and preamble(e.options) or {}
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
    {
      options = [[ first entry options ]],
      code = [[ first entry code ]]
    },
    {
      code = [[ second entry code]]
    }
  }
]=]

do
  local matches = finder.grammar:match(test_case1)
  assert(#matches == 2)
  assert(u.strip(matches[1].code) == "first entry code")
  assert(u.strip(matches[1].options) == "first entry options")
  assert(u.strip(matches[2].code) == "second entry code")
  assert(not matches[2].options)
end

local test_case2 =
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

  examples = {
    {
      code = [[ another example first entry ]]
    },
    {
      code = [[ another example second entry]]
    }
  }
]=]

do
  local matches = finder.grammar:match(test_case2)
  assert(#matches == 4)
  assert(u.strip(matches[1].code) == "first entry code")
  assert(u.strip(matches[1].options) == "first entry options")
  assert(u.strip(matches[2].code) == "second entry code")
  assert(u.strip(matches[2].options) == "top level options")
  assert(u.strip(matches[3].code) == "another example first entry")
  assert(not matches[3].options)
  assert(u.strip(matches[4].code) == "another example second entry")
  assert(not matches[4].options)
end

local test_case3 =
  [=[
  examples = {
    options = [[ preamble={\usetikzlibrary{graphs,graphdrawing} \usegdlibrary{force}} ]],

    {
      options = [["preamble={\usetikzlibrary{graphs,graphdrawing} \usegdlibrary{force}}"]],
      code = [["
        \tikz \graph [spring electrical layout, horizontal=0 to 1]
          { 0 [electric charge=1] -- subgraph C_n [n=10] };
      "]]
    },

    {
      code = [["
        \tikz \graph [spring electrical layout, horizontal=0 to 1]
          { [clique] 1 [electric charge=5], 2, 3, 4 };
      "]]
    }
  }
]=]

do
  local matches = finder.grammar:match(test_case3)
  print(tostring(matches))
end

return finder
