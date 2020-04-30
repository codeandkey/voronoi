local sites = require 'sites'
local voronoi = require 'voronoi'
local dcel = require 'dcel'
local beachline = require 'beachline'
local util = require 'util'
local delaunay = require 'delaunay'

local vsites = sites.parse('sites.txt')
local vstate = voronoi.init(vsites)
local ddcel = nil

local cx = 0
local cy = 0
local cscale = 1
local cscalespeed = 0.2
local cspeed = 300

function love.keypressed(key)
    if key == 'space' then
        if voronoi.step(vstate) then
        elseif not vstate.finalized then
            voronoi.finalize(vstate)
            dcel.write(vstate.vdcel)
        else
            ddcel = delaunay.generate(vstate.vdcel)
            dcel.write(ddcel)
        end
    end
end

function love.update(dt)
    if love.keyboard.isDown('x') then
        vstate.bly = vstate.bly + math.floor(100 * dt)
    end

    if love.keyboard.isDown('left') then
        cx = cx - dt * cspeed
    end

    if love.keyboard.isDown('right') then
        cx = cx + dt * cspeed
    end

    if love.keyboard.isDown('up') then
        cy = cy - dt * cspeed
    end

    if love.keyboard.isDown('down') then
        cy = cy + dt * cspeed
    end

    if love.keyboard.isDown('w') then
        cscale = cscale - dt * cscalespeed
    end

    if love.keyboard.isDown('s') then
        cscale = cscale + dt * cscalespeed
    end
end

function love.draw()
    love.graphics.push()
    love.graphics.translate(-cx + love.graphics.getWidth() / 2, -cy + love.graphics.getHeight() / 2)
    love.graphics.scale(cscale)

    if ddcel then
        dcel.draw(ddcel, {0, 0, 1, 1}, {1, 1, 1, 1})
    end

    voronoi.draw_state(vstate)

    love.graphics.pop()
end
