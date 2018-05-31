local enums = ::require("std/enums.nut")
local workshop = ::require("scripts/items/workshop/workshop.nut")
local seenList = ::require("scripts/seen/seenList.nut")

local shopSheets = {
  types = []
}

local isOnlyExtInventory = @(shopTab) shopTab == itemsTab.INVENTORY && ::has_feature("ExtInventory")

shopSheets.template <- {
  id = "" //used from type name
  sortId = 0
  locId = null //default: "itemTypes/" + id.tolower()
  emptyTabLocId = null //default: "items/shop/emptyTab/" + id.tolower()

  typeMask = itemType.INVENTORY_ALL
  isDevItemsTab = false
  isMarketplace = false

  getSeenId = @() "##item_sheet_" + id

  isAllowedForTab = @(shopTab) shopTab != itemsTab.WORKSHOP
  isEnabled = @(shopTab) isAllowedForTab(shopTab)
    && ::ItemsManager.checkItemsMaskFeatures(typeMask) != 0
    && (shopTab != itemsTab.SHOP || getItemsList(shopTab).len() > 0)

  getItemFilterFunc = @(shopTab)
    shopTab == itemsTab.SHOP ? (@(item) item.isCanBuy() && isDevItemsTab == item.isDevItem)
    : (@(item) true)

  getItemsList = function(shopTab)
  {
    local visibleTypeMask = ::ItemsManager.checkItemsMaskFeatures(typeMask)
    local filterFunc = getItemFilterFunc(shopTab).bindenv(this)
    if (shopTab == itemsTab.INVENTORY)
      return ::ItemsManager.getInventoryList(visibleTypeMask, filterFunc)
    if (shopTab == itemsTab.SHOP)
      return ::ItemsManager.getShopList(visibleTypeMask, filterFunc)
    return []
  }
}

local function getTabSeenId(tabIdx) //!!FIX ME: move tabs to separate enum
{
  switch (tabIdx)
  {
    case itemsTab.SHOP:          return SEEN.ITEMS_SHOP
    case itemsTab.INVENTORY:     return SEEN.INVENTORY
    case itemsTab.WORKSHOP:      return SEEN.WORKSHOP
  }
  return null
}
local isTabVisible = @(tabIdx) tabIdx != itemsTab.WORKSHOP || workshop.isAvailable() //!!FIX ME: move tabs to separate enum

shopSheets.addSheets <- function(sheetsTable)
{
  enums.addTypes(this, sheetsTable,
    function()
    {
      if (!locId)
        locId = "itemTypes/" + id.tolower()
      if (!emptyTabLocId)
        emptyTabLocId = "items/shop/emptyTab/" + id.tolower()
    },
    "id")
  shopSheets.types.sort(@(a, b) a.sortId <=> b.sortId)

  //register seen sublist getters
  for (local tab = 0; tab < itemsTab.TOTAL; tab++)
    if (isTabVisible(tab))
    {
      local curTab = tab
      local tabSeenList = seenList.get(getTabSeenId(tab))
      foreach (sh in types)
        if (sh.isAllowedForTab(tab))
        {
          local curSheet = sh
          tabSeenList.setSubListGetter(sh.getSeenId(), @() curSheet.getItemsList(curTab).map(@(it) it.getSeenId()))
        }
    }
}

shopSheets.findSheet <- function(config, defSheet = null)
{
  local res = null
  foreach(sh in types)
  {
    if (config == sh)
    {
      res = sh //this is already sheet
      break
    }

    local isFullMatch = true
    local isPartMatch = false
    foreach(key, value in config)
      if (key in sh)
        if (value == sh[key])
          isPartMatch = true
        else
          isFullMatch = false

    if (isFullMatch || isPartMatch && !res)
      res = sh
    if (isFullMatch)
      break
  }
  return res ?? defSheet
}

local sortId = 0
shopSheets.addSheets({
  ALL = {
    locId = "userlog/page/all"
    typeMask = itemType.INVENTORY_ALL
    sortId = sortId++
  }
  TROPHY = {
    typeMask = itemType.TROPHY
    isAllowedForTab = @(shopTab) shopTab == itemsTab.SHOP
    sortId = sortId++
  }
  BOOSTER = {
    typeMask = itemType.BOOSTER
    sortId = sortId++
  }
  WAGERS = {
    typeMask = itemType.WAGER
    sortId = sortId++
  }
  DISCOUNT = {
    typeMask = itemType.DISCOUNT
    sortId = sortId++
    isAllowedForTab = @(shopTab) shopTab == itemsTab.INVENTORY
      || (shopTab == itemsTab.SHOP && ::has_feature("CanBuyDiscountItems"))
  }
  TICKETS = {
    typeMask = itemType.TICKET
    sortId = sortId++
  }
  ORDERS = {
    typeMask = itemType.ORDER
    sortId = sortId++
  }
  UNIVERSAL_SPARE = {
    locId = "itemTypes/universalSpare"
    emptyTabLocId = "items/shop/emptyTab/universalSpare"
    typeMask = itemType.UNIVERSAL_SPARE
    sortId = sortId++
    isAllowedForTab = @(shopTab) shopTab != itemsTab.WORKSHOP && !::has_feature("ItemModUpgrade")
  }
  MODIFICATIONS = {
    locId = "mainmenu/btnWeapons"
    typeMask = itemType.UNIVERSAL_SPARE | itemType.MOD_UPGRADE | itemType.MOD_OVERDRIVE
    sortId = sortId++
    isAllowedForTab = @(shopTab) shopTab != itemsTab.WORKSHOP && ::has_feature("ItemModUpgrade")
  }
  VEHICLES = {
    typeMask = itemType.VEHICLE
    isMarketplace = true
    sortId = sortId++
    isAllowedForTab = isOnlyExtInventory
  }
  SKINS = {
    typeMask = itemType.SKIN
    isMarketplace = true
    sortId = sortId++
    isAllowedForTab = isOnlyExtInventory
  }
  DECALS = {
    locId = "unlocks/chapter/attachable"
    typeMask = itemType.DECAL | itemType.ATTACHABLE
    isMarketplace = true
    sortId = sortId++
    isAllowedForTab = isOnlyExtInventory
  }
  KEYS = {
    typeMask = itemType.KEY
    isMarketplace = true
    sortId = sortId++
    isAllowedForTab = isOnlyExtInventory
  }
  CHESTS = {
    typeMask = itemType.CHEST
    isMarketplace = true
    sortId = sortId++
    isAllowedForTab = isOnlyExtInventory
  }
  OTHER = {
    locId = "attachables/category/other"
    typeMask = itemType.WARBONDS
    isMarketplace = true
    sortId = sortId++
    isAllowedForTab = isOnlyExtInventory
  }
  DEV_ITEMS = {
    locId = "itemTypes/devItems"
    emptyTabLocId = "items/shop/emptyTabdevItems/"
    typeMask = itemType.ALL
    isDevItemsTab = true
    sortId = sortId++
    isAllowedForTab = @(shopTab) shopTab == itemsTab.SHOP && ::has_feature("devItemShop")
  }
})

shopSheets.updateWorkshopSheets <- function()
{
  local sets = workshop.getSetsList()
  local newSheets = {}
  foreach(idx, set in sets)
  {
    local id = set.getShopTabId()
    if (id in this)
      continue

    newSheets[id] <- {
      locId = set.locId
      typeMask = itemType.ALL
      isMarketplace = true
      sortId = sortId++

      setIdx = idx
      getSet = @() workshop.getSetsList()?[setIdx] ?? workshop.emptySet
      isAllowedForTab = @(shopTab) shopTab == itemsTab.WORKSHOP
      isEnabled = @(shopTab) isAllowedForTab(shopTab)&& getSet().isVisible()

      getItemFilterFunc = function(shopTab) {
        local set = getSet()
        return set.isItemInSet.bindenv(set)
      }

      getItemsList = @(shopTab) getSet().getItemsList()
    }
  }

  if (newSheets.len())
    shopSheets.addSheets(newSheets)
}

shopSheets.getSheetDataByItem <- function(item)
{
  if (item.shouldAutoConsume)
    return null

  updateWorkshopSheets()

  local iType = item.iType
  for (local tab = 0; tab < itemsTab.TOTAL; tab++)
    if (isTabVisible(tab))
      foreach (sh in types)
        if ((sh.typeMask & iType)
            && sh.isAllowedForTab(tab)
            && ::u.search(sh.getItemsList(tab), @(it) item.isEqual(it)) != null)
          return {
            tab = tab
            sheet = sh
          }
  return null
}

return shopSheets