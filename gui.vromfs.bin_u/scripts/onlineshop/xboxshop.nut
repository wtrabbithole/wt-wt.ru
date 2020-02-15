require("scripts/onlineShop/ingameConsoleStore.nut")

local seenList = require("scripts/seen/seenList.nut").get(SEEN.EXT_XBOX_SHOP)
local xboxShopData = require("scripts/onlineShop/xboxShopData.nut")

local sheetsArray = [
  {
    id = "xbox_game_content"
    locId = "itemTypes/xboxGameContent"
    getSeenId = @() "##xbox_item_sheet_" + mediaType
    mediaType = xboxMediaItemType.GameContent
    sortParams = ["releaseDate", "price", "isBought"]
    sortSubParam = "name"
    contentTypes = [null, ""]
  },
  {
    id = "xbox_game_consumation"
    locId = "itemTypes/xboxGameConsumation"
    getSeenId = @() "##xbox_item_sheet_" + mediaType
    mediaType = xboxMediaItemType.GameConsumable
    sortParams = ["price"]
    sortSubParam = "consumableQuantity"
    contentTypes = ["eagles"]
  }
]

foreach (sh in sheetsArray)
{
  local sheet = sh
  seenList.setSubListGetter(sheet.getSeenId(), @() (
    xboxShopData.xboxProceedItems?[sheet.mediaType] ?? []).filter(@(it) !it.canBeUnseen()).map(@(it) it.getSeenId()))
}

class ::gui_handlers.XboxShop extends ::gui_handlers.IngameConsoleStore
{
  function loadCurSheetItemsList()
  {
    itemsList = itemsCatalog?[curSheet.mediaType] ?? []
  }

  function onEventXboxSystemUIReturn(p)
  {
    lastSelectedItem = getCurItem()
    local wasItemBought = lastSelectedItem?.isBought
    lastSelectedItem?.updateIsBoughtStatus()

    local wasPurchasePerformed = wasItemBought != lastSelectedItem?.isBought

    if (wasPurchasePerformed)
    {
      ::g_tasker.addTask(::update_entitlements_limited(),
        {
          showProgressBox = true
          progressBoxText = ::loc("charServer/checking")
        },
        ::Callback(function() {
          updateSorting()
          fillItemsList()
          ::g_discount.updateOnlineShopDiscounts()

          if (lastSelectedItem.isMultiConsumable || wasPurchasePerformed)
            ::update_gamercards()
        }, this)
      )
    }
  }

  function goBack()
  {
    ::g_tasker.addTask(::update_entitlements_limited(),
      {
        showProgressBox = true
        progressBoxText = ::loc("charServer/checking")
      },
      ::Callback(function() {
        ::g_discount.updateOnlineShopDiscounts()
        ::update_gamercards()
      })
    )

    base.goBack()
  }
}

return xboxShopData.__merge({
  openWnd = @(chapter = null, afterCloseFunc = null) xboxShopData.requestData(
    false,
    @() ::handlersManager.loadHandler(::gui_handlers.XboxShop, {
      itemsCatalog = xboxShopData.xboxProceedItems,
      chapter = chapter,
      afterCloseFunc = afterCloseFunc
      titleLocId = "topmenu/xboxIngameShop"
      storeLocId = "items/openIn/XboxStore"
      seenEnumId = SEEN.EXT_XBOX_SHOP
      seenList = seenList
      sheetsArray = sheetsArray
    }),
    true
  )
})