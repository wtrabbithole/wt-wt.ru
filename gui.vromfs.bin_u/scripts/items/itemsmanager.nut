/*
  ::ItemsManager API:

  getItemsList(typeMask = itemType.ALL)     - get items list by type mask
  fillItemDescr(item, holderObj, handler)   - update item description in object.
  findItemById(id, typeMask = itemType.ALL) - search item by id

  getInventoryList(typeMask = itemType.ALL) - get items list by type mask
*/

class BoosterEffectType
{
  static RP = {
    name = "xpRate"
    currencyMark = ::loc("currency/researchPoints/sign/colored")
    abbreviation = "xp"
    checkBooster = function(booster)
    {
      return ::getTblValue("xpRate", booster, 0) != 0
    }
    getValue = function(booster)
    {
      return ::getTblValue("xpRate", booster, 0)
    }
    getText = function(value, colored = false, showEmpty = true)
    {
      if (value == 0 && !showEmpty)
        return ""
      return ::getRpPriceText(value, colored)
    }
  }
  static WP = {
    name = "wpRate"
    currencyMark = ::loc("warpoints/short/colored")
    abbreviation = "wp"
    checkBooster = function(booster)
    {
      return ::getTblValue("wpRate", booster, 0) != 0
    }
    getValue = function(booster)
    {
      return ::getTblValue("wpRate", booster, 0)
    }
    getText = function(value, colored = false, showEmpty = true)
    {
      if (value == 0 && !showEmpty)
        return ""
      return ::getWpPriceText(value, colored)
    }
  }
}

::SEEN_ITEM_MAX_DAYS <- 28
::FAKE_ITEM_CYBER_CAFE_BOOSTER_UID <- -1

//events from code:
function on_items_loaded()
{
  ::ItemsManager.markInventoryUpdate()
}

foreach (fn in [
                 "items.nut"
                 "itemTrophy.nut"
                 "itemBooster.nut"
                 "itemTicket.nut"
                 "itemWager.nut"
                 "itemDiscount.nut"
                 "discountItemSortMethod.nut"
                 "itemOrder.nut"

                 "trophyMultiAward.nut"
                 "itemsRoulette.nut"
                 "itemLimits.nut"
               ])
  ::g_script_reloader.loadOnce("scripts/items/" + fn)

::ItemsManager <- {
  itemsList = []
  inventory = []
  shopItemById = {}

  itemTypeClasses = {} //itemtype = itemclass

  itemTypeFeatures = {
    [itemType.WAGER] = "Wagers",
    [itemType.ORDER] = "Orders"
  }

  _reqUpdateList = true
  _needInventoryUpdate = true
  _needInventoryUpdateDelayed = false

  // Things needed to handle seen/unseen items.
  _seenItemsInfoByCategory = {
    [true] = {
      name = "seen_inventory_items" // Used as data block name.
      seenItemsData = null // Use ItemsManager::getSeenItemsData() to access.
      numUnseenItems = -1 // Use ItemsManager::getNumUnseenItems() to access.
      numUnseenItemsInvalidated = true // Num unseen shop items invalidation flag.
      saveSeenItemsInvalidated = false // Raised when seen shop items data save required.
      updateSeenItemsData = function (items, curDays)
        {
          seenItemsData.clear()
          foreach (item in items)
            seenItemsData[item.id] <- curDays
        }
    },
    [false] = {
      name = "seen_shop_items"
      seenItemsData = null
      numUnseenItems = -1
      numUnseenItemsInvalidated = true
      saveSeenItemsInvalidated = false
      updateSeenItemsData = function (items, curDays)
        {
          foreach (item in items)
          {
            if (!(item.id in seenItemsData))
              continue
            if (item.isCanBuy())
              seenItemsData[item.id] <- curDays
            else
              delete seenItemsData[item.id]
          }

          // Removing old items.
          local trophiesBought = ::loadLocalByAccount("shop/trophyBought")
          local trophiesBoughtChanged = false
          foreach (itemId, lastDaySeen in seenItemsData)
            if (lastDaySeen < curDays - ::SEEN_ITEM_MAX_DAYS)
            {
              delete seenItemsData[itemId]
              if (itemId in trophiesBought)
              {
                trophiesBought.removeParam(itemId)
                trophiesBoughtChanged = true
              }
            }

          if (trophiesBoughtChanged)
            ::saveLocalByAccount("shop/trophyBought", trophiesBought)
        }
    }
  }

  ignoreItemLimits = false
  fakeItemsList = null
  genericItemsForCyberCafeLevel = -1

  refreshBoostersTask = -1
  boostersTaskUpdateFlightTime = -1
}

function ItemsManager::fillFakeItemsList()
{
  local curLevel = ::get_cyber_cafe_level()
  if (curLevel == genericItemsForCyberCafeLevel)
    return

  genericItemsForCyberCafeLevel = curLevel

  fakeItemsList = ::DataBlock()

  for (local i = 0; i <= ::cyber_cafe_max_level; i++)
  {
    local level = i || curLevel //we do not need level0 booster, but need booster of current level.
    local table = {
      type = itemType.FAKE_BOOSTER
      iconStyle = "cybercafebonus"
      locId = "item/FakeBoosterForNetCafeLevel"
      rateBoosterParams = {
        xpRate = ::floor(100.0 * ::get_cyber_cafe_bonus_by_effect_type(BoosterEffectType.RP, level) + 0.5)
        wpRate = ::floor(100.0 * ::get_cyber_cafe_bonus_by_effect_type(BoosterEffectType.WP, level) + 0.5)
      }
    }
    fakeItemsList["FakeBoosterForNetCafeLevel" + (i || "")] <- ::build_blk_from_container(table)
  }

  for (local i = 2; i <= ::g_squad_manager.maxSquadSize; i++)
  {
    local table = {
      type = itemType.FAKE_BOOSTER
      rateBoosterParams = {
        xpRate = ::floor(100.0 * ::get_squad_bonus_for_same_cyber_cafe(BoosterEffectType.RP, i) + 0.5)
        wpRate = ::floor(100.0 * ::get_squad_bonus_for_same_cyber_cafe(BoosterEffectType.WP, i) + 0.5)
      }
    }
    fakeItemsList["FakeBoosterForSquadFromSameCafe" + i] <- ::build_blk_from_container(table)
  }
}

/////////////////////////////////////////////////////////////////////////////////////////////
//---------------------------------SHOP ITEMS----------------------------------------------//
/////////////////////////////////////////////////////////////////////////////////////////////
function ItemsManager::_checkUpdateList()
{
  if (!_reqUpdateList)
    return
  _reqUpdateList = false

  itemsList = []
  shopItemById = {}
  local duplicatesId = []

  local pBlk = ::get_price_blk()
  local trophyBlk = pBlk && pBlk.trophy
  if (trophyBlk)
    for (local i = 0; i < trophyBlk.blockCount(); i++)
    {
      local blk = trophyBlk.getBlock(i)
      local id = blk.getBlockName()
      if (findItemById(id))
      {
        duplicatesId.append(id)
        continue
      }
      local item = createItem(itemType.TROPHY, blk)
      itemsList.append(item)
      shopItemById[item.id] <- item
    }

  local itemsBlk = ::get_items_blk()
  ignoreItemLimits = !!itemsBlk.ignoreItemLimits
  for(local i = 0; i < itemsBlk.blockCount(); i++)
  {
    local blk = itemsBlk.getBlock(i)
    local id = blk.getBlockName()
    if (findItemById(id))
    {
      duplicatesId.append(id)
      continue
    }
    local iType = getInventoryItemType(blk.type)
    if (iType == itemType.UNKNOWN)
    {
      ::dagor.debug("Error: unknown item type in items blk = " + blk.type)
      continue
    }
    local item = createItem(iType, blk)
    itemsList.append(item)
    shopItemById[item.id] <- item
  }

  ::ItemsManager.fillFakeItemsList()
  if (fakeItemsList)
    for (local i = 0; i < fakeItemsList.blockCount(); i++)
    {
      local blk = fakeItemsList.getBlock(i)
      local id = blk.getBlockName()

      if (findItemById(id))
      {
        duplicatesId.append(id)
        continue
      }

      local item = createItem(blk.type, blk)
      itemsList.append(item)
      shopItemById[id] <- item
    }

  if (duplicatesId.len())
    ::dagor.assertf(false, "Items shop: found duplicate items id = \n" + ::implode(duplicatesId, ", "))

  ::ItemsManager.updateSeenItemsData(false)
}

function ItemsManager::onEventEntitlementsUpdatedFromOnlineShop(params)
{
  local curLevel = ::get_cyber_cafe_level()
  if (genericItemsForCyberCafeLevel != curLevel)
  {
    _reqUpdateList = true
    _checkUpdateList()
    markInventoryUpdate()
  }
}

function ItemsManager::initItemsClasses()
{
  foreach(name, itemClass in ::items_classes)
  {
    local iType = itemClass.iType
    if (::number_of_set_bits(iType) != 1)
      ::dagor.assertf(false, "Incorrect item class iType " + iType + " must be a power of 2")
    if (iType in itemTypeClasses)
      ::dagor.assertf(false, "duplicate iType in item classes " + iType)
    else
      itemTypeClasses[iType] <- itemClass
  }
}
::ItemsManager.initItemsClasses() //init classes right after scripts load.

function ItemsManager::createItem(itemType, blk, inventoryBlk = null, slotData = null)
{
  local iClass = (itemType in itemTypeClasses)? itemTypeClasses[itemType] : ::BaseItem
  return iClass(blk, inventoryBlk, slotData)
}

function ItemsManager::getItemClass(itemType)
{
  return (itemType in itemTypeClasses)? itemTypeClasses[itemType] : ::BaseItem
}

function ItemsManager::getItemsList(typeMask = itemType.ALL, filterFunc = null)
{
  _checkUpdateList()
  return _getItemsFromList(itemsList, typeMask, filterFunc)
}

function ItemsManager::getShopList(typeMask = itemType.ALL, filterFunc = null)
{
  _checkUpdateList()
  return _getItemsFromList(itemsList, typeMask, filterFunc, "shopFilterMask")
}

function ItemsManager::findItemById(id, typeMask = itemType.ALL)
{
  _checkUpdateList()
  return ::getTblValue(id, shopItemById, null)
}


/////////////////////////////////////////////////////////////////////////////////////////////
//---------------------------------INVENTORY ITEMS-----------------------------------------//
/////////////////////////////////////////////////////////////////////////////////////////////
function ItemsManager::getInventoryItemType(blkType)
{
  if (typeof(blkType) == "string")
    blkType = ::item_get_type_id_by_type_name(blkType)

  switch (blkType)
  {
    case ::EIT_BOOSTER:           return itemType.BOOSTER
    case ::EIT_TOURNAMENT_TICKET: return itemType.TICKET
    case ::EIT_WAGER:             return itemType.WAGER
    case ::EIT_PERSONAL_DISCOUNTS:return itemType.DISCOUNT
    case ::EIT_ORDER:             return itemType.ORDER
  }
  return itemType.UNKNOWN
}

function ItemsManager::_checkInventoryUpdate()
{
  if (!_needInventoryUpdate)
    return
  _needInventoryUpdate = false

  inventory = []

  local itemsBlk = ::get_items_blk()

  local total = get_items_count()
  local itemsCache = get_items_cache()
  foreach(slot in itemsCache)
  {
    if (!slot.uids.len())
      continue

    local invItemBlk = ::DataBlock()
    ::get_item_data_by_uid(invItemBlk, slot.uids[0])
    if (::getTblValue("expiredTime", invItemBlk, 0) < 0)
      continue

    local iType = getInventoryItemType(invItemBlk.type)
    if (iType == itemType.UNKNOWN)
    {
      //debugTableData(invItemBlk)
      //::dagor.assertf(false, "Inventory: unknown item type = " + invItemBlk.type)
      continue
    }

    local blk = itemsBlk[slot.id]
    if (!blk)
    {
      if (::is_dev_version)
        dagor.debug("Error: found removed item: " + slot.id)
      continue //skip removed items
    }

    inventory.append(createItem(iType, blk, invItemBlk, slot))
  }

  ::ItemsManager.fillFakeItemsList()
  if (fakeItemsList && ::get_cyber_cafe_level())
  {
    local id = "FakeBoosterForNetCafeLevel"
    local blk = fakeItemsList.getBlockByName(id)
    if (blk)
    {
      local item = createItem(blk.type, blk, ::DataBlock(), {uids = [::FAKE_ITEM_CYBER_CAFE_BOOSTER_UID]})
      inventory.append(item)
    }
  }

}

function ItemsManager::getInventoryList(typeMask = itemType.ALL, filterFunc = null)
{
  _checkInventoryUpdate()
  return _getItemsFromList(inventory, typeMask, filterFunc)
}

function ItemsManager::markInventoryUpdate()
{
  _needInventoryUpdateDelayed = false
  if (_needInventoryUpdate)
    return

  _needInventoryUpdate = true
  ::broadcastEvent("InventoryUpdate")
}

function ItemsManager::markInventoryUpdateDelayed()
{
  if (_needInventoryUpdateDelayed || _needInventoryUpdate)
    return

  _needInventoryUpdateDelayed = true
  local guiScene = ::get_main_gui_scene()
  guiScene.performDelayed(::ItemsManager, markInventoryUpdate)
}


/////////////////////////////////////////////////////////////////////////////////////////////
//---------------------------------ITEM UTILS----------------------------------------------//
/////////////////////////////////////////////////////////////////////////////////////////////

function ItemsManager::checkItemsMaskFeatures(itemsMask) //return itemss mask only of available features
{
  foreach(iType, feature in itemTypeFeatures)
    if ((itemsMask & iType) && !::has_feature(feature))
      itemsMask -= iType
  return itemsMask
}

function ItemsManager::_getItemsFromList(list, typeMask, filterFunc = null, itemMaskProperty = "iType")
{
  if (typeMask == itemType.ALL && !filterFunc)
    return list

  local res = []
  foreach(item in list)
    if (::getTblValue(itemMaskProperty, item, item.iType) & typeMask
        && (!filterFunc || filterFunc(item)))
      res.append(item)
  return res
}

function ItemsManager::fillItemDescr(item, holderObj, handler = null, shopDesc = false, preferMarkup = false, params = null)
{
  handler = handler || ::get_cur_base_gui_handler()

  local obj = holderObj.findObject("item_name")
  if (::checkObj(obj))
    obj.setValue(item? item.getDescriptionTitle() : "")

  local helpObj = holderObj.findObject("item_type_help")
  if (::checkObj(helpObj))
  {
    local helpText = item? item.getItemTypeDescription() : ""
    helpObj.tooltip = helpText
    helpObj.show(shopDesc && helpText != "")
  }

  obj = holderObj.findObject("item_desc")
  if (::checkObj(obj))
  {
    local desc = ""
    if (item)
    {
      desc = item.getShortItemTypeDescription()
      local descText = preferMarkup ? item.getLongDescription() : item.getDescription()
      if (descText.len() > 0)
        desc += (desc.len() ? "\n\n" : "") + descText
      local itemLimitsDesc = item.getLimitsDescription()
      if (itemLimitsDesc.len() > 0)
        desc += (desc.len() ? "\n" : "") + itemLimitsDesc
    }
    local descModifyFunc = ::getTblValue("descModifyFunc", params)
    if (descModifyFunc)
      desc = descModifyFunc(desc)
    obj.setValue(desc)
  }

  obj = holderObj.findObject("item_desc_div")
  if (::checkObj(obj))
  {
    local longdescMarkup = (preferMarkup && item) ? item.getLongDescriptionMarkup({ shopDesc = shopDesc }) : ""
    obj.show(longdescMarkup != "")
    if (longdescMarkup != "")
      obj.getScene().replaceContentFromText(obj, longdescMarkup, longdescMarkup.len(), handler)
  }
  ::ItemsManager.fillItemTableInfo(item, holderObj)

  obj = holderObj.findObject("item_icon")
  obj.show(item != null)
  if (item)
  {
    local iconSetParams = {
      bigPicture = item.allowBigPicture
      addItemName = !shopDesc
    }
    item.setIcon(obj, iconSetParams)
  }
  obj.scrollToView()
}

function ItemsManager::fillItemTableInfo(item, holderObj)
{
  if (!::checkObj(holderObj))
    return

  ::ItemsManager.fillItemTable(item, holderObj)

  local obj = holderObj.findObject("item_desc_above_table")
  if (::checkObj(obj))
    obj.setValue(item? item.getDescriptionAboveTable() : "")

  local obj = holderObj.findObject("item_desc_under_table")
  if (::checkObj(obj))
    obj.setValue(item ? item.getDescriptionUnderTable() : "")
}

function ItemsManager::fillItemTable(item, holderObj)
{
  local containerObj = holderObj.findObject("item_table_container")
  if (!::checkObj(containerObj))
    return

  local tableData = null
  if (item != null)
    tableData = item.getTableData()
  local show = tableData != null
  containerObj.show(show)

  if (show)
    holderObj.getScene().replaceContentFromText(containerObj, tableData, tableData.len(), this)
}

function ItemsManager::getActiveBoostersArray(effectType = null)
{
  local array = []
  local total = ::get_current_booster_count(::INVALID_USER_ID)
  local bonusType = effectType ? effectType.name : null
  for (local i = 0; i < total; i++)
  {
    local uid = ::get_current_booster_uid(::INVALID_USER_ID, i)
    local item = ::ItemsManager.findItemByUid(uid, itemType.BOOSTER)
    if (!item || bonusType && item[bonusType] == 0 || !item.isActive(true))
      continue

    array.append(item)
  }

  if (array.len())
    registerBoosterUpdateTimer(array)

  return array
}

//just update gamercards atm.
function ItemsManager::registerBoosterUpdateTimer(boostersList)
{
  if (!::is_in_flight())
    return

  local curFlightTime = ::get_usefull_total_time()
  local nextExpireTime = -1
  foreach(booster in boostersList)
  {
    local expireTime = booster.getExpireFlightTime()
    if (expireTime <= curFlightTime)
      continue
    if (nextExpireTime < 0 || expireTime < nextExpireTime)
      nextExpireTime = expireTime
  }

  if (nextExpireTime < 0)
    return

  local nextUpdateTime = nextExpireTime.tointeger() + 1
  if (refreshBoostersTask >= 0 && nextUpdateTime >= boostersTaskUpdateFlightTime)
    return

  removeRefreshBoostersTask()

  boostersTaskUpdateFlightTime = nextUpdateTime
  refreshBoostersTask = ::periodic_task_register_ex(this,
                                                    _onBoosterExpiredInFlight,
                                                    boostersTaskUpdateFlightTime - curFlightTime,
                                                    ::EPTF_IN_FLIGHT,
                                                    ::EPTT_BEST_EFFORT,
                                                    false //flight time
                                                   )
}

function ItemsManager::_onBoosterExpiredInFlight(dt = 0)
{
  removeRefreshBoostersTask()
  if (::is_in_flight())
    ::update_gamercards()
}

function ItemsManager::removeRefreshBoostersTask()
{
  if (refreshBoostersTask >= 0)
    ::periodic_task_unregister(refreshBoostersTask)
  refreshBoostersTask = -1
}

function ItemsManager::onEventLoadingStateChange(p)
{
  if (!::is_in_flight())
    removeRefreshBoostersTask()
}

/**
 * Returns structure table of boosters.
 * This structure looks like this:
 * {
 *   <sort_order> = {
 *     publick = [array of public boosters]
 *     personal = [array of personal boosters]
 *   }
 *  maxSortOrder = <maximum sort_order>
 * }
 * Public and personal arrays of boosters sorted by effect type
 */
function ItemsManager::sortBoosters(boosters, effectType)
{
  local res = {
    maxSortOrder = 0
  }
  foreach(booster in boosters)
  {
    res.maxSortOrder = ::max(::getTblValue("maxSortOrder", res, 0), booster.sortOrder)
    if (!::getTblValue(booster.sortOrder, res))
      res[booster.sortOrder] <- {
        personal = [],
        public = [],
      }

    if (booster.personal)
      res[booster.sortOrder].personal.append(booster)
    else
      res[booster.sortOrder].public.append(booster)
  }

  for (local i = 0; i <= res.maxSortOrder; i++)
    if (i in res && res[i].len())
      foreach (array in res[i])
        ::ItemsManager.sortByParam(array, effectType.name)
  return res
}

/**
 * Summs effects of passed boosters and returns table in format:
 * {
 *   <BoosterEffectType.name> = <value in percent>
 * }
 */
function ItemsManager::getBoostersEffects(boosters)
{
  local result = {}
  foreach (effectType in ::BoosterEffectType)
  {
    result[effectType.name] <- 0
    local sortedBoosters = ::ItemsManager.sortBoosters(boosters, effectType)
    for (local i = 0; i <= sortedBoosters.maxSortOrder; i++)
    {
      if (!(i in sortedBoosters))
        continue
      result[effectType.name] += ::calc_public_boost(::ItemsManager.getBoostersEffectsArray(sortedBoosters[i].public, effectType))
                              + ::calc_personal_boost(::ItemsManager.getBoostersEffectsArray(sortedBoosters[i].personal, effectType))
    }
  }
  return result
}

function ItemsManager::getBoostersEffectsArray(itemsArray, effectType)
{
  local res = []
  foreach(item in itemsArray)
    res.append(item[effectType.name])
  return res
}

function ItemsManager::getActiveBoostersDescription(boostersArray, effectType, selectedItem = null)
{
  if (!boostersArray || boostersArray.len() == 0)
    return ""

  local getColoredNumByType = (@(effectType) function(num) {
    return ::colorize("activeTextColor", "+" + num + "%") + effectType.currencyMark
  })(effectType)

  local separateBoosters = []

  local itemsArray = []
  foreach(booster in boostersArray)
  {
    if (booster.showBoosterInSeparateList)
      separateBoosters.append(booster.getName() + ::loc("ui/colon") + booster.getEffectDesc(true, effectType))
    else
      itemsArray.append(booster)
  }
  if (separateBoosters.len())
    separateBoosters.append("\n")

  local sortedItemsTable = ::ItemsManager.sortBoosters(itemsArray, effectType)
  local detailedDescription = []
  for (local i = 0; i <= sortedItemsTable.maxSortOrder; i++)
  {
    local arraysList = ::getTblValue(i, sortedItemsTable)
    if (!arraysList || arraysList.len() == 0)
      continue

    local personalTotal = arraysList.personal.len() == 0
                          ? 0
                          : ::calc_personal_boost(::ItemsManager.getBoostersEffectsArray(arraysList.personal, effectType))

    local publicTotal = arraysList.public.len() == 0
                        ? 0
                        : ::calc_public_boost(::ItemsManager.getBoostersEffectsArray(arraysList.public, effectType))

    local isBothBoosterTypesAvailable = personalTotal != 0 && publicTotal != 0

    local header = ""
    local detailedArray = []
    local insertedSubHeader = false

    foreach(j, arrayName in ["personal", "public"])
    {
      local array = arraysList[arrayName]
      if (array.len() == 0)
        continue

      local personal = array[0].personal
      local boostNum = personal? personalTotal : publicTotal

      header = ::loc("mainmenu/boosterType/common")
      if (array[0].eventConditions)
        header = ::UnlockConditions.getConditionsText(array[0].eventConditions, null, null, { inlineText = true })

      local subHeader = "* " + ::loc("mainmenu/booster/" + arrayName)
      if (isBothBoosterTypesAvailable)
      {
        subHeader += ::loc("ui/colon")
        subHeader += getColoredNumByType(boostNum)
      }

      detailedArray.append(subHeader)

      local effectsArray = []
      foreach(idx, item in array)
      {
        local effOld = personal? ::calc_personal_boost(effectsArray) : ::calc_public_boost(effectsArray)
        effectsArray.append(item[effectType.name])
        local effNew = personal? ::calc_personal_boost(effectsArray) : ::calc_public_boost(effectsArray)

        local string = array.len() == 1? "" : (idx+1) + ") "
        string += item.getEffectDesc(false) + ::loc("ui/comma")
        string += ::loc("items/booster/giveRealBonus", {realBonus = getColoredNumByType(::format("%.02f", effNew - effOld).tofloat())})
        string += (idx == array.len()-1? ::loc("ui/dot") : ::loc("ui/semicolon"))

        if (selectedItem != null && selectedItem.id == item.id)
          string = ::colorize("userlogColoredText", string)

        detailedArray.append(string)
      }

      if (!insertedSubHeader)
      {
        local totalBonus = publicTotal + personalTotal
        header += ::loc("ui/colon") + getColoredNumByType(totalBonus)
        detailedArray.insert(0, header)
        insertedSubHeader = true
      }
    }
    detailedDescription.append(::implode(detailedArray, "\n"))
  }

  local description = ::loc("mainmenu/boostersTooltip", effectType) + ::loc("ui/colon") + "\n"
  return description + ::implode(separateBoosters, "\n") + ::implode(detailedDescription, "\n\n")
}

function ItemsManager::hasActiveBoosters(effectType, personal)
{
  local items = ::ItemsManager.getInventoryList(itemType.BOOSTER, (@(effectType, personal) function (item) {
    return item.isActive(true) && effectType.checkBooster(item) && item.personal == personal
  })(effectType, personal))
  return items.len() != 0
}

function ItemsManager::sortEffectsArray(a, b)
{
  if (a != b)
    return a > b? -1 : 1
  return 0
}

function ItemsManager::sortByParam(array, param)
{
  local sortByBonus = (@(param) function(a, b) {
    if (a[param] != b[param])
      return a[param] > b[param]? -1 : 1
    return 0
  })(param)

  array.sort(sortByBonus)
  return array
}

function ItemsManager::findItemByUid(uid, filterType = itemType.ALL)
{
  local itemsArray = ::ItemsManager.getInventoryList(filterType,
                (@(uid) function (item) { return ::isInArray(uid, item.uids)})(uid) )

  return itemsArray.len() > 0? itemsArray[0] : null
}

/////////////////////////////////////////////////////////////////////////////////////////////
//--------------------------------SEEN ITEMS-----------------------------------------------//
/////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns table with data format:
 * {
 *   itemId1 = lastDaySeen1
 *   itemId2 = lastDaySeen2
 * }
 * @param forInventoryItems Used to decided which items to scan:
 *                          inventory items or shop item.
 */
function ItemsManager::getSeenItemsData(forInventoryItems)
{
  local seenItemsInfo = _seenItemsInfoByCategory[forInventoryItems]
  if (seenItemsInfo.seenItemsData != null)
    return seenItemsInfo.seenItemsData
  if (!::g_login.isLoggedIn()) // Account isn't loaded yet.
    return null
  local seenItemsBlk = ::loadLocalByAccount(seenItemsInfo.name)
  seenItemsInfo.seenItemsData = buildTableFromBlk(seenItemsBlk)

  // Validates data as profile may become corrupted.
  foreach (itemId, lastDaySeen in seenItemsInfo.seenItemsData)
  {
    if (typeof(lastDaySeen) != "array")
      continue
    if (lastDaySeen.len() > 0)
      seenItemsInfo.seenItemsData[itemId] = lastDaySeen[0]
    else
      delete seenItemsInfo.seenItemsData[itemId]
  }
  return seenItemsInfo.seenItemsData
}

function ItemsManager::getNumUnseenItems(forInventoryItems)
{
  local seenItemsData = ::ItemsManager.getSeenItemsData(forInventoryItems)
  if (seenItemsData == null)
    return 0

  if (forInventoryItems)
    _checkInventoryUpdate()
  else
    _checkUpdateList()

  local seenItemsInfo = _seenItemsInfoByCategory[forInventoryItems]
  if (seenItemsInfo.numUnseenItemsInvalidated)
  {
    local curDays = ::get_days_by_time(::get_utc_time())
    seenItemsInfo.numUnseenItemsInvalidated = false
    seenItemsInfo.numUnseenItems = 0
    local items = forInventoryItems
      ? inventory
      : itemsList
    local hasDevItemShopFeature = ::has_feature("devItemShop")
    foreach (item in items)
    {
      if (item.id in seenItemsData ||
          !forInventoryItems && !item.isCanBuy() ||
          item.isDevItem && !hasDevItemShopFeature)
        continue

      ++seenItemsInfo.numUnseenItems
    }
  }
  return seenItemsInfo.numUnseenItems
}

function ItemsManager::hasSeenItems(forInventoryItems)
{
  local seenItemsData = ::ItemsManager.getSeenItemsData(forInventoryItems)
  return seenItemsData != null && seenItemsData.len() > 0
}

/**
 * Returns true if item's seen\unseen state was actually changed in this call.
 */
function ItemsManager::markItemSeen(item)
{
  if (item == null)
    return false
  local seenItemsData = ::ItemsManager.getSeenItemsData(item.isInventoryItem)
  if (seenItemsData == null)
    return false
  local seenItemsInfo = _seenItemsInfoByCategory[item.isInventoryItem]
  local curDays = ::get_days_by_time(::get_utc_time())
  local result = false

  // This will force _numUnseenItems to recalc on next access
  // as well as actually save on next saveSeenItemsData() call.
  if (!(item.id in seenItemsData))
  {
    seenItemsInfo.saveSeenItemsInvalidated = true
    seenItemsInfo.numUnseenItemsInvalidated = true
    result = true
  }
  seenItemsData[item.id] <- curDays
  return result
}

function ItemsManager::saveSeenItemsData(forInventoryItems)
{
  local seenItemsData = ::ItemsManager.getSeenItemsData(forInventoryItems)
  if (seenItemsData == null)
    return
  local seenItemsInfo = _seenItemsInfoByCategory[forInventoryItems]
  if (!seenItemsInfo.saveSeenItemsInvalidated)
    return
  seenItemsInfo.saveSeenItemsInvalidated = false
  ::saveLocalByAccount(seenItemsInfo.name, seenItemsData)
}

function ItemsManager::updateGamercardIcons(forInventoryItems = null)
{
  _checkUpdateList()
  _checkInventoryUpdate()

  ::broadcastEvent("UpdatedSeenItems", {forInventoryItems = forInventoryItems})
}

function ItemsManager::updateSeenItemsData(forInventoryItems)
{
  local seenItemsData = ::ItemsManager.getSeenItemsData(forInventoryItems)
  if (seenItemsData == null)
    return
  local seenItemsInfo = _seenItemsInfoByCategory[forInventoryItems]
  local curDays = ::get_days_by_time(::get_utc_time())
  local items = forInventoryItems
    ? inventory
    : itemsList
  seenItemsInfo.updateSeenItemsData(items, curDays)
  seenItemsInfo.saveSeenItemsInvalidated = true
  seenItemsInfo.numUnseenItemsInvalidated = true
  ::ItemsManager.updateGamercardIcons(forInventoryItems)
  ::ItemsManager.saveSeenItemsData(forInventoryItems)
}

function ItemsManager::isItemUnseen(item)
{
  if (item == null)
    return false
  local seenItemsData = ::ItemsManager.getSeenItemsData(item.isInventoryItem)
  if (seenItemsData == null)
    return false
  if (item.id in seenItemsData)
    return false
  return item.isInventoryItem || item.isCanBuy()
}

function ItemsManager::isEnabled()
{
  local checkNewbie = !::my_stats.isMeNewbie()
    || ItemsManager.hasSeenItems(true)
    || inventory.len() > 0
  return ::has_feature("Items") && checkNewbie && ::isInMenu()
}

function ItemsManager::itemsSortComparator(item1, item2)
{
  local active1 = item1.isActive()
  local active2 = item2.isActive()
  if (active1 != active2)
    return active1 ? -1 : 1

  local unseen1 = ::ItemsManager.isItemUnseen(item1)
  local unseen2 = ::ItemsManager.isItemUnseen(item2)
  if (unseen1 != unseen2)
    return unseen1 ? -1 : 1

  local timer1 = item1.hasTimer()
  local timer2 = item2.hasTimer()
  if (timer1 != timer2)
    return timer1 ? -1 : 1

  if (timer1 && item1.expiredTimeSec != item2.expiredTimeSec)
    return (item1.expiredTimeSec < item2.expiredTimeSec) ? -1 : 1

  return 0
}

::subscribe_handler(::ItemsManager, ::g_listener_priority.DEFAULT_HANDLER)
