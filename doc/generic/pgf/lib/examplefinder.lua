local lpeg = require("lpeg")
local C, Ct, P, V = lpeg.C, lpeg.Ct, lpeg.P, lpeg.V

local t = {}

-- Grammar to extract code from example with a string only parameter
t.grammar =
    P {
    "example",
    begincodeexample = P "\n" ^ -1 * "example\n[[",
    endcodeexample = P "\n]]",
    content = C((1 - V "endcodeexample") ^ 0),
    codeexample = Ct(V "begincodeexample" * V "content" * V "endcodeexample"),
    anything = (1 - V "codeexample") ^ 0,
    example = V "anything" * Ct(V "codeexample" * (V "anything" * V "codeexample") ^ 0) * V "anything"
}

function t.get_options(_)
    return {}
end

function t.get_cotent(e)
    return e[1]
end

function t.get_name()
    return "example"
end

return t
