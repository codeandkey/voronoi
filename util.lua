local util = {}

function util.name_of(obj)
    if obj then
        return obj.name
    else
        return 'nil'
    end
end

function util.bp_moving_left(bp)
    return bp.first.y < bp.second.y
end

function util.bp_moving_right(bp)
    return bp.first.y > bp.second.y
end

function util.convergence_point(p1, p2, p3)
    local v1 = {
        x = -(p1.y - p2.y),
        y = p1.x - p2.x,
    }

    local v2 = {
        x = -(p2.y - p3.y),
        y = p2.x - p3.x,
    }

    local d = {
        x = 0.5 * (p3.x - p1.x),
        y = 0.5 * (p3.y - p1.y),
    }

    local det1 = d.x * v2.y - d.y * v2.x
    local det2 = v1.x * v2.y - v1.y * v2.x
    local t = det1 / det2

    local center = {
        x = 0.5 * (p1.x + p2.x) + t * v1.x,
        y = 0.5 * (p1.y + p2.y) + t * v1.y,
    }

    local radius = math.sqrt(math.pow(p1.x - center.x, 2) + math.pow(p1.y - center.y, 2))

    return center, center.y + radius
end

return util
