--- Site parsing utilities.
-- Uses regular expressions to match sites in a file.

local sites = {}

function sites.parse(filename)
    io.input(filename)

    local num = 1
    local output = {}

    for rx, ry in io.read('*all'):gmatch('%(%s*(%-?%d+)%s*,%s*(%-?%d+)%s*%)') do
        local name = string.format('p%d', num)

        output[name] = {
            name = name,
            x = tonumber(rx),
            y = tonumber(ry),
            index = num,
        }

        num = num + 1
    end

    return output
end

return sites
