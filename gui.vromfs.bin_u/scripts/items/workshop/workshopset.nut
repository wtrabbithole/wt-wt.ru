local ExchangeRecipes = require("scripts/items/exchangeRecipes.nut")

const KNOWN_ITEMS_SAVE_ID = "workshop/known"
const KNOWN_ITEMS_SAVE_KEY = "id"
const PREVIEWED_SAVE_PATH = "workshop/previewed/"

local WorkshopSet = class {
  id = "" //name of config blk. not unique
  uid = -1
  reqFeature = null //""
  locId = ""

  itemdefsSorted = null //[]
  itemdefs = null //{ <itemdef> = sortId }
  alwaysVisibleItemdefs = null // { <itemdef> = sortId }
  knownItemdefs = null // { <itemdef> = true }

  isToStringForDebug = true

  itemsListCache = null
  numUnseenItems = -1

  previewBlk = null

  constructor(blk)
  {
    id = blk.getBlockName() || ""
    reqFeature = blk.reqFeature
    locId = blk.locId || id

    itemdefsSorted = []
    itemdefs = {}
    alwaysVisibleItemdefs = {}
    local itemsBlk = blk.items
    if (itemsBlk)
      for ( local i = 0; i < itemsBlk.paramCount(); i++ )
      {
        local itemdef = itemsBlk.getParamValue(i)
        if (typeof itemdef != "integer")
          continue

        itemdefs[itemdef] <- itemdefsSorted.len()
        if (itemsBlk.getParamName(i) == "alwaysVisibleItem")
          alwaysVisibleItemdefs[itemdef] <- itemdefsSorted.len()
        itemdefsSorted.append(itemdef)
      }

    if (blk.eventPreview)
    {
      previewBlk = ::DataBlock()
      previewBlk.setFrom(blk.eventPreview)
    }

    ::subscribe_handler(this, ::g_listener_priority.CONFIG_VALIDATION)
  }

  isValid                   = @() id.len() > 0 && itemdefs.len() > 0
  isVisible                 = @() !reqFeature || ::has_feature(reqFeature)
  isItemDefAlwaysVisible    = @(itemdef) itemdef in alwaysVisibleItemdefs
  getItemdefs               = @() itemdefsSorted
  getLocName                = @() ::loc(locId)
  getShopTabId              = @()"WORKSHOP_SET_" + uid

  isItemInSet               = @(item) item.id in itemdefs
  isItemIdInSet             = @(id) id in itemdefs
  isItemIdKnown             = @(id) initKnownItemsOnce() || id in knownItemdefs
  shouldDisguiseItem        = @(item) !(item.id in alwaysVisibleItemdefs) && !isItemIdKnown(item.id)

  hasPreview                = @() previewBlk != null

  function getItemsList()
  {
    if (itemsListCache)
      return itemsListCache

    itemsListCache = ::ItemsManager.getInventoryList(itemType.ALL, isItemInSet.bindenv(this) )
    updateKnownItems(itemsListCache)

    local requiredList = alwaysVisibleItemdefs.__merge(knownItemdefs)

    //add all craft parts recipes result to visible items.
    if (requiredList.len() != itemdefs.len())
      foreach(item in itemsListCache)
        if (item.iType == itemType.CRAFT_PART)
        {
          local recipes = item.getRelatedRecipes()
          if (!recipes.len())
            continue
          foreach(r in recipes)
            if (r.generatorId in itemdefs)
              requiredList[r.generatorId] <- 0
        }

    foreach(item in itemsListCache)
      if (item.id in requiredList)
        delete requiredList[item.id]

    foreach(itemdef, sortId in requiredList)
    {
      local item = ItemsManager.findItemByItemDefId(itemdef)
      if (item)
      {
        local newItem = item.makeEmptyInventoryItem()
        if (!(item.id in alwaysVisibleItemdefs) && !isItemIdKnown(item.id))
          newItem.setDisguise(true)
        itemsListCache.append(newItem)
      }
    }

    itemsListCache.sort((@(a, b) itemdefs?[a.id] <=> itemdefs?[b.id]).bindenv(this))
    return itemsListCache
  }

  static function clearOutdatedData(actualSets)
  {
    local knownBlk = ::load_local_account_settings(KNOWN_ITEMS_SAVE_ID)
    if (!knownBlk)
      return

    local hasChanges = false
    for(local i = knownBlk.paramCount() - 1; i >= 0; i--)
    {
      local id = knownBlk.getParamValue(i)
      local isActual = false
      foreach(set in actualSets)
        if (set.isItemIdInSet(id))
        {
          isActual = true
          break
        }
      if (isActual)
        continue
      knownBlk.removeParamById(i)
      hasChanges = true
    }
    if (hasChanges)
      ::save_local_account_settings(KNOWN_ITEMS_SAVE_ID, knownBlk)
  }

  function loadKnownItemsOnce()
  {
    if (knownItemdefs)
      return

    knownItemdefs = {}
    local knownBlk = ::load_local_account_settings(KNOWN_ITEMS_SAVE_ID)
    if (!knownBlk)
      return

    local knownList = knownBlk % KNOWN_ITEMS_SAVE_KEY
    foreach(id in knownList)
      if (isItemIdInSet(id))
        knownItemdefs[id] <- true
  }

  function initKnownItemsOnce()
  {
    if (!knownItemdefs)
      updateKnownItems(::ItemsManager.getInventoryList(itemType.ALL, isItemInSet.bindenv(this) ))
  }

  function updateKnownItems(curInventoryItems)
  {
    loadKnownItemsOnce()

    local newKnownIds = []
    foreach(item in curInventoryItems)
      if (!isItemIdKnown(item.id))
      {
        knownItemdefs[item.id] <- true
        newKnownIds.append(item.id)
      }

    if (!newKnownIds.len())
      return

    local knownBlk = ::load_local_account_settings(KNOWN_ITEMS_SAVE_ID)
    if (!knownBlk)
      knownBlk = ::DataBlock()
    foreach(id in newKnownIds)
      knownBlk[KNOWN_ITEMS_SAVE_KEY] <- id
    ::save_local_account_settings(KNOWN_ITEMS_SAVE_ID, knownBlk)
  }

  getPreviewedSaveId   = @() PREVIEWED_SAVE_PATH + id
  needShowPreview      = @() hasPreview() && !::load_local_account_settings(getPreviewedSaveId(), false)
  markPreviewed        = @() ::save_local_account_settings(getPreviewedSaveId(), true)

  function getNumUnseenItems()
  {
    if (numUnseenItems >= 0)
      return numUnseenItems

    numUnseenItems = 0
    foreach(item in getItemsList())
      if (::ItemsManager.isItemUnseen(item))
        numUnseenItems++
    return numUnseenItems
  }

  function onEventInventoryUpdate(p)
  {
    numUnseenItems = -1
    itemsListCache = null
  }

  function onEventItemsShopUpdate(p)
  {
    itemsListCache = null
  }

  function onEventSeenItemsChanged(p)
  {
    if (p.forInventoryItems)
      numUnseenItems = -1
  }

  _tostring = @() ::format("WorkshopSet %s (itemdefsAmount = %d)", id, itemdefs.len())
}

return WorkshopSet