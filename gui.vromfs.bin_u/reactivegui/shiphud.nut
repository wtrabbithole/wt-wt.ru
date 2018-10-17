local networkState = require("networkState.nut")
local activeOrder = require("activeOrder.nut")
local shipStateModule = require("shipStateModule.nut")
local hudLogs = require("hudLogs.nut")
local voiceChat = require("chat/voiceChat.nut")
local screenState = require("style/screenState.nut")


local shipHud = @(){
  watch = networkState.isMultiplayer
  size = [SIZE_TO_CONTENT, flex()]
  margin = screenState.safeAreaSizeHud.value.borders
  flow = FLOW_VERTICAL
  valign = VALIGN_BOTTOM
  halign = HALIGN_LEFT
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
  children = [shipHud]
}
