local ingame_chat = require("scripts/chat/mpChatModel.nut")
enum SPECTATOR_MODE {
  RESPAWN     // Common multiplayer battle participant between respawns or after death.
  SKIRMISH    // Anyone entered as a Referee into any Skirmish session.
  SUPERVISOR  // Special online tournament master or observer, assigned by Operator.
  REPLAY      // Player viewing any locally saved local-replay or server-replay file.
}

class Spectator extends ::gui_handlers.BaseGuiHandlerWT
{
  scene  = null
  sceneBlkName = "gui/spectator.blk"
  wndType      = handlerType.CUSTOM

  debugMode = false
  spectatorModeInited = false
  catchingFirstTarget = false
  ignoreUiInput = false

  mode = SPECTATOR_MODE.SKIRMISH
  gameType            = 0
  gotRefereeRights    = false
  isMultiplayer       = false
  canControlTimeline  = false
  canControlCameras   = false
  canSeeMissionTimer  = false
  canSeeOppositeTeam  = false
  canSendChatMessages = false

  cameraRotationByMouse = null

  replayAuthorUserId = -1
  replayTimeSpeedMin = 1.0
  replayTimeSpeedMax = 1.0
  replayPaused = null
  replayTimeSpeed = 0.0
  replayTimeTotal = 0.0
  replayTimeProgress = 0
  replayMarkersEnabled = null

  updateCooldown = 0.0
  statNumRows = 0
  teams = [ { players = [] }, { players = [] } ]
  lastTargetNick = ""
  lastTargetId = null
  lastHudUnitType = ::ES_UNIT_TYPE_AIRCRAFT
  lastFriendlyTeam = 0
  statSelPlayerId = [ null, null ]

  funcSortPlayersSpectator = null
  funcSortPlayersDefault   = null

  scanPlayerParams = [
    "canBeSwitchedTo",
    "id",
    "state",
    "isDead",
    "aircraftName",
    "weapon",
    "isBot",
    "deaths",
    "briefMalfunctionState",
    "isBurning",
    "isExtinguisherActive",
  ]

  historyMaxLen = ::g_chat.MAX_ROOM_MSGS_FOR_MODERATOR
  historySkipDuplicatesSec = 10
  historyLogCustomMsgType = -200
  historyLog = null
  chatData = null
  actionBar = null

  staticWidgets = [ "log_div", "map_div", "controls_div" ]
  movingWidgets = { ["spectator_hud_damage"] = [] }

  supportedMsgTypes = [
    ::HUD_MSG_MULTIPLAYER_DMG
    ::HUD_MSG_STREAK
    ::HUD_MSG_OBJECTIVE
    ::HUD_MSG_DIALOG
    ::HUD_MSG_DAMAGE
    ::HUD_MSG_ENEMY_DAMAGE
    ::HUD_MSG_DEATH_REASON
    ::HUD_MSG_EVENT
    -200 // historyLogCustomMsgType
  ]

  weaponIcons = {
    [::BMS_OUT_OF_BOMBS]      = "bomb",
    [::BMS_OUT_OF_ROCKETS]    = "rocket",
    [::BMS_OUT_OF_TORPEDOES]  = "torpedo",
  }

  function initScreen()
  {
    gameType = ::get_game_type()
    local mplayerTable = ::get_local_mplayer() || {}
    local isReplay = ::is_replay_playing()
    local replayProps = ("get_replay_props" in getroottable()) ? ::get_replay_props() : {}

    if (isReplay)
    {
      // Trying to restore some missing data when replay is started via command-line or browser link
      ::back_from_replays = ::back_from_replays || ::gui_start_mainmenu
      ::current_replay = ::current_replay.len() ? ::current_replay : ::getFromSettingsBlk("viewReplay", "")
    }

    gotRefereeRights = ::getTblValue("spectator", mplayerTable, 0) == 1
    mode = isReplay ? SPECTATOR_MODE.REPLAY : gotRefereeRights ? SPECTATOR_MODE.SKIRMISH : SPECTATOR_MODE.SKIRMISH
    isMultiplayer = !!(gameType & ::GT_VERSUS) || !!(gameType & ::GT_COOPERATIVE)
    canControlTimeline  = mode == SPECTATOR_MODE.REPLAY && ::getTblValue("timeSpeedAllowed", replayProps, false)
    canControlCameras   = mode == SPECTATOR_MODE.REPLAY || gotRefereeRights
    canSeeMissionTimer  = !canControlTimeline && mode == SPECTATOR_MODE.SKIRMISH
    canSeeOppositeTeam  = mode != SPECTATOR_MODE.RESPAWN
    canSendChatMessages = mode != SPECTATOR_MODE.REPLAY

    historyLog = []

    loadGameChat()
    if (isMultiplayer)
      setHotkeysToObjTooltips(scene.findObject("gamechat"), {
        btn_activate  = { shortcuts = [ "ID_TOGGLE_CHAT_TEAM" ] }
        btn_send      = { keys = [ "key/Enter" ] }
        btn_cancel    = { keys = [ "key/Esc" ] }
      })
    else
      ::showBtnTable(scene, {
          btn_tab_chat  = false
          target_stats  = false
      })

    local objReplayControls = scene.findObject("controls_div")
    ::showBtnTable(objReplayControls, {
        controls_mpstats_spectator  = mode != SPECTATOR_MODE.REPLAY
        controls_mpstats_replays    = mode == SPECTATOR_MODE.REPLAY
        controls_target             = true
        controls_cameras            = canControlCameras
        controls_toggles            = true
        ID_REPLAY_SHOW_MARKERS      = mode == SPECTATOR_MODE.REPLAY
        controls_timeline           = canControlTimeline
        controls_timer              = canSeeMissionTimer
    })
    ::enableBtnTable(objReplayControls, {
        ID_PREV_PLANE = mode != SPECTATOR_MODE.REPLAY || isMultiplayer
        ID_NEXT_PLANE = mode != SPECTATOR_MODE.REPLAY || isMultiplayer
    })

    for (local section = 0; section < objReplayControls.childrenCount(); section++)
    {
      local objSection = objReplayControls.getChild(section)
      for (local b = 0; b < objSection.childrenCount(); b++)
      {
        local obj = objSection.getChild(b)
        if (obj && obj.is_shortcut && obj.id)
        {
          local shortcutId = obj.id
          local shortcuts = ::get_shortcuts([ shortcutId ])
          local hotkeys = ::get_shortcut_text(shortcuts, 0, false, true)
          if (hotkeys.len())
            hotkeys = "<color=@hotkeyColor>" + ::loc("ui/parentheses/space", {text = hotkeys}) + "</color>"
          local title = ::loc("hotkeys/" + shortcutId)
          obj.tooltip = ::tooltipColorTheme(title + hotkeys)
        }
      }
    }

    if (canControlCameras)
    {
      local objControlsCameras = scene.findObject("controls_cameras")
      ::showBtnTable(objControlsCameras, {
          ID_CAMERA_DEFAULT           = mode == SPECTATOR_MODE.REPLAY || gotRefereeRights
          ID_TOGGLE_FOLLOWING_CAMERA  = mode == SPECTATOR_MODE.REPLAY || gotRefereeRights
          ID_REPLAY_CAMERA_OPERATOR   = mode == SPECTATOR_MODE.REPLAY && !gotRefereeRights
          ID_REPLAY_CAMERA_FLYBY      = mode == SPECTATOR_MODE.REPLAY && !gotRefereeRights
          ID_REPLAY_CAMERA_WING       = mode == SPECTATOR_MODE.REPLAY && !gotRefereeRights
          ID_REPLAY_CAMERA_GUN        = mode == SPECTATOR_MODE.REPLAY && !gotRefereeRights
          ID_REPLAY_CAMERA_RANDOMIZE  = mode == SPECTATOR_MODE.REPLAY && !gotRefereeRights
          ID_REPLAY_CAMERA_FREE       = mode == SPECTATOR_MODE.REPLAY && !gotRefereeRights
      })
    }

    if (mode == SPECTATOR_MODE.REPLAY)
    {
      local timeSpeeds = ("get_time_speeds_list" in getroottable()) ? ::get_time_speeds_list() : [ ::get_time_speed() ]
      replayTimeSpeedMin = timeSpeeds[0]
      replayTimeSpeedMax = timeSpeeds[timeSpeeds.len() - 1]

      local info = ::current_replay.len() && get_replay_info(::current_replay)
      local comments = info && ::getTblValue("comments", info)
      if (comments)
      {
        replayAuthorUserId = ::getTblValue("authorUserId", comments, replayAuthorUserId)
        replayTimeTotal = ::getTblValue("timePlayed", comments, replayTimeTotal)
        scene.findObject("txt_replay_time_total").setValue(::preciseSecondsToString(replayTimeTotal))
      }

      local replaySessionId = ::getTblValue("sessionId", replayProps, "")
      scene.findObject("txt_replay_session_id").setValue(replaySessionId)
    }

    funcSortPlayersSpectator = mpstatSortSpectator.bindenv(this)
    funcSortPlayersDefault   = ::mpstat_get_sort_func(gameType)

    ::g_hud_live_stats.init(scene, "spectator_live_stats_nest", false)
    actionBar = ActionBar(scene.findObject("spectator_hud_action_bar"))
    actionBar.reinit()
    if (!::has_feature("SpectatorUnitDmgIndicator"))
      scene.findObject("xray_render_dmg_indicator_spectator").show(false)
    //TODO: Xray damage indicator // init()
    recalculateLayout()

    ::g_hud_event_manager.subscribe("HudMessage", function(eventData)
      {
        onHudMessage(eventData)
      }, this)

    onUpdate()
    scene.findObject("update_timer").setUserData(this)

    updateClientHudOffset()
  }

  function reinitScreen()
  {
    restoreFocus()
    updateHistoryLog(true)
    loadGameChat()

    ::g_hud_live_stats.update()
    actionBar.reinit()
    //TODO: Xray damage indicator // reinit()
    recalculateLayout()
  }

  function loadGameChat()
  {
    if (isMultiplayer)
    {
      chatData = ::loadGameChatToObj(scene.findObject("chat_container"), "gui/chat/gameChatSpectator.blk", this, true, !canSendChatMessages, false)

      local objGameChat = scene.findObject("gamechat")
      objGameChat.findObject("chat_input_div").show(canSendChatMessages)
      local objChatLogDiv = objGameChat.findObject("chat_log_tdiv")
      objChatLogDiv.size = canSendChatMessages ? objChatLogDiv.sizeWithInput : objChatLogDiv.sizeWithoutInput

      if (mode == SPECTATOR_MODE.SKIRMISH || mode == SPECTATOR_MODE.SUPERVISOR)
        ::chat_set_mode(::CHAT_MODE_ALL, "")
    }
  }

  function onShowHud(show = true)
  {
    if (show)
      restoreFocus()
  }

  function onUpdate(obj=null, dt=0.0)
  {
    if (!spectatorModeInited && is_in_flight())
    {
      if (!getTargetPlayer())
      {
        spectatorModeInited = true
        ::on_spectator_mode(true)
        catchingFirstTarget = isMultiplayer && gotRefereeRights
        dagor.debug("Spectator: init " + ::getEnumValName("SPECTATOR_MODE", mode))
      }
      updateCooldown = 0.0
    }

    if (!::checkObj(scene))
      return

    updateCooldown -= dt
    local isUpdateByCooldown = updateCooldown <= 0.0

    local targetNick  = ::get_spectator_target_name()
    local hudUnitType = is_tank_interface() ? ::ES_UNIT_TYPE_TANK : ::ES_UNIT_TYPE_AIRCRAFT
    local isTargetSwitched = targetNick != lastTargetNick || hudUnitType != lastHudUnitType
    lastTargetNick  = targetNick
    lastHudUnitType = hudUnitType

    local friendlyTeam = ::get_player_army_for_hud()
    local friendlyTeamSwitched = friendlyTeam != lastFriendlyTeam
    lastFriendlyTeam = friendlyTeam

    if (isUpdateByCooldown || isTargetSwitched)
    {
      updateStats()
      updateTarget(isTargetSwitched)
    }

    if (friendlyTeamSwitched)
    {
      ::g_hud_live_stats.show(isMultiplayer, null, lastTargetId)
      updateHistoryLog()
    }

    updateControls(isTargetSwitched)

    if (::is_chat_active())
    {
      local obj = scene.findObject("chat_input")
      if (!::checkObj(obj) || !obj.isFocused())
        ::game_chat_input_toggle_request(false)
    }

    if (isUpdateByCooldown)
    {
      updateCooldown = 0.5

      // Forced switching target to catch the first target
      if (spectatorModeInited && catchingFirstTarget)
      {
        if (getTargetPlayer())
          catchingFirstTarget = false
        else
        {
          foreach (info in teams)
            foreach (p in info.players)
              if (p.state == ::PLAYER_IN_FLIGHT && !p.isDead)
              {
                switchTargetPlayer(p.id)
                break
              }
        }
      }
    }
  }

  function restoreFocus(checkPrimaryFocus = true)
  {
    local player = getTargetPlayer()
    if (!player)
      return

    local tblObj = getTeamTableObj(player.team)
    if (tblObj)
      tblObj.select()
  }

  function isPlayerSpectatorTarget(player, targetNick)
  {
    if (!player || targetNick == "")
      return false
    local nickStart = getPlayerNick(player) + " ("
    local nickStartLen = nickStart.len()
    return targetNick.len() > nickStartLen && targetNick.slice(0, nickStartLen) == nickStart
  }

  function isPlayerFriendly(player)
  {
    return player != null && player.team == ::get_player_army_for_hud()
  }

  function getPlayerNick(player, colored = false)
  {
    local name = player ? format("%s%s", (player.clanTag != "" ?  player.clanTag + " " : ""), player.name) : ""
    local color = !colored ? "" : !player ? "hudColorRed" : player.isLocal ? "hudColorHero" : player.isInHeroSquad ? "hudColorSquad" :
      player.team == ::get_player_army_for_hud() ? "hudColorBlue" : "hudColorRed"
    return colored ? ::colorize(color, name) : name
  }

  function getPlayerStateDesc(player)
  {
    return !player ? "" :
      !player.ingame ? ::loc(player.deaths ? "spectator/player_quit" : "multiplayer/state/player_not_in_game") :
      player.isDead ? ::loc(player.deaths ? "spectator/player_vehicle_lost" : "spectator/player_connecting") :
      !player.canBeSwitchedTo ? ::loc("multiplayer/state/player_in_game/location_unknown") : ""
  }

  function getUnitMalfunctionDesc(player)
  {
    if (!player || !player.ingame || player.isDead)
      return ""
    local briefMalfunctionState = ::getTblValue("briefMalfunctionState", player, 0)
    local list = []
    if (::getTblValue("isExtinguisherActive", player, false))
      list.append(::loc("fire_extinguished"))
    else if (::getTblValue("isBurning", player, false))
      list.append(::loc("fire_in_tank"))
    if (briefMalfunctionState & ::BMS_ENGINE_BROKEN)
      list.append(::loc("my_dmg_msg/tank_engine"))
    if (briefMalfunctionState & ::BMS_MAIN_GUN_BROKEN)
      list.append(::loc("my_dmg_msg/tank_gun_barrel"))
    if (briefMalfunctionState & ::BMS_TRACK_BROKEN)
      list.append(::loc("my_dmg_msg/tank_track"))
    if (briefMalfunctionState & ::BMS_OUT_OF_AMMO)
      list.append(::loc("controls/no_bullets_left"))
    if (briefMalfunctionState & ::BMS_OUT_OF_BOMBS)
      list.append(::loc("controls/no_bombs_left"))
    if (briefMalfunctionState & ::BMS_OUT_OF_ROCKETS)
      list.append(::loc("controls/no_rockets_left"))
    if (briefMalfunctionState & ::BMS_OUT_OF_TORPEDOES)
      list.append(::loc("controls/no_torpedoes_left"))
    local desc = ::implode(list, ::loc("ui/semicolon"))
    if (desc.len())
      desc = ::colorize("warningTextColor", desc)
    return desc
  }

  function getPlayer(id)
  {
    foreach (info in teams)
      foreach (p in info.players)
        if (p.id == id)
          return p
    return null
  }

  function getPlayerByUserId(userId)
  {
    userIdStr = userId.tostring()
    foreach (info in teams)
      foreach (p in info.players)
        if (p.userId == userIdStr)
          return p
    return null
  }

  function getTargetPlayer()
  {
    local name = ::get_spectator_target_name()

    if (!isMultiplayer)
      return (name.len() && teams.len() && teams[0].players.len()) ? teams[0].players[0] : null

    if (name == "")
      return (mode == SPECTATOR_MODE.RESPAWN && lastTargetId) ? getPlayer(lastTargetId) : null

    foreach (info in teams)
      foreach (p in info.players)
        if (isPlayerSpectatorTarget(p, name))
          return p

    return null
  }

  function setTargetInfo(player)
  {
    local infoObj = scene.findObject("target_info")
    local waitingObj = scene.findObject("waiting_for_target_spawn")
    if (!::checkObj(infoObj) || !::checkObj(waitingObj))
      return

    infoObj.show(player != null && isMultiplayer)
    waitingObj.show(player == null && catchingFirstTarget)

    if (!player || !isMultiplayer)
      return

    guiScene.setUpdatesEnabled(false, false)

    if (isMultiplayer)
    {
      local statusObj = infoObj.findObject("target_state")
      statusObj.setValue(getPlayerStateDesc(player))
    }

    guiScene.setUpdatesEnabled(true, true)
  }

  function updateTarget(targetSwitched = false)
  {
    local player = getTargetPlayer()

    if (targetSwitched && player)
    {
      lastTargetId = player ? player.id : null
      local playerTeamIndex = teamIdToIndex(player.team)
      statSelPlayerId[playerTeamIndex] = player.id
      local tblObj = getTeamTableObj(player.team)
      if (tblObj)
      {
        tblObj.select()
        onStatTblFocus(tblObj)
      }
    }

    if (targetSwitched)
    {
      ::g_hud_live_stats.show(isMultiplayer, null, lastTargetId)
      actionBar.reinit()
      //TODO: Xray damage indicator // reinit()
      recalculateLayout()
    }

    setTargetInfo(player)
  }

  function updateControls(targetSwitched = false)
  {
    if (canControlTimeline)
    {
      if (::is_game_paused() != replayPaused)
      {
        replayPaused = ::is_game_paused()
        scene.findObject("ID_REPLAY_PAUSE").findObject("icon")["background-image"] = replayPaused ? "#ui/gameuiskin#replay_play" : "#ui/gameuiskin#replay_pause"
      }
      if (::get_time_speed() != replayTimeSpeed)
      {
        replayTimeSpeed = ::get_time_speed()
        scene.findObject("txt_replay_time_speed").setValue(::format("%.3fx", replayTimeSpeed))
        scene.findObject("ID_REPLAY_SLOWER").enable(replayTimeSpeed > replayTimeSpeedMin)
        scene.findObject("ID_REPLAY_FASTER").enable(replayTimeSpeed < replayTimeSpeedMax)
      }
      if (::is_replay_markers_enabled() != replayMarkersEnabled)
      {
        replayMarkersEnabled = ::is_replay_markers_enabled()
        scene.findObject("ID_REPLAY_SHOW_MARKERS").highlighted = replayMarkersEnabled ? "yes" : "no"
      }
      local replayTimeCurrent = ::get_usefull_total_time()
      scene.findObject("txt_replay_time_current").setValue(::preciseSecondsToString(replayTimeCurrent))
      local progress = (replayTimeTotal > 0) ? (1000 * replayTimeCurrent / replayTimeTotal).tointeger() : 0
      if (progress != replayTimeProgress)
      {
        replayTimeProgress = progress
        scene.findObject("timeline_progress").setValue(replayTimeProgress)
      }
    }

    if (canSeeMissionTimer)
    {
      scene.findObject("txt_mission_timer").setValue(::secondsToString(::get_usefull_total_time(), false))
    }

    if (::is_spectator_rotation_forced() != cameraRotationByMouse)
    {
      cameraRotationByMouse = ::is_spectator_rotation_forced()
      scene.findObject("ID_TOGGLE_FORCE_SPECTATOR_CAM_ROT").highlighted = cameraRotationByMouse ? "yes" : "no"
    }

    if (canControlCameras && targetSwitched)
    {
      local player = getTargetPlayer()
      local isValid = player != null
      local isPlayer = player ? !player.isBot : false
      local userId   = player ? ::getTblValue("userId", player, 0) : 0
      local isAuthor = userId == replayAuthorUserId
      local isAuthorUnknown = replayAuthorUserId == -1

      local objControlsCameras = scene.findObject("controls_cameras")
      ::enableBtnTable(objControlsCameras, {
          ID_CAMERA_DEFAULT           = isValid
          ID_TOGGLE_FOLLOWING_CAMERA  = isValid && isPlayer && (gotRefereeRights || isAuthor || isAuthorUnknown)
          ID_REPLAY_CAMERA_OPERATOR   = isValid
          ID_REPLAY_CAMERA_FLYBY      = isValid
          ID_REPLAY_CAMERA_WING       = isValid
          ID_REPLAY_CAMERA_GUN        = isValid
          ID_REPLAY_CAMERA_RANDOMIZE  = isValid
          ID_REPLAY_CAMERA_FREE       = isValid
          ID_REPLAY_CAMERA_HOVER      = isValid
      })
    }
  }

  function statTblGetSelectedPlayer(obj)
  {
    local teamNum = ::getObjIdByPrefix(obj, "table_team")
    if (!teamNum || teamNum != "1" && teamNum != "2")
      return null
    local teamIndex = teamNum.tointeger() - 1
    local players =  teams[teamIndex].players
    local value = obj.getValue()
    if (value < 0 || value >= players.len())
      return null

    return players[value]
  }

  function onPlayerClick(obj)
  {
    if (ignoreUiInput)
      return

    local player = statTblGetSelectedPlayer(obj)
    if (!player)
      return

    statSelPlayerId[teamIdToIndex(player.team)] = player.id
    if (!obj.isFocused())
      obj.select()

    switchTargetPlayer(player.id)
  }

  function onPlayerRClick(obj)
  {
    local player = statTblGetSelectedPlayer(obj)
    if (player)
      ::session_player_rmenu(this, player)
  }

  function statTblUpdateSelection(obj)
  {
    local teamNum = ::getObjIdByPrefix(obj, "table_team")
    if (!teamNum || teamNum != "1" && teamNum != "2")
      return
    local teamIndex = teamNum.tointeger() - 1
    local players =  teams[teamIndex].players

    local selIndex = -1

    if (obj.isFocused())
    {
      if (statSelPlayerId[teamIndex])
        foreach (index, player in players)
          if (("id" in player) && player.id == statSelPlayerId[teamIndex])
          {
            selIndex = index
            break
          }
      if (selIndex == -1 && players.len() > 0)
        selIndex = 0
    }

    if (obj.getValue() != selIndex)
    {
      ignoreUiInput = true
      obj.setValue(selIndex)
      obj.cur_row = selIndex
      ignoreUiInput = false
    }
  }

  function onSwitchPlayersTbl(obj)
  {
    local tab1 = scene.findObject("table_team1")
    local tab2 = scene.findObject("table_team2")
    if (!::checkObj(tab1) || !::checkObj(tab2))
      return

    local tblObj = (tab1.isFocused() && tab2.isVisible()) ? tab2 : (tab2.isFocused() && tab1.isVisible()) ? tab1 : null
    if (!tblObj)
      return

    tblObj.select()
    onPlayerClick(tblObj)
  }

  function onStatTblFocus(obj)
  {
    local tab1 = scene.findObject("table_team1")
    local tab2 = scene.findObject("table_team2")
    if (!::checkObj(tab1) || !::checkObj(tab2))
      return

    statTblUpdateSelection(tab1)
    statTblUpdateSelection(tab2)
  }

  function switchTargetPlayer(id = null, index = null)
  {
    if (id)
      ::switch_spectator_target_by_id(id)
    else if (index)
      ::switch_spectator_target(index > 0)
  }

  function onBtnMpStatScreen(obj)
  {
    if (isMultiplayer)
      ::gui_start_mpstatscreen()
    else
      ::gui_start_tactical_map()
  }

  function onBtnShortcut(obj)
  {
    local id = (::checkObj(obj) && obj.id) || ""
    if (id.len() > 3 && id.slice(0, 3) == "ID_")
      ::toggle_shortcut(id)
  }

  function onMapClick(obj)
  {
    local mapLargePanelObj = scene.findObject("map_large_div")
    if (!::checkObj(mapLargePanelObj))
      return
    local mapLargeObj = mapLargePanelObj.findObject("tactical_map")
    if (!::checkObj(mapLargeObj))
      return

    local toggle = !mapLargePanelObj.isVisible()
    mapLargePanelObj.show(toggle)
    mapLargeObj.show(toggle)
    mapLargeObj.enable(toggle)
  }

  function onToggleButtonClick(obj)
  {
    if (!::checkObj(obj) || !("toggleObj" in obj))
      return
    local toggleObj = scene.findObject(obj.toggleObj)
    if (!::checkObj(toggleObj))
      return

    local toggle = !toggleObj.isVisible()
    toggleObj.show(toggle)
    obj.toggled = toggle ? "yes" : "no"

    restoreFocus()
    updateHistoryLog(true)
    updateClientHudOffset()
    recalculateLayout()
  }

  function teamIdToIndex(teamId)
  {
    foreach (info in teams)
      if (info.teamId == teamId)
        return info.index
    return 0
  }

  function getTableObj(index)
  {
    local obj = scene.findObject("table_team" + (index + 1))
    return ::checkObj(obj) ? obj : null
  }

  function getTeamTableObj(teamId)
  {
    return getTableObj(teamIdToIndex(teamId))
  }

  function getTeamPlayers(teamId)
  {
    local tbl = (teamId != 0) ? ::get_mplayers_list(teamId, true) : [ ::get_local_mplayer() ]
    for (local i = tbl.len() - 1; i >= 0; i--)
    {
      local player = tbl[i]
      if (player.spectator || mode == SPECTATOR_MODE.SKIRMISH && (player.state != ::PLAYER_IN_FLIGHT || player.isDead) && !player.deaths)
      {
        tbl.remove(i)
        continue
      }

      player.team = teamId
      player.ingame <- player.state == ::PLAYER_IN_FLIGHT || player.state == ::PLAYER_IN_RESPAWN
      player.isActing <- player.ingame
        && (!(gameType & ::GT_RACE) || player.raceFinishTime < 0)
        && (!(gameType & ::GT_LAST_MAN_STANDING) || player.deaths == 0)
      if (mode == SPECTATOR_MODE.REPLAY && !player.isBot)
        player.isBot = player.userId == "0" || ::getTblValue("invitedName", player) != null
      local unitId = (!player.isDead && player.state == ::PLAYER_IN_FLIGHT) ? player.aircraftName : null
      unitId = (unitId != "dummy_plane" && unitId != "") ? unitId : null
      player.aircraftName = unitId || ""
      player.canBeSwitchedTo = unitId ? player.canBeSwitchedTo : false
    }
    tbl.sort(funcSortPlayersSpectator)
    return tbl
  }

  function mpstatSortSpectator(a, b)
  {
    return b.isActing <=> a.isActing
      || !a.isActing && funcSortPlayersDefault(a, b)
      || a.isBot <=> b.isBot
      || a.id <=> b.id
  }

  function getPlayersData()
  {
    local _teams = array(2, null)
    local isMpMode = !!(gameType & ::GT_VERSUS) || !!(gameType & ::GT_COOPERATIVE)
    local isPvP = !!(gameType & ::GT_VERSUS)
    local isTeamplay = isPvP && ::is_mode_with_teams(gameType)

    if (isTeamplay || !canSeeOppositeTeam)
    {
      local localTeam = ::get_mp_local_team() != 2 ? 1 : 2
      local myTeamFriendly = localTeam == ::get_player_army_for_hud()

      for (local i = 0; i < 2; i++)
      {
        local teamId = ((i == 0) == (localTeam == 1)) ? Team.A : Team.B
        local color = ((i == 0) == myTeamFriendly)? "blue" : "red"

        _teams[i] = {
          active = true
          index = i
          teamId = teamId
          players = getTeamPlayers(teamId)
          color = color
        }
      }
    }
    else if (isMpMode)
    {
      local teamId = isTeamplay ? ::get_mp_local_team() : ::GET_MPLAYERS_LIST
      local color  = isTeamplay ? "blue" : "red"

      _teams[0] = {
        active = true
        index = 0
        teamId = teamId
        players = getTeamPlayers(teamId)
        color = color
      }
      _teams[1] = {
        active = false
        index = 1
        teamId = 0
        players = []
        color = ""
      }
    }
    else
    {
      local teamId = 0
      local color = "blue"

      _teams[0] = {
        active = false
        index = 0
        teamId = teamId
        players = getTeamPlayers(teamId)
        color = color
      }
      _teams[1] = {
        active = false
        index = 1
        teamId = 0
        players = []
        color = ""
      }
    }

    local length = 0
    foreach (info in _teams)
      length = max(length, info.players.len())
    local maxNoScroll = ::global_max_players_versus / 2
    statNumRows = min(maxNoScroll, length)
    return _teams
  }

  function updateStats()
  {
    local _teams = getPlayersData()
    foreach (idx, info in _teams)
    {
      local tblObj = getTableObj(info.index)
      if (tblObj)
      {
        local infoPrev = ::getTblValue(idx, teams)
        if (info.active)
          statTblUpdateInfo(tblObj, info, infoPrev)
        if (info.active != ::getTblValue("active", infoPrev, true))
        {
          tblObj.getParent().getParent().show(info.active)
          scene.findObject("btnToggleStats" + (idx + 1)).show(info.active)
        }
      }
    }
    teams = _teams
  }

  function addPlayerRows(objTbl, teamInfo)
  {
    local totalRows = objTbl.childrenCount()
    local newRows = teamInfo.players.len() - totalRows
    if (newRows <= 0)
      return totalRows

    local view = { rows = array(newRows, 1)
                   iconLeft = teamInfo.index == 0
                 }
    local data = ::handyman.renderCached(("gui/hud/spectatorTeamRow"), view)
    guiScene.appendWithBlk(objTbl, data, this)
    return totalRows
  }

  function isPlayerChanged(p1, p2)
  {
    if (debugMode)
      return true
    if (!p1 != !p2)
      return true
    if (!p1)
      return false
    foreach(param in scanPlayerParams)
      if (::getTblValue(param, p1) != ::getTblValue(param, p2))
        return true
    return false
  }

  function statTblUpdateInfo(objTbl, teamInfo, infoPrev = null)
  {
    local players = ::getTblValue("players", teamInfo)
    if (!::checkObj(objTbl) || !players)
      return

    guiScene.setUpdatesEnabled(false, false)

    local prevPlayers = ::getTblValue("players", infoPrev)
    local wasRows = addPlayerRows(objTbl, teamInfo)
    local totalRows = objTbl.childrenCount()

    local selPlayerId = getTblValue(teamInfo.index, statSelPlayerId)
    local selIndex = null

    for(local i = 0; i < totalRows; i++)
    {
      local player = ::getTblValue(i, players)
      if (i < wasRows && !isPlayerChanged(player, ::getTblValue(i, prevPlayers)))
        continue

      local obj = objTbl.getChild(i)
      obj.show(player != null)
      if (!player)
        continue

      local nameObj = obj.findObject("name")
      if (!::checkObj(nameObj)) //some validation
        continue

      local playerName = getPlayerNick(player)
      nameObj.setValue(playerName)

      local unitId = player.aircraftName != "" ? player.aircraftName : null
      local iconImg = !player.ingame ? "#ui/gameuiskin#player_not_ready" : unitId ? ::getUnitClassIco(unitId) : "#ui/gameuiskin#dead"
      local iconType = unitId ? ::get_unit_role(unitId) : ""
      local stateDesc = getPlayerStateDesc(player)
      local malfunctionDesc = getUnitMalfunctionDesc(player)

      obj.dead = player.canBeSwitchedTo ? "no" : "yes"
      obj.findObject("unit").setValue(getUnitName(unitId || "dummy_plane"))
      obj.tooltip = ::tooltipColorTheme(playerName + (unitId ? ::loc("ui/parentheses/space", {text = ::getUnitName(unitId, false)}) : "")
        + (stateDesc != "" ? ("\n" + stateDesc) : "")
        + (malfunctionDesc != "" ? ("\n" + malfunctionDesc) : ""))

      if (debugMode)
        obj.tooltip += "\n\n" + getPlayerDebugTooltipText(player)

      local unitIcoObj = obj.findObject("unit-ico")
      unitIcoObj["background-image"] = iconImg
      unitIcoObj.shopItemType = iconType

      local briefMalfunctionState = ::getTblValue("briefMalfunctionState", player, 0)
      local weaponType = (unitId && ("weapon" in player)) ?
          ::getWeaponTypeIcoByWeapon(unitId, player.weapon, true) : ::getWeaponTypeIcoByWeapon("", "")

      foreach (bit, w in weaponIcons)
      {
        local weaponIcoObj = obj.findObject(w + "-ico")
        weaponIcoObj.show(weaponType[w] != "")
        weaponIcoObj["reloading"] = (briefMalfunctionState & bit) ? "yes" : "no"
      }

      local battleStateIconClass =
        (!player.ingame || player.isDead)                     ? "" :
        ::getTblValue("isExtinguisherActive", player, false)  ? "ExtinguisherActive" :
        ::getTblValue("isBurning", player, false)             ? "IsBurning" :
        (briefMalfunctionState & ::BMS_ENGINE_BROKEN)         ? "BrokenEngine" :
        (briefMalfunctionState & ::BMS_MAIN_GUN_BROKEN)       ? "BrokenGun" :
        (briefMalfunctionState & ::BMS_TRACK_BROKEN)          ? "BrokenTrack" :
        (briefMalfunctionState & ::BMS_OUT_OF_AMMO)           ? "OutOfAmmo" :
                                                                ""
      obj.findObject("battle-state-ico")["class"] = battleStateIconClass

      if (player.id == selPlayerId)
        selIndex = i
    }

    if (selIndex != null && objTbl.getValue() != selIndex && objTbl.isFocused())
    {
      ignoreUiInput = true
      objTbl.setValue(selIndex)
      objTbl.cur_row = selIndex
      ignoreUiInput = false
    }

    if (objTbl.team != teamInfo.color)
      objTbl.team = teamInfo.color

    guiScene.setUpdatesEnabled(true, true)
  }

  function getPlayerDebugTooltipText(player)
  {
    if (!player)
      return ""
    local extra = []
    foreach (i, v in player)
    {
      if (i == "uid")
        continue
      if (i == "state")
        v = ::playerStateToString(v)
      extra.append(i + " = " + v)
    }
    extra.sort()
    return ::implode(extra, "\n")
  }

  function updateClientHudOffset()
  {
    guiScene.setUpdatesEnabled(true, true)
    local obj = scene.findObject("stats_left")
    ::spectator_air_hud_offset_x = (::checkObj(obj) && obj.isVisible()) ? obj.getPos()[0] + obj.getSize()[0] : 0
  }

  function onBtnLogTabSwitch(obj)
  {
    if (!::checkObj(obj))
      return

    local tabId = obj.id
    foreach (i in ["btn_tab_history", "btn_tab_chat"])
    {
      local objTab = scene.findObject(i)
      if (::checkObj(objTab))
      {
        local wasSelected = objTab.highlighted == "yes"
        local newSelected = i == tabId
        objTab.highlighted = newSelected ? "yes" : "no"
        if (wasSelected || newSelected)
          objTab.alert = "no"
      }
    }

    ::showBtnTable(scene, {
      history_container = tabId == "btn_tab_history"
      chat_container    = tabId == "btn_tab_chat"
    })

    if (tabId == "btn_tab_chat")
      loadGameChat()
    updateHistoryLog(true)
  }

  function onEventMpChatLogUpdated(params)
  {
    if (!::checkObj(scene))
      return
    local obj = scene.findObject("btn_tab_chat")
    if (::checkObj(obj))
      obj.alert = "yes"
  }

  function onEventMpChatInputRequested(params)
  {
    if (!::checkObj(scene))
      return
    if (!canSendChatMessages)
      return
    local obj = scene.findObject("btnToggleLog")
    if (::checkObj(obj) && obj.toggled != "yes")
      onToggleButtonClick(obj)
    obj = scene.findObject("btn_tab_chat")
    if (::checkObj(obj) && obj.highlighted != "yes")
      onBtnLogTabSwitch(obj)

    if (::getTblValue("activate", params, false))
      ::game_chat_input_toggle_request(true)
  }

  function onEventMpChatInputToggled(params)
  {
    if (!::checkObj(scene))
      return
    local active = ::getTblValue("active", params, true)
    if (!active)
      restoreFocus()
  }

  function onEventHudActionbarResized(params)
  {
    recalculateLayout()
  }

  function onPlayerRequestedArtillery(userId)
  {
    local player = getPlayerByUserId(userId)
    local color = isPlayerFriendly(player) ? "hudColorDarkBlue" : "hudColorDarkRed"
    addHistroyLogMessage(::colorize(color, ::loc("artillery_strike/called_by_player", { player =  getPlayerNick(player, true) })))
  }

  function onHudMessage(msg)
  {
    if (!::isInArray(msg.type, supportedMsgTypes))
      return

    if (!("id" in msg))
      msg.id <- -1
    if (!("text" in msg))
      msg.text <- ""

    msg.time <- ::get_usefull_total_time()

    historyLog = historyLog || []
    if (msg.id != -1)
      foreach (m in historyLog)
        if (m.id == msg.id)
          return
    if (msg.id == -1 && msg.text != "")
    {
      local skipDupTime = msg.time - historySkipDuplicatesSec
      for (local i = historyLog.len() - 1; i >= 0; i--)
      {
        if (historyLog[i].time < skipDupTime)
          break
        if (historyLog[i].text == msg.text)
          return
      }
    }

    local msgTeamAlly  = "message" + (::get_player_army_for_hud() != 2 ? 1 : 2)
    local msgTeamEnemy = "message" + (::get_player_army_for_hud() != 2 ? 2 : 1)
    local message = buildHistoryLogMessage(msg)
    msg[msgTeamAlly] <- message
    msg[msgTeamEnemy] <- (msg.type == ::HUD_MSG_MULTIPLAYER_DMG) ? "" :
      invertHistoryLogMsgTeamColors(message)

    if (historyLog.len() == historyMaxLen)
      historyLog.remove(0)
    historyLog.append(msg)

    updateHistoryLog()
  }

  function addHistroyLogMessage(text)
  {
    onHudMessage({
      id   = -1
      text = text
      type = historyLogCustomMsgType
    })
  }

  function clearHistoryLog()
  {
    if (!historyLog)
      return
    historyLog.clear()
    updateHistoryLog()
  }

  function updateHistoryLog(updateVisibility = false)
  {
    if (!::checkObj(scene))
      return

    local obj = scene.findObject("history_log")
    if (::checkObj(obj))
    {
      if (updateVisibility)
        guiScene.setUpdatesEnabled(true, true)
      historyLog = historyLog || []

      local msgTeamAlly  = "message" + (::get_player_army_for_hud() != 2 ? 1 : 2)
      foreach (msg in historyLog)
        if (msg[msgTeamAlly] == "")
          msg[msgTeamAlly] <- buildHistoryLogMessage(msg)

      local historyLogMessages = ::u.map(historyLog, (@(msgTeamAlly) function(x) { return x[msgTeamAlly] })(msgTeamAlly))
      obj.setValue(obj.isVisible() ? ::implode(historyLogMessages, "\n") : "")
    }
  }

  function buildHistoryLogMessage(msg)
  {
    local timestamp = ::secondsToString(msg.time, false) + " "
    switch (msg.type)
    {
      // All players messages
      case ::HUD_MSG_MULTIPLAYER_DMG: // Any player or ai unit damaged or destroyed
        local text = ::HudBattleLog.msgMultiplayerDmgToText(msg)
        return timestamp + ::colorize("userlogColoredText", text)
        break
      case ::HUD_MSG_STREAK: // Any player got streak
        local text = ::HudBattleLog.msgEscapeCodesToCssColors(msg.text)
        return timestamp + ::colorize("streakTextColor", ::loc("unlocks/streak") + ::loc("ui/colon") + text)
        break

      // Mission objectives
      case ::HUD_MSG_OBJECTIVE: // Hero team mission objective
        local text = ::HudBattleLog.msgEscapeCodesToCssColors(msg.text)
        return timestamp + ::colorize("white", ::loc("sm_objective") + ::loc("ui/colon") + text)
        break

      // Team progress
      case ::HUD_MSG_DIALOG: // Hero team base capture events
        local text = ::HudBattleLog.msgEscapeCodesToCssColors(msg.text)
        return timestamp + ::colorize("commonTextColor", text)
        break

      // Hero (spectated target) messages
      case ::HUD_MSG_DAMAGE: // Hero air unit damaged
      case ::HUD_MSG_ENEMY_DAMAGE: // Hero target air unit damaged
      case ::HUD_MSG_DEATH_REASON: // Hero unit destroyed, killer name
      case ::HUD_MSG_EVENT: // Hero tank unit damaged, and some system messages
      case historyLogCustomMsgType: // Custom messages sent by script
        local text = ::HudBattleLog.msgEscapeCodesToCssColors(msg.text)
        return timestamp + ::colorize("commonTextColor", text)
        break
      default:
        return ""
    }
  }

  function invertHistoryLogMsgTeamColors(message)
  {
    local colorMap = [
      [ "hudColorBlue",  "_hudColorBlue" ],
      [ "hudColorRed",   "hudColorBlue" ],
      [ "_hudColorBlue", "hudColorRed" ],
    ]
    foreach(pair in colorMap)
      message = ::stringReplace(message, "<color=@" + pair[0] + ">", "<color=@" + pair[1] + ">")
    return message
  }

  function setHotkeysToObjTooltips(scanObj, objects)
  {
    if (::checkObj(scanObj))
      foreach (objId, keys in objects)
      {
        local obj = scanObj.findObject(objId)
        if (::checkObj(obj))
        {
          local hotkeys = ""
          if ("shortcuts" in keys)
          {
            local shortcuts = ::get_shortcuts(keys.shortcuts)
            local keys = []
            foreach (idx, data in shortcuts)
            {
              local shortcutsText = ::get_shortcut_text(shortcuts, idx, true, true)
              if (shortcutsText != "")
                keys.append(shortcutsText)
            }
            hotkeys = ::implode(keys, ::loc("ui/comma"))
          }
          else if ("keys" in keys)
          {
            local keysLocalized = ::u.map(keys.keys, ::loc)
            hotkeys = ::implode(keysLocalized, ::loc("ui/comma"))
          }

          if (hotkeys != "")
          {
            local tooltip = obj.tooltip || ""
            local add = "<color=@hotkeyColor>" + ::loc("ui/parentheses/space", {text = hotkeys}) + "</color>"
            obj.tooltip = ::tooltipColorTheme(tooltip + add)
          }
        }
      }
  }

  function recalculateLayout()
  {
    local staticBoxes = []
    foreach (objId in staticWidgets)
    {
      local obj = scene.findObject(objId)
      if (!::checkObj(obj))
        continue
      if (obj.isVisible())
        staticBoxes.append(::GuiBox().setFromDaguiObj(obj))
    }

    foreach (objId, positions in movingWidgets)
    {
      local obj = scene.findObject(objId)
      if (!::checkObj(obj))
        continue

      if (!positions.len())
      {
        local idx = 1
        while (obj["pos" + idx])
          positions.append(obj["pos" + idx++])
      }

      local posStr = "0, 0"
      local size = obj.getSize()
      foreach (p in positions)
      {
        posStr = p
        local pos = ::split(posStr, ",")
        if (pos.len() != 2)
          break
        foreach (i, v in pos)
          pos[i] = guiScene.calcString(v, obj)
        local b1 = ::GuiBox(pos[0], pos[1], pos[0] + size[0], pos[1] + size[1])
        local fits = true
        foreach(b2 in staticBoxes)
        {
          if (b1.isIntersect(b2))
          {
            fits = false
            break
          }
        }
        if (fits)
          break
      }
      if (obj.pos != posStr)
        obj.pos = posStr
    }
  }
}

function spectator_debug_mode()
{
  local handler = ::is_dev_version && ::handlersManager.findHandlerClassInScene(::Spectator)
  if (handler)
    handler.debugMode = !handler.debugMode
}

function playerStateToString(state)
{
  switch (state)
  {
    case ::PLAYER_NOT_EXISTS:                 return "PLAYER_NOT_EXISTS"
    case ::PLAYER_HAS_LEAVED_GAME:            return "PLAYER_HAS_LEAVED_GAME"
    case ::PLAYER_IN_LOBBY_NOT_READY:         return "PLAYER_IN_LOBBY_NOT_READY"
    case ::PLAYER_IN_LOADING:                 return "PLAYER_IN_LOADING"
    case ::PLAYER_IN_STATISTICS_BEFORE_LOBBY: return "PLAYER_IN_STATISTICS_BEFORE_LOBBY"
    case ::PLAYER_IN_LOBBY_READY:             return "PLAYER_IN_LOBBY_READY"
    case ::PLAYER_READY_TO_START:             return "PLAYER_READY_TO_START"
    case ::PLAYER_IN_FLIGHT:                  return "PLAYER_IN_FLIGHT"
    case ::PLAYER_IN_RESPAWN:                 return "PLAYER_IN_RESPAWN"
    default:                                  return "" + state
  }
}

function isPlayerDedicatedSpectator(name = null)
{
  if (name)
  {
    local member = ::SessionLobby.isInRoom() ? ::SessionLobby.getMemberByName(name) : null
    return member ? !!::SessionLobby.getMemberPublicParam(member, "spectator") : false
  }
  return !!::getTblValue("spectator", ::get_local_mplayer() || {}, 0)
}

::spectator_air_hud_offset_x <- 0
function get_spectator_air_hud_offset_x() // called from client
{
  return ::spectator_air_hud_offset_x
}

function on_player_requested_artillery(userId) // called from client
{
  local handler = ::handlersManager.findHandlerClassInScene(::Spectator)
  if (handler)
    handler.onPlayerRequestedArtillery(userId)
}
