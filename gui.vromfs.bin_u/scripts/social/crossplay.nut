local subscriptions = require("sqStdlibs/helpers/subscriptions.nut")

local persistentData = {
  crossNetworkPlayStatus = null
  crossNetworkChatStatus = null
}
::g_script_reloader.registerPersistentData("crossplay", persistentData,
  ["crossNetworkPlayStatus", "crossNetworkChatStatus"])

local updateCrossNetworkPlayStatus = function()
{
  if (persistentData.crossNetworkPlayStatus != null)
    return

  persistentData.crossNetworkPlayStatus = !::is_platform_xboxone || ::check_crossnetwork_play_privilege()
  ::broadcastEvent("CrossPlayOptionChanged")
}

local isCrossNetworkPlayEnabled = function()
{
  updateCrossNetworkPlayStatus()
  return persistentData.crossNetworkPlayStatus
}

local updateCrossNetworkChatStatus = function()
{
  if (persistentData.crossNetworkChatStatus != null)
    return

  persistentData.crossNetworkChatStatus = !::is_platform_xboxone? XBOX_COMMUNICATIONS_ALLOWED
                                                 : ::check_crossnetwork_communications_permission()
}

local isCrossNetworkChatEnabled = function()
{
  updateCrossNetworkChatStatus()
  return persistentData.crossNetworkChatStatus != XBOX_COMMUNICATIONS_BLOCKED
}

local getCrossNetworkChatStatus = function()
{
  updateCrossNetworkChatStatus()
  return persistentData.crossNetworkChatStatus
}

local getTextWithCrossplayIcon = @(addIcon, text) (addIcon? (::loc("icon/cross_play") + " " ) : "") + text

local invalidateCache = function()
{
  persistentData.crossNetworkPlayStatus = null
  persistentData.crossNetworkChatStatus = null
}

subscriptions.addListenersWithoutEnv({
  XboxSystemUIReturn = function(p) {
    invalidateCache()
    updateCrossNetworkPlayStatus()
    updateCrossNetworkChatStatus()
  }
  SignOut = @(p) invalidateCache()
}, ::g_listener_priority.CONFIG_VALIDATION)

return {
  isCrossPlayEnabled = isCrossNetworkPlayEnabled
  isCrossNetworkChatEnabled = isCrossNetworkChatEnabled
  getCrossNetworkChatStatus = getCrossNetworkChatStatus
  getTextWithCrossplayIcon = getTextWithCrossplayIcon
}