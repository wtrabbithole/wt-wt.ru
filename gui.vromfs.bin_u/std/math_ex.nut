/*
  This module have all math functions
*/

local math = require("math.nut").__merge(require("math"),require("dagor.math"))

local function degToRad(angle){
  return angle/180.0*math.PI
}

return math.__merge({degToRad = degToRad})
