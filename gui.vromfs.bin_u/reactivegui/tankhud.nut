local radarComponent = require("radarComponent.nut")
local aamAim = require("rocketAamAim.nut")
local tws = require("tws.nut")
local {IsMlwsLwsHudVisible} = require("twsState.nut")

local greenColor = Color(10, 202, 10, 250)
local getColor = @() greenColor

local styleAamAim = {
  color = greenColor
  fillColor = Color(0, 0, 0, 0)
  lineWidth = hdpx(1) * 2.0
}

local function Root() {
  return {
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    size = [sw(100), sh(100)]
    children = [
      radarComponent.radar(false)
      aamAim(styleAamAim, getColor)
    ]
  }
}


local function tankTws() {
  return @(){
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    size = flex() //linked to damagePanel, and size can be changed in option
    watch = IsMlwsLwsHudVisible
    children = !IsMlwsLwsHudVisible.value ? null :
      tws({
          colorStyle = styleAamAim,
          pos = [0, 0],
          size = [pw(80), ph(80)],
          relativCircleSize = 49,
          needDrawCentralIcon = false
        })
  }
}


return {
  Root
  tankTws
}
