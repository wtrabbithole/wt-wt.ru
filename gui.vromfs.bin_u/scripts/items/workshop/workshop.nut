local u = ::require("std/u.nut")
local Set = ::require("workshopSet.nut")
local inventoryClient = require("scripts/inventory/inventoryClient.nut")
local seenWorkshop = ::require("scripts/seen/seenList.nut").get(SEEN.WORKSHOP)

local OUT_OF_DATE_DAYS_WORKSHOP = 28

local isInited = false
local setsList = []
local emptySet = Set(::DataBlock())

local visibleSeenIds = null
local seenIdCanBeNew = {}

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

    seenWorkshop.setSubListGetter(set.getSeenId(), @() set.getVisibleSeenIds())
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

local function shouldDisguiseItemId(id)
{
  foreach(set in getSetsList())
    if (set.isItemIdInSet(id))
      return set.shouldDisguiseItemId(id)
  return false
}

local function getVisibleSeenIds()
{
  if (!visibleSeenIds)
  {
    visibleSeenIds = {}
    foreach(set in getSetsList())
      if (set.isVisible())
        visibleSeenIds.__update(set.getVisibleSeenIds())
  }
  return visibleSeenIds
}

local function invalidateItemsCache()
{
  visibleSeenIds = null
  seenIdCanBeNew.clear()
  foreach(set in getSetsList())
    set.invalidateItemsCache()
  if (ItemsManager.isInventoryFullUpdated)
    seenWorkshop.setDaysToUnseen(OUT_OF_DATE_DAYS_WORKSHOP)
  seenWorkshop.onListChanged()
}

local function canSeenIdBeNew(seenId)
{
  if (!(seenId in seenIdCanBeNew))
  {
    local id = ::to_integer_safe(seenId, seenId, false) //ext inventory items id need to convert to integer.
    seenIdCanBeNew[seenId] <- !shouldDisguiseItemId(id)
  }
  return seenIdCanBeNew[seenId]
}

::subscribe_events({
  SignOut = @(p) invalidateCache()
  InventoryUpdate = @(p) invalidateItemsCache()
  ItemsShopUpdate = @(p) invalidateItemsCache()
}, ::g_listener_priority.CONFIG_VALIDATION)

seenWorkshop.setListGetter(getVisibleSeenIds)
seenWorkshop.setCanBeNewFunc(canSeenIdBeNew)

return {
  emptySet = emptySet

  isAvailable = @() u.search(getSetsList(), @(s) s.isVisible()) != null
  getSetsList = @() getSetsList()
  shouldDisguiseItem = @(item) shouldDisguiseItemId(item.id)
  getSetByItemId = @(itemId) u.search(getSetsList(), @(s) s.isItemIdInSet(itemId))
}