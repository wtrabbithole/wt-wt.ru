require("ingameConsoleStore.nut")
local psnStore = require("ps4_api.store")
local psnSystem = require("ps4_api.sys")

local seenEnumId = SEEN.EXT_PS4_SHOP

local subscriptions = require("sqStdlibs/helpers/subscriptions.nut")
local seenList = require("scripts/seen/seenList.nut").get(seenEnumId)
local shopData = require("scripts/onlineShop/ps4ShopData.nut")

local persist = {
  sheetsArray = []
}
::g_script_reloader.registerPersistentData("PS4Shop", persist, ["sheetsArray"])


local defaultsSheetData = {
  WARTHUNDEREAGLES = {
    sortParams = ["price"]
    sortSubParam = "name"
    contentTypes = ["eagles"]
  }
  def = {
    sortParams = ["price", "isBought"]
    sortSubParam = "name"
    contentTypes = [null, ""]
  }
}

local fillSheetsArray = function(bcEventParams = {}) {
  if (!shopData.getData().blockCount())
  {
    ::dagor.debug("PS4: Ingame Shop: Don't init sheets. CategoriesData is empty")
    return
  }

  if (!persist.sheetsArray.len())
  {
    for (local i = 0; i < shopData.getData().blockCount(); i++)
    {
      local block = shopData.getData().getBlock(i)
      local categoryId = block.getBlockName()

      persist.sheetsArray.append({
        id = "sheet_" + categoryId
        locText = block.name
        getSeenId = @() "##ps4_item_sheet_" + categoryId
        categoryId = categoryId
        sortParams = defaultsSheetData?[categoryId].sortParams ?? defaultsSheetData.def.sortParams
        sortSubParam = "name"
        contentTypes = defaultsSheetData?[categoryId].contentTypes ?? defaultsSheetData.def.contentTypes
      })
    }
  }

  foreach (sh in persist.sheetsArray)
  {
    local sheet = sh
    seenList.setSubListGetter(sheet.getSeenId(), function()
    {
      local res = []
      local productsList = shopData.getData()?[sheet.categoryId].links ?? ::DataBlock()
      for (local i = 0; i < productsList.blockCount(); i++)
      {
        local blockName = productsList.getBlock(i).getBlockName()
        local item = shopData.getShopItem(blockName)
        if (!item)
          continue

        if (!item.canBeUnseen())
          res.append(item.getSeenId())
      }
      return res
    })
  }

  ::broadcastEvent("PS4ShopSheetsInited", bcEventParams)
}

subscriptions.addListenersWithoutEnv({
  Ps4ShopDataUpdated = fillSheetsArray
})

class ::gui_handlers.Ps4Shop extends ::gui_handlers.IngameConsoleStore
{
  needWaitIcon = true
  isLoadingInProgress = false

  function initScreen()
  {
    if (canDisplayStoreContents())
    {
      psnStore.show_icon(psnStore.IconPosition.CENTER)
      base.initScreen()
    }
    else
      goBack()
  }

  function loadCurSheetItemsList()
  {
    itemsList = []
    local itemsLinks = shopData.getData().getBlockByName(curSheet.categoryId)?.links ?? ::DataBlock()
    for (local i = 0; i < itemsLinks.blockCount(); i++)
    {
      local itemId = itemsLinks.getBlock(i).getBlockName()
      local block = shopData.getShopItem(itemId)
      if (block)
        itemsList.append(block)
      else
        ::dagor.debug($"PS4: Ingame Shop: Skip missing info of item {itemId}")
    }
  }

  function afterModalDestroy()
  {
    psnStore.hide_icon()
  }

  function canDisplayStoreContents()
  {
    local isStoreEmpty = !isLoadingInProgress && !itemsCatalog.len()
    if (isStoreEmpty)
      psnSystem.show_message(psnSystem.Message.EMPTY_STORE, @() null)
    return !isStoreEmpty
  }

  function onEventPS4ShopSheetsInited(p)
  {
    isLoadingInProgress = p?.isLoadingInProgress ?? false
    fillItemsList()
    restoreFocus()
    updateItemInfo()
    if (!canDisplayStoreContents())
      goBack()
  }

  function onEventPS4IngameShopUpdate(p)
  {
    lastSelectedItem = getCurItem()
    local wasBought = lastSelectedItem?.isBought
    lastSelectedItem?.updateIsBoughtStatus()
    if (wasBought != lastSelectedItem?.isBought)
      ::configs.ENTITLEMENTS_PRICE.checkUpdate()

    updateSorting()
    fillItemsList()
    ::g_discount.updateOnlineShopDiscounts()
  }
}

return {
  canUseIngameShop = shopData.canUseIngameShop
  openWnd = @(chapter = null, afterCloseFunc = null) ::handlersManager.loadHandler(::gui_handlers.Ps4Shop, {
    itemsCatalog = shopData.getShopItemsTable()
    isLoadingInProgress = !shopData.isItemsUpdated()
    chapter = chapter
    afterCloseFunc = afterCloseFunc
    titleLocId = "topmenu/ps4IngameShop"
    storeLocId = "items/purchaseIn/Ps4Store"
    openStoreLocId = "items/openIn/Ps4Store"
    seenEnumId = seenEnumId
    seenList = seenList
    sheetsArray = persist.sheetsArray
  })
}
