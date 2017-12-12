local time = require("scripts/time.nut")

const MAX_ALLOWED_WARBONDS_BALANCE = 0x7fffffff

::g_warbonds <- {
  FULL_ID_SEPARATOR = "."

  list = []
  isListValid = false

  fontIcons = {}
  isFontIconsValid = false
  defaultWbFontIcon = "currency/warbond/green"

  seenAwardsData = {}
  numUnseenAwards = {}
  numUnseenAwardsInvalidated = true
  saveSeenAwardsInvalidated = true

  maxAllowedWarbondsBalance = MAX_ALLOWED_WARBONDS_BALANCE //default value as on server side, MAX_ALLOWED_WARBONDS_BALANCE

  WARBOND_ID = "WarBond"
  SEEN_AWARDS_INFO_PREFIX = "seen/warbond_shop_award"
}

function g_warbonds::getList(filterFunc = null)
{
  validateList()
  if (filterFunc)
    return ::u.filter(list, filterFunc)
  return list
}

function g_warbonds::getVisibleList(filterFunc = null)
{
  return getList((@(filterFunc) function(wb) {
                   if (!wb.isVisible())
                     return false
                   return filterFunc ? filterFunc(wb) : true
                 })(filterFunc))
}

function g_warbonds::validateList()
{
  ::configs.PRICE.checkUpdate()
  if (isListValid)
    return
  isListValid = true

  list.clear()

  local pBlk = ::get_price_blk()
  local wBlk = pBlk.warbonds
  if (!wBlk)
    return

  maxAllowedWarbondsBalance = wBlk.maxAllowedWarbondsBalance || maxAllowedWarbondsBalance
  for(local i = 0; i < wBlk.blockCount(); i++)
  {
    local warbondBlk = wBlk.getBlock(i)
    for(local j = 0; j < warbondBlk.blockCount(); j++)
    {
      local wbListBlk = warbondBlk.getBlock(j)
      list.append(::Warbond(warbondBlk.getBlockName(), wbListBlk.getBlockName()))
    }
  }
  numUnseenAwardsInvalidated = true
  numUnseenAwards.clear()

  list.sort(function(a, b)
  {
    if (a.expiredTime != b.expiredTime)
      return a.expiredTime > b.expiredTime ? -1 : 1
    return 0
  })

  ::g_warbonds.updateSeenAwardsData()
}

function g_warbonds::getBalanceText()
{
  local wbList = getVisibleList()
  return wbList.len()? wbList[0].getBalanceText() : ""
}

function g_warbonds::isWarbondsRecounted()
{
  local hasCurrent = false
  local timersValid = true
  foreach(wb in getList())
  {
    hasCurrent = hasCurrent || wb.isCurrent()
    timersValid = timersValid && wb.getChangeStateTimeLeft() >= 0
  }
  return hasCurrent && timersValid
}

function g_warbonds::getInfoText()
{
  if (!::g_warbonds.isWarbondsRecounted())
    return ::loc("warbonds/recalculating")
  return getBalanceText()
}

function g_warbonds::findWarbond(wbId, wbListId = null)
{
  if (!wbListId)
    wbListId = ::get_warbond_curr_stage_name(wbId)

  return ::u.search(getList(), @(wb) wbId == wb.id && wbListId == wb.listId)
}

function g_warbonds::getCurrentWarbond()
{
  return findWarbond(WARBOND_ID)
}

function g_warbonds::getWarbondByFullId(wbFullId)
{
  local data = ::g_string.split(wbFullId, FULL_ID_SEPARATOR)
  if (data.len() >= 2)
    return findWarbond(data[0], data[1])
  return null
}

function g_warbonds::getWarbondAwardByFullId(wbAwardFullId)
{
  local data = ::g_string.split(wbAwardFullId, FULL_ID_SEPARATOR)
  if (data.len() < 3)
    return null

  local wb = findWarbond(data[0], data[1])
  return wb && wb.getAwardByIdx(data[2])
}

function g_warbonds::getWarbondPriceText(wbId, wbListId, amount)
{
  if (!amount)
    return ""
  if (!wbListId)
    wbListId = ::get_warbond_curr_stage_name(wbId)
  return amount + ::loc(defaultWbFontIcon)
}

function g_warbonds::openShop(params = {})
{
  if (!isShopAvailable())
    return ::showInfoMsgBox(::loc("msgbox/notAvailbleYet"))

  ::g_warbonds_view.resetShowProgressBarFlag()
  ::handlersManager.loadHandler(::gui_handlers.WarbondsShop, params)
}

function g_warbonds::isShopAvailable()
{
  return ::has_feature("Warbonds") && ::has_feature("WarbondsShop") && getList().len() > 0
}

function g_warbonds::isShopButtonVisible()
{
  return ::has_feature("Warbonds")
}

function g_warbonds::getLimit()
{
  return maxAllowedWarbondsBalance
}

function g_warbonds::checkOverLimit(battleTask, silent = false)
{
  local curWb = ::g_warbonds.getCurrentWarbond()
  if (!curWb)
    return true
  local limit = getLimit()
  local newBalance = curWb.getBalance() + battleTask.amount_warbonds
  if (newBalance <= limit)
    return true

  if (!silent)
  {
    ::scene_msg_box("warbonds_over_limit",
      null,
      ::loc("warbond/msg/awardMayBeLost", {maxWarbonds = limit, lostWarbonds = newBalance - limit}),
      [
        ["yes", @() ::g_battle_tasks.sendReceiveRewardRequest(battleTask)],
        ["#mainmenu/btnWarbondsShop", @() ::g_warbonds.openShop()],
        ["no", @() null ]
      ],
      "#mainmenu/btnWarbondsShop",
      {cancel_fn = @() null})
  }
  return false
}

function g_warbonds::getSeenAwardsInfoPath(wbClassListId)
{
  return SEEN_AWARDS_INFO_PREFIX + "/" + wbClassListId
}

function g_warbonds::getSeenAwardsDataByWb(wbClass)
{
  if (wbClass.listId in seenAwardsData)
    return seenAwardsData[wbClass.listId]

  if (!::g_login.isLoggedIn()) // Account isn't loaded yet.
    return {}

  local seenAwardsBlk = ::loadLocalByAccount(getSeenAwardsInfoPath(wbClass.listId))
  seenAwardsData[wbClass.listId] <- ::buildTableFromBlk(seenAwardsBlk)

  // Validates data as profile may become corrupted.
  foreach (awardId, lastSecSeen in seenAwardsData[wbClass.listId])
  {
    if (!::u.isArray(lastSecSeen))
      continue
    if (lastSecSeen.len() > 0)
      seenAwardsData[wbClass.listId][awardId] = lastSecSeen[0]
    else
      delete seenAwardsData[wbClass.listId][awardId]
  }
  return seenAwardsData[wbClass.listId]
}

function g_warbonds::isAwardUnseen(award, wbClass)
{
  if (!wbClass || !award || !award.isValid())
    return false

  local seenAwardsDataByWb = getSeenAwardsDataByWb(wbClass)
  if (award.id in seenAwardsDataByWb)
    return false

  return !award.isItemLocked()
}

function g_warbonds::getNumUnseenAwards(wbClass)
{
  if (!wbClass)
    return 0

  updateNumUnseenAwards()
  return ::getTblValue(wbClass.listId, numUnseenAwards, 0)
}

function g_warbonds::updateNumUnseenAwards()
{
  if (!numUnseenAwardsInvalidated)
    return

  numUnseenAwardsInvalidated = false

  foreach (wbClass in getList())
  {
    numUnseenAwards[wbClass.listId] <- 0

    foreach (award in wbClass.getAwardsList())
    {
      if (isAwardUnseen(award, wbClass))
        ++numUnseenAwards[wbClass.listId]
    }
  }
}

function g_warbonds::getNumUnseenAwardsTotal()
{
  local total = 0
  foreach (wbClass in getList())
    total += getNumUnseenAwards(wbClass)
  return total
}

function g_warbonds::markAwardsSeen(awardsList, wbClass)
{
  if (awardsList == null)
    return false

  if (!::u.isArray(awardsList))
    awardsList = [awardsList]

  local result = false
  foreach (award in awardsList)
  {
    if (!award.isItemLocked())
    {
      local seenAwardsDataByWb = getSeenAwardsDataByWb(wbClass)
      if (!(award.id in seenAwardsDataByWb))
      {
        saveSeenAwardsInvalidated = true
        numUnseenAwardsInvalidated = true
        result = true
      }
      seenAwardsData[wbClass.listId][award.id] <- wbClass.expiredTime
    }
  }

  if (result)
    ::g_warbonds.saveSeenAwardsData()
  return result
}

function g_warbonds::updateSeenAwardsData()
{
  local seenAwardsBlk = ::loadLocalByAccount(SEEN_AWARDS_INFO_PREFIX)
  seenAwardsData = ::buildTableFromBlk(seenAwardsBlk)

  local charServTime = ::get_charserver_time_sec()
  local wbListIdsToDelete = []
  foreach (wbClassListId, seenList in seenAwardsData)
  {
    if (findWarbond(WARBOND_ID, wbClassListId) != null)
      continue

    foreach (itemId, expireTime in seenList)
    {
      if (expireTime - charServTime <= 0)
        wbListIdsToDelete.append(wbClassListId)
      break
    }
  }

  foreach (wbClass in getList())
  {
    if (wbClass.getExpiredTimeLeft() <= 0)
      wbListIdsToDelete.append(wbClass.listId)

    numUnseenAwardsInvalidated = true
    saveSeenAwardsInvalidated = true
  }

  foreach (id in wbListIdsToDelete)
    if (id in seenAwardsData)
      delete seenAwardsData[id]

  ::g_warbonds.saveSeenAwardsData()
}

function g_warbonds::saveSeenAwardsData()
{
  if (!saveSeenAwardsInvalidated)
    return

  saveSeenAwardsInvalidated = false
  ::saveLocalByAccount(SEEN_AWARDS_INFO_PREFIX, seenAwardsData)
  ::broadcastEvent("UpdatedSeenWarbondAwards")
}

function g_warbonds::resetSeenAwardsData()
{
  seenAwardsData.clear()
  if (::g_login.isProfileReceived()) // Account isn't loaded yet.
    ::saveLocalByAccount(SEEN_AWARDS_INFO_PREFIX, {})
}

function g_warbonds::onEventAccountReset(p)
{
  resetSeenAwardsData()
}

function g_warbonds::onEventPriceUpdated(p)
{
  isListValid = false
}

function g_warbonds::onEventInitConfigs(p)
{
  isFontIconsValid = false
}

::subscribe_handler(::g_warbonds ::g_listener_priority.CONFIG_VALIDATION)
