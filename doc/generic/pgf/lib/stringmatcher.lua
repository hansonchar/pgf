local UNIT_TESTING = false
local lpeg = require("lpeg")
local C, P, V = lpeg.C, lpeg.P, lpeg.V

local loc = lpeg.locale()
local SP = loc.space ^ 0 -- spaces
-- local I = function(tag)
--     return lpeg.P(
--         function()
--             print(tag)
--             return true
--         end
--     )
-- end

if UNIT_TESTING then
    -- Define patterns for single-quoted and double-quoted strings
    local single_quoted = SP * "'" * C(((1 - P "'") + "\\'") ^ 0) * "'"

    local str = "'single quoted string'"
    print(single_quoted:match("  'testing single quotes'"))
    print(single_quoted:match(str))

    local double_quoted = SP * '"' * C(((1 - P '"') + '\\"') ^ 0) * '"'
    print(double_quoted:match('  "testing double quotes"  '))
    print(double_quoted:match('"double quoted string"'))

    -- Define pattern for multiline strings
    -- local mline_str = I "[[" * "[[" * I "C" * C(1 - P "]]" * I "x") ^ 0 * I "]]" * "]]"
    local multiline = SP * "[[" * C((1 - (SP * P "]]")) ^ 0) * SP * "]]"
    print(multiline:match("[[testing single multi-line string]]"))

    print(multiline:match([=[
    [[
        testing first line
        testing second line
    ]]
    ]=]))
end

-- Combine all patterns into one general pattern
-- local general_str = single_quoted + double_quoted + multiline

local string_matcher =
    P {
    "str",
    single_quoted = SP * "'" * C(((1 - P "'") + "\\'") ^ 0) * "'",
    double_quoted = SP * '"' * C(((1 - P '"') + '\\"') ^ 0) * '"',
    multiline = SP * "[[" * C((1 - (SP * P "]]")) ^ 0) * SP * "]]",
    str = V "single_quoted" + V "double_quoted" + V "multiline"
}

if not UNIT_TESTING then
    return string_matcher
end

-- Test strings
local test_strings = {
    "'single quoted string'",
    '"double quoted string"',
    "[[multiline\nstring]]",
    [=[
        [[
            line1
            line2
        ]]
    ]=],
    "not a string"
}

-- Match and print results
for _, s in ipairs(test_strings) do
    -- local match = lpeg.match(general_str, s)
    -- local match = general_str:match(s)
    local match = string_matcher:match(s)
    if match then
        print("Match found: " .. match)
    else
        print("No match: " .. s)
    end
end
