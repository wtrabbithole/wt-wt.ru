local xboxShopData = ::require("scripts/onlineShop/xboxShopData.nut")

::visibleDiscountNotifications <- {}

::g_script_reloader.registerPersistentData("discounts", ::getroottable(),
  ["visibleDiscountNotifications"])

::g_discount <- {
  getDiscountIconId = @(name) name + "_discount"
  canBeVisibleOnUnit = @(unit) unit && unit.isVisibleInShop() && !unit.isBought()
}

//return 0 if when discount not visible
function g_discount::getUnitDiscount(unit)
{
  if (!::visibleDiscountNotifications.len() || !canBeVisibleOnUnit(unit))
    return 0
  return ::max(::getTblValue(unit.name, ::visibleDiscountNotifications.airList, 0),
               ::getTblValue(unit.name, ::visibleDiscountNotifications.entitlementUnits, 0))
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
  if (!::get_tbl_value_by_path_array(["airList", unitName], ::visibleDiscountNotifications)
      && !::get_tbl_value_by_path_array(["entitlementUnits", unitName], ::visibleDiscountNotifications))
    return

  updateDiscountData()
  //push event after current event completely finished
  ::get_gui_scene().performDelayed(this, pushDiscountsUpdateEvent)
}

function g_discount::updateXboxShopDiscounts()
{
  ::visibleDiscountNotifications[getDiscountIconId(::g_top_menu_buttons.ONLINE_SHOP.id)] <- xboxShopData.haveDiscount()
  updateDiscountNotifications()
}

function g_discount::updateDiscountData(isSilentUpdate = false)
{
  ::visibleDiscountNotifications.clear()

  local pBlk = ::get_price_blk()

  local chPath = ["exp_to_gold_rate"]
  chPath.append(::shopCountriesList)
  local changeExp_discount = getDiscountByPath(chPath, pBlk)
  ::visibleDiscountNotifications[getDiscountIconId("changeExp")] <- changeExp_discount > 0

  local airList = {}
  local giftUnits = {}

  foreach(air in ::all_units)
    if (::isCountryAvailable(air.shopCountry)
        && !air.isBought()
        && ::is_unit_visible_in_shop(air))
    {
      if (::is_platform_pc && ::isUnitGift(air))
      {
        giftUnits[air.name] <- 0
        continue
      }

      local path = ["aircrafts", air.name]
      local discount = ::getDiscountByPath(path, pBlk)
      if (discount > 0)
        airList[air.name] <- discount
    }
  ::visibleDiscountNotifications.airList <- airList

  ::visibleDiscountNotifications.entitlements <- {}
  ::visibleDiscountNotifications.entitlementUnits <- {}

  local eblk = ::get_entitlements_price_blk() || ::DataBlock()
  foreach (entName, entBlock in eblk)
    checkEntitlement(entName, entBlock, giftUnits)

  if (xboxShopData.canUseIngameShop())
    ::visibleDiscountNotifications[getDiscountIconId(::g_top_menu_buttons.ONLINE_SHOP.id)] <- xboxShopData.haveDiscount()

  local isShopDiscountVisible = false
  foreach(airName, discount in airList)
    if (discount > 0 && canBeVisibleOnUnit(::getAircraftByName(airName)))
    {
      isShopDiscountVisible = true
      break
    }
  if (!isShopDiscountVisible)
    foreach(airName, discount in ::visibleDiscountNotifications.entitlementUnits)
      if (discount > 0 && canBeVisibleOnUnit(::getAircraftByName(airName)))
      {
        isShopDiscountVisible = true
        break
      }
  ::visibleDiscountNotifications[getDiscountIconId("topmenu_research")] <- isShopDiscountVisible

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

  ::visibleDiscountNotifications.entitlements[entName] <- discount

  if (chapter == "campaign" || chapter == "bonuses")
    chapter = ::g_top_menu_buttons.ONLINE_SHOP.id

  ::visibleDiscountNotifications[getDiscountIconId(chapter)] <- chapter == ::g_top_menu_buttons.ONLINE_SHOP.id ?
      (xboxShopData.canUseIngameShop() || ::is_platform_pc)
    : true

  if (entlBlock.aircraftGift)
  {
    local array = entlBlock % "aircraftGift"
    foreach(unitName in array)
      if (unitName in giftUnits)
        ::visibleDiscountNotifications.entitlementUnits[unitName] <- discount
  }
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
      obj.show(::getTblValue(id, ::visibleDiscountNotifications, false))
  }

  local section = ::g_top_menu_right_side_sections.getSectionByName("shop")
  local sectionId = section.getTopMenuButtonDivId()
  local shopObj = ::checkObj(scene)? scene.findObject(sectionId) : ::get_cur_gui_scene()[sectionId]
  if (!::checkObj(shopObj))
    return

  local stObj = shopObj.findObject(section.getTopMenuDiscountId())
  if (!::checkObj(stObj))
    return

  //TODO: Check via section.buttons by haveDiscount.
  local inShopIcons = ["premium", "warpoints", "eagles", ::g_top_menu_buttons.ONLINE_SHOP.id]
  local haveAnyDiscount = false
  foreach(name in inShopIcons)
  {
    local id = getDiscountIconId(name)
    local show = ::getTblValue(id, ::visibleDiscountNotifications, false)
    haveAnyDiscount = haveAnyDiscount || show

    local dObj = shopObj.findObject(id)
    if (::checkObj(dObj))
      dObj.show(show)
  }

  stObj.show(haveAnyDiscount)
}

::subscribe_handler(::g_discount, ::g_listener_priority.CONFIG_VALIDATION)