local u = ::require("std/u.nut")

local sendingList = {}

local function updateSendingList()
{
  local newList = ::inventory_get_transfer_items_by_state(INVENTORY_STATE_SENDING)

  local isChanged = newList.len() != sendingList.len()
  if (!isChanged)
    foreach(key, data in newList)
      if (!(key in sendingList))
      {
        isChanged = true
        break
      }
  sendingList = newList
  if (isChanged)
    ::broadcastEvent("SendingItemsChanged")
}

::subscribe_events({
  SignOut = @(p) sendingList.clear()
  ProfileUpdated = @(p) updateSendingList()
  ScriptsReloaded = @(p) ::g_login.isProfileReceived() && updateSendingList()
}, ::g_listener_priority.CONFIG_VALIDATION)

return {
  getSendingList = @() sendingList
}