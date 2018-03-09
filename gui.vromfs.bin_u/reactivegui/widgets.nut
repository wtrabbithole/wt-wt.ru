local globalState = require("globalState.nut")
local widgetsState = require("widgetsState.nut")
local hudState = require("hudState.nut")
local helicopterHud = require("helicopterHud.nut")
local shipHud = require("shipHud.nut")
local shipObstacleRf = require("shipObstacleRangefinder.nut")


local widgetsMap = {
  [DargWidgets.HUD] = function() {
    if (!globalState.isInFlight.value)
      return null

    if (hudState.unitType.value == "helicopter")
      return helicopterHud
    else if (hudState.unitType.value == "ship")
      return shipHud
    else
      return null
  },

  [DargWidgets.SHIP_OBSTACLE_RF] = function () {
    return {
      size = flex()
      halign = HALIGN_CENTER
      children = shipObstacleRf
    }
  }
}



local widgets = @() {
  watch = [
    globalState.isInFlight
    hudState.unitType
    widgetsState.widgets
  ]
  children = widgetsState.widgets.value.map(function(widget) {
    return widgetsMap?[widget?.widgetId]()
  })
}


return widgets