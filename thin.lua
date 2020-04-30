local sites = require 'sites'
local voronoi = require 'voronoi'
local dcel = require 'dcel'
local beachline = require 'beachline'
local util = require 'util'
local delaunay = require 'delaunay'

local vsites = sites.parse('sites.txt')
local vstate = voronoi.init(vsites)
local ddcel = nil

while voronoi.step(vstate) do
end

voronoi.finalize(vstate)
ddcel = delaunay.generate(vstate.vdcel)

io.output('voronoi.txt')

io.write('****** Voronoi diagram ******\n\n')
dcel.write(vstate.vdcel)
io.write('\n****** Delaunay triangulation ******\n\n')
dcel.write(ddcel)
