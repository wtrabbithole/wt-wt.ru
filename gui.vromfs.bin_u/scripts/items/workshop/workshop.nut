local u = ::require("std/u.nut")
local Set = ::require("workshopSet.nut")
local inventoryClient = require("scripts/inventory/inventoryClient.nut")

local isInited = false
local setsList = []
local emptySet = Set(::DataBlock())

local function initOnce()
{
  if (isInited || !::g_login.isProfileReceived())
    return
  isInited = true
  setsList.clear()

  local wBlk = ::DataBlock("config/workshop.blk")
  for(local i = 0; i < wBlk.blockCount(); i++)
  {
    local set = Set(wBlk.getBlock(i))
    if (!set.isValid())
      continue

    set.uid = setsList.len()
    setsList.append(set)

    if (set.isVisible())
      inventoryClient.requestItemdefsByIds(set.itemdefsSorted)
  }
  Set.clearOutdatedData(setsList)
}

local function invalidateCache()
{
  setsList.clear()
  isInited = false
}

local function getSetsList()
{
  initOnce()
  return setsList
}

local function shouldDisguiseItem(item)
{
  foreach(set in getSetsList())
    if (set.isItemInSet(item))
      return set.shouldDisguiseItem(item)
  return false
}

::subscribe_handler({
  onEventSignOut = @(p) invalidateCache()
}, ::g_listener_priority.CONFIG_VALIDATION)

return {
  emptySet = emptySet

  isAvailable = @() u.search(getSetsList(), @(s) s.isVisible()) != null
  getSetsList = @() getSetsList()
  shouldDisguiseItem = shouldDisguiseItem
  getSetByItemId = @(itemId) u.search(getSetsList(), @(s) s.isItemIdInSet(itemId))
}