local lfs = require "lfs"
local lpeg = require "lpeg"
local DEBUG = false

if DEBUG then
    local luarocks_path = os.getenv("HOME") .. "/.luarocks/share/lua/5.3/?.lua"
    package.path = package.path .. ";" .. luarocks_path
end
local tostring = DEBUG and require "ml".tstring or nil

-- luacheck:ignore 542 (Empty if branch.)
local utils = {}
local u = utils

utils.pathsep = package.config:sub(1, 1)

-- strip leading and trailing whitespace
function u.strip(str)
    return str:match "^%s*(.-)%s*$"
end
-- strip braces
function u.strip_braces(str)
    return str:match "^{?(.-)}?$"
end

-- optional whitespace
u.ws = lpeg.S " \t\n\r" ^ 0

-- match string literal
function u.lit(str)
    return u.ws * lpeg.P(str) * u.ws
end

-- setter for options table
u.invalid = string.char(0x8)

function u.set(t, k, v)
    -- strip whitespace from keys
    k = u.strip(k)
    -- if the value is empty, set it to invalid character
    v = v and u.strip_braces(v) or u.invalid
    return rawset(t, k, v)
end

-- get the basename and extension of a file
function u.basename(file)
    local name, ext = string.match(file, "^(.+)%.([^.]+)$")
    return name or "", ext or file
end

-- Walk the file tree
function u.walk(sourcedir, targetdir, finder)
    -- print("grammar_t:", grammar_t)
    -- os.exit()
    -- Make sure the arguments are directories
    assert(lfs.attributes(sourcedir, "mode") == "directory", sourcedir .. " is not a directory")
    assert(lfs.attributes(targetdir, "mode") == "directory", targetdir .. " is not a directory")

    -- Append the path separator if necessary
    if sourcedir:sub(-1, -1) ~= u.pathsep then
        sourcedir = sourcedir .. u.pathsep
    end
    if targetdir:sub(-1, -1) ~= u.pathsep then
        targetdir = targetdir .. u.pathsep
    end

    -- Process all items in the directory
    for file in lfs.dir(sourcedir) do
        if file == "." or file == ".." then
            -- Ignore these two special ones
        elseif lfs.attributes(sourcedir .. file, "mode") == "directory" then
            -- Recurse into subdirectories
            lfs.mkdir(targetdir .. file)
            u.walk(sourcedir .. file .. u.pathsep, targetdir .. file .. u.pathsep, finder)
        elseif lfs.attributes(sourcedir .. file, "mode") == "file" then
            print("Processing " .. sourcedir .. file)

            -- Read file into memory
            local f = io.open(sourcedir .. file)
            local text = f:read("*all")
            f:close()
            local name, _ = u.basename(file)

            -- preprocess, strip all commented lines
            text = text:gsub("\n%%[^\n]*", "")

            -- extract all code examples
            local matches = finder.grammar:match(text) or {}

            if DEBUG then
                print("matches:", matches)
                print("tostring(matches):", tostring(matches))
            end

            -- write code examples to separate files
            local setup_code = ""
            for n, e in ipairs(matches) do
                -- local options = e[1]
                -- local content = e[2]
                local options = finder.get_options(e)
                local content = finder.get_cotent(e)
                -- if DEBUG then
                --     print("options:", options)
                --     print("content:", content)
                -- end
                if content:match("remember picture") then
                    -- skip
                elseif options["setup code"] then
                    -- If the snippet is marked as setup code, we have to put it before
                    -- every other snippet in the same file
                    -- if options["setup code"] then
                    setup_code = setup_code .. u.strip(content) .. "\n"
                elseif not options["code only"] and not options["setup code"] then
                    -- Skip those that say "code only" or "setup code"
                    -- if not options["code only"] and not options["setup code"] then
                    local newname = finder.get_name() .. "-" .. name .. "-" .. n .. ".tex"
                    local examplefile = io.open(targetdir .. newname, "w")

                    examplefile:write "\\documentclass{standalone}\n"
                    examplefile:write "\\usepackage{fp,pgf,tikz,xcolor}\n"
                    examplefile:write(options["preamble"] and options["preamble"] .. "\n" or "")
                    examplefile:write "\\begin{document}\n"

                    examplefile:write(setup_code)
                    local pre = options["pre"] or ""
                    pre = pre:gsub("##", "#")
                    examplefile:write(pre .. "\n")
                    if options["render instead"] then
                        examplefile:write(options["render instead"] .. "\n")
                    else
                        examplefile:write(u.strip(content) .. "\n")
                    end
                    examplefile:write(options["post"] and options["post"] .. "\n" or "")
                    examplefile:write "\\end{document}\n"

                    examplefile:close()
                end
            end
        end
    end
end

return utils
