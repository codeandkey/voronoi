local dcel = {}
local util = require 'util'

function dcel.write(self)
    for _, v in pairs(self.vertices) do
        io.write(string.format('%s (%f, %f) %s\n', v.name, v.x, v.y, util.name_of(v.incident_edge)))
    end

    io.write('\n')

    for _, v in pairs(self.faces) do
        io.write(string.format('%s %s %s\n', v.name, util.name_of(v.inneredge), util.name_of(v.outeredge)))
    end

    io.write('\n')

    for _, v in pairs(self.halfedges) do
        io.write(string.format('%s %s %s %s %s %s\n', v.name, util.name_of(v.origin), util.name_of(v.twin), util.name_of(v.incident_face), util.name_of(v.next), util.name_of(v.prev)))
    end
end

function dcel.draw(self, edge_color, vertex_color)
    -- render halfedges
    love.graphics.setColor(edge_color)
    for _, obj in pairs(self.halfedges) do
        if obj.origin ~= nil and obj.dest ~= nil then
            local src = obj.origin
            local dst = obj.dest
            love.graphics.line(src.x, src.y, dst.x, dst.y)
        end
    end

    -- render vertices
    love.graphics.setColor(vertex_color)
    for _, obj in pairs(self.vertices) do
        love.graphics.rectangle('fill', obj.x - 2, obj.y - 2, 4, 4)
        love.graphics.printf(obj.name, obj.x - 20, obj.y - 20, 40, 'center')
    end
end

function dcel.new_halfedge(self, name)
    local new_edge = {}
    if name then
        new_edge.name = name
    end
    table.insert(self.halfedges, new_edge)
    return new_edge
end

function dcel.new_face(self, name)
    local new_face = {
        name = name,
    }

    table.insert(self.faces, new_face)
    return new_face
end

function dcel.new_vertex(self, name, x, y)
    local new_vert = {
        name = name,
        x = x,
        y = y,
    }

    table.insert(self.vertices, new_vert)
    return new_vert
end

function dcel.add_face(self, name)
    self.faces[name] = {
        name = name,
    }

    return self.faces[name]
end

function dcel.connect(first, second)
    first.next = second
    second.prev = first
end

function dcel.setdest(edge, vert)
    edge.dest = vert
    edge.twin.origin = vert
end

function dcel.setorigin(edge, vert)
    dcel.setdest(edge.twin, vert)
end

function dcel.new()
    return {
        vertices = {},
        faces = {},
        halfedges = {},
    }
end

return dcel
