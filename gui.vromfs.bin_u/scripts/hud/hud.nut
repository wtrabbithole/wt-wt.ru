local SecondsUpdater = require("sqDagui/timer/secondsUpdater.nut")
local time = require("scripts/time.nut")


::chat_window_appear_time <- 0.125;
::chat_window_disappear_time <- 20.0;
::unmapped_controls_warning_time_show <- 30.0
::unmapped_controls_warning_time_wink <- 3.0

::need_offer_controls_help <- true

::air_hud_actions <- {
  flaps = {
    id     = "flaps"
    image  = "#ui/gameuiskin#aerodinamic_wing"
    action = "ID_FLAPS"
  }

  gear = {
    id     = "gear"
    image  = "#ui/gameuiskin#hidraulic"
    action = "ID_GEAR"
  }

  rocket = {
    id     = "rocket"
    image  = "#ui/gameuiskin#rocket"
    action = "ID_ROCKETS"
  }

  bomb = {
    id     = "bomb"
    image  = "#ui/gameuiskin#torpedo_bomb"
    action = "ID_BOMBS"
  }
}

function get_ingame_map_aabb()
{
  local handler = ::handlersManager.findHandlerClassInScene(::gui_handlers.Hud)
  return handler && ::get_dagui_obj_aabb(handler.getTacticalMapObj())
}

function get_ingame_multiplayer_score_progress_bar_aabb()
{
  local handler = ::handlersManager.findHandlerClassInScene(::gui_handlers.Hud)
  return handler && ::get_dagui_obj_aabb(handler.getMultiplayerScoreObj())
}

function on_show_hud(show = true) //called from native code
{
  local handler = ::handlersManager.getActiveBaseHandler()
  if (handler && ("onShowHud" in handler))
    handler.onShowHud(show)
  ::broadcastEvent("ShowHud", { show = show })
}

class ::gui_handlers.Hud extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName         = "gui/hud/hud.blk"
  keepLoaded           = true
  wndControlsAllowMask = CtrlsInGui.CTRL_ALLOW_FULL
  widgetsList = [
    {
      widgetId = DargWidgets.HUD
    }
  ]

  ucWarningActive   = false
  ucWarningTimeShow = 0.0
  ucPrevList        = []
  spectatorMode     = false

  hudType    = HUD_TYPE.NONE
  isXinput   = false
  currentHud = null

  isLowQualityWarningVisible = false

  curTacticalMapObj = null

  afkTimeToKick = null
  delayOnCheckAfkTimeToKick = 0.0

  curHudVisMode = null
  isReinitDelayed = false

  objectsTable = {
    [::USEROPT_DAMAGE_INDICATOR_SIZE] = {
      objectsToScale = {
        hud_tank_damage_indicator = "@sizeDamageIndicatorFull"
        xray_render_dmg_indicator = "@sizeDamageIndicator"
      }
      onChangedFunc = @(obj) ::g_hud_event_manager.onHudEvent("DamageIndicatorSizeChanged")
    },
    [::USEROPT_TACTICAL_MAP_SIZE] = {
      objectsToScale = {
        hud_tank_tactical_map     = "@sizeTacticalMap"
        hud_air_tactical_map      = "@sizeTacticalMap"
      }
      onChangedFunc = null
    }
  }

  function initScreen()
  {
    ::init_options()
    ::g_hud_event_manager.init()
    ::g_streaks.clear()
    initSubscribes()

    isXinput = ::is_xinput_device()
    spectatorMode = ::isPlayerDedicatedSpectator() || ::is_replay_playing()
    unmappedControlsCheck()
    warnLowQualityModelCheck()
    switchHud(getHudType())
    loadGameChat()

    scene.findObject("hud_update").setUserData(this)
    local gm = get_game_mode()
    showSceneBtn("stats", (gm == ::GM_DOMINATION || gm == ::GM_SKIRMISH))
    showSceneBtn("voice", (gm == ::GM_DOMINATION || gm == ::GM_SKIRMISH))

    ::HudBattleLog.init()
    ::g_hud_message_stack.init(scene)
    ::g_hud_message_stack.clearMessageStacks()
    ::g_hud_live_stats.init(scene, "hud_live_stats_nest", !spectatorMode && ::is_multiplayer())
    ::g_hud_hints_manager.init(scene)
    ::g_hud_tutorial_elements.init(scene)

    switchControlsAllowMask(spectatorMode
                            ? CtrlsInGui.CTRL_ALLOW_MP_STATISTICS | CtrlsInGui.CTRL_ALLOW_MP_CHAT
                              | CtrlsInGui.CTRL_ALLOW_FLIGHT_MENU | CtrlsInGui.CTRL_ALLOW_SPECTATOR
                            : CtrlsInGui.CTRL_ALLOW_FULL)
  }

  /*override*/ function onSceneActivate(show)
  {
    ::g_orders.enableOrders(scene.findObject("order_status"))
    base.onSceneActivate(show)
  }

  function loadGameChat()
  {
    if (::is_multiplayer())
      ::loadGameChatToObj(scene.findObject("chatPlace"), "gui/chat/gameChat.blk", this, true, false, true)
  }

  function reinitScreen(params = {})
  {
    isReinitDelayed = !scene.isVisible() //hud not visible. we just wait for show_hud event
    if (isReinitDelayed)
      return

    setParams(params)
    if (switchHud(getHudType()))
      loadGameChat()
    else
    {
      if (currentHud && ("reinitScreen" in currentHud))
        currentHud.reinitScreen()
      ::g_hud_hitcamera.reinit()
    }
    ::g_hud_message_stack.reinit()
    ::g_hud_live_stats.reinit()
    ::g_hud_hints_manager.reinit()
    ::g_hud_tutorial_elements.reinit()

    unmappedControlsCheck()
    warnLowQualityModelCheck()
    updateHudVisMode()
    onHudUpdate(null, 0.0)
  }

  function initSubscribes()
  {
    ::g_hud_event_manager.subscribe("ReinitHud", function(eventData)
      {
        reinitScreen()
      }, this)
    ::g_hud_event_manager.subscribe("Cutscene", function(eventData)
      {
        reinitScreen()
      }, this)
    ::g_hud_event_manager.subscribe("LiveStatsVisibilityToggled",
        @(ed) warnLowQualityModelCheck(),
        this)
  }

  function onShowHud(show = true)
  {
    if (currentHud && ("onShowHud" in currentHud))
      currentHud.onShowHud(show)
    base.onShowHud(show)
    if (show && isReinitDelayed)
      reinitScreen()
  }

  function switchHud(newHudType)
  {
    if (!::checkObj(scene))
      return false

    if (newHudType == hudType && isXinput == (isXinput = ::is_xinput_device()))
      return false

    local hudObj = scene.findObject("hud_obj")
    if (!::checkObj(hudObj))
      return false

    guiScene.replaceContentFromText(hudObj, "", 0, this)

    if (newHudType == HUD_TYPE.CUTSCENE)
      currentHud = ::handlersManager.loadHandler(::HudCutscene, { scene = hudObj })
    else if (newHudType == HUD_TYPE.SPECTATOR)
      currentHud = ::handlersManager.loadHandler(::Spectator, { scene = hudObj })
    else if (newHudType == HUD_TYPE.AIR)
      currentHud = ::handlersManager.loadHandler(::use_touchscreen && !isXinput ? ::HudTouchAir : ::HudAir, { scene = hudObj })
    else if (newHudType == HUD_TYPE.TANK)
      currentHud = ::handlersManager.loadHandler(::use_touchscreen && !isXinput ? ::HudTouchTank : ::HudTank, { scene = hudObj })
    else if (newHudType == HUD_TYPE.SHIP)
      currentHud = ::handlersManager.loadHandler(::HudShip, { scene = hudObj })
    else if (newHudType == HUD_TYPE.HELICOPTER)
      currentHud = ::handlersManager.loadHandler(::HudHelicopter, { scene = hudObj })
    else //newHudType == HUD_TYPE.NONE
      currentHud = null

    showSceneBtn("ship_obstacle_rf", newHudType == HUD_TYPE.SHIP)

    hudType = newHudType

    onHudSwitched()
    ::broadcastEvent("HudTypeSwitched")
    return true
  }

  function onHudSwitched()
  {
    updateHudVisMode(::FORCE_UPDATE)
    ::g_hud_hitcamera.init(scene.findObject("hud_hitcamera"))

    // All required checks are performed internally.
    ::g_orders.enableOrders(scene.findObject("order_status"))

    changeObjectsSize(::USEROPT_DAMAGE_INDICATOR_SIZE)
    changeObjectsSize(::USEROPT_TACTICAL_MAP_SIZE)
  }

  //get means determine in this case, but "determine" is too long for function name
  function getHudType()
  {
    if (::hud_is_in_cutscene())
      return HUD_TYPE.CUTSCENE
    else if (spectatorMode)
      return HUD_TYPE.SPECTATOR
    else if (::get_game_mode() == ::GM_BENCHMARK)
      return HUD_TYPE.BENCHMARK
    else
    {
      local unit = ::get_player_cur_unit()
      if (unit != null && unit.unitType == ::g_unit_type.AIRCRAFT
        && ::isInArray("helicopter", ::getTblValue("tags", unit)))
        return HUD_TYPE.HELICOPTER

      local unitType = ::get_es_unit_type(unit)
      if (unitType == ::ES_UNIT_TYPE_AIRCRAFT)
        return HUD_TYPE.AIR
      else if (unitType == ::ES_UNIT_TYPE_TANK)
        return HUD_TYPE.TANK
      else if (unitType == ::ES_UNIT_TYPE_SHIP)
        return HUD_TYPE.SHIP
    }
    return HUD_TYPE.NONE
  }

  function updateHudVisMode(forceUpdate = false)
  {
    local visMode = ::g_hud_vis_mode.getCurMode()
    if (!forceUpdate && visMode == curHudVisMode)
      return
    curHudVisMode = visMode

    local isDmgPanelVisible = visMode.isPartVisible(HUD_VIS_PART.DMG_PANEL)

    local objsToShow = {
      xray_render_dmg_indicator = isDmgPanelVisible
      hud_tank_damage_indicator = isDmgPanelVisible
      tank_background = ::is_dmg_indicator_visible() && isDmgPanelVisible
      hud_tank_tactical_map     = visMode.isPartVisible(HUD_VIS_PART.MAP)
      hud_kill_log              = visMode.isPartVisible(HUD_VIS_PART.KILLLOG)
      chatPlace                 = visMode.isPartVisible(HUD_VIS_PART.CHAT)
      hud_enemy_damage_nest     = visMode.isPartVisible(HUD_VIS_PART.KILLCAMERA)
      order_status              = visMode.isPartVisible(HUD_VIS_PART.ORDERS)
    }

    guiScene.setUpdatesEnabled(false, false)
    ::showBtnTable(scene, objsToShow)
    guiScene.setUpdatesEnabled(true, true)
  }

  function onHudUpdate(obj=null, dt=0.0)
  {
    ::g_streaks.onUpdate(dt)
    unmappedControlsUpdate(dt)

    delayOnCheckAfkTimeToKick -= dt
    if (delayOnCheckAfkTimeToKick <= 0.0)
    {
      delayOnCheckAfkTimeToKick = 1.0
      updateAFKTimeKickText(dt)
    }
  }

  function unmappedControlsCheck()
  {
    if (spectatorMode || !::is_hud_visible())
      return

    local unmapped = ::getUnmappedControlsForCurrentMission()

    if (!unmapped.len())
    {
      if (ucWarningActive)
      {
        ucWarningTimeShow = 0.0
        unmappedControlsUpdate()
      }
      return
    }

    if (::u.isEqual(unmapped, ucPrevList))
      return

    local warningObj = scene.findObject("unmapped_shortcuts_warning")
    if (!::checkObj(warningObj))
      return

    local unmappedLocalized = ::u.map(unmapped, ::loc)
    local text = ::loc("controls/warningUnmapped") + ::loc("ui/colon") + "\n" + ::g_string.implode(unmappedLocalized, ::loc("ui/comma"))
    warningObj.setValue(text)
    warningObj.show(true)
    warningObj.wink = "yes"

    ucWarningTimeShow = ::unmapped_controls_warning_time_show
    ucPrevList = unmapped
    ucWarningActive = true
    unmappedControlsUpdate()
  }

  function unmappedControlsUpdate(dt=0.0)
  {
    if (!ucWarningActive)
      return

    local noWinkTime = ::unmapped_controls_warning_time_show - ::unmapped_controls_warning_time_wink
    local winkingOld = ucWarningTimeShow > noWinkTime
    ucWarningTimeShow -= dt
    local winkingNew = ucWarningTimeShow > noWinkTime

    if (ucWarningTimeShow <= 0 || winkingOld != winkingNew)
    {
      local warningObj = scene.findObject("unmapped_shortcuts_warning")
      if (!::checkObj(warningObj))
        return

      warningObj.wink = "no"

      if (ucWarningTimeShow <= 0)
      {
        warningObj.show(false)
        ucWarningActive = false
      }
    }
  }

  function warnLowQualityModelCheck()
  {
    if (spectatorMode || !::is_hud_visible())
      return

    local isShow = !::is_hero_highquality() && !::g_hud_live_stats.isVisible()
    if (isShow == isLowQualityWarningVisible)
      return

    isLowQualityWarningVisible = isShow
    showSceneBtn("low-quality-model-warning", isShow)
  }

  function onEventHudIndicatorChangedSize(params)
  {
    local option = ::getTblValue("option", params, -1)
    if (option < 0)
      return

    changeObjectsSize(option)
  }

  function changeObjectsSize(optionNum)
  {
    local option = ::get_option(optionNum)
    local value = (option && option.value != null) ? option.value : 0
    local max   = (option && option.max != null && option.max != 0) ? option.max : 2
    local size = 1.0 + 0.333 * value / max

    local table = ::getTblValue(optionNum, objectsTable, {})
    foreach (id, cssConst in ::getTblValue("objectsToScale", table, {}))
    {
      local obj = scene.findObject(id)
      if (!::checkObj(obj))
        continue

      obj.size = ::format("%.3f*%s, %.3f*%s", size, cssConst, size, cssConst)
      guiScene.applyPendingChanges(false)

      if (optionNum == ::USEROPT_TACTICAL_MAP_SIZE)
        curTacticalMapObj = obj

      local func = ::getTblValue("onChangedFunc", table)
      if (func)
        func.call(this, obj)
    }
  }

  function getTacticalMapObj()
  {
    return curTacticalMapObj
  }

  function getMultiplayerScoreObj()
  {
    return scene.findObject("hud_multiplayer_score_progress_bar")
  }

  function updateAFKTimeKick()
  {
    afkTimeToKick = ::get_mp_kick_countdown()
  }

  function updateAFKTimeKickText(sec)
  {
    local timeToKickAlertObj = scene.findObject("time_to_kick_alert_text")
    if (!::checkObj(timeToKickAlertObj))
      return

    updateAFKTimeKick()
    local showAlertText = ::get_in_battle_time_to_kick_show_alert() >= afkTimeToKick
    local showTimerText = ::get_in_battle_time_to_kick_show_timer() >= afkTimeToKick
    local showMessage = afkTimeToKick >= 0 && (showTimerText || showAlertText)
    timeToKickAlertObj.show(showMessage)
    if (!showMessage)
      return

    if (showAlertText)
    {
      timeToKickAlertObj.setValue(afkTimeToKick > 0
        ? ::loc("inBattle/timeToKick", {timeToKick = time.secondsToString(afkTimeToKick, true, true)})
        : "")
      local curTime = ::dagor.getCurTime()
      local prevSeconds = sec? ((curTime - sec * 1000) / sec).tointeger() : 0
      local currSeconds = sec? (curTime / sec).tointeger() : 0
      timeToKickAlertObj["_blink"] = currSeconds != prevSeconds? "yes" : "no"
      ::play_gui_sound("kick_alert")
    }
    else if (showTimerText)
      timeToKickAlertObj.setValue(::loc("inBattle/timeToKickAlert"))
  }

  //
  // Server message
  //

  function onEventServerMessage(params)
  {
    local serverMessageTimerObject = scene.findObject("server_message_timer")
    if (::checkObj(serverMessageTimerObject))
    {
      SecondsUpdater(serverMessageTimerObject, (@(scene) function (obj, params) {
        return !::server_message_update_scene(scene)
      })(scene))
    }
  }
}

::baseTouchActions <-
{
  onShortcutOn = function (obj)
  {
    ::set_shortcut_on(obj.shortcut_id)
  }

  onShortcutOff = function (obj)
  {
    ::set_shortcut_off(obj.shortcut_id)
  }
}

class HudCutscene extends ::gui_handlers.BaseUnitHud
{
  sceneBlkName = "gui/hud/hudCutscene.blk"

  function initScreen()
  {
  }

  function reinitScreen(params = {})
  {
  }
}

class HudAir extends ::gui_handlers.BaseUnitHud
{
  sceneBlkName = "gui/hud/hudAir.blk"

  function initScreen()
  {
    ::g_hud_display_timers.init(scene, ::ES_UNIT_TYPE_AIRCRAFT)

    updateTacticalMapVisibility()
    updateDmgIndicatorVisibility()
    updateShowHintsNest()

    ::g_hud_event_manager.subscribe("DamageIndicatorToggleVisbility",
      function(ed) { updateDmgIndicatorVisibility() },
      this)
    ::g_hud_event_manager.subscribe("DamageIndicatorSizeChanged",
      function(ed) { updateDmgIndicatorVisibility() },
      this)
    ::g_hud_event_manager.subscribe("LiveStatsVisibilityToggled",
      function(ed) { updateMissionProgressOffset() },
      this)
  }

  function reinitScreen(params = {})
  {
    ::g_hud_display_timers.reinit()
    updateTacticalMapVisibility()
    updateDmgIndicatorVisibility()
    updateShowHintsNest()
  }

  function updateTacticalMapVisibility()
  {
    local isVisible = ::g_hud_vis_mode.getCurMode().isPartVisible(HUD_VIS_PART.MAP)
                         && !is_replay_playing() && (::get_game_type() & ::GT_RACE)
    showSceneBtn("hud_air_tactical_map", isVisible)
  }

  function updateDmgIndicatorVisibility()
  {
    updateMissionProgressOffset()
    updateChatOffset()
  }

  function updateShowHintsNest()
  {
    showSceneBtn("actionbar_hints_nest", false)
  }

  _missionProgressOffset = -1
  function updateMissionProgressOffset()
  {
    local isVisibleByParts = ::is_dmg_indicator_visible()
    local isShifted = isVisibleByParts
                      && ::g_hud_vis_mode.getCurMode().isPartVisible(HUD_VIS_PART.MAP)
                      && !::g_hud_live_stats.isVisible()

    local damageIndicatorObj = scene.findObject("xray_render_dmg_indicator")
    local offset = ::check_obj(damageIndicatorObj) && isShifted ?
      damageIndicatorObj.getSize()[0] + damageIndicatorObj.getPosRC()[0] + guiScene.calcString("1@hudMisObjIconsSize", null) :
      0

    if (_missionProgressOffset == offset)
      return

    ::hud_set_progress_left_margin(offset)
    _missionProgressOffset = offset
  }

  _chatOffset = -1
  function updateChatOffset()
  {
    local chatObj = scene.findObject("chatPlace")
    if (!::check_obj(chatObj))
      return

    local offset = 0
    if (::is_dmg_indicator_visible())
    {
      local dmgIndObj = scene.findObject("xray_render_dmg_indicator")
      if (::check_obj(dmgIndObj))
        offset = guiScene.calcString("sh - 1@bhHud - 1@hudMisObjIconsSize", null) - dmgIndObj.getPosRC()[1]
    }

    if (_chatOffset == offset)
      return

    chatObj["margin-bottom"] = offset.tostring()
    _chatOffset = offset
  }
}

class HudTouchAir extends ::HudAir
{
  scene        = null
  sceneBlkName = "gui/hud/hudTouchAir.blk"
  wndType      = handlerType.CUSTOM

  function initScreen()
  {
    ::HudAir.initScreen()
    fillAirButtons()
  }

  function reinitScreen(params = {})
  {
  }

  function _get(idx)
  {
    if (idx in ::baseTouchActions)
      return ::baseTouchActions.rawget(idx)
    throw null
  }

  function fillAirButtons()
  {
    local actionsObj = scene.findObject("hud_air_actions")
    if (!::checkObj(actionsObj))
      return

    local view = {
      actionFunction = "onAirHudAction"
      items = function ()
      {
        local res = []
        local availActionsList = ::get_aircraft_available_actions()
        local areaNum = 3
        foreach (name,  action in ::air_hud_actions)
          if (::isInArray(name, availActionsList))
            res.append(action)
        return res
      }
    }

    local blk = ::handyman.renderCached(("gui/hud/hudAirActions"), view)
    guiScene.replaceContentFromText(actionsObj, blk, blk.len(), this)
  }
}

class HudTank extends ::gui_handlers.BaseUnitHud
{
  actionBar    = null
  sceneBlkName = "gui/hud/hudTank.blk"

  function initScreen()
  {
    ::g_hud_display_timers.init(scene, ::ES_UNIT_TYPE_TANK)
    ::g_hud_tank_debuffs.init(scene)
    ::g_hud_crew_state.init(scene)
    ::hudEnemyDamage.init(scene)
    actionBar = ActionBar(scene.findObject("hud_action_bar"))
    updateMissionProgressOffset()
    updateShowHintsNest()

    ::g_hud_event_manager.subscribe("DamageIndicatorSizeChanged",
      @(eventData) updateMissionProgressOffset(),
      this)
    ::g_hud_event_manager.subscribe("DamageIndicatorToggleVisbility",
      @(eventData) updateDamageIndicatorBackground(),
      this)
  }

  function reinitScreen(params = {})
  {
    actionBar.reinit()
    ::hudEnemyDamage.reinit()
    ::g_hud_display_timers.reinit()
    ::g_hud_tank_debuffs.reinit()
    ::g_hud_crew_state.reinit()
    updateMissionProgressOffset()
    updateShowHintsNest()
  }

  _missionProgressOffset = -1
  function updateMissionProgressOffset()
  {
    local isShifted = ::g_hud_vis_mode.getCurMode().isPartVisible(HUD_VIS_PART.DMG_PANEL)

    local damageIndicatorObj = scene.findObject("hud_tank_damage_indicator")
    local offset = ::check_obj(damageIndicatorObj) && isShifted ?
      damageIndicatorObj.getPosRC()[0] + damageIndicatorObj.getSize()[0] * 0.85 :
      0

    if (_missionProgressOffset == offset)
      return

    ::hud_set_progress_left_margin(offset)
    _missionProgressOffset = offset
  }

  function updateDamageIndicatorBackground()
  {
    local visMode = ::g_hud_vis_mode.getCurMode()
    local isDmgPanelVisible = ::is_dmg_indicator_visible() && visMode.isPartVisible(HUD_VIS_PART.DMG_PANEL)
    ::showBtn("tank_background", isDmgPanelVisible, scene)

    updateMissionProgressOffset()
  }

  function updateShowHintsNest()
  {
    showSceneBtn("actionbar_hints_nest", true)
  }
}

class HudHelicopter extends ::gui_handlers.BaseUnitHud
{
  actionBar    = null
  sceneBlkName = "gui/hud/hudHelicopter.blk"

  function initScreen()
  {
    ::g_hud_crew_state.init(scene)
    ::hudEnemyDamage.init(scene)
    actionBar = ActionBar(scene.findObject("hud_action_bar"))
  }

  function reinitScreen(params = {})
  {
    actionBar.reinit()
    ::hudEnemyDamage.reinit()
    ::g_hud_crew_state.reinit()

    if (::need_offer_controls_help)
    {
      ::need_offer_controls_help = false
      ::g_hud_event_manager.onHudEvent("hint:controlsHelp:offer", {})
    }
  }
}

class HudTouchTank extends ::HudTank
{
  scene        = null
  sceneBlkName = "gui/hud/hudTouchTank.blk"
  wndType      = handlerType.CUSTOM

  function initScreen()
  {
    ::HudTank.initScreen()
    setupTankControlStick()
    ::g_hud_event_manager.subscribe(
      "tankRepair:offerRepair",
      function (eventData) {
        showTankRepairButton(true)
      },
      this
    )
    ::g_hud_event_manager.subscribe(
      "tankRepair:cantRepair",
      function (eventData) {
        showTankRepairButton(false)
      },
      this
    )
  }

  function reinitScreen(params = {})
  {
    ::HudTank.reinitScreen()
    setupTankControlStick()
  }

  function setupTankControlStick()
  {
    local stickObj = scene.findObject("tank_stick")
    if (!::checkObj(stickObj))
      return

    register_tank_control_stick(stickObj)
  }

  function _get(idx)
  {
    if (idx in ::baseTouchActions)
      return ::baseTouchActions.rawget(idx)
    throw null
  }

  function onEventArtilleryTarget(p)
  {
    local active = ::getTblValue("active", p, false)
    for(local i = 1; i <= 2; i++)
    {
      showSceneBtn("touch_fire_" + i, !active)
      showSceneBtn("touch_art_fire_" + i, active)
    }
  }

  function showTankRepairButton(show)
  {
    local repairButtonObj = scene.findObject("repair_tank")
    if (::checkObj(repairButtonObj))
    {
      repairButtonObj.show(show)
      repairButtonObj.enable(show)
    }
  }
}

class HudShip extends ::gui_handlers.BaseUnitHud
{
  actionBar    = null
  sceneBlkName = "gui/hud/hudShip.blk"
  widgetsList = [
    {
      widgetId = DargWidgets.SHIP_OBSTACLE_RF
      placeholderId = "ship_obstacle_rf"
    }
  ]

  function initScreen()
  {
    ::hudEnemyDamage.init(scene)
    ::g_hud_display_timers.init(scene, ::ES_UNIT_TYPE_SHIP)
    ::g_hud_ship_debuffs.init(scene)
    ::g_hud_crew_state.init(scene)
    actionBar = ActionBar(scene.findObject("hud_action_bar"))
  }

  function reinitScreen(params = {})
  {
    actionBar.reinit()
    ::hudEnemyDamage.reinit()
    ::g_hud_display_timers.reinit()
    ::g_hud_ship_debuffs.reinit()
    ::g_hud_crew_state.reinit()

    if (::need_offer_controls_help)
    {
      ::need_offer_controls_help = false
      if (::is_submarine(::get_player_cur_unit()))
        ::g_hud_event_manager.onHudEvent("hint:controlsHelp:offer", {})
    }
  }
}

function gui_start_hud()
{
  ::handlersManager.loadHandler(::gui_handlers.Hud)
}

function gui_start_hud_no_chat()
{
  //HUD can determine is he need chat or not
  //this function is left just for back compotibility with cpp code
  ::gui_start_hud()
}

function gui_start_spectator()
{
  ::handlersManager.loadHandler(::gui_handlers.Hud, { spectatorMode = true })
}

//contact = null for clean up vioce chat display
function updateVoicechatDisplay(contact = null)
{
  local handler = ::handlersManager.findHandlerClassInScene(::gui_handlers.Hud)
  if(!is_chat_screen_allowed() || !handler)
    return

  local obj = handler.scene.findObject("div_for_voice_chat")
  if(!::checkObj(obj))
    return

  if (contact == null)
  {
    for(local i = obj.childrenCount() - 1; i >= 0 ; i--)
    {
      local cObj = obj.getChild(i)
      if (::checkObj(cObj)) cObj.fade = "out"
    }
    return
  }

  local popup = null
  if("uid" in contact)
    popup = obj.findObject("user_talk_" + contact.uid)
  if(::checkObj(popup))
    popup.fade = (contact.voiceStatus == voiceChatStats.talking) ? "in" : "out"
  else if (contact.voiceStatus == voiceChatStats.talking)
  {
    local data = "usertalk { id:t='user_talk_%s'; fade:t='in'; _size-timer:t='0';" +
                   "img{ background-image:t='#ui/gameuiskin#voip_talking'; color-factor:t='0' }" +
                   "activeText{ id:t='users_name_%s'; text:t=''; color-factor:t='0' }" +
                 "}"
    data = format(data, contact.uid, contact.uid)
    obj.getScene().prependWithBlk(obj, data, this)
    obj.findObject("users_name_" + contact.uid).setValue(contact.name)
  }
}
