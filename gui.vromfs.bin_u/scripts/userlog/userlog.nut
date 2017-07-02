::hidden_userlogs <- [
  ::EULT_NEW_STREAK,
  ::EULT_SESSION_START
]

::popup_userlogs <- [
  ::EULT_SESSION_RESULT
  {
    type = ::EULT_CHARD_AWARD
    rewardType = [
      "WagerWin"
      "WagerFail"
      "WagerStageWin"
      "WagerStageFail"
    ]
  }
  ::EULT_EXCHANGE_WARBONDS
]

::userlog_pages <- [
  {
    id="all"
    hide = ::hidden_userlogs
  }
  {
    id="battle"
    show = [::EULT_EARLY_SESSION_LEAVE, ::EULT_SESSION_RESULT,
            ::EULT_AWARD_FOR_PVE_MODE]
  }
  {
    id="economic"
    show = [::EULT_BUYING_AIRCRAFT, ::EULT_REPAIR_AIRCRAFT, ::EULT_REPAIR_AIRCRAFT_MULTI,
            ::EULT_BUYING_WEAPON, ::EULT_BUYING_WEAPONS_MULTI, ::EULT_BUYING_WEAPON_FAIL,
            ::EULT_SESSION_RESULT, ::EULT_BUYING_MODIFICATION, ::EULT_BUYING_SPARE_AIRCRAFT,
            ::EULT_BUYING_UNLOCK, ::EULT_BUYING_RESOURCE,
            ::EULT_CHARD_AWARD, ::EULT_ADMIN_ADD_GOLD,
            ::EULT_ADMIN_REVERT_GOLD, ::EULT_BUYING_SCHEME, ::EULT_OPEN_ALL_IN_TIER,
            ::EULT_BUYING_MODIFICATION_MULTI, ::EULT_BUYING_MODIFICATION_FAIL, ::EULT_BUY_ITEM,
            ::EULT_BUY_BATTLE, ::EULT_CONVERT_EXPERIENCE, ::EULT_SELL_BLUEPRINT,
            ::EULT_EXCHANGE_WARBONDS, ::EULT_CLAN_ACTION,
            ::EULT_BUYENTITLEMENT, ::EULT_OPEN_TROPHY]
    checkFunc = function(userlogBlk)
    {
      local body = userlogBlk.body
      if (!body)
        return true

      local logType = userlogBlk.type
      if (logType == ::EULT_CLAN_ACTION
          || logType == ::EULT_BUYING_UNLOCK
          || logType == ::EULT_BUYING_RESOURCE)
        return ::getTblValue("goldCost", body, 0) > 0 || ::getTblValue("wpCost", body, 0) > 0

      if (logType == ::EULT_BUYENTITLEMENT)
        return ::getTblValue("cost", body, 0) > 0

      if (logType == ::EULT_OPEN_TROPHY)
        return ::getTblValue("gold", body, 0) > 0 || ::getTblValue("warpoints", body, 0) > 0

      return true
    }
  }
  {
    id="achivements"
    show = [::EULT_NEW_RANK, ::EULT_NEW_UNLOCK, ::EULT_CHARD_AWARD]
    checkFunc = function(userlog) { return !::g_battle_tasks.isUserlogForBattleTasksGroup(userlog.body) }
  }
  {
    id="battletasks"
    reqFeature = "BattleTasks"
    show = [::EULT_PUNLOCK_ACCEPT, ::EULT_PUNLOCK_CANCELED, ::EULT_PUNLOCK_REROLL_PROPOSAL,
            ::EULT_PUNLOCK_EXPIRED, ::EULT_PUNLOCK_NEW_PROPOSAL, ::EULT_NEW_UNLOCK, EULT_PUNLOCK_ACCEPT_MULTI]
    unlocks = [::UNLOCKABLE_ACHIEVEMENT, ::UNLOCKABLE_TROPHY, ::UNLOCKABLE_WARBOND]
    checkFunc = function(userlog) { return ::g_battle_tasks.isUserlogForBattleTasksGroup(userlog.body) }
  }
  {
    id="crew"
    show = [::EULT_BUYING_SLOT, ::EULT_TRAINING_AIRCRAFT, ::EULT_UPGRADING_CREW,
            ::EULT_SPECIALIZING_CREW, ::EULT_PURCHASINGSKILLPOINTS]
  }
  {
    id = "items"
    reqFeature = "Items"
    show = [::EULT_BUY_ITEM, ::EULT_OPEN_TROPHY, ::EULT_NEW_ITEM, ::EULT_NEW_UNLOCK
            ::EULT_ACTIVATE_ITEM, ::EULT_REMOVE_ITEM, ::EULT_TICKETS_REMINDER, ::EULT_CONVERT_BLUEPRINTS]
    unlocks = [::UNLOCKABLE_TROPHY]
  }
  {
    id="onlineShop"
    show = [::EULT_BUYENTITLEMENT, ::EULT_BUYING_UNLOCK]
  }
  {
    id="worldWar"
    show = [::EULT_WW_START_OPERATION, ::EULT_WW_CREATE_OPERATION, ::EULT_WW_END_OPERATION]
  }
]

function save_online_job()
{
  return ::save_online_single_job(223) //super secure digit for job tag :)
}

function gui_modal_userLog()
{
  ::gui_start_modal_wnd(::gui_handlers.UserLogHandler)
}

class ::gui_handlers.UserLogHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  function initScreen()
  {
    if (!::checkObj(scene))
      return goBack()

    listObj = scene.findObject("items_list")

    fillTabs()

    scene.findObject("btn_refresh").show(true)
  }

  function fillTabs()
  {
    mainOptionsMode = ::get_gui_options_mode()
    ::set_gui_options_mode(::OPTIONS_MODE_SEARCH)
    local value = ::get_gui_option(::USEROPT_USERLOG_FILTER)
    local curIdx = (value in ::userlog_pages)? value : 0

    local view = {
      tabs = []
    }
    foreach(idx, page in ::userlog_pages)
    {
      if (::getTblValue("reqFeature", page) && !::has_feature(page.reqFeature))
        continue
      view.tabs.push({
        id = "page_" + idx
        cornerImg = "#ui/gameuiskin#new_icon"
        cornerImgId = "img_new_" + page.id
        cornerImgSmall = true
        tabName = "#userlog/page/" + page.id
        navImagesText = ::get_navigation_images_text(idx, ::userlog_pages.len())
      })
    }
    local data = ::handyman.renderCached("gui/frameHeaderTabs", view)
    local tabsObj = scene.findObject("tabs_list")
    guiScene.replaceContentFromText(tabsObj, data, data.len(), this)
    updateTabNewIconWidgets()

    tabsObj.setValue(curIdx)
    onChangePage(tabsObj)
  }

  function getNewMessagesByPages()
  {
    local res = array(::userlog_pages.len(), 0)
    local total = ::get_user_logs_count()
    for(local i=0; i<total; i++)
    {
      local blk = ::DataBlock()
      ::get_user_log_blk_body(i, blk)

      if (blk.disabled) // was seen
        continue

      foreach(idx, page in ::userlog_pages)
        if (::isUserlogVisible(blk, page, i))
          res[idx]++
    }
    return res
  }

  function initPage(page)
  {
    if (!page) return
    curPage = page

    logs = getUserLogsList(curPage);
    guiScene.replaceContentFromText(listObj, "", 0, this)
    nextLogId = 0
    haveNext = false
    addLogsPage()
    if (selectedIndex < listObj.childrenCount())
      listObj.setValue(selectedIndex);
    listObj.select()

    local msgObj = scene.findObject("middle_message")
    msgObj.show(logs.len()==0)
    if (logs.len()==0)
      msgObj.setValue(::loc("userlog/noMessages"))
  }

  function addLogsPage()
  {
    if (nextLogId>=logs.len())
      return

    guiScene.setUpdatesEnabled(false, false)
    local showTo = (nextLogId+logsPerPage < logs.len())? nextLogId+logsPerPage : logs.len()

    local data=""
    for(local i=nextLogId; i<showTo; i++)
      if (i!=nextLogId || !haveNext)
      {
        local rowName = "row"+logs[i].idx
        data += format("expandable { id:t='%s' } ", rowName)
      }
    guiScene.appendWithBlk(listObj, data, this)

    for(local i=nextLogId; i<showTo; i++)
      fillLog(logs[i])
    nextLogId=showTo

    haveNext = nextLogId<logs.len()
    if (haveNext)
      addNextButton(logs[nextLogId])

    guiScene.setUpdatesEnabled(true, true)
  }

  function fillLog(log)
  {
    local rowName = "row"+log.idx
    local rowObj = listObj.findObject(rowName)
    guiScene.replaceContent(rowObj, "gui/userLogRow.blk", this)

    local rowData = ::get_userlog_view_data(log)

    if (::getTblValue("descriptionBlk", rowData, "") != "")
    {
      guiScene.appendWithBlk(rowObj.findObject("hiddenDiv"), rowData.descriptionBlk, this)
    }
    else
    {
      guiScene.destroyElement(rowObj.findObject("hiddenDiv"))
      guiScene.destroyElement(rowObj.findObject("expandImg"))
    }

    //fillData
    foreach(name, value in rowData)
    {
      local obj = rowObj.findObject(name)
      if (!::checkObj(obj))
        continue

      if (typeof(value)=="table")
        foreach(name, result in value)
          obj[name] = result
      else
        obj.setValue(value)
    }
    rowObj.tooltip = ::tooltipColorTheme(rowData.tooltip)
    if (log.enabled)
      rowObj.status="owned"
    if (rowData.logImg)
      rowObj.findObject("log_image")["background-image"] = rowData.logImg
    if (rowData.logImg2)
      rowObj.findObject("log_image2")["background-image"] = rowData.logImg2
  }

  function addNextButton(log)
  {
    local rowName = "row"+log.idx
    local rowObj = listObj.findObject(rowName)
    if (!rowObj)
    {
      local data = format("expandable { id:t='%s' } ", rowName)
      guiScene.appendWithBlk(listObj, data, this)
      rowObj = listObj.findObject(rowName)
    }
    guiScene.replaceContent(rowObj, "gui/userLogRow.blk", this)
    rowObj.findObject("middle").setValue(::loc("userlog/showMore"))
  }

  function saveOnlineJobWithUpdate()
  {
    taskId = ::save_online_job()
    dagor.debug("saveOnlineJobWithUpdate")
    if (taskId >= 0)
    {
      ::set_char_cb(this, slotOpCb)
      afterSlotOp = updateTabNewIconWidgets
    }
  }

  function markCurrentPageSeen()
  {
    local needSave = false
    if (logs)
      foreach(log in logs)
        if (log.enabled && log.idx >= 0 && log.idx < get_user_logs_count())
        {
          if (::disable_user_log_entry(log.idx))
            needSave = true
        }

    if (needSave)
      saveOnlineJobWithUpdate()
  }

  function markItemSeen(index)
  {
    local needSave = false

    local total = get_user_logs_count()
    local counter = 0
    for(local i=total-1; i>=0; i--)
    {
      local blk = ::DataBlock()
      ::get_user_log_blk_body(i, blk)
      if (!::isInArray(blk.type, ::hidden_userlogs))
      {
        if (index == counter && !blk.disabled)
        {
          if (::disable_user_log_entry(i))
          {
            needSave = true
            break;
          }
        }
        counter++
      }
    }

    if (needSave)
      saveOnlineJobWithUpdate()
  }

  function updateTabNewIconWidgets()
  {
    if (!::checkObj(scene))
      return

    local newMsgs = getNewMessagesByPages()
    foreach(idx, count in newMsgs)
    {
      local obj = scene.findObject("img_new_" + ::userlog_pages[idx].id)
      if (::checkObj(obj))
        obj.show(count > 0)
    }
    update_gamercards();
  }

  function goBack()
  {
    markCurrentPageSeen()

    ::g_tasker.restoreCharCallback()
    afterSlotOp = null;
    taskId = null

    restoreMainOptions()
    base.goBack()
  }

  function onUserLog(obj)
  {
    goBack()
  }

  function onItemSelect(obj)
  {
    if (obj)
    {
      local index = obj.getValue();
      if (index != selectedIndex && selectedIndex != -1)
      {
        markItemSeen(selectedIndex);
        if (selectedIndex < obj.childrenCount())
          obj.getChild(selectedIndex).status=""
      }
      selectedIndex = index;
    }
    if (obj && haveNext && obj.getValue() == (obj.childrenCount()-1))
    {
      addLogsPage()
      obj.getChild(obj.childrenCount()-1).scrollToView()
    }
  }

  function onChangePage(obj)
  {
    local value = obj.getValue()
    if (value < 0 || value > obj.childrenCount())
      return

    local idx = ::to_integer_safe(::getObjIdByPrefix(obj.getChild(value), "page_"), -1)
    local newPage = ::getTblValue(idx, ::userlog_pages)
    if (!newPage || newPage == curPage)
      return

    if (logs)
    {
      markCurrentPageSeen()
      updateTabNewIconWidgets()
    }
    initPage(newPage)
    ::set_gui_option(::USEROPT_USERLOG_FILTER, value)
    ::update_gamercards()
  }

  function onRefresh(obj)
  {
    if (logs)
    {
      markCurrentPageSeen()
      updateTabNewIconWidgets()
    }
    initPage(curPage)
    ::update_gamercards()
  }

  function onUnitHover(obj)
  {
    openUnitActionsList(obj, true, true)
  }

  scene = null
  wndType = handlerType.MODAL
  sceneBlkName = "gui/userlog.blk"

  logs = null
  listObj = null
  curPage = null

  nextLogId = 0
  logsPerPage = 10
  haveNext = false

  selectedIndex = 0

  slotbarActions = [ "take", "showroom", "testflight", "weapons", "rankinfo", "info" ]
}
