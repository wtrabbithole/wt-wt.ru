local time = require("scripts/time.nut")
local daguiFonts = require("scripts/viewUtils/daguiFonts.nut")

::req_tutorial <- {
  [::ES_UNIT_TYPE_AIRCRAFT] = "tutorialB_takeoff_and_landing",
  //[::ES_UNIT_TYPE_TANK] = "",
}


::req_time_in_mode <- 60 //req time in mode when no need check tutorial
::instant_domination_handler <- null
::start_mission_instead_of_queue <- null
::const_wait_time <- 300.0

::isTanskEventsEnabled <- true

::battle_type_option_name <- "battle_type"

/*
::start_mission_instead_of_queue <- {
    name = "guadalcanal_night_fight"
    //isBotsAllowed = true
  }
*/

/* ::domination_modes are DEPRECATED, use ::g_difficulty instead */
::domination_modes <-
[
  {
    id = "arcade"
    modeId = ::EGD_ARCADE
    diff = ::DIFFICULTY_ARCADE
    diffName = ::get_difficulty_name(::DIFFICULTY_ARCADE)
    diffIcon = "#ui/gameuiskin#mission_complete_arcade"
    subId = "arcade"
    name = "mainmenu/arcadeInstantAction"
    desc = "encyclopedia/arcade_battles/desc"
    locId = "missions/air_event_arcade"
    clanDataEnding = "_arc"
    leaderboardsId = "arcade"
    statisticsId = "arcade"
    arcadeCountry = true
    respawns = true
    availableMissionTypes = ["ground_strike", "airfield_dom"]
    tankEventName     = "tank_event_in_random_battles_arcade"
    displayWide = !::has_feature("Tanks")
    rankCalcMode = "average"
  }
  {
    id = "historical"
    modeId = ::EGD_HISTORICAL
    diff = ::DIFFICULTY_REALISTIC
    diffName = ::get_difficulty_name(::DIFFICULTY_REALISTIC)
    diffIcon = "#ui/gameuiskin#mission_complete_realistic"
    name = "mainmenu/instantAction"
    desc = "encyclopedia/historical_battles/desc"
    locId = "missions/air_event_historical"
    clanDataEnding = "_hist"
    leaderboardsId = "historical"
    statisticsId = "realistic"
    arcadeCountry = true
    respawns = false
    checkTutorial = true
    availableMissionTypes = ["base_dom", "airfield_dom"]
    tankEventName     = "tank_event_in_random_battles_historical"
    displayWide = !::has_feature("Tanks")
    rankCalcMode = "maximum"
  }
  {
    id = "fullreal"
    modeId = ::EGD_SIMULATION
    diff = ::DIFFICULTY_HARDCORE
    diffName = ::get_difficulty_name(::DIFFICULTY_HARDCORE)
    diffIcon = "#ui/gameuiskin#mission_complete_simulator"
    name = "mainmenu/fullRealInstantAction"
    desc = "encyclopedia/realistic_battles/desc"
    locId = "missions/air_event_simulator"
    clanDataEnding = "_sim"
    leaderboardsId = "simulation"
    statisticsId = "hardcore"
    arcadeCountry = false
    respawns = false
    checkTutorial = true
    availableMissionTypes = ["base_dom", "airfield_dom"]
    tankEventName     = "tank_event_in_random_battles_simulation"
    displayWide = !::has_feature("Tanks")
    rankCalcMode = "maximum"
  }
]

foreach(idx, mode in ::domination_modes)
  mode.modeIdx <- idx

::domination_rank_groups <- [-1, 4, 10, 20]

function update_start_mission_instead_of_queue()
{
  local rBlk = ::get_ranks_blk()

  local mInfo = rBlk.custom_single_mission
  if (!mInfo || !mInfo.name)
    ::start_mission_instead_of_queue = null
  else
  {
    ::start_mission_instead_of_queue = {}
    foreach(name, val in mInfo)
      ::start_mission_instead_of_queue[name] <- val
  }
}

function get_req_tutorial(unitType)
{
  return ::getTblValue(unitType, ::req_tutorial, "")
}

class ::gui_handlers.InstantDomination extends ::gui_handlers.BaseGuiHandlerWT
{
  static keepLoaded = true

  sceneBlkName = "gui/mainmenu/instantAction.blk"

  toBattleButtonObj = null
  gameModeChangeButtonObj = null
  newGameModesWidgetsPlaceObj = null
  countriesListObj = null
  inited = false
  wndGameMode = ::GM_DOMINATION
  clusters = null
  needBattleMenuShow = false
  isBattleMenuShow = false
  curCluster = 0
  startEnabled = false
  waitTime = 0
  updateTimer = 0
  timeToChooseCountry = 1.0
  switcheHidden = false
  lastBattleMode = null
  queueMask = QUEUE_TYPE_BIT.DOMINATION | QUEUE_TYPE_BIT.NEWBIE

  curQueue = null
  function getCurQueue() { return curQueue }
  function setCurQueue(value)
  {
    curQueue = value
    if (value != null)
    {
      initQueueTableHandler()
      restoreQueueParams()
    }
  }

  curCountry = ""
  function getCurCountry() { return curCountry }
  function setCurCountry(value)
  {
    curCountry = value
  }

  gamercardDrawerHandler = null
  function getGamercardDrawerHandler()
  {
    if (!::handlersManager.isHandlerValid(gamercardDrawerHandler))
      initGamercardDrawerHandler()
    if (::handlersManager.isHandlerValid(gamercardDrawerHandler))
      return gamercardDrawerHandler
    ::dagor.assertf(false, "Failed to get gamercardDrawerHandler.")
    return null
  }

  queueTableHandler = null
  function getQueueTableHandler()
  {
    if (!::handlersManager.isHandlerValid(queueTableHandler))
      initQueueTableHandler()
    if (::handlersManager.isHandlerValid(queueTableHandler))
      return queueTableHandler
    ::dagor.assertf(false, "Failed to get queueTableHandler.")
    return null
  }

  gameModeSelectHandler = null
  newGameModeIconWidget = null
  function getGameModeSelectHandler()
  {
    if (!::handlersManager.isHandlerValid(gameModeSelectHandler))
      initGameModeSelectHandler()
    if (::handlersManager.isHandlerValid(gameModeSelectHandler))
      return gameModeSelectHandler
    ::dagor.assertf(false, "Failed to get gameModeSelectHandler.")
    return null
  }

  slotbarPresetsTutorial = null

  function initScreen()
  {
    ::enableHangarControls(true)
    ::instant_domination_handler <- this

    // Causes drawer to initialize once.
    getGamercardDrawerHandler()

    mainOptionsMode = ::get_gui_options_mode()
    ::set_gui_options_mode(::OPTIONS_MODE_MP_DOMINATION)

    initToBattleButton()
    setCurrentGameModeName()

    for(local i = 1; i< ::domination_rank_groups.len(); i++)
    {
      local obj = scene.findObject("rankLimit"+i)
      if (obj)
        obj.text = ::loc("mainmenu/rankLimit",
                         { rank1 = ::domination_rank_groups[i-1]+1, rank2 = ::domination_rank_groups[i]})
    }

    setCurQueue(::queues.findQueue({}, queueMask))

    updateStartButton()

    inited = true

    offsetSettingsBeforeInstantAction()

    ::dmViewer.update()
  }

  function reinitScreen(params)
  {
    inited = false
    initScreen()
  }

  function canShowDmViewer()
  {
    return getCurQueue() == null
  }

  function initQueueTableHandler()
  {
    if (::handlersManager.isHandlerValid(queueTableHandler))
      return

    local drawer = getGamercardDrawerHandler()
    if (drawer == null)
      return

    local queueTableContainer = drawer.scene.findObject("queue_table_container")
    if (queueTableContainer == null)
      return

    local queue = getCurQueue()
    local params = {
      scene = queueTableContainer
      queueMask = queueMask
    }
    queueTableHandler = ::handlersManager.loadHandler(::gui_handlers.QueueTable, params)
  }

  function initGamercardDrawerHandler()
  {
    if (::top_menu_handler == null)
      return

    local gamercardPanelCenterObject = ::top_menu_handler.scene.findObject("gamercard_panel_center")
    if (gamercardPanelCenterObject == null)
      return
    gamercardPanelCenterObject.show(true)
    gamercardPanelCenterObject.enable(true)

    local gamercardDrawerContainer = ::top_menu_handler.scene.findObject("gamercard_drawer_container")
    if (gamercardDrawerContainer == null)
      return

    local params = {
      scene = gamercardDrawerContainer
    }
    gamercardDrawerHandler = ::handlersManager.loadHandler(::gui_handlers.GamercardDrawer, params)
  }

  function initGameModeSelectHandler()
  {
    local drawer = getGamercardDrawerHandler()
    if (drawer == null)
      return

    local gameModeSelectContainer = drawer.scene.findObject("game_mode_select_container")
    if (gameModeSelectContainer == null)
      return

    local params = {
      scene = gameModeSelectContainer
    }
    gameModeSelectHandler = ::handlersManager.loadHandler(::gui_handlers.GameModeSelect, params)
  }

  function initToBattleButton()
  {
    if (!rootHandlerWeak)
      return

    local centeredPlaceObj = ::showBtn("gamercard_center", true, rootHandlerWeak.scene)
    if (!centeredPlaceObj)
      return

    local toBattleNest = ::showBtn("gamercard_tobattle", true, rootHandlerWeak.scene)
    if (toBattleNest)
    {
      rootHandlerWeak.scene.findObject("top_gamercard_bg").needRedShadow = "no"
      local toBattleBlk = ::handyman.renderCached("gui/mainmenu/toBattleButton", {
        enableEnterKey = !::is_platform_shield_tv()
      })
      guiScene.replaceContentFromText(toBattleNest, toBattleBlk, toBattleBlk.len(), this)
      toBattleButtonObj = rootHandlerWeak.scene.findObject("to_battle_button")
      rootHandlerWeak.scene.findObject("gamercard_tobattle_bg")["background-color"] = "#00000000"
    }
    rootHandlerWeak.scene.findObject("gamercard_logo").show(false)
    gameModeChangeButtonObj = rootHandlerWeak.scene.findObject("game_mode_change_button")
    countriesListObj = rootHandlerWeak.scene.findObject("countries_list")

    newGameModesWidgetsPlaceObj = rootHandlerWeak.scene.findObject("new_game_modes_widget_place")
    updateUnseenGameModesCounter()
  }

  _lastGameModeId = null
  function setGameMode(modeId)
  {
    local gameMode = ::game_mode_manager.getGameModeById(modeId)
    if (gameMode == null || modeId == _lastGameModeId)
      return
    _lastGameModeId = modeId

    onCountrySelectAction()//bad function naming. Actually this function validates your units and selected country for new mode
    setCurrentGameModeName()
    reinitSlotbar()
  }

  function setCurrentGameModeName()
  {
    if (!::checkObj(gameModeChangeButtonObj))
      return

    local gameMode = ::game_mode_manager.getCurrentGameMode()
    local text = gameMode ? gameMode.text : ::loc("mainmenu/gamemodesNotLoaded")
    gameModeChangeButtonObj.findObject("game_mode_change_button_text").setValue(text)
  }

  function updateUnseenGameModesCounter()
  {
    if (!::check_obj(newGameModesWidgetsPlaceObj))
      return

    if (!newGameModeIconWidget)
      newGameModeIconWidget = ::NewIconWidget(guiScene, newGameModesWidgetsPlaceObj)

    newGameModeIconWidget.setValue(::game_mode_manager.getUnseenGameModeCount())
  }

  function onEventShowingGameModesUpdated(params)
  {
    updateUnseenGameModesCounter()
  }

  function onEventEventsDataUpdated(params)
  {
    setCurrentGameModeName()
  }

  function onEventMyStatsUpdated(params)
  {
    setCurrentGameModeName()
    doWhenActiveOnce("checkNoviceTutor")
    updateStartButton()
  }

  function onEventCrewTakeUnit(params)
  {
    doWhenActiveOnce("onCountrySelectAction")
  }

  function onEventSlotbarPresetLoaded(params)
  {
    if (::getTblValue("crewsChanged", params, true))
      doWhenActiveOnce("onCountrySelectAction")
  }

  function onEventUpdateModesInfo(p)
  {
    doWhenActiveOnce("doWhenActiveOnce_reinitScreen")
  }

  /**
   * This is a 'reinitScreen' wrapper that
   * fixes 'wrong number of parameters' error.
   */
  function doWhenActiveOnce_reinitScreen()
  {
    reinitScreen(null)
  }

  function onEventSquadSetReady(params)
  {
    doWhenActiveOnce("updateStartButton")
  }

  function onEventSquadStatusChanged(params)
  {
    doWhenActiveOnce("updateStartButton")
  }

  function onEventCrewChanged(params)
  {
    doWhenActiveOnce("checkCountries")
  }

  function onEventCheckClientUpdate(params)
  {
    if (!::checkObj(scene))
      return

    local obj = scene.findObject("update_avail")
    if (!::checkObj(obj))
      return

    obj.show(::getTblValue("update_avail", params, false))
  }

  function checkCountries()
  {
    onCountrySelectAction()
    return
  }

  function onEventQueueChangeState(_queue)
  {
    if (!::queues.checkQueueType(_queue, queueMask))
      return
    setCurQueue(::queues.isQueueActive(_queue) ? _queue : null)
    updateStartButton()
    ::dmViewer.update()
  }

  function onEventCurrentGameModeIdChanged(params)
  {
    setGameMode(::game_mode_manager.getCurrentGameModeId())
  }

  function onEventGameModesUpdated(params)
  {
    setGameMode(::game_mode_manager.getCurrentGameModeId())
    updateUnseenGameModesCounter()
  }

  function onCountrySelect()
  {
    checkQueue(onCountrySelectAction)
  }

  function onCountrySelectAction()
  {
    if (!::checkObj(scene))
      return
    local currentGameMode = ::game_mode_manager.getCurrentGameMode()
    if (currentGameMode == null)
      return
    local multiSlotEnabled = isCurrentGameModeMultiSlotEnabled()
    setCurCountry(::get_profile_country_sq())
    local countryEnabled = ::isCountryAvailable(getCurCountry()) && ::events.isCountryAvailable(currentGameMode.getEvent(), getCurCountry())
    local crewsGoodForMode = testCrewsForMode(getCurCountry())
    local currentUnitGoodForMode = testCurrentUnitForMode(getCurCountry())
    local requiredUnitsAvailable = checkRequiredUnits(getCurCountry())
    startEnabled = countryEnabled && requiredUnitsAvailable && ((!multiSlotEnabled && currentUnitGoodForMode) || (multiSlotEnabled && crewsGoodForMode))
  }

  function getQueueAircraft(country)
  {
    local slots = getCurQueue() && ::queues.getQueueSlots(getCurQueue())
    if (slots && (country in slots))
    {
      foreach(cIdx, c in ::g_crews_list.get())
        if (c.country == country)
          return getSlotAircraft(cIdx, slots[country])
      return null
    }
    return getSelAircraftByCountry(country)
  }

  function onReinitSlotbar()
  {
    offsetSettingsBeforeInstantAction()
  }

  function onTopMenuGoBack(checkTopMenuButtons = false)
  {
    if (!getCurQueue() && ::g_squad_manager.isInSquad() && !::g_squad_manager.isSquadLeader() && ::g_squad_manager.isMeReady())
      return ::g_squad_manager.setReadyFlag()

    if (getCurQueue())
    {
      if (!::g_squad_utils.canJoinFlightMsgBox({ isLeaderCanJoin = true, msgId = "squad/only_leader_can_cancel" }))
        return
      leaveCurQueue()
      return
    }

    if (getGameModeSelectHandler().getShowGameModeSelect())
    {
      getGameModeSelectHandler().setShowGameModeSelect(false)
      return
    }

    if (checkTopMenuButtons && ::top_menu_handler && ::top_menu_handler.leftSectionHandlerWeak)
    {
      ::top_menu_handler.leftSectionHandlerWeak.switchDropDownMenu()
      return
    }
  }

  function canRestoreFocus()
  {
    local drawer = getGamercardDrawerHandler()
    return !drawer || !drawer.isActive()
  }

  function onEventGamercardDrawerAnimationStart(params)
  {
    if (!params.isOpening)
      restoreFocus()

    // This deactivates "To battle" button when game mode select is active.
    //FIX ME: better to ask about cur handler from drawer, but he doesn't know about it atm
    if (::handlersManager.isHandlerValid(gameModeSelectHandler))
      setToBattleButtonAccessKeyActive(!params.isOpening
        || gameModeSelectHandler.scene.id != getGamercardDrawerHandler()?.currentTarget?.id)
  }

  _isToBattleAccessKeyActive = true
  function setToBattleButtonAccessKeyActive(value)
  {
    if (value == _isToBattleAccessKeyActive)
      return
    if (toBattleButtonObj == null)
      return

    _isToBattleAccessKeyActive = value
    toBattleButtonObj.enable(value)
    local consoleImageObj = toBattleButtonObj.findObject("to_battle_console_image")
    if (::checkObj(consoleImageObj))
      consoleImageObj.show(value && ::show_console_buttons)
  }

  function startManualMission(manualMission)
  {
    local missionBlk = ::DataBlock()
    missionBlk.setFrom(::get_mission_meta_info(manualMission.name))
    foreach(name, value in manualMission)
      if (name != "name")
        missionBlk[name] <- value
    ::select_mission(missionBlk, true)
    ::current_campaign_mission = missionBlk.name
    guiScene.performDelayed(this, function() { goForward(::gui_start_flight)})
  }

  function onStart()
  {
    if (::start_mission_instead_of_queue)
    {
      startManualMission(::start_mission_instead_of_queue)
      return
    }

    if (::g_squad_manager.isInSquad() && !::g_squad_manager.isSquadLeader())
      return ::g_squad_manager.setReadyFlag()

    if (getCurQueue())
    {
      if (::g_squad_utils.canJoinFlightMsgBox({ isLeaderCanJoin = true }))
        leaveCurQueue()
      return
    }

    local curGameMode = ::game_mode_manager.getCurrentGameMode()
    if ("onBattleButtonClick" in curGameMode)
      return curGameMode.onBattleButtonClick()

    checkedNewFlight(onStartAction)
  }

  function onStartAction()
  {
    checkCountries()

    if (!::is_online_available())
    {
      local handler = this
      goForwardIfOnline((@(handler) function() {
          if (handler && ::checkObj(handler.scene))
            handler.onStartAction.call(handler)
        })(handler), false, true)
      return
    }

    if (::g_squad_utils.canJoinFlightMsgBox({ isLeaderCanJoin = true }))
    {
      setCurCountry(::get_profile_country_sq())
      local gameMode = ::game_mode_manager.getCurrentGameMode()
      if (gameMode == null)
        return
      if (checkGameModeTutorial(gameMode))
        return

      local countryGoodForMode = ::events.isCountryAvailable(gameMode.getEvent(), getCurCountry())
      local multiSlotEnabled = isCurrentGameModeMultiSlotEnabled()
      local requiredUnitsAvailable = checkRequiredUnits(getCurCountry())
      if (countryGoodForMode && startEnabled)
        onCountryApply()
      else if (!requiredUnitsAvailable)
        showRequirementsMsgBox()
      else if (countryGoodForMode && !testCrewsForMode(getCurCountry()))
        showNoSuitableVehiclesMsgBox()
      else if (countryGoodForMode && !testCurrentUnitForMode(getCurCountry()) && !multiSlotEnabled)
        showBadCurrentUnitMsgBox()
      else
        ::gui_start_modal_wnd(::gui_handlers.ChangeCountry, {
          currentCountry = getCurCountry()
        })
    }
  }

  function startEventBattle(event)
  {
    //!!FIX ME: this is a start random_battles or newbie battles events without check old domination modes
    //can be used as base random battles start for new matching.
    //valid only for newbie events yes
    if (::queues.isAnyQueuesActive(queueMask) || !::g_squad_utils.canJoinFlightMsgBox({ isLeaderCanJoin = true }))
      return

    ::EventJoinProcess(event)
  }

  function getTypeLocTexts()
  {
    local battleTypeLoc = ""
    local unitTypeLoc = ""
    if (::mission_settings.battleMode == BATTLE_TYPES.AIR)
    {
      battleTypeLoc = ::loc("mainmenu/airBattles")
      unitTypeLoc = ::loc("unit_type/air")
    }
    else if (::mission_settings.battleMode == BATTLE_TYPES.TANK)
    {
      battleTypeLoc = ::loc("mainmenu/tankBattles")
      unitTypeLoc = ::loc("unit_type/tank")
    }

    return [battleTypeLoc, unitTypeLoc]
  }

  function showNoSuitableVehiclesMsgBox()
  {
    msgBox("cant_fly", ::loc("events/no_allowed_crafts", " "), [["ok", function() {
      startSlotbarPresetsTutorial()
    }]], "ok")
  }

  function showBadCurrentUnitMsgBox()
  {
    msgBox("cant_fly", ::loc("events/no_allowed_crafts", " "), [["ok", function() {
      startSlotbarPresetsTutorial()
    }]], "ok")
  }

  function getRequirementsMsgText()
  {
    local gameMode = ::game_mode_manager.getCurrentGameMode()
    if (!gameMode || gameMode.type != RB_GM_TYPE.EVENT)
      return ""

    local requirements = []
    local event = gameMode.getEvent()
    if (!event)
      return ""

    foreach (team in ::events.getSidesList(event))
    {
      local teamData = ::events.getTeamData(event, team)
      if (!teamData)
        continue

      requirements = ::events.getRequiredCrafts(teamData)
      if (requirements.len() > 0)
        break
    }
    if (requirements.len() == 0)
      return ""

    local msgText = ::loc("events/no_required_crafts") + ::loc("ui/colon")
    foreach(rule in requirements)
      msgText += "\n" + ::events.generateEventRule(rule, true)

    return msgText
  }

  function showRequirementsMsgBox()
  {
    showBadUnitMsgBox(getRequirementsMsgText())
  }

  function showBadUnitMsgBox(msgText)
  {
    local unitType
    local buttonsArray = []

    // "Change mode" button
    unitType = ::get_es_unit_type(::get_cur_slotbar_unit())
    local gameMode = ::game_mode_manager.getGameModeByUnitType(unitType, -1, true)
    if (gameMode != null)
    {
      buttonsArray.push([
        "#mainmenu/changeMode",
        function () {
          ::game_mode_manager.setCurrentGameModeById(gameMode.id)
          checkCountries()
          onStart()
        }
      ])
    }

    // "Change vehicle" button
    local currentGameMode = ::game_mode_manager.getCurrentGameMode()
    local properUnitType = null
    if (currentGameMode.type == RB_GM_TYPE.EVENT)
    {
      local event = currentGameMode.getEvent()
      foreach(unitType in ::g_unit_type.types)
        if (::events.isUnitTypeRequired(event, unitType.esUnitType))
        {
          properUnitType = unitType
          break
        }
    }

    if (rootHandlerWeak)
    {
      buttonsArray.push([
        "#mainmenu/changeVehicle",
        function () {
          if (isValid() && rootHandlerWeak)
            rootHandlerWeak.openShop(properUnitType)
        }
      ])
    }

    // "Ok" button
    buttonsArray.push(["ok", function () {}])

    msgBox("bad_current_unit", msgText, buttonsArray, "ok"/*"#mainmenu/changeMode"*/, { cancel_fn = function () {} })
  }

  function isCurrentGameModeMultiSlotEnabled()
  {
    local gameMode = ::game_mode_manager.getCurrentGameMode()
    return ::events.isEventMultiSlotEnabled(::getTblValue("source", gameMode, null))
  }

  function onCountryChoose(country)
  {
    if (::isCountryAvailable(country))
    {
      setCurCountry(country)
      topMenuSetCountry(getCurCountry())
      onCountryApply()
    }
  }

  function topMenuSetCountry(country)
  {
    local slotbar = getSlotbar()
    if (slotbar)
      slotbar.setCountry(country)
  }

  function onAdvertLinkClick(obj, itype, link)
  {
    proccessLinkFromText(obj, itype, link)
  }

  function onCountryApply()
  {
    if (::tanksDriveGamemodeRestrictionMsgBox("TanksInRandomBattles",
                                              getCurCountry(),
                                              null,
                                              "cbt_tanks/forbidden/instant_action"))
      return

    local multiSlotEnabled = isCurrentGameModeMultiSlotEnabled()
    if (!testCrewsForMode(getCurCountry()))
      return showNoSuitableVehiclesMsgBox()
    if (!multiSlotEnabled && !testCurrentUnitForMode(getCurCountry()))
      return showBadCurrentUnitMsgBox()

    local gameMode   = ::game_mode_manager.getCurrentGameMode()
    if (gameMode == null)
      return
    if (::events.checkEventDisableSquads(this, gameMode.id))
      return
    if (checkGameModeTutorial(gameMode))
      return

    if (gameMode.type == RB_GM_TYPE.EVENT)
      return startEventBattle(gameMode.getEvent()) //better to do completely the same here as we do n events.
                                               // but better to refactor this place after remove old gamemodes
  }

  function checkGameModeTutorial(gameMode)
  {
    local checkTutorUnitType = (gameMode.unitTypes.len() == 1)? gameMode.unitTypes[0] : null
    local diffCode = ::events.getEventDiffCode(gameMode.getEvent())
    return checkDiffTutorial(diffCode, checkTutorUnitType)
  }

  function updateStartButton()
  {
    if (!::checkObj(scene) || !::checkObj(toBattleButtonObj))
      return

    local inQueue = getCurQueue() != null
    local isSquadMember = ::g_squad_manager.isSquadMember()
    local isReady = ::g_squad_manager.isMeReady()

    local txt = ""
    local isCancel = false

    if (!inQueue)
    {
      if (isSquadMember)
      {
        txt = ::loc(isReady ? "multiplayer/btnNotReady" : "mainmenu/btnReady")
        isCancel = isReady
      }
      else
      {
        txt = ::loc("mainmenu/toBattle/short")
        isCancel = false
      }
    }
    else
    {
      txt = ::loc("mainmenu/btnCancel")
      isCancel = true
    }

    toBattleButtonObj.setValue(txt)
    toBattleButtonObj.findObject("to_battle_button_text").setValue(txt)
    toBattleButtonObj.isCancel = isCancel ? "yes" : "no"

    toBattleButtonObj.fontOverride = daguiFonts.getMaxFontTextByWidth(txt,
      to_pixels("1@maxToBattleButtonTextWidth"), "bold")

    if (::top_menu_handler)
      ::top_menu_handler.onQueue.call(::top_menu_handler, inQueue)
  }

  function afterCountryApply(membersData = null, team = null, event = null)
  {
    if (::disable_network())
    {
      ::quick_match_flag <- true;
      ::match_search_diff <- -1
      ::match_search_gm <- ::GM_DOMINATION
      ::match_search_map <- ""
      guiScene.performDelayed(this, function() {
        goForwardIfOnline(::gui_start_session_list, false)
      })
      return
    }

    joinQuery(null, membersData, team, event)
  }

  function joinQuery(query = null, membersData = null, team = null, event = null)
  {
    leaveCurQueue()

    local modeName = ""
    local isEventBattle = event != null
    if (event)
      modeName = event.name
    else
    {
      local gameMode = ::game_mode_manager.getCurrentGameMode()
      modeName = ::getTblValue("id", gameMode, "")
    }
    if (!query)
    {
      query = {
        mode = modeName
        country = getCurCountry()
        //cluster = curCluster
      }

      //if (team && isEventBattle)  //!!can choose team correct only with multiEvents support
      //  query.team <- team
    }
    /*if (!isEventBattle)
      validateQuery(query)*/

    if (membersData)
      query.members <- membersData

    ::set_presence_to_player("queue")
    ::queues.joinQueue(query)

    local chatDiv = null
    if (::top_menu_handler)
      chatDiv = getChatDiv(::top_menu_handler.scene)
    if (!chatDiv && scene && scene.isValid())
      chatDiv = getChatDiv(scene)
    if(chatDiv)
      ::switchMenuChatObjIfVisible(chatDiv)
  }

  function leaveCurQueue()
  {
    if (getCurQueue())
      ::queues.leaveQueue(getCurQueue())
  }

  function goBack()
  {
    if (isBattleMenuShow)
    {
      local blocksObj = scene.findObject("ia_active_blocks")
      local selObj = getIaBlockSelObj(blocksObj)
      if (selObj && selObj.isFocused())
        return blocksObj.select()
    }

    if (getCurQueue())
    {
      if (!::g_squad_utils.canJoinFlightMsgBox({ isLeaderCanJoin = true, msgId = "squad/only_leader_can_cancel" }))
        return
      leaveCurQueue()
      return
    }

    if (needBattleMenuShow)
      return onInstantActionMenu()

     onTopMenuGoBack()
  }

  function checkQueue(func)
  {
    if (!inited)
      return func()

    checkedModifyQueue(queueMask, func, restoreQueueParams)
  }

  function restoreQueueParams()
  {
    local tMsgBox = guiScene["req_tutorial_msgbox"]
    if (::checkObj(tMsgBox))
      guiScene.destroyElement(tMsgBox)

    if (!getCurQueue())
      return

    if (!::checkObj(scene))
    {
      dagor.debug("No scene found on cancel requeue")
      return
    }

    local qCountry = ::queues.getQueueCountry(getCurQueue())
    local obj = countriesListObj
    if (::checkObj(obj))
    {
      local option = ::get_option(::USEROPT_COUNTRY)
      local value = 0
      foreach(idx, c in option.values)
        if (c == qCountry)
          value = idx

      if (qCountry != getCurCountry() || value != obj.getValue())
        obj.setValue(value)
    }

    local battleMode = ::queues.getQueueBattleType(getCurQueue(), BATTLE_TYPES.AIR)
  }

  function selectFirstMode()
  {
    local modesObj = scene.findObject("modes_list")
    if (!::checkObj(modesObj))
      return
    foreach(idx, mode in ::domination_modes)
      if (!("checkTutorial" in mode) || !mode.checkTutorial)
      {
        modesObj.setValue(idx)
        return
      }
  }

  function offsetSettingsBeforeInstantAction()
  {
    local obj = scene.findObject("nav-topMenu")
    if (!::checkObj(obj))
      obj = guiScene["nav-topMenu"]
    if (::checkObj(obj))
      obj = obj.findObject("autorefill-settings")
    if (::checkObj(obj))
      obj["offset"] = "yes"
  }

  function testCurrentUnitForMode(country)
  {
    if (country == "country_0")
    {
      local option = ::get_option(::USEROPT_COUNTRY)
      foreach(idx, optionCountryName in option.values)
        if (optionCountryName != "country_0" && option.items[idx].enabled)
        {
          local unit = getQueueAircraft(optionCountryName)
          if (!unit)
            continue
          if (::game_mode_manager.isUnitAllowedForGameMode(unit))
            return true
        }
      return false
    }
    local unit = ::getSelAircraftByCountry(country)
    return ::game_mode_manager.isUnitAllowedForGameMode(unit)
  }

  function testCrewsForMode(country)
  {
    local countryToCheckArr = []
    if (country == "country_0")
    {//fill countryToCheckArr with countries, allowed by game mode
      local option = ::get_option(::USEROPT_COUNTRY)
      foreach(idx, optionCountryName in option.values)
        if (optionCountryName != "country_0" && option.items[idx].enabled)
          countryToCheckArr.append(optionCountryName)
    }
    else
      countryToCheckArr.append(country)

    foreach (countryCrews in ::g_crews_list.get())
    {
      if (!::isInArray(countryCrews.country, countryToCheckArr))
        continue

      foreach (crew in countryCrews.crews)
      {
        if (!("aircraft" in crew))
          continue
        local unit = ::getAircraftByName(crew.aircraft)
        if (::game_mode_manager.isUnitAllowedForGameMode(unit))
          return true
      }
    }

    return false
  }

  function checkRequiredUnits(country)
  {
    local gameMode = ::game_mode_manager.getCurrentGameMode()
    return gameMode ? ::events.checkRequiredUnits(gameMode.getEvent(), null, country) : true
  }

  function onInstantActionMenu()
  {
    //showBattleMenu(!isBattleMenuShow)
  }

  function onCloseBattleMenu()
  {
    //showBattleMenu(false)
  }

  function getIaBlockSelObj(obj)
  {
    local value = obj.getValue() || 0
    if (obj.childrenCount() <= value)
      return null

    local id = ::getObjIdByPrefix(obj.getChild(value), "block_")
    if (!id)
      return null

    local selObj = obj.findObject(id)
    return ::checkObj(selObj)? selObj : null
  }

  function onIaBlockActivate(obj)
  {
    local selObj = getIaBlockSelObj(obj)
    if (!selObj)
      return

    selObj.select()
  }

  function getMainFocusObj()
  {
    if (::handlersManager.isHandlerValid(queueTableHandler))
      return queueTableHandler.getCurFocusObj()
    return null
  }

  function getMainFocusObj2()
  {
    if (!isBattleMenuShow)
      return null

    local blocksObj = scene.findObject("ia_active_blocks")
    local selObj = getIaBlockSelObj(blocksObj)
    if (selObj && selObj.isFocused())
      return selObj
    return blocksObj
  }

  function getMainFocusObj3()
  {
    return scene.findObject("promo_mainmenu_place_top")
  }

  function getMainFocusObj4()
  {
    return scene.findObject("promo_mainmenu_place_bottom")
  }

  function onUnlockCrew(obj)
  {
    if (!obj)
      return
    local isGold = false
    if (obj.id == "btn_unlock_crew_gold")
      isGold = true
    local unit = ::get_player_cur_unit()
    if (!unit)
      return

    local crewId = ::getCrewByAir(unit).id
    local cost = ::Cost()
    if (isGold)
      cost.gold = ::shop_get_unlock_crew_cost_gold(crewId)
    else
      cost.wp = ::shop_get_unlock_crew_cost(crewId)

    local msg = ::format("%s %s?", ::loc("msgbox/question_crew_unlock"), cost.getTextAccordingToBalance())
    msgBox("unlock_crew", msg, [
        ["yes", (@(crewId, isGold) function() {
          taskId = ::unlockCrew( crewId, isGold )
          ::sync_handler_simulate_signal("profile_reload")
          if (taskId >= 0)
          {
            ::set_char_cb(this, slotOpCb)
            showTaskProgressBox()
            afterSlotOp = null
          }
        })(crewId, isGold)],
        ["no", function() { return false }]
      ], "no")
  }

  function checkNoviceTutor()
  {
    if (::disable_network() || !::my_stats.isStatsLoaded())
      return

    local id = "tutor/toBattle"
    if (!::loadLocalByAccount(id, false) && ::is_me_newbie() && !::my_stats.getPvpRespawns())
      toBattleTutor()
    ::saveLocalByAccount(id, true)
  }

  function checkUpgradeCrewTutorial()
  {
    if (!::g_login.isLoggedIn())
      return

    if (!::g_crew.isAllCrewsMinLevel())
      return

    tryToStartUpgradeCrewTutorial()
  }

  function getCurrentCrewSlot()
  {
    local slotbar = getSlotbar()
    return slotbar && slotbar.getCurrentCrewSlot()
  }

  function tryToStartUpgradeCrewTutorial()
  {
    local curCrew = getCurCrew()
    if (!curCrew)
      return

    local curCrewSlot = getCurrentCrewSlot()
    if (!curCrewSlot)
      return

    local tutorialPageId = ::g_crew.getSkillPageIdToRunTutorial(curCrew)
    if (!tutorialPageId)
      return

    local inst = this
    local steps = [
      {
        obj = [curCrewSlot]
        text = ::loc("tutorials/upg_crew/skill_points_info") + " " + ::loc("tutorials/upg_crew/press_to_crew")
        actionType = tutorAction.OBJ_CLICK
        cb = function()
        {
          openUnitActionsList(curCrewSlot, false, true)
        }
      },
      {
        actionType = tutorAction.WAIT_ONLY
        waitTime = 0.5
      },
      {
        obj = [function() {
          return curCrewSlot.findObject("crew")
        }]
        text = ::loc("tutorials/upg_crew/select_crew")
        actionType = tutorAction.OBJ_CLICK
        cb = function() {
          ::gui_modal_crew(curCrew.idCountry, curCrew.idInCountry, tutorialPageId, true)
        }
      }
    ]
    ::gui_modal_tutor(steps, this)
  }

  function toBattleTutor()
  {
    local objs = [toBattleButtonObj, ::top_menu_handler.getObj("to_battle_console_image")]
    local steps = [{
      obj = [objs]
      text = ::loc("tutor/battleButton")
      actionType = tutorAction.OBJ_CLICK
      accessKey = "J:X"
      cb = onStart
    }]
    ::gui_modal_tutor(steps, this)
  }

  function startSlotbarPresetsTutorial()
  {
    local tutorialCounter = SlotbarPresetsTutorial.getCounter()
    if (tutorialCounter >= SlotbarPresetsTutorial.MAX_TUTORIALS)
      return false

    local currentGameMode = ::game_mode_manager.getCurrentGameMode()
    if (currentGameMode == null)
      return false

    local missionCounter = ::stat_get_value_missions_completed(currentGameMode.diffCode, 1)
    if (missionCounter >= SlotbarPresetsTutorial.MAX_PLAYS_FOR_GAME_MODE)
      return false

    local tutorial = SlotbarPresetsTutorial()
    tutorial.currentCountry = getCurCountry()
    tutorial.currentHandler = this
    tutorial.onComplete = function (params) {
      slotbarPresetsTutorial = null
    }.bindenv(this)
    tutorial.preset = ::game_mode_manager.findPresetValidForCurrentGameMode(getCurCountry())
    if (tutorial.startTutorial())
    {
      slotbarPresetsTutorial = tutorial
      return true
    }
    return false
  }
}

function is_need_check_tutorial(diff)
{
  return diff > 0
}

function isDiffUnlocked(diff, checkUnitType)
{
  //check played before
  for(local d = diff; d<3; d++)
    if (::my_stats.getTimePlayed(checkUnitType, d) >= ::req_time_in_mode)
      return true

  local reqName = ::get_req_tutorial(checkUnitType)
  if (reqName == "")
    return true

  local mainGameMode = ::get_mp_mode()
  ::set_mp_mode(::GM_TRAINING)  //req to check progress

  local chapters = ::get_meta_missions_info_by_chapters(::GM_TRAINING)
  foreach(chapter in chapters)
    foreach(m in chapter)
      if (reqName == m.name)
      {
        local fullMissionName = m.getStr("chapter", ::get_game_mode_name(::GM_TRAINING)) + "/" + m.name
        local progress = ::get_mission_progress(fullMissionName)
        if (mainGameMode >= 0)
          ::set_mp_mode(mainGameMode)
        return (progress<3 && progress>=diff) // 3 == unlocked, 0-2 - completed at difficulty
      }
  dagor.assertf(false, "Error: Not found mission ::req_tutorial_name = " + reqName)
  ::set_mp_mode(mainGameMode)
  return true
}

function getBrokenAirsInfo(countries, respawn, checkAvailFunc = null)
{
  local res = {
          canFlyout = true
          canFlyoutIfRepair = true
          canFlyoutIfRefill = true
          weaponWarning = false
          repairCost = 0
          broken_countries = [] // { country, airs }
          unreadyAmmoList = []
          unreadyAmmoCost = 0
          unreadyAmmoCostGold = 0

          haveRespawns = respawn
          randomCountry = countries.len() > 1
        }

  local readyWeaponsFound = false
  local unreadyAmmo = []
  if (!respawn)
  {
    local selList = getSelAirsTable()
    foreach(c, airName in selList)
      if ((::isInArray(c, countries)) && airName!="")
      {
        local repairCost = ::wp_get_repair_cost(airName)
        if (repairCost > 0)
        {
          res.repairCost += repairCost
          res.broken_countries.append({ country = c, airs = [airName] })
          res.canFlyout = false
        }
        local air = getAircraftByName(airName)
        local crew = air && getCrewByAir(air)
        if (!crew || ::is_crew_locked_by_prev_battle(crew))
          res.canFlyoutIfRepair = false

        local ammoList = ::getUnitNotReadyAmmoList(air, ::UNIT_WEAPONS_WARNING)
        if (ammoList.len())
          unreadyAmmo.extend(ammoList)
        else
          readyWeaponsFound = true
      }
  }
  else
    foreach(cc in ::g_crews_list.get())
      if (::isInArray(cc.country, countries))
      {
        local have_repaired_in_country = false
        local have_unlocked_in_country = false
        local brokenList = []
        foreach (crew in cc.crews)
        {
          local unit = ::g_crew.getCrewUnit(crew)
          if (!unit || (checkAvailFunc && !checkAvailFunc(unit)))
            continue

          local repairCost = ::wp_get_repair_cost(unit.name)
          if (repairCost > 0)
          {
            brokenList.append(unit.name)
            res.repairCost += repairCost
          }
          else
            have_repaired_in_country = true

          if (!::is_crew_locked_by_prev_battle(crew))
            have_unlocked_in_country = true

          local ammoList = ::getUnitNotReadyAmmoList(unit, ::UNIT_WEAPONS_WARNING)
          if (ammoList.len())
            unreadyAmmo.extend(ammoList)
          else
            readyWeaponsFound = true
        }
        res.canFlyout = res.canFlyout && have_repaired_in_country
        res.canFlyoutIfRepair = res.canFlyoutIfRepair && have_unlocked_in_country
        if (brokenList.len() > 0)
          res.broken_countries.append({ country = cc.country, airs = brokenList })
      }
  res.canFlyout = res.canFlyout && res.canFlyoutIfRepair

  local allUnitsMustBeReady = countries.len() > 1
  if (unreadyAmmo.len() && (allUnitsMustBeReady || (!allUnitsMustBeReady && !readyWeaponsFound)))
  {
    res.weaponWarning = true
    res.canFlyoutIfRefill = res.canFlyout

    res.canFlyout = false

    res.unreadyAmmoList = unreadyAmmo
    foreach(ammo in unreadyAmmo)
    {
      local cost = ::getAmmoCost(::getAircraftByName(ammo.airName), ammo.ammoName, ammo.ammoType)
      res.unreadyAmmoCost     += ammo.buyAmount * cost.wp
      res.unreadyAmmoCostGold += ammo.buyAmount * cost.gold
    }
  }
  return res
}

function checkBrokenAirsAndDo(repairInfo, handler, startFunc, canRepairWholeCountry = true, cancelFunc = null)
{
  if (repairInfo.weaponWarning && repairInfo.unreadyAmmoList)
  {
    local msg = ::loc(repairInfo.haveRespawns ? "msgbox/all_planes_zero_ammo_warning" : "controls/no_ammo_left_warning")
    msg += "\n\n" + format(::loc("buy_unsufficient_ammo"), ::Cost(repairInfo.unreadyAmmoCost, repairInfo.unreadyAmmoCostGold).tostring())

    ::gui_start_modal_wnd(::gui_handlers.WeaponWarningHandler,
      {
        parentHandler = handler
        message = msg
        startBtnText = ::loc("mainmenu/btnBuy")
        ableToStartAndSkip = true
        onStartPressed = (@(repairInfo, handler, startFunc, canRepairWholeCountry) function() {
          buyAllAmmoAndApply(handler, repairInfo.unreadyAmmoList,
            (@(repairInfo, handler, startFunc, canRepairWholeCountry) function() {
              repairInfo.weaponWarning = false
              repairInfo.canFlyout = repairInfo.canFlyoutIfRefill
              ::checkBrokenAirsAndDo(repairInfo, handler, startFunc, canRepairWholeCountry)
            })(repairInfo, handler, startFunc, canRepairWholeCountry),
            repairInfo.unreadyAmmoCost, repairInfo.unreadyAmmoCostGold
          )
        })(repairInfo, handler, startFunc, canRepairWholeCountry)
        cancelFunc = cancelFunc
      })
    return
  }

  local repairAll = function()
  {
    local rCost = ::Cost(repairInfo.repairCost)
    ::repairAllAirsAndApply(handler, repairInfo.broken_countries, startFunc, cancelFunc, canRepairWholeCountry, rCost)
  }

  local onCancel = function() { ::call_for_handler(handler, cancelFunc) }

  if (!repairInfo.canFlyout)
  {
    local msgText = ""
    local respawns = repairInfo.haveRespawns
    if (respawns)
      msgText = repairInfo.randomCountry ? "msgbox/no_%s_aircrafts_random" : "msgbox/no_%s_aircrafts"
    else
      msgText = repairInfo.randomCountry ? "msgbox/select_%s_aircrafts_random" : "msgbox/select_%s_aircraft"

    if(repairInfo.canFlyoutIfRepair)
      msgText = ::format(::loc(::format(msgText, "repared")), ::Cost(repairInfo.repairCost).tostring())
    else
      msgText = ::format(::loc(::format(msgText, "available")),
        time.secondsToString(::get_warpoints_blk().lockTimeMaxLimitSec || 0))

    local repairBtnName = respawns ? "RepairAll" : "Repair"
    local buttons = repairInfo.canFlyoutIfRepair ?
                      [[repairBtnName, repairAll], ["cancel", onCancel]] :
                      [["ok", onCancel]]
    local defButton = repairInfo.canFlyoutIfRepair ? repairBtnName : "ok"
    handler.msgBox("no_aircrafts", msgText, buttons, defButton)
    return
  }
  else if (repairInfo.broken_countries.len() > 0)
  {
    local msgText = repairInfo.randomCountry ? ::loc("msgbox/some_repared_aircrafts_random") : ::loc("msgbox/some_repared_aircrafts")
    msgText = format(msgText, ::Cost(repairInfo.repairCost).tostring())
    ::scene_msg_box("no_aircrafts", null, msgText,
       [
         ["ContinueWithoutRepair", function() { startFunc.call(handler) }],
         ["RepairAll", repairAll],
         ["cancel", onCancel]
       ], "RepairAll")
    return
  }
  else
    startFunc.call(handler)
}

function repairAllAirsAndApply(handler, broken_countries, afterDoneFunc, onCancelFunc, canRepairWholeCountry = true, totalRCost=null)
{
  if (!handler)
    return

  if (broken_countries.len()==0)
  {
    afterDoneFunc.call(handler)
    return
  }

  if (totalRCost)
  {
    local afterCheckFunc = function() {
      if (::check_balance_msgBox(totalRCost, null, true))
        ::repairAllAirsAndApply(handler, broken_countries, afterDoneFunc, onCancelFunc, canRepairWholeCountry)
      else if (onCancelFunc)
        onCancelFunc.call(handler)
    }
    if (!::check_balance_msgBox(totalRCost, afterCheckFunc))
      return
  }

  local taskId = -1

  if (broken_countries[0].airs.len() == 1 || !canRepairWholeCountry)
    taskId = ::shop_repair_aircraft(broken_countries[0].airs[0])
  else
    taskId = ::shop_repair_all(broken_countries[0].country, true)

  if (broken_countries[0].airs.len() > 1 && !canRepairWholeCountry)
    broken_countries[0].airs.remove(0)
  else
    broken_countries.remove(0)

  if (taskId >= 0)
  {
    local progressBox = ::scene_msg_box("char_connecting", null, ::loc("charServer/purchase0"), null, null)
    ::add_bg_task_cb(taskId, function()
    {
      ::destroyMsgBox(progressBox)
      ::repairAllAirsAndApply(handler, broken_countries, afterDoneFunc, onCancelFunc, canRepairWholeCountry)
    })
  }
}

function buyAllAmmoAndApply(handler, unreadyAmmoList, afterDoneFunc, totalCost = 0, totalCostGold = 0)
{
  if (!handler)
    return

  if (unreadyAmmoList.len()==0)
  {
    afterDoneFunc.call(handler)
    return
  }

  if (!::old_check_balance_msgBox(totalCost, totalCostGold))
    return

  local ammo = unreadyAmmoList[0]
  local taskId = -1

  if (ammo.ammoType==AMMO.WEAPON)
    taskId = ::shop_purchase_weapon(ammo.airName, ammo.ammoName, ammo.buyAmount)
  else
  if (ammo.ammoType==AMMO.MODIFICATION)
    taskId = ::shop_purchase_modification(ammo.airName, ammo.ammoName, ammo.buyAmount, false)
  unreadyAmmoList.remove(0)

  if (taskId >= 0)
  {
    local progressBox = ::scene_msg_box("char_connecting", null, ::loc("charServer/purchase0"), null, null)
    ::add_bg_task_cb(taskId, (@(handler, unreadyAmmoList, afterDoneFunc, progressBox) function() {
      ::destroyMsgBox(progressBox)
      ::buyAllAmmoAndApply(handler, unreadyAmmoList, afterDoneFunc)
    })(handler, unreadyAmmoList, afterDoneFunc, progressBox))
  }
}
