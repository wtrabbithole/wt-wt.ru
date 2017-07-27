function gui_start_battle_tasks_wnd(taskId = null)
{
  if (!::g_battle_tasks.isAvailableForUser())
    return ::showInfoMsgBox(::loc("msgbox/notAvailbleYet"))

  ::gui_start_modal_wnd(::gui_handlers.BattleTasksWnd, {currentTaskId = taskId})
}

enum BattleTasksWndTab {
  BATTLE_TASKS,
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
  buildedBattleTasksArray = null
  buildedPersonalUnlocksArray = null
  newIconWidgetByTaskId = null

  finishedTaskIdx = -1
  usingDifficulties = null

  currentTaskId = null
  currentTabType = null

  static UNLOCK_PLAYBACK_KEY = "personal"
  isCurrentPlaybackPlayed = false

  userglogFinishedTasksFilter = {
    show = [::EULT_NEW_UNLOCK]
    checkFunc = function(userlog) { return ::g_battle_tasks.isBattleTask(userlog.body.unlockId) }
  }

  tabsList = [
    {
      tabType = BattleTasksWndTab.BATTLE_TASKS
      isVisible = function(){ return ::has_feature("BattleTasks")}
      text = "#mainmenu/btnBattleTasks"
      fillFunc = "fillBattleTasksList"
    },
    {
      tabType = BattleTasksWndTab.PERSONAL_UNLOCKS
      isVisible = function() { return ::has_feature("PersonalUnlocks")}
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

  function buildBattleTasksArray()
  {
    buildedBattleTasksArray = []

    local filteredByDiffArray = []
    local haveRewards = false
    foreach(type in ::g_battle_task_difficulty.types)
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
    if (!haveRewards)
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
      buildedBattleTasksArray.append(generateTaskConfig(task))
  }

  function buildPersonalUnlocksArray()
  {
    buildedPersonalUnlocksArray = []
    foreach(unlockBlk in personalUnlocksArray)
      buildedPersonalUnlocksArray.append(generateTaskConfig(unlockBlk))
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
    foreach (idx, config in buildedBattleTasksArray)
    {
      view.items.append(::g_battle_tasks.generateItemView(config))
      if (::g_battle_tasks.canGetReward(::g_battle_tasks.getTaskById(config)))
        finishedTaskIdx = finishedTaskIdx < 0? idx : finishedTaskIdx
      else if (finishedTaskIdx < 0 && config.id == currentTaskId)
        finishedTaskIdx = idx
    }

    local data = ::handyman.renderCached(battleTaskItemTpl, view)
    guiScene.replaceContentFromText(listBoxObj, data, data.len(), this)

    foreach(config in buildedBattleTasksArray)
    {
      local task = config.originTask
      ::g_battle_tasks.setUpdateTimer(task, scene.findObject(task.id))
    }

    updateWidgetsVisibility()
    if (finishedTaskIdx < 0 || finishedTaskIdx >= buildedBattleTasksArray.len())
      finishedTaskIdx = 0
    listBoxObj.setValue(finishedTaskIdx)
  }

  function fillPersonalUnlocksList()
  {
    local listBoxObj = getConfigsListObj()
    if (!::checkObj(listBoxObj))
      return

    local view = {items = []}
    foreach (idx, config in buildedPersonalUnlocksArray)
      view.items.append(::g_battle_tasks.generateItemView(config))

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
    buildBattleTasksArray()
    buildPersonalUnlocksArray()
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

    resetPlayback()
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

    resetPlayback()

    local config = getConfigByValue(val)
    updateButtons(config)

    if (config.playback)
      ::set_cached_music(::CACHED_MUSIC_MISSION, config.playback, UNLOCK_PLAYBACK_KEY)
    hideTaskWidget(config)
  }

  function resetPlayback()
  {
    isCurrentPlaybackPlayed = false
    ::play_cached_music("")
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

    ::enableBtnTable(taskObj, {[getConfigPlaybackButtonId(config)] = !::u.isEmpty(::getTblValue("playback", config))}, true)
  }

  function updateTabButtons()
  {
    showSceneBtn("show_all_tasks", ::has_feature("ShowAllBattleTasks") && currentTabType != BattleTasksWndTab.HISTORY)
    showSceneBtn("battle_tasks_modes_radiobuttons", currentTabType == BattleTasksWndTab.BATTLE_TASKS)
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
    local listBoxObj = getConfigsListObj()
    if (!::checkObj(listBoxObj))
      return null

    local config = getConfigByValue(listBoxObj.getValue())
    return ::g_battle_tasks.getTaskById(config)
  }

  function getConfigByValue(value)
  {
    local checkArray = []
    if (currentTabType == BattleTasksWndTab.BATTLE_TASKS)
      checkArray = buildedBattleTasksArray
    if (currentTabType == BattleTasksWndTab.PERSONAL_UNLOCKS)
      checkArray = buildedPersonalUnlocksArray

    if (!(value in checkArray))
      return null

    return checkArray[value]
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

  function getConfigPlaybackButtonId(config)
  {
    return ::getTblValue("id", config, "") + "_sound"
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
    resetPlayback()
    base.goBack()
  }

  function initWarbonds()
  {
    if (!::has_feature("Warbonds"))
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
    if (!::has_feature("Warbonds"))
      return

    updateWarbondsText(scene.findObject("warbonds_balance"))
  }

  function onEventWarbondAwardBought(p)
  {
    updateWarbonds()
  }

  function onWarbondsShop()
  {
    ::g_warbonds.openShop()
  }

  function onViewUnlocks()
  {
    local listBoxObj = getConfigsListObj()
    if (!::checkObj(listBoxObj))
      return null

    local config = getConfigByValue(listBoxObj.getValue())
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
    if (obj.getValue())
    {
      if (isCurrentPlaybackPlayed)
        ::pause_cached_music(false)
      else
        ::play_cached_music(UNLOCK_PLAYBACK_KEY)
    }
    else
      ::pause_cached_music(true)
    isCurrentPlaybackPlayed = obj.getValue()
  }

  function onDestroy()
  {
    resetPlayback()
  }
}
