class ::gui_handlers.WwMap extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName = "gui/worldWar/worldWarMap.blk"
  operationStringTpl = "gui/worldWar/operationString"

  UPDATE_ARMY_STRENGHT_DELAY = 60000

  needUpdateSidesStrenghtView = false

  currentOperationInfoTabType = null
  currentReinforcementInfoTabType = null
  mainBlockHandler = null
  reinforcementBlockHandler = null
  needReindforcementsUpdate = false
  currentSelectedObject = null
  objectiveHandler = null
  timerDescriptionHandler = null
  highlightZonesTimer = null
  updateLogsTimer = null
  checkJoinEnabledTimer = null

  armyStrengthUpdateTimeRemain = 0
  isArmiesPathSwitchedOn = false
  leftSectionHandlerWeak = null

  static renderFlagPID = ::dagui_propid.add_name_id("_renderFlag")

  gamercardTopIds = [ //OVERRIDE
    "top_menu_panel_place"
    "gamercard_panel_left"
    "gamercard_panel_right"
    function() { return rightSectionHandlerWeak && rightSectionHandlerWeak.getFocusObj() }
  ]

  renderCheckBoxesList = [
    {id = "render_zones", renderCategory = ::ERC_ZONES, image = "#ui/gameuiskin#render_zones"}
    {id = "render_arrows", renderCategory = ::ERC_ALL_ARROWS, hidden = true}
    {id = "render_arrows_for_selected", renderCategory = ::ERC_ARROWS_FOR_SELECTED_ARMIES, image = "#ui/gameuiskin#render_arrows"}
    {id = "render_battles", renderCategory = ::ERC_BATTLES, image = "#ui/gameuiskin#battles_open"}
    {id = "render_map_picture", renderCategory = ::ERC_MAP_PICTURE, hidden = true}
  ]

  function initScreen()
  {
    backSceneFunc = ::gui_start_mainmenu
    ::g_world_war_render.init()
    registerSubHandler(::handlersManager.loadHandler(::gui_handlers.wwMapTooltip,
      { scene = scene.findObject("hovered_map_object_info"),
        controllerScene = scene.findObject("hovered_map_object_controller") }))

    leftSectionHandlerWeak = ::gui_handlers.TopMenuButtonsHandler.create(
      scene.findObject("topmenu_menu_panel"),
      this, ::g_ww_top_menu_left_side_sections)
    registerSubHandler(leftSectionHandlerWeak)

    showSceneBtn("ww_map_render_filters", true)
    initMapName()
    initOperationStatus(false)
    initGCBottomBar()
    initToBattleButton()
    initArmyControlButtons()
    initControlBlockVisibiltiySwitch()
    initPageSwitch()
    initReinforcementPageSwitch()
    setCurrentSelectedObject(mapObjectSelect.NONE)
    initFocusArray()
    markMainObjectiveZones()

    ::g_ww_logs.lastReadLogMark = ::loadLocalByAccount(::g_world_war.getSaveOperationLogId(), "")
    ::g_ww_logs.requestNewLogs(WW_LOG_MAX_LOAD_AMOUNT, !::g_ww_logs.loaded.len())

    scene.findObject("update_timer").setUserData(this)
    if (::g_world_war_render.isCategoryEnabled(::ERC_ARMY_RADIUSES))
      ::g_world_war_render.setCategory(::ERC_ARMY_RADIUSES, false)
  }

  function initMapName()
  {
    local headerObj = scene.findObject("operation_name")
    if (!::check_obj(headerObj))
      return

    local curOperation = ::g_ww_global_status.getOperationById(::ww_get_operation_id())
    headerObj.setValue(curOperation? curOperation.getNameText() : "")
  }

  function initControlBlockVisibiltiySwitch()
  {
    local obj = getObj("control_block_visibility_switch")
    if (!::check_obj(obj))
      return

    local show = ::screen_width() / ::screen_height() < 1.5
    obj.show(show)
    obj.setValue(true)
    onChangeInfoBlockVisibility(obj)
  }

  function initPageSwitch()
  {
    local pagesObj = scene.findObject("pages_list")
    if (!::checkObj(pagesObj))
      return

    pagesObj.setValue(currentOperationInfoTabType? currentOperationInfoTabType.index : 0)
    onPageChange(pagesObj)
  }

  function onPageChange(obj)
  {
    currentOperationInfoTabType = ::g_ww_map_info_type.getTypeByIndex(obj.getValue())
    showSceneBtn("content_block_2", currentOperationInfoTabType == ::g_ww_map_info_type.OBJECTIVE)
    updatePage()
  }


  function onReinforcementTabChange(obj)
  {
    currentReinforcementInfoTabType = ::g_ww_map_reinforcement_tab_type.getTypeByCode(obj.getValue())

    if (currentSelectedObject == mapObjectSelect.REINFORCEMENT)
      setCurrentSelectedObject(mapObjectSelect.NONE)

    updateSecondaryBlock()
    updateSecondaryBlockTabs()
  }


  function initReinforcementPageSwitch()
  {
    local tabsObj = scene.findObject("reinforcement_pages_list")
    if (!::check_obj(tabsObj))
      return

    tabsObj.setValue(0)
    onReinforcementTabChange(tabsObj)

    local show = ::g_world_war.haveManagementAccessForAnyGroup()
    showSceneBtn("reinforcements_block", show)
    showSceneBtn("armies_block", show)
    if (show)
      updateSecondaryBlockTab(::g_ww_map_reinforcement_tab_type.REINFORCEMENT)
  }

  function updatePage()
  {
    updateMainBlock()
    updateSecondaryBlock()
  }

  function updateMainBlock()
  {
    local operationBlockObj = scene.findObject("selected_page_block")
    if (!::checkObj(operationBlockObj))
      return

    mainBlockHandler = currentOperationInfoTabType.getMainBlockHandler(operationBlockObj, ::ww_get_player_side())
    if (mainBlockHandler)
      registerSubHandler(mainBlockHandler)
  }

  function updateSecondaryBlockTabs()
  {
    local blockObj = scene.findObject("reinforcement_pages_list")
    if (!::checkObj(blockObj))
      return

    foreach (tab in ::g_ww_map_reinforcement_tab_type.types)
      updateSecondaryBlockTab(tab, blockObj)
  }

  function updateSecondaryBlockTab(tab, blockObj = null)
  {
    blockObj = blockObj || scene.findObject("reinforcement_pages_list")
    if (!::checkObj(blockObj))
      return

    local tabId = ::getTblValue("tabId", tab, "")
    local tabObj = blockObj.findObject(tabId + "_text")
    if (!::checkObj(tabObj))
      return

    local tabName = ::loc(::getTblValue("tabIcon", tab, ""))
    if (currentReinforcementInfoTabType == tab)
      tabName += " " + ::loc(::getTblValue("tabText", tab, ""))

    tabObj.setValue(tabName + tab.getTabTextPostfix())
  }

  function updateSecondaryBlock()
  {
    if (!currentReinforcementInfoTabType || !isSecondaryBlockVisible())
      return

    local commandersObj = scene.findObject("reinforcement_block")
    if (!::checkObj(commandersObj))
      return

    reinforcementBlockHandler = currentReinforcementInfoTabType.getHandler(commandersObj)
    if (reinforcementBlockHandler)
      registerSubHandler(reinforcementBlockHandler)
  }

  function isSecondaryBlockVisible()
  {
    local secondaryBlockObj = scene.findObject("content_block_2")
    return ::check_obj(secondaryBlockObj) && secondaryBlockObj.isVisible()
  }

  function initGCBottomBar()
  {
    local obj = scene.findObject("gamercard_bottom_navbar_place")
    if (!::checkObj(obj))
      return
    guiScene.replaceContent(obj, "gui/worldWar/worldWarMapGCBottom.blk", this)
  }

  function initArmyControlButtons()
  {
    local obj = scene.findObject("ww_army_controls_place")
    if (!::checkObj(obj))
      return

    local markUp = ""
    foreach (buttonView in ::g_ww_map_controls_buttons.types)
      markUp += ::handyman.renderCached("gui/commonParts/button", buttonView)

    guiScene.replaceContentFromText(obj, markUp, markUp.len(), this)
  }

  function updateArmyActionButtons()
  {
    local obj = scene.findObject("ww_army_controls_place")
    if (!::checkObj(obj))
      return

    local hasAccess = false
    if (currentSelectedObject == mapObjectSelect.AIRFIELD ||
        currentSelectedObject == mapObjectSelect.REINFORCEMENT)
      hasAccess = true
    else if (currentSelectedObject == mapObjectSelect.ARMY ||
             currentSelectedObject == mapObjectSelect.LOG_ARMY)
      hasAccess = ::g_world_war.haveManagementAccessForSelectedArmies()

    local showAny = false
    foreach (buttonView in ::g_ww_map_controls_buttons.types)
    {
      local showButton = hasAccess && !buttonView.isHidden()
      local buttonObj = ::showBtn(buttonView.id, showButton, obj)
      if (::checkObj(buttonObj))
      {
        buttonObj.enable(buttonView.isEnabled())
        buttonObj.setValue(buttonView.text())
      }

      showAny = showAny || showButton
    }
    obj.show(showAny)
  }

  function initToBattleButton()
  {
    showSceneBtn("gamercard_center", false)
    local toBattleNest = scene.findObject("gamercard_tobattle")
    if (::checkObj(toBattleNest))
    {
      local toBattleBlk = ::handyman.renderCached("gui/mainmenu/toBattleButton", {
        enableEnterKey = !::is_platform_shield_tv()
      })
      guiScene.replaceContentFromText(toBattleNest, toBattleBlk, toBattleBlk.len(), this)
    }
    showSceneBtn("gamercard_logo", false)

    updateToBattleButton()
  }

  function updateToBattleButton()
  {
    local toBattleButtonObj = scene.findObject("to_battle_button")
    if (!::checkObj(scene) || !::checkObj(toBattleButtonObj))
      return

    local isOperationContinue = !::g_world_war.isCurrentOperationFinished()
    local isInQueue = isOperationContinue && ::queues.isAnyQueuesActive(queueType.WW_BATTLE)
    local isSquadMember = isOperationContinue && ::g_squad_manager.isSquadMember()

    local txt = ::loc("mainmenu/toBattle")
    local isCancel = false

    if (isSquadMember)
    {
      local isReady = ::g_squad_manager.isMeReady()
      txt = ::loc(isReady ? "multiplayer/btnNotReady" : "mainmenu/btnReady")
      isCancel = isReady
    }
    else if (isInQueue)
    {
      txt = ::loc("mainmenu/btnCancel")
      isCancel = true
    }

    local enable = isOperationContinue && ::g_world_war.getBattles().len() > 0
    toBattleButtonObj.inactiveColor = enable? "no" : "yes"
    toBattleButtonObj.setValue(txt)
    toBattleButtonObj.findObject("to_battle_button_text").setValue(txt)
    toBattleButtonObj.isCancel = isCancel ? "yes" : "no"
  }

  function onStart()
  {
    if (::g_world_war.isCurrentOperationFinished())
      return ::showInfoMsgBox(::loc("worldwar/operation_complete"))

    local isSquadMember = ::g_squad_manager.isSquadMember()
    if (isSquadMember)
      return ::g_squad_manager.setReadyFlag()

    local isInOperationQueue = ::queues.isAnyQueuesActive(queueType.WW_BATTLE)
    if (isInOperationQueue)
      return ::g_world_war.leaveWWBattleQueues()

    local playerSide = ::ww_get_player_side()
    if (playerSide == ::SIDE_NONE)
      return ::showInfoMsgBox(::loc("msgbox/internal_error_header"))

    local allBattles = ::g_world_war.getBattles()
    if (allBattles.len() == 0)
      return ::showInfoMsgBox(::loc("worldwar/no_battles_now"))

    local availableBattles = ::g_world_war.getAvailableBattles(playerSide)
    if (availableBattles.len() > 0)
    {
      local battle = ::u.chooseRandom(availableBattles)
      ::gui_handlers.WwBattleDescription.open(battle)
      if (availableBattles.len() == 1)
        battle.join(playerSide)
      return
    }

    ::gui_handlers.WwBattleDescription.open(allBattles[0])
  }

  function goBackToOperations()
  {
    backSceneFunc = function()
    {
      ::g_world_war.openOperationsOrQueues()
    }
    goBackToHangar()
  }

  function goBackToHangar()
  {
    ::queues.leaveQueueByType(queueType.WW_BATTLE)
    ::ww_service.unsubscribeOperation(::ww_get_operation_id())
    ::g_world_war.stopWar()
    base.goBack()
  }

  function onEventMatchingConnect(params)
  {
    ::ww_service.unsubscribeOperation(::ww_get_operation_id())
    ::ww_service.subscribeOperation(::ww_get_operation_id())
  }

  function onArmyMove(obj)
  {
    local cursorPos = ::get_dagui_mouse_cursor_pos()

    if (currentSelectedObject == mapObjectSelect.ARMY ||
        currentSelectedObject == mapObjectSelect.LOG_ARMY)
      ::g_world_war.moveSelectedArmes(cursorPos[0], cursorPos[1],
        ::ww_find_army_name_by_coordinates(cursorPos[0], cursorPos[1]))
    else if (currentSelectedObject == mapObjectSelect.REINFORCEMENT)
      ::ww_event("MapRequestReinforcement", {
        cellIdx = ::ww_get_map_cell_by_coords(cursorPos[0], cursorPos[1])
      })
    else if (currentSelectedObject == mapObjectSelect.AIRFIELD)
    {
      local mapObj = scene.findObject("worldwar_map")
      if (!::checkObj(mapObj))
        return

      ::ww_gui_bhv.worldWarMapControls.onMoveCommand.call(
        ::ww_gui_bhv.worldWarMapControls, mapObj, ::Point2(cursorPos[0], cursorPos[1]), false
      )
    }
  }

  function onArmyStop(obj)
  {
    ::g_world_war.stopSelectedArmy()
  }

  function onArmyEntrench(obj)
  {
    ::g_world_war.entrenchSelectedArmy()
  }

  function onArtilleryArmyPrepareToFire(obj)
  {
    if (::ww_artillery_strike_mode_on())
    {
      setArtilleryArmyFireMode(false)
      return
    }

    local armiesNames = ::ww_get_selected_armies_names()
    if (!armiesNames.len())
      return

    if (armiesNames.len() > 1)
      return ::g_popups.add(::loc("worldwar/artillery/cant_fire"),
                            ::loc("worldwar/artillery/selectOneArmy"),
                            null, null, null, "select_one_army")

    setArtilleryArmyFireMode(true)
  }

  function onArtilleryArmyCancelFire(obj)
  {
    setArtilleryArmyFireMode(false)
  }

  function setArtilleryArmyFireMode(isEnabled)
  {
    ::ww_artillery_turn_fire(isEnabled)
    updateArmyActionButtons()
    local cancelFireBtnObj = scene.findObject("cancel_artillery_fire")
    if (::check_obj(cancelFireBtnObj))
      cancelFireBtnObj.enable(isEnabled)
  }

  function onForceShowArmiesPath(obj)
  {
    isArmiesPathSwitchedOn = ::g_world_war_render.isCategoryEnabled(::ERC_ARROWS_FOR_SELECTED_ARMIES)
    if (isArmiesPathSwitchedOn)
      ::g_world_war_render.setCategory(::ERC_ARROWS_FOR_SELECTED_ARMIES, false)
  }

  function onRemoveForceShowArmiesPath(obj)
  {
    if (isArmiesPathSwitchedOn != ::g_world_war_render.isCategoryEnabled(::ERC_ARROWS_FOR_SELECTED_ARMIES))
      ::g_world_war_render.setCategory(::ERC_ARROWS_FOR_SELECTED_ARMIES, true)
  }

  function onShowMapRenderFilters(obj)
  {
    onRemoveForceShowArmiesPath(null)
    local optionsList = []
    foreach(renderData in renderCheckBoxesList)
    {
      local id = renderData.id
      local category = renderData.renderCategory
      optionsList.append({
        value = category
        selected = ::g_world_war_render.isCategoryEnabled(category)
        show = ::g_world_war_render.isCategoryVisible(category) && !::getTblValue("hidden", renderData, false)
        text = ::loc("worldwar/renderMap/" + id, id)
        icon = ::getTblValue("image", renderData, "#ui/gameuiskin#slot_weapons")
      })
    }

    optionsList.append({
      value = "d_mode"
      selected = ::g_world_war.isDebugModeEnabled()
      show = ::has_feature("worldWarMaster")
      text = "Debug Mode"
      icon = "#ui/gameuiskin#battles_closed"
    })

    ::gui_start_multi_select_menu({
      list = optionsList
      onChangeValueCb = function(values) {
        foreach(renderData in renderCheckBoxesList)
        {
          local category = renderData.renderCategory
          local enable = ::isInArray(category, values)
          if (enable != ::g_world_war_render.isCategoryEnabled(category))
            ::g_world_war_render.setCategory(category, enable)
        }
        local debugModeEnable = ::isInArray("d_mode", values)
        if (debugModeEnable != ::g_world_war.isDebugModeEnabled())
          ::g_world_war.setDebugMode(debugModeEnable)
      }.bindenv(this)
      align = "bottom"
      alignObj = scene.findObject("ww_map_render_filters")
      sndSwitchOn = "check"
      sndSwitchOff = "uncheck"
    })
  }

  function collectArmyStrengthData()
  {
    local result = {}
    local collectedUnits = {}

    local currentStrenghtInfo = ::g_world_war.getSidesStrenghtInfo()
    for (local side = ::SIDE_NONE; side < ::SIDE_TOTAL; side++)
    {
      if (!(side in currentStrenghtInfo))
        continue

      local sideName = ::ww_side_val_to_name(side)
      local armyGroups = ::g_world_war.getArmyGroupsBySide(side)
      if (!armyGroups.len())
        continue

      if (!(sideName in result))
        result[sideName] <- {}

      if (!("country" in result[sideName]))
        result[sideName].country <- []

      foreach(group in armyGroups)
      {
        local country = group.getArmyCountry()
        if (!::isInArray(country, result[sideName].country))
          result[sideName].country.append(country)
      }

      result[sideName].units <- currentStrenghtInfo[side]
    }

    return result
  }

  function collectUnitsData(formationsArray)
  {
    local unitsList = []
    foreach(formation in formationsArray)
      unitsList.extend(formation.getUnits())

    return ::g_world_war.collectUnitsData(unitsList, false)
  }

  function markMainObjectiveZones()
  {
    local objectivesBlk = ::g_world_war.getOperationObjectives()
    if (!objectivesBlk)
      return

    local staticBlk = ::u.copy(objectivesBlk.data) || ::DataBlock()
    local dynamicBlk = ::u.copy(objectivesBlk.status) || ::DataBlock()

    local playerSideName = ::ww_side_val_to_name(::ww_get_player_side())
    for (local i = 0; i < staticBlk.blockCount(); i++)
    {
      local statBlk = staticBlk.getBlock(i)
      if (!statBlk.mainObjective || !statBlk.defenderSide == playerSideName)
        continue

      local type = ::g_ww_objective_type.getTypeByTypeName(statBlk.type)
      if (type != ::g_ww_objective_type.OT_CAPTURE_ZONE)
        continue

      local dynBlock = dynamicBlk[statBlk.getBlockName()]
      if (!dynBlock)
        continue

      local zones = type.getUpdatableZonesParams(
        dynBlock, statBlk, ::ww_side_val_to_name(::ww_get_player_side())
      )
      if (!zones.len())
        continue

      for (local i = WW_MAP_HIGHLIGHT.LAYER_0; i<= WW_MAP_HIGHLIGHT.LAYER_2; i++)
      {
        local zonesArray = ::u.map(zones, (@(i) function(zone) {
          if (zone.mapLayer == i)
            return zone.id
        })(i))
        ::ww_highlight_zones_by_name(zonesArray, i)
      }
    }
  }

  function showSidesStrenght()
  {
    local blockObj = scene.findObject("content_block_3")
    local armyStrengthData = collectArmyStrengthData()

    local orderArray = ::g_world_war.getSidesOrder()

    local side1Name = ::ww_side_val_to_name(orderArray.len()? orderArray[0] : ::SIDE_NONE)
    local side1Data = ::getTblValue(side1Name, armyStrengthData, {})

    local side2Name = ::ww_side_val_to_name(orderArray.len() > 1? orderArray[1] : ::SIDE_NONE)
    local side2Data = ::getTblValue(side2Name, armyStrengthData, {})

    local view = {
      armyCountryImg1 = ::u.map(side1Data.country, function(country) { return {image = ::get_country_icon(country)}})
      armyCountryImg2 = ::u.map(side2Data.country, function(country) { return {image = ::get_country_icon(country)}})
      unitString = []
    }

    local armyStrengthsTable = {}
    local armyStrengths = []
    foreach (sideName, army in armyStrengthData)
      foreach (wwUnit in army.units)
        if (wwUnit.isValid())
        {
          local strenght = ::getTblValue(wwUnit.stengthGroupExpClass, armyStrengthsTable)
          if (!strenght)
          {
            strenght = {
              unitIcon = wwUnit.getWwUnitClassIco()
              unitName = wwUnit.getUnitStrengthGroupTypeText()
              shopItemType = wwUnit.getUnitRole()
              count = 0
            }
            strenght[side1Name] <- 0
            strenght[side2Name] <- 0

            armyStrengthsTable[wwUnit.stengthGroupExpClass] <- strenght
            armyStrengths.append(strenght)
          }

          strenght[sideName] += wwUnit.count
          strenght.count += wwUnit.count
        }

    foreach (idx, strength in armyStrengths)
    {
      view.unitString.append({
        unitIcon = strength.unitIcon
        unitName = strength.unitName
        shopItemType = strength.shopItemType
        side1UnitCount = strength[side1Name]
        side2UnitCount = strength[side2Name]
      })
    }

    local data = ::handyman.renderCached("gui/worldWar/worldWarMapSidesStrenght", view)
    guiScene.replaceContentFromText(blockObj, data, data.len(), this)

    needUpdateSidesStrenghtView = false
  }

  function showSelectedArmy()
  {
    local blockObj = scene.findObject("content_block_3")
    local selectedArmyNames = ::ww_get_selected_armies_names()
    if (!selectedArmyNames.len())
      return

    local selectedArmy = ::g_world_war.getArmyByName(selectedArmyNames[0])
    if (!selectedArmy.isValid())
    {
      ::ww_event("MapClearSelection")
      return
    }

    local data = ::handyman.renderCached("gui/worldWar/worldWarMapArmyInfo", selectedArmy.getView())
    guiScene.replaceContentFromText(blockObj, data, data.len(), this)

    if (timerDescriptionHandler)
    {
      timerDescriptionHandler.destroy()
      timerDescriptionHandler = null
    }

    if (!selectedArmy.needUpdateDescription())
      return

    timerDescriptionHandler = ::Timer(blockObj, 1, (@(blockObj, selectedArmy) function() {
      updateSelectedArmy(blockObj, selectedArmy)
    })(blockObj, selectedArmy), this, true)
  }

  function showSelectedLogArmy(params)
  {
    local blockObj = scene.findObject("content_block_3")
    if (!::check_obj(blockObj) || !("wwArmy" in params))
      return

    local data = ::handyman.renderCached("gui/worldWar/worldWarMapArmyInfo", params.wwArmy.getView())
    guiScene.replaceContentFromText(blockObj, data, data.len(), this)
  }

  function updateSelectedArmy(blockObj, selectedArmy)
  {
    blockObj = blockObj || scene.findObject("content_block_3")
    if (!::check_obj(blockObj) || !selectedArmy)
      return

    local armyView = selectedArmy.getView()
    foreach (fieldId, func in armyView.getRedrawArmyStatusData())
    {
      local redrawFieldObj = blockObj.findObject(fieldId)
      if (::check_obj(redrawFieldObj))
        redrawFieldObj.setValue(func.call(armyView))
    }

    updateArmyActionButtons()
  }

  function showSelectedReinforcement(params)
  {
    local blockObj = scene.findObject("content_block_3")
    local reinforcement = ::g_world_war.getReinforcementByName(::getTblValue("name", params))
    if (!reinforcement)
      return

    local reinfView = reinforcement.getView()
    local data = ::handyman.renderCached("gui/worldWar/worldWarMapArmyInfo", reinfView)
    guiScene.replaceContentFromText(blockObj, data, data.len(), this)
  }

  function showSelectedAirfield(params)
  {
    if (currentReinforcementInfoTabType != ::g_ww_map_reinforcement_tab_type.AIRFIELDS)
      return

    if (!getTblValue("formationType", params) ||
        getTblValue("formationId", params, -1) < 0)
      return

    local airfield = ::g_world_war.getAirfieldByIndex(::ww_get_selected_airfield())
    local formation = null

    if (params.formationType == "formation")
    {
      formation = params.formationId == WW_ARMY_RELATION_ID.CLAN ?
        airfield.clanFormation : airfield.allyFormation
    }
    else if (params.formationType == "cooldown")
    {
      if (airfield.cooldownFormations.len() > params.formationId)
        formation = airfield.cooldownFormations[params.formationId]
    }

    if (!formation)
    {
      reinforcementBlockHandler.selectDefaultFormation()
      return
    }

    local blockObj = scene.findObject("content_block_3")
    local data = ::handyman.renderCached("gui/worldWar/worldWarMapArmyInfo", formation.getView())
    guiScene.replaceContentFromText(blockObj, data, data.len(), this)
  }

  function setCurrentSelectedObject(value, params = {})
  {
    local lastSelectedOject = currentSelectedObject
    currentSelectedObject = value
    ::g_ww_map_controls_buttons.setSelectedObjectCode(currentSelectedObject)

    if (currentSelectedObject == mapObjectSelect.ARMY)
      showSelectedArmy()
    else if (currentSelectedObject == mapObjectSelect.REINFORCEMENT)
      showSelectedReinforcement(params)
    else if (currentSelectedObject == mapObjectSelect.AIRFIELD)
      showSelectedAirfield(params)
    else if (currentSelectedObject == mapObjectSelect.NONE)
    {
      needUpdateSidesStrenghtView = true
      if (lastSelectedOject != mapObjectSelect.NONE)
        showSidesStrenght()
    }

    updateArmyActionButtons()
  }

  function onSecondsUpdate(obj, dt)
  {
    if (needReindforcementsUpdate)
      needReindforcementsUpdate = updateReinforcements()

    armyStrengthUpdateTimeRemain -= dt
    if (armyStrengthUpdateTimeRemain >= 0)
    {
      updateArmyStrenght()
      armyStrengthUpdateTimeRemain = UPDATE_ARMY_STRENGHT_DELAY
    }

    ::g_operations.fullUpdate()
  }

  function updateReinforcements()
  {
    updateSecondaryBlockTab(::g_ww_map_reinforcement_tab_type.REINFORCEMENT)
    return ::g_world_war.hasSuspendedReinforcements()
  }

  function updateArmyStrenght()
  {
    if (!needUpdateSidesStrenghtView)
      return

    showSidesStrenght()
  }

  function getMainFocusObj()
  {
    return scene.findObject("worldwar_map")
  }

  function initOperationStatus(sendEvent = true)
  {
    local objStartBox = scene.findObject("wwmap_operation_status")
    if (!::check_obj(objStartBox))
      return

    local objTarget = scene.findObject("operation_status")
    if (!::check_obj(objTarget))
      return

    local isFinished = ::g_world_war.isCurrentOperationFinished()
    local isPaused = ::ww_is_operation_paused()
    local statusTextId = ""
    objStartBox.show(isFinished || isPaused)

    if (isFinished)
    {
      local isVictory = ::ww_get_operation_winner() == ::ww_get_player_side()
      statusTextId = isVictory ? "debriefing/victory" : "debriefing/defeat"
      ::play_gui_sound(isVictory ? "ww_oper_end_win" : "ww_oper_end_fail")
    }
    else if (isPaused)
      statusTextId = ::loc("debriefing/pause")
    else
    {
      objTarget.show(false)
      return
    }
    objTarget.setValue("")
    objTarget.show(true)

    local statusText = ::loc(statusTextId)
    local copyObjTarget = scene.findObject("operation_status_hidden_copy")
    if (::check_obj(copyObjTarget))
      copyObjTarget.setValue(statusText)

    local objStart = objStartBox.findObject("wwmap_operation_status_text")
    if (!::check_obj(objStart))
    {
      objTarget.setValue(statusText)
      objStartBox.show(false)
      return
    }
    objStart.setValue(statusText)

    objStartBox.animation = "show"

    ::Timer(scene, 2, (@(scene, objStart, objTarget, objStartBox, statusText) function() {
        objTarget.needAnim = "yes"
        objTarget.setValue(statusText)

        objStartBox.animation = "hide"

        ::create_ObjMoveToOBj(scene, objStart, objTarget, { time = 0.6, bhvFunc = "square" })
      })(scene, objStart, objTarget, objStartBox, statusText),
    this)

    if (sendEvent)
      ::ww_event("OperationFinished")
  }

  function onEventWWChangedDebugMode(params)
  {
    updatePage()
  }

  function onEventWWMapArmySelected(params)
  {
    setCurrentSelectedObject(params.armyType, params)
  }

  function onEventWWMapSelectedReinforcement(params)
  {
    setCurrentSelectedObject(mapObjectSelect.REINFORCEMENT, params)
  }

  function onEventWWMapAirfieldSelected(params)
  {
    local tabsObj = scene.findObject("reinforcement_pages_list")
    if (tabsObj.getValue() != 2)
    {
      tabsObj.setValue(2)
      onReinforcementTabChange(tabsObj)
    }
    setCurrentSelectedObject(mapObjectSelect.AIRFIELD, params)
  }

  function onEventWWMapAirfieldFormationSelected(params)
  {
    setCurrentSelectedObject(mapObjectSelect.AIRFIELD, params)
  }

  function onEventWWMapAirfieldCooldownSelected(params)
  {
    setCurrentSelectedObject(mapObjectSelect.AIRFIELD, params)
  }

  function onEventWWMapClearSelection(params)
  {
    setCurrentSelectedObject(mapObjectSelect.NONE)
  }

  function onEventWWLoadOperation(params = {})
  {
    updateSecondaryBlockTab(::g_ww_map_reinforcement_tab_type.REINFORCEMENT)
    needReindforcementsUpdate = true

    setCurrentSelectedObject(currentSelectedObject)
    markMainObjectiveZones()
    initOperationStatus()

    onSecondsUpdate(null, 0)
    startRequestNewLogsTimer()
  }

  function startRequestNewLogsTimer()
  {
    if (updateLogsTimer)
      return

    updateLogsTimer = ::Timer(scene, WW_LOG_REQUEST_DELAY,
      function()
      {
        updateLogsTimer = null
        local logHandler = null
        if (currentOperationInfoTabType &&
            currentOperationInfoTabType == ::g_ww_map_info_type.LOG)
          logHandler = mainBlockHandler

        ::g_ww_logs.requestNewLogs(WW_LOG_EVENT_LOAD_AMOUNT, false, logHandler)
      }, this, false)
  }

  function onEventWWMapSelectedBattle(params)
  {
    ::gui_handlers.WwBattleDescription.open(::getTblValue("battle", params))
  }

  function onEventWWSelectedReinforcement(params)
  {
    local mapObj = scene.findObject("worldwar_map")
    if (!::checkObj(mapObj))
      return

    local name = ::getTblValue("name", params, "")
    if (::u.isEmpty(name))
      return

    ::ww_gui_bhv.worldWarMapControls.selectedReinforcement.call(::ww_gui_bhv.worldWarMapControls, mapObj, name)
  }

  function onEventMyStatsUpdated(params)
  {
    updateToBattleButton()
  }

  function onEventSquadSetReady(params)
  {
    updateToBattleButton()
  }

  function onEventSquadStatusChanged(params)
  {
    updateToBattleButton()
  }

  function onEventQueueChangeState(params)
  {
    updateToBattleButton()
  }

  function onChangeInfoBlockVisibility(obj)
  {
    local blockObj = getObj("ww-right-panel")
    if (::checkObj(blockObj))
      blockObj.show(obj.getValue())
  }

  function onEventWWShowLogArmy(params)
  {
    local mapObj = guiScene["worldwar_map"]
    if (::check_obj(mapObj))
      ::ww_gui_bhv.worldWarMapControls.selectArmy.call(
        ::ww_gui_bhv.worldWarMapControls, mapObj, params.wwArmy.getName(), true, mapObjectSelect.LOG_ARMY
      )
    showSelectedLogArmy({wwArmy = params.wwArmy})
  }

  function onEventWWNewLogsDisplayed(params)
  {
    local tabObj = getObj("operation_log_block_text")
    if (!::check_obj(tabObj))
      return

    local text = ::loc("mainmenu/log/short")
    if (params.amount > 0)
      text += ::loc("ui/parentheses/space", { text = params.amount })
    tabObj.setValue(text)
  }

  function onEventWWMapArmiesByStatusUpdated(params)
  {
    local armies = ::getTblValue("armies", params, [])
    if (armies.len() == 0)
      return

    updateSecondaryBlockTab(::g_ww_map_reinforcement_tab_type.ARMIES)

    local selectedArmyNames = ::ww_get_selected_armies_names()
    if (!selectedArmyNames.len())
      return

    local army = armies[0]
    if (army.name != selectedArmyNames[0])
      return

    updateSelectedArmy(null, army)
  }

  function onEventWWShowRearZones(params)
  {
    if (!::g_world_war.rearZones)
      ::g_world_war.updateRearZones()
    if (!::g_world_war.rearZones)
      return

    local reinforcement = ::g_world_war.getReinforcementByName(::getTblValue("name", params))
    if (!reinforcement)
      return

    local sideName = ::ww_side_val_to_name(reinforcement.getArmySide())
    ::ww_mark_zones_as_outlined_by_name(::g_world_war.rearZones[sideName])

    if (highlightZonesTimer)
      highlightZonesTimer.destroy()

    highlightZonesTimer = ::Timer(scene, 10,
      function()
      {
        ::ww_clear_outlined_zones()
      }, this, false)
  }

  function onEventWWArmyStatusChanged(params)
  {
    updateArmyActionButtons()
  }

  function onEventWWJoinBattle(params)
  {
    destroyCheckJoinEnabledTimer()

    local battleId = params.battleId
    checkJoinEnabledTimer = ::Timer(scene, 1,
      @() onCheckJoinEnabled(battleId), this, true)
  }

  function onEventLobbyStatusChange(params)
  {
    destroyCheckJoinEnabledTimer()
  }

  function onEventWWLeaveBattle(params)
  {
    destroyCheckJoinEnabledTimer()
  }

  function onCheckJoinEnabled(battleId)
  {
    local battle = ::g_world_war.getBattleById(battleId)
    local cantJoinReasonData = battle.getCantJoinReasonData(::ww_get_player_side(), false)
    if (!cantJoinReasonData.canJoin)
    {
      destroyCheckJoinEnabledTimer()
      ::g_world_war.leaveWWBattleQueues()
      ::showInfoMsgBox(cantJoinReasonData.reasonText)
    }
  }

  function destroyCheckJoinEnabledTimer()
  {
    if (checkJoinEnabledTimer && checkJoinEnabledTimer.isValid())
      checkJoinEnabledTimer.destroy()
  }
}
