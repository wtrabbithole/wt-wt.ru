function gui_start_itemsShop(params = null)
{
  ::gui_start_items_list(itemsTab.SHOP, params)
}

function gui_start_inventory(params = null)
{
  ::gui_start_items_list(itemsTab.INVENTORY, params)
}

function gui_start_items_list(curTab, params = null)
{
  if (!::ItemsManager.isEnabled())
    return

  local handlerParams = { curTab = curTab }
  if (params != null)
    handlerParams = ::inherit_table(handlerParams, params)
  ::handlersManager.loadHandler(::gui_handlers.ItemsList, handlerParams)
}

class ::gui_handlers.ItemsList extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/items/itemsShop.blk"

  filter = null
  curTab = 0 //first itemsTab

  _defaultFilter = {
    typeMask = itemType.ALL
    devItemsTab = false
    emptyTabLocId = "items/shop/emptyTab/default"
  }

  _types = [{
      key = "all"
      typeMask = itemType.ALL
      text = "#userlog/page/all"
    } {
      key = "trophy"
      typeMask = itemType.TROPHY
      tabEnable = [itemsTab.SHOP]
    } {
      key = "booster"
      typeMask = itemType.BOOSTER
    } {
      key = "wagers"
      typeMask = itemType.WAGER
    } {
      key = "discount"
      typeMask = itemType.DISCOUNT
      tabEnable = function () {
        local result = [itemsTab.INVENTORY]
        if (::has_feature("CanBuyDiscountItems"))
          result.push(itemsTab.SHOP)
        return result
      }
    } {
      key = "tickets"
      typeMask = itemType.TICKET
    } {
      key = "orders"
      typeMask = itemType.ORDER
    } {
      key = "universalSpare"
      typeMask = itemType.UNIVERSAL_SPARE
    } {
      key = "vehicles"
      typeMask = itemType.VEHICLE
      tabEnable = @() ::has_feature("ExtInventory") ? [itemsTab.INVENTORY] : []
    } {
      key = "skins"
      typeMask = itemType.SKIN
      tabEnable = @() ::has_feature("ExtInventory") ? [itemsTab.INVENTORY] : []
    } {
      key = "decals"
      typeMask = itemType.DECAL
      tabEnable = @() ::has_feature("ExtInventory") ? [itemsTab.INVENTORY] : []
    } {
      key = "chests"
      typeMask = itemType.CHEST
      tabEnable = @() ::has_feature("ExtInventory") ? [itemsTab.INVENTORY] : []
    } {
      key = "devItems"
      typeMask = itemType.ALL
      devItemsTab = true
      tabEnable = @() ::has_feature("devItemShop") ? [itemsTab.SHOP] : []
    }
    /*
    { typeMask = itemType.WARPOINTS
      text = ::loc("warpoints/short/colored") + " " + ::loc("charServer/chapter/warpoints")
    }
    { typeMask = itemType.PREMIUM
      text = ::loc("charServer/chapter/premium")
    }
    { typeMask = itemType.GOLD
      text = ::loc("gold/short/colored") + " " + ::loc("shop/recharge")
    }
    */
  ]

  filtersInited = false
  filtersInUpdate = false
  itemsPerPage = -1
  itemsList = null
  curPage = 0

  _lastItem = null //last selected item to restore selection after change list

  slotbarActions = [ "showroom", "testflight", "weapons", "info" ]
  widgetByItem = {}
  widgetByFilter = {}
  widgetByTab = {}

  // This table holds array of filters that makes
  // sense to check for item with specified item type.
  // This optimizes numUnseenItemsByTab calculation.
  filtersByItemType = {}

  // Used to avoid expensive get...List and further sort.
  itemsListValid = false

  function initScreen()
  {
    prepareFilterTypes(_types)
    if (!filter)
      filter = clone _defaultFilter
    else
      validateFilter(filter)

    if (curTab < 0 || curTab >= itemsTab.TOTAL)
      curTab = 0

    fillTabs()

    currentFocusItem++  //main focus obj 2
    initFocusArray()

    scene.findObject("update_timer").setUserData(this)

    // If items shop was opened not in menu - player should not
    // be able to navigate through filters and tabs.
    local checkIsInMenu = ::isInMenu() || ::has_feature("devItemShop")
    local checkEnableShop = checkIsInMenu && ::has_feature("ItemsShop")
    scene.findObject("wnd_title").show(!checkEnableShop)
    getTabsListObj().show(checkEnableShop)
    getTabsListObj().enable(checkEnableShop)
    getItemTypeFilterObj().show(isInMenu)
    getItemTypeFilterObj().enable(isInMenu)
  }

  function validateFilter(checkFilter)
  {
    local newFilter = clone checkFilter
    if ("typeMask" in newFilter)
      foreach(idx, type in _types)
        if (type.typeMask == newFilter.typeMask)
        {
          newFilter = ::combine_tables(newFilter, type)
          break
        }

    newFilter = ::combine_tables(newFilter, _defaultFilter)

    if (!checkShopItemsWithFilter(newFilter, curTab))
      validateFilter(_types[0])
    else
      filter = newFilter
  }

  function prepareFilterTypes(types)
  {
    foreach (type in types)
    {
      type.id <- "shop_filter_" + type.key
      if (!("text" in type))
        type.text <- "#itemTypes/" + type.key
      if (!("emptyTabLocId" in type))
        type.emptyTabLocId <- "items/shop/emptyTab/" + type.key
      type.numUnseenItemsByTab <- {
        [itemsTab.INVENTORY] = 0,
        [itemsTab.SHOP] = 0
      }
    }
    foreach(itemClass in ::items_classes)
    {
      local itemType = itemClass.iType
      local filters = []
      foreach (type in types)
      {
        if ((type.typeMask & itemType) != 0)
          filters.push(type)
      }
      filtersByItemType[itemType] <- filters
    }
  }

  function getMainFocusObj()
  {
    return getItemTypeFilterObj()
  }

  function getMainFocusObj2()
  {
    local obj = getItemsListObj()
    return obj.childrenCount() ? obj : null
  }

  function focusFilters()
  {
    local obj = getItemTypeFilterObj()
    obj.select()
    checkCurrentFocusItem(obj)
  }

  function getTabName(tabIdx)
  {
    switch (tabIdx)
    {
      case itemsTab.SHOP:          return "items/shop"
      case itemsTab.INVENTORY:     return "items/inventory"
    }
    return ""
  }

  function fillTabs()
  {
    local view = {
      tabs = []
    }
    for (local i = 0; i < itemsTab.TOTAL; ++i)
      view.tabs.push({
        newIconWidget = NewIconWidget.createLayout()
        tabName = ::loc(getTabName(i))
        navImagesText = ::get_navigation_images_text(i, itemsTab.TOTAL)
      })

    local data = ::handyman.renderCached("gui/frameHeaderTabs", view)
    local tabsObj = getTabsListObj()
    guiScene.replaceContentFromText(tabsObj, data, data.len(), this)
    for (local i = 0; i < itemsTab.TOTAL; ++i)
    {
      local tabObj = tabsObj.getChild(i)
      local newIconWidgetObj = tabObj.findObject("tab_new_icon_widget")
      if (::checkObj(newIconWidgetObj))
        widgetByTab[i] <- NewIconWidget(guiScene, newIconWidgetObj)
    }
    tabsObj.setValue(curTab)
  }

  function onTabChange()
  {
    markCurrentPageSeen()

    local value = getTabsListObj().getValue()
    if (value >= 0 && value < itemsTab.TOTAL)
      curTab = value

    itemsListValid = false
    updateFilters()
    updateTabNewIconWidgets()
  }

  function initFilters()
  {
    if (filtersInited)
      return

    local view = {
      items = _types
    }
    for (local i = view.items.len() - 1; i >= 0; --i)
      view.items[i].newIconWidget <- NewIconWidget.createLayout()

    local data = ::handyman.renderCached(("gui/items/shopFilters"), view)
    guiScene.replaceContentFromText(scene.findObject("filter_block"), data, data.len(), this)

    local typesObj = getItemTypeFilterObj()
    if (::checkObj(typesObj))
    {
      for (local i = view.items.len() - 1; i >= 0; --i)
      {
        local filterObj = typesObj.getChild(i)
        local newIconWidgetObj = filterObj.findObject("filter_new_icon_widget")
        if (::checkObj(newIconWidgetObj))
          widgetByFilter[_types[i]] <- NewIconWidget(guiScene, newIconWidgetObj)
      }
    }

    filtersInited = true
  }

  function updateFilters()
  {
    filtersInUpdate = true //there can be multiple filters changed on switch tab, so no need to update items several times.
    guiScene.setUpdatesEnabled(false, false)
    initFilters()

    local typesObj = getItemTypeFilterObj()
    local curValue = -1
    foreach(idx, t in _types)
    {
      local enable = checkItemTab(t, curTab)
      if (enable)
        if (curValue < 0 || compareFilters(filter, t))
          curValue = idx

      local child = typesObj.getChild(idx)
      child.show(enable)
      child.enable(enable)
    }
    if (curValue >= 0)
      typesObj.setValue(curValue)

    guiScene.setUpdatesEnabled(true, true)
    filtersInUpdate = false

    applyFilters()
    updateFilterNewIconWidgets()
  }

  function updateTabNewIconWidgets()
  {
    for (local i = 0; i < itemsTab.TOTAL; ++i)
    {
      local widget = ::getTblValue(i, widgetByTab, null)
      if (widget == null)
        continue
      widget.setValue(::ItemsManager.getNumUnseenItems(i == itemsTab.INVENTORY))
    }
  }

  /**
   * @param changedItem Optional parameter which specifies shich item's
   *        seen\unseen state actually changed. Passing null will force
   *        complete recalculation.
   */
  function updateFilterNewIconWidgets(changedItem = null)
  {
    local filtersToUpdate = changedItem == null
      ? _types
      : filtersByItemType[changedItem.iType]
    foreach (filter in filtersToUpdate)
      filter.numUnseenItemsByTab[curTab] = 0

    local customEnv = {
      curTab = curTab
      filter = null
    }
    local items = curTab == itemsTab.INVENTORY
      ? ::ItemsManager.inventory
      : ::ItemsManager.itemsList
    foreach (item in items)
    {
      if (!::ItemsManager.isItemUnseen(item))
        continue
      foreach (filter in filtersToUpdate)
      {
        customEnv.filter = filter
        if ((item.iType & filter.typeMask) != 0 && filterFunc.bindenv(customEnv)(item))
          ++filter.numUnseenItemsByTab[curTab]
      }
    }

    foreach (type in _types)
    {
      local widget = ::getTblValue(type, widgetByFilter, null)
      if (widget == null)
        continue
      widget.setValue(type.numUnseenItemsByTab[curTab])
    }
  }

  function compareFilters(filter1, filter2)
  {
    return ::getTblValue("typeMask", filter1, itemType.ALL) == ::getTblValue("typeMask", filter2, itemType.ALL) &&
      ::getTblValue("devItemsTab", filter1, false) == ::getTblValue("devItemsTab", filter2, false)
  }

  function checkItemTab(itemTabData, curTab)
  {
    if (curTab == itemsTab.SHOP &&
        !checkShopItemsWithFilter(itemTabData, itemsTab.SHOP))
      return false

    if (!::ItemsManager.checkItemsMaskFeatures(itemTabData.typeMask))
      return false

    if (!("tabEnable" in itemTabData))
      return true
    local tabEnable = itemTabData.tabEnable
    if (tabEnable == null)
      return false
    if (typeof(tabEnable) == "function")
      tabEnable = tabEnable()
    if (typeof(tabEnable) == "array")
      return ::isInArray(curTab, tabEnable)
    return false
  }

  function onItemTypeChange(obj)
  {
    markCurrentPageSeen()

    local value = obj.getValue()
    if (!(value in _types))
      return

    filter.typeMask = _types[value].typeMask
    filter.devItemsTab <- ::getTblValue("devItemsTab", _types[value], false)
    filter.emptyTabLocId <- ::getTblValue("emptyTabLocId", _types[value], "")
    itemsListValid = false

    if (!filtersInUpdate)
      applyFilters()
  }

  function initItemsListSizeOnce()
  {
    if (itemsPerPage >= 1)
      return

    local sizes = ::g_dagui_utils.adjustWindowSize(scene.findObject("wnd_items_shop"), getItemsListObj(), 
                                                   "@itemWidth", "@itemHeight", "@itemSpacing", "@itemSpacing")
    itemsPerPage = sizes.itemsCountX * sizes.itemsCountY
  }

  function filterFunc(item)
  {
    return (curTab != itemsTab.SHOP || item.isCanBuy()) &&
      (::getTblValue("devItemsTab", filter, false) == item.isDevItem)
  }

  function applyFilters(resetPage = true)
  {
    initItemsListSizeOnce()

    if (!itemsListValid)
    {
      itemsListValid = true
      local typeMask = ::ItemsManager.checkItemsMaskFeatures(filter.typeMask)
      if (curTab == itemsTab.INVENTORY)
      {
        itemsList = ::ItemsManager.getInventoryList(typeMask, filterFunc.bindenv(this))
        itemsList.sort(::ItemsManager.itemsSortComparator)
      }
      else //if (curTab == itemsTab.SHOP)
        itemsList = ::ItemsManager.getShopList(typeMask, filterFunc.bindenv(this))
    }

    if (resetPage)
      curPage = 0
    else if (curPage * itemsPerPage > itemsList.len())
      curPage = ::max(0, ((itemsList.len() - 1) / itemsPerPage).tointeger())

    fillPage()
  }

  /**
   * Returns true if user has some items in shop with specified filter.
   */
  function checkShopItemsWithFilter(filter, checkTab = itemsTab.SHOP)
  {
    local customEnv = {
      filter = filter
      curTab = checkTab
    }
    local items = []
    if (checkTab == itemsTab.INVENTORY)
      items = ::ItemsManager.getInventoryList(filter.typeMask, filterFunc.bindenv(customEnv))
    else if (checkTab == itemsTab.SHOP)
      items = ::ItemsManager.getShopList(filter.typeMask, filterFunc.bindenv(customEnv))
    return items.len() > 0
  }

  function fillPage()
  {
    widgetByItem = {}
    local view = { items = [] }
    local pageStartIndex = curPage * itemsPerPage
    local pageEndIndex = min((curPage + 1) * itemsPerPage, itemsList.len())
    for(local i=pageStartIndex; i < pageEndIndex; i++)
    {
      local item = itemsList[i]
      if (item.hasLimits())
        ::g_item_limits.enqueueItem(item.id)
      local hasWidget = item.isInventoryItem || item.canBuy
      view.items.append(item.getViewData({
        itemIndex = i.tostring(),
        showSellAmount = curTab == itemsTab.SHOP,
        newIconWidget = hasWidget ? NewIconWidget.createLayout() : null
        isItemLocked = isItemLocked(item)
      }))
    }
    ::g_item_limits.requestLimits()

    local listObj = getItemsListObj()
    local data = ::handyman.renderCached(("gui/items/item"), view)
    if (::checkObj(listObj))
    {
      listObj.show(data != "")
      listObj.enable(data != "")
      guiScene.replaceContentFromText(listObj, data, data.len(), this)
      for (local i = pageStartIndex; i < pageEndIndex; ++i)
      {
        local item = itemsList[i]
        local itemObj = listObj.getChild(i - pageStartIndex)
        if (!::check_obj(itemObj))
        {
          local itemViewData = item.getViewData({
            itemIndex = i.tostring(),
            showSellAmount = curTab == itemsTab.SHOP,
            isItemLocked = isItemLocked(item)
          })
          local itemsListText = ::toString(::u.map(itemsList, @(it) it.id))
          local msg = "Error: failed to load items list:\nitemViewData =\n" + ::toString(itemViewData) + "\nfullList = \n" + itemsListText
          ::script_net_assert_once("failed to load items list", msg)
          continue
        }

        local newIconWidgetObj = itemObj.findObject("item_new_icon_widget")
        if (::checkObj(newIconWidgetObj))
        {
          local newIconWidget = NewIconWidget(guiScene, newIconWidgetObj)
          widgetByItem[item] <- newIconWidget
          newIconWidget.setWidgetVisible(::ItemsManager.isItemUnseen(item))
        }
      }
    }

    local emptyListObj = scene.findObject("empty_items_list")
    if (::checkObj(emptyListObj))
    {
      local adviseShop = ::has_feature("ItemsShop") && curTab != itemsTab.SHOP
      if (adviseShop)
        foreach (t in _types)
          if (compareFilters(filter, t))
          {
            adviseShop = checkItemTab(t, itemsTab.SHOP)
            break
          }

      emptyListObj.show(data.len() == 0)
      emptyListObj.enable(data.len() == 0)
      showSceneBtn("items_shop_to_shop_button", adviseShop)
      local emptyListTextObj = scene.findObject("empty_items_list_text")
      if (::checkObj(emptyListTextObj))
      {
        local emptyTabLocId = ::getTblValue("emptyTabLocId", filter, "")
        local caption = ::loc(emptyTabLocId, ::loc(_defaultFilter.emptyTabLocId, ""))
        if (caption.len() > 0)
        {
          local noItemsAdviceLocId = adviseShop
            ? "items/shop/emptyTab/noItemsAdvice/shopEnabled"
            : "items/shop/emptyTab/noItemsAdvice/shopDisabled"
          caption += " " + ::loc(noItemsAdviceLocId)
        }
        emptyListTextObj.setValue(caption)
      }
    }

    local prevValue = listObj.getValue()
    local value = findLastValue(prevValue)
    if (value >= 0)
      listObj.setValue(value)

    updateItemInfo()

    generatePaginator(scene.findObject("paginator_place"), this,
      curPage, ceil(itemsList.len().tofloat() / itemsPerPage) - 1, null, true /*show last page*/)

    if (!itemsList.len())
      focusFilters()
  }

  function isItemLocked(item)
  {
    return false
  }

  function isLastItemSame(item)
  {
    if (!_lastItem || _lastItem.id != item.id)
      return false
    if (!_lastItem.uids || !item.uids)
      return true
    foreach(uid in _lastItem.uids)
      if (::isInArray(uid, item.uids))
        return true
    return false
  }

  function findLastValue(prevValue)
  {
    local offset = curPage * itemsPerPage
    local total = ::min(itemsList.len() - offset, itemsPerPage)
    if (!total)
      return -1

    for(local i = 0; i < total; i++)
      if (isLastItemSame(itemsList[offset + i]))
        return i
    return ::max(0, ::min(total - 1, prevValue))
  }

  function onEventInventoryUpdate(p)
  {
    updateTabNewIconWidgets()
    if (curTab == itemsTab.INVENTORY)
    {
      itemsListValid = false
      applyFilters(false)
    }
  }

  function onEventUnitBought(params)
  {
    updateItemInfo()
  }

  function onEventUnitRented(params)
  {
    updateItemInfo()
  }

  function getCurItem()
  {
    local value = getItemsListObj().getValue() + curPage * itemsPerPage
    _lastItem = ::getTblValue(value, itemsList)
    return _lastItem
  }

  function getCurItemObj()
  {
    local itemListObj = getItemsListObj()
    local value = itemListObj.getValue()
    if (value < 0)
      return null
    return itemListObj.getChild(value)
  }

  function goToPage(obj)
  {
    markCurrentPageSeen()
    curPage = obj.to_page.tointeger()
    fillPage()
  }

  function updateItemInfo()
  {
    markItemSeen(getCurItem()) // Then and only then tabs update is required.
    ::ItemsManager.fillItemDescr(getCurItem(), scene.findObject("item_info"), this, true, true)
    updateButtons()
  }

  function markItemSeen(item)
  {
    if (item == null)
      return
    local result = ::ItemsManager.markItemSeen(item)
    local widget = ::getTblValue(item, widgetByItem, null)
    if (widget != null)
      widget.setWidgetVisible(false)
    if (result)
    {
      updateFilterNewIconWidgets()
      updateTabNewIconWidgets()
      ::ItemsManager.updateGamercardIcons(item.isInventoryItem)
    }
    ::ItemsManager.saveSeenItemsData(item.isInventoryItem)
  }

  function markCurrentPageSeen()
  {
    if (itemsList == null)
      return
    local pageStartIndex = curPage * itemsPerPage
    local pageEndIndex = min((curPage + 1) * itemsPerPage, itemsList.len())
    local result = false
    for(local i = pageStartIndex; i < pageEndIndex; ++i)
    {
      local item = itemsList[i]
      result = ::ItemsManager.markItemSeen(item) || result
      local widget = ::getTblValue(item, widgetByItem, null)
      if (widget != null)
        widget.setWidgetVisible(false)
    }
    if (result)
    {
      updateFilterNewIconWidgets()
      updateTabNewIconWidgets()
      ::ItemsManager.updateGamercardIcons(curTab == itemsTab.INVENTORY)
    }
    ::ItemsManager.saveSeenItemsData(curTab == itemsTab.INVENTORY)
  }

  function updateButtons()
  {
    local item = getCurItem()
    local mainActionName = item ? item.getMainActionName() : ""
    local limitsCheckData = item ? item.getLimitsCheckData() : null
    local limitsCheckResult = ::getTblValue("result", limitsCheckData, true)
    local showMainAction = mainActionName != "" && limitsCheckResult
    local buttonObj = showSceneBtn("btn_main_action", showMainAction)
    if (showMainAction)
    {
      buttonObj.visualStyle = curTab == itemsTab.INVENTORY? "secondary" : "purchase"
      ::setDoubleTextToButton(scene, "btn_main_action", item.getMainActionName(false), mainActionName)
    }

    local warningText = ""
    if (!limitsCheckResult && item && !item.isInventoryItem)
      warningText = limitsCheckData.reason
    setWarningText(warningText)
    showSceneBtn("btn_link_action", item && item.link.len() && ::has_feature("AllowExternalLink"))
  }

  function onLinkAction(obj)
  {
    local item = getCurItem()
    local link = ::g_url.validateLink(item.link)
    if (!link)
      return

    ::open_url(link, item.forceExternalBrowser, false, "item_shop")
   }

  function onItemAction(buttonObj)
  {
    local id = buttonObj && buttonObj.holderId
    local item = ::getTblValue(id.tointeger(), itemsList)
    local obj = scene.findObject("shop_item_" + id)
    doMainAction(item, obj)
  }

  function onMainAction(obj)
  {
    doMainAction()
  }

  function doMainAction(item = null, obj = null)
  {
    item = item || getCurItem()
    obj = obj || getCurItemObj()
    if (item != null)
    {
      item.doMainAction(function(result) { this && onMainActionComplete(result) }.bindenv(this),
                        this,
                        { obj = obj })
      markItemSeen(item)
    }
  }

  function onMainActionComplete(result)
  {
    if (!::checkObj(scene))
      return false
    if (result.success)
      updateItemInfo()
    return result.success
  }

  function onUnitHover(obj)
  {
    openUnitActionsList(obj, true, true)
  }

  function onTimer(obj, dt)
  {
    local startIdx = curPage * itemsPerPage
    local lastIdx = min((curPage + 1) * itemsPerPage, itemsList.len())
    for(local i=startIdx; i < lastIdx; i++)
    {
      if (!itemsList[i].hasTimer())
        continue
      local listObj = ::checkObj(scene) && getItemsListObj()
      local itemObj = ::checkObj(listObj) && listObj.getChild(i - curPage * itemsPerPage)
      local timeTxtObj = ::checkObj(itemObj) && itemObj.findObject("expire_time")
      if (::checkObj(timeTxtObj))
        timeTxtObj.setValue(itemsList[i].getTimeLeftText())
    }
  }

  function onToShopButton(obj)
  {
    curTab = itemsTab.SHOP
    fillTabs()
  }

  function goBack()
  {
    markCurrentPageSeen()
    base.goBack()
  }

  function getItemsListObj()
  {
    return scene.findObject("items_list")
  }

  function getTabsListObj()
  {
    return scene.findObject("tabs_list")
  }

  function getItemTypeFilterObj()
  {
    return scene.findObject("item_type_filter")
  }

  /**
   * Returns all the data required to restore current window state:
   * filter tab, items tab, current page, selected item, etc...
   */
  function getHandlerRestoreData()
  {
    local data = {
      openData = {
        curTab = curTab
        filter = filter
      }
      stateData = {
        currentItemId = ::getTblValue("id", getCurItem(), null)
      }
    }
    return data
  }

  /**
   * Returns -1 if item was not found.
   */
  function getItemIndexById(itemId)
  {
    foreach (itemIndex, item in itemsList)
    {
      if (item.id == itemId)
        return itemIndex
    }
    return -1
  }

  function restoreHandler(stateData)
  {
    local itemIndex = getItemIndexById(stateData.currentItemId)
    if (itemIndex == -1)
      return
    curPage = ::ceil(itemIndex / itemsPerPage).tointeger()
    fillPage()
    getItemsListObj().setValue(itemIndex % itemsPerPage)
  }

  function onEventShowroomOpened(params)
  {
    ::handlersManager.requestHandlerRestore(this, ::gui_handlers.MainMenu)
  }

  function onEventMissionBuilderApplied(params)
  {
    ::handlersManager.requestHandlerRestore(this, ::gui_handlers.MainMenu)
  }

  function onEventItemLimitsUpdated(params)
  {
    updateItemInfo()
  }

  function setWarningText(text)
  {
    local warningTextObj = scene.findObject("warning_text")
    if (::checkObj(warningTextObj))
      warningTextObj.setValue(::colorize("redMenuButtonColor", text))
  }
}
