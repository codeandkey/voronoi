local arc = {
    segwidth = 2,
}

--- Arc utilities.
-- Arcs are defined by their site point and a directrix y.

function arc.point(a, ly, x)
    return {
        x = x,
        y = math.pow(x - a.x, 2) / (2 * (a.y - ly)) + (a.y + ly) / 2,
    }
end

function arc.breakpoint(b, a, ly)
    local d1 = 1 / (2 * (a.y - ly))
    local d2 = 1 / (2 * (b.y - ly))
    local e = d1 - d2
    local f = 2 * (b.x * d2 - a.x * d1)
    local g = (a.y * a.y + a.x * a.x - ly * ly) * d1 - (b.y * b.y + b.x * b.x - ly * ly) * d2
    local dt = f * f - 4 * e * g

    return (math.sqrt(dt) - f) / (2 * e)
end

function arc.breakpoint_full(b, a, ly)
    return arc.point(a, ly, arc.breakpoint(b, a, ly))
end

function arc.draw(a, ly, left, right, col)
    steps = math.floor((right - left) / arc.segwidth)

    love.graphics.setColor(col)

    for i=0,steps do
        local xl = left + arc.segwidth * i
        local xr = math.min(xl + arc.segwidth, right)
        love.graphics.line(xl, arc.point(a, ly, xl).y, xr, arc.point(a, ly, xr).y)
    end
end

return arc
