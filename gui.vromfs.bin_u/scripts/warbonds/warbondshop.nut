local time = require("scripts/time.nut")


class ::gui_handlers.WarbondsShop extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/items/itemsShop.blk"

  filterFunc = null

  wbList = null
  curWbIdx = 0
  curWb = null
  curPage = 0
  curPageAwards = null
  itemsPerPage = 1

  widgetByAward = {}
  widgetByTab = {}

  slotbarActions = [ "preview", "testflight", "weapons", "info" ]

  function initScreen()
  {
    wbList = ::g_warbonds.getList(filterFunc)
    if (!wbList.len())
      return goBack()

    scene.findObject("filter_block").show(false)
    curPageAwards = []
    if (!(curWbIdx in wbList))
      curWbIdx = 0
    curWb = wbList[curWbIdx]

    local obj = scene.findObject("warbond_shop_progress_block")
    if (::check_obj(obj))
      obj.show(true)

    initItemsListSize()
    fillTabs()
    updateBalance()

    scene.findObject("update_timer").setUserData(this)
  }

  function fillTabs()
  {
    local view = { tabs = [] }
    foreach(i, wb in wbList)
      view.tabs.append({
        id = getTabId(i)
        object = wb.haveAnyOrdinaryRequirements()? ::g_warbonds_view.getCurrentLevelItemMarkUp(wb) : null
        navImagesText = ::get_navigation_images_text(i, wbList.len())
        newIconWidget = ::NewIconWidget.createLayout({ needContainer = false })
      })

    local data = ::handyman.renderCached("gui/frameHeaderTabs", view)
    local tabsObj = getTabsListObj()
    guiScene.replaceContentFromText(tabsObj, data, data.len(), this)

    widgetByTab = {}
    foreach(i, wb in wbList)
    {
      local tabObj = tabsObj.getChild(i)
      local newIconWidgetObj = tabObj.findObject("tab_new_icon_widget")
      if (::checkObj(newIconWidgetObj))
        widgetByTab[i] <- ::NewIconWidget(guiScene, newIconWidgetObj)
    }

    tabsObj.setValue(0)
    updateTabsTexts()
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

    markCurrentPageSeen()

    local i = obj.getValue()
    curWbIdx = (i in wbList) ? i : 0
    curWb = wbList[curWbIdx]
    curPage = 0
    initItemsProgress()
    fillPage()
    updateBalance()
    updateTabsTexts() //to reccount tabs textarea colors
    updateTabNewIconWidgets()
  }

  function updateTabNewIconWidgets()
  {
    foreach(i, wb in wbList)
    {
      local widget = ::getTblValue(i, widgetByTab, null)
      if (widget)
        widget.setValue(::g_warbonds.getNumUnseenAwards(wb))
    }
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
    widgetByAward = {}
    updateCurPageAwardsList()

    local view = {
      items = curPageAwards
      enableBackground = true
      hasButton = true
      newIconWidget = ::NewIconWidget.createLayout({ needContainer = false })
    }

    local listObj = getItemsListObj()
    local data = ::handyman.renderCached(("gui/items/item"), view)
    listObj.enable(data != "")
    guiScene.replaceContentFromText(listObj, data, data.len(), this)

    foreach (idx, award in curPageAwards)
    {
      local itemObj = listObj.getChild(idx)
      local newIconWidgetObj = itemObj.findObject("item_new_icon_widget")
      if (::checkObj(newIconWidgetObj))
      {
        local newIconWidget = ::NewIconWidget(guiScene, newIconWidgetObj)
        widgetByAward[award] <- newIconWidget
        newIconWidget.setWidgetVisible(::g_warbonds.isAwardUnseen(award, curWb))
      }
    }

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
    markCurrentPageSeen()
    goToPageIdx(obj.to_page.tointeger())
  }

  function goToPageIdx(idx)
  {
    curPage = idx
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
    markAwardSeen(award)
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
    local tooltip = ""
    if (curWb)
    {
      text = ::loc("warbonds/currentAmount", { warbonds = curWb.getBalanceText() })
      tooltip = ::loc("warbonds/maxAmount", { warbonds = ::g_warbonds.getLimit() })
    }
    local textObj = scene.findObject("balance_text")
    textObj.setValue(text)
    textObj.tooltip = tooltip
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

      local timeText = ""
      local timeLeft = wb.getChangeStateTimeLeft()
      if (timeLeft > 0)
      {
        timeText = time.hoursToString(time.secondsToHours(timeLeft), false, true)
        timeText = " " + ::loc("ui/parentheses", { text = timeText })
      }
      obj.setValue(timeText)
    }
  }

  function onTimer(obj, dt)
  {
    updateTabsTexts()
  }

  function initItemsProgress()
  {
    local showAnyShopProgress = ::g_warbonds_view.showOrdinaryProgress(curWb)
    local progressPlaceObj = scene.findObject("shop_level_progress_place")
    progressPlaceObj.show(showAnyShopProgress)

    local isShopInactive = !curWb || !curWb.isCurrent()
    if (showAnyShopProgress)
    {
      local oldShopObj = progressPlaceObj.findObject("old_shop_progress_place")
      oldShopObj.show(isShopInactive)

      ::g_warbonds_view.createProgressBox(curWb, progressPlaceObj, this, isShopInactive)
      if (isShopInactive)
      {
        local data = ::g_warbonds_view.getCurrentLevelItemMarkUp(curWb)
        guiScene.replaceContentFromText(oldShopObj.findObject("level_icon"), data, data.len(), this)
      }
    }

    local showAnyMedalProgress = ::g_warbonds_view.showSpecialProgress(curWb)
    local medalsPlaceObj = scene.findObject("special_tasks_progress_block")
    medalsPlaceObj.show(showAnyMedalProgress)
    if (showAnyMedalProgress)
    {
      ::g_warbonds_view.createSpecialMedalsProgress(curWb, medalsPlaceObj, this)
      scene.findObject("medals_block").tooltip = ::g_warbonds_view.getSpecialMedalsTooltip(curWb)
    }
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

  function markAwardSeen(award)
  {
    if (award == null)
      return

    local result = ::g_warbonds.markAwardsSeen(award, curWb)
    local widget = ::getTblValue(award, widgetByAward)
    if (widget)
      widget.setWidgetVisible(false)

    if (result)
      updateTabNewIconWidgets()
  }

  function markCurrentPageSeen()
  {
    if (curPageAwards == null || curWb == null)
      return

    local result = ::g_warbonds.markAwardsSeen(curPageAwards, curWb)
    foreach (idx, award in curPageAwards)
    {
      local widget = ::getTblValue(award, widgetByAward)
      if (widget)
        widget.setWidgetVisible(false)
    }

    if (result)
      updateTabNewIconWidgets()
  }

  function onEventWarbondAwardBought(p)
  {
    guiScene.setUpdatesEnabled(false, false)
    updateBalance()
    updateAwardPrices()
    updateItemInfo()
    guiScene.setUpdatesEnabled(true, true)
  }

  function onEventBattleTasksFinishedUpdate(p)
  {
    updateItemInfo()
  }

  function onEventItemsShopUpdate(p)
  {
    doWhenActiveOnce("fillPage")
  }

  function onDestroy()
  {
    markCurrentPageSeen()
    local activeWb = ::g_warbonds.getCurrentWarbond()
    if (activeWb)
      activeWb.markSeenLastResearchShopLevel()
  }

  function onEventBeforeStartShowroom(params)
  {
    ::handlersManager.requestHandlerRestore(this, ::gui_handlers.MainMenu)
  }

  function onEventBeforeStartTestFlight(params)
  {
    ::handlersManager.requestHandlerRestore(this, ::gui_handlers.MainMenu)
  }

  function getHandlerRestoreData()
  {
    return {
      openData = {
        filterFunc = filterFunc
        curWbIdx   = curWbIdx
      }
      stateData = {
        curAwardId = getCurAward()?.id
      }
    }
  }

  function restoreHandler(stateData)
  {
    local fullList = curWb.getAwardsList()
    foreach (i, v in fullList)
      if (v.id == stateData.curAwardId)
      {
        goToPageIdx(::ceil(i / itemsPerPage).tointeger())
        getItemsListObj().setValue(i % itemsPerPage)
        break
      }
  }

  function onDescAction(obj)
  {
    local data = ::check_obj(obj) && obj.actionData && ::parse_json(obj.actionData)
    local item = ::ItemsManager.findItemById(data?.itemId)
    local action = data?.action
    if (item && action && (action in item) && ::u.isFunction(item[action]))
      item[action]()
  }

  //dependence by blk
  function onToShopButton(obj) {}
  function onToMarketplaceButton(obj) {}
  function onItemPreview(obj) {}
  function onLinkAction(obj) {}
  function onAltAction(obj) {}

  function onUnitHover(obj)
  {
    openUnitActionsList(obj, true, true)
  }
}
