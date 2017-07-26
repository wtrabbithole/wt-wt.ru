class ::gui_handlers.WarbondsShop extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/items/itemsShop.blk"

  filterFunc = null

  wbList = null
  curWb = null
  curPage = 0
  curPageAwards = null
  itemsPerPage = 1

  slotbarActions = [ "showroom", "testflight", "weapons", "rankinfo", "info" ]

  function initScreen()
  {
    wbList = ::g_warbonds.getVisibleList(filterFunc)
    if (!wbList.len())
      return goBack()

    curPageAwards = []

    initItemsListSize()
    fillTabs()
    updateBalance()

    scene.findObject("update_timer").setUserData(this)
  }

  function fillTabs()
  {
    local view = {
      tabs = []
    }
    foreach(i, wb in wbList)
      view.tabs.append({
        id = getTabId(i)
        navImagesText = ::get_navigation_images_text(i, wbList.len())
      })

    local data = ::handyman.renderCached("gui/frameHeaderTabs", view)
    local tabsObj = getTabsListObj()
    guiScene.replaceContentFromText(tabsObj, data, data.len(), this)
    tabsObj.setValue(0)

    updateTabsTexts()
    onTabChange(tabsObj)
  }

  function getTabId(idx)
  {
    return "warbond_tab_" + idx
  }

  function getTabsListObj()
  {
    return scene.findObject("tabs_list")
  }

  function getItemsListObj()
  {
    return scene.findObject("items_list")
  }

  function onTabChange(obj)
  {
    if (!obj || !wbList.len())
      return

    local value = obj.getValue()
    curWb = ::getTblValue(value, wbList, wbList[0])
    curPage = 0
    fillPage()
    updateBalance()
    updateTabsTexts() //to reccount tabs textarea colors
  }

  function initItemsListSize()
  {
    guiScene.applyPendingChanges(false)
    local sizes = ::g_dagui_utils.adjustWindowSize(scene.findObject("wnd_items_shop"), getItemsListObj(),
                                                   "@itemWidth", "@itemHeight", "@itemSpacing", "@itemSpacing")
    itemsPerPage = sizes.itemsCountX * sizes.itemsCountY
  }

  function updateCurPageAwardsList()
  {
    curPageAwards.clear()
    if (!curWb)
      return

    local fullList = curWb.getAwardsList()
    local pageStartIndex = curPage * itemsPerPage
    local pageEndIndex = min((curPage + 1) * itemsPerPage, fullList.len())
    for(local i=pageStartIndex; i < pageEndIndex; i++)
      curPageAwards.append(fullList[i])
  }

  function fillPage()
  {
    updateCurPageAwardsList()

    local view = {
      items = curPageAwards
      enableBackground = true
      hasButton = true
    }

    local listObj = getItemsListObj()
    local data = ::handyman.renderCached(("gui/items/item"), view)
    listObj.enable(data != "")
    guiScene.replaceContentFromText(listObj, data, data.len(), this)

    local value = listObj.getValue()
    local total = curPageAwards.len()
    if (total && value >= total)
      listObj.setValue(total - 1)
    listObj.select()

    updateItemInfo()

    updatePaginator()
  }

  function updatePaginator()
  {
    local totalPages = curWb ? ceil(curWb.getAwardsList().len().tofloat() / itemsPerPage) : 1
    ::generatePaginator(scene.findObject("paginator_place"), this,
      curPage, totalPages - 1, null, true /*show last page*/)
  }

  function goToPage(obj)
  {
    curPage = obj.to_page.tointeger()
    fillPage()
  }

  function getCurAward()
  {
    local value = getItemsListObj().getValue()
    return ::getTblValue(value, curPageAwards)
  }

  function fillItemDesc(award)
  {
    local obj = scene.findObject("item_info")
    local hasItemDesc = award != null && award.fillItemDesc(obj, this)
    obj.show(hasItemDesc)
  }

  function fillCommonDesc(award)
  {
    local obj = scene.findObject("common_info")
    local hasCommonDesc = award != null && award.hasCommonDesc()
    obj.show(hasCommonDesc)
    if (!hasCommonDesc)
      return

    obj.findObject("info_name").setValue(award.getNameText())
    obj.findObject("info_desc").setValue(award.getDescText())

    local imageData = award.getDescriptionImage()
    guiScene.replaceContentFromText(obj.findObject("info_icon"), imageData, imageData.len(), this)
  }

  function updateItemInfo()
  {
    local award = getCurAward()
    fillItemDesc(award)
    fillCommonDesc(award)
    updateButtons()
  }

  function updateButtons()
  {
    local award = getCurAward()
    local mainActionBtn = showSceneBtn("btn_main_action", award != null)
    if (award)
    {
      mainActionBtn.visualStyle = "purchase"
      mainActionBtn.inactiveColor = award.canBuy() ? "no" : "yes"
      ::set_double_text_to_button(scene, "btn_main_action", award.getBuyText(false))
    }
  }

  function updateBalance()
  {
    local text = ""
    if (curWb)
      text = ::loc("warbonds/currentAmount", { warbonds = ::colorize("activeTextColor", curWb.getBalanceText()) })
    scene.findObject("balance_text").setValue(text)
  }

  function updateAwardPrices()
  {
    local listObj = getItemsListObj()
    local total = ::min(listObj.childrenCount(), curPageAwards.len())
    for(local i = 0; i < total; i++)
    {
      local childObj = listObj.getChild(i)
      local priceObj = childObj.findObject("price")
      if (!::checkObj(priceObj)) //price obj always exist in item. so it check that childObj valid
        continue

      priceObj.setValue(curPageAwards[i].getCostText())

      local isAllBought = curPageAwards[i].isAllBought()
      local iconObj = childObj.findObject("all_bougt_icon")
      if (::checkObj(iconObj))
      {
        iconObj.show(isAllBought)
        priceObj.show(!isAllBought)
      }

      local btnObj = childObj.findObject("actionBtn")
      if (isAllBought && ::checkObj(btnObj))
        guiScene.destroyElement(btnObj)
    }
  }

  function updateTabsTexts()
  {
    local tabsObj = getTabsListObj()
    foreach(idx, wb in wbList)
    {
      local id = getTabId(idx) + "_text"
      local obj = tabsObj.findObject(id)
      if (!::checkObj(obj))
        continue

      local tabName = ::loc(wb.fontIcon)
      local timeText = ""
      local timeLeft = wb.getChangeStateTimeLeft()
      if (timeLeft > 0)
      {
        timeText = ::hoursToString(timeLeft.tofloat() / TIME_HOUR_IN_SECONDS, false, true)
        timeText = " " + ::loc("ui/parentheses", { text = timeText })
      }
      obj.setValue(tabName + timeText)
    }
  }

  function onTimer(obj, dt)
  {
    updateTabsTexts()
  }

  function onItemAction(buttonObj)
  {
    local fullAwardId = buttonObj && buttonObj.holderId
    if (!fullAwardId)
      return
    local wbAward = ::g_warbonds.getWarbondAwardByFullId(fullAwardId)
    if (wbAward)
      buyAward(wbAward)
  }

  function onMainAction(obj)
  {
    buyAward()
  }

  function buyAward(wbAward = null)
  {
    if (!wbAward)
      wbAward = getCurAward()
    if (wbAward)
      wbAward.buy()
  }

  function onEventWarbondAwardBought(p)
  {
    guiScene.setUpdatesEnabled(false, false)
    updateBalance()
    updateAwardPrices()
    updateItemInfo()
    guiScene.setUpdatesEnabled(true, true)
  }

  //dependence by blk
  function onToShopButton() {}
  function onLinkAction(obj) {}

  function onUnitHover(obj)
  {
    openUnitActionsList(obj, true, true)
  }
}
