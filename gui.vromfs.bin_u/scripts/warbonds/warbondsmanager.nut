::g_warbonds <- {
  FULL_ID_SEPARATOR = "."

  list = []
  isListValid = false

  fontIcons = {}
  isFontIconsValid = false
  defaultWbFontIcon = "currency/warbond"
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

  for(local i = 0; i < wBlk.blockCount(); i++)
  {
    local warbondBlk = wBlk.getBlock(i)
    for(local j = 0; j < warbondBlk.blockCount(); j++)
    {
      local wbListBlk = warbondBlk.getBlock(j)
      list.append(::Warbond(warbondBlk.getBlockName(), wbListBlk.getBlockName()))
    }
  }

  list.sort(function(a, b)
  {
    if (a.expiredTime != b.expiredTime)
      return a.expiredTime > b.expiredTime ? -1 : 1
    return 0
  })
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

function g_warbonds::getBalanceText(wbId = null, wbListId = null, showNextTime = true)
{
  local wbList = getVisibleList((@(wbId, wbListId) function(wb) {
                                  return (!wbId || wbId == wb.id) && (!wbListId || wbListId == wb.listId)
                                })(wbId, wbListId))
  local textList = ::u.map(wbList, function (wb) { return ::colorize("activeTextColor", wb.getBalanceText()) })

  if (showNextTime)
  {
    local nextTime = 0
    local nextTimeIdx = -1
    foreach(idx, wb in wbList)
    {
      local timeLeft = wb.getChangeStateTimeLeft()
      if (!timeLeft)
        continue
      if (timeLeft > nextTime && nextTimeIdx >= 0)
        continue
      nextTime = timeLeft
      nextTimeIdx = idx
    }
    if (nextTimeIdx in textList)
    {
      local timeText = ::hoursToString(nextTime.tofloat() / TIME_HOUR_IN_SECONDS, false, true)
      textList[nextTimeIdx] += " " + ::loc("ui/parentheses", { text = timeText })
    }
  }

  return ::implode(textList, ", ")
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
  return ::u.search(getList(),
                    (@(wbId, wbListId) function(wb) {
                      return wbId == wb.id && wbListId == wb.listId
                    })(wbId, wbListId))
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
  return wb && wb.getAwardById(data[2])
}

function g_warbonds::checkLoadWarbondsIcons()
{
  if (isFontIconsValid)
    return
  isFontIconsValid = true

  fontIcons.clear()
  local blk = ::get_gui_regional_blk()
  local iconsBlk = blk.warbondsFontIcons
  if (!::u.isDataBlock(iconsBlk))
    return

  for(local i = 0; i < iconsBlk.blockCount(); i++)
  {
    local wbBlk = iconsBlk.getBlock(i)
    local wbName = wbBlk.getBlockName()
    if (!(wbName in fontIcons))
      fontIcons[wbName] <- {}

    for(local j = 0; j < wbBlk.paramCount(); j++)
    {
      local value = wbBlk.getParamValue(j)
      if (!::u.isString(value))
        continue
      fontIcons[wbName][wbBlk.getParamName(j)] <- value
    }
  }
}

function g_warbonds::getWarbondFontIcon(wbId, wbListId)
{
  checkLoadWarbondsIcons()
  return ::getTblValue(wbListId, ::getTblValue(wbId, fontIcons), defaultWbFontIcon)
}

function g_warbonds::getWarbondPriceText(wbId, wbListId, amount)
{
  if (!amount)
    return ""
  if (!wbListId)
    wbListId = ::get_warbond_curr_stage_name(wbId)
  return amount + ::loc(getWarbondFontIcon(wbId, wbListId))
}

function g_warbonds::openShop(params = {})
{
  if (!isShopAvailable())
    return ::showInfoMsgBox(::loc("msgbox/notAvailbleYet"))
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

function g_warbonds::onEventPriceUpdated(p)
{
  isListValid = false
}

function g_warbonds::onEventInitConfigs(p)
{
  isFontIconsValid = false
}

::subscribe_handler(::g_warbonds ::g_listener_priority.CONFIG_VALIDATION)