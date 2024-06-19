local lpeg = require("lpeg")
local C, Cf, Cg, Ct, P, S, V = lpeg.C, lpeg.Cf, lpeg.Cg, lpeg.Ct, lpeg.P, lpeg.S, lpeg.V
local u = require("utils")

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
    return e[1]
end

function finder.get_content(e)
    return e[2]
end

function finder.get_name()
    return "document"
end

return finder
