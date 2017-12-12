::g_item_limits <- {

  /** Seconds to keep limit data without updating. */
  ITEM_REFRESH_TIME = 60

  /** Seconds to timout the request. */
  REQUEST_UNLOCK_TIMEOUT = 45

  /** Maximum number of items to go in a single request. */
  MAX_REQUEST_SIZE = 0 // Disabled for now.

  limitDataByItemName = {}
  itemNamesQueue = []
  isRequestLocked = false
  requestLockTime = -1 // Milliseconds
}

//
// Public
//

function g_item_limits::requestLimits(isBlocking = false)
{
  if (requestLockTime < ::max(::dagor.getCurTime() - REQUEST_UNLOCK_TIMEOUT * 1000, 0))
    isRequestLocked = false

  if (isRequestLocked)
    return false

  local curTime = ::dagor.getCurTime()

  local requestBlk = ::DataBlock()
  local requestSize = 0
  while (itemNamesQueue.len() > 0 && checkRequestSize(requestSize))
  {
    local itemName = itemNamesQueue.pop()
    local limitData = getLimitDataByItemName(itemName)
    if (limitData.lastUpdateTime < ::max(curTime - ITEM_REFRESH_TIME * 1000, 0))
    {
      requestBlk["name"] <- itemName
      ++requestSize
    }
  }

  itemNamesQueue.clear()
  if (requestSize == 0)
    return false

  isRequestLocked = true
  requestLockTime = curTime

  local taskId = ::get_items_count_for_limits(requestBlk)
  local taskOptions = {
    showProgressBox = isBlocking
  }
  local taskCallback = function (result = ::YU2_OK)
    {
      ::g_item_limits.isRequestLocked = false
      if (result == ::YU2_OK)
      {
        local resultBlk = ::get_items_count_for_limits_result()
        ::g_item_limits.onRequestComplete(resultBlk)
      }
      ::broadcastEvent("ItemLimitsUpdated")
    }
  return ::g_tasker.addTask(taskId, taskOptions, taskCallback, taskCallback)
}

function g_item_limits::enqueueItem(itemName)
{
  ::u.appendOnce(itemName, itemNamesQueue)
}

function g_item_limits::requestLimitsForItem(itemId, forceRefresh = false)
{
  if (forceRefresh)
    getLimitDataByItemName(itemId).lastUpdateTime = -1
  enqueueItem(itemId)
  requestLimits()
}

function g_item_limits::getLimitDataByItemName(itemName)
{
  return ::getTblValue(itemName, limitDataByItemName) || createLimitData(itemName)
}

//
// Private
//

function g_item_limits::onRequestComplete(resultBlk)
{
  for (local i = resultBlk.blockCount() - 1; i >= 0; --i)
  {
    local itemBlk = resultBlk.getBlock(i)
    local itemName = itemBlk.getBlockName()
    local limitData = getLimitDataByItemName(itemName)
    limitData.countGlobal = itemBlk.countGlobal || 0
    limitData.countPersonalTotal = itemBlk.countPersonalTotal || 0
    limitData.countPersonalAtTime = itemBlk.countPersonalAtTime || 0
    limitData.lastUpdateTime = ::dagor.getCurTime()
  }
  requestLimits()
}

function g_item_limits::createLimitData(itemName)
{
  ::dagor.assertf(
    !(itemName in limitDataByItemName),
    ::format("Limit data with name %s already exists.", itemName)
  )

  local limitData = {
    itemName = itemName
    countGlobal = -1
    countPersonalTotal = -1
    countPersonalAtTime = -1
    lastUpdateTime = -1 // Milliseconds
  }
  limitDataByItemName[itemName] <- limitData
  return limitData
}

function g_item_limits::checkRequestSize(requestSize)
{
  return MAX_REQUEST_SIZE == 0 || requestSize < MAX_REQUEST_SIZE
}
