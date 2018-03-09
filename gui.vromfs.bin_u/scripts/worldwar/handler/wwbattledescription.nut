local time = require("scripts/time.nut")

// Temporary image. Has to be changed after receiving correct art
const WW_OPERATION_DEFAULT_BG_IMAGE = "#ui/bkg/login_layer_h1_0"

enum WW_BATTLE_VIEW_MODES
{
  BATTLE_LIST,
  SQUAD_INFO,
  QUEUE_INFO
}

class ::gui_handlers.WwBattleDescription extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/modalSceneWithGamercard.blk"
  sceneTplName = "gui/worldWar/battleDescriptionWindow"
  sceneTplBattleList = "gui/missions/missionBoxItemsList"
  sceneTplDescriptionName = "gui/worldWar/battleDescriptionWindowContent"
  sceneTplTeamRight = "gui/worldWar/wwBattleDescriptionTeamUnitsInfo"
  sceneTplTeamHeaderInfo = "gui/worldWar/wwBattleDescriptionTeamInfo"

  slotbarActions = [ "autorefill", "aircraft", "weapons", "info", "repair" ]
  shouldCheckCrewsReady = true
  hasSquadsInviteButton = true
  hasBattleFilter = false

  inactiveGroupId = "group_inactive"
  curBattleInList = null      // selected battle in list
  operationBattle = null      // battle to dasplay, check join enable, join, etc
  needEventHeader = true
  currViewMode = WW_BATTLE_VIEW_MODES.BATTLE_LIST

  battlesListObj = null
  lastBattleListMap = null

  battleDurationTimer = null
  squadListHandlerWeak = null
  queueInfoHandlerWeak = null

  idPrefix = "btn_"

  static function open(battle)
  {
    if (battle.isValid())
    {
      if (!battle.isStillInOperation())
      {
        battle = ::WwBattle()
        ::g_popups.add("", ::loc("worldwar/battle_finished"),
          null, null, null, "battle_finished")
      }
      else if (battle.isAutoBattle())
      {
        battle = ::WwBattle()
        ::g_popups.add("", ::loc("worldwar/battleIsInAutoMode"),
          null, null, null, "battle_in_auto_mode")
      }
    }

    ::handlersManager.loadHandler(::gui_handlers.WwBattleDescription, {
        curBattleInList = battle
        operationBattle = ::WwBattle()
      })
  }

  function getSceneTplContainerObj()
  {
    return scene.findObject("root-box")
  }

  function getSceneTplView()
  {
    return {
      hasGotoGlobalBattlesBtn = true
    }
  }

  function initScreen()
  {
    battlesListObj = scene.findObject("items_list")

    initQueueInfo()

    local queue = ::queues.getActiveQueueWithType(QUEUE_TYPE_BIT.WW_BATTLE)
    if (queue)
    {
      local battleWithQueue = queue.getWWBattle()
      if (battleWithQueue && battleWithQueue.isValid())
        operationBattle = battleWithQueue
    }

    syncSquadCountry()
    reinitBattlesList()
    initSquadList()
  }

  function initQueueInfo()
  {
    local queueInfoObj = scene.findObject("queue_info")
    if (!::check_obj(queueInfoObj))
      return

    local handler = ::handlersManager.loadHandler(::gui_handlers.WwQueueInfo,
      { scene = queueInfoObj })
    registerSubHandler(handler)
    queueInfoHandlerWeak = handler.weakref()
  }

  function initSquadList()
  {
    local squadInfoObj = scene.findObject("squad_info")
    if (!::check_obj(squadInfoObj))
      return

    local handler = ::handlersManager.loadHandler(::gui_handlers.WwSquadList,
      { scene = squadInfoObj })
    registerSubHandler(handler)
    squadListHandlerWeak = handler.weakref()
    updateBattleSquadListData()
  }

  function reinitBattlesList()
  {
    local closedGroups = getClosedGroups()
    local currentBattleListMap = createBattleListMap()
    local needRefillBattleList = hasChangedInBattleListMap(currentBattleListMap)

    lastBattleListMap = currentBattleListMap

    if (!curBattleInList || !curBattleInList.isValid())
      curBattleInList = getFirstBattleInListMap()

    if (needRefillBattleList)
      fillBattleList()
    else
      updateBattlesStatusInList()

    onItemSelect()
    updateClosedGroups(closedGroups)
  }

  function getClosedGroups()
  {
    local closedGroups = []
    if (!lastBattleListMap)
      return closedGroups

    foreach(groupId, groupData in lastBattleListMap)
      if (groupData.isCollapsed)
        closedGroups.append(groupId)

    return closedGroups
  }

  function updateClosedGroups(closedGroups)
  {
    foreach(groupId in closedGroups)
      onCollapse(scene.findObject(idPrefix + groupId))
  }

  function getBattleById(battleId)
  {
    return ::g_world_war.getBattleById(battleId)
  }

  function isBattleValid(battleId)
  {
    return getBattleById(battleId).isValid()
  }

  function updateWindow()
  {
    updateViewMode()
    updateDescription()
    updateSlotbar()
    updateButtons()
    updateCanJoinBattleStatus()
    updateDurationTimer()
  }

  function updateTitle()
  {
    local titleTextObj = scene.findObject("battle_description_frame_text")
    if (!::check_obj(titleTextObj))
      return

    titleTextObj.setValue(currViewMode == WW_BATTLE_VIEW_MODES.BATTLE_LIST ?
      getTitleText() : ::loc("worldwar/prepare_battle"))
  }

  function getTitleText()
  {
    return ::loc("userlog/page/battle")
  }

  function updateDurationTimer()
  {
    if (battleDurationTimer && battleDurationTimer.isValid())
      battleDurationTimer.destroy()

    battleDurationTimer = ::Timer(scene, 1,
      @() updateBattleStatus(operationBattle.getView()), this, true)
  }

  selIdx = -1
  function fillBattleList()
  {
    local view = { items = [] }
    local inactiveBattlesGroup = null
    selIdx = -1

    foreach(groupId, groupData in lastBattleListMap)
      if (groupData.isInactiveBattles)
        inactiveBattlesGroup = groupData
      else
        createBattleListGroupViewData(groupId, groupData, view.items)

    if (inactiveBattlesGroup != null)
      createBattleListGroupViewData(inactiveGroupId, inactiveBattlesGroup, view.items)

    local battleListData = ::handyman.renderCached(sceneTplBattleList, view)
    guiScene.replaceContentFromText(battlesListObj, battleListData, battleListData.len(), this)

    local maxSectorNameWidth = 0
    local sectorNameTextObjs = []
    foreach(item in view.items)
    {
      local sectorNameTxtObj = scene.findObject("mission_item_prefix_text_" + item.id)
      if (::checkObj(sectorNameTxtObj))
      {
        sectorNameTextObjs.append(sectorNameTxtObj)
        maxSectorNameWidth = ::max(maxSectorNameWidth, sectorNameTxtObj.getSize()[0])
      }
    }

    local sectorWidth = maxSectorNameWidth + guiScene.calcString("1@framePadding", null)
    foreach(sectorNameTextObj in sectorNameTextObjs)
      sectorNameTextObj.width = sectorWidth

    local showEmptyBattlesListInfo = !lastBattleListMap.len()
    showSceneBtn("no_active_battles_text", showEmptyBattlesListInfo)
    showSceneBtn("active_country_info", showEmptyBattlesListInfo)
    if (showEmptyBattlesListInfo)
      createActiveCountriesInfo()
  }

  function createBattleListGroupViewData(groupId, groupData, items)
  {
    local view = {
      id = groupId
      itemTag = "group"
      itemText = groupData.text
      isCollapsable = true
    }
    items.append(view)

    local createBattleViewCallback = ::Callback(createBattleListItemView, this)
    local battles = ::u.map(
        groupData.childrenBattles,
        (@(createBattleViewCallback) function(battleData) {
          return createBattleViewCallback(battleData)
        })(createBattleViewCallback)
      )

    battles.sort(
      function(battleA, battleB) {
        if (battleA.itemPrefixText != battleB.itemPrefixText)
          return battleA.itemPrefixText < battleB.itemPrefixText ? -1 : 1
        return 0
      }
    )

    items.extend(battles)
  }

  function createBattleListItemView(battleData)
  {
    local battleView = battleData.getView()
    local view = {
      id = battleData.id.tostring()
      itemTag = "mission_item_unlocked"
      itemPrefixText = getSelectedBattlePrefixText(battleData)
      itemIcon = battleView.getIconImage()
      iconColor = battleView.getIconColor()
      isSelected = curBattleInList.isValid() && battleData.id == curBattleInList.id
    }

    if (battleData.isActive())
      view.itemText <- battleData.getLocName()
    else
    {
      local battleSides = ::g_world_war.getSidesOrder(curBattleInList)
      local teamsData = battleView.getTeamBlockByIconSize(
        getPlayerSide(), battleSides, WW_ARMY_GROUP_ICON_SIZE.SMALL, false,
        {hasArmyInfo = false, hasVersusText = true, canAlignRight = false})
      local teamsMarkUp = ""
      foreach(idx, army in teamsData)
        teamsMarkUp += army.armies.armyViews

      view.additionalDescription <- teamsMarkUp
    }

    return view
  }

  function getSelectedBattlePrefixText(battleData)
  {
    local battleView = battleData.getView()
    local battleName = ::colorize("newTextColor", battleView.getShortBattleName())
    local sectorName = battleData.getSectorName()
    return battleName + (!::u.isEmpty(sectorName) ? " " + sectorName : "")
  }

  function updateBattlesStatusInList()
  {
    local battleObj = null
    local iconObj = null
    foreach (groupId, groupData in lastBattleListMap)
      foreach (idx, battleData in groupData.childrenBattles)
      {
        battleObj = battlesListObj.findObject(battleData.id.tostring())
        if (!::checkObj(battleObj))
          continue

        iconObj = battleObj.findObject("medal_icon")
        if (!::checkObj(iconObj))
          continue

        iconObj.style = "background-color:" + battleData.isActive() ? "@wwTeamAllyColor" : "@wwTeamEnemyColor"
      }
  }

  function updateSlotbar()
  {
    showSceneBtn("nav-slotbar", operationBattle.isActive())
    if (!operationBattle.isActive())
      return

    local playerTeam = operationBattle.getTeamBySide(getPlayerSide())
    ::switch_profile_country(playerTeam.country)
    local availableUnits = operationBattle.getTeamRemainUnits(playerTeam)
    createSlotbar(
      {
        customCountry = playerTeam.country
        availableUnits = availableUnits,
        showTopPanel = false
        gameModeName = operationBattle.getLocName()
        showEmptySlot = true
        needPresetsPanel = true
        beforeCountrySelect = beforeCountrySelect
        shouldCheckCrewsReady = true
      }
    )
  }

  function beforeCountrySelect(onOk, onCancel, countryData)
  {
    local playerTeam = operationBattle.getTeamBySide(getPlayerSide())
    if (countryData.country != playerTeam.country)
    {
      onCancel()
      ::showInfoMsgBox(::loc("worldWar/cantChangeCountryInOperation"))
      return
    }
    onOk()
  }

  function updateDescription()
  {
    local descrObj = scene.findObject("item_desc")
    if (!::check_obj(descrObj))
      return

    local isOperationBattleLoaded = curBattleInList.id == operationBattle.id
    local battle = isOperationBattleLoaded ? operationBattle : curBattleInList
    local battleView = battle.getView()
    local blk = ::handyman.renderCached(sceneTplDescriptionName, battleView)

    guiScene.replaceContentFromText(descrObj, blk, blk.len(), this)

    fillOperationBackground()
    fillOperationInfoText()
    fillNoBattlesText(battle.isValid())

    showSceneBtn("operation_loading_wait_anim", battle.isValid() && !isOperationBattleLoaded)

    if (!battle.isValid() || !isOperationBattleLoaded)
    {
      showSceneBtn("teams_unis", false)
      showSceneBtn("tactical_map_block", false)
      return
    }

    local battleSides = ::g_world_war.getSidesOrder(curBattleInList)
    foreach(idx, side in battleSides)
    {
      local teamObjHeaderInfo = scene.findObject("team_header_info_" + idx)
      if (::check_obj(teamObjHeaderInfo))
      {
        local teamHeaderInfoBlk = ::handyman.renderCached(sceneTplTeamHeaderInfo,
          battleView.getTeamDataBySide(side, battleSides))
        guiScene.replaceContentFromText(teamObjHeaderInfo, teamHeaderInfoBlk, teamHeaderInfoBlk.len(), this)
      }

      local teamObjPlace = scene.findObject("team_unit_info_" + idx)
      if (::check_obj(teamObjPlace))
      {
        local teamBlk = ::handyman.renderCached(sceneTplTeamRight,
          battleView.getTeamDataBySide(side, battleSides))
        guiScene.replaceContentFromText(teamObjPlace, teamBlk, teamBlk.len(), this)
      }
    }

    loadMap(battleSides[0])
    updateBattleStatus(battleView)
    ::show_selected_clusters(scene.findObject("cluster_select_button_text"))
  }

  function fillOperationBackground()
  {
    local battleBgObj = scene.findObject("battle_background")
    if (!::check_obj(battleBgObj))
      return

    battleBgObj["background-image"] = getOperationBackground()
  }

  function getOperationBackground()
  {
    local curOperation = ::g_ww_global_status.getOperationById(::ww_get_operation_id())
    if (!curOperation)
      return WW_OPERATION_DEFAULT_BG_IMAGE

    local curMap = ::g_ww_global_status.getMapByName(curOperation.getMapId())
    if (!curMap)
      return WW_OPERATION_DEFAULT_BG_IMAGE

    return curMap.getBackground()
  }

  function fillOperationInfoText()
  {
  }

  function fillNoBattlesText(isBattleValid)
  {
    local noBattlesTextObj = scene.findObject("no_active_battles_full_text")
    if (!::check_obj(noBattlesTextObj))
      return

    noBattlesTextObj.setValue(getNoBattlesText())
    noBattlesTextObj.show(!isBattleValid)
  }

  function getNoBattlesText()
  {
    return ::loc("worldwar/operation/noActiveBattlesFullText")
  }

  function loadMap(playerSide)
  {
    local tacticalMapObj = scene.findObject("tactical_map_single")
    if (!::checkObj(tacticalMapObj))
      return

    local misFileBlk = null
    local misData = operationBattle.missionInfo
    if (misData != null)
    {
      local missionBlk = ::DataBlock()
      missionBlk.setFrom(misData)

      misFileBlk = ::DataBlock()
      misFileBlk.load(missionBlk.getStr("mis_file",""))
    }
    else
      dagor.debug("Error: WWar: Battle with id=" + operationBattle.id + ": not found mission info for mission " + operationBattle.missionName)

    ::g_map_preview.setMapPreview(tacticalMapObj, misFileBlk)
    local playerTeam = operationBattle.getTeamBySide(playerSide)
    if (playerTeam && "name" in playerTeam)
      ::tactical_map_set_team_for_briefing(::get_mp_team_by_team_name(playerTeam.name))
  }

  function updateViewMode()
  {
    currViewMode = getViewMode()

    showSceneBtn("queue_info", currViewMode == WW_BATTLE_VIEW_MODES.QUEUE_INFO)
    showSceneBtn("items_list", currViewMode == WW_BATTLE_VIEW_MODES.BATTLE_LIST)
    showSceneBtn("squad_info", currViewMode == WW_BATTLE_VIEW_MODES.SQUAD_INFO)

    updateCanJoinBattleStatus()
    updateTitle()
  }

  function getViewMode()
  {
    if (::queues.hasActiveQueueWithType(QUEUE_TYPE_BIT.WW_BATTLE))
      return WW_BATTLE_VIEW_MODES.QUEUE_INFO

    if (::g_squad_manager.isInSquad() &&
        ::g_squad_manager.getWwOperationBattle() &&
        ::g_squad_manager.isMeReady())
      return WW_BATTLE_VIEW_MODES.SQUAD_INFO

    return WW_BATTLE_VIEW_MODES.BATTLE_LIST
  }

  function updateButtons()
  {
    local isJoinBattleVisible = currViewMode != WW_BATTLE_VIEW_MODES.QUEUE_INFO
    local isLeaveBattleVisible = currViewMode == WW_BATTLE_VIEW_MODES.QUEUE_INFO
    local isJoinBattleActive = true
    local isLeaveBattleActive = true
    local battleText = isJoinBattleVisible
      ? ::loc("mainmenu/toBattle")
      : ::loc("mainmenu/btnCancel")

    local cantJoinReasonData = operationBattle.getCantJoinReasonData(getPlayerSide(),
      ::g_squad_manager.isInSquad() && ::g_squad_manager.isSquadLeader())
    local joinWarningData = operationBattle.getWarningReasonData(getPlayerSide())
    local warningText = ""
    local fullWarningText = ""

    if (!::g_squad_manager.isInSquad() || ::g_squad_manager.getOnlineMembersCount() == 1)
    {
      isJoinBattleActive = isJoinBattleVisible && cantJoinReasonData.canJoin
      warningText = getWarningText(cantJoinReasonData, joinWarningData)
      fullWarningText = getFullWarningText(cantJoinReasonData, joinWarningData)
    }
    else
      switch (currViewMode)
      {
        case WW_BATTLE_VIEW_MODES.BATTLE_LIST:
          if (::g_squad_manager.isSquadMember())
          {
            isJoinBattleVisible = !::g_squad_manager.isMeReady()
            isLeaveBattleVisible = ::g_squad_manager.isMeReady()
            battleText = ::g_squad_manager.isMeReady()
              ? ::loc("multiplayer/state/player_not_ready")
              : ::loc("multiplayer/state/player_ready")
          }
          else
          {
            if (canPrerareSquadForBattle(cantJoinReasonData))
            {
              isJoinBattleActive = false
              warningText = cantJoinReasonData.reasonText
            }
            else if (!::g_squad_manager.readyCheck(false))
            {
              isJoinBattleActive = false
              warningText = ::loc("squad/not_all_ready")
            }
          }
          break

        case WW_BATTLE_VIEW_MODES.SQUAD_INFO:
          if (::g_squad_manager.isSquadMember())
          {
            isJoinBattleVisible = !::g_squad_manager.isMyCrewsReady
            isLeaveBattleVisible = ::g_squad_manager.isMyCrewsReady
            battleText = ::g_squad_manager.isMyCrewsReady
              ? ::loc("multiplayer/state/player_not_ready")
              : ::loc("multiplayer/state/crews_ready")
          }
          isJoinBattleActive = cantJoinReasonData.canJoin
          warningText = getWarningText(cantJoinReasonData, joinWarningData)
          fullWarningText = getFullWarningText(cantJoinReasonData, joinWarningData)
          break

        case WW_BATTLE_VIEW_MODES.QUEUE_INFO:
          if (::g_squad_manager.isSquadMember())
          {
            isJoinBattleVisible = false
            isLeaveBattleVisible = true
            isLeaveBattleActive = false
          }
          break
      }

    if (isJoinBattleVisible)
      scene.findObject("btn_join_battle_text").setValue(battleText)
    if (isLeaveBattleVisible)
      scene.findObject("btn_leave_event_text").setValue(battleText)

    local joinButtonObj = showSceneBtn("btn_join_battle", isJoinBattleVisible)
    joinButtonObj.inactiveColor = isJoinBattleActive ? "no" : "yes"
    local leaveButtonObj = showSceneBtn("btn_leave_battle", isLeaveBattleVisible)
    leaveButtonObj.enable(isLeaveBattleActive)

    local warningTextObj = showSceneBtn("cant_join_reason_txt", !::u.isEmpty(warningText))
    warningTextObj.setValue(warningText)

    local warningIconObj = showSceneBtn("warning_icon", !::u.isEmpty(fullWarningText))
    warningIconObj.tooltip = fullWarningText

    showSceneBtn("invite_squads_button",
      hasSquadsInviteButton && ::g_world_war.isSquadsInviteEnable())
    showSceneBtn("hide_unavailable_battles", hasBattleFilter)
    showSceneBtn("goto_global_battles_btn", currViewMode == WW_BATTLE_VIEW_MODES.BATTLE_LIST)

    if (!operationBattle.isValid())
      return

    local unitAvailability = ::g_world_war.getSetting("checkUnitAvailability",
      WW_BATTLE_UNITS_REQUIREMENTS.BATTLE_UNITS)
    showSceneBtn("required_crafts_block",
      unitAvailability == WW_BATTLE_UNITS_REQUIREMENTS.OPERATION_UNITS ||
      unitAvailability == WW_BATTLE_UNITS_REQUIREMENTS.BATTLE_UNITS)
  }

  function getWarningText(cantJoinReasonData, joinWarningData)
  {
    return !cantJoinReasonData.canJoin ? cantJoinReasonData.reasonText
      : joinWarningData.needShow ? joinWarningData.warningText
      : ""
  }

  function getFullWarningText(cantJoinReasonData, joinWarningData)
  {
    return !cantJoinReasonData.canJoin ? cantJoinReasonData.fullReasonText
      : joinWarningData.needShow ? joinWarningData.fullWarningText
      : ""
  }

  function canPrerareSquadForBattle(cantJoinReasonData)
  {
    return !cantJoinReasonData.canJoin &&
           (cantJoinReasonData.code == WW_BATTLE_CANT_JOIN_REASON.WRONG_SIDE ||
            cantJoinReasonData.code == WW_BATTLE_CANT_JOIN_REASON.NOT_ACTIVE)
  }

  function updateCanJoinBattleStatus()
  {
    local battleCanJoinStatusObj = showSceneBtn("battle_can_join_state", operationBattle.isActive())
    if (!operationBattle.isActive() || !::checkObj(battleCanJoinStatusObj))
      return

    local battleView = operationBattle.getView()
    battleCanJoinStatusObj.setValue(battleView.getCanJoinText())
  }

  function updateBattleStatus(battleView)
  {
    local statusObj = scene.findObject("battle_status_text")
    if (::check_obj(statusObj))
      statusObj.setValue(battleView.getBattleStatusWithCanJoinText())

    local battleTimeObj = scene.findObject("battle_time_text")
    if (::check_obj(battleTimeObj) && battleView)
    {
      local battleTimeText = ::loc("worldwar/battleNotActive")
      if (battleView.hasBattleDurationTime())
        battleTimeText = ::loc("debriefing/BattleTime") + ::loc("ui/colon") + battleView.getBattleDurationTime()
      battleTimeObj.setValue(battleTimeText)
    }

    local hasTeamsInfo = battleView.hasTeamsInfo()
    showSceneBtn("teams_info", hasTeamsInfo)
    if (hasTeamsInfo)
    {
      local playersTextObj = scene.findObject("number_of_players")
      if (::check_obj(playersTextObj))
        playersTextObj.setValue(battleView.getTotalPlayersInfoText())
    }
  }

  function onOpenClusterSelect(obj)
  {
    checkedModifyQueue(QUEUE_TYPE_BIT.WW_BATTLE,
      @() ::gui_handlers.ClusterSelect.open(obj, "bottom"))
  }

  function onOpenSquadsListModal(obj)
  {
    ::gui_handlers.WwMyClanSquadInviteModal.open(
      ::ww_get_operation_id(), operationBattle.id, ::get_profile_country_sq())
  }

  function onOpenGlobalBattlesModal(obj)
  {
    msgBox("ask_leave_operation", ::loc("worldwar/gotoGlobalBattlesMsgboxText"),
      [
        ["yes", function() { ::g_world_war.openOperationsOrQueues(true) }],
        ["no", @() null]
      ],
      "yes", { cancel_fn = @() null })
  }

  function onEventClusterChange(params)
  {
    ::show_selected_clusters(scene.findObject("cluster_select_button_text"))
  }

  function goBack()
  {
    if (::g_squad_manager.isInSquad() && ::g_squad_manager.getOnlineMembersCount() > 1)
      switch (currViewMode)
      {
        case WW_BATTLE_VIEW_MODES.SQUAD_INFO:
          if (::g_squad_manager.isSquadLeader())
            msgBox("ask_leave_squad", ::loc("squad/ask/cancel_fight"),
              [
                ["yes", ::Callback(function() {
                    ::g_squad_manager.cancelWwBattlePrepare()
                  }, this)],
                ["no", @() null]
              ],
              "no", { cancel_fn = function() {} })
          else
            msgBox("ask_leave_squad", ::loc("squad/ask/leave"),
              [
                ["yes", ::Callback(function() {
                    ::g_squad_manager.leaveSquad()
                    goBack()
                  }, this)
                ],
                ["no", @() null]
              ],
              "no", { cancel_fn = function() {} })
          return
      }

    base.goBack()
  }

  function onShowHelp(obj)
  {
    if (!::check_obj(obj))
      return

    local side = obj.isPlayerSide == "yes" ?
      getPlayerSide() : ::g_world_war.getOppositeSide(getPlayerSide())

    ::handlersManager.loadHandler(::gui_handlers.WwJoinBattleCondition, {
      battle = operationBattle
      side = side
    })
  }

  function onJoinBattle()
  {
    local side = getPlayerSide()
    local cantJoinReasonData = operationBattle.getCantJoinReasonData(side, false)
    switch (currViewMode)
    {
      case WW_BATTLE_VIEW_MODES.BATTLE_LIST:
        if (!::g_squad_manager.isInSquad() || ::g_squad_manager.getOnlineMembersCount() == 1)
          tryToJoin(side)
        else if (::g_squad_manager.isSquadLeader())
        {
          if (::g_squad_manager.readyCheck(false))
          {
            if (!::has_feature("WorldWarSquadInfo"))
              tryToJoin(side)
            else
            {
              if (canPrerareSquadForBattle(cantJoinReasonData))
                ::showInfoMsgBox(cantJoinReasonData.reasonText)
              else
                ::g_squad_manager.startWWBattlePrepare(operationBattle.id)
            }
          }
          else
            ::showInfoMsgBox(::loc("squad/not_all_ready"))
        }
        else
          ::g_squad_manager.setReadyFlag()
        break

      case WW_BATTLE_VIEW_MODES.SQUAD_INFO:
        if (::g_squad_manager.isSquadLeader())
          tryToJoin(side)
        else
        {
          if (cantJoinReasonData.canJoin)
            tryToSetCrewsReadyFlag()
          else
            ::showInfoMsgBox(cantJoinReasonData.reasonText)
        }
        break
    }
  }

  function tryToJoin(side)
  {
    queueInfoHandlerWeak.hideQueueInfoObj()
    operationBattle.tryToJoin(side)
  }

  function tryToSetCrewsReadyFlag()
  {
    local warningData = operationBattle.getWarningReasonData(getPlayerSide())
    if (warningData.needShow && !::loadLocalByAccount(WW_SKIP_BATTLE_WARNINGS_SAVE_ID, false))
    {
      ::gui_start_modal_wnd(::gui_handlers.SkipableMsgBox,
        {
          parentHandler = this
          message = ::u.isEmpty(warningData.fullWarningText)
            ? warningData.warningText
            : warningData.fullWarningText
          ableToStartAndSkip = true
          onStartPressed = setCrewsReadyFlag
          skipFunc = @(value) ::saveLocalByAccount(WW_SKIP_BATTLE_WARNINGS_SAVE_ID, value)
        })
      return
    }
    setCrewsReadyFlag()
  }

  function setCrewsReadyFlag()
  {
    ::g_squad_manager.setCrewsReadyFlag()
  }

  function onLeaveBattle()
  {
    switch (currViewMode)
    {
      case WW_BATTLE_VIEW_MODES.BATTLE_LIST:
        if (::g_squad_manager.isInSquad() && ::g_squad_manager.isSquadMember())
          ::g_squad_manager.setReadyFlag()
        break

      case WW_BATTLE_VIEW_MODES.SQUAD_INFO:
        if (::g_squad_manager.isInSquad() && ::g_squad_manager.isSquadMember())
          ::g_squad_manager.setCrewsReadyFlag()
        break

      case WW_BATTLE_VIEW_MODES.QUEUE_INFO:
        ::g_world_war.leaveWWBattleQueues()
        ::ww_event("LeaveBattle")
        break
    }
  }

  function onItemSelect()
  {
    refreshSelBattle()
    operationBattle = getBattleById(curBattleInList.id)
    updateBattleSquadListData()
    updateWindow()
  }

  function updateBattleSquadListData()
  {
    local country = null
    local remainUnits = null
    if (operationBattle && operationBattle.isValid())
    {
      local side = getPlayerSide()
      local team = operationBattle.getTeamBySide(side)
      country = team.country
      remainUnits = operationBattle.getUnitsRequiredForJoin(team, side)
    }
    if (squadListHandlerWeak)
      squadListHandlerWeak.updateBattleData(country, remainUnits)
  }

  function refreshSelBattle()
  {
    local idx = battlesListObj.getValue()
    if (idx < 0 || idx >= battlesListObj.childrenCount())
      return

    local opObj = battlesListObj.getChild(idx)
    if(!::checkObj(opObj))
      return

    if(::g_string.indexOf(opObj.id, "group") != ::g_string.INVALID_INDEX)
      return

    local newBattle = getBattleById(opObj.id)
    if (!newBattle.isValid())
      return

    curBattleInList = newBattle
  }

  function syncSquadCountry()
  {
    if (!::g_squad_manager.isInSquad() || ::g_squad_manager.isSquadLeader())
      return
    if (getViewMode() != WW_BATTLE_VIEW_MODES.SQUAD_INFO)
      return

    local squadCountry = ::g_squad_manager.getWwOperationCountry()
    if (!::u.isEmpty(squadCountry) && ::get_profile_country_sq() != squadCountry)
      ::switch_profile_country(squadCountry)
  }

  function onEventSquadDataUpdated(params)
  {
    local wwBattleName = ::g_squad_manager.getWwOperationBattle()
    local squadCountry = ::g_squad_manager.getWwOperationCountry()
    local selectedBattleName = curBattleInList.id
    local prevCurrViewMode = currViewMode
    updateViewMode()

    if (!wwBattleName)
      refreshSelBattle()
    else
    {
      if (!::g_squad_manager.isInSquad() || ::g_squad_manager.getOnlineMembersCount() == 1)
      {
        ::g_squad_manager.cancelWwBattlePrepare()
        return
      }

      local isBattleDifferent = !curBattleInList || curBattleInList.id != wwBattleName
      if (isBattleDifferent)
        curBattleInList = getBattleById(wwBattleName)

      if (!::u.isEmpty(squadCountry) && ::get_profile_country_sq() != squadCountry)
        guiScene.performDelayed(this, function() {
          if (isValid())
            syncSquadCountry()
        })
      else
        if (isBattleDifferent)
          reinitBattlesList()
    }

    if (getPlayerSide() == ::SIDE_NONE)
      return

    if (selectedBattleName != curBattleInList.id)
      updateDescription()

    updateButtons()

    if (prevCurrViewMode == WW_BATTLE_VIEW_MODES.SQUAD_INFO &&
        prevCurrViewMode != currViewMode &&
        ::g_squad_manager.isSquadMember())
    {
      ::g_squad_manager.setCrewsReadyFlag(false)
      ::showInfoMsgBox(::loc("squad/message/cancel_fight"))
    }
  }

  function onEventCrewTakeUnit(params)
  {
    updateButtons()
  }

  function onEventQueueChangeState(params)
  {
    if (getPlayerSide() == ::SIDE_NONE)
      return

    updateViewMode()
    refreshSelBattle()
    updateButtons()
  }

  function onEventSlotbarPresetLoaded(params)
  {
    updateButtons()
  }

  function onEventWWLoadOperation(params)
  {
    reinitBattlesList()
  }

  function onCollapse(obj)
  {
    if (!::checkObj(obj))
      return

    local headerId = ::g_string.slice(obj.id, idPrefix.len())
    local headerData = ::getTblValue(headerId, lastBattleListMap, null)
    if (headerData == null)
      return

    local headerObj = scene.findObject(headerId)
    if (!::checkObj(headerObj))
      return

    guiScene.setUpdatesEnabled(false, false)

    headerData.isCollapsed = !headerData.isCollapsed
    foreach (idx, battleData in headerData.childrenBattles)
      showSceneBtn(battleData.id, !headerData.isCollapsed)

    headerObj.collapsed = headerData.isCollapsed ? "yes" : "no"

    guiScene.setUpdatesEnabled(true, true)
  }

  function getFirstBattleInListMap()
  {
    return ::u.search(::g_world_war.getBattles(),
      ::g_world_war.isBattleAvailableToPlay) || ::WwBattle()
  }

  function createBattleListMap()
  {
    local battles = ::g_world_war.getBattles()
    local currentBattleListMap = {}

    foreach (idx, battleData in battles)
    {
      if (!::g_world_war.isBattleAvailableToPlay(battleData))
        continue

      local armyUnitTypesData = getBattleArmyUnitTypesData(battleData)
      local armyUnitGroupId = armyUnitTypesData.groupId
      if (!(armyUnitGroupId in currentBattleListMap))
        currentBattleListMap[armyUnitGroupId] <- {
          isCollapsed = false
          isInactiveBattles = armyUnitTypesData.isInactiveBattles
          text = armyUnitTypesData.text
          childrenBattles = []
          childrenBattlesIds = []
        }

      local groupBattleList = currentBattleListMap[armyUnitGroupId]
      groupBattleList.childrenBattles.append(battleData)
      groupBattleList.childrenBattlesIds.append(battleData.id)
    }

    return currentBattleListMap
  }

  function createActiveCountriesInfo()
  {
  }

  function getBattleArmyUnitTypesData(battleData)
  {
    local res = {
      text = ""
      groupId = "group_"
      isInactiveBattles = false
    }

    if (!battleData.isActive())
    {
      res.groupId = inactiveGroupId
      res.text = ::colorize("@white", ::loc("worldwar/battleNotActive"))
      res.isInactiveBattles = true
      return res
    }

    local playerSide = getPlayerSide(battleData)
    local team = battleData.getTeamBySide(playerSide)
    foreach(idx, unitType in team.unitTypes)
    {
      res.text += ::colorize("@wwTeamAllyColor", ::g_ww_unit_type.getUnitTypeFontIcon(unitType))
      res.groupId += unitType.tostring()
    }

    res.text += " " + ::colorize("@white", ::loc("country/VS")) + " "
    res.groupId += "vs"

    foreach(idx, team in battleData.teams)
      if (team.side != playerSide)
        foreach(idx, unitType in team.unitTypes)
        {
          res.text += ::colorize("@wwTeamEnemyColor", ::g_ww_unit_type.getUnitTypeFontIcon(unitType))
          res.groupId += unitType.tostring()
        }

    return res
  }

  function getPlayerSide(battle = null)
  {
    return ::ww_get_player_side()
  }

  function hasChangedInBattleListMap(currentBattleListMap)
  {
    if (lastBattleListMap == null)
      return true

    if (currentBattleListMap.len() != lastBattleListMap.len())
      return true

    foreach(groupId, groupData in currentBattleListMap)
    {
      local lastGroupData = ::getTblValue("groupId", lastBattleListMap, null)
      if (lastGroupData == null)
        return true

      if (groupData.childrenBattles.len() != lastGroupData.childrenBattles.len())
        return true

      foreach(idx, battleId in groupData.childrenBattlesIds)
        if (!::isInArray(battleId, lastGroupData.childrenBattlesIds))
          return true
    }

    return false
  }

  function onChangeFilter(obj)
  {
  }
}
