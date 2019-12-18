require("ingameConsoleStore.nut")

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

local fillSheetsArray = function() {
  if (!shopData.getData().blockCount())
  {
    //Empty categories data
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
}

subscriptions.addListenersWithoutEnv({
  Ps4ShopDataUpdated = @(p) fillSheetsArray()
})

class ::gui_handlers.Ps4Shop extends ::gui_handlers.IngameConsoleStore
{
  needWaitIcon = true
  isLoadingInProgress = false

  function loadCurSheetItemsList()
  {
    itemsList = []
    local itemsLinks = shopData.getData().getBlockByName(curSheet.categoryId)?.links ?? ::DataBlock()
    for (local i = 0; i < itemsLinks.blockCount(); i++)
      itemsList.append(shopData.getShopItem(itemsLinks.getBlock(i).getBlockName()))
  }

  function onEventPs4ShopDataUpdated(p)
  {
    isLoadingInProgress = p?.isLoadingInProgress ?? false
    fillItemsList()
    restoreFocus()
    updateItemInfo()
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
    chapter = chapter
    afterCloseFunc = afterCloseFunc
    titleLocId = "topmenu/ps4IngameShop"
    storeLocId = "items/openIn/Ps4Store"
    seenEnumId = seenEnumId
    seenList = seenList
    sheetsArray = persist.sheetsArray
  })
}