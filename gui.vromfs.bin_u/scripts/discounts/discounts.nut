local xboxShopData = ::require("scripts/onlineShop/xboxShopData.nut")

::g_discount <- {
  [PERSISTENT_DATA_PARAMS] = ["discountsList"]

  getDiscountIconId = @(name) name + "_discount"
  canBeVisibleOnUnit = @(unit) unit && unit.isVisibleInShop() && !unit.isBought()
  discountsList = {}
}

function g_discount::clearDiscountsList()
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
function g_discount::getUnitDiscount(unit)
{
  if (!canBeVisibleOnUnit(unit))
    return 0
  return ::max(getUnitDiscountByName(unit.name),
               getEntitlementUnitDiscount(unit.name))
}

function g_discount::getGroupDiscount(list)
{
  local res = 0
  foreach(unit in list)
    res = ::max(res, getUnitDiscount(unit))
  return res
}

function g_discount::pushDiscountsUpdateEvent()
{
  ::update_gamercards()
  ::broadcastEvent("DiscountsDataUpdated")
}

function g_discount::onEventUnitBought(p)
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

function g_discount::updateXboxShopDiscounts()
{
  discountsList[::g_top_menu_buttons.ONLINE_SHOP.id] = xboxShopData.haveDiscount()
  updateDiscountNotifications()
}

function g_discount::updateDiscountData(isSilentUpdate = false)
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

  if (xboxShopData.canUseIngameShop())
    discountsList[::g_top_menu_buttons.ONLINE_SHOP.id] = xboxShopData.haveDiscount()

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

function g_discount::checkEntitlement(entName, entlBlock, giftUnits)
{
  local discountItemList = ["premium", "warpoints", "eagles", "campaign", "bonuses"]
  local chapter = entlBlock.chapter
  if (!::isInArray(chapter, discountItemList))
    return

  local discount = ::get_entitlement_gold_discount(entName)
  local singleDiscount = entlBlock.singleDiscount && !::has_entitlement(entName)
                            ? entlBlock.singleDiscount
                            : 0

  discount = ::max(discount, singleDiscount)
  if (discount == 0)
    return

  discountsList.entitlements[entName] <- discount

  if (chapter == "campaign" || chapter == "bonuses")
    chapter = ::g_top_menu_buttons.ONLINE_SHOP.id

  discountsList[chapter] <- chapter == ::g_top_menu_buttons.ONLINE_SHOP.id ?
      (xboxShopData.canUseIngameShop() || ::is_platform_pc)
    : true

  if (entlBlock.aircraftGift)
    foreach(unitName in entlBlock % "aircraftGift")
      if (unitName in giftUnits)
        discountsList.entitlementUnits[unitName] <- discount
}

function g_discount::generateDiscountInfo(discountsTable, headerLocId = "")
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

function g_discount::updateDiscountNotifications(scene = null)
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

function g_discount::onEventXboxShopDataUpdated(p)
{
  updateXboxShopDiscounts()
}

function g_discount::getDiscount(id, defVal = false)
{
  return discountsList[id] || defVal
}

function g_discount::getEntitlementDiscount(id)
{
  return discountsList.entitlements?[id] || 0
}

function g_discount::getEntitlementUnitDiscount(unitName)
{
  return discountsList.entitlementUnits?[unitName] || 0
}

function g_discount::getUnitDiscountByName(unitName)
{
  return discountsList.airList?[unitName] || 0
}

function g_discount::haveAnyUnitDiscount()
{
  return discountsList.entitlementUnits.len() > 0 || discountsList.airList.len() > 0
}

function g_discount::getUnitDiscountList(countryId = null)
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