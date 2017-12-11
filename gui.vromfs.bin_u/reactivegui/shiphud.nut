local activeOrder = require("activeOrder.nut")
local shipStateModule = require("shipStateModule.nut")
local depthGauge = require("shipDepthGauge.nut")
local hudLogs = require("hudLogs.nut")


return {
  vplace = VALIGN_BOTTOM
  size = SIZE_TO_CONTENT
  flow = FLOW_VERTICAL
  margin = [sh(5), sh(1)] //keep gap for counters
  gap = sh(1)
  children = [
    activeOrder
    hudLogs
    depthGauge
    shipStateModule
  ]
}
