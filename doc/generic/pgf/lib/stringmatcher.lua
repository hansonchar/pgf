local UNIT_TESTING = false
local lpeg = require("lpeg")
local C, P, V = lpeg.C, lpeg.P, lpeg.V

local loc = lpeg.locale()
local SP = loc.space ^ 0 -- spaces

-- Used to match a string which can be single-quoted, double-quoted or multi-line
-- surrounded by inside double square brackets.
local matcher =
    P {
    "str",
    single_quoted = SP * "'" * C(((1 - P "'") + "\\'") ^ 0) * "'",
    double_quoted = SP * '"' * C(((1 - P '"') + '\\"') ^ 0) * '"',
    multiline = SP * "[[" * C((1 - (SP * P "]]")) ^ 0) * SP * "]]",
    str = V "single_quoted" + V "double_quoted" + V "multiline"
}

if not UNIT_TESTING then
    return matcher
end

-- Unit tests and debugging

-- local I = function(tag)
--     return lpeg.P(
--         function()
--             print(tag)
--             return true
--         end
--     )
-- end

do
    -- Define patterns for single-quoted and double-quoted strings
    local single_quoted = SP * "'" * C(((1 - P "'") + "\\'") ^ 0) * "'"

    local str = "'single quoted string'"
    assert(single_quoted:match("  'testing single quotes'") == "testing single quotes")
    assert(single_quoted:match(str) == "single quoted string")

    local double_quoted = SP * '"' * C(((1 - P '"') + '\\"') ^ 0) * '"'
    assert(double_quoted:match('  "testing double quotes"  ') ==  "testing double quotes")
    assert(double_quoted:match('"double quoted string"') == "double quoted string")

    -- Define pattern for multiline strings
    -- local mline_str = I "[[" * "[[" * I "C" * C(1 - P "]]" * I "x") ^ 0 * I "]]" * "]]"
    local multiline = SP * "[[" * C((1 - (SP * P "]]")) ^ 0) * SP * "]]"
    assert(multiline:match("[[testing single multi-line string]]") == "testing single multi-line string")

    assert(multiline:match([=[
    [[
        testing first line
        testing second line
    ]]
    ]=]) == "\n        testing first line\n        testing second line")
end

assert(matcher:match("'single quoted string'") == 'single quoted string')
assert(matcher:match('"double quoted string"') == "double quoted string")
assert(matcher:match("[[multiline\nstring]]") == "multiline\nstring")
assert(matcher:match([=[
        [[
            line1
            line2
        ]]
]=]) == "\n            line1\n            line2")
assert(not matcher:match("not a string"))

local string_in_string =
[=[
[["
    \tikz \graph [spring electrical layout, horizontal=0 to 1]
        { [clique] 1 [electric charge=5], 2, 3, 4 };
"]]
]=]
local first_matches = matcher:match(string_in_string)
print(first_matches)
local second_matches = matcher:match(first_matches)
print(second_matches)
local third_matches = matcher:match(second_matches)
print(third_matches)

return matcher
