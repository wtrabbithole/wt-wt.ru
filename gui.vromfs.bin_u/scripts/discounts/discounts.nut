local { getTimestampFromStringUtc } = require("scripts/time.nut")
local { haveDiscount, canUseIngameShop } = ::is_platform_ps4? require("scripts/onlineShop/ps4ShopData.nut")
  : ::is_platform_xboxone? require("scripts/onlineShop/xboxShopData.nut")
    : { haveDiscount = @() false, canUseIngameShop = @() false }

local topMenuOnlineShopId = ::is_platform_ps4? ::g_top_menu_buttons.PS4_ONLINE_SHOP.id
  : ::is_platform_xboxone? ::g_top_menu_buttons.XBOX_ONLINE_SHOP.id
    : ""

::g_discount <- {
  [PERSISTENT_DATA_PARAMS] = ["discountsList"]

  getDiscountIconId = @(name) name + "_discount"
  canBeVisibleOnUnit = @(unit) unit && unit.isVisibleInShop() && !unit.isBought()
  discountsList = {}

  function updateOnlineShopDiscounts()
  {
    if (topMenuOnlineShopId == "")
      return

    discountsList[topMenuOnlineShopId] = haveDiscount()
    updateDiscountNotifications()
  }

  onEventXboxShopDataUpdated = @(p) updateOnlineShopDiscounts()
  onEventPs4ShopDataUpdated = @(p) updateOnlineShopDiscounts()

  function updateGiftUnitsDiscountFromGuiBlk(giftUnits) { // !!!FIX ME Remove this function when gift units discount will received from char
    if (!::is_platform_pc)
      return

    local discountConfig = ::configs.GUI.get()?.entitlement_units_discount
    if (discountConfig == null)
      return

    local startTime = getTimestampFromStringUtc(discountConfig.beginDate)
    local endTime = getTimestampFromStringUtc(discountConfig.endDate)
    local currentTime = get_charserver_time_sec()
    if (currentTime < startTime || currentTime > endTime)
      return

    foreach (unitName, discount in discountConfig)
      if (unitName in giftUnits)
        discountsList.entitlementUnits[unitName] <- discount
  }
}

g_discount.clearDiscountsList <- function clearDiscountsList()
{
  foreach (button in ::g_top_menu_buttons.types)
    if (button.needDiscountIcon)
      discountsList[button.id] <- false
  discountsList.changeExp <- false
  discountsList.topmenu_research <- false

  discountsList.entitlements <- {}

  discountsList.entitlementUnits <- {}
  discountsList.airList <- {}
}

::g_discount.clearDiscountsList()

//return 0 if when discount not visible
g_discount.getUnitDiscount <- function getUnitDiscount(unit)
{
  if (!canBeVisibleOnUnit(unit))
    return 0
  return ::max(getUnitDiscountByName(unit.name),
               getEntitlementUnitDiscount(unit.name))
}

g_discount.getGroupDiscount <- function getGroupDiscount(list)
{
  local res = 0
  foreach(unit in list)
    res = ::max(res, getUnitDiscount(unit))
  return res
}

g_discount.pushDiscountsUpdateEvent <- function pushDiscountsUpdateEvent()
{
  ::update_gamercards()
  ::broadcastEvent("DiscountsDataUpdated")
}

g_discount.onEventUnitBought <- function onEventUnitBought(p)
{
  local unitName = ::getTblValue("unitName", p)
  if (!unitName)
    return

  if (getUnitDiscountByName(unitName) == 0 && getEntitlementUnitDiscount(unitName) == 0)
    return

  updateDiscountData()
  //push event after current event completely finished
  ::get_gui_scene().performDelayed(this, pushDiscountsUpdateEvent)
}

g_discount.updateDiscountData <- function updateDiscountData(isSilentUpdate = false)
{
  clearDiscountsList()

  local pBlk = ::get_price_blk()

  local chPath = ["exp_to_gold_rate"]
  chPath.append(::shopCountriesList)
  discountsList.changeExp = getDiscountByPath(chPath, pBlk) > 0

  local giftUnits = {}

  foreach(air in ::all_units)
    if (::isCountryAvailable(air.shopCountry)
        && !air.isBought()
        && air.isVisibleInShop())
    {
      if (::is_platform_pc && ::isUnitGift(air))
      {
        giftUnits[air.name] <- 0
        continue
      }

      local path = ["aircrafts", air.name]
      local discount = ::getDiscountByPath(path, pBlk)
      if (discount > 0)
        discountsList.airList[air.name] <- discount
    }

  local eblk = ::get_entitlements_price_blk() || ::DataBlock()
  foreach (entName, entBlock in eblk)
    checkEntitlement(entName, entBlock, giftUnits)

  updateGiftUnitsDiscountFromGuiBlk(giftUnits)  // !!!FIX ME Remove this function when gift units discount will received from char

  if (canUseIngameShop() && topMenuOnlineShopId != "")
    discountsList[topMenuOnlineShopId] = haveDiscount()

  local isShopDiscountVisible = false
  foreach(airName, discount in discountsList.airList)
    if (discount > 0 && canBeVisibleOnUnit(::getAircraftByName(airName)))
    {
      isShopDiscountVisible = true
      break
    }
  if (!isShopDiscountVisible)
    foreach(airName, discount in discountsList.entitlementUnits)
      if (discount > 0 && canBeVisibleOnUnit(::getAircraftByName(airName)))
      {
        isShopDiscountVisible = true
        break
      }
  discountsList.topmenu_research = isShopDiscountVisible

  if (!isSilentUpdate)
    pushDiscountsUpdateEvent()
}

g_discount.checkEntitlement <- function checkEntitlement(entName, entlBlock, giftUnits)
{
  local discountItemList = ["premium", "warpoints", "eagles", "campaign", "bonuses"]
  local chapter = entlBlock?.chapter
  if (!::isInArray(chapter, discountItemList))
    return

  local discount = ::get_entitlement_gold_discount(entName)
  local singleDiscount = entlBlock?.singleDiscount && !::has_entitlement(entName)
                            ? entlBlock.singleDiscount
                            : 0

  discount = ::max(discount, singleDiscount)
  if (discount == 0)
    return

  discountsList.entitlements[entName] <- discount

  if (chapter == "campaign" || chapter == "bonuses")
  {
    if (canUseIngameShop())
      chapter = topMenuOnlineShopId
  }

  local chapterVal = true
  if (chapter == topMenuOnlineShopId)
    chapterVal = canUseIngameShop() || ::is_platform_pc
  discountsList[chapter] <- chapterVal

  if (entlBlock?.aircraftGift)
    foreach(unitName in entlBlock % "aircraftGift")
      if (unitName in giftUnits)
        discountsList.entitlementUnits[unitName] <- discount
}

g_discount.generateDiscountInfo <- function generateDiscountInfo(discountsTable, headerLocId = "")
{
  local maxDiscount = 0
  local headerText = ::loc(headerLocId == ""? "discount/notification" : headerLocId) + "\n"
  local discountText = ""
  foreach(locId, discount in discountsTable)
  {
    if (discount <= 0)
      continue

    discountText += ::loc("discount/list_string", {itemName = ::loc(locId), discount = discount}) + "\n"
    maxDiscount = ::max(maxDiscount, discount)
  }

  if (discountsTable.len() > 20)
    discountText = ::format(::loc("discount/buy/tooltip"), maxDiscount.tostring())

  if (discountText == "")
    return {}

  discountText = headerText + discountText

  return {maxDiscount = maxDiscount, discountTooltip = discountText}
}

g_discount.updateDiscountNotifications <- function updateDiscountNotifications(scene = null)
{
  foreach(name in ["topmenu_research", "changeExp"])
  {
    local id = getDiscountIconId(name)
    local obj = ::checkObj(scene)? scene.findObject(id) : ::get_cur_gui_scene()[id]
    if (::checkObj(obj))
      obj.show(getDiscount(name))
  }

  local section = ::g_top_menu_right_side_sections.getSectionByName("shop")
  local sectionId = section.getTopMenuButtonDivId()
  local shopObj = ::checkObj(scene)? scene.findObject(sectionId) : ::get_cur_gui_scene()[sectionId]
  if (!::checkObj(shopObj))
    return

  local stObj = shopObj.findObject(section.getTopMenuDiscountId())
  if (!::checkObj(stObj))
    return

  local haveAnyDiscount = false
  foreach (column in section.buttons)
  {
    foreach (button in column)
    {
      if (!button.needDiscountIcon)
        continue

      local id = getDiscountIconId(button.id)
      local dObj = shopObj.findObject(id)
      if (!::checkObj(dObj))
        continue

      local discountStatus = getDiscount(button.id)
      haveAnyDiscount = haveAnyDiscount || discountStatus
      dObj.show(discountStatus)
    }
  }

  stObj.show(haveAnyDiscount)
}

g_discount.getDiscount <- function getDiscount(id, defVal = false)
{
  return discountsList?[id] ?? defVal
}

g_discount.getEntitlementDiscount <- function getEntitlementDiscount(id)
{
  return discountsList.entitlements?[id] || 0
}

g_discount.getEntitlementUnitDiscount <- function getEntitlementUnitDiscount(unitName)
{
  return discountsList.entitlementUnits?[unitName] || 0
}

g_discount.getUnitDiscountByName <- function getUnitDiscountByName(unitName)
{
  return discountsList.airList?[unitName] || 0
}

g_discount.haveAnyUnitDiscount <- function haveAnyUnitDiscount()
{
  return discountsList.entitlementUnits.len() > 0 || discountsList.airList.len() > 0
}

g_discount.getUnitDiscountList <- function getUnitDiscountList(countryId = null)
{
  if (!haveAnyUnitDiscount())
    return {}

  local discountsList = {}
  foreach(unit in ::all_units)
    if (!countryId || unit.shopCountry == countryId)
    {
      local discount = getUnitDiscount(unit)
      if (discount > 0)
        discountsList[unit.name + "_shop"] <- discount
    }

  return discountsList
}

::subscribe_handler(::g_discount, ::g_listener_priority.CONFIG_VALIDATION)
::g_script_reloader.registerPersistentDataFromRoot("g_discount")