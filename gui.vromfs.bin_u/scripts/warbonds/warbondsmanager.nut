local time = require("scripts/time.nut")
local seenWarbondsShop = ::require("scripts/seen/seenList.nut").get(SEEN.WARBONDS_SHOP)

const MAX_ALLOWED_WARBONDS_BALANCE = 0x7fffffff
local OUT_OF_DATE_DAYS_WARBONDS_SHOP = 28

::g_warbonds <- {
  FULL_ID_SEPARATOR = "."

  list = []
  isListValid = false

  fontIcons = {}
  isFontIconsValid = false
  defaultWbFontIcon = "currency/warbond/green"

  visibleSeenIds = null

  maxAllowedWarbondsBalance = MAX_ALLOWED_WARBONDS_BALANCE //default value as on server side, MAX_ALLOWED_WARBONDS_BALANCE

  WARBOND_ID = "WarBond"
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
      local wbClass = ::Warbond(warbondBlk.getBlockName(), wbListBlk.getBlockName())
      list.append(wbClass)
      seenWarbondsShop.setSubListGetter(wbClass.getSeenId(), @() wbClass.getUnseenAwardIds())
    }
  }

  list.sort(function(a, b)
  {
    if (a.expiredTime != b.expiredTime)
      return a.expiredTime > b.expiredTime ? -1 : 1
    return 0
  })

  visibleSeenIds = null
  seenWarbondsShop.setDaysToUnseen(OUT_OF_DATE_DAYS_WARBONDS_SHOP)
  seenWarbondsShop.onListChanged()
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

function g_warbonds::onEventPriceUpdated(p)
{
  isListValid = false
}

function g_warbonds::onEventInitConfigs(p)
{
  isFontIconsValid = false
}

function g_warbonds::getUnseenAwardIds()
{
  if (!visibleSeenIds)
  {
    visibleSeenIds = []
    foreach(wbClass in getList())
      visibleSeenIds.extend(::u.map(
        wbClass.getAwardsList().filter(@(idx, award) !award.isItemLocked()),
        @(award) award.getSeenId()))
  }

  return visibleSeenIds
}

::subscribe_handler(::g_warbonds ::g_listener_priority.CONFIG_VALIDATION)

seenWarbondsShop.setListGetter(@() ::g_warbonds.getUnseenAwardIds())
seenWarbondsShop.setCompatibilityLoadData(function()
 {
   local res = {}
   local savePath = "seen/warbond_shop_award"
   local blk = ::loadLocalByAccount(savePath)
   if (!::u.isDataBlock(blk))
     return res

   for (local i = 0; i < blk.blockCount(); i++)
   {
     local warbondBlk = blk.getBlock(i)
     for (local j = 0; j < warbondBlk.paramCount(); j++)
       res[warbondBlk.getBlockName() + "_" + warbondBlk.getParamName(j)] <- warbondBlk.getParamValue(j)
   }
   ::saveLocalByAccount(savePath, null)
   return res
  })
