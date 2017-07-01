::last_ca_aircraft <- null
::last_ca_base <- null
::used_planes <- {}
::need_race_finish_results <- false

::before_first_flight_in_session <- false

::g_script_reloader.registerPersistentData("RespawnGlobals", ::getroottable(),
  ["last_ca_aircraft", "last_ca_base", "used_planes", "need_race_finish_results", "before_first_flight_in_session"])

::COLORED_DROPRIGHT_TEXT_STYLE <- "textStyle:t='textarea';"

enum ESwitchSpectatorTarget
{
  E_DO_NOTHING,
  E_NEXT,
  E_PREV
}

::respawn_options <- [
  {id = "skin",        hint = "options/skin",                   user_option = ::USEROPT_SKIN },
  {id = "user_skins",  hint = "options/user_skins",             user_option = ::USEROPT_USER_SKIN },
  {id = "gundist",     hint = "options/gun_target_dist",        user_option = ::USEROPT_GUN_TARGET_DISTANCE},
  {id = "gunvertical", hint = "options/gun_vertical_targeting", user_option = ::USEROPT_GUN_VERTICAL_TARGETING},
  {id = "bombtime",    hint = "options/bomb_activation_time",   user_option = ::USEROPT_BOMB_ACTIVATION_TIME},
  {id = "rocket_fuse_dist",  hint = "options/rocket_fuse_dist",       user_option = ::USEROPT_ROCKET_FUSE_DIST},
  {id = "fuel",        hint = "options/fuel_amount",            user_option = ::USEROPT_LOAD_FUEL_AMOUNT},
  {id = "respawn_base",hint = "options/respawn_base",        cb = "onRespawnbaseOptionUpdate", use_margin_top = true},
]

function gui_start_respawn(is_match_start = false)
{
  ::mp_stat_handler = ::handlersManager.loadHandler(::gui_handlers.RespawnHandler)
  ::mp_stat_handler.initStats()
  ::mp_stat_handler.onUpdate(null, 0.03)
  ::handlersManager.setLastBaseHandlerStartFunc(::gui_start_respawn)
}

class ::gui_handlers.RespawnHandler extends ::gui_handlers.MPStatistics
{
  sceneBlkName = "gui/respawn.blk"
  keepLoaded = true
  wndControlsAllowMask = CtrlsInGui.CTRL_ALLOW_NONE

  showButtons = true
  sessionWpBalance = 0

  slotDelayDataByCrewIdx = {}

  //temporary hack before real fix will appear at all platforms.
  needCheckSlotReady = true //!::is_version_equals_or_newer("1.51.7.81")
  slotReadyAtHostMask = 0
  slotsCostSum = 0 //refreash slotbar when unit costs sum will changed after initslotbar.

  isFirstInit = true
  weaponsSelectorWeak = null
  teamUnitsLeftWeak = null

  canSwitchChatSize = false
  isChatFullSize = true

  isModeStat = false
  showLocalTeamOnly = true
  isStatScreen = false

  haveSlots = false
  haveSlotbar = false
  canChangeAircraft = false
  stayOnRespScreen = false
  haveRespawnBases = false
  canChooseRespawnBase = false
  respawnBasesInfo = []
  isNoRespawns = false
  isRespawn = false //use for called respawn from battle on M or Tab
  needRefreshSlotbarOnReinit = false

  noRespText = ""
  applyText = ""

  tmapBtnObj  = null
  tmapHintObj = null

  lastRequestData = null
  lastSpawnUnitName = ""
  requestInProgress = false

  readyForRespawn = true  //aircraft and weapons choosen
  doRespawnCalled = false
  respawnRecallTimer = -1.0
  autostartTimer = -1
  autostartTime = 0
  autostartShowTime = 0
  autostartShowInColorTime = 0

  spectator_switch_timer_max = 0.5
  spectator_switch_timer = 0
  spectator_switch_direction = ESwitchSpectatorTarget.E_DO_NOTHING

  filterTags = []
  gunDescr = null
  bulletsDescr = array(::BULLETS_SETS_QUANTITY, null)
  fuelDescr = null
  bombDescr = null
  rocketDescr = null
  skins = null

  missionRules = null
  slotbarCheckTags = true
  slotbarInited = false
  leftRespawns = -1
  customStateCrewAvailableMask = 0
  curSpawnScore = 0
  crewsSpawnScoreMask = 0 //mask of crews available by spawn score


  // debug vars
  timeToAutoSelectAircraft = 0.0
  timeToAutoStart = 0.0

  // Debug vars
  timeToAutoRespawn = 0.0

  prevUnitAutoChangeTimeMsec = -1
  prevAutoChangedUnit = null
  delayAfterAutoChangeUnitMsec = 1000

  focusArray = [
    function() { return getCurrentTopGCPanel() }     //gamercard
    function() { return null }                    //gamercard menu
    function() { return getCurrentAirsTable() }   // slotbar
    function() { return getFocusObjUnderSlotbar() }
    "respawn_options_table"
    "mis_obj_button_header"
    "chat_tabs"
    "chat_input"
  ]
  focusItemAirsTable = 2
  focusItemChatTabs  = 4
  focusItemChatInput = 5

  currentFocusItem = 2

  function initScreen()
  {
    missionRules = ::g_mis_custom_state.getCurMissionRules()

    checkFirstInit()

    ::disable_flight_menu(true)

    needPlayersTbl = false
    isApplyPressed = false
    doRespawnCalled = false
    local wasIsRespawn = isRespawn
    isRespawn = ::is_respawn_screen()
    needRefreshSlotbarOnReinit = isRespawn || wasIsRespawn

    gameMode = ::get_game_mode()
    gameType = ::get_game_type()

    updateCooldown = -1
    wasTimeLeft = -1000
    mplayerTable = ::get_local_mplayer() || {}
    missionTable = missionRules.missionParams

    readyForRespawn = readyForRespawn && isRespawn
    recountStayOnRespScreen()

    updateSpawnScore(true)
    updateLeftRespawns()

    local blk = ::dgs_get_game_params()
    autostartTime = blk.autostartTime;
    autostartShowTime = blk.autostartShowTime;
    autostartShowInColorTime = blk.autostartShowInColorTime;

    dagor.debug("stayOnRespScreen = "+stayOnRespScreen)

    local spectator = isSpectator()
    haveSlotbar = (gameType & (::GT_VERSUS | ::GT_COOPERATIVE)) &&
                  (gameMode != ::GM_SINGLE_MISSION && gameMode != ::GM_DYNAMIC) &&
                  !spectator
    canChangeAircraft = haveSlotbar && !stayOnRespScreen && isRespawn

    if (fetch_change_aircraft_on_start() && !stayOnRespScreen && !spectator)
    {
      dagor.debug("fetch_change_aircraft_on_start() true")
      isRespawn = true
      stayOnRespScreen = false
      canChangeAircraft = true
    }

    if (missionRules.isScoreRespawnEnabled)
      canChangeAircraft = canChangeAircraft && curSpawnScore >= missionRules.getMinimalRequiredSpawnScore()
    canChangeAircraft = canChangeAircraft && leftRespawns != 0

    setSpectatorMode(isRespawn && stayOnRespScreen, true)
    createRespawnOptions()

    loadChat()

    updateRespawnBasesStatus()
    initAircraftSelect()
    init_options() //for disable menu only

    updateApplyText()
    updateButtons()
    ::add_tags_for_mp_players()

    currentFocusItem = canChangeAircraft && !isSpectate ? focusItemAirsTable :
      ::ps4_is_chat_enabled() ? focusItemChatInput :
      focusItemChatTabs
    restoreFocus()

    showSceneBtn("screen_button_back", ::use_touchscreen && !isRespawn)

    if (gameType & ::GT_RACE)
    {
      local finished = ::race_finished_by_local_player()
      if (finished && ::need_race_finish_results)
        ::gui_start_mpstatscreen_from_game()
      ::need_race_finish_results = !finished
    }

    local ordersButton = scene.findObject("btn_activateorder")
    if (::checkObj(ordersButton))
      ordersButton.setUserData(this)

    updateControlsAllowMask()
  }

  function recountStayOnRespScreen() //return isChanged
  {
    local newHaveSlots = ::has_available_slots()
    local newStayOnRespScreen = missionRules.isStayOnRespScreen() || !newHaveSlots
    if ((newHaveSlots == haveSlots) && (newStayOnRespScreen == stayOnRespScreen))
      return false

    haveSlots = newHaveSlots
    stayOnRespScreen = newStayOnRespScreen
    return true
  }

  function checkFirstInit()
  {
    if (!isFirstInit)
      return
    isFirstInit = false

    scene.findObject("stat_update").setUserData(this)

    subHandlers.extend([
      ::gui_load_mission_objectives(scene.findObject("primary_tasks_list"),   true, 1 << ::OBJECTIVE_TYPE_PRIMARY)
      ::gui_load_mission_objectives(scene.findObject("secondary_tasks_list"), true, 1 << ::OBJECTIVE_TYPE_SECONDARY)
    ])

    local navBarObj = scene.findObject("gamercard_bottom_navbar_place")
    if (::checkObj(navBarObj))
    {
      navBarObj.show(true)
      navBarObj["id"] = "nav-help"
      guiScene.replaceContent(navBarObj, "gui/navRespawn.blk", this)
    }

    includeMissionInfoBlocksToGamercard()
    initMisObjExpandButton()
    initTeamUnitsLeftView()
  }

  function initTeamUnitsLeftView()
  {
    local handler = ::handlersManager.loadHandler(::gui_handlers.teamUnitsLeftView,
                                      { scene = scene.findObject("team_units_left_respawns")
                                        parentHandlerWeak = this
                                      })
    registerSubHandler(handler)
    teamUnitsLeftWeak = handler.weakref()
  }

  function getFocusObjUnderSlotbar()
  {
    local obj = teamUnitsLeftWeak && teamUnitsLeftWeak.getMainFocusObj()
    if (::checkObj(obj) && obj.isFocused())
      return obj

    return weaponsSelectorWeak && weaponsSelectorWeak.getMainFocusObj()
  }

  function onWrapLeft(obj)
  {
    local newObj = weaponsSelectorWeak && weaponsSelectorWeak.getMainFocusObj()
    if (::checkObj(newObj))
      newObj.select()
  }

  function onWrapRight(obj)
  {
    local newObj = teamUnitsLeftWeak && teamUnitsLeftWeak.getMainFocusObj()
    if (::checkObj(newObj))
      newObj.select()
  }

  /*override*/ function onSceneActivate(show)
  {
    setOrdersEnabled(show && isSpectate)
    updateSpectatorRotationForced(show)
    base.onSceneActivate(show)
  }

  function getOrderStatusObj()
  {
    local statusObj = scene.findObject("respawn_order_status")
    return ::checkObj(statusObj) ? statusObj : null
  }

  function isSpectator()
  {
    return ::getTblValue("spectator", mplayerTable, false)
  }

  function updateRespawnBasesStatus() //return is isNoRespawns changed
  {
    local wasIsNoRespawns = isNoRespawns
    if (gameType & ::GT_COOPERATIVE)
    {
      isNoRespawns = false
      updateNoRespawnText()
      return wasIsNoRespawns != isNoRespawns
    }

    noRespText = ""
    if (!::g_mis_loading_state.isReadyToShowRespawn())
    {
      isNoRespawns = true
      readyForRespawn = false
      noRespText = ::loc("multiplayer/loadingMissionData")
    } else
    {
      local isAnyBases = missionRules.isAnyUnitHaveRespawnBases()
      readyForRespawn = readyForRespawn && isAnyBases

      isNoRespawns = true
      if (!isAnyBases)
        noRespText = ::loc("multiplayer/noRespawnBasesLeft")
      else if (missionRules.isScoreRespawnEnabled && curSpawnScore < missionRules.getMinimalRequiredSpawnScore())
        noRespText = isRespawn? ::loc("multiplayer/noSpawnScore") : ""
      else if (leftRespawns == 0)
        noRespText = ::loc("multiplayer/noRespawnsInMission")
      else if (!haveSlots)
        noRespText = ::loc("multiplayer/noCrewsLeft")
      else
        isNoRespawns = false
    }

    updateNoRespawnText()

    tmapBtnObj  = scene.findObject("tmap_btn")
    tmapHintObj = scene.findObject("tmap_hint")
    return wasIsNoRespawns != isNoRespawns
  }

  function updateCurSpawnScoreText()
  {
    local scoreObj = scene.findObject("gc_spawn_score")
    if (::checkObj(scoreObj) && missionRules.isScoreRespawnEnabled)
      scoreObj.setValue(::getCompoundedText(::loc("multiplayer/spawnScore") + " ", curSpawnScore, "activeTextColor"))
  }

  function updateSpawnScore(isOnInit = false)
  {
    if (!missionRules.isScoreRespawnEnabled)
      return

    local newSpawnScore = missionRules.getCurSpawnScore()
    if (!isOnInit && curSpawnScore == newSpawnScore)
      return

    curSpawnScore = newSpawnScore

    local newSpawnScoreMask = calcCrewSpawnScoreMask()
    if (crewsSpawnScoreMask != newSpawnScoreMask)
    {
      crewsSpawnScoreMask = newSpawnScoreMask
      if (!isOnInit)
        return reinitScreen({})
    }

    updateCurSpawnScoreText()
  }

  function calcCrewSpawnScoreMask()
  {
    local res = 0
    foreach(idx, crew in ::get_country_crews(::get_local_player_country()))
    {
      local unit = ::g_crew.getCrewUnit(crew)
      if (unit && ::shop_get_spawn_score(unit.name, "") >= curSpawnScore)
        res = res | (1 << idx)
    }
    return res
  }

  function updateLeftRespawns()
  {
    leftRespawns = missionRules.getLeftRespawns()
    customStateCrewAvailableMask = missionRules.getCurCrewsRespawnMask()
  }

  function onEventChangedMissionRespawnBasesStatus(params)
  {
    local isStayOnrespScreenChanged = recountStayOnRespScreen()
    local isNoRespawnsChanged = updateRespawnBasesStatus()
    if (!stayOnRespScreen  && !isNoRespawns
        && (isStayOnrespScreenChanged || isNoRespawnsChanged))
    {
      reinitScreen({})
      return
    }

    reinitSlotbar()
    updateOtherOptions()
    updateButtons()
    updateApplyText()
    checkReady()
    restoreFocus()
  }

  function updateNoRespawnText()
  {
    local noRespObj = scene.findObject("txt_no_respawn_bases")
    if (::checkObj(noRespObj))
    {
      noRespObj.setValue(noRespText)
      noRespObj.show(isNoRespawns)
    }
  }

  function reinitScreen(params = {})
  {
    setParams(params)
    initScreen()

    delayedRestoreFocus()
  }

  function createRespawnOptions()
  {
    local dObj = scene.findObject("respawn_options_table")
    local optionObj = dObj.findObject("option_row_sample")
    local newOptionObj = null

    if(!::checkObj(optionObj))
      return

    foreach (option in ::respawn_options)
    {
      local newOptLableObj = null
      local newDroprightObj = null
      newOptionObj = optionObj.getClone(dObj, this)
      newOptionObj.id = option.id + "_tr"

      newOptLableObj = newOptionObj.findObject("option_lable")
      newOptLableObj.id = "lbl_" + option.id
      newOptLableObj.setValue(::loc(option.hint))

      newDroprightObj = newOptionObj.findObject("option")
      newDroprightObj.id = option.id
      if ("cb" in option && option.cb)
        newDroprightObj.on_select = option.cb
      else
        newDroprightObj.on_select = "checkReady"

      newOptionObj.show(true)
      newOptionObj.enable(isRespawn)
    }
    guiScene.destroyElement(optionObj)
  }

  function initAircraftSelect()
  {
    local team = ::get_mp_local_team()
    local country = ::get_local_player_country()

    filterTags = []
    ::set_aircrafts_filter(filterTags)

    foreach(tag in ::aircrafts_filter_tags)
      dagor.debug("Filter by tag: "+tag.tostring());

    if (::show_aircraft == null)
      ::show_aircraft = getAircraftByName(::last_ca_aircraft)

    dagor.debug("initScreen aircraft "+ ::last_ca_aircraft + " show_aircraft " + ::show_aircraft);

    scene.findObject("CA_div").show(haveSlotbar)
    updateSessionWpBalance()

    if (haveSlotbar)
    {
      local needWaitSlotbar = !::g_mis_loading_state.isReadyToShowRespawn() && !isSpectator()
      showSceneBtn("slotbar_load_wait", needWaitSlotbar)
      if (!isSpectator() && ::g_mis_loading_state.isReadyToShowRespawn()
          && (needRefreshSlotbarOnReinit || !::checkObj(slotbarScene)))
      {
        slotbarInited = false
        beforeRefreshSlotbar()
        ::init_slotbar(this, scene.findObject("flight_menu_bgd"), false, country, getSlotbarParams())
        afterRefreshSlotbar()
        slotReadyAtHostMask = getCrewSlotReadyMask()
        slotbarInited = true
        updateUnitOptions()

        scene.findObject("respawn_options_table").select()
        if (canChangeAircraft)
          readyForRespawn = false
      }
    }
    else
    {
      ::destroy_slotbar(this)
      local airName = ::last_ca_aircraft
      if (gameType & ::GT_COOPERATIVE)
        airName = ::getTblValue("aircraftName", mplayerTable, "")
      local air = ::getAircraftByName(airName)
      if (air)
      {
        scene.findObject("air_info_div").show(true)

        local data = ::build_aircraft_item(air.name, air, {
          showBR        = ::has_feature("SlotbarShowBattleRating")
          getEdiffFunc  = getCurrentEdiff.bindenv(this)
        })
        guiScene.replaceContentFromText(scene.findObject("air_item_place"), data, data.len(), this)
        ::fill_unit_item_timers(scene.findObject("air_item_place").findObject(air.name), air)
      }
    }

    setRespawnCost()
    reset_mp_autostart_countdown();
  }

  function getSlotbarParams()
  {
    return {
      toBattle = canChangeAircraft
      haveRespawnCost = missionRules.hasRespawnCost
      haveSpawnDelay = missionRules.isSpawnDelayEnabled
      totalSpawnScore = curSpawnScore
      sessionWpBalance = sessionWpBalance
      checkRespawnBases = true
      active = false
      missionRules = missionRules
      hasExtraInfoBlock = true
    }
  }

  function updateSessionWpBalance()
  {
    if (!(missionRules.isWarpointsRespawnEnabled && isRespawn))
      return

    local info = ::get_cur_rank_info()
    local curWpBalance = ::get_cur_warpoints()
    sessionWpBalance = curWpBalance + info.cur_award_positive - info.cur_award_negative
  }

  function setRespawnCost()
  {
    local showWPSpend = missionRules.isWarpointsRespawnEnabled && isRespawn
    local wpBalance = ""
    if (showWPSpend)
    {
      updateSessionWpBalance()
      local info = ::get_cur_rank_info()
      local curWpBalance = ::get_cur_warpoints()
      local total = sessionWpBalance
      if (curWpBalance != total || (info.cur_award_positive != 0 && info.cur_award_negative != 0))
      {
        local curWpBalanceString = ::getWpPriceText(curWpBalance, true)
        local curPositiveIncrease = ""
        local curNegativeDecrease = ""
        local color = info.cur_award_positive > 0? "good" : "bad"
        local curDifference = info.cur_award_positive
        if (info.cur_award_positive < 0)
        {
          curDifference = info.cur_award_positive - info.cur_award_negative
          color = "bad"
        }
        else if (info.cur_award_negative != 0)
          curNegativeDecrease = "<color=@badTextColor>" + ::getWpPriceText(-1*info.cur_award_negative, true) + "</color>"

        if (curDifference != 0)
          curPositiveIncrease = "<color=@" + color + "TextColor>" + (curDifference > 0? "+" : "") + ::getWpPriceText(curDifference, true) + "</color>"

        local totalString = " = <color=@activeTextColor>" + ::getWpPriceText(total, true) + "</color>"
        wpBalance = curWpBalanceString + curPositiveIncrease + curNegativeDecrease + totalString
      }
    }

    local balanceObj = getObj("gc_wp_respawn_balance")
    if (::checkObj(balanceObj))
    {
      local text = ""
      if (wpBalance != "")
        text = ::getCompoundedText(::loc("multiplayer/wp_header"), wpBalance, "activeTextColor")
      balanceObj.setValue(text)
    }
  }

  function getRespawnTotalCost(getInt = false)
  {
    if(!missionRules.isWarpointsRespawnEnabled)
      return ""

    local air = getSlotAircraft(curSlotCountryId, curSlotIdInCountry)
    local slotItem = getSlotItem(curSlotCountryId, curSlotIdInCountry)
    local airRespawnCost = (slotItem && "wpToRespawn" in slotItem) ? slotItem.wpToRespawn : 0
    local weaponPrice = (air && "name" in air) ? getWeaponPrice(air.name, getSelWeapon()) : 0

    local total = airRespawnCost + weaponPrice
    if (getInt)
      return total

    return ::getPriceText(total, 0, false)
  }

  function reinitSlotbarAction(newCrewMask = -1)
  {
    beforeRefreshSlotbar()
    base.reinitSlotbarAction()
    afterRefreshSlotbar()
    updateApplyText()

    if (!needCheckSlotReady)
      return

    slotReadyAtHostMask = (newCrewMask == -1) ? getCrewSlotReadyMask() : newCrewMask
    slotsCostSum = getSlotsSpawnCostSumNoWeapon()
  }

  function isInAutoChangeDelay()
  {
    return ::dagor.getCurTime() - prevUnitAutoChangeTimeMsec < delayAfterAutoChangeUnitMsec
  }

  function beforeRefreshSlotbar()
  {
    if (slotbarScene && !isInAutoChangeDelay())
      prevAutoChangedUnit = getSlotAircraft(curSlotCountryId, curSlotIdInCountry)
  }

  function afterRefreshSlotbar()
  {
    local curUnit = getSlotAircraft(curSlotCountryId, curSlotIdInCountry)
    if (curUnit && curUnit != prevAutoChangedUnit)
      prevUnitAutoChangeTimeMsec = ::dagor.getCurTime()
  }

  //hack: to check slotready changed
  function checkCrewAccessChange()
  {
    if (!slotbarCountry || !slotbarInited)
      return

    local needReinitSlotbar = false

    local newMask = getCrewSlotReadyMask()
    if (newMask != slotReadyAtHostMask)
    {
      dagor.debug("Error: is_crew_slot_was_ready_at_host or is_crew_available_in_session have changed without cb. force reload slots")
      statsd_counter("errors.changeDisabledSlots." + ::get_current_mission_name())
      needReinitSlotbar = true
    }

    local newSlotsCostSum = getSlotsSpawnCostSumNoWeapon()
    if (newSlotsCostSum != slotsCostSum)
    {
      dagor.debug("Error: slots spawn cost have changed without cb. force reload slots")
      statsd_counter("errors.changedSlotsSpawnCost." + ::get_current_mission_name())
      needReinitSlotbar = true
    }

    if (needReinitSlotbar)
      reinitSlotbarAction(newMask)
  }

  function getCrewSlotReadyMask()
  {
    local res = 0
    if (!::g_mis_loading_state.isCrewsListReceived())
      return res

    local MAX_UNIT_SLOTS = 16
    for(local i = 0; i < MAX_UNIT_SLOTS; i++)
      if (::is_crew_slot_was_ready_at_host(i, "", false) && ::is_crew_available_in_session(i, false))
        res += (1 << i)
    return res
  }

  function getSlotsSpawnCostSumNoWeapon()
  {
    local res = 0
    local crewsCountry = ::getTblValue(curSlotCountryId, ::crews_list)
    if (!crewsCountry)
      return res

    foreach(crew in crewsCountry.crews)
    {
      local unit = ::g_crew.getCrewUnit(crew)
      if (unit)
        res += ::shop_get_spawn_score(unit.name, "")
    }
    return res
  }

  function onSlotbarSelect(obj)
  {
    if (!::checkObj(obj))
      return

    local tblId = obj.id
    if ((tblId.len() <= 11) || (tblId.slice(0, 11) != "airs_table_"))
      return
    local newCountryId = tblId.slice(11).tointeger()
    local cur_col = obj.cur_col.tointeger()
    local newIdInCountry = -1
    local trObj = obj.getChild(0)
    if (cur_col >= 0 && cur_col < trObj.childrenCount())
    {
      local curObjId = trObj.getChild(cur_col).getChild(0).id
      local prefix = "slot_"+newCountryId+"_"
      if (curObjId && curObjId.len() > prefix.len() && curObjId.find(prefix) == 0)
        newIdInCountry = curObjId.slice(prefix.len()).tointeger()
    }

    if (newIdInCountry < 0
        || curSlotCountryId == newCountryId && curSlotIdInCountry == newIdInCountry)
      return

    if (!canChangeAircraft && slotbarInited)
    {
      selectTblAircraft(obj, curSlotIdInCountry)
      return
    }

    local air = getSlotAircraft(newCountryId, newIdInCountry)
    local available = ::is_crew_available_in_session(newIdInCountry, false)

    if (air && (available || !slotbarInited))  //can init wnd without any available aircrafts
    {
      curSlotCountryId = newCountryId
      curSlotIdInCountry = newIdInCountry
      if (!air)
      {
        ::callstack()
        dagor.assert(true, "Respawn, no unit on selected crew")
      }
      else
      {
        if (slotbarInited)
          prevUnitAutoChangeTimeMsec = -1
        ::cur_aircraft_name = air.name
        updateRespawnBases(air)
      }

      slotbarInited=true
      onAircraftUpdate(obj)
      return
    }

    if (!::has_available_slots())
      return

    local msgId = "not_available_aircraft"
    if (!available && ::getTblValue("useKillStreaks", missionTable) && ::get_es_unit_type(air) == ::ES_UNIT_TYPE_AIRCRAFT)
      msgId = "msg/need_more_kills_for_aircraft"

    msgBox("not_available_air", ::loc(msgId),
      [
        ["ok", (@(obj) function() { selectTblAircraft(obj, curSlotIdInCountry) })(obj) ]
      ], "ok")
  }

  function onSlotbarDblClick(obj) {onApply(obj)}
  function onSlotbarCountry(obj) {}
  function onSlotBattle(obj) {onApply(obj)}

  function updateWeaponsSelector()
  {
    local unit = getSlotAircraft(curSlotCountryId, curSlotIdInCountry)
    local canChangeWeaponry = canChangeAircraft
    if (weaponsSelectorWeak)
    {
      weaponsSelectorWeak.setUnit(unit)
      weaponsSelectorWeak.updateAllItems()
      weaponsSelectorWeak.setCanChangeWeaponry(canChangeWeaponry)
      delayedRestoreFocus()
      return
    }

    local handler = ::handlersManager.loadHandler(::gui_handlers.unitWeaponsHandler,
                                       { scene = scene.findObject("unit_weapons_selector")
                                         unit = unit
                                         parentHandlerWeak = this
                                         canShowPrice = true
                                         canChangeWeaponry = canChangeWeaponry
                                       })

    weaponsSelectorWeak = handler.weakref()
    registerSubHandler(handler)
    delayedRestoreFocus()
  }

  function showOptionRow(id, show)
  {
    local obj = scene.findObject(id + "_tr")
    if (!::checkObj(obj))
      return false

    obj.show(show)
    obj.inactive = show ? null : "yes"
    return true
  }

  function getWeaponPrice(airName, weapon)
  {
    if(missionRules.isWarpointsRespawnEnabled
       && isRespawn
       && airName in ::used_planes
       && ::isInArray(weapon, ::used_planes[airName]))
    {
      local count = ::getAmmoMaxAmountInSession(airName, weapon, AMMO.WEAPON) - getAmmoAmount(airName, weapon, AMMO.WEAPON)
      return (count * ::wp_get_cost2(airName, weapon))
    }
    return 0
  }

  function onRespawnbaseOptionUpdate(obj)
  {
    if (!isRespawn)
      return

    local idx = ::checkObj(obj) ? obj.getValue() : 0
    local spawn = (idx in respawnBasesInfo) ? respawnBasesInfo[idx] : null
    ::select_respawnbase((spawn && spawn.mapSelectable) ? spawn.id : -1)
    ::last_ca_base = (spawn && spawn.id != -1) ? spawn.id : null
    checkReady()
  }

  function updateTacticalMapHint()
  {
    if (!isRespawn || !::checkObj(tmapHintObj))
      return

    local hint = ""
    local coords = ::get_mouse_relative_coords_on_obj(tmapBtnObj)
    if (coords)
    {
      if (canChooseRespawnBase)
      {
        local valid = false
        local spawnId = coords ? ::get_respawn_base(coords[0], coords[1]) : -1
        if (spawnId != -1)
          foreach (spawn in respawnBasesInfo)
            if (spawn.id == spawnId && spawn.mapSelectable)
            {
              valid = true
              hint = ::colorize("userlogColoredText", spawn.title)
              if (spawnId == ::last_ca_base)
                hint += ::colorize("activeTextColor", ::loc("ui/parentheses/space", { text = ::loc("ui/selected") }))
              break
            }

        if (!valid)
          hint = ::colorize("activeTextColor", ::loc("guiHints/respawn_base/choice_enabled"))
      }
      else
        hint = ::colorize("commonTextColor", ::loc("guiHints/respawn_base/choice_disabled"))
    }

    tmapHintObj.setValue(hint)
  }

  function onTacticalmapClick(obj)
  {
    if (!isRespawn || !::checkObj(scene) || !canChooseRespawnBase)
      return

    local coords = ::get_mouse_relative_coords_on_obj(tmapBtnObj)
    local spawnId = coords ? ::get_respawn_base(coords[0], coords[1]) : -1
    if (spawnId == ::last_ca_base)
      spawnId = -1

    local selIdx = -1
    if (spawnId != -1)
      foreach (idx, spawn in respawnBasesInfo)
        if (spawn.id == spawnId && spawn.mapSelectable)
        {
          selIdx = idx
          break
        }

    if (selIdx == -1)
      foreach (idx, spawn in respawnBasesInfo)
        if (!spawn.mapSelectable)
        {
          selIdx = idx
          break
        }

    if (selIdx != -1)
    {
      local optionObj = scene.findObject("respawn_base")
      if (::checkObj(optionObj))
        optionObj.setValue(selIdx)
    }
  }

  function onOtherOptionUpdate(obj)
  {
    reset_mp_autostart_countdown();
    if (!obj)
      return

    local air = getSlotAircraft(curSlotCountryId, curSlotIdInCountry)
    if (!air) return

    ::aircraft_for_weapons = air.name
    local option = getUserOptionInRespawnOptions(obj.id)
    if (!option)
      return

    local value = obj.getValue()
    ::set_option(option.type, value, option)
  }

  function getUserOptionInRespawnOptions(id)
  {
    if (!id)
      return null

    //search by respawn_option id
    foreach (option in ::respawn_options)
      if ("id" in option && option.id)
        if (id == option.id)
          if ("user_option" in option && option.user_option)
            return ::get_option(option.user_option)
          else
            return null

    //search by real option id
    foreach (option in ::respawn_options)
    {
      local optType = ::getTblValue("user_option", option)
      if (optType == null)
        continue

      local userOption = ::get_option(optType)
      if (userOption.id == id)
        return userOption
    }
    return null
  }

  function checkRocketDisctanceFuseRow()
  {
    local air = getSlotAircraft(curSlotCountryId, curSlotIdInCountry)
    if (!air)
      return

    local option = get_option(::USEROPT_ROCKET_FUSE_DIST)
    showOptionRow(option.id, ::is_unit_available_use_rocket_diffuse(air))
  }

  function updateSkin()
  {
    local air = getSlotAircraft(curSlotCountryId, curSlotIdInCountry)
    if (!air) return

    local data = ""
    local skinsData = ::g_decorator.getSkinsOption(air.name)
    skins = skinsData.values
    local selIndex = skinsData.value

    local items = skinsData.items
    if(!canChangeAircraft && skins.len() > 1)
      data = build_option_blk(items[selIndex], "", true)
    else
      for (local i = 0; i < skins.len(); i++)
        data += build_option_blk(items[i], "", i == selIndex)

    local skinObj = scene.findObject("skin")
    if (::checkObj(skinObj))
      guiScene.replaceContentFromText(skinObj, data, data.len(), this)
  }

  function updateUserSkins()
  {
    local air = getSlotAircraft(curSlotCountryId, curSlotIdInCountry)
    if (!air) return

    local userSkinsOption = ::get_option(::USEROPT_USER_SKIN)

    local data = ""
    for(local i = 0; i < userSkinsOption.items.len(); i++)
      data += ::build_option_blk(userSkinsOption.items[i].text, "", userSkinsOption.value == i, true, "", false, userSkinsOption.items[i].tooltip)

    local uskObj = scene.findObject("user_skins")
    if (::checkObj(uskObj))
      guiScene.replaceContentFromText(uskObj, data, data.len(), this)
  }

  function updateRespawnBases(air)
  {
    haveRespawnBases = false
    canChooseRespawnBase = false
    respawnBasesInfo = []

    local rbs = ::get_available_respawn_bases(air.tags)
    if (rbs.len())
    {
      haveRespawnBases = true
      local sel = 0;
      for (local i = 0; i < rbs.len(); ++i)
        if (rbs[i] == ::last_ca_base)
          sel = i;

      if (!canChangeAircraft && rbs.len()>1)
      {
        rbs = [rbs[sel]]
        sel = 0
      }

      for (local i = 0; i < rbs.len(); ++i)
      {
        if (sel == 0 && i != 0 && ::is_default_respawn_base(rbs[i]))
          sel = i;
        local name = ::get_respawn_base_name_by_id(rbs[i]);
        local mapSelectable = name != "missions/random_spawn" && name != "missions/ground_spawn_random"
        local title = (name == "") ? ::loc("missions/spawn_number", { number = i+1 }) : ::loc(name)

        respawnBasesInfo.append({ id = rbs[i], title = title, mapSelectable = mapSelectable })
      }

      canChooseRespawnBase = haveRespawnBases && respawnBasesInfo.len() > 1

      local respawnBaseObj = scene.findObject("respawn_base")
      if (::checkObj(respawnBaseObj))
      {
        local data = ""
        foreach (i, spawn in respawnBasesInfo)
          data += ::build_option_blk(spawn.title, "", i == sel)
        guiScene.replaceContentFromText(respawnBaseObj, data, data.len(), this);
        onRespawnbaseOptionUpdate(respawnBaseObj)
      }
    }

    checkRespawnTr(haveRespawnBases)
  }

  function checkRespawnTr(show)
  {
    local obj = scene.findObject("respawn_base_tr")
    if (::checkObj(obj))
      obj.show(show)
  }

  function updateGunVerticalOption(unit)
  {
    local isAir = unit && isAircraft(unit)
    showOptionRow("gunvertical", isAir && ::is_gun_vertical_convergence_allowed())

    local option = ::get_option(::USEROPT_GUN_VERTICAL_TARGETING)
    local gunVerticalObj = scene.findObject(option.id)
    if (::checkObj(gunVerticalObj))
    {
      if (gunVerticalObj.getValue() != option.value)
        gunVerticalObj.setValue(option.value)
    } else
    {
      gunVerticalObj = scene.findObject("gunvertical")
      if (!::checkObj(gunVerticalObj))
        return

      local parentObj = gunVerticalObj.getParent()
      option.cb <- "checkReady"
      local data = ::create_option_switchbox(option)
      guiScene.replaceContentFromText(parentObj, data, data.len(), this)
      gunVerticalObj = parentObj.findObject(option.id)
    }

    if (::checkObj(gunVerticalObj))
      gunVerticalObj.enable(canChangeAircraft)
  }

  function updateOtherOptions()
  {
    local air = getSlotAircraft(curSlotCountryId, curSlotIdInCountry)
    if (!air)
      return

    updateRespawnBases(air)

    local aircraft = air && isAircraft(air)
    local bomb = false
    local rocket = false

    local weaponName = getSelWeapon()
    foreach(w in air.weapons)
    {
      if (w.name == weaponName)
      {
        bomb = w.bomb
        rocket = w.rocket
      }
    }

    gunDescr = ::get_option(::USEROPT_GUN_TARGET_DISTANCE)
    local data = ""
    foreach (idx, item in gunDescr.items)
      if (canChangeAircraft || idx == gunDescr.value)
        data += build_option_blk(item, "", idx == gunDescr.value)
    local gundistObj = scene.findObject("gundist")
    if (::checkObj(gundistObj))
      guiScene.replaceContentFromText(gundistObj, data, data.len(), this)
    showOptionRow("gundist", aircraft)

    updateGunVerticalOption(air)

    bombDescr = ::get_option(::USEROPT_BOMB_ACTIVATION_TIME)
    local data = ""
    foreach (idx, item in bombDescr.items)
      if (canChangeAircraft || idx == bombDescr.value)
        data += build_option_blk(item.text, "", idx == bombDescr.value, true, "", false, item.tooltip)
    local bombTimeObj = scene.findObject("bombtime")
    if (::checkObj(bombTimeObj))
      guiScene.replaceContentFromText(bombTimeObj, data, data.len(), this)
    showOptionRow("bombtime", aircraft && bomb)

    rocketDescr = ::get_option(::USEROPT_ROCKET_FUSE_DIST)
    local data = ""
    foreach (idx, item in rocketDescr.items)
      if (canChangeAircraft || idx == rocketDescr.value)
        data += build_option_blk(item, "", idx == rocketDescr.value)
    local rocketdistObj = scene.findObject(rocketDescr.id)
    if (::checkObj(rocketdistObj))
      guiScene.replaceContentFromText(rocketdistObj, data, data.len(), this)
    showOptionRow(rocketDescr.id, aircraft && rocket && ::is_unit_available_use_rocket_diffuse(air))

    local fuelObj = scene.findObject("fuel")
    if (::checkObj(fuelObj))
    {
      fuelDescr = ::get_option(::USEROPT_LOAD_FUEL_AMOUNT)
      data = ""
      foreach (idx, item in fuelDescr.items)
        if (canChangeAircraft || idx == fuelDescr.value)
          data += build_option_blk(item, "", idx == fuelDescr.value, true, "id:t='fuel_opt"+idx+"'; ")
      guiScene.replaceContentFromText(fuelObj, data, data.len(), this)
      fuelObj.setValue(fuelDescr.value)
    }
    showOptionRow("fuel", aircraft) //TODO: fuel for tanks
  }

  function updateUnitOptions()
  {
    local unit = getSlotAircraft(curSlotCountryId, curSlotIdInCountry)
    if (unit)
    {
      ::cur_aircraft_name = unit.name //used in some options
      ::set_tactical_map_type_without_unit(
        (isTank(unit) || isShip(unit)) ? ::HUD_TYPE_TANK : ::HUD_TYPE_AIRPLANE)
    }
    updateWeaponsSelector()
    checkRocketDisctanceFuseRow()
    updateOtherOptions()
    updateSkin()
    updateUserSkins()
  }

  function onAircraftUpdate(obj)
  {
    updateUnitOptions()
    checkReady()
  }
  function onWeaponOptionUpdate(obj) {}

  function getSelWeapon()
  {
    local unit = getSlotAircraft(curSlotCountryId, curSlotIdInCountry)
    if (unit)
      return ::get_last_weapon(unit.name)
    return null
  }

  function getSelSkin()
  {
    local skinObj = scene.findObject("skin")
    local skinIndex = null
    if (!::checkObj(skinObj))
      return skinIndex
    skinIndex = skinObj.getValue()
    if (skinIndex >= 0 && skinIndex < skins.len())
      return skins[skinIndex]
    return null
  }

  function getSelRespBase(air)
  {
    if (!air)
      return -1
    local obj = scene.findObject("respawn_base")
    local idx = ::checkObj(obj) ? obj.getValue() : 0
    if (idx < 0)
      idx = 0

    local rbs = ::get_available_respawn_bases(air.tags);
    return idx < rbs.len() ? rbs[idx] : -1
  }

  function doSelectAircraftSkipAmmo()
  {
    doSelectAircraft(false)
  }

  function doSelectAircraft(checkAmmo = true)
  {
    if (requestInProgress)
      return

    local requestData = getSelectedRequestData(false)
    if (!requestData)
      return
    if (checkAmmo && !checkCurAirAmmo(doSelectAircraftSkipAmmo))
      return

    requestAircraftAndWeapon(requestData)
    if (scene.findObject("skin").getValue() > 0)
      ::req_unlock_by_client("non_standard_skin", false)

    ::show_aircraft = ::getAircraftByName(requestData.name)
    ::hangar_model_load_manager.loadModel(requestData.name)
  }

  function getSelectedRequestData(silent = true)
  {
    local air = getSlotAircraft(curSlotCountryId, curSlotIdInCountry)
    if (!air)
    {
      dagor.debug("getSlotAircraft(curSlotCountryId, curSlotIdInCountry) returned null?")
      return null
    }

    if (prevAutoChangedUnit && prevAutoChangedUnit != air && isInAutoChangeDelay())
    {
      if (!silent)
      {
        local msg = missionRules.getSpecialCantRespawnMessage(prevAutoChangedUnit)
        if (msg)
          ::g_popups.add(null, msg)
        prevUnitAutoChangeTimeMsec = -1
      }
      return null
    }

    local crew = getSlotItem(curSlotCountryId, curSlotIdInCountry)
    local weapon = ::get_last_weapon(air.name)
    local skin = ::hangar_get_last_skin(air.name)
    if (!weapon || !skin)
    {
      dagor.debug("no weapon or skin selected?")
      return null
    }

    local ruleMsg = missionRules.getSpecialCantRespawnMessage(air)
    if (!::u.isEmpty(ruleMsg))
    {
      if (!silent)
        ::showInfoMsgBox(ruleMsg, "cant_spawn_by_mission_rules", true)
      return null
    }

    if (!haveRespawnBases)
    {
      if (!silent)
        ::showInfoMsgBox(::loc("multiplayer/noRespawnBasesLeft"), "no_respawn_bases", true)
      return null
    }

    if (missionRules.isWarpointsRespawnEnabled && isRespawn)
    {
      local respawnPrice = getRespawnTotalCost(true)
      if (respawnPrice > 0 && respawnPrice > sessionWpBalance)
      {
        if (!silent)
          ::showInfoMsgBox(::loc("msg/not_enought_warpoints_for_respawn"), "not_enought_wp", true)
        return null
      }
    }

    if (missionRules.isScoreRespawnEnabled && isRespawn && (curSpawnScore < ::shop_get_spawn_score(air.name, getSelWeapon() || "")))
    {
      if (!silent)
        ::showInfoMsgBox(::loc("multiplayer/noSpawnScore"), "not_enought_score", true)
      return null
    }

    if (missionRules.isSpawnDelayEnabled && isRespawn)
    {
      local slotDelay = ::get_slot_delay(air.name)
      if (slotDelay > 0)
      {
        local timeText = ::secondsToString(slotDelay)
        local msgBoxText = ::loc("multiplayer/slotDelay", { time = timeText })
        if (!silent)
          ::showInfoMsgBox(msgBoxText, "wait_for_slot_delay", true)
        return null
      }
    }

    if (!::is_crew_available_in_session(crew.idInCountry, true))
    {
      if (!silent)
      {
        local locId = "crew_not_available"
        if (::getTblValue("useKillStreaks", missionTable) && ::get_es_unit_type(air) == ::ES_UNIT_TYPE_AIRCRAFT)
          locId = "msg/need_more_kills_for_aircraft"

        ::showInfoMsgBox(::loc(locId), "crew_not_available", true)
      }
      return null
    }


    if (!silent)
      dagor.debug("try to select aircraft " + air.name)
    if (!::is_crew_slot_was_ready_at_host(crew.idInCountry, air.name, true))
    {
      dagor.debug("is_crew_slot_was_ready_at_host return false for" +
                   crew.idInCountry + " - " + air.name)
      if (!silent)
        ::showInfoMsgBox(::loc("aircraft_not_repaired"), "aircraft_not_repaired", true)
      return null
    }

    local res = {
      name = air.name
      weapon = weapon
      skin = skin
      respBaseId = getSelRespBase(air)
      idInCountry = crew.idInCountry
    }

    local bulletInd = 0;
    local bulletGroups = weaponsSelectorWeak ? weaponsSelectorWeak.bulletsManager.getBulletsGroups() : []
    foreach(groupIndex, bulGroup in bulletGroups)
    {
      if (!bulGroup.active)
        continue
      local modName = bulGroup.selectedName
      if (!modName)
        continue

      local count = bulGroup.bulletsCount * bulGroup.guns
      if (bulGroup.canChangeBulletsCount() && bulGroup.bulletsCount <= 0)
        continue

      if (::getModificationByName(air, modName)) //!default bullets (fake)
        res["bullets" + bulletInd] <- modName
      else
        res["bullets" + bulletInd] <- ""
      res["bulletCount" + bulletInd] <- count
      bulletInd++;
    }
    while(bulletInd < ::BULLETS_SETS_QUANTITY)
    {
      res["bullets" + bulletInd] <- ""
      res["bulletCount" + bulletInd] <- 0
      bulletInd++;
    }

    foreach(optId in [::USEROPT_GUN_TARGET_DISTANCE, ::USEROPT_GUN_VERTICAL_TARGETING,
                      ::USEROPT_BOMB_ACTIVATION_TIME,
                      ::USEROPT_ROCKET_FUSE_DIST, ::USEROPT_LOAD_FUEL_AMOUNT
                     ])
    {
      local opt = ::get_option(optId)
      if (opt.controlType = optionControlType.LIST)
        res[opt.id] <- ::getTblValue(opt.value, opt.values)
      else
        res[opt.id] <- opt.value
    }

    return res
  }

  function requestAircraftAndWeapon(requestData)
  {
    if (requestInProgress)
      return

    ::set_aircraft_accepted_cb(this, aircraftAcceptedCb);
    local _taskId = ::request_aircraft_and_weapon(requestData, requestData.idInCountry, requestData.respBaseId)
    if (_taskId < 0)
      ::set_aircraft_accepted_cb(null, null);
    else
    {
      requestInProgress = true
      showTaskProgressBox(::loc("charServer/purchase0"), function() { requestInProgress = false })

      lastRequestData = requestData
    }
  }

  function aircraftAcceptedCb(result)
  {
    ::set_aircraft_accepted_cb(null, null)
    destroyProgressBox()
    requestInProgress = false

    reset_mp_autostart_countdown()

    switch (result)
    {
      case ::ERR_ACCEPT:
        onApplyAircraft(lastRequestData)
        ::update_gamercards() //update balance
        break;

      case ::ERR_REJECT_SESSION_FINISHED:
      case ::ERR_REJECT_DISCONNECTED:
        break;

      default:
        dagor.debug("Respawn Erorr: aircraft accepted cb result = " + result + ", on request:")
        debugTableData(lastRequestData)
        lastRequestData = null
        if (!::checkObj(guiScene["char_connecting_error"]))
          ::showInfoMsgBox(::loc("changeAircraftResult/"+result.tostring()), "char_connecting_error")
        break
    }
  }

  function onApplyAircraft(requestData)
  {
    if (requestData)
    {
      ::last_ca_aircraft = requestData.name
      ::last_ca_base = requestData.respBaseId
    }

    checkReady()
    if (readyForRespawn)
      onApply(null)
  }

  function checkReady(obj=null)
  {
    onOtherOptionUpdate(obj)

    readyForRespawn = lastRequestData != null && ::u.isEqual(lastRequestData, getSelectedRequestData())

    if (!readyForRespawn && isApplyPressed)
      if (!doRespawnCalled)
        isApplyPressed = false
      else
        dagor.debug("Something has changed in the aircraft selection, but too late - do_respawn was called before.")
    updateApplyText()
  }

  function updateApplyText()
  {
    local buttonSelectObj = scene.findObject("btn_select")

    if (isApplyPressed)
    {
      applyText = ::loc("mainmenu/btnCancel")
      buttonSelectObj.tooltip = ""
    }
    else
    {
      applyText = ::loc("mainmenu/toBattle")
      local respawnCostText = getRespawnTotalCost()
      if (respawnCostText != "")
        applyText = ::format("%s (%s)", applyText, respawnCostText)

      local tooltipText = ::loc("mainmenu/selectAircraftTooltip")
      if (::is_platform_pc)
        tooltipText += ::format(" [%s, %s]", ::loc("key/Space"), ::loc("key/Enter"))
      buttonSelectObj.tooltip = tooltipText
    }

    local battleObj = ::get_slot_obj(scene, curSlotCountryId, curSlotIdInCountry)
    ::setDoubleTextToButton(battleObj, "slotBtn_battle", applyText)

    local unit = getSlotAircraft(curSlotCountryId, curSlotIdInCountry)
    local isAvailResp = haveRespawnBases
    local infoTexts = []
    if (missionRules.isScoreRespawnEnabled && unit)
    {
      local curScore = ::shop_get_spawn_score(unit.name, getSelWeapon() || "")
      isAvailResp = isAvailResp && (curScore <= curSpawnScore)
      if (!isApplyPressed && curScore > 0)
        infoTexts.append(::loc("respawn/costRespawn", {cost = curScore}))
    }
    if (leftRespawns > 0 && !isApplyPressed)
      infoTexts.append(::loc("respawn/leftRespawns", {num = leftRespawns.tostring()}))

    infoTexts.append(missionRules.getRespawnInfoTextForUnit(unit))
    isAvailResp = isAvailResp && missionRules.getUnitLeftRespawns(unit) != 0

    local infoText = ::implode(infoTexts, ", ")
    if (infoText.len())
      applyText += ::loc("ui/parentheses/space", { text = infoText })

    local checkSlotDelay = true
    if (missionRules.isSpawnDelayEnabled)
    {
      local unit = getSlotAircraft(curSlotCountryId, curSlotIdInCountry)
      if (unit)
      {
        local slotDelay = ::get_slot_delay(unit.name)
        checkSlotDelay = slotDelay <= 0
      }
    }

    if (::checkObj(battleObj))
    {
      local slotBtnObj = battleObj.findObject("slotBtn_battle")
      if (::checkObj(slotBtnObj))
      {
        slotBtnObj.isCancel = isApplyPressed ? "yes" : "no"
        slotBtnObj.inactiveColor = (isAvailResp && checkSlotDelay) ? "no" : "yes"
      }
      buttonSelectObj.isCancel = isApplyPressed ? "yes" : "no"
      buttonSelectObj.inactiveColor = (isAvailResp && checkSlotDelay) ? "no" : "yes"
    }
    ::set_double_text_to_button(scene.findObject("nav-help"), "btn_select", applyText)

    checkRespawnTr(isAvailResp && checkSlotDelay)
  }

  function setApplyPressed()
  {
    isApplyPressed = !isApplyPressed
    updateApplyText()
  }

  function onApply(obj)
  {
    if (doRespawnCalled)
      return

    if (!haveSlots || leftRespawns == 0)
      return

    reset_mp_autostart_countdown()
    if (readyForRespawn)
      setApplyPressed()
    else if (canChangeAircraft && !isApplyPressed && ::can_request_aircraft_now())
      doSelectAircraft()
  }

  function checkChosenBulletsCount(applyFunc, bulletsManager)
  {
    local readyCounts = bulletsManager.checkBulletsCountReady()
    if (readyCounts.status == bulletsAmountState.READY
        || readyCounts.status == bulletsAmountState.HAS_UNALLOCATED && ::get_gui_option(::USEROPT_SKIP_LEFT_BULLETS_WARNING))
      return true

    local msg = ""
    if (readyCounts.status == bulletsAmountState.HAS_UNALLOCATED)
      msg = ::format(::loc("multiplayer/someBulletsLeft"), readyCounts.unallocated.tostring())
    else //status == bulletsAmountState.LOW_AMOUNT
      msg = ::format(::loc("multiplayer/notEnoughBullets"), readyCounts.required.tostring())

    ::gui_start_modal_wnd(::gui_handlers.WeaponWarningHandler,
      {
        parentHandler = this
        message = msg
        list = ""
        showCheckBoxBullets = false
        ableToStartAndSkip = readyCounts.status != bulletsAmountState.LOW_AMOUNT
        skipOption = ::USEROPT_SKIP_LEFT_BULLETS_WARNING
        onStartPressed = applyFunc
      })

    return false
  }

  function checkCurAirAmmo(applyFunc)
  {
    local bulletsManager = weaponsSelectorWeak && weaponsSelectorWeak.bulletsManager
    if (!bulletsManager)
      return true

    if (bulletsManager.canChangeBulletsCount())
      return checkChosenBulletsCount(applyFunc, bulletsManager)

    local air = getSlotAircraft(curSlotCountryId, curSlotIdInCountry)
    if (!air)
      return true

    local text = "";
    local zero = false;

    local weapon = getSelWeapon()
    if (weapon)
    {
      local weaponText = ::getAmmoAmountData(air.name, weapon, AMMO.WEAPON)
      if (weaponText.warning)
      {
        text += ::getWeaponNameText(air.name, false, -1, ", ") + weaponText.text;
        if (!weaponText.amount)
          zero = true
      }
    }


    local bulletGroups = bulletsManager.getBulletsGroups()
    foreach(groupIndex, bulGroup in bulletGroups)
    {
      if (!bulGroup.active)
        continue
      local modifName = bulGroup.selectedName
      if (modifName == "")
        continue

      local modificationText = ::getAmmoAmountData(air.name, modifName, AMMO.MODIFICATION)
      if (!modificationText.warning)
        continue

      if (text != "")
        text += "\n"
      text += ::getModificationName(air, modifName) + modificationText.text;
      if (!modificationText.amount)
        zero = true
    }

    if (!zero && !::is_game_mode_with_spendable_weapons())
      return true

    if (text != "" && (zero || !::get_gui_option(::USEROPT_SKIP_WEAPON_WARNING))) //skip warning only
    {
      ::gui_start_modal_wnd(::gui_handlers.WeaponWarningHandler,
        {
          parentHandler = this
          message = ::loc(zero ? "msgbox/zero_ammo_warning" : "controls/no_ammo_left_warning")
          list = text
          ableToStartAndSkip = !zero
          onStartPressed = applyFunc
        })
      return false
    }
    return true
  }

  function use_autostart()
  {
    if (!(get_game_type() & ::GT_AUTO_SPAWN))
      return false;
    if (isSpectate || curSlotIdInCountry < 0 || !::before_first_flight_in_session || missionRules.isWarpointsRespawnEnabled)
      return false;

    local crew = getSlotItem(curSlotCountryId, curSlotIdInCountry)
    local air = getSlotAircraft(curSlotCountryId, curSlotIdInCountry)
    if (!air)
      return false

    return !::is_spare_aircraft_in_slot(curSlotIdInCountry) &&
      ::is_crew_slot_was_ready_at_host(crew.idInCountry, air.name, false)
  }

  function onUpdate(obj, dt)
  {
    if (needCheckSlotReady)
      checkCrewAccessChange()

    updateSwitchSpectatorTarget(dt)
    if (missionRules.isSpawnDelayEnabled)
      updateSlotDelays()

    updateSpawnScore(false)

    autostartTimer += dt;

    local countdown = ::get_mp_respawn_countdown()
    updateCountdown(countdown)

    updateTimeToKick(dt)
    updateTables(dt)
    setInfo()

    updateTacticalMapHint()

    if (use_autostart() && get_mp_autostart_countdown() <= 0 && !isApplyPressed)
    {
      onApply(obj);
      return
    }

    if (isApplyPressed)
    {
      if (checkSpawnInterrupt())
        return

      if (::can_respawn_ca_now() && countdown < -100)
      {
        ::disable_flight_menu(false)
        if (respawnRecallTimer < 0)
        {
          respawnRecallTimer = 3.0
          doRespawn()
        }
        else
          respawnRecallTimer -= dt
      }
    }

    if (isRespawn && isSpectate)
      updateSpectatorName()

    if (isRespawn && ::get_mission_status() > ::MISSION_STATUS_RUNNING)
      ::quit_to_debriefing()
  }

  function doRespawn()
  {
    dagor.debug("do_respawn_player called")
    ::before_first_flight_in_session = false;
    ::do_respawn_player()
    doRespawnCalled = true
    ::broadcastEvent("PlayerSpawn", lastRequestData)
    if (lastRequestData)
    {
      lastSpawnUnitName = lastRequestData.name
      local requestedWeapon = lastRequestData.weapon
      if (!(lastSpawnUnitName in ::used_planes))
        ::used_planes[lastSpawnUnitName] <- []
      if (!::isInArray(requestedWeapon, ::used_planes[lastSpawnUnitName]))
        ::used_planes[lastSpawnUnitName].append(requestedWeapon)
      lastRequestData = null
    }
    updateButtons()
    ::select_respawnbase(-1)
  }

  function checkSpawnInterrupt()
  {
    if (!doRespawnCalled)
      return false
    if (::can_respawn_ca_now())
      return false

    guiScene.performDelayed(this, function()
    {
      if (!doRespawnCalled)
        return

      local msg = ::loc("multiplayer/noTeamUnitLeft",
                        { unitName = lastSpawnUnitName.len() ? ::getUnitName(lastSpawnUnitName) : "" })
      reinitScreen()
      ::g_popups.add(null, msg)
    })
    return true
  }

  function updateSlotDelays()
  {
    if (!::checkObj(scene))
      return

    local crews = ::get_crews_list_by_country(::get_local_player_country())
    foreach(crew in crews)
    {
      local idInCountry = crew.idInCountry
      if (!(idInCountry in slotDelayDataByCrewIdx))
        slotDelayDataByCrewIdx[idInCountry] <- { slotDelay = -1, updateTime = 0 }
      local slotDelayData = slotDelayDataByCrewIdx[idInCountry]

      local prevSlotDelay = ::getTblValue("slotDelay", slotDelayData, -1)
      local curSlotDelay = ::get_slot_delay_by_slot(idInCountry)
      if (prevSlotDelay != curSlotDelay)
      {
        slotDelayData.slotDelay = curSlotDelay
        slotDelayData.updateTime = ::dagor.getCurTime()
      }
      else if (curSlotDelay < 0)
        continue

      if (curSlotIdInCountry == idInCountry)
        updateApplyText()
      updateCrewSlotText(crew)
    }
  }

  //only for crews of current country
  function updateCrewSlotText(crew)
  {
    local unit = ::g_crew.getCrewUnit(crew)
    if (!unit)
      return

    local idInCountry = crew.idInCountry
    local slotObj = ::get_slot_obj(scene, curSlotCountryId, idInCountry)
    if (!slotObj)
      return

    local params = getSlotbarParams()
    params.curSlotIdInCountry <- idInCountry
    params.curSlotCountryId <- curSlotCountryId
    params.unlocked <- ::isUnitUnlocked(this, unit, curSlotCountryId, idInCountry, ::get_local_player_country())
    params.weaponPrice <- getWeaponPrice(unit.name, ::get_last_weapon(unit.name))
    if (idInCountry in slotDelayDataByCrewIdx)
      params.slotDelayData <- slotDelayDataByCrewIdx[idInCountry]

    local priceTextObj = slotObj.findObject("bottom_item_price_text")
    if (::checkObj(priceTextObj))
      priceTextObj.setValue(::get_unit_item_price_text(unit, params))

    local nameObj = slotObj.findObject(::get_slot_obj_id(curSlotCountryId, idInCountry) + "_txt")
    if (::checkObj(nameObj))
      nameObj.setValue(::get_slot_unit_name_text(unit, params))
  }

  function updateAllCrewSlotTexts()
  {
    foreach(crew in ::get_crews_list_by_country(::get_local_player_country()))
      updateCrewSlotText(crew)
  }

  function get_mp_autostart_countdown()
  {
    local countdown = autostartTime - autostartTimer;
    return ::ceil(countdown);
  }
  function reset_mp_autostart_countdown()
  {
    autostartTimer = 0;
  }

  function showLoadAnim(show)
  {
    if (::checkObj(scene))
      scene.findObject("LOADANIM").show(show)

    if (show)
      reset_mp_autostart_countdown();
  }

  function updateButtons(show = null, checkShowChange = false)
  {
    if ((checkShowChange && show == showButtons) || !::checkObj(scene))
      return

    if (show != null)
      showButtons = show

    local buttons = {
      btn_select =      showButtons && isRespawn && !isNoRespawns && !stayOnRespScreen && !doRespawnCalled
      btn_spectator =   showButtons && isRespawn && (!isSpectate || ::is_has_multiplayer())
      btn_mpStat =      showButtons && isRespawn && ::is_has_multiplayer()
      btn_QuitMission = showButtons && isRespawn && isNoRespawns && ::g_mis_loading_state.isReadyToShowRespawn()
      btn_back =        showButtons && ::use_touchscreen && !isRespawn
      btn_activateorder=showButtons && isRespawn && ::g_orders.showActivateOrderButton() && (!isSpectate || !::show_console_buttons)
    }
    foreach(id, value in buttons)
      showSceneBtn(id, value)

    local slotObj = ::get_slot_obj(scene, curSlotCountryId, curSlotIdInCountry)
    showBtn("buttonsDiv", show && isRespawn, slotObj)
  }

  function updateCountdown(countdown)
  {
    local isLoadingUnitModel = !stayOnRespScreen && !::can_request_aircraft_now()
    showLoadAnim(isLoadingUnitModel || !::g_mis_loading_state.isReadyToShowRespawn())
    updateButtons(!isLoadingUnitModel, true)

    if (isLoadingUnitModel || !use_autostart())
      reset_mp_autostart_countdown();

    if (stayOnRespScreen)
      return

    local btnText = applyText
    if (countdown > 0 && readyForRespawn)
      btnText += " (" + countdown  + ::loc("mainmenu/seconds") + ")"

    ::set_double_text_to_button(scene, "btn_select", btnText)

    local textObj = scene.findObject("autostart_countdown_text")
    if (!::checkObj(textObj))
      return

    local autostartCountdown = get_mp_autostart_countdown()
    local text = ""
    if (use_autostart() && autostartCountdown > 0 && autostartCountdown <= autostartShowTime)
    {
      text = ::loc("mainmenu/autostartCountdown") + " " + autostartCountdown + ::loc("mainmenu/seconds")
      if (autostartCountdown <= autostartShowInColorTime)
        text = ::colorize("warningTextColor", text)
      else
        text = ::colorize("activeTextColor", text)
    }
    textObj.setValue(text)
  }

  curChatBlk = ""
  curChatData = null
  function loadChat()
  {
    local chatBlkName = isSpectate? "gui/chat/gameChat.blk" : "gui/chat/gameChatRespawn.blk"
    if (!curChatData || chatBlkName != curChatBlk)
      loadChatScene(chatBlkName)
    if (curChatData)
      ::hide_game_chat_scene_input(curChatData, !isRespawn && !isSpectate)
  }

  function loadChatScene(chatBlkName)
  {
    local chatObj = scene.findObject(isSpectate ? "mpChatInSpectator" : "mpChatInRespawn")
    if (!::checkObj(chatObj))
      return

    if (curChatData)
    {
      if (::checkObj(curChatData.scene))
        guiScene.replaceContentFromText(curChatData.scene, "", 0, null)
      ::detachGameChatSceneData(curChatData)
    }

    curChatData = ::loadGameChatToObj(chatObj, chatBlkName, this)
    curChatBlk = chatBlkName
  }

  function updateSpectatorRotationForced(isRespawnSceneActive = null)
  {
    if (isRespawnSceneActive == null)
      isRespawnSceneActive = isSceneActive()
    ::force_spectator_camera_rotation(isRespawnSceneActive && isSpectate)
  }

  function setSpectatorMode(is_spectator, forceShowInfo = false)
  {
    if (isSpectate == is_spectator && !forceShowInfo)
      return

    isSpectate = is_spectator
    showSpectatorInfo(is_spectator)
    setOrdersEnabled(isSpectate)
    updateSpectatorRotationForced()

    if (is_spectator)
    {
      scene.findObject("btn_spectator").setValue(canChangeAircraft? ::loc("multiplayer/changeAircraft") : ::loc("multiplayer/backToMap"))
      updateSpectatorName()
    }
    else
      scene.findObject("btn_spectator").setValue(::loc("multiplayer/spectator"))

    loadChat()

    updateListsButtons()

    ::on_spectator_mode(is_spectator)

    updateApplyText()
    restoreFocus()
    updateControlsAllowMask()
  }

  function updateControlsAllowMask()
  {
    switchControlsAllowMask(
      !isRespawn ? (
        CtrlsInGui.CTRL_ALLOW_TACTICAL_MAP |
        CtrlsInGui.CTRL_ALLOW_VEHICLE_KEYBOARD |
        CtrlsInGui.CTRL_ALLOW_VEHICLE_JOY |
        CtrlsInGui.CTRL_ALLOW_VEHICLE_XINPUT)
      : isSpectate ? CtrlsInGui.CTRL_ALLOW_SPECTATOR
      : CtrlsInGui.CTRL_ALLOW_NONE)
  }

  function setOrdersEnabled(value)
  {
    local statusObj = getOrderStatusObj()
    if (statusObj == null)
      return
    statusObj.show(value)
    statusObj.enable(value)
    if (value)
      ::g_orders.enableOrders(statusObj)
  }

  function showSpectatorInfo(status)
  {
    if (!::checkObj(scene))
      return

    setSceneTitle(status ? "" : getCurMpTitle())

    scene.findObject("spectator_mode_title").show(status)
    scene.findObject("flight_menu_bgd").show(!status)
    scene.findObject("bg-shade").show(!status)
    scene.findObject("spectator_controls").show(status)
    updateButtons()
  }

  function setSceneTitle(text)
  {
    ::set_menu_title(text, scene, "respawn_title")
  }

  function getEndTimeObj()
  {
    return scene.findObject("respawn_time_end")
  }

  function getScoreLimitObj()
  {
    return scene.findObject("respawn_score_limit")
  }

  function getTimeToKickObj()
  {
    return scene.findObject("respawn_time_to_kick")
  }

  function updateSpectatorName()
  {
    if (!::checkObj(scene))
      return

    local name = ::get_spectator_target_name()
    scene.findObject("spectator_name").setValue(name)
  }

  function onChatCancel()
  {
    onGamemenu(null)
  }

  function onEmptyChatEntered()
  {
    onApply(null)
  }

  function onGamemenu(obj)
  {
    if (showHud())
      return; //was hidden, ignore menu opening

    if (!isRespawn || !::can_request_aircraft_now())
      return

    guiScene.performDelayed(this, function() {
      ::disable_flight_menu(false)
      gui_start_flight_menu()
    })
  }

  function onSpectator(obj)
  {
    if (!::can_request_aircraft_now())
      return
    if (isRespawn)
      setSpectatorMode(!isSpectate)
  }

  function setHudVisibility(obj)
  {
    if(!isSpectate)
      return

    ::show_hud(!scene.findObject("respawn_screen").isVisible())
  }

  function showHud()
  {
    if (!::checkObj(scene) || scene.findObject("respawn_screen").isVisible())
      return false
    ::show_hud(true)
    return true
  }

  function updateSwitchSpectatorTarget(dt)
  {
    spectator_switch_timer -= dt;

    if (spectator_switch_direction == ESwitchSpectatorTarget.E_DO_NOTHING)
      return; //do nothing
    if (spectator_switch_timer <= 0)
    {
      ::switch_spectator_target(spectator_switch_direction == ESwitchSpectatorTarget.E_NEXT);
      updateSpectatorName();

      spectator_switch_direction = ESwitchSpectatorTarget.E_DO_NOTHING;
      spectator_switch_timer = spectator_switch_timer_max;
    }
  }
  function switchSpectatorTargetToNext()
  {
    if (spectator_switch_direction == ESwitchSpectatorTarget.E_NEXT)
      return; //already switching
    if (spectator_switch_direction == ESwitchSpectatorTarget.E_PREV)
    {
      spectator_switch_direction = ESwitchSpectatorTarget.E_DO_NOTHING; //switch back
      return;
    }
    spectator_switch_direction = ESwitchSpectatorTarget.E_NEXT;
  }
  function switchSpectatorTargetToPrev()
  {
    if (spectator_switch_direction == ESwitchSpectatorTarget.E_PREV)
      return; //already switching
    if (spectator_switch_direction == ESwitchSpectatorTarget.E_NEXT)
    {
      spectator_switch_direction = ESwitchSpectatorTarget.E_DO_NOTHING; //switch back
      return;
    }
    spectator_switch_direction = ESwitchSpectatorTarget.E_PREV;
  }

  function onHideHUD(obj)
  {
    ::show_hud(false)
  }

  function onShowHud(show = true) //return - was changed
  {
    if (!isSceneActive())
      return

    guiScene.showCursor(show);
    if (!::checkObj(scene))
      return

    local obj = scene.findObject("respawn_screen")
    local isHidden = obj.display == "hide" //until scene recount obj.isVisible will return false, because it was full hidden
    if (isHidden != show)
      return

    obj.show(show)
    if (show)
    {
      //delayed restore focus still find all objects invisible.  so need to force update scene before restore,
      guiScene.setUpdatesEnabled(true, true)
      restoreFocus()
    }
  }

  function onSpectatorNext(obj)
  {
    if (!::can_request_aircraft_now())
      return
    if (isRespawn && isSpectate)
      switchSpectatorTargetToNext();
  }

  function onSpectatorPrev(obj)
  {
    if (!::can_request_aircraft_now())
      return
    if (isRespawn && isSpectate)
      switchSpectatorTargetToPrev();
  }

  function onMpStatScreen(obj)
  {
    if (!::can_request_aircraft_now())
      return

    guiScene.performDelayed(this, function() {
      ::disable_flight_menu(false)
      ::gui_start_mpstatscreen()
    })
  }

  function getCurrentEdiff()
  {
    return ::get_mission_mode()
  }

  function onQuitMission(obj)
  {
    ::quit_mission()
  }

  function goBack()
  {
    if (!isRespawn)
      ::close_ingame_gui()
  }

  function onEventUpdateEsFromHost(p)
  {
    if (isSceneActive())
      reinitScreen({})
  }

  function onEventUnitWeaponChanged(p)
  {
    local crew = ::getSlotItem(curSlotCountryId, curSlotIdInCountry)
    local unit = ::g_crew.getCrewUnit(crew)
    if (!unit)
      return

    if (missionRules.hasRespawnCost)
      updateCrewSlotText(crew)

    checkRocketDisctanceFuseRow()
    updateOtherOptions()
    checkReady()
  }

  function onEventBulletsGroupsChanged(p)
  {
    checkReady()
  }

  function onEventBulletsCountChanged(p)
  {
    checkReady()
  }

  function initMisObjExpandButton()
  {
    local totalHeight = scene.findObject("mis_obj_and_chat_place").getSize()[1]
    local optimalMisObjHeight = ::g_dagui_utils.toPixels(guiScene, "1@optimalMisObjHeight")
    local maxChatHeight = ::g_dagui_utils.toPixels(guiScene, "1@maxChatHeight")

    canSwitchChatSize = totalHeight < optimalMisObjHeight + maxChatHeight
    showSceneBtn("mis_obj_text_header", !canSwitchChatSize)
    showSceneBtn("mis_obj_button_header", canSwitchChatSize)

    if (!canSwitchChatSize)
    {
      isChatFullSize = true
      return
    }

    isChatFullSize = ::loadLocalByScreenSize("isRespawnChatFullSize", null)

    if (!::u.isBool(isChatFullSize))
    {
      local minMisObjHeight = ::g_dagui_utils.toPixels(guiScene, "1@minMisObjHeight")
      local foldedMisObjHeight = totalHeight - maxChatHeight
      isChatFullSize = optimalMisObjHeight - foldedMisObjHeight < 0.8 * (foldedMisObjHeight - minMisObjHeight)
    }
    updateChatSize(isChatFullSize)
  }

  function onSwitchChatSize()
  {
    if (!canSwitchChatSize)
      return

    updateChatSize(!isChatFullSize)
    ::saveLocalByScreenSize("isRespawnChatFullSize", isChatFullSize)
  }

  function updateChatSize(newIsChatFullSize)
  {
    isChatFullSize = newIsChatFullSize

    scene.findObject("mis_obj_button_header").direction = isChatFullSize ? "down" : "up"
    scene.findObject("mpChatInRespawn").height = isChatFullSize ? "1@maxChatHeight" : "1@minChatHeight"
  }

  function checkUpdateCustomStateRespawns()
  {
    if (!isSceneActive())
      return //when scene become active again there will be full update on reinitScreen

    local newRespawnMask = missionRules.getCurCrewsRespawnMask()
    if (!customStateCrewAvailableMask && newRespawnMask)
    {
      reinitScreen({})
      return
    }

    if (customStateCrewAvailableMask == newRespawnMask)
      return updateApplyText() //unit left respawn text

    updateLeftRespawns()
    reinitSlotbar()
  }

  function onEventMissionCustomStateChanged(p)
  {
    doWhenActiveOnce("checkUpdateCustomStateRespawns")
    doWhenActiveOnce("updateAllCrewSlotTexts")
  }

  function onEventMyCustomStateChanged(p)
  {
    doWhenActiveOnce("checkUpdateCustomStateRespawns")
    doWhenActiveOnce("updateAllCrewSlotTexts")
  }
}

function cant_respawn_anymore() // called when no more respawn bases left
{
  if (::current_base_gui_handler && ("stayOnRespScreen" in ::current_base_gui_handler))
    ::current_base_gui_handler.stayOnRespScreen = true
}

function get_mouse_relative_coords_on_obj(obj)
{
  if (!::checkObj(obj))
    return null

  local objPos  = obj.getPosRC()
  local objSize = obj.getSize()
  local cursorPos = ::get_dagui_mouse_cursor_pos_RC()
  if (cursorPos[0] >= objPos[0] && cursorPos[0] <= objPos[0] + objSize[0] && cursorPos[1] >= objPos[1] && cursorPos[1] <= objPos[1] + objSize[1])
    return [
      1.0 * (cursorPos[0] - objPos[0]) / objSize[0],
      1.0 * (cursorPos[1] - objPos[1]) / objSize[1],
    ]

  return null
}

//FOR DEBUGGING. remove when bug is caught
if ("get_available_respawn_bases_debug" in getroottable())
  ::get_available_respawn_bases <- ::get_available_respawn_bases_debug

function has_available_slots()
{
  if (!(get_game_type() & (::GT_VERSUS | ::GT_COOPERATIVE)))
    return true

  if (get_game_mode() == ::GM_SINGLE_MISSION || get_game_mode() == ::GM_DYNAMIC)
    return true

  if (!::g_mis_loading_state.isCrewsListReceived())
    return false

  local team = ::get_mp_local_team()
  local country = ::get_local_player_country()
  local crews = ::get_crews_list_by_country(country, true)
  if (!crews)
    return false

  dagor.debug("looking for country "+country+" in team "+team)

  local missionRules = ::g_mis_custom_state.getCurMissionRules()
  local leftRespawns = missionRules.getLeftRespawns()
  if (leftRespawns == 0)
    return false

  local curSpawnScore = missionRules.getCurSpawnScore()
  foreach (c in crews)
  {
    local air = ::g_crew.getCrewUnit(c)
    if (!air)
      continue

    if (!::is_crew_available_in_session(c.idInCountry, false)
        || !::is_crew_slot_was_ready_at_host(c.idInCountry, air.name, true)
        || !::get_available_respawn_bases(air.tags).len()
        || !missionRules.getUnitLeftRespawns(air))
      continue

    if (missionRules.isScoreRespawnEnabled)
    {
      local enoughSpawnScore = curSpawnScore < 0 || curSpawnScore >= ::shop_get_spawn_score(air.name, "")
      if (!enoughSpawnScore)
        continue
    }

    dagor.debug("has_available_slots true: unit "+air.name+" in slot "+c.idInCountry)
    return true
  }
  dagor.debug("has_available_slots false")
  return false
}
