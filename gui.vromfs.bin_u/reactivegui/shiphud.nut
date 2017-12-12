local networkState = require("networkState.nut")
local activeOrder = require("activeOrder.nut")
local shipStateModule = require("shipStateModule.nut")
local obstacleRangefinder = require("shipObstacleRangefinder.nut")
local hudLogs = require("hudLogs.nut")


return @(){
  watch = networkState.isMultiplayer
  vplace = VALIGN_BOTTOM
  size = SIZE_TO_CONTENT
  flow = FLOW_VERTICAL
  margin = [sh(5), sh(1)] //keep gap for counters
  gap = sh(1)
  children = [
    activeOrder
    networkState.isMultiplayer.value ? hudLogs : null
    obstacleRangefinder
    shipStateModule
  ]
}
