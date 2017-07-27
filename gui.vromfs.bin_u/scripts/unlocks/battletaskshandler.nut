function gui_start_battle_tasks_wnd(taskId = null)
{
  if (!::g_battle_tasks.isAvailableForUser())
    return ::showInfoMsgBox(::loc("msgbox/notAvailbleYet"))

  ::gui_start_modal_wnd(::gui_handlers.BattleTasksWnd, {currentTaskId = taskId})
}

enum BattleTasksWndTab {
  BATTLE_TASKS,
  BATTLE_TASKS_HARD,
  PERSONAL_UNLOCKS,
  HISTORY
}

class ::gui_handlers.BattleTasksWnd extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/modalSceneWithGamercard.blk"
  sceneTplName = "gui/unlocks/battleTasks"
  sceneTplDescriptionName = "gui/unlocks/battleTasksDescription"
  battleTaskItemTpl = "gui/unlocks/battleTasksItem"

  currentTasksArray = null
  personalUnlocksArray = null

  configsArrayByTabType = {
    [BattleTasksWndTab.BATTLE_TASKS] = null,
    [BattleTasksWndTab.BATTLE_TASKS_HARD] = null,
    [BattleTasksWndTab.PERSONAL_UNLOCKS] = null,
  }

  difficultiesByTabType = {
    [BattleTasksWndTab.BATTLE_TASKS] = (::has_feature("Warbonds_2_0")
      ? [::g_battle_task_difficulty.EASY, ::g_battle_task_difficulty.MEDIUM]
      : [::g_battle_task_difficulty.EASY, ::g_battle_task_difficulty.MEDIUM, ::g_battle_task_difficulty.HARD]),
    [BattleTasksWndTab.BATTLE_TASKS_HARD] = [::g_battle_task_difficulty.HARD]
  }

  newIconWidgetByTaskId = null

  finishedTaskIdx = -1
  usingDifficulties = null

  currentTaskId = null
  currentTabType = null

  userglogFinishedTasksFilter = {
    show = [::EULT_NEW_UNLOCK]
    checkFunc = function(userlog) { return ::g_battle_tasks.isBattleTask(userlog.body.unlockId) }
  }

  tabsList = [
    {
      tabType = BattleTasksWndTab.BATTLE_TASKS
      isVisible = @() ::has_feature("BattleTasks")
      text = "#mainmenu/btnBattleTasks"
      fillFunc = "fillBattleTasksList"
    },
    {
      tabType = BattleTasksWndTab.BATTLE_TASKS_HARD
      isVisible = @() ::has_feature("BattleTasks") && ::has_feature("Warbonds_2_0")
      text = "#mainmenu/btnBattleTasksHard"
      fillFunc = "fillBattleTasksList"
    },
    {
      tabType = BattleTasksWndTab.PERSONAL_UNLOCKS
      isVisible = @() ::has_feature("PersonalUnlocks")
      text = "#mainmenu/btnPersonalUnlocks"
      fillFunc = "fillPersonalUnlocksList"
    },
    {
      tabType = BattleTasksWndTab.HISTORY
      text = "#mainmenu/battleTasks/history"
      fillFunc = "fillTasksHistory"
    }
  ]

  function initScreen()
  {
    updateBattleTasksData()
    onChangeTab(scene.findObject("tasks_sheet_list"))

    initFocusArray()

    initWarbonds()
    updateWarbondsBalance()
  }

  function getAvailablePageIndex()
  {
    foreach(idx, tab in tabsList)
      if (!("isVisible" in tab) || tab.isVisible())
        return idx
    return -1
  }

  function getSceneTplView()
  {
    return {
      radiobuttons = getRadioButtonsView()
      tabs = getTabsView()
    }
  }

  function getSceneTplContainerObj()
  {
    return scene.findObject("root-box")
  }

  function buildBattleTasksArray(tabType)
  {
    configsArrayByTabType[tabType] = []

    local filteredByDiffArray = []
    local haveRewards = false
    foreach(type in difficultiesByTabType[tabType])
    {
      local array = ::g_battle_task_difficulty.withdrawTasksArrayByDifficulty(type.name, currentTasksArray)
      if (array.len() == 0)
        continue

      local taskWithReward = ::g_battle_tasks.getTaskWithAvailableAward(array)
      if (!::g_battle_tasks.showAllTasksValue && !::u.isEmpty(taskWithReward))
      {
        filteredByDiffArray.append(taskWithReward)
        haveRewards = true
      }
      else
        filteredByDiffArray.extend(array)
    }

    local resultArray = filteredByDiffArray
    if (!haveRewards && filteredByDiffArray.len())
    {
      local obj = getDifficultySwitchObj()
      local val = obj.getValue()
      local diffCode = val in usingDifficulties? usingDifficulties[val] : ::DIFFICULTY_ARCADE

      local filteredByModeArray = ::g_battle_tasks.getTasksArrayByGameModeDiffCode(
                                        filteredByDiffArray,
                                        null,
                                        ::g_difficulty.getDifficultyByDiffCode(diffCode),
                                        ::g_battle_tasks.showAllTasksValue)
      resultArray = filteredByModeArray
    }

    foreach(task in resultArray)
      configsArrayByTabType[tabType].append(generateTaskConfig(task))
  }

  function buildPersonalUnlocksArray(tabType)
  {
    configsArrayByTabType[tabType] = []
    foreach(unlockBlk in personalUnlocksArray)
      configsArrayByTabType[tabType].append(generateTaskConfig(unlockBlk))
  }

  function generateTaskConfig(task)
  {
    local config = ::build_conditions_config(task)
    ::build_unlock_desc(config)
    config.originTask <- task
    return config
  }

  function fillBattleTasksList()
  {
    local listBoxObj = getConfigsListObj()
    if (!::checkObj(listBoxObj))
      return

    local view = {items = []}
    foreach (idx, config in configsArrayByTabType[currentTabType])
    {
      view.items.append(::g_battle_tasks.generateItemView(config))
      if (::g_battle_tasks.canGetReward(::g_battle_tasks.getTaskById(config)))
        finishedTaskIdx = finishedTaskIdx < 0? idx : finishedTaskIdx
      else if (finishedTaskIdx < 0 && config.id == currentTaskId)
        finishedTaskIdx = idx
    }

    scene.findObject("battle_tasks_no_tasks_text").show(view.items.len() == 0)
    local data = ::handyman.renderCached(battleTaskItemTpl, view)
    guiScene.replaceContentFromText(listBoxObj, data, data.len(), this)

    foreach(config in configsArrayByTabType[currentTabType])
    {
      local task = config.originTask
      ::g_battle_tasks.setUpdateTimer(task, scene.findObject(task.id))
    }

    updateWidgetsVisibility()
    if (finishedTaskIdx < 0 || finishedTaskIdx >= configsArrayByTabType[currentTabType].len())
      finishedTaskIdx = 0
    listBoxObj.setValue(finishedTaskIdx)

    local obj = scene.findObject("warbond_shop_progress_block")
    local curWb = ::g_warbonds.getCurrentWarbond()
    if (currentTabType == BattleTasksWndTab.BATTLE_TASKS)
      ::g_warbonds_view.createProgressBox(curWb, obj, this)
    else if (currentTabType == BattleTasksWndTab.BATTLE_TASKS_HARD)
      ::g_warbonds_view.createSpecialMedalsProgress(curWb, obj, this)
  }

  function fillPersonalUnlocksList()
  {
    local listBoxObj = getConfigsListObj()
    if (!::checkObj(listBoxObj))
      return

    local view = {items = []}
    foreach (idx, config in configsArrayByTabType[BattleTasksWndTab.PERSONAL_UNLOCKS])
      view.items.append(::g_battle_tasks.generateItemView(config))

    scene.findObject("battle_tasks_no_tasks_text").show(false)
    local data = ::handyman.renderCached(battleTaskItemTpl, view)
    guiScene.replaceContentFromText(listBoxObj, data, data.len(), this)
    listBoxObj.setValue(0)
  }

  function updateWidgetsVisibility()
  {
    local listBoxObj = getConfigsListObj()
    if (!::checkObj(listBoxObj))
      return

    foreach(taskId, widget in newIconWidgetByTaskId)
    {
      local newIconWidgetContainer = listBoxObj.findObject("new_icon_widget_" + taskId)
      if (!::checkObj(newIconWidgetContainer))
        continue

      local widget = NewIconWidget(guiScene, newIconWidgetContainer)
      newIconWidgetByTaskId[taskId] = widget
      widget.setWidgetVisible(::g_battle_tasks.isBattleTaskNew(taskId))
    }
  }

  function updateBattleTasksData()
  {
    currentTasksArray = ::g_battle_tasks.getTasksArray()
    newIconWidgetByTaskId = ::g_battle_tasks.getWidgetsTable()
    personalUnlocksArray = ::g_personal_unlocks.getUnlocksArray()
    buildBattleTasksArray(BattleTasksWndTab.BATTLE_TASKS)
    buildBattleTasksArray(BattleTasksWndTab.BATTLE_TASKS_HARD)
    buildPersonalUnlocksArray(BattleTasksWndTab.PERSONAL_UNLOCKS)
  }

  function fillTasksHistory()
  {
    local finishedTasksUserlogsArray = ::getUserLogsList(userglogFinishedTasksFilter)

    local view = {
      doneTasksTable = {}
    }

    if (finishedTasksUserlogsArray.len())
    {
      view.doneTasksTable.rows <- ""
      view.doneTasksTable.rows += ::buildTableRow("tr_header",
               [{textType = "textareaNoTab", text = ::loc("unlocks/battletask"), tdalign = "left", width = "65%pw"},
               {textType = "textarea", text = ::loc("options/time"), tdalign = "right", width = "30%pw"}])

      foreach(idx, uLog in finishedTasksUserlogsArray)
      {
        local config = ::build_log_unlock_data(uLog)
        local text = config.name
        if (!::u.isEmpty(config.rewardText))
          text += ::loc("ui/parentheses/space", {text = config.rewardText})
        text = ::colorize("activeTextColor", text)

        local time = ::build_date_time_str(uLog.time, true)
        local rowData = [{textType = "textareaNoTab", text = text, tooltip = text, width = "60%pw", textRawParam = "pare-text:t='yes'; width:t='pw'; max-height:t='ph'"},
                         {textType = "textarea", text = time, tooltip = time, tdalign = "right", width = "40%pw"}]

        view.doneTasksTable.rows += ::buildTableRow("tr_" + idx, rowData, idx % 2 == 0)
      }
    }

    local data = ::handyman.renderCached(sceneTplDescriptionName, view)
    guiScene.replaceContentFromText(scene.findObject("tasks_history_frame"), data, data.len(), this)
  }

  function onChangeTab(obj)
  {
    if (!::checkObj(obj))
      return

    ::g_sound.stop()
    local curTabData = getSelectedTabData(obj)
    currentTabType = curTabData.tabType
    changeFrameVisibility()
    updateTabButtons()

    if (curTabData.fillFunc in this)
      this[curTabData.fillFunc]()

    restoreFocus()
  }

  function getSelectedTabData(listObj)
  {
    local val = 0
    if (::checkObj(listObj))
      val = listObj.getValue()

    return val in tabsList? tabsList[val] : {}
  }

  function changeFrameVisibility()
  {
    showSceneBtn("tasks_list_frame", currentTabType != BattleTasksWndTab.HISTORY)
    showSceneBtn("tasks_history_frame", currentTabType == BattleTasksWndTab.HISTORY)
  }

  function onEventBattleTasksFinishedUpdate(params)
  {
    updateBattleTasksData()
    onChangeTab(scene.findObject("tasks_sheet_list"))
  }

  function onShowAllTasks(obj)
  {
    ::broadcastEvent("BattleTasksShowAll", {showAllTasksValue = obj.getValue()})
  }

  function notifyUpdate()
  {
    ::broadcastEvent("BattleTasksIncomeUpdate")
  }

  function onTasksListDblClick(obj)
  {
    local value = obj.getValue()
    local config = getConfigByValue(value)
    local task = ::g_battle_tasks.getTaskById(config)
    if (!task)
      return

    if (::g_battle_tasks.canGetReward(task))
      return ::g_battle_tasks.getRewardForTask(task.id)

    local isActive = ::g_battle_tasks.isTaskActive(task)
    if (isActive && ::g_battle_tasks.canCancelTask(task))
      return onCancel(config)

    if (!isActive)
      return onActivate()
  }

  function onSelectTask(obj)
  {
    local val = obj.getValue()
    finishedTaskIdx = val

    ::g_sound.stop()

    local config = getConfigByValue(val)
    preparePlaybackForConfig(config)

    updateButtons(config)
    hideTaskWidget(config)
  }

  function preparePlaybackForConfig(config, useDefault = false)
  {
    if (::getTblValue("playback", config))
      ::g_sound.preparePlayback(::g_battle_tasks.getPlaybackPath(config.playback, useDefault), config.id)
  }

  function hideTaskWidget(config)
  {
    if (!config)
      return

    local uid = config.id
    local widget = ::getTblValue(uid, newIconWidgetByTaskId)
    if (!widget)
      return

    widget.setWidgetVisible(false)
    ::g_battle_tasks.markTaskSeen(uid)
  }

  function updateButtons(config = null)
  {
    local task = ::g_battle_tasks.getTaskById(config)
    local isBattleTask = ::g_battle_tasks.isBattleTask(task)

    local isActive = ::g_battle_tasks.isTaskActive(task)
    local isDone = ::g_battle_tasks.isTaskDone(task)
    local canCancel = isBattleTask && ::g_battle_tasks.canCancelTask(task)
    local canGetReward = isBattleTask && ::g_battle_tasks.canGetReward(task)
    local isController = ::g_battle_tasks.isController(task)
    local showActivateButton = !isActive && ::g_battle_tasks.canActivateTask(task)

    local showCancelButton = isActive && canCancel && !canGetReward && !isController

    ::showBtnTable(scene, {
      btn_activate = showActivateButton
      btn_cancel = showCancelButton
      btn_warbonds_shop = ::g_warbonds.isShopButtonVisible()
    })

    local showRerollButton = isBattleTask && !isDone && !canGetReward && !::u.isEmpty(::g_battle_tasks.rerollCost)
    local taskObj = getCurrentTaskObj()
    ::showBtn("btn_reroll", showRerollButton, taskObj)
    ::showBtn("btn_recieve_reward", canGetReward, taskObj)
    if (showRerollButton)
      ::placePriceTextToButton(taskObj, "btn_reroll", ::loc("mainmenu/battleTasks/reroll"), ::g_battle_tasks.rerollCost)
    showSceneBtn("btn_requirements_list", ::show_console_buttons && ::getTblValue("names", config, []).len() != 0)

    ::enableBtnTable(taskObj, {[getConfigPlaybackButtonId(config.id)] = ::g_sound.canPlay(config.id)}, true)
  }

  function updateTabButtons()
  {
    showSceneBtn("show_all_tasks", ::has_feature("ShowAllBattleTasks") && currentTabType != BattleTasksWndTab.HISTORY)
    showSceneBtn("battle_tasks_modes_radiobuttons", isBattleTasksTab())
    showSceneBtn("warbond_shop_progress_block", isBattleTasksTab())
    showSceneBtn("progress_box_place", currentTabType == BattleTasksWndTab.BATTLE_TASKS)
    showSceneBtn("medals_block", currentTabType == BattleTasksWndTab.BATTLE_TASKS_HARD)
    updateProgressText()
  }

  function isBattleTasksTab()
  {
    return currentTabType == BattleTasksWndTab.BATTLE_TASKS
    || currentTabType == BattleTasksWndTab.BATTLE_TASKS_HARD
  }

  function updateProgressText()
  {
    local textObj = scene.findObject("progress_text")
    if (!::check_obj(textObj))
      return

    local curWb = ::g_warbonds.getCurrentWarbond()
    local text = ""
    if (curWb)
      if (currentTabType == BattleTasksWndTab.BATTLE_TASKS)
        text = ::g_warbonds_view.getOrdinaryText(curWb)
      else if (currentTabType == BattleTasksWndTab.BATTLE_TASKS_HARD)
        text = ::g_warbonds_view.getSpecialText(curWb)

    textObj.setValue(text)
  }

  function getCurrentTaskObj()
  {
    local listObj = getConfigsListObj()
    if (!::checkObj(listObj))
      return

    local value = listObj.getValue()
    if (value < 0 || value >= listObj.childrenCount())
      return null

    return listObj.getChild(value)
  }

  function getRadioButtonsView()
  {
    usingDifficulties = []
    local tplView = []
    local curMode = ::game_mode_manager.getCurrentGameMode()
    local selDiff = ::g_difficulty.getDifficultyByDiffCode(curMode ? curMode.diffCode : ::DIFFICULTY_ARCADE)

    foreach(idx, diff in ::g_difficulty.types)
    {
      if (diff.diffCode < 0 || !diff.isAvailable(::GM_DOMINATION))
        continue

      local array = ::g_battle_tasks.getTasksArrayByGameModeDiffCode(::g_battle_tasks.getTasksArray(), null, diff, false, true)
      if (array.len() == 0)
        continue

      tplView.append({
        radiobuttonName = diff.getLocName(),
        selected = selDiff == diff
      })
      usingDifficulties.append(diff.diffCode)
    }

    return tplView
  }

  function getTabsView()
  {
    local pageIndex = getAvailablePageIndex()
    local view = {tabs = []}
    foreach (idx, tabData in tabsList)
    {
      view.tabs.append({
        tabName = tabData.text
        navImagesText = ::get_navigation_images_text(idx, tabsList.len())
        hidden = ("isVisible" in tabData) && !tabData.isVisible()
        selected = idx == pageIndex
      })
    }

    return ::handyman.renderCached("gui/frameHeaderTabs", view)
  }

  function onChangeShowMode(obj)
  {
    notifyUpdate()
  }

  function getCurrentSelectedTask()
  {
    local config = getCurrentConfig()
    return ::g_battle_tasks.getTaskById(config)
  }

  function getConfigByValue(value)
  {
    local checkArray = ::getTblValue(currentTabType, configsArrayByTabType, [])
    return ::getTblValue(value, checkArray)
  }

  function onGetRewardForTask(obj)
  {
    ::g_battle_tasks.getRewardForTask(obj.task_id)
  }

  function madeTaskAction(mode)
  {
    local task = getCurrentSelectedTask()
    if (!::getTblValue("id", task))
      return

    local blk = ::DataBlock()
    blk.setStr("mode", mode)
    blk.setStr("unlockName", task.id)

    local taskId = ::char_send_blk("cln_management_personal_unlocks", blk)
    ::g_tasker.addTask(taskId, {showProgressBox = true}, notifyUpdate)
  }

  function makeRerollAction(battleTaskId, battleTaskTemplateId)
  {
    if (::u.isEmpty(battleTaskId))
      return

    local blk = ::DataBlock()
    blk.setStr("unlockName", battleTaskId)

    local taskId = ::char_send_blk("cln_reroll_battle_task", blk)
    ::g_tasker.addTask(taskId, {showProgressBox = true}, (@(notifyUpdate, battleTaskId, battleTaskTemplateId) function() {
      ::statsd_counter("battle_tasks.reroll_v2." + battleTaskTemplateId)
      notifyUpdate()
    })(notifyUpdate, battleTaskId, battleTaskTemplateId))
  }

  function onTaskReroll(obj)
  {
    local taskId = ::getTblValue("taskId", obj)
    if (!taskId)
      return

    local task = ::g_battle_tasks.getTaskById(taskId)
    if (!task)
      return

    if (::check_balance_msgBox(::g_battle_tasks.rerollCost))
      msgBox("reroll_perform_action",
             ::loc("msgbox/battleTasks/reroll",
                  {cost = ::g_battle_tasks.rerollCost.tostring(),
                    taskName = ::g_battle_tasks.getLocalizedTaskNameById(task)
                  }),
      [
        ["yes", (@(task) function() { makeRerollAction(task.id, task._base_id) })(task) ],
        ["no", function() {} ]
      ], "yes", { cancel_fn = function() {}})
  }

  function onActivate()
  {
    local task = getCurrentSelectedTask()
    if (!::g_battle_tasks.canActivateTask(task))
      return

    madeTaskAction("accept")
  }

  function onCancel(config)
  {
    if (::getTblValue("curVal", config, 0) <= 0)
      return madeTaskAction("cancel")

    msgBox("battletasks_confirm_cancel", ::loc("msgbox/battleTasks/clarifyCancel"),
    [["ok", function(){ madeTaskAction("cancel") }],
     ["cancel", function() {}]], "cancel")
  }

  function getConfigPlaybackButtonId(btnId)
  {
    return btnId + "_sound"
  }

  function getConfigsListObj()
  {
    if (::checkObj(scene))
      return scene.findObject("tasks_list")
    return null
  }

  function getMainFocusObj()
  {
    return getConfigsListObj()
  }

  function getMainFocusObj2()
  {
    return getDifficultySwitchObj()
  }

  function getDifficultySwitchObj()
  {
    return scene.findObject("battle_tasks_modes_radiobuttons")
  }

  function goBack()
  {
    ::g_battle_tasks.markAllTasksSeen()
    ::g_battle_tasks.saveSeenTasksData()
    ::g_sound.stop()
    base.goBack()
  }

  function initWarbonds()
  {
    if (!::has_feature("Warbonds") || ::has_feature("Warbonds_2_0"))
      return

    local warbondsObj = scene.findObject("warbonds_balance")
    ::secondsUpdater(warbondsObj, updateWarbondsText)
  }

  static function updateWarbondsText(textObj, ...)
  {
    textObj.setValue(::g_warbonds.getInfoText())
  }

  function updateWarbonds()
  {
    if (!::has_feature("Warbonds") || ::has_feature("Warbonds_2_0"))
      return

    updateWarbondsText(scene.findObject("warbonds_balance"))
  }

  function updateWarbondsBalance()
  {
    if (::has_feature("Warbonds") && !::has_feature("Warbonds_2_0"))
      return

    local warbondsObj = scene.findObject("warbonds_balance")
    warbondsObj.setValue(::g_warbonds.getBalanceText())
    warbondsObj.tooltip = ::loc("warbonds/maxAmount", {warbonds = ::g_warbonds.getLimit()})
  }

  function onEventWarbondAwardBought(p)
  {
    updateWarbonds()
    updateWarbondsBalance()
  }

  function onEventPlaybackDownloaded(p)
  {
    if (!::check_obj(scene))
      return

    local pbObj = scene.findObject(getConfigPlaybackButtonId(p.id))
    if (!::check_obj(pbObj))
      return

    pbObj.enable(p.success)
    pbObj.downloading = p.success? "no" : "yes"

    if (p.success)
      return

    local config = getConfigByValue(finishedTaskIdx)
    if (config)
      preparePlaybackForConfig(config, true)
  }

  function onEventFinishedPlayback(p)
  {
    local config = getConfigByValue(finishedTaskIdx)
    if (!config)
      return

    local pbObjId = getConfigPlaybackButtonId(config.id)
    local pbObj = scene.findObject(pbObjId)
    if (::check_obj(pbObj))
      pbObj.setValue(false)
  }

  function onWarbondsShop()
  {
    ::g_warbonds.openShop()
  }

  function getCurrentConfig()
  {
    local listBoxObj = getConfigsListObj()
    if (!::checkObj(listBoxObj))
      return null

    return getConfigByValue(listBoxObj.getValue())
  }

  function onViewUnlocks()
  {
    local config = getCurrentConfig()
    if (::getTblValue("names", config, []).len() == 0)
      return []

    local awardsList = []
    foreach(id in config.names)
      awardsList.append(::build_log_unlock_data(::build_conditions_config(::g_unlocks.getUnlockById(id))))

    ::showUnlocksGroupWnd([{
      unlocksList = awardsList
      titleText = ::loc("unlocks/requirements")
    }])
  }

  function switchPlaybackMode(obj)
  {
    local config = getConfigByValue(finishedTaskIdx)
    if (!config)
      return

    if (!obj.getValue())
      ::g_sound.stop()
    else
      ::g_sound.play(config.id)
  }

  function onDestroy()
  {
    ::g_sound.stop()
  }
}