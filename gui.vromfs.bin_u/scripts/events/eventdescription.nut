local SecondsUpdater = require("sqDagui/timer/secondsUpdater.nut")
local time = require("scripts/time.nut")
local platformModule = require("modules/platform.nut")

function create_event_description(parent_scene, event = null, needEventHeader = true)
{
  local containerObj = parent_scene.findObject("item_desc")
  if (!::checkObj(containerObj))
    return null
  local params = {
    scene = containerObj
    selectedEvent = event
    needEventHeader = needEventHeader
  }
  local handler = ::handlersManager.loadHandler(::gui_handlers.EventDescription, params)
  return handler
}

class ::gui_handlers.EventDescription extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = "gui/empty.blk"

  selectedEvent = null
  room = null
  needEventHeader = true

  playersInTable = null
  currentFullRoomData = null

  // Most recent request for short leaderboards.
  newSelfRowRequest = null

  function initScreen()
  {
    playersInTable = []
    local blk = ::handyman.renderCached("gui/events/eventDescription", {})
    guiScene.replaceContentFromText(scene, blk, blk.len(), this)
    updateContent()
  }

  function selectEvent(event, eventRoom = null)
  {
    if (room)
      ::g_mroom_info.get(room.roomId).checkRefresh()
    if (selectedEvent == event && ::u.isEqual(room, eventRoom))
      return

    selectedEvent = event
    room = eventRoom
    updateContent()
  }

  function updateContent()
  {
    if (!::checkObj(scene))
      return

    guiScene.setUpdatesEnabled(false, false)
    _updateContent()
    guiScene.setUpdatesEnabled(true, true)
  }

  function _updateContent()
  {
    currentFullRoomData = getFullRoomData()
    if (selectedEvent == null)
    {
      setEventDescObjVisible(false)
      return
    }

    setEventDescObjVisible(true)

    if (needEventHeader)
      updateContentHeader()

    local roomMGM = ::events.getMGameMode(selectedEvent, room)

    local eventDescTextObj = getObject("event_desc_text")
    if (eventDescTextObj != null)
      eventDescTextObj.setValue(::events.getEventDescriptionText(selectedEvent, room))

    // Event difficulty
    local eventDifficultyObj = getObject("event_difficulty")
    if (eventDifficultyObj != null)
    {
      local difficultyText = ::events.isDifficultyCustom(selectedEvent)
        ? ::loc("options/custom")
        : ::events.getDifficultyText(selectedEvent.name)
      local respawnText = ::events.getRespawnsText(selectedEvent)
      eventDifficultyObj.text = ::format(" %s %s", difficultyText, respawnText)
    }

    // Event players range
    local eventPlayersRangeObj = getObject("event_players_range")
    if (eventPlayersRangeObj != null)
    {
      local rangeData = ::events.getPlayersRangeTextData(roomMGM)
      eventPlayersRangeObj.show(rangeData.isValid)
      if (rangeData.isValid)
      {
        local labelObj = getObject("event_players_range_label")
        if (labelObj != null)
          labelObj.setValue(rangeData.label)
        local valueObj = getObject("event_players_range_text")
        if (valueObj != null)
          valueObj.setValue(rangeData.value)
      }
    }

    // Clan info
    local clanOnlyInfoObj = getObject("clan_event")
    if(clanOnlyInfoObj != null)
      clanOnlyInfoObj.show(::events.isEventForClan(selectedEvent))

    // Allow switch clan
    local allowSwitchClanObj = getObject("allow_switch_clan")
    if (allowSwitchClanObj != null)
    {
      local eventType = ::getTblValue("type", selectedEvent, 0)
      local clanTournamentType = EVENT_TYPE.TOURNAMENT | EVENT_TYPE.CLAN
      local showMessage = (eventType & clanTournamentType) == clanTournamentType
      allowSwitchClanObj.show(showMessage)
      if (showMessage)
      {
        local locId = "events/allowSwitchClan/" + ::events.isEventAllowSwitchClan(selectedEvent).tostring()
        allowSwitchClanObj.text = ::loc(locId)
      }
    }

    // Timer
    local timerObj = getObject("event_time")
    if (timerObj != null)
    {
        SecondsUpdater(timerObj, ::Callback(function(obj, params)
        {
          local text = getDescriptionTimeText()
          obj.setValue(text)
          return text.len() == 0
        }, this))
    }

    local timeLimitObj = showSceneBtn("event_time_limit", !!room)
    if (timeLimitObj && room)
    {
      local timeLimit = ::SessionLobby.getTimeLimit(room)
      local timeText = ""
      if (timeLimit > 0)
      {
        local option = ::get_option(::USEROPT_TIME_LIMIT)
        timeText = option.getTitle() + ::loc("ui/colon") + option.getValueLocText(timeLimit)
      }
      timeLimitObj.setValue(timeText)
    }

    showSceneBtn("players_list_btn", !!room)

    // Fill vehicle lists
    local teamObj = null
    local sides = ::events.getSidesList(roomMGM)
    foreach(team in ::events.getSidesList())
    {
      local teamName = ::events.getTeamName(team)
      teamObj = getObject(teamName)
      if (teamObj == null)
        continue

      local show = ::isInArray(team, sides)
      teamObj.show(show)
      if (!show)
        continue

      local titleObj = teamObj.findObject("team_title")
      if(::checkObj(titleObj))
      {
        local isEventFreeForAll = ::events.isEventFreeForAll(roomMGM)
        titleObj.show( ! ::events.isEventSymmetricTeams(roomMGM) || isEventFreeForAll)
        titleObj.setValue(isEventFreeForAll ? ::loc("events/ffa")
          : ::g_team.getTeamByCode(team).getName())
      }

      local teamData = ::events.getTeamDataWithRoom(roomMGM, team, room)
      local playersCountObj = getObject("players_count", teamObj)
      if (playersCountObj)
        playersCountObj.setValue(sides.len() > 1 ? getTeamPlayersCountText(team, teamData, roomMGM) : "")

      ::fillCountriesList(getObject("countries", teamObj), ::events.getCountries(teamData))
      local unitTypes = ::events.getUnitTypesByTeamDataAndName(teamData, teamName)
      local roomSpecialRules = room && ::SessionLobby.getRoomSpecialRules(room)
      ::events.fillAirsList(this, teamObj, teamData, unitTypes, roomSpecialRules)
    }

    // Team separator
    local separatorObj = getObject("teams_separator")
    if (separatorObj != null)
      separatorObj.show(sides.len() > 1)

    // Misc
    updateCostText()
    loadMap()
    fetchLbData()
  }

  function getTeamPlayersCountText(team, teamData, roomMGM)
  {
    if (!room)
    {
      if (::events.hasTeamSizeHandicap(roomMGM))
        return ::colorize("activeTextColor", ::loc("events/handicap") + ::events.getTeamSize(teamData))
      return ""
    }

    local otherTeam = ::g_team.getTeamByCode(team).opponentTeamCode
    local countTblReady = ::SessionLobby.getMembersCountByTeams(room, true)
    local countText = countTblReady[team]
    if (countTblReady[team] >= ::events.getTeamSize(teamData)
        || countTblReady[team] - ::events.getMaxLobbyDisbalance(roomMGM) >= countTblReady[otherTeam])
      countText = ::colorize("warningTextColor", countText)

    local countTbl = currentFullRoomData && ::SessionLobby.getMembersCountByTeams(currentFullRoomData)
    local locId = "multiplayer/teamPlayers"
    local locParams = {
      players = countText
      maxPlayers = ::events.getMaxTeamSize(roomMGM)
      unready = ::max(0, ::getTblValue(team, countTbl, 0) - countTblReady[team])
    }
    if (locParams.unready)
      locId = "multiplayer/teamPlayers/hasUnready"
    return ::loc("events/players_count") + ::loc("ui/colon") + ::loc(locId, locParams)
  }

  function updateContentHeader()
  {
    // Difficulty image
    local difficultyImgObj = getObject("difficulty_img")
    if (difficultyImgObj)
    {
      difficultyImgObj["background-image"] = ::events.getDifficultyImg(selectedEvent.name)
      difficultyImgObj["tooltip"] = ::events.getDifficultyTooltip(selectedEvent.name)
    }

    // Event name
    local eventNameObj = getObject("event_name")
    if (eventNameObj)
      eventNameObj.setValue(getHeaderText())
  }

  function getHeaderText()
  {
    if (!room)
      return ::events.getEventNameText(selectedEvent) + " " + ::events.getRespawnsText(selectedEvent)

    local res = ""
    local reqUnits = ::SessionLobby.getRequiredCratfs(Team.A, room)
    local tierText = ::events.getTierTextByRules(reqUnits)
    if (tierText.len())
      res += tierText + " "

    res += ::SessionLobby.getMissionNameLoc(room)

    local teamsCnt = ::SessionLobby.getMembersCountByTeams(room)
    local teamsCntText = ""
    if (::events.isEventSymmetricTeams(::events.getMGameMode(selectedEvent, room)))
      teamsCntText = ::loc("events/players_count") + ::loc("ui/colon") + (teamsCnt[Team.A] + teamsCnt[Team.B])
    else
      teamsCntText = teamsCnt[Team.A] + " " + ::loc("country/VS") + " " + teamsCnt[Team.B]
    res += ::loc("ui/parentheses/space", { text =teamsCntText })
    return res
  }

  function updateCostText()
  {
    if (selectedEvent == null)
      return

    local costDescObj = getObject("cost_desc")
    if (costDescObj == null)
      return

    local text = ::events.getEventActiveTicketText(selectedEvent, "activeTextColor")
    text += (text.len() ? "\n" : "") + ::events.getEventBattleCostText(selectedEvent, "activeTextColor")
    costDescObj.setValue(text)

    local ticketBoughtImgObj = getObject("bought_ticket_img")
    if (ticketBoughtImgObj != null)
    {
      local showImg = ::events.hasEventTicket(selectedEvent)
        && ::events.getEventActiveTicket(selectedEvent).getCost() > ::zero_money
      ticketBoughtImgObj.show(showImg)
    }

    showSceneBtn("rewards_list_btn",
      ::EventRewards.haveRewards(selectedEvent) || ::EventRewards.getBaseVictoryReward(selectedEvent))
  }

  function loadMap()
  {
    if (selectedEvent.name.len() == 0)
      return

    local misName = ""
    if (room)
      misName = ::SessionLobby.getMissionName(true, room)
    if (!misName.len())
      misName = ::events.getEventMission(selectedEvent.name)

    local hasMission = misName != ""
    if (hasMission)
    {
      local misData = ::get_meta_mission_info_by_name(misName)
      if (misData)
      {
        local m = ::DataBlock()
        m.load(misData.getStr("mis_file",""))
        ::g_map_preview.setMapPreview(scene.findObject("tactical-map"), m)
      }
      else
      {
        dagor.debug("Error: Event " + selectedEvent.name + ": not found mission info for mission " + misName)
        hasMission = false
      }
    }
    showSceneBtn("tactical_map_single", hasMission)

    local multipleMapObj = showSceneBtn("multiple_mission", !hasMission)
    if (!hasMission && multipleMapObj)
      multipleMapObj["background-image"] = "#ui/random_mission_map"
  }

  function getDescriptionTimeText()
  {
    if (!room)
      return ::events.getEventTimeText(::events.getMGameMode(selectedEvent, room))

    local startTime = ::SessionLobby.getRoomSessionStartTime(room)
    if (startTime <= 0)
      return ""

    local secToStart = startTime - ::get_matching_server_time()
    if (secToStart <= 0)
      return ::loc("multiplayer/battleInProgressTime", { time = time.secondsToString(-secToStart, true) })
    return ::loc("multiplayer/battleStartsIn", { time = time.secondsToString(secToStart, true) })
  }

  function fetchLbData()
  {
    hideEventLeaderboard()
    newSelfRowRequest = ::events.getMainLbRequest(selectedEvent)
    ::events.getSelfRow(
      newSelfRowRequest,
      "mini_lb_self",
      (@(selectedEvent) function (self_row) {
        ::events.getLeaderboard(::events.getMainLbRequest(selectedEvent),
        "mini_lb_self",
        function (lb_data) {
          showEventLb(lb_data)
        }, this)
      })(selectedEvent), this)
  }

  function showEventLb(lb_data)
  {
    if (!::checkObj(scene))
      return

    local lbWrapObj = getObject("lb_wrap")
    local lbWaitBox = getObject("msgWaitAnimation")
    if (lbWrapObj == null || lbWaitBox == null)
      return

    local btnLb = getObject("leaderboards_btn", lbWrapObj)
    local lbTable = getObject("lb_table", lbWrapObj)
    if (btnLb == null || lbTable == null)
      return

    local lbRows = lb_data ? ::getTblValue("rows", lb_data, []) : []
    local tableData = ""
    local headerRow = ""
    playersInTable = []
    guiScene.replaceContentFromText(lbTable, "", 0, this)
    lbWaitBox.show(!lb_data)

    if (::events.isEventForClanGlobalLb(selectedEvent))
      return

    local field = newSelfRowRequest.lbField
    local lbCategory = ::events.getLbCategoryByField(field)
    local showTable = checkLbTableVisible(lbRows, lbCategory)
    local showButton = lbRows.len() > 0
    lbTable.show(showTable)
    btnLb.show(showButton)
    if (!showTable)
      return

    local data = ""
    local rowIdx = 0
    foreach(row in lbRows)
    {
      data += generateRowTableData(row, rowIdx++, lbCategory)
      playersInTable.append("nick" in row ? row.nick : -1)
      if (rowIdx >= EVENTS_SHORT_LB_VISIBLE_ROWS)
        break
    }
    guiScene.replaceContentFromText(lbTable, data, data.len(), this)
  }

  function checkLbTableVisible(lb_rows, lbCategory)
  {
    if (lbCategory == null)
      return false

    local participants = lb_rows ? lb_rows.len() : 0
    if (!participants || ::isProductionCircuit() && participants < EVENTS_SHORT_LB_REQUIRED_PARTICIPANTS_TO_SHOW)
      return false

    local lastValidatedRow = lb_rows.top()
    return ::getTblValue(lbCategory.field, lastValidatedRow, 0) > 0
  }

  function generateRowTableData(row, rowIdx, lbCategory)
  {
    local rowName = "row_" + rowIdx
    local forClan = ::events.isClanLbRequest(newSelfRowRequest)

    local name = row?.name ?? ""
    name = platformModule.getPlayerName(name)

    local text = name
    if (forClan)
      text = row?.tag ?? ""

    local rowData = [
      {
        text = (row.pos + 1).tostring()
        width = "0.01*@sf"
      }
      {
        id = "name"
        width = "3fw"
        textRawParam = "width:t='pw'; pare-text:t='yes';"
        tdAlign = "left"
        text = text
        tooltip = forClan ? name : ""
        active = false
      }
    ]

    if (lbCategory)
    {
      local td = lbCategory.getItemCell(::getTblValue(lbCategory.field, row, -1))
      td.tdAlign <- "right"
      rowData.append(td)
    }
    local data = ::buildTableRow(rowName, rowData, 0, "inactive:t='yes'; commonTextColor:t='yes';", "0")
    return data
  }

  function setEventDescObjVisible(value)
  {
    local eventDescObj = getObject("event_desc")
    if (eventDescObj != null)
      eventDescObj.show(value)
  }

  function getObject(id, parentObject = null)
  {
    if (parentObject == null)
      parentObject = scene
    local obj = parentObject.findObject(id)
    return ::checkObj(obj) ? obj : null
  }

  function onEventInventoryUpdate(params)
  {
    updateCostText()
  }

  function onEventEventlbDataRenewed(params)
  {
    if (::getTblValue("eventId", params) == ::getTblValue("name", selectedEvent))
      fetchLbData()
  }

  function onEventItemBought(params)
  {
    local item = ::getTblValue("item", params)
    if (item && item.isForEvent(::getTblValue("name", selectedEvent)))
      updateCostText()
  }

  function onOpenEventLeaderboards()
  {
    if (selectedEvent != null)
      ::gui_modal_event_leaderboards(selectedEvent.name)
  }

  function onRewardsList()
  {
    ::gui_handlers.EventRewardsWnd.open(selectedEvent)
  }

  function onPlayersList()
  {
    ::gui_handlers.MRoomMembersWnd.open(room)
  }

  function hideEventLeaderboard()
  {
    local lbWrapObj = getObject("lb_wrap")
    if (lbWrapObj == null)
      return
    local btnLb = getObject("leaderboards_btn", lbWrapObj)
    if (btnLb != null)
      btnLb.show(false)
    local lbTable = getObject("lb_table", lbWrapObj)
    if (lbTable != null)
      lbTable.show(false)
    local lbWaitBox = getObject("msgWaitAnimation")
    if (lbWaitBox != null)
      lbWaitBox.show(true)
  }

  function getFullRoomData()
  {
    return room && ::g_mroom_info.get(room.roomId).getFullRoomData()
  }

  function onEventMRoomInfoUpdated(p)
  {
    if (room && p.roomId == room.roomId && !::u.isEqual(currentFullRoomData, getFullRoomData()))
      updateContent()
  }
}
