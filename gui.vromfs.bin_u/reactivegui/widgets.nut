local globalState = require("globalState.nut")
local widgetsState = require("widgetsState.nut")
local hudState = require("hudState.nut")
local helicopterHud = require("reactiveGui/helicopterHud.nut")
local shipHud = require("reactiveGui/shipHud.nut")


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