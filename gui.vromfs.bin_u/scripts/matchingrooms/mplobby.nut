mplobby_spawn_time <- 5.0 // this changes from native code when isMultiplayerDebug option enabled
::back_from_lobby <- ::gui_start_mainmenu

//::use_debug_fake_players <- false

function session_fill_info(scene, sessionInfo)
{
  if (!::checkObj(scene))
    return
  if (!sessionInfo)
    return ::session_clear_info(scene)

  local textSample = "<color=@activeTextColor>%s</color>%s"
  local setTextToObj = (@(textSample) function(obj, coloredText, value)
  {
    if (!::checkObj(obj))
      return

    if (::u.isBool(value))
      value = ::loc("options/" + (value ? "yes" : "no"))
    obj.setValue((!::u.isEmpty(value)) ? ::format(textSample, coloredText, value.tostring()) : "")
  })(textSample)
  local setTextToObjByOption = (@(setTextToObj, scene) function(objId, optionId, value)
  {
    local obj = scene.findObject(objId)
    if ( ! obj || ! ::checkObj(obj))
      return
    local option = ::get_option(optionId)
    local displayValue = option.getValueLocText(value)
    setTextToObj(obj, option.getTitle() + ::loc("ui/colon"), displayValue)
  })(setTextToObj, scene)

  local gm = ("gm" in sessionInfo)? sessionInfo.gm : ::GM_SKIRMISH
  local gt = ::SessionLobby.getGameType(sessionInfo)
  local missionInfo = ("mission" in sessionInfo)? sessionInfo.mission : {}
  local isEventRoom = ::SessionLobby.isInRoom() && ::SessionLobby.isEventRoom

  local nameObj = scene.findObject("session_creator")
  setTextToObj(nameObj, ::loc("multiplayer/game_host") + ::loc("ui/colon"), ::getTblValue("creator", sessionInfo, null))

  local teams = ::SessionLobby.getTeamsCountries(sessionInfo)
  local isEqual = teams.len() == 1 || ::u.isEqual(teams[0], teams[1])
  local cObj1 = scene.findObject("countries1")
  local cObj2 = scene.findObject("countries2")
  if (::checkObj(cObj1))
  {
    cObj1.show(true)
    fillCountriesList(cObj1, teams[0])
    cObj2.show(!isEqual)
    if (!isEqual)
      fillCountriesList(cObj2, teams[1])
  }
  local vsObj = scene.findObject("vsText")
  if (::checkObj(vsObj))
    vsObj.show(!isEqual)

  local mapNameObj = scene.findObject("session_mapName")
  if (::SessionLobby.isUserMission(sessionInfo))
    setTextToObj(mapNameObj, ::loc("options/mp_user_mission") + ::loc("ui/colon"), ::getTblValue("userMissionName", sessionInfo))
  else if (::SessionLobby.isUrlMission(sessionInfo))
  {
    local url = ::getTblValue("missionURL", sessionInfo, "")
    local urlMission =  ::g_url_missions.findMissionByUrl(url)
    local missionName = urlMission ? urlMission.name : url
    setTextToObj(mapNameObj, ::loc("urlMissions/sessionInfoHeader") + ::loc("ui/colon"), missionName)
  } else
    setTextToObj(mapNameObj, ::loc("options/mp_mission") + ::loc("ui/colon"), get_combine_loc_name_mission(missionInfo))

  local pasObj = scene.findObject("session_hasPassword")
  setTextToObj(pasObj ::loc("options/session_password") + ::loc("ui/colon"),
               isEventRoom ? null : ::getTblValue("hasPassword", sessionInfo, false))

  local tlObj = scene.findObject("session_teamLimit")
  local rangeData = ::events.getPlayersRangeTextData(::SessionLobby.getRoomEvent())
  setTextToObj(tlObj, rangeData.label + ::loc("ui/colon"),
               isEventRoom && rangeData.isValid ? rangeData.value : null)

  local craftsObj = scene.findObject("session_battleRating")
  local reqUnits = ::SessionLobby.getRequiredCratfs(Team.A, sessionInfo)
  setTextToObj(craftsObj, ::loc("events/required_crafts") + ::loc("ui/colon"), ::events.getRulesText(reqUnits))

  local envObj = scene.findObject("session_environment")
  local envTexts = []
  if ("weather" in missionInfo)
    envTexts.append(::loc("options/weather" + missionInfo.weather))
  if ("environment" in missionInfo)
    envTexts.append(::get_mission_time_text(missionInfo.environment))
  setTextToObj(envObj, ::loc("sm_conditions") + ::loc("ui/colon"), ::implode(envTexts, ", "))

  local difObj = scene.findObject("session_difficulty")
  local diff = ::getTblValue("difficulty", missionInfo)
  setTextToObj(difObj, ::loc("multiplayer/difficultyShort") + ::loc("ui/colon"), ::loc("options/" + diff))
  local diffTooltip = ""
  if (diff=="custom")
  {
    local custDiff = ::getTblValue("custDifficulty", missionInfo, null)
    if (custDiff)
      diffTooltip = ::get_custom_difficulty_tooltip_text(custDiff)
  }
  difObj.tooltip = diffTooltip


  local bObj = scene.findObject("session_laps")
  setTextToObj(bObj, ::loc("options/race_laps") + ::loc("ui/colon"),
               (gt & ::GT_RACE)? ::getTblValue("raceLaps", missionInfo) : null)
  local bObj = scene.findObject("session_winners")
  setTextToObj(bObj, ::loc("options/race_winners") + ::loc("ui/colon"),
               (gt & ::GT_RACE)? ::getTblValue("raceWinners", missionInfo) : null)
  local bObj = scene.findObject("session_can_shoot")
  setTextToObj(bObj, ::loc("options/race_can_shoot") + ::loc("ui/colon"),
               (gt & ::GT_RACE)? !::getTblValue("raceForceCannotShoot", missionInfo, false) : null)

  setTextToObjByOption("session_timeLimit", ::USEROPT_TIME_LIMIT, ::getTblValue("timeLimit", missionInfo, 0))

  setTextToObjByOption("limited_fuel", ::USEROPT_LIMITED_FUEL, ::getTblValue("isLimitedFuel", missionInfo))
  setTextToObjByOption("limited_ammo", ::USEROPT_LIMITED_AMMO, ::getTblValue("isLimitedAmmo", missionInfo))

  setTextToObjByOption("session_respawn", ::USEROPT_VERSUS_RESPAWN, ::getTblValue("maxRespawns", missionInfo, -1))

  local tObj = scene.findObject("session_takeoff")
  setTextToObj(tObj, ::loc("options/optional_takeoff") + ::loc("ui/colon"),
               ::getTblValue("optionalTakeOff", missionInfo, false))

  setTextToObjByOption("session_allowbots", ::USEROPT_IS_BOTS_ALLOWED,
               (gt & ::GT_RACE)? null : ::getTblValue("isBotsAllowed", missionInfo))
  setTextToObjByOption("session_botsranks", ::USEROPT_BOTS_RANKS,
               (gt & ::GT_RACE)? null : ::getTblValue("ranks", missionInfo))

  local bObj = scene.findObject("session_jip")
  setTextToObj(bObj, ::loc("options/allow_jip") + ::loc("ui/colon"),
               ::getTblValue("allowJIP", sessionInfo, true))

  setTextToObjByOption("session_cluster", ::USEROPT_CLUSTER, ::getTblValue("cluster", sessionInfo))

  setTextToObjByOption("disable_airfields", ::USEROPT_DISABLE_AIRFIELDS, ::getTblValue("disableAirfields", missionInfo))

  setTextToObjByOption("spawn_ai_tank_on_tank_maps", ::USEROPT_SPAWN_AI_TANK_ON_TANK_MAPS, ::getTblValue("spawnAiTankOnTankMaps", missionInfo))

}

function session_clear_info(scene)
{
  foreach (name in ["session_creator", "session_mapName", "session_hasPassword",
                    "session_environment", "session_difficulty", "session_timeLimit",
                    "session_limits", "session_respawn", "session_takeoff",
                    "session_allowbots", "session_botsranks", "session_jip",
                    "limited_fuel", "limited_ammo"])
  {
    local obj = scene.findObject(name)
    if (::checkObj(obj)) obj.setValue("")
  }
  foreach (name in ["countries1", "vsText", "countries2"])
  {
    local obj = scene.findObject(name)
    if (::checkObj(obj)) obj.show(false)
  }
}

function set_mplayer_info(scene, player, is_team, teamCountry=false)
{
  local teamObj = scene.findObject("player_team")
  if (is_team && ::checkObj(teamObj))
  {
    local teamTxt = ""
    local team = player? player.team : Team.Any
    if (team == Team.A)
      teamTxt = ::loc("multiplayer/teamA")
    else if (team == Team.B)
      teamTxt = ::loc("multiplayer/teamB")
    else
      teamTxt = ::loc("multiplayer/teamRandom")
    teamObj.setValue(::loc("multiplayer/team") + ::loc("ui/colon") + teamTxt)
  }

  ::fill_gamer_card({
                    name = player? player.name : ""
                    clanTag = player? player.clanTag : ""
                    icon = (!player || player.isBot)? "cardicon_bot" : ::get_pilot_icon_by_id(player.pilotId)
                    country = player? player.country : ""
                  },
                  true, "player_", scene)
}

function updateCurrentPlayerInfo(handler, scene, playerInfo, unitParams = null)
{
  local mainObj = scene.findObject("player_info")
  if (!::checkObj(mainObj) || !playerInfo)
    return

  local guiScene = scene.getScene()
  local playerNick = playerInfo.name
  local playerClan = playerInfo.clanTag + (playerInfo.clanTag != ""? " " : "")
  local playerName = playerClan + playerNick
  local playerCountry = "country" in playerInfo? playerInfo.country : ""
  local playerIcon = (!playerInfo || playerInfo.isBot)? "cardicon_bot" : ::get_pilot_icon_by_id(playerInfo.pilotId)

  local titleObj = mainObj.findObject("player_title")
  if (::checkObj(titleObj))
    titleObj.setValue((playerInfo.title != "") ? (::loc("title/title") + ::loc("ui/colon") + ::loc("title/" + playerInfo.title)) : "")

  local spectatorObj = mainObj.findObject("player_spectator")
  if (::checkObj(spectatorObj))
  {
    local desc = ::getPlayerStateDesc(playerInfo)
    spectatorObj.setValue((desc != "") ? (::loc("multiplayer/state") + ::loc("ui/colon") + desc) : "")
  }

  local myTeam = (::SessionLobby.status == lobbyStates.IN_LOBBY)? ::SessionLobby.team : ::get_mp_local_team()
  mainObj.playerTeam = myTeam==Team.A? "a" : (myTeam == Team.B? "b" : "")

  local teamObj = mainObj.findObject("player_team")
  if (::checkObj(teamObj))
  {
    local teamTxt = ""
    local teamStyle = ""
    local team = playerInfo? playerInfo.team : Team.Any
    if (team == Team.A)
    {
      teamStyle = "a"
      teamTxt = ::loc("multiplayer/teamA")
    }
    else if (team == Team.B)
    {
      teamStyle = "b"
      teamTxt = ::loc("multiplayer/teamB")
    }

    teamObj.team = teamStyle
    if (teamTxt != "")
    {
      local teamIcoObj = teamObj.findObject("player_team_ico")
      teamIcoObj.tooltip = ::loc("multiplayer/team") + ::loc("ui/colon") + teamTxt
    }
  }

  ::fill_gamer_card({
                    name = playerNick
                    clanTag = playerClan
                    icon = playerIcon
                    country = playerCountry
                  },
                  true, "player_", mainObj)

  local airObj = mainObj.findObject("curAircraft")
  if (!::checkObj(airObj))
    return

  local showAirItem = ::SessionLobby.getMissionParam("maxRespawns", -1) == 1 && playerInfo.country && playerInfo.selAirs.len() > 0
  airObj.show(showAirItem)

  if (showAirItem)
  {
    local airName = ::getTblValue(playerInfo.country, playerInfo.selAirs, "")
    local air = getAircraftByName(airName)
    if (!air)
    {
      airObj.show(false)
      return
    }
    local existingAirObj = airObj.findObject("curAircraft_place")
    if (::checkObj(existingAirObj))
      guiScene.destroyElement(existingAirObj)

    local params = clone unitParams
    params.status <- ::getUnitItemStatusText(bit_unit_status.owned)
    local data = ::build_aircraft_item(airName, air, params)
    data = "tdiv { id:t='curAircraft_place'; class:t='rankUpList';" + data + "}"
    guiScene.appendWithBlk(airObj, data, handler)
    ::fill_unit_item_timers(airObj.findObject(airName), air)
  }
}

enum SessionStatus
{
  READY_TO_GO,
  NOT_ENOUGH_PLAYERS,
  TOO_FEW_A,
  TOO_FEW_B
}

function session_player_rmenu(handler, player, chatText = "", position = null)
{
  if (!player || player.isBot || !("userId" in player) || !::g_login.isLoggedIn())
      return

  local name = player.name
  local clanTag = player.clanTag
  local isMe = player.isLocal
  local uid = player.userId
  local isFriend = ::isPlayerInFriendsGroup(uid)
  local isBlock = ::isPlayerInContacts(uid, ::EPL_BLOCKLIST)
  local owner = ::SessionLobby.isRoomOwner

  local menu =[
    {
      text = ::loc("contacts/message")
      show = !isMe
      action = (@(name) function() {
        if ("changePrivateTo" in this)
          changePrivateTo(name)
        else
          ::openChatPrivate(name, this)
      })(name)
    }
    {
      text = ::loc("mainmenu/btnUserCard")
      action = (@(name, uid) function() { ::gui_modal_userCard({ name = name, uid = uid }) })(name, uid)
    }

    {
      text = ::loc("contacts/friendlist/add")
      show = !isMe && !isFriend && !isBlock
      action = (@(name, uid) function() { ::editContactMsgBox({uid = uid, name = name}, ::EPL_FRIENDLIST, true, this) })(name, uid)
    }
    {
      text = ::loc("contacts/friendlist/remove")
      show = isFriend
      action = (@(name, uid) function() { ::editContactMsgBox({uid = uid, name = name}, ::EPL_FRIENDLIST, false, this) })(name, uid)
    }
    {
      text = ::loc("contacts/blacklist/add")
      show = !isMe && !isFriend && !isBlock
      action = (@(name, uid) function() { ::editContactMsgBox({uid = uid, name = name}, ::EPL_BLOCKLIST, true, this) })(name, uid)
    }
    {
      text = ::loc("contacts/blacklist/remove")
      show = isBlock
      action = (@(name, uid) function() { ::editContactMsgBox({uid = uid, name = name}, ::EPL_BLOCKLIST, false, this) })(name, uid)
    }
    //{}
    {
      text = ::loc("mainmenu/btnComplain")
      show = !isMe
      action = (@(player, chatText) function() {
        ::gui_modal_complain(player, chatText)
      })(player, chatText)
    }
    {
      text = ::loc("mainmenu/btnKick")
      show = !isMe && owner
      action = (@(player) function() { ::SessionLobby.kickPlayer(::SessionLobby.getMemberByName(player.name)) })(player)
    }
    {
      text = ::loc("contacts/moderator_copyname")
      show = ::is_myself_moderator() || ::is_myself_chat_moderator()
      action = (@(name) function() { ::copy_to_clipboard(name) })(name)
    }
    {
      text = ::loc("contacts/moderator_ban")
      show = ::myself_can_devoice() || ::myself_can_ban()
      action = (@(uid, clanTag, name, chatText) function() {
        ::gui_modal_ban({ uid = uid, name = name, clanTag = clanTag }, chatText? chatText : "")
      })(uid, clanTag, name, chatText)
    }
  ]
  ::gui_right_click_menu(menu, handler, position)
}

function gui_start_mp_lobby(next_mission = false)
{
  if (::SessionLobby.status != lobbyStates.IN_LOBBY)
  {
    ::back_from_lobby()
    return
  }

  if (::SessionLobby.getGameMode() == ::GM_SKIRMISH && !::g_missions_manager.isRemoteMission)
    ::back_from_lobby = ::gui_start_skirmish
  else
    ::back_from_lobby = ::gui_start_mainmenu

  ::g_missions_manager.isRemoteMission = false
  ::handlersManager.loadHandler(::gui_handlers.MPLobby, { backSceneFunc = ::back_from_lobby })
}

function gui_start_mp_lobby_next_mission()
{
  gui_start_mp_lobby(true);
}

class ::gui_handlers.MPLobby extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName = "gui/mpLobby.blk"

  tblData = null
  tblMarkupData = null

  haveUnreadyButton = false
  waitBox = null
  spawnTime = mplobby_spawn_time
  curStatus = -1
  optionsBox = null
  curGMmode = -1
  slotbarActions = ["autorefill", "aircraft", "crew", "weapons", "rankinfo", "repair"]

  tableTeams = null
  playersInTeamTables = null
  focusedTeam = ::g_team.ANY
  isTablesInUpdate = false
  isInfoByTeams = false

  isTimerVisible = false

  static TEAM_TBL_PREFIX = "players_table_"

  function initScreen()
  {
    if (!::SessionLobby.isInRoom())
      return

    curGMmode = ::SessionLobby.getGameMode()
    ::set_gui_options_mode(::get_options_mode(curGMmode))

    scene.findObject("mplobby_update").setUserData(this)

    if (::SessionLobby.isEventRoom)
    {
      tableTeams = [::g_team.A, ::g_team.B]
      isInfoByTeams = true
    }
    else
      tableTeams = [::g_team.ANY]
    focusedTeam = tableTeams[0]
    playersInTeamTables = {}
    initPlayersTbl()

    if (!::SessionLobby.getPublicParam("symmetricTeams", true))
      ::SessionLobby.setTeam(::SessionLobby.getRandomTeam(), true)

    updateSessionInfo()
    updatePlayersTbl()
    ::init_slotbar(this, scene.findObject("nav-help"))
    setSceneTitle(::loc("multiplayer/lobby"))
    updateButtons()
    updateRoomInSession()

    initChat()
    initFocusArray()
    local sessionInfo = ::SessionLobby.getSessionInfo()
    ::update_vehicle_info_button(scene, sessionInfo)
  }

  function getMainFocusObj()
  {
    return getFocusedTeamTableObj()
  }

  function getMainFocusObj2()
  {
    local chatPlace = getObj("lobby_chat_place")
    return ::checkObj(chatPlace)? ::getCustomObjEditbox(chatPlace) : null
  }

  function initChat()
  {
    if (!::ps4_is_chat_enabled())
      return

    local chatObj = scene.findObject("lobby_chat_place")
    if (::checkObj(chatObj))
      ::joinCustomObjRoom(chatObj, ::SessionLobby.getChatRoomId(), ::SessionLobby.getChatRoomPassword(), this)

    restoreFocus()
  }

  function updateSessionInfo()
  {
    local mpMode = ::SessionLobby.getGameMode()
    if (curGMmode != mpMode)
    {
      curGMmode = mpMode
      ::set_mp_mode(curGMmode)
      ::set_gui_options_mode(::get_options_mode(curGMmode))
    }

    ::session_fill_info(scene, ::SessionLobby.getSessionInfo())
  }

  function getTeamTableId(team)
  {
    return TEAM_TBL_PREFIX + team.id
  }

  function initPlayersTbl()
  {
    local tablesView = {
      teamsAmount = tableTeams.len()
      teams = []
    }

    tblData = ["team", "country", "name"]
    local membersInfoList = ::SessionLobby.getMembersInfoList()
    local nameWidth = "(pw - 2*@tablePad -2*ph)"
    local markupData = {
      tr_size = "pw, @baseTrHeight"
      name = {width = nameWidth, readyIcon = true}
    }
    foreach(idx, team in tableTeams)
    {
      markupData.invert <- idx == 0 && tableTeams.len() == 2
      tablesView.teams.append(
      {
        isFirst = idx == 0
        tableId = getTeamTableId(team)
        content = ::build_mp_table(membersInfoList, markupData, tblData, ::SessionLobby.getMaxMembersCount())
      })
    }
    local data = ::handyman.renderCached("gui/mpLobbyTables", tablesView)
    guiScene.replaceContentFromText(scene.findObject("players_tables_place"), data, data.len(), this)
  }

  function updatePlayersTbl()
  {
    isTablesInUpdate = true
    local playersList = ::SessionLobby.getMembersInfoList()
    foreach(team in tableTeams)
      updateTeamPlayersTbl(team, playersList)
    isTablesInUpdate = false

    updateTableHeader()
    refreshPlayerInfo()
    updateSessionStatus()
  }

  function updateTableHeader()
  {
    local commonHeader = showSceneBtn("common_list_header", !isInfoByTeams)
    local byTeamsHeader = showSceneBtn("list_by_teams_header", isInfoByTeams)
    local teamsNest = isInfoByTeams ? byTeamsHeader : commonHeader.findObject("num_teams")

    local maxMembers = ::SessionLobby.getMaxMembersCount()
    local countTbl = ::SessionLobby.getMembersCountByTeams()
    local countTblReady = ::SessionLobby.getMembersCountByTeams(null, true)
    if (!isInfoByTeams)
    {
      local totalNumPlayersTxt = ::loc("multiplayer/playerList")
        + ::loc("ui/parentheses/space", { text = countTbl.total + "/" + maxMembers })
      commonHeader.findObject("num_players").setValue(totalNumPlayersTxt)
    }

    local event = ::SessionLobby.getRoomEvent()
    foreach(team in tableTeams)
    {
      local teamObj = teamsNest.findObject("num_team" + team.id)
      if (!::check_obj(teamObj))
        continue

      local text = ""
      if (isInfoByTeams && event)
      {
        local locId = "multiplayer/teamPlayers"
        local locParams = {
          players = countTblReady[team.code]
          maxPlayers = ::events.getMaxTeamSize(event)
          unready = countTbl[team.code] - countTblReady[team.code]
        }
        if (locParams.unready)
          locId = "multiplayer/teamPlayers/hasUnready"
        text = ::loc(locId, locParams)
      }
      teamObj.setValue(text)
    }

    ::update_team_css_label(teamsNest)
  }

  function updateTeamPlayersTbl(team, playersList)
  {
    local objTbl = scene.findObject(getTeamTableId(team))
    if (!::checkObj(objTbl))
      return

    local totalRows = objTbl.childrenCount()
    local teamList = team == ::g_team.ANY ? playersList
      : ::u.filter(playersList, (@(team) function(p) { return p.team.tointeger() == team.code })(team))
    ::set_mp_table(objTbl, teamList, { max_rows = totalRows })
    ::update_team_css_label(objTbl)

    for(local i = 0; i < totalRows; i++)
      objTbl.getChild(i).show(i < teamList.len())
    playersInTeamTables[team] <- teamList

    //update cur value
    if (teamList.len())
    {
      local curValue = objTbl.getValue()
      local validValue = ::clamp(curValue, 0, teamList.len())
      if (curValue != validValue)
        objTbl.setValue(validValue)
    }
  }

  function updateRoomInSession()
  {
    if (::checkObj(scene))
      scene.findObject("battle_in_progress").wink = ::SessionLobby.roomInSession? "yes" : "no"
    updateTimerInfo()
  }

  function onEventLobbyMembersChanged(p)
  {
    updatePlayersTbl()
    updateButtons()
  }

  function onEventLobbyMemberInfoChanged(p)
  {
    updatePlayersTbl()
    updateButtons()
  }

  function onEventLobbySettingsChange(p)
  {
    updateSessionInfo()
    updatePlayersTbl()
    reinitSlotbar()
    updateButtons()
    updateTimerInfo()
  }

  function onEventLobbyRoomInSession(p)
  {
    updateRoomInSession()
    updateButtons()
  }

  function getFocusedTeamTableObj()
  {
    return getObj(getTeamTableId(focusedTeam))
  }

  function updateFocusedTeamByObj(obj)
  {
    focusedTeam = ::getTblValue(::getObjIdByPrefix(obj, TEAM_TBL_PREFIX), ::g_team, focusedTeam)
  }

  function getSelectedRowPos()
  {
    local objTbl = getFocusedTeamTableObj()
    if(!objTbl)
      return null
    local rowNum = objTbl.getValue()
    if (rowNum < 0 || rowNum > objTbl.childrenCount())
      return null
    local rowObj = objTbl.getChild(rowNum)
    local topLeftCorner = rowObj.getPosRC()
    return [topLeftCorner[0], topLeftCorner[1] + rowObj.getSize()[1]]
  }

  function getSelectedPlayer()
  {
    local objTbl = getFocusedTeamTableObj()
    return objTbl && ::getTblValue(objTbl.getValue(), ::getTblValue(focusedTeam, playersInTeamTables))
  }

  function refreshPlayerInfo()
  {
    if (!::checkObj(scene))
      return

    local player = getSelectedPlayer()
    ::updateCurrentPlayerInfo(this, scene, player, { getEdiffFunc = getCurrentEdiff.bindenv(this) })
    showSceneBtn("btn_usercard", player != null && !::show_console_buttons)
    showSceneBtn("btn_user_options", player != null && ::show_console_buttons)
  }

  function onPlayerSelect(obj)
  {
    if (isTablesInUpdate)
      return
    updateFocusedTeamByObj(obj)
    refreshPlayerInfo()
  }

  function onPlayersWrapRight(obj) { wrapFocusedTeam(1) }
  function onPlayersWrapLeft(obj)  { wrapFocusedTeam(-1) }

  function wrapFocusedTeam(dir)
  {
    local newFocusedTeamIdx = ::find_in_array(tableTeams, focusedTeam, 0) + dir
    local newFocusedTeam = ::getTblValue(newFocusedTeamIdx, tableTeams, focusedTeam)
    if (newFocusedTeam == focusedTeam)
      return
    local newTeamObj = getObj(getTeamTableId(newFocusedTeam))
    if (!newTeamObj)
      return

    focusedTeam = newFocusedTeam
    newTeamObj.select()
    refreshPlayerInfo()
  }

  function getMyTeamDisbalanceMsg(isFullText = false)
  {
    local countTbl = ::SessionLobby.getMembersCountByTeams(null, true)
    local maxDisbalance = ::SessionLobby.getMaxDisbalance()
    local myTeam = ::SessionLobby.team
    if (myTeam != Team.A && myTeam != Team.B)
      return ""

    local otherTeam = ::g_team.getTeamByCode(myTeam).opponentTeamCode
    if (countTbl[myTeam] - maxDisbalance < countTbl[otherTeam])
      return ""

    local params = {
      chosenTeam = ::colorize("teamBlueColor", ::g_team.getTeamByCode(myTeam).getShortName())
      otherTeam =  ::colorize("teamRedColor", ::g_team.getTeamByCode(otherTeam).getShortName())
      chosenTeamCount = countTbl[myTeam]
      otherTeamCount =  countTbl[otherTeam]
      reqOtherteamCount = countTbl[myTeam] - maxDisbalance + 1
    }
    local locKey = "multiplayer/enemyTeamTooLowMembers" + (isFullText ? "" : "/short")
    return ::loc(locKey, params)
  }

  function getReadyData()
  {
    local res = {
      readyBtnText = ""
      readyBtnHint = ""
      isVisualDisabled = false
    }

    if (!::SessionLobby.isUserCanChangeReady() && !::SessionLobby.hasSessionInLobby())
      return res

    local isReady = ::SessionLobby.hasSessionInLobby() ? ::SessionLobby.isInLobbySession : ::SessionLobby.isReady
    if (::SessionLobby.canStartSession() && isReady)
      res.readyBtnText = ::loc("multiplayer/btnStart")
    else if (::SessionLobby.roomInSession)
    {
      res.readyBtnText = ::loc("mainmenu/toBattle")
      res.isVisualDisabled = !::SessionLobby.canJoinSession()
    } else if (!isReady)
      res.readyBtnText = ::loc("mainmenu/btnReady")

    if (!isReady && ::SessionLobby.isEventRoom && ::SessionLobby.roomInSession)
    {
      res.readyBtnHint = getMyTeamDisbalanceMsg()
      res.isVisualDisabled = res.readyBtnHint.len() > 0
    }
    return res
  }

  function updateButtons()
  {
    local readyData = getReadyData()
    local readyBtn = showSceneBtn("btn_ready", readyData.readyBtnText.len())
    ::setDoubleTextToButton(scene, "btn_ready", readyData.readyBtnText)
    readyBtn.inactiveColor = readyData.isVisualDisabled ? "yes" : "no"
    scene.findObject("cant_ready_reason").setValue(readyData.readyBtnHint)

    local spectatorBtnObj = scene.findObject("btn_spectator")
    if (::checkObj(spectatorBtnObj))
    {
      local isSpectator = ::SessionLobby.spectator
      local buttonText = ::loc("mainmenu/btnReferee")
        + (isSpectator ? (::loc("ui/colon") + ::loc("options/on")) : "")
      spectatorBtnObj.setValue(buttonText)
      spectatorBtnObj.active = isSpectator ? "yes" : "no"
    }

    local isReady = ::SessionLobby.isReady
    showSceneBtn("btn_not_ready", ::SessionLobby.isUserCanChangeReady() && isReady)
    showSceneBtn("btn_ses_settings", ::SessionLobby.canChangeSettings())
    showSceneBtn("btn_team", !isReady && ::SessionLobby.canChangeTeam())
    showSceneBtn("btn_spectator", !isReady && ::SessionLobby.canBeSpectator()
      && !::SessionLobby.isSpectatorSelectLocked)
  }

  function getCurrentEdiff()
  {
    local ediff = ::SessionLobby.getCurRoomEdiff()
    return ediff != -1 ? ediff : ::get_current_ediff()
  }

  function onEventLobbyMyInfoChanged(params)
  {
    updateButtons()
    if ("team" in params)
      guiScene.performDelayed(this, function () {
        reinitSlotbar()
      })
  }

  function onEventLobbyReadyChanged(p)
  {
    updateButtons()
  }

  function updateSessionStatus()
  {
    local needSessionStatus = !isInfoByTeams && !::SessionLobby.roomInSession
    local sessionStatusObj = showSceneBtn("session_status", needSessionStatus)
    if (needSessionStatus)
      sessionStatusObj.setValue(::SessionLobby.getMembersReadyStatus().statusText)

    local event = ::SessionLobby.getRoomEvent()
    local needTeamStatus = isInfoByTeams && !::SessionLobby.roomInSession && !!event
    foreach(idx, team in tableTeams)
    {
      local teamObj = showSceneBtn("team_status_" + team.id, needTeamStatus)
      if (!teamObj || !needTeamStatus)
        continue

      local status = ""
      local minSize = ::events.getMinTeamSize(event)
      local teamSize = getPlayersAmountByTeam(team)
      if (teamSize < minSize)
        status = ::loc("multiplayer/playersTeamLessThanMin", { minSize = minSize })
      else
      {
        local maxDisbalance = ::SessionLobby.getMaxDisbalance()
        local otherTeamSize = getPlayersAmountByTeam(tableTeams[1 - idx])
        if (teamSize - maxDisbalance > ::max(otherTeamSize, minSize))
          status = ::loc("multiplayer/playersTeamDisbalance", { maxDisbalance = maxDisbalance })
      }
      teamObj.setValue(status)
    }
  }

  function getPlayersAmountByTeam(team)
  {
    local list = ::getTblValue(team, playersInTeamTables)
    return list ? list.len() : 0
  }

  function updateTimerInfo()
  {
    local timers = ::SessionLobby.getRoomActiveTimers()
    local isVisibleNow = timers.len() > 0 && !::SessionLobby.roomInSession
    if (!isVisibleNow && !isTimerVisible)
      return

    isTimerVisible = isVisibleNow
    local timerObj = showSceneBtn("battle_start_countdown", isTimerVisible)
    if (timerObj && isTimerVisible)
      timerObj.setValue(timers[0].text)
  }

  function onUpdate(obj, dt)
  {
    updateTimerInfo()
  }

  function onKick(obj)
  {
    local player = getSelectedPlayer()
    if (player)
      ::SessionLobby.kickPlayer(player)
  }

  function getLogText()
  {
    return "" //!!FIX ME
  }

  function onComplain(obj)
  {
    local player = getSelectedPlayer()
    if (player && !player.isBot && !player.isLocal)
      ::gui_modal_complain({uid = player.userId, name = player.name }, getLogText())
  }

  function onUserCard(obj)
  {
    local player = getSelectedPlayer()
    if (player && !player.isBot)
      ::gui_modal_userCard({ name = player.name, uid = player.userId });
  }

  function onUserRClick(obj)
  {
    session_player_rmenu(this, getSelectedPlayer(), getLogText())
  }

  function onUserOption(obj)
  {
    session_player_rmenu(this, getSelectedPlayer(), getLogText(), getSelectedRowPos())
  }

  function onSessionSettings()
  {
    if (!::SessionLobby.isRoomOwner)
      return

    if (::SessionLobby.isReady)
    {
      msgBox("cannot_options_on_ready", ::loc("multiplayer/cannotOptionsOnReady"),
        [["ok", function() {}]], "ok", {cancel_fn = function() {}})
      return
    }

    if (::SessionLobby.roomInSession)
    {
      msgBox("cannot_options_on_ready", ::loc("multiplayer/cannotOptionsWhileInBattle"),
        [["ok", function() {}]], "ok", {cancel_fn = function() {}})
      return
    }

    //local gm = ::SessionLobby.getGameMode()
    //if (gm == ::GM_SKIRMISH)
    ::gui_start_mislist(true, ::get_mp_mode())
  }

  function onSpectator(obj)
  {
    ::SessionLobby.switchSpectator()
  }

  function onTeam(obj)
  {
    local isSymmetric = ::SessionLobby.getPublicParam("symmetricTeams", true)
    ::SessionLobby.switchTeam(!isSymmetric)
  }

  function onPlayers(obj)
  {
  }

  function doQuit()
  {
    SessionLobby.leaveRoom()
  }

  function onEventLobbyStatusChange(params)
  {
    if (!::SessionLobby.isInRoom())
      goBack()
    else
      updateButtons()
  }

  function onNotReady()
  {
    if (::SessionLobby.isReady)
      ::SessionLobby.setReady(false)
  }

  function onCancel()
  {
    msgBox("ask_leave_lobby", ::loc("flightmenu/questionQuitGame"),
    [
      ["yes", doQuit],
      ["no", function() { }]
    ], "no", { cancel_fn = function() {}})
  }

  function onReady()
  {
    if (::SessionLobby.tryJoinSession())
      return

    if (!::SessionLobby.isRoomOwner || !::SessionLobby.isReady)
      return ::SessionLobby.setReady(true)

    local status = ::SessionLobby.getMembersReadyStatus()
    if (status.readyToStart)
      return ::SessionLobby.startSession()

    local msg = status.statusText
    local buttons = [["ok", function() {}]]
    local defButton = "ok"
    if (status.ableToStart)
    {
      buttons = [["#multiplayer/btnStart", function() { ::SessionLobby.startSession() }], ["cancel", function() {}]]
      defButton = "cancel"
      msg += "\n" + ::loc("ask/startGameAnyway")
    }

    msgBox("ask_start_session", msg, buttons, defButton, { cancel_fn = function() {}})
  }

  function onCustomChatCancel()
  {
    onCancel()
  }

  function onCustomChatContinue()
  {
    onReady()
  }

  function canPresetChange()
  {
    return true
  }

  function onVehiclesInfo(obj)
  {
    ::gui_start_modal_wnd(::gui_handlers.VehiclesWindow, {
      teamDataByTeamName = ::SessionLobby.getSessionInfo()
      roomSpecialRules = ::SessionLobby.getRoomSpecialRules()
    })
  }
}

function gui_modal_joiningGame()
{
  ::gui_start_modal_wnd(::gui_handlers.JoiningGame)
}

class ::gui_handlers.JoiningGame extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/msgBox.blk"
  timeToShowCancel = 30
  timer = -1

  function initScreen()
  {
    scene.findObject("msgWaitAnimation").show(true)
    scene.findObject("msg_box_timer").setUserData(this)
    updateInfo()
  }

  function onEventLobbyStatusChange(params)
  {
    updateInfo()
  }

  function onEventEventsDataUpdated(params)
  {
    updateInfo()
  }

  function updateInfo()
  {
    if (!::SessionLobby.needJoiningWnd())
      return goBack()

    resetTimer() //statusChanged
    checkGameMode()

    local misData = ::SessionLobby.getMissionParams()
    local msg = ::loc("wait/sessionJoin")
    if (::SessionLobby.status == lobbyStates.UPLOAD_CONTENT)
      msg = ::loc("wait/sessionUpload")
    if (misData)
    {
      msg += "\n\n" + ::colorize("activeTextColor", getCurrentMissionGameMode())
      msg += "\n" + ::colorize("userlogColoredText", getCurrentMissionName())
    }
    scene.findObject("msgText").setValue(msg)
  }

  function getCurrentMissionGameMode()
  {
    local gameModeName = ::get_cur_game_mode_name()
    if (gameModeName == "domination")
    {
      local event = ::SessionLobby.getRoomEvent()
      if (event == null ||
          ::Events.getEventDisplayType(event) != ::g_event_display_type.RANDOM_BATTLE)
        gameModeName = "event"
    }
    return ::loc("multiplayer/" + gameModeName + "Mode")
  }

  function getCurrentMissionName()
  {
    if (::get_game_mode() == ::GM_DOMINATION)
    {
      local event = ::SessionLobby.getRoomEvent()
      if (event)
        return ::events.getEventNameText(event)
    }
    else
    {
      local misName = ::SessionLobby.getMissionNameLoc()
      if (misName != "")
        return misName
    }
    return ""
  }

  function checkGameMode()
  {
    local gm = ::SessionLobby.getGameMode()
    local curGm = ::get_game_mode()
    if (gm < 0 || curGm==gm)
      return

    ::set_mp_mode(gm)
    if (mainGameMode < 0)
      mainGameMode = curGm  //to restore gameMode after close window
  }

  function showCancelButton(show)
  {
    local btnId = "btn_cancel"
    local obj = scene.findObject(btnId)
    if (obj)
    {
      obj.show(show)
      obj.enable(show)
      if (show)
        obj.select()
      return
    }
    if (!show)
      return

    local data = format("dialog_button { id:t='%s'; btnName:t='AB'; text:t='#msgbox/btn_cancel'; on_click:t='onCancel' }", btnId)
    local holderObj = scene.findObject("buttons_holder")
    if (!holderObj)
      return

    guiScene.appendWithBlk(holderObj, data, this)
    obj = scene.findObject(btnId)
    obj.select()
  }

  function resetTimer()
  {
    timer = timeToShowCancel
    showCancelButton(false)
  }

  function onUpdate(obj, dt)
  {
    if (timer < 0)
      return
    timer -= dt
    if (timer < 0)
      showCancelButton(true)
  }

  function onCancel()
  {
    guiScene.performDelayed(this, function()
    {
      if (timer >= 0)
        return
      ::destroy_session_scripted()
      ::SessionLobby.leaveRoom()
    })
  }
}
