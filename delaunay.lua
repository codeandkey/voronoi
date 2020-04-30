local delaunay = {}

local dcel = require 'dcel'

function delaunay.generate(vdcel)
    -- Walk through each edge adjacent to two cells.
    local ddcel = dcel.new()
    local sitelist = {}

    -- Create site vertices
    for _, e in pairs(vdcel.faces) do
        if e.site then
            sitelist[e.site.index] = dcel.new_vertex(ddcel,
                string.format('p%d', e.site.index),
                e.site.x,
                e.site.y
            )

            sitelist[e.site.index].index = e.site.index
        end
    end

    -- Determine which sites are connected

    for _, e in pairs(vdcel.halfedges) do
        if e.incident_face.name:sub(1, 1) == 'c' then
            if e.twin.incident_face.name:sub(1, 1) == 'c' then
                local first = tonumber(e.incident_face.name:sub(2, 2))
                local second = tonumber(e.twin.incident_face.name:sub(2, 2))

                if first < second then
                    -- Connect first to second with two half edges.

                    local new_edge = dcel.new_halfedge(ddcel, string.format('d%d,%d', first, second))
                    local new_edge_twin = dcel.new_halfedge(ddcel, string.format('d%d,%d', second, first))

                    new_edge.twin = new_edge_twin
                    new_edge_twin.twin = new_edge

                    new_edge.origin = sitelist[first]
                    new_edge.dest = sitelist[second]
                    new_edge_twin.origin = sitelist[second]
                    new_edge_twin.dest = sitelist[first]
                end
            end
        end
    end

    -- Perform edge connections at sites
    for _, s in pairs(sitelist) do
        local incoming = {}

        for _, e in pairs(ddcel.halfedges) do
            if e.dest == s then
                table.insert(incoming, e)
            end
        end

        -- We need to walk through the incoming edges in a clockwise or counterclockwise order.
        -- Compute the angle of each edge.

        for _, e in ipairs(incoming) do
            e.angle = math.atan2(e.origin.y - e.dest.y, e.origin.x - e.dest.x)
        end

        table.sort(incoming, function(a, b)
            return a.angle < b.angle
        end)

        local num = #incoming

        for i, iedge in ipairs(incoming) do
            local nind = i + 1

            if nind > num then
                nind = 1
            end

            local inext = incoming[nind]

            dcel.connect(iedge, inext.twin)
        end
    end

    -- Generate faces
    local fnum = 1

    for _, e in pairs(ddcel.halfedges) do
        if not e.incident_face then
            local new_face = dcel.new_face(ddcel, string.format('t%d', fnum))
            fnum = fnum + 1
            e.incident_face = new_face
            new_face.outeredge = e

            local cur = e.next
            while cur ~= e do
                cur.incident_face = new_face
                cur = cur.next
            end
        end
    end

    -- Find unbounded face
    for _, e in pairs(vdcel.halfedges) do
        -- Edges from a voronoi vertex to a boundary are the clue.
        -- It indicates that the halfedge connecting the two adjacent sites will border the unbounded face.

        if e.origin.name:sub(1, 1) == 'v' and e.dest.name:sub(1, 1) == 'b' then
            local top = e.incident_face.site.index
            local bottom = e.twin.incident_face.site.index

            -- So, the halfedge connecting top to bottom is incident to the unbounded face.

            for _, i in pairs(ddcel.halfedges) do
                if i.origin.index == top and i.dest.index == bottom then
                    -- simply rename the face record.
                    local ff = i.incident_face
                    ff.inneredge, ff.outeredge = ff.outeredge, ff.inneredge
                    i.incident_face.name = 'uf'
                    break
                end
            end
        end
    end

    return ddcel
end

return delaunay
