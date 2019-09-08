const KNOWN_ITEMS_SAVE_ID = "workshop/known"
const KNOWN_REQ_ITEMS_SAVE_ID = "workshop/knownReqItems"
const KNOWN_ITEMS_SAVE_KEY = "id"
const PREVIEWED_SAVE_PATH = "workshop/previewed/"

local WorkshopSet = class {
  id = "" //name of config blk. not unique
  uid = -1
  reqFeature = null //""
  locId = ""

  itemdefsSorted = null //[]
  itemdefs = null //{ <itemdef> = sortId }
  requiredItemsTbl = null  // { <itemIs> = true }
  hiddenItemsBlocks = null // { <blockId> = true }
  alwaysVisibleItemdefs = null // { <itemdef> = sortId }
  knownItemdefs = null // { <itemdef> = true }
  knownReqItemdefs = null // { <reqitemdef> = true }

  isToStringForDebug = true

  itemsListCache = null
  visibleSeenIds = null

  previewBlk = null

  constructor(blk)
  {
    id = blk.getBlockName() || ""
    reqFeature = blk?.reqFeature
    locId = blk?.locId || id

    itemdefsSorted = []
    itemdefs = {}
    requiredItemsTbl = {}
    alwaysVisibleItemdefs = {}

    local itemsBlk = blk?.items
    itemdefsSorted.extend(getItemsFromBlk(itemsBlk, 0))
    if (itemsBlk)
      foreach (idx, itemBlk in itemsBlk % "itemBlock")
        itemdefsSorted.extend(getItemsFromBlk(itemBlk, idx + 1))

    if (blk?.eventPreview)
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
  getShopTabId              = @() "WORKSHOP_SET_" + uid
  getSeenId                 = @() "##workshop_set_" + uid

  isItemInSet               = @(item) item.id in itemdefs
  isItemIdInSet             = @(id) id in itemdefs
  isItemIdHidden            = @(id) itemdefs[id].blockNumber in hiddenItemsBlocks
  isItemIdKnown             = @(id) initKnownItemsOnce() || id in knownItemdefs
  isReqItemIdKnown          = @(id) id in knownReqItemdefs
  shouldDisguiseItem        = @(item) !(item.id in alwaysVisibleItemdefs) && !isItemIdKnown(item.id)
    && !item?.itemDef?.tags?.alwaysKnownItem

  hasPreview                = @() previewBlk != null

  function getItemsFromBlk(itemsBlk, blockNumber)
  {
    local items = []
    if (!itemsBlk)
      return items

    local sortByParam = itemsBlk?.sortByParam
    local requiredItems = []
    local passBySavedReqItems = itemsBlk?.passBySavedReqItems ?? false
    foreach(reqItems in itemsBlk % "reqItems")
    {
      local reqItemsList = ::u.map(::split(reqItems, ","), @(item) item.tointeger())
      requiredItems.append(reqItemsList)
      foreach (itemId in reqItemsList)
        if (!(itemId in requiredItemsTbl))
          requiredItemsTbl[itemId] <- true
    }

    for (local i = 0; i < itemsBlk.paramCount(); i++)
    {
      local itemdef = itemsBlk.getParamValue(i)
      if (typeof(itemdef) != "integer")
        continue

      if (itemsBlk.getParamName(i) == "alwaysVisibleItem")
        alwaysVisibleItemdefs[itemdef] <- true

      items.append(itemdef)
    }

    foreach (idx, itemId in items)
      itemdefs[itemId] <- {
        blockNumber = blockNumber
        itemNumber = idx
        sortByParam = sortByParam
        requiredItems = requiredItems
        passBySavedReqItems = passBySavedReqItems
      }

    return items
  }

  function initHiddenItemsBlocks()
  {
    loadKnownReqItemsOnce()

    hiddenItemsBlocks = {}

    local reqItems = ::ItemsManager.getInventoryList(itemType.ALL,
      (@(item) item.id in requiredItemsTbl).bindenv(this))

    local reqItemsAmountTbl = {}
    foreach (item in reqItems)
      reqItemsAmountTbl[item.id] <- item.getAmount() + (reqItemsAmountTbl?[item.id] ?? 0)

    updateKnownReqItems(reqItemsAmountTbl)

    foreach (itemData in itemdefs)
    {
      local blockNumber = itemData.blockNumber
      if (itemData.blockNumber in hiddenItemsBlocks)
        continue

      local requiredItems = itemData?.requiredItems
      if (!requiredItems || !requiredItems.len())
        continue

      local isHidden = true
      foreach (items in requiredItems)
      {
        local canShow = true
        foreach (itemId in items)
        {
          if ((reqItemsAmountTbl?[itemId] ?? 0) > 0 ||
              (itemData.passBySavedReqItems && knownReqItemdefs?[itemId]))
            continue

          canShow = false
          break
        }

        if (canShow)
        {
          isHidden = false
          break
        }
      }

      if (isHidden)
        hiddenItemsBlocks[blockNumber] <- true
    }
  }

  function getItemsList()
  {
    if (itemsListCache && !requiredItemsTbl.len())
      return itemsListCache

    initHiddenItemsBlocks()
    itemsListCache = ::ItemsManager.getInventoryList(itemType.ALL,
      (@(item) isItemIdInSet(item.id) && !item.isHiddenItem() && !isItemIdHidden(item.id)).bindenv(this))
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
      if (isItemIdHidden(itemdef))
        continue

      local item = ItemsManager.getItemOrRecipeBundleById(itemdef)
      if (!item
          || (item.iType == itemType.RECIPES_BUNDLE && !item.getMyRecipes().len()))
        continue

      local newItem = item.makeEmptyInventoryItem()
      if (!newItem.isEnabled())
        continue

      if (shouldDisguiseItem(item))
        newItem.setDisguise(true)

      itemsListCache.append(newItem)
    }

    itemsListCache.sort((@(a, b)
      (itemdefs?[a.id].blockNumber ?? -1) <=> (itemdefs?[b.id].blockNumber ?? -1)
      || (itemdefs?[a.id].sortByParam == "name" && a.getName(false) <=> b.getName(false))
      || (itemdefs?[a.id].itemNumber ?? -1) <=> (itemdefs?[b.id].itemNumber ?? -1)).bindenv(this))

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
    foreach(_id in knownList)
      if (isItemIdInSet(_id))
        knownItemdefs[_id] <- true
  }

  function loadKnownReqItemsOnce()
  {
    if (knownReqItemdefs)
      return

    knownReqItemdefs = {}
    local knownBlk = ::load_local_account_settings(KNOWN_REQ_ITEMS_SAVE_ID)
    if (!knownBlk)
      return

    local knownList = knownBlk % KNOWN_ITEMS_SAVE_KEY
    foreach(_id in knownList)
      knownReqItemdefs[_id] <- true
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

    saveKnownItems(newKnownIds, KNOWN_ITEMS_SAVE_ID)
  }

  function updateKnownReqItems(reqItemsAmountTbl)
  {
    loadKnownReqItemsOnce()

    local newKnownIds = []
    foreach(reqItemId, amount in reqItemsAmountTbl)
      if (amount > 0 && !isReqItemIdKnown(reqItemId))
      {
        knownReqItemdefs[reqItemId] <- true
        newKnownIds.append(reqItemId)
      }

    saveKnownItems(newKnownIds, KNOWN_REQ_ITEMS_SAVE_ID)
  }

  function saveKnownItems(newKnownIds, saveId)
  {
    if (!newKnownIds.len())
      return

    local knownBlk = ::load_local_account_settings(saveId)
    if (!knownBlk)
      knownBlk = ::DataBlock()
    foreach(_id in newKnownIds)
      knownBlk[KNOWN_ITEMS_SAVE_KEY] <- _id

    ::save_local_account_settings(saveId, knownBlk)
  }

  getPreviewedSaveId   = @() PREVIEWED_SAVE_PATH + id
  needShowPreview      = @() hasPreview() && !::load_local_account_settings(getPreviewedSaveId(), false)
  markPreviewed        = @() ::save_local_account_settings(getPreviewedSaveId(), true)

  function invalidateItemsCache()
  {
    visibleSeenIds = null
    itemsListCache = null
  }

  function getVisibleSeenIds()
  {
    if (!visibleSeenIds)
    {
      visibleSeenIds = {}
      foreach(item in getItemsList())
        if (!item.isDisguised)
          visibleSeenIds[item.id] <- item.getSeenId()
    }
    return visibleSeenIds
  }

  _tostring = @() ::format("WorkshopSet %s (itemdefsAmount = %d)", id, itemdefs.len())
}

return WorkshopSet