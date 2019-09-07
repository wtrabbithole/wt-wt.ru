local bhvUnseen = ::require("scripts/seen/bhvUnseen.nut")
local seenList = ::require("scripts/seen/seenList.nut").get(SEEN.EXT_XBOX_SHOP)

local xboxShopData = ::require("scripts/onlineShop/xboxShopData.nut")

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
    xboxShopData.xboxProceedItems?[sheet.mediaType] ?? []).filter(@(idx, it) !it.canBeUnseen()).map(@(it) it.getSeenId()))
}

class ::gui_handlers.XboxShop extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/items/itemsShop.blk"

  itemsCatalog = null
  chapter = null
  afterCloseFunc = null

  curSheet = null
  lastSelectedItem = null //last selected item to restore selection after change list

  itemsPerPage = -1
  itemsList = null
  curPage = 0
  currentFocusItem = 6

  // Used to avoid expensive get...List and further sort.
  itemsListValid = false

  lastSortingPeerSheet = {}

  function initScreen()
  {
    local titleObj = scene.findObject("wnd_title")
    titleObj.setValue(::loc("topmenu/xboxIngameShop"))

    ::show_obj(getTabsListObj(), false)
    ::show_obj(getSheetsListObj(), false)
    showSceneBtn("sorting_block", true)

    fillItemsList()

    initFocusArray()
  }

  function reinitScreen(params)
  {
    itemsCatalog = params?.itemsCatalog
    itemsListValid = false
    applyFilters()
  }

  function fillItemsList()
  {
    markCurrentPageSeen()
    initSheets()
  }

  function initSheets()
  {
    local sheetIdx = 0
    local view = { items = [] }

    foreach (idx, sh in sheetsArray)
    {
      if (!curSheet && ::isInArray(chapter, sh.contentTypes))
        curSheet = sh

      sheetIdx = curSheet == sh? idx : 0
      view.items.append({
        id = sh.id
        text = ::loc(sh.locId)
        unseenIcon = bhvUnseen.makeConfigStr(SEEN.EXT_XBOX_SHOP, sh.getSeenId())
      })
    }

    local data = ::handyman.renderCached("gui/items/shopFilters", view)
    guiScene.replaceContentFromText(scene.findObject("filter_block"), data, data.len(), this)
    initItemsListSizeOnce()

    getSheetsListObj().setValue(sheetIdx)
  }

  function onItemTypeChange(obj)
  {
    markCurrentPageSeen()

    local newSheet = sheetsArray?[obj.getValue()]
    if (!newSheet)
      return

    curSheet = newSheet
    itemsListValid = false

    applyFilters()
  }

  function applyFilters()
  {
    if (!itemsListValid)
    {
      itemsListValid = true
      getCurSheetItemsList()
      updateSortingList()
    }

    curPage = 0
    if (lastSelectedItem)
    {
      local lastIdx = itemsList.searchIndex(function(item) { return item.id == lastSelectedItem.id}.bindenv(this)) ?? -1
      if (lastIdx >= 0)
        curPage = (lastIdx / itemsPerPage).tointeger()
      else if (curPage * itemsPerPage > itemsCatalog.len())
        curPage = ::max(0, ((itemsCatalog.len() - 1) / itemsPerPage).tointeger())
    }
    fillPage()
  }

  function fillPage()
  {
    local view = { items = [] }
    local pageStartIndex = curPage * itemsPerPage
    local pageEndIndex = min((curPage + 1) * itemsPerPage, itemsList.len())
    for (local i=pageStartIndex; i < pageEndIndex; i++)
    {
      local item = itemsList[i]
      view.items.append(item.getViewData({
        itemIndex = i.tostring(),
        unseenIcon = item.canBeUnseen()? null : bhvUnseen.makeConfigStr(SEEN.EXT_XBOX_SHOP, item.getSeenId())
      }))
    }

    local listObj = getItemsListObj()
    local data = ::handyman.renderCached(("gui/items/item"), view)
    local isEmptyList = data.len() == 0
    ::show_obj(listObj, !isEmptyList)
    guiScene.replaceContentFromText(listObj, data, data.len(), this)

    local emptyListObj = scene.findObject("empty_items_list")
    ::show_obj(emptyListObj, isEmptyList)

    showSceneBtn("items_shop_to_marketplace_button", false)
    showSceneBtn("items_shop_to_shop_button", false)
    local emptyListTextObj = scene.findObject("empty_items_list_text")
    emptyListTextObj.setValue(::loc("items/shop/emptyTab/default"))

    local prevValue = listObj.getValue()
    local value = findLastValue(prevValue)
    if (value >= 0)
      listObj.setValue(value)

    updateItemInfo()

    generatePaginator(scene.findObject("paginator_place"), this,
      curPage, ::ceil(itemsList.len().tofloat() / itemsPerPage) - 1, null, true /*show last page*/)

    if (!itemsList.len())
      focusSheetsList()
  }

  function focusSheetsList()
  {
    local obj = getSheetsListObj()
    obj.select()
    checkCurrentFocusItem(obj)
  }

  function findLastValue(prevValue)
  {
    local offset = curPage * itemsPerPage
    local total = ::clamp(itemsList.len() - offset, 0, itemsPerPage)
    if (!total)
      return -1

    local res = ::clamp(prevValue, 0, total - 1)
    if (lastSelectedItem)
      for(local i = 0; i < total; i++)
      {
        local item = itemsList[offset + i]
        if (lastSelectedItem.id != item.id)
          continue
        res = i
      }
    return res
  }

  function goToPage(obj)
  {
    markCurrentPageSeen()
    curPage = obj.to_page.tointeger()
    fillPage()
  }

  function onItemAction(buttonObj)
  {
    local id = buttonObj?.holderId
    if (id == null)
      return
    local item = ::getTblValue(id.tointeger(), itemsList)
    onShowDetails(item)
  }

  function onMainAction(obj)
  {
    onShowDetails()
  }

  function onShowDetails(item = null)
  {
    item = item || getCurItem()
    if (!item)
      return

    ::xbox_show_details(item.id)
  }

  function initItemsListSizeOnce()
  {
    if (itemsPerPage >= 1)
      return

    local sizes = ::g_dagui_utils.adjustWindowSize(scene.findObject("wnd_items_shop"), getItemsListObj(),
                                                   "@itemWidth", "@itemHeight", "@itemSpacing", "@itemSpacing")
    itemsPerPage = sizes.itemsCountX * sizes.itemsCountY
  }

  function onChangeSortOrder(obj)
  {
    updateSorting()
    fillPage()
  }

  function onChangeSortParam(obj)
  {
    lastSortingPeerSheet[curSheet.id] <- obj.getValue()
    updateSorting()
    fillPage()
  }

  function getCurSheetItemsList()
  {
    itemsList = itemsCatalog?[curSheet.mediaType] ?? []
  }

  function updateSortingList()
  {
    local obj = getSortListObj()
    if (!::checkObj(obj))
      return

    local view = { radiobutton = [] }
    foreach (param in curSheet.sortParams)
    {
      view.radiobutton.append({
        tooltip = "#items/sort/" + param
        text = "#items/sort/" + param
      })
    }

    local val = lastSortingPeerSheet?[curSheet.id] ?? obj.getValue()
    local data = ::handyman.renderCached("gui/commonParts/radiobutton", view)
    guiScene.replaceContentFromText(obj, data, data.len(), this)
    local newVal = val < 0 || val >= view.radiobutton.len()? 0 : val
    obj.setValue(newVal)
  }

  function updateSorting()
  {
    local isAscendingSort = scene.findObject("sort_order").getValue()
    local sortParam = getSortParam()
    local sortSubParam = curSheet.sortSubParam
    itemsList.sort(function(a, b) {
      return sortOrder(a, b, isAscendingSort, sortParam, sortSubParam)
    }.bindenv(this))
  }

  function sortOrder(a, b, isAscendingSort, sortParam, sortSubParam)
  {
    return (isAscendingSort? -1: 1) * (a[sortParam] <=> b[sortParam]) || a[sortSubParam] <=> b[sortSubParam]
  }

  function getSortParam()
  {
    return curSheet.sortParams[getSortListObj().getValue()]
  }

  function markCurrentPageSeen()
  {
    if (!itemsList)
      return

    local pageStartIndex = curPage * itemsPerPage
    local pageEndIndex = min((curPage + 1) * itemsPerPage, itemsList.len())
    local list = []
    for (local i = pageStartIndex; i < pageEndIndex; ++i)
      list.append(itemsList[i].getSeenId())

    seenList.markSeen(list)
  }

  function updateItemInfo()
  {
    local item = getCurItem()
    if (!item)
      return

    local descObj = scene.findObject("item_info")

    local obj = null

    obj = descObj.findObject("item_name")
    obj.setValue(item.name)

    obj = descObj.findObject("item_desc")
    obj.setValue(item.getDescription())

    obj = descObj.findObject("item_icon")
    local imageData = item.getIcon()
    if (imageData)
    {
      obj.wideSize = "yes"
      guiScene.replaceContentFromText(obj, imageData, imageData.len(), this)
    }

    lastSelectedItem = item
    markItemSeen(item)
    updateButtons()
  }

  function updateButtons()
  {
    local item = getCurItem()
    local showMainAction = item != null
    local buttonObj = showSceneBtn("btn_main_action", showMainAction)
    if (showMainAction)
    {
      buttonObj.visualStyle = "secondary"
      ::set_double_text_to_button(scene, "btn_main_action", ::loc("items/openIn/XboxStore"))
      updateConsoleImage(buttonObj)
    }

    showSceneBtn("btn_preview", false)
  }

  function markItemSeen(item)
  {
    if (item)
      seenList.markSeen(item.getSeenId())
  }

  function getCurItem()
  {
    local obj = getItemsListObj()
    if (!::check_obj(obj))
      return null

    return itemsList?[obj.getValue() + curPage * itemsPerPage]
  }

  function getCurItemObj()
  {
    local itemListObj = getItemsListObj()
    local value = itemListObj.getValue()
    if (value < 0)
      return null
    return itemListObj.getChild(value)
  }

  onTabChange = @() null
  onToShopButton = @(obj) null
  onToMarketplaceButton = @(obj) null
  onLinkAction = @(obj) null
  onItemPreview = @(obj) null
  onAltAction = @(obj) null

  getTabsListObj = @() scene.findObject("tabs_list")
  getSheetsListObj = @() scene.findObject("sheets_list")
  getSortListObj = @() scene.findObject("sort_params_list")
  getItemsListObj = @() scene.findObject("items_list")

  function getMainFocusObj() { return getSortListObj() }
  function getMainFocusObj2() { return getSheetsListObj() }
  function getMainFocusObj3()
  {
    local obj = getItemsListObj()
    return obj.childrenCount() ? obj : null
  }

  function onEventXboxSystemUIReturn(p)
  {
    local item = getCurItem()
    item?.updateIsBoughtStatus?()
    updateSorting()
    fillItemsList()
    ::g_discount.updateXboxShopDiscounts()
  }

  function goBack()
  {
    markCurrentPageSeen()
    base.goBack()
  }

  function afterModalDestroy()
  {
    if (afterCloseFunc)
      afterCloseFunc()
  }

  function onItemsListFocusChange()
  {
    if (!isValid())
      return

    updateConsoleImage(scene.findObject("btn_main_action"))
  }

  function updateConsoleImage(buttonObj)
  {
    buttonObj.hideConsoleImage = (!::show_console_buttons || !getItemsListObj().isFocused()) ? "yes" : "no"
  }
}

return xboxShopData.__merge({
  openWnd = @(chapter = null, afterCloseFunc = null) xboxShopData.requestData(
    false,
    @() ::handlersManager.loadHandler(::gui_handlers.XboxShop, {
      itemsCatalog = xboxShopData.xboxProceedItems,
      chapter = chapter,
      afterCloseFunc = afterCloseFunc}),
    true
  )
})