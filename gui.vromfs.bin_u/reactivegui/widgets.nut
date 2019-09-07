local globalState = require("globalState.nut")
local widgetsState = require("widgetsState.nut")
local hudState = require("hudState.nut")
local hudUnitType = require("hudUnitType.nut")
local helicopterHud = require("helicopterHud.nut")
local shipHud = require("shipHud.nut")
local shipExHud = require("shipExHud.nut")
local shipObstacleRf = require("shipObstacleRangefinder.nut")
local shipDeathTimer = require("shipDeathTimer.nut")
local footballHud = require("footballHud.nut")
local screenState = require("style/screenState.nut")
local airHud = require("airHud.nut")
local tankHud = require("tankHud.nut")
local helicopterExHud = require("helicopterExHud.nut")


local widgetsMap = {
  [DargWidgets.HUD] = function() {
    if (!globalState.isInFlight.value)
      return null

    if (hudUnitType.isHelicopter())
      return helicopterHud
    else if (hudUnitType.isAir() && !hudState.isPlayingReplay.value)
      return airHud
    else if (hudUnitType.isTank() && !hudState.isPlayingReplay.value)
      return tankHud
    else if (hudUnitType.isShip() && !hudState.isPlayingReplay.value)
      return shipHud
    else if (hudUnitType.isSubmarine() && !hudState.isPlayingReplay.value)
      return shipExHud
    else if (hudUnitType.isUfo())
      return helicopterExHud
    else
      return null
  },

  [DargWidgets.SHIP_OBSTACLE_RF] = function () {
    return {
      size = flex()
      halign = HALIGN_CENTER
      children = [shipObstacleRf, shipDeathTimer]
    }
  },

  [DargWidgets.FOOTBALL] = @ () {
    size = flex()
    halign = HALIGN_CENTER
    children = footballHud
  }
}


local widgets = @() {
  watch = [
    globalState.isInFlight
    hudState.unitType
    hudState.isPlayingReplay
    widgetsState.widgets
    screenState.safeAreaSizeHud
  ]
  children = widgetsState.widgets.value.map(@(widget) {
    size = widget?.transform?.size ?? [sw(100), sh(100)]
    pos = widget?.transform?.pos ?? [0, 0]
    children = widgetsMap?[widget.widgetId]()
  })
}


return widgets