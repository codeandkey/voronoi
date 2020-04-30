local arc = require 'arc'
local eq = require 'eq'
local dcel = require 'dcel'
local beachline = require 'beachline'
local util = require 'util'

local voronoi = {
    boundary_padding = 50,
}

function voronoi.init(vsites)
    local q = eq.create()
    local vdcel = dcel.new()

    -- Push site events and compute boundary
    for name, point in pairs(vsites) do
        eq.push(q, {
            type = 'site',
            point = point,
        })

        point.face = dcel.new_face(vdcel, string.format('c%d', point.index))
        point.face.site = point
    end

    return {
        vsites = vsites,
        vdcel = vdcel,
        bly = 0,
        bl = beachline.create(),
        q = q,
        vert_count = 0,
        halfedges = {},
        num_halfedges = 0,
        finalized = false,
        circle_centers = {}
    }
end

function voronoi.step(self)
    local next_event = eq.pop(self.q)

    -- No more events.
    if next_event == nil then
        return false
    end

    if next_event.type == 'site' then
        -- Handle site event.
        self.bly = next_event.point.y

        if beachline.is_empty(self.bl) then
            beachline.insert_arc(self.bl, self.bly, next_event.point)
        else
            local arc_a, arc_b, arc_c, bp_left, bp_right, circ = beachline.insert_arc(self.bl, self.bly, next_event.point)

            -- Remove false alarm circle events if needed
            if circ ~= nil then
                eq.remove(self.q, circ)
            end

            -- We have two new breakpoints which will each trace out part of the edge.
            -- Each breakpoint traces half of a half-edge.
            -- Create the edges here -- other fields are filled in by circle events later.

            bp_left.halfedge = dcel.new_halfedge(self.vdcel)
            bp_right.halfedge = dcel.new_halfedge(self.vdcel)

            bp_left.halfedge.twin = bp_right.halfedge
            bp_right.halfedge.twin = bp_left.halfedge

            voronoi.check_circle_event(self, arc_a)
            voronoi.check_circle_event(self, arc_c)
        end

        self.bly = next_event.point.y + 0.5
    elseif next_event.type == 'circle' then
        self.bly = next_event.point.y

        -- Handle circle event.
        local vertex = next_event.center

        self.vert_count = self.vert_count + 1
        local name = string.format('v%d', self.vert_count)

        -- add new voronoi vertex.
        local new_vert = dcel.new_vertex(self.vdcel, name, vertex.x, vertex.y)
        new_vert.index = self.vert_count

        -- par is the arc node that is dissappearing.
        local par = next_event.par

        -- remove circle events associated with par.
        local left, bp_left = beachline.arc_left(self.bl, par)
        local right, bp_right = beachline.arc_right(self.bl, par)

        if left.circle_event ~= nil then
            eq.remove(self.q, left.circle_event)
            left.circle_event = nil
        end

        if right.circle_event ~= nil then
            eq.remove(self.q, right.circle_event)
            right.circle_event = nil
        end

        -- Grab references to relevant edges
        local left_edge = bp_left.halfedge
        local right_edge = bp_right.halfedge

        -- Grab references to relevant faces
        local s1 = bp_left.first.face
        local s2 = par.site.face
        local s3 = bp_right.second.face

        -- remove arc from beachline and start a new breakpoint
        local new_breakpoint = beachline.remove_arc(self.bl, par, new_vert)

        new_breakpoint.halfedge = dcel.new_halfedge(self.vdcel)

        local new_edge = new_breakpoint.halfedge
        local twin_new_edge = dcel.new_halfedge(self.vdcel)

        new_edge.twin = twin_new_edge
        twin_new_edge.twin = new_edge

        -- Update fields in new edges
        -- TODO: update incident face fields
        dcel.setdest(left_edge, new_vert)
        dcel.setdest(right_edge, new_vert)
        dcel.setorigin(new_edge, new_vert)

        dcel.connect(left_edge, right_edge.twin)
        dcel.connect(new_edge.twin, left_edge.twin)
        dcel.connect(right_edge, new_edge)

        left_edge.incident_face = s2
        left_edge.twin.incident_face = s1
        right_edge.incident_face = s3
        right_edge.twin.incident_face = s2
        new_edge.incident_face = s3
        new_edge.twin.incident_face = s1

        s1.outeredge = left_edge.twin
        s2.outeredge = left_edge
        s3.outeredge = new_edge

        new_vert.incident_edge = new_edge

        -- rename completed edges
        if left_edge.origin and left_edge.dest then
            left_edge.name = string.format('e%d,%d', left_edge.origin.index, left_edge.dest.index)
        end

        if right_edge.origin and right_edge.dest then
            right_edge.name = string.format('e%d,%d', right_edge.origin.index, right_edge.dest.index)
        end

        -- add new circle events
        voronoi.check_circle_event(self, left)
        voronoi.check_circle_event(self, right)
    end

    return true
end

function voronoi.check_circle_event(self, check)
    if check == nil then
        return
    end

    local left, bp_left = beachline.arc_left(self.bl, check)
    local right, bp_right = beachline.arc_right(self.bl, check)

    if left == nil or right == nil or left.site == right.site then
        return
    end

    local center, event_y = util.convergence_point(left.site, check.site, right.site)

    -- Event occurrence is above beachline, no circle event
    if event_y < self.bly then
        return
    end

    -- Check breakpoints are moving towards convergence point.
    if util.bp_moving_left(bp_left) and center.x > bp_left.ray_origin.x then
        return
    end

    if util.bp_moving_right(bp_left) and center.x < bp_left.ray_origin.x then
        return
    end

    if util.bp_moving_left(bp_right) and center.x > bp_right.ray_origin.x then
        return
    end

    if util.bp_moving_right(bp_right) and center.x < bp_right.ray_origin.x then
        return
    end

    local new_event = {
        type = 'circle',
        point = { x = center.x, y = event_y },
        center = center,
        par = check,
    }

    check.circle_event = new_event

    table.insert(self.circle_centers, new_event.center)

    -- Finally add the new circle event.
    eq.push(self.q, new_event)
end

function voronoi.draw_state(self)
    love.graphics.setColor(1, 1, 1, 1)
    for name, p in pairs(self.vsites) do
        love.graphics.rectangle('fill', p.x - 2, p.y - 2, 2, 2)
        love.graphics.printf(name, p.x - 20, p.y - 20, 40, 'center')
    end

    dcel.draw(self.vdcel, {1, 0, 0, 1}, {1, 1, 1, 1})

    love.graphics.setColor(0, 1, 0, 1)
    love.graphics.line(0, self.bly, love.graphics.getWidth(), self.bly)

    if not self.finalized then
        love.graphics.setColor(1, 0, 1, 1)
        for _, p in ipairs(self.circle_centers) do
            love.graphics.rectangle('fill', p.x - 2, p.y - 2, 2, 2)
        end

        beachline.draw(self.bl, self.bly)
    end
end

function voronoi.finalize(self)
    -- Finalize voronoi diagram after all events have been processed.
    -- Each incomplete halfedge needs to be intersected with the bounding box.

    -- Collect inner nodes in the beachline.
    -- All remaining breakpoints correspond to edges we need to intersect.

    local remaining = beachline.collect_remaining(self.bl)

    local bleft = math.huge
    local bright = -math.huge
    local btop = math.huge
    local bbottom = -math.huge

    -- just make sure everything is in the bounding box
    for _, v in pairs(self.vdcel.vertices) do
        bright = math.max(bright, v.x)
        bleft = math.min(bleft, v.x)
        btop = math.min(btop, v.y)
        bbottom = math.max(bbottom, v.y)
    end

    for _, v in pairs(self.vsites) do
        bright = math.max(bright, v.x)
        bleft = math.min(bleft, v.x)
        btop = math.min(btop, v.y)
        bbottom = math.max(bbottom, v.y)
    end

    bleft = bleft - voronoi.boundary_padding
    bright = bright + voronoi.boundary_padding
    btop = btop - voronoi.boundary_padding
    bbottom = bbottom + voronoi.boundary_padding

    -- collect relevant information for each ray
    for _, v in ipairs(remaining) do
        local cx = arc.breakpoint(v.first, v.second, self.bly)
        local c = arc.point(v.first, self.bly + 10, cx)

        v.s = v.ray_origin
        v.d = {
            x = c.x - v.s.x,
            y = c.y - v.s.y,
        }
    end

    -- start intersecting rays

    -- left bounding box
    local left_rays = {}

    for _, v in ipairs(remaining) do
        local ix = bleft
        local iy = v.s.y + v.d.y * ((bleft - v.s.x) / v.d.x)

        local ver = v.halfedge.origin or v.halfedge.twin.origin

        if iy > btop and iy < bbottom and v.d.x < 0 then
            v.bvertex = {
                x = ix,
                y = iy,
            }

            table.insert(left_rays, v)
        end
    end

    table.sort(left_rays, function(a, b)
        return a.bvertex.y < b.bvertex.y
    end)

    -- right bounding box
    local right_rays = {}

    for _, v in ipairs(remaining) do
        local ix = bright
        local iy = v.s.y + v.d.y * ((bright - v.s.x) / v.d.x)

        if iy > btop and iy < bbottom and v.d.x > 0 then
            v.bvertex = {
                x = ix,
                y = iy,
            }

            table.insert(right_rays, v)
        end
    end

    table.sort(right_rays, function(a, b)
        return a.bvertex.y > b.bvertex.y
    end)

    -- top bounding box
    local top_rays = {}

    for _, v in ipairs(remaining) do
        local ix = v.s.x + v.d.x * ((btop - v.s.y) / v.d.y)
        local iy = btop

        if ix >= bleft and ix <= bright and v.d.y < 0 then
            v.bvertex = {
                x = ix,
                y = iy,
            }

            table.insert(top_rays, v)
        end
    end

    table.sort(top_rays, function(a, b)
        return a.bvertex.x > b.bvertex.x
    end)

    -- bottom bounding box
    local bottom_rays = {}

    for _, v in ipairs(remaining) do
        local ix = v.s.x + v.d.x * ((bbottom - v.s.y) / v.d.y)
        local iy = bbottom

        if ix >= bleft and ix <= bright and v.d.y > 0 then
            v.bvertex = {
                x = ix,
                y = iy,
            }

            table.insert(bottom_rays, v)
        end
    end

    table.sort(bottom_rays, function(a, b)
        return a.bvertex.x < b.bvertex.x
    end)

    -- initialize corner vertices
    local b_bl = dcel.new_vertex(self.vdcel, 'b1', bleft, bbottom)
    local b_br = dcel.new_vertex(self.vdcel, 'b2', bright, bbottom)
    local b_tr = dcel.new_vertex(self.vdcel, 'b3', bright, btop)
    local b_tl = dcel.new_vertex(self.vdcel, 'b4', bleft, btop)

    -- initialize unbounded face
    local uf = dcel.new_face(self.vdcel, 'uf')

    local bindex = 5

    function fill_dcel(first, last, rays)
        local tail = first
        local last_inner = nil
        local last_twin = nil
        local first_edge = nil

        for _, r in ipairs(rays) do
            local name = string.format('b%d', bindex)
            bindex = bindex + 1

            -- Create a boundary vertex at the ray intersection.
            local vert = dcel.new_vertex(self.vdcel, name, r.bvertex.x, r.bvertex.y)

            -- Find the inner voronoi vertex.
            -- only one of these two values is not nil.
            local v_vert = r.halfedge.origin or r.halfedge.twin.origin

            -- Create boundary halfedge pair.
            local b_edge = dcel.new_halfedge(self.vdcel, string.format('e%s,%s', tail.name, name))
            local b_edge_twin = dcel.new_halfedge(self.vdcel, string.format('e%s,%s', name, tail.name))

            b_edge_twin.incident_face = uf

            if first_edge == nil then
                first_edge = b_edge
            end

            -- Find inner halfedge ray
            local inner_edge = r.halfedge

            if r.halfedge.twin.origin then
                inner_edge = r.halfedge.twin
            end

            inner_edge.name = string.format('e%d,%s', inner_edge.origin.index, name)
            inner_edge.twin.name = string.format('e%s,%d', name, inner_edge.origin.index)

            inner_edge.dest = vert
            inner_edge.twin.origin = vert

            -- Assign boundary edge values
            b_edge.twin = b_edge_twin
            b_edge_twin.twin = b_edge
            b_edge.incident_face = inner_edge.twin.incident_face

            -- Set boundary edge vertices
            b_edge.origin = tail
            b_edge.dest = vert
            b_edge.twin.origin = vert
            b_edge_twin.dest = tail

            tail.incident_edge = b_edge

            -- connect boundary edge to inner twin
            dcel.connect(b_edge, inner_edge.twin)

            -- connect new twin to last twin
            if last_twin then
                dcel.connect(b_edge_twin, last_twin)
            end

            -- connect last inner to new bedge
            if last_inner then
                dcel.connect(last_inner, b_edge)
            end

            -- set values for next iteration
            last_inner = inner_edge
            last_twin = b_edge_twin

            tail = vert
        end

        -- connect tail vertex to last vertex
        local last_name = string.format('e%s,%s', tail.name, last.name)
        local last_twin_name = string.format('e%s,%s', last.name, tail.name)
        local last_edge = dcel.new_halfedge(self.vdcel, last_name)
        local last_twin_edge = dcel.new_halfedge(self.vdcel, last_tail_name)

        last_twin_edge.incident_face = uf

        if first_edge == nil then
            first_edge = last_edge
        end

        tail.incident_edge = last_edge

        last_edge.twin = last_twin_edge
        last_twin_edge.twin = last_edge
        last_edge.origin = tail
        last_edge.dest = last
        last_twin_edge.dest = tail
        last_twin_edge.origin = last

        if last_inner then
            dcel.connect(last_inner, last_edge)
        end

        if last_twin_edge then
            dcel.connect(last_twin_edge, last_twin)
        end

        return first_edge, last_edge
    end

    -- fill DCEL for each corner
    local bfirst, blast = fill_dcel(b_bl, b_br, bottom_rays)
    local rfirst, rlast = fill_dcel(b_br, b_tr, right_rays)
    local tfirst, tlast = fill_dcel(b_tr, b_tl, top_rays)
    local lfirst, llast = fill_dcel(b_tl, b_bl, left_rays)

    -- reconnect corners
    dcel.connect(blast, rfirst)
    dcel.connect(rfirst.twin, blast.twin)

    dcel.connect(rlast, tfirst)
    dcel.connect(tfirst.twin, rlast.twin)

    dcel.connect(tlast, lfirst)
    dcel.connect(lfirst.twin, tlast.twin)

    dcel.connect(llast, bfirst)
    dcel.connect(bfirst.twin, llast.twin)

    -- rename inner edges
    for _, e in pairs(self.vdcel.halfedges) do
        if e.prev then
            e.prev.next = e
        end

        if e.next then
            e.next.prev = e
        end

        local from = e.origin.name

        if from:sub(1, 1) == 'v' then
            from = from:sub(2, 2)
        end

        local to = e.dest.name

        if to:sub(1, 1) == 'v' then
            to = to:sub(2, 2)
        end

        e.name = string.format('e%s,%s', from, to)
    end

    -- init unbounded face
    uf.inneredge = bfirst.twin

    -- fill remaining inner faces (particularly boundary edges)
    for _, f in pairs(self.vdcel.faces) do
        if f.name:sub(1, 1) == 'c' then
            local start = f.outeredge
            start.incident_face = f

            local cur = start.next

            while cur and cur ~= start do
                cur.incident_face = f
                cur = cur.next
            end
        end
    end

    self.finalized = true
end

return voronoi
