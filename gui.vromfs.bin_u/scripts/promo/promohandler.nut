const VOTED_POLLS_SAVE_ID = "voted_polls"

::dagui_propid.add_name_id("task_id")

function create_promo_blocks(handler)
{
  if (!::handlersManager.isHandlerValid(handler))
    return null

  local owner = handler.weakref()
  local guiScene = handler.guiScene
  local scene = handler.scene.findObject("promo_mainmenu_place")

  return ::Promo(owner, guiScene, scene)
}

class Promo
{
  owner = null
  guiScene = null
  scene = null

  sourceDataBlock = null

  widgetsTable = {}
  widgetsWithCounter = ["events_mainmenu_button", "battle_tasks_mainmenu_button"]

  votedPolls = null
  pollIdToObjectId = {}

  updateFunctions = {
    events_mainmenu_button = function() { return updateEventButton() }
    world_war_button = function() { return updateWorldWarButton() }
    tutorial_mainmenu_button = function() { return updateTutorialButton() }
    battle_tasks_mainmenu_button = function() { return updateBattleTasksButton() }
    current_battle_tasks_mainmenu_button = function() { return updateCurrentBattleTaskButton() }
    invite_squad_mainmenu_button = function() { return updateSquadInviteButton() }
    recent_items_mainmenu_button = function() { return updateRecentItemsButton() }
  }

  function constructor(_handler, _guiScene, _scene)
  {
    owner = _handler
    guiScene = _guiScene
    scene = _scene

    votedPolls = ::load_local_custom_settings(VOTED_POLLS_SAVE_ID, ::DataBlock())

    initScreen(true)
    clearOldVotedPolls()
    ::subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)
  }

  function initScreen(forceReplaceContent = false)
  {
    updatePromoBlocks(forceReplaceContent)
    local timerObj = owner.scene.findObject("promo_blocks_timer")
    if (::checkObj(timerObj))
      timerObj.setUserData(this)
  }

  function updatePromoBlocks(forceReplaceContent = false)
  {
    if (!::g_promo.requestUpdate() && !forceReplaceContent)
      return

    sourceDataBlock = ::g_promo.getConfig()
    updateAllBlocks()
  }

  function updateAllBlocks()
  {
    local data = generateData()
    local topPositionPromoPlace = scene.findObject("promo_mainmenu_place_top")
    if (::checkObj(topPositionPromoPlace))
      guiScene.replaceContentFromText(topPositionPromoPlace, data.upper, data.upper.len(), this)

    local bottomPositionPromoPlace = scene.findObject("promo_mainmenu_place_bottom")
    if (::checkObj(bottomPositionPromoPlace))
      guiScene.replaceContentFromText(bottomPositionPromoPlace, data.bottom, data.bottom.len(), this)

    ::g_promo.initWidgets(scene, widgetsTable, widgetsWithCounter)
    updateData()
    owner.restoreFocus()
  }

  function onSceneActivate(show)
  {
    if (show)
      updatePromoBlocks()
  }

  function generateData()
  {
    widgetsTable = {}
    local upperPromoView = {
      showAllCheckBoxEnabled = ::g_promo.canSwitchShowAllPromoBlocksFlag()
      showAllCheckBoxValue = ::g_promo.getShowAllPromoBlocks()
      promoButtons = []
    }

    local bottomPromoView = {
      showAllCheckBoxEnabled = false
      promoButtons = []
    }

    for (local i = 0; sourceDataBlock != null && i < sourceDataBlock.blockCount(); i++)
    {
      local block = sourceDataBlock.getBlock(i)

      local blockView = ::g_promo.generateBlockView(block)
      if(block.pollId != null)
        pollIdToObjectId[block.pollId] <- blockView.id

      if (block.bottom)
        bottomPromoView.promoButtons.push(blockView)
      else
        upperPromoView.promoButtons.push(blockView)

      if (::getTblValue("notifyNew", block, true) && !::g_promo.isWidgetSeenById(blockView.id))
        widgetsTable[blockView.id] <- {}

      local playlistArray = getPlaylistArray(block)
      if (playlistArray.len() > 0)
      {
        local requestStopPlayTimeSec = block.requestStopPlayTimeSec || ::g_promo.DEFAULT_REQ_STOP_PLAY_TIME_SONG_SEC
        ::g_promo.enablePlayMenuMusic(playlistArray, requestStopPlayTimeSec)
      }
    }

    return {
      upper = ::handyman.renderCached("gui/promo/promoBlocks", upperPromoView)
      bottom = ::handyman.renderCached("gui/promo/promoBlocks", bottomPromoView)
    }
  }

  function clearOldVotedPolls()
  {
    local votedCount = votedPolls.blockCount() - 1
    for (local i = votedCount; i >= 0; i--)
    {
      local savedId = votedPolls.getBlockName(i)
      local found = false
      for (local j = 0; sourceDataBlock != null && j < sourceDataBlock.blockCount(); j++)
      {
        local block = sourceDataBlock.getBlock(j)
        if(block.pollId && block.pollId == savedId)
        {
          found = true
          break
        }
      }
      if( ! found)
        votedPolls[savedId] = null
    }
    ::save_local_custom_settings(VOTED_POLLS_SAVE_ID, votedPolls)
  }

  function setTplView(tplPath, object, view = {})
  {
    if (!::checkObj(object))
      return

    local data = ::handyman.renderCached(tplPath, view)
    guiScene.replaceContentFromText(object, data, data.len(), this)
  }

  function updateData()
  {
    if (sourceDataBlock == null)
      return

    for (local i = 0; i < sourceDataBlock.blockCount(); i++)
    {
      local block = sourceDataBlock.getBlock(i)
      local id = block.getBlockName()
      if (id in updateFunctions)
        updateFunctions[id].call(this)

      local btnObj = scene.findObject(id)
      if (::checkObj(btnObj))
        btnObj.setUserData(this)

      if(block.pollId != null)
        updateWebPollButton({id = block.pollId})
    }
  }

  function getPlaylistArray(block)
  {
    local defaultName = "playlist"
    local langKey = defaultName + "_" + ::g_language.getShortName()
    local list = block[langKey] || block[defaultName]
    if (!list)
      return []

    local array = ::blk_to_array(list, "name")
    return array
  }

  function activateSelectedBlock(obj)
  {
    local promoButtonObj = obj.getChild(obj.getValue())
    local searchObjId = ::g_promo.getActionParamsKey(promoButtonObj.id)
    local radioButtonsObj = promoButtonObj.findObject("multiblock_radiobuttons_list")
    if (::check_obj(radioButtonsObj))
    {
      local val = radioButtonsObj.getValue()
      if (val >= 0)
        searchObjId += "_" + val
    }
    ::g_promo.performAction(owner, promoButtonObj.findObject(searchObjId))
  }

  function performAction(obj)
  {
    performActionWithStatistics(obj, false)
  }

  function performActionWithStatistics(obj, isFromCollapsed)
  {
    ::add_big_query_record("promo_click",
      ::save_to_json({id = ::g_promo.cutActionParamsKey(obj.id), collapsed = isFromCollapsed}))
    local objScene = obj.getScene()
    objScene.performDelayed(
      this,
      (@(owner, obj, widgetsTable, widgetsWithCounter) function() {
        if (!::checkObj(obj))
          return

        if (!::g_promo.performAction(owner, obj))
          if (::checkObj(obj))
            ::g_promo.setSimpleWidgetData(widgetsTable, obj.id, widgetsWithCounter)
      })(owner, obj, widgetsTable, widgetsWithCounter)
    )
  }

  function performActionCollapsed(obj)
  {
    local buttonObj = obj.getParent()
    performActionWithStatistics(buttonObj.findObject(::g_promo.getActionParamsKey(buttonObj.id)), true)
  }

  function onShowAllCheckBoxChange(obj)
  {
    ::g_promo.setShowAllPromoBlocks(obj.getValue())
  }

  function isShowAllCheckBoxEnabled()
  {
    if (!isValid())
      return null

    local chBoxObj = scene.findObject("checkbox_show_all_promo_blocks")
    if (!::checkObj(chBoxObj))
      return null

    return chBoxObj.getValue()
  }

  function getBoolParamByIdFromSourceBlock(param, id, defaultValue = false)
  {
    if (!sourceDataBlock || !sourceDataBlock[id] || !sourceDataBlock[id][param])
      return null

    local show = ::getTblValue(param, sourceDataBlock[id], defaultValue)
    if (::u.isString(show))
      show = show == "yes"? true : false

    return show
  }

  function isValid()
  {
    return ::check_obj(scene)
  }

  function onPromoBlocksUpdate(obj, dt)
  {
    updatePromoBlocks()
  }

  //--------------- <BATTLE TASKS> -------------------------
  function updateBattleTasksButton()
  {
    local id = "battle_tasks_mainmenu_button"
    if (isShowAllCheckBoxEnabled())
      ::showBtn(id, true, scene)
    else
    {
      local show = ::g_battle_tasks.isAvailableForUser() && ::g_promo.getVisibilityById(id)
      ::showBtn(id, show, scene)
      if (!show)
        return
    }

    local widget = ::getTblValue(id, widgetsTable)
    if (!widget)
      return

    local haveRewards = ::g_battle_tasks.canGetAnyReward()
    widget.setValue(haveRewards? -1 : ::g_battle_tasks.getUnseenTasksCount())
    widget.setIcon(haveRewards ? "#ui/gameuiskin#new_reward_icon" : widget.defaultIcon)
  }
  //--------------- </BATTLE TASKS> ------------------------

  //------------- <CURRENT BATTLE TASK ---------------------
  function updateCurrentBattleTaskButton()
  {
    local reqTask = null
    local id = "current_battle_tasks_mainmenu_button"
    local show = ::g_battle_tasks.isAvailableForUser() && ::g_promo.getVisibilityById(id)

    local buttonObj = ::showBtn(id, show, scene)
    if (!show || !::checkObj(buttonObj))
      return

    local currentGameModeId = ::game_mode_manager.getCurrentGameModeId()
    if (currentGameModeId == null)
      return

    local searchedTask = ::g_battle_tasks.getTasksArrayByGameModeDiffCode(null, currentGameModeId)
    foreach(task in searchedTask)
    {
      if (::g_battle_tasks.isTaskDone(task))
        continue

      reqTask = task
    }

    local promoView = ::u.copy(::getTblValue(id, ::g_promo.getConfig(), {}))
    local view = {}
    local config = {}

    if (reqTask)
    {
      config = ::build_conditions_config(reqTask)
      ::build_unlock_desc(config)

      local itemView = ::g_battle_tasks.generateItemView(config, true)
      itemView.canReroll = false
      view = ::u.tablesCombine(itemView, promoView, function(val1, val2) { return val1 != null? val1 : val2 })
      view.collapsedText <- ::g_promo.getCollapsedText(view, id)
    }
    else
    {
      promoView.id <- id
      view = ::g_battle_tasks.generateItemView(promoView, true)
      view.collapsedText <- ::g_promo.getCollapsedText(promoView, id)
      view.refreshTimer <- true
    }

    view.performActionId <- ::g_promo.getActionParamsKey(id)
    view.taskId <- ::getTblValue("id", reqTask)
    view.action <- ::g_promo.PERFORM_ACTON_NAME
    view.collapsedIcon <- ::g_promo.getCollapsedIcon(view, id)
    setTplView("gui/unlocks/battleTasksItem", buttonObj, { items = [view], collapsedAction = ::g_promo.PERFORM_ACTON_NAME})
    ::g_battle_tasks.setUpdateTimer(reqTask, buttonObj)
  }

  function onGenericTooltipOpen(obj)
  {
    ::g_tooltip.open(obj, this)
  }

  function onTooltipObjClose(obj)
  {
    ::g_tooltip.close.call(this, obj)
  }

  function onGetRewardForTask(obj)
  {
    ::g_battle_tasks.getRewardForTask(obj.task_id)
  }
  //------------- </CURRENT BATTLE TASK --------------------

  //-------------- <TUTORIAL> ------------------------------

  function updateTutorialButton()
  {
    local tutorialData = getTutorialData()

    local tutorialMissionName = ::getTblValue("tutorialMissionName", tutorialData)
    local tutorialId = ::getTblValue("tutorialId", tutorialData)

    local id = "tutorial_mainmenu_button"
    local actionKey = ::g_promo.getActionParamsKey(id)
    ::g_promo.setActionParamsData(actionKey, "tutorial", [tutorialId])

    local buttonObj = null
    local show = isShowAllCheckBoxEnabled()
    if (show)
      buttonObj = ::showBtn(id, show, scene)
    else
    {
      show = tutorialMissionName != null && ::g_promo.getVisibilityById(id)
      buttonObj = ::showBtn(id, show, scene)
    }

    if (!show || !::checkObj(buttonObj))
      return

    local buttonText = ::loc("missions/" + ::getTblValue("name", tutorialMissionName) + "/short", "")
    if (!tutorialMissionName)
      buttonText = ::loc("mainmenu/btnTutorial")
    ::g_promo.setButtonText(buttonObj, id, buttonText)
  }

  function getTutorialData()
  {
    local tutorial = null
    local tutorialId = ""
    local curUnit = ::get_show_aircraft()

    if (::isTank(curUnit) && ::has_feature("Tanks"))
    {
      tutorialId = "lightTank"
      tutorial = ::get_uncompleted_tutorial_data("tutorial_tank_basics_arcade", 0)
    }

    if (!tutorial)
      foreach (tut in ::tutorials_to_check)
      {
        if (("requiresFeature" in tut) && !::has_feature(tut.requiresFeature))
          continue

        tutorial = ::get_uncompleted_tutorial_data(tut.tutorial, 0)
        if (tutorial)
        {
          tutorialId = tut.id
          break
        }
      }

    return {
      tutorialMissionName = ::getTblValue("mission", tutorial)
      tutorialId = tutorialId
    }
  }
  //--------------- </TUTORIAL> ----------------------------

  //--------------- <EVENTS> -------------------------------
  function updateEventButton()
  {
    local id = "events_mainmenu_button"
    local buttonObj = null
    local show = isShowAllCheckBoxEnabled()
    if (show)
      buttonObj = ::showBtn(id, show, scene)
    else
    {
      show = isEventsAvailable() && ::g_promo.getVisibilityById(id)
      buttonObj = ::showBtn(id, show, scene)
    }

    if (!show || !::checkObj(buttonObj))
      return

    ::g_promo.setButtonText(buttonObj, id, getEventsButtonText())
    ::g_promo.updateWidgetNum(widgetsTable, id, ::events.getNewEventsCount())
  }

  function getEventsButtonText()
  {
    local activeEventsNum = ::events.getEventsVisibleInEventsWindowCount()
    return activeEventsNum <= 0
      ? ::loc("mainmenu/events/eventlist_btn_no_active_events")
      : ::loc("mainmenu/btnTournamentsAndEvents")
  }

  function isEventsAvailable()
  {
    return ::has_feature("Events")
           && ::events
           && ::events.getEventsVisibleInEventsWindowCount()
  }
  //----------------- </EVENTS> -----------------------------

  //----------------- <WORLD WAR> ---------------------------
  function updateWorldWarButton()
  {
    local id = "world_war_button"
    local isWwEnabled = ::is_worldwar_enabled()
    local isVisible = ::g_promo.getShowAllPromoBlocks() || isWwEnabled

    local wwButton = ::showBtn(id, isVisible, scene)
    if (!isVisible || !::checkObj(wwButton))
      return

    local text = ::loc("mainmenu/btnWorldwar")
    if (isWwEnabled && ::g_world_war.lastPlayedOperationId)
    {
      local operation = ::g_ww_global_status.getOperationById(::g_world_war.lastPlayedOperationId)
      if (!::u.isEmpty(operation))
         text = operation.getMapText()
    }

    wwButton.findObject("world_war_button_text").setValue(::loc("worldWar/iconWorldWar") + " " + text)
  }
  //----------------- </WORLD WAR> --------------------------

  //---------------- <INVITE SQUAD> -------------------------

  function updateSquadInviteButton()
  {
    local id = "invite_squad_mainmenu_button"
    local show = !::is_me_newbie() && ::g_promo.getVisibilityById(id)
    local buttonObj = ::showBtn(id, show, scene)
    if (!show || !::checkObj(buttonObj))
      return

    buttonObj.inactiveColor = ::checkIsInQueue() ? "yes" : "no"
  }

  //---------------- </INVITE SQUAD> ------------------------

  //----------------- <NAVIGATION> --------------------------

  function getWrapNestObj()
  {
    if (!isValid())
      return null

    for (local i = 0; i < scene.childrenCount(); i++)
    {
      local child = scene.getChild(i)
      if (child.isVisible() && child.isEnabled())
        return scene
    }

    return null
  }

  function onWrapUp(obj)
  {
    owner.onWrapUp(obj)
  }

  function onWrapDown(obj)
  {
    owner.onWrapDown(obj)
  }

  //------------------ </NAVIGATION> --------------------------

  //--------------------- <TOGGLE> ----------------------------

  function onToggleItem(obj) { ::g_promo.toggleItem(obj) }

  //-------------------- </TOGGLE> ----------------------------

  //------------------ <RECENT ITEMS> -------------------------

  function updateRecentItemsButton()
  {
    local id = "recent_items_mainmenu_button"
    local show = isShowAllCheckBoxEnabled() || ::g_promo.getVisibilityById(id)
    ::showBtn(id, show, scene)
    if (!show)
      return

    ::g_recent_items.createHandler(this, scene.findObject(id))
  }

  //----------------- </RECENT ITEMS> -------------------------

  //------------------ <WEB POLL> -------------------------

  function updateWebPollButton(pollData)
  {
    local pollId = ::getTblValue("id", pollData)
    if(pollId == null)
      return

    pollId = pollId.tostring()

    local objectId = ::getTblValue(pollId, pollIdToObjectId)
    if(objectId == null)
      return

    local showByLocalConditions = ! (pollId in votedPolls) && ::g_promo.getVisibilityById(objectId)
    if( ! showByLocalConditions)
    {
      ::showBtn(objectId, false, scene)
      return
    }

    local hasVote = ::getTblValue("voted", pollData)
    if(hasVote)
    {
      votedPolls[pollId] <- true
      ::save_local_custom_settings(VOTED_POLLS_SAVE_ID, votedPolls)
      return
    }

    local token = ::g_webpoll.getPollToken(pollId)
    if(token.len() == 0)
      return // will be back here by WebPollAuthResult event

    local link = ::g_webpoll.generatePollUrl(pollId, token)
    ::set_blk_value_by_path(sourceDataBlock, objectId + "/link", link)
    ::g_promo.generateBlockView(sourceDataBlock[objectId])
    local obj = scene.findObject(::g_promo.getActionParamsKey(objectId))
    if(::checkObj(obj))
      obj.link = link


    ::showBtn(objectId, ! hasVote, scene)
  }

  //----------------- </WEB POLL> -------------------------

  //----------------- <RADIOBUTTONS> --------------------------

  function switchBlock(obj) { ::g_promo.switchBlock(obj, scene) }
  function manualSwitchBlock(obj) { ::g_promo.manualSwitchBlock(obj, scene) }
  function selectNextBlock(obj, dt) { ::g_promo.selectNextBlock(obj, dt) }

  //----------------- </RADIOBUTTONS> -------------------------

  function onEventEventsDataUpdated(p)  { updateEventButton() }
  function onEventMyStatsUpdated(p)     {
                                          updateEventButton()
                                          updateBattleTasksButton()
                                        }
  function onEventQueueChangeState(p)   {
                                          updateSquadInviteButton()
                                        }
  function onEventUnlockedCountriesUpdate(p) { updateEventButton() }
  function onEventNewEventsChanged(p)   { updateEventButton() }
  function onEventNewBattleTasksChanged(p) { updateBattleTasksButton() }
  function onEventBattleTasksFinishedUpdate(p) {
                                                  updateBattleTasksButton()
                                                  updateCurrentBattleTaskButton()
                                               }
  function onEventCurrentGameModeIdChanged(p) { updateCurrentBattleTaskButton() }
  function onEventHangarModelLoaded(p)  { updateTutorialButton() }
  function onEventShowAllPromoBlocksValueChanged(p) { updatePromoBlocks() }
  function onEventPartnerUnlocksUpdated(p) { updatePromoBlocks(true) }
  function onEventWWLoadOperation(p) { updateWorldWarButton() }
  function onEventWWStopWorldWar(p) { updateWorldWarButton() }
  function onEventWWGlobalStatusChanged(p) { updateWorldWarButton() }
  function onEventWebPollAuthResult(p) { updateWebPollButton(p) }
}
