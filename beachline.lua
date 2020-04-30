local arc = require 'arc'
local beachline = {}

--- Beachline status structure
--
-- Internal nodes:
--      type: 'breakpoint'
--      left: ref to left child node
--      right: ref to right child node
--      first: ref to left arcsite of breakpoint
--      second: ref to right arcsite of breakpoint
--
-- Leaf nodes:
--      type: 'node'
--      site: ref to arcsite
--      circle_event: ref to circle event if any

function beachline.create()
    return { root = nil }
end

function beachline.collect_remaining(bl)
    function collect(tb, node)
        if node == nil then
            return tb
        end

        if node.type == 'breakpoint' then
            table.insert(tb, node)

            collect(tb, node.left)
            collect(tb, node.right)
        end

        return tb
    end

    return collect({}, bl.root)
end

--- Find the nearest arc to the left of a or return nil.
function beachline.arc_left(bl, a)
    -- Walk up to the split node.
    local split_node = nil

    while a.parent ~= nil do
        if a.parent.right == a then
            split_node = a.parent
            break
        end

        a = a.parent
    end

    if split_node == nil then
        return nil
    end

    local bp = split_node

    -- Walk back down the left child of the split node to the rightmost leaf.
    split_node = split_node.left

    while split_node.type ~= 'arc' do
        split_node = split_node.right
    end

    return split_node, bp
end

--- Find the nearest arc to the right of a or return nil.
function beachline.arc_right(bl, a)
    -- Walk up to the split node.
    local split_node = nil

    while a.parent ~= nil do
        if a.parent.left == a then
            split_node = a.parent
            break
        end

        a = a.parent
    end

    if split_node == nil then
        return nil
    end

    local bp = split_node

    -- Walk back down the right child of the split node to the leftmost leaf.
    split_node = split_node.right

    while split_node.type ~= 'arc' do
        split_node = split_node.left
    end

    return split_node, bp
end

function beachline.query_arc(bl, bly, x)
    if bl.root == nil then
        return nil
    end

    -- walk to the correct leaf arc
    if bl.root.type == 'arc' then
        return bl.root
    end

    local cur = bl.root

    while cur.type ~= 'arc' do
        local bp = arc.breakpoint(cur.first, cur.second, bly)

        if x == bp then
            print('WARNING: beachline query point hits breakpoint')
        end

        if x < bp then
            cur = cur.left
        else
            cur = cur.right
        end
    end

    return cur
end

function beachline.is_empty(bl)
    return bl.root == nil
end

function beachline.remove_arc(bl, a, v)
    local left, bp_left = beachline.arc_left(bl, a)
    local right, bp_right = beachline.arc_right(bl, a)

    -- locate highest breakpoint
    local cur = a
    local highest = nil

    while cur.parent ~= nil do
        cur = cur.parent
        if cur == bp_left then
            highest = bp_left
        end

        if cur == bp_right then
            highest = bp_right
        end
    end

    -- re-use highest breakpoint as new breakpoint
    highest.first = left.site
    highest.second = right.site
    highest.ray_origin = v

    -- remove arc from tree and fill in gaps
    local gparent = a.parent.parent

    if a == a.parent.left then
        if gparent.left == a.parent then
            gparent.left = a.parent.right
            a.parent.right.parent = gparent
        elseif gparent.right == a.parent then
            gparent.right = a.parent.right
            a.parent.right.parent = gparent
        end
    elseif a == a.parent.right then
        if gparent.left == a.parent then
            gparent.left = a.parent.left
            a.parent.left.parent = gparent
        elseif gparent.right == a.parent then
            gparent.right = a.parent.left
            a.parent.left.parent = gparent
        end
    end

    return highest
end

--- Inserts a new arc into the beachline.
-- If the arc being replaced contains a circle event, it is returned.
-- The returned circle event should be removed from the event queue.
function beachline.insert_arc(bl, bly, site)
    -- If the beachline is empty, no tree operations are needed.
    if bl.root == nil then
        bl.root = {
            type = 'arc',
            site = site,
        }

        return
    end

    -- Locate an existing arc above the new site.
    local existing_arc = beachline.query_arc(bl, bly, site.x)

    -- Remove present circle events.
    local circle_event = nil

    if existing_arc.circle_event ~= nil then
        circle_event = existing_arc.circle_event
        existing_arc.circle_event = nil
    end

    -- Construct new arc nodes.
    local arc_a = {
        type = 'arc',
        site = existing_arc.site,
    }

    local arc_b = {
        type = 'arc',
        site = site,
    }

    local arc_c = {
        type = 'arc',
        site = existing_arc.site,
    }

    -- Construct new breakpoint nodes.
    local breakpoint_left = {
        type = 'breakpoint',
        first = arc_a.site,
        second = site,
        ray_origin = arc.point(arc_a.site, bly, site.x),
    }

    local breakpoint_right = {
        type = 'breakpoint',
        first = site,
        second = arc_c.site,
        ray_origin = arc.point(arc_c.site, bly, site.x),
    }

    local prev_parent = existing_arc.parent

    -- Connect new subtree.
    arc_a.parent = breakpoint_left
    arc_b.parent = breakpoint_right
    arc_c.parent = breakpoint_right

    breakpoint_left.left = arc_a
    breakpoint_left.right = breakpoint_right

    breakpoint_right.left = arc_b
    breakpoint_right.right = arc_c
    breakpoint_right.parent = breakpoint_left

    -- Connect new subtree back to main tree.
    breakpoint_left.parent = prev_parent

    if prev_parent ~= nil then
        if prev_parent.right == existing_arc then
            prev_parent.right = breakpoint_left
        elseif prev_parent.left == existing_arc then
            prev_parent.left = breakpoint_left
        else
            print('WARNING: beachline structure corrupted')
        end
    else
        bl.root = breakpoint_left
    end

    return arc_a, arc_b, arc_c, breakpoint_left, breakpoint_right, circle_event
end

function beachline.draw(bl, bly)
    xmin = 0
    xmax = love.graphics.getWidth()

    --print('Starting beachline draw.')

    function bld(node, left, right)
        if right <= left then
            return
        end

        if node ~= nil then
            if node.type == 'breakpoint' then
                local bpx = arc.breakpoint(node.first, node.second, bly)
                local bpy = arc.point(node.first, bly, bpx).y

                love.graphics.setColor(0, 1, 1, 1)
                love.graphics.rectangle('fill', bpx - 2, bpy - 2, 4, 4)

                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.line(bpx, bpy, node.ray_origin.x, node.ray_origin.y)

                --print(string.format('breakpoint segment: (%d, %d) from ray origin (%d, %d)', bpx, bpy, node.ray_origin.x, node.ray_origin.y))

                --print(string.format('drawing arc breakpoint (%d, %d) between %s %s', bpx, bpy, node.first.name, node.second.name))

                bld(node.left, left, math.min(right, bpx))
                bld(node.right, math.max(left, bpx), right)
            elseif node.type == 'arc' then
                --print(string.format('drawing arc node: %s (%d, %d) from %d to %d', node.site.name, node.site.x, node.site.y, left, right))
                arc.draw(node.site, bly, left, right, {0, 0.75, 0.75, 1})
            end
        end
    end

    bld(bl.root, xmin, xmax)
end

function beachline.dump(self)
    io.write('beachline: ')

    function wr(node)
        if node == nil then
            return
        end

        if node.type == 'breakpoint' then
            wr(node.left)
            io.write(string.format('%s%s ', node.first.name, node.second.name))
            wr(node.right)
        else
            io.write(string.format('%s ', node.site.name))
        end
    end

    wr(self.root)
    io.write('\n')
end

return beachline
