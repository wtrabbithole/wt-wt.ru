class ::gui_handlers.WwBattleDescription extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/modalSceneWithGamercard.blk"
  sceneTplName = "gui/worldWar/battleDescriptionWindow"
  sceneTplBattleList = "gui/missions/missionBoxItemsList"
  sceneTplDescriptionName = "gui/worldWar/battleDescriptionWindowContent"
  sceneTplTeamRight = "gui/worldWar/wwBattleDescriptionTeamUnitsInfo"
  sceneTplTeamHeaderInfo = "gui/worldWar/wwBattleDescriptionTeamInfo"
  sceneTplQueueSideInfo = "gui/worldWar/wwBattleQueueSideInfo"

  inactiveGroupId = "group_inactive"
  battle = null
  needEventHeader = true

  battlesListObj = null
  lastBattleListMap = null

  lastQueueInfoTimeLeft = 0
  battleDurationTimer = null

  static function open(battle)
  {
    if (battle.isValid())
      if (!battle.isStillInOperation() || battle.isAutoBattle())
        battle = ::WwBattle()

    ::handlersManager.loadHandler(::gui_handlers.WwBattleDescription, {battle = battle})
  }

  function getSceneTplContainerObj()
  {
    return scene.findObject("root-box")
  }

  function getSceneTplView()
  {
    return {}
  }

  function initScreen()
  {
    battlesListObj = scene.findObject("items_list")
    local timerObj = scene.findObject("ww_queue_update_timer")

    if (::checkObj(timerObj))
      timerObj.setUserData(this)

    reinitBattlesList()
  }

  function reinitBattlesList()
  {
    local currentBattleListMap = _createBattleListMap()
    local needRefillBattleList = _hasChangedInBattleListMap(currentBattleListMap)

    lastBattleListMap = currentBattleListMap

    if (!battle || !::g_world_war.getBattleById(battle.id).isValid())
      battle = _getFirstBattleInListMap()

    if (needRefillBattleList)
      fillBattleList()
    else
      updateBattlesStatusInList()

    onItemSelect()
  }

  function updateWindow()
  {
    updateDescription()
    updateQueueInfoPanel()
    updateSlotbar()
    updateQueueInfo()
    updateButtons()
    updateCanJoinBattleStatus()
    updateDurationTimer()
  }

  function updateDurationTimer()
  {
    if (battleDurationTimer && battleDurationTimer.isValid())
      battleDurationTimer.destroy()

    battleDurationTimer = ::Timer(scene, 1,
      @() updateBattleStatus(battle.getView()), this, true)
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
        _createBattleListGroupViewData(groupId, groupData, view.items)

    if (inactiveBattlesGroup != null)
      _createBattleListGroupViewData(inactiveGroupId, inactiveBattlesGroup, view.items)

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

    local noBattlesTextObj = scene.findObject("no_active_battles_text")
    if (::check_obj(noBattlesTextObj))
      noBattlesTextObj.show(!lastBattleListMap.len())
  }

  function _createBattleListGroupViewData(groupId, groupData, items)
  {
    local view = {
      id = groupId
      itemTag = "group"
      itemText = groupData.text
      isCollapsable = true
    }
    items.append(view)

    local createBattleViewCallback = ::Callback(_createBattleListItemView, this)
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

  function _createBattleListItemView(battleData)
  {
    local battleView = battleData.getView()
    local battleNumbText = ::colorize("newTextColor", battleView.getShortOrdinalNumberText())
    local view = {
      id = battleData.id.tostring()
      itemTag = "mission_item_unlocked"
      itemPrefixText = battleNumbText + " " + battleData.getSectorName()
      itemIcon = battleView.getIconImage()
      iconColor = battleView.getIconColor()
      isSelected = battle != null && battle.isValid() && battleData.id == battle.id
    }

    if (battleData.isActive())
      view.itemText <- battleData.getLocName()
    else
    {
      local teamsData = battleView.getTeamBlockByIconSize(WW_ARMY_GROUP_ICON_SIZE.BASE)
      local teamsMarkUp = ""
      foreach(idx, army in teamsData)
        teamsMarkUp += army.armies.armyViews

      view.newIconWidgetLayout <- teamsMarkUp
    }

    return view
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
    showSceneBtn("nav-slotbar", battle.isActive())
    if (!battle.isActive())
      return

    local playerTeam = battle.getTeamBySide(::ww_get_player_side())
    ::switch_profile_country(playerTeam.country)
    local availableUnits = battle.getTeamRemainUnits(playerTeam)
    ::init_slotbar(
      this,
      scene.findObject("nav-help"),
      true,
      null,
      {
        limitCountryChoice = true
        customCountry = playerTeam.country
        availableUnits = availableUnits,
        gameModeName = battle.getLocName()
        showEmptySlot = true
        showPresetsPanel = true
      }
    )
  }

  function updateQueueInfoPanel()
  {
    if (!battle.isValid())
      return

    local mySide = ::ww_get_player_side()
    local battleView = battle.getView()

    local side1InfoObj = scene.findObject("SIDE_1_queue_side_info")
    local side1InfoBlk = ::handyman.renderCached(sceneTplQueueSideInfo, battleView.getTeamDataBySide(mySide))

    local side2InfoObj = scene.findObject("SIDE_2_queue_side_info")
    local side2InfoBlk = ::handyman.renderCached(sceneTplQueueSideInfo,
      battleView.getTeamDataBySide(::g_world_war.getOppositeSide(mySide))
    )

    guiScene.replaceContentFromText(side1InfoObj, side1InfoBlk, side1InfoBlk.len(), this)
    guiScene.replaceContentFromText(side2InfoObj, side2InfoBlk, side2InfoBlk.len(), this)
  }

  function updateDescription()
  {
    local descrObj = scene.findObject("item_desc")
    if (!::checkObj(descrObj))
      return

    local battleView = battle.getView()
    local blk = ::handyman.renderCached(sceneTplDescriptionName, battleView)

    guiScene.replaceContentFromText(descrObj, blk, blk.len(), this)

    if (!battle.isValid())
      return

    local noBattlesTextObj = scene.findObject("no_active_battles_full_text")
    if (::check_obj(noBattlesTextObj))
      noBattlesTextObj.show(false)

    local mySide = ::ww_get_player_side()

    foreach(idx, side in ::g_world_war.getSidesOrder())
    {
      local teamObjHeaderInfo = scene.findObject("team_header_info_" + idx)
      if (::check_obj(teamObjHeaderInfo))
      {
        local teamHeaderInfoBlk = ::handyman.renderCached(sceneTplTeamHeaderInfo, battleView.getTeamDataBySide(side))
        guiScene.replaceContentFromText(teamObjHeaderInfo, teamHeaderInfoBlk, teamHeaderInfoBlk.len(), this)
      }

      local teamObjPlace = scene.findObject("team_unit_info_" + idx)
      if (::check_obj(teamObjPlace))
      {
        local teamBlk = ::handyman.renderCached(sceneTplTeamRight, battleView.getTeamDataBySide(side))
        guiScene.replaceContentFromText(teamObjPlace, teamBlk, teamBlk.len(), this)
      }
    }

    loadMap()
    updateBattleStatus(battleView)
    ::show_selected_clusters(scene.findObject("cluster_select_button_text"))
  }

  function loadMap()
  {
    local tacticalMapObj = scene.findObject("tactical_map_single")
    if (!::checkObj(tacticalMapObj))
      return

    local misFileBlk = null
    local misData = battle.missionInfo
    if (misData != null)
    {
      local missionBlk = ::DataBlock()
      missionBlk.setFrom(misData)

      misFileBlk = ::DataBlock()
      misFileBlk.load(missionBlk.getStr("mis_file",""))
    }
    else
      dagor.debug("Error: WWar: Battle with id=" + battle.id + ": not found mission info for mission " + battle.missionName)

    ::g_map_preview.setMapPreview(tacticalMapObj, misFileBlk)
    local playerTeam = battle.getTeamBySide(::ww_get_player_side())
    if (playerTeam && "name" in playerTeam)
      ::tactical_map_set_team_for_briefing(::get_mp_team_by_team_name(playerTeam.name))
  }

  function updateQueueInfo()
  {
    local currentBattleQueue = ::queues.findQueueByName(battle.getQueueId(), true)
    showSceneBtn("queue_info", currentBattleQueue != null)
    showSceneBtn("items_list", currentBattleQueue == null)
    showSceneBtn("ww_queue_update_timer", currentBattleQueue != null)
    updateCanJoinBattleStatus()

    if (currentBattleQueue != null)
      onTimerUpdate(null, 0)
  }

  function onTimerUpdate(obj, dt)
  {
    if (battle == null)
      return

    local currentBattleQueue = ::queues.findQueueByName(battle.getQueueId(), true)
    if (currentBattleQueue == null)
      return

    local currentWaitingTime = ::queues.getQueueActiveTime(currentBattleQueue).tointeger()
    scene.findObject("ww_queue_waiting_time").setValue(::secondsToString(currentWaitingTime, false))

    lastQueueInfoTimeLeft += dt
    if (lastQueueInfoTimeLeft <= 5)
      return

    lastQueueInfoTimeLeft = 0
    updateBattlesStatusInList()

    ::queues.updateQueueInfoByType(::g_queue_type.WW_BATTLE, ::Callback(updateWWQueuesInfoSuccessCallback, this))
  }

  function updateWWQueuesInfoSuccessCallback(queueInfo)
  {
    local currentBattleQueueInfo = ::getTblValue(battle.id, queueInfo, null)

    local mySide = ::ww_get_player_side()
    local myTeamName = "team" + battle.getTeamNameBySide(mySide)
    local enemyTeamName = "team" + battle.getTeamNameBySide(::g_world_war.getOppositeSide(mySide))

    updateQueueSideInfoBySide("SIDE_1_queue_side_info", currentBattleQueueInfo, myTeamName)
    updateQueueSideInfoBySide("SIDE_2_queue_side_info", currentBattleQueueInfo, enemyTeamName)
  }

  function updateQueueSideInfoBySide(objectId, currentBattleQueueInfo, teamName)
  {
    local sideInfoObj = scene.findObject(objectId)
    local sideInfoClanPlayers = sideInfoObj.findObject("players_in_clans_count")
    sideInfoClanPlayers.setValue(getPlayersCountFromBattleQueueInfo(currentBattleQueueInfo, teamName, "playersInClans"))

    local sideInfoOtherPlayers = sideInfoObj.findObject("other_players_count")
    sideInfoOtherPlayers.setValue(getPlayersCountFromBattleQueueInfo(currentBattleQueueInfo, teamName, "playersOther"))
  }

  function getPlayersCountFromBattleQueueInfo(battleQueueInfo, teamName, field)
  {
    if (battleQueueInfo == null)
      return ::loc("event_dash")

    local teamData = ::getTblValue(teamName, battleQueueInfo, null)
    if (field == "playersInClans")
    {
      local clanPlayerCount = 0
      local clanPlayers = ::getTblValue(field, teamData, [])
      foreach(clanPlayerData in clanPlayers)
        clanPlayerCount += ::getTblValue("count", clanPlayerData, 0)

      return clanPlayerCount.tostring()
    }
    else if (field == "playersOther")
    {
      local count = ::getTblValue(field, teamData, 0)
      return count.tostring()
    }

    return 0
  }

  function updateButtons()
  {
    local queueIsActive = ::queues.hasActiveQueueWithType(QUEUE_TYPE_BIT.WW_BATTLE)

    showSceneBtn("btn_leave_battle", queueIsActive)
    local joinBattleButtonObj = showSceneBtn("btn_join_battle", !queueIsActive)

    if (!queueIsActive)
    {
      local cantJoinReasonData = battle.getCantJoinReasonData(null, false)
      local cantJoinReasonTextObj = showSceneBtn("cant_join_reason_txt", !cantJoinReasonData.canJoin)
      cantJoinReasonTextObj.setValue(::u.isEmpty(cantJoinReasonData.shortReasonText) ? cantJoinReasonData.reasonText
                                                                                     : cantJoinReasonData.shortReasonText)

      joinBattleButtonObj.inactiveColor = cantJoinReasonData.canJoin ? "no" : "yes"
      if (!cantJoinReasonData.canJoin)
        return

      local needShowWarningData = battle.getWarningReasonData()
      cantJoinReasonTextObj.show(needShowWarningData.needShow)
      if (needShowWarningData.needShow)
        cantJoinReasonTextObj.setValue(needShowWarningData.warningText)
    }
    else
    {
      showSceneBtn("cant_join_reason_txt", false)
    }
  }

  function updateCanJoinBattleStatus()
  {
    local battleCanJoinStatusObj = showSceneBtn("battle_can_join_state", battle.isActive())
    if (!battle.isActive() || !::checkObj(battleCanJoinStatusObj))
      return

    local battleView = battle.getView()
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
  }

  function onOpenClusterSelect(obj)
  {
    checkedModifyQueue(QUEUE_TYPE_BIT.WW_BATTLE,
      @() ::gui_handlers.ClusterSelect.open(obj, "bottom"))
  }

  function onEventClusterChange(params)
  {
    ::show_selected_clusters(scene.findObject("cluster_select_button_text"))
  }

  function onJoinBattle()
  {
    battle.join()
  }

  function onLeaveBattle()
  {
    ::g_world_war.leaveWWBattleQueues()
    ::ww_event("LeaveBattle")
  }

  function onItemSelect()
  {
    refreshSelBattle()
    updateWindow()
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

    local newBattle = ::g_world_war.getBattleById(opObj.id)
    if (!newBattle.isValid())
      return

    battle = newBattle
  }

  function onEventSquadDataUpdated(params)
  {
    updateButtons()
  }

  function onEventCrewTakeUnit(params)
  {
    updateButtons()
  }

  function onEventQueueChangeState(params)
  {
    refreshSelBattle()
    updateButtons()
    updateQueueInfo()
  }

  function onEventPresetUpdated(params)
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

    local idPrefix = "btn_"
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

  function _getFirstBattleInListMap()
  {
    return ::u.search(::g_world_war.getBattles(),
      ::g_world_war.isBattleAvailableToPlay) || ::WwBattle()
  }

  function _createBattleListMap()
  {
    local battles = ::g_world_war.getBattles()
    local currentBattleListMap = {}

    foreach (idx, battleData in battles)
    {
      if (!::g_world_war.isBattleAvailableToPlay(battleData))
        continue

      local armyUnitTypesData = _getBattleArmyUnitTypesData(battleData)
      if (!(armyUnitTypesData.groupId in currentBattleListMap))
        currentBattleListMap[armyUnitTypesData.groupId] <- {
          isCollapsed = false
          isInactiveBattles = armyUnitTypesData.isInactiveBattles
          text = armyUnitTypesData.text
          childrenBattles = []
          childrenBattlesIds = []
        }

      currentBattleListMap[armyUnitTypesData.groupId].childrenBattles.append(battleData)
      currentBattleListMap[armyUnitTypesData.groupId].childrenBattlesIds.append(battleData.id)
    }

    return currentBattleListMap
  }

  function _getBattleArmyUnitTypesData(battleData)
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

    local team = battleData.getTeamBySide(::ww_get_player_side())
    foreach(idx, unitType in team.unitTypes)
    {
      res.text += ::colorize("@wwTeamAllyColor", ::g_ww_unit_type.getUnitTypeFontIcon(unitType))
      res.groupId += unitType.tostring()
    }

    res.text += " " + ::colorize("@white", ::loc("country/VS")) + " "
    res.groupId += "vs"

    foreach(idx, team in battleData.teams)
      if (team.side != ::ww_get_player_side())
        foreach(idx, unitType in team.unitTypes)
        {
          res.text += ::colorize("@wwTeamEnemyColor", ::g_ww_unit_type.getUnitTypeFontIcon(unitType))
          res.groupId += unitType.tostring()
        }

    return res
  }

  function _hasChangedInBattleListMap(currentBattleListMap)
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
}
