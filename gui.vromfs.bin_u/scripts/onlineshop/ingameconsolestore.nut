local bhvUnseen = require("scripts/seen/bhvUnseen.nut")

class ::gui_handlers.IngameConsoleStore extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/items/itemsShop.blk"

  itemsCatalog = null
  chapter = null
  afterCloseFunc = null

  seenList = null
  sheetsArray = null

  titleLocId = ""
  storeLocId = ""
  openStoreLocId = ""
  seenEnumId = "other" // replacable

  curSheet = null
  lastSelectedItem = null //last selected item to restore selection after change list

  itemsPerPage = -1
  itemsList = null
  curPage = 0
  currentFocusItem = 6

  // Used to avoid expensive get...List and further sort.
  itemsListValid = false

  lastSortingPeerSheet = {}

  needWaitIcon = false
  isLoadingInProgress = false

  function initScreen()
  {
    local titleObj = scene.findObject("wnd_title")
    titleObj.setValue(::loc(titleLocId))

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
    if (!sheetsArray.len() && isLoadingInProgress)
    {
      fillPage()
      return
    }

    local sheetIdx = 0
    local view = { items = [] }

    foreach (idx, sh in sheetsArray)
    {
      if (!curSheet && ::isInArray(chapter, sh.contentTypes))
        curSheet = sh

      if (sheetIdx <= 0)
        sheetIdx = curSheet == sh? idx : 0

      view.items.append({
        id = sh.id
        text = sh?.locText ?? ::loc(sh.locId)
        unseenIcon = bhvUnseen.makeConfigStr(seenEnumId, sh.getSeenId())
      })
    }

    local data = ::handyman.renderCached("gui/items/shopFilters", view)
    guiScene.replaceContentFromText(scene.findObject("filter_tabs"), data, data.len(), this)
    initItemsListSizeOnce()

    getSheetsListObj().setValue(sheetIdx)

    //Update this objects only once. No need to do it on each updateButtons
    showSceneBtn("btn_preview", false)
    local warningTextObj = scene.findObject("warning_text")
    if (::checkObj(warningTextObj))
      warningTextObj.setValue(::colorize("warningTextColor", ::loc("warbond/alreadyBoughtMax")))
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
      loadCurSheetItemsList()
      updateSortingList()
    }

    curPage = 0
    if (lastSelectedItem)
    {
      local lastIdx = itemsList.findindex(function(item) { return item.id == lastSelectedItem.id}.bindenv(this)) ?? -1
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

    if (!isLoadingInProgress)
    {
      local pageStartIndex = curPage * itemsPerPage
      local pageEndIndex = min((curPage + 1) * itemsPerPage, itemsList.len())
      for (local i=pageStartIndex; i < pageEndIndex; i++)
      {
        local item = itemsList[i]
        if (!item)
          continue
        view.items.append(item.getViewData({
          itemIndex = i.tostring(),
          unseenIcon = item.canBeUnseen()? null : bhvUnseen.makeConfigStr(seenEnumId, item.getSeenId())
        }))
      }
    }
    local listObj = getItemsListObj()
    local data = ::handyman.renderCached(("gui/items/item"), view)
    local isEmptyList = data.len() == 0 || isLoadingInProgress
    ::show_obj(listObj, !isEmptyList)
    guiScene.replaceContentFromText(listObj, data, data.len(), this)

    local emptyListObj = scene.findObject("empty_items_list")
    ::show_obj(emptyListObj, isEmptyList)
    ::show_obj(emptyListObj.findObject("loadingWait"), isEmptyList && needWaitIcon)

    showSceneBtn("items_shop_to_marketplace_button", false)
    showSceneBtn("items_shop_to_shop_button", false)
    local emptyListTextObj = scene.findObject("empty_items_list_text")
    emptyListTextObj.setValue(::loc($"items/shop/emptyTab/default{isLoadingInProgress ? "/loading" : ""}"))

    if (!isLoadingInProgress)
    {
      local prevValue = listObj.getValue()
      local value = findLastValue(prevValue)
      if (value >= 0)
        listObj.setValue(value)
    }

    updateItemInfo()

    if (isLoadingInProgress)
      ::hidePaginator(scene.findObject("paginator_place"))
    else
      generatePaginator(scene.findObject("paginator_place"), this,
        curPage, ::ceil(itemsList.len().tofloat() / itemsPerPage) - 1, null, true /*show last page*/)

    if (!itemsList?.len() && sheetsArray.len())
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

  function onAltAction(obj)
  {
    local item = getCurItem()
    if (!item)
      return

    item.showDescription()
  }

  function onShowDetails(item = null)
  {
    item = item || getCurItem()
    if (!item)
      return

    item.showDetails()
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
    if (!curSheet)
      return

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
    return curSheet?.sortParams[getSortListObj().getValue()]
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
    if (!item && !isLoadingInProgress)
      return

    fillItemInfo(item)

    lastSelectedItem = item
    markItemSeen(item)
    updateButtons()
  }

  function fillItemInfo(item)
  {
    local descObj = scene.findObject("item_info")

    local obj = null

    obj = descObj.findObject("item_name")
    obj.setValue(item?.name ?? "")

    obj = descObj.findObject("item_desc_div")
    local data = getPriceBlock(item)
    guiScene.replaceContentFromText(obj, data, data.len(), this)

    obj = descObj.findObject("item_desc_under_div")
    obj.setValue(item?.getDescription() ?? "")

    obj = descObj.findObject("item_icon")
    local imageData = item?.getIcon() ?? ""
    if (imageData)
    {
      obj.wideSize = "yes"
      guiScene.replaceContentFromText(obj, imageData, imageData.len(), this)
    }
  }

  function getPriceBlock(item)
  {
    if (item?.isBought)
      return ""
    //Generate price string as PSN requires and return blk format to replace it.
    return handyman.renderCached("gui/commonParts/discount", item)
  }

  function updateButtons()
  {
    local item = getCurItem()
    local showMainAction = item != null && !item.isBought
    local buttonObj = showSceneBtn("btn_main_action", showMainAction)
    if (showMainAction)
    {
      buttonObj.visualStyle = "secondary"
      ::set_double_text_to_button(scene, "btn_main_action", ::loc(storeLocId))
      updateConsoleImage(buttonObj)
    }

    local showSecondAction = openStoreLocId != "" && (item?.isBought ?? false)
    buttonObj = showSceneBtn("btn_alt_action", showSecondAction)
    if (showSecondAction)
    {
      ::set_double_text_to_button(scene, "btn_alt_action", ::loc(openStoreLocId))
      updateConsoleImage(buttonObj)
    }

    showSceneBtn("warning_text", showSecondAction)
  }

  function markItemSeen(item)
  {
    if (item)
      seenList.markSeen(item.getSeenId())
  }

  function getCurItem()
  {
    if (isLoadingInProgress)
      return null

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
  onOpenCraftTree = @(obj) null
  onShowSpecialTasks = @(obj) null

  getTabsListObj = @() scene.findObject("tabs_list")
  getSheetsListObj = @() scene.findObject("sheets_list")
  getSortListObj = @() scene.findObject("sort_params_list")
  getItemsListObj = @() scene.findObject("items_list")

  function getMainFocusObj() { return getSheetsListObj() }
  function getMainFocusObj2()
  {
    local obj = getItemsListObj()
    return obj.childrenCount() ? obj : null
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
    updateConsoleImage(scene.findObject("btn_alt_action"))
  }

  function updateConsoleImage(buttonObj)
  {
    local isInactive = !::show_console_buttons || !getItemsListObj().isFocused()
    buttonObj.hideConsoleImage = isInactive ? "yes" : "no"
    buttonObj.enable(!isInactive)
  }
}