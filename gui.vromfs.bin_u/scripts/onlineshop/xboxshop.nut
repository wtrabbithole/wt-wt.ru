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
  function onEventXboxSystemUIReturn(p)
  {
    local item = getCurItem()
    item?.updateIsBoughtStatus?()
    updateSorting()
    fillItemsList()
    ::g_discount.updateXboxShopDiscounts()
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