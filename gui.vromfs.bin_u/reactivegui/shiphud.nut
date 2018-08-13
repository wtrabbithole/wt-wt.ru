local networkState = require("networkState.nut")
local activeOrder = require("activeOrder.nut")
local shipStateModule = require("shipStateModule.nut")
local hudLogs = require("hudLogs.nut")
local voiceChat = require("chat/voiceChat.nut")


local shipHud = @(){
  watch = networkState.isMultiplayer
  size = [SIZE_TO_CONTENT, flex()]
  flow = FLOW_VERTICAL
  valign = VALIGN_BOTTOM
  margin = [sh(5), sh(1)] //keep gap for counters
  gap = sh(1)
  children = [
    voiceChat
    activeOrder
    networkState.isMultiplayer.value ? hudLogs : null
    shipStateModule
  ]
}


return {
  size = flex()
  valign = VALIGN_BOTTOM
  halign = HALIGN_LEFT
  children = [shipHud]
}
