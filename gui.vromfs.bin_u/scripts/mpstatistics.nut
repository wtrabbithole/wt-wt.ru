local time = require("scripts/time.nut")
local platformModule = require("scripts/clientState/platform.nut")

const PLAYERS_IN_FIRST_TABLE_IN_FFA = 16

::team_aircraft_list <- null


::time_to_kick_show_timer <- null
::time_to_kick_show_alert <- null
::in_battle_time_to_kick_show_timer <- null
::in_battle_time_to_kick_show_alert <- null

function get_time_to_kick_show_timer()
{
  if (::time_to_kick_show_timer == null)
  {
    ::time_to_kick_show_timer = ::getTblValueByPath(
      "time_to_kick.show_timer_threshold",
      ::get_game_settings_blk(), 30)
  }
  return ::time_to_kick_show_timer
}

function get_time_to_kick_show_alert()
{
  if (::time_to_kick_show_alert == null)
  {
    ::time_to_kick_show_alert = ::getTblValueByPath(
      "time_to_kick.show_alert_threshold",
      ::get_game_settings_blk(), 15)
  }
  return ::time_to_kick_show_alert
}

function get_in_battle_time_to_kick_show_timer()
{
  if (::in_battle_time_to_kick_show_timer == null)
  {
    ::in_battle_time_to_kick_show_timer = ::getTblValueByPath(
      "time_to_kick.in_battle_show_timer_threshold",
      ::get_game_settings_blk(), 150)
  }
  return ::in_battle_time_to_kick_show_timer
}

function get_in_battle_time_to_kick_show_alert()
{
  if (::in_battle_time_to_kick_show_alert == null)
  {
    ::in_battle_time_to_kick_show_alert = ::getTblValueByPath(
      "time_to_kick.in_battle_show_alert_threshold",
      ::get_game_settings_blk(), 50)
  }
  return ::in_battle_time_to_kick_show_alert
}

function get_local_team_for_mpstats(team = null)
{
  return (team ?? ::get_mp_local_team()) != Team.B ? Team.A : Team.B
}

function gui_start_mpstatscreen_(is_from_game)
{
  local handler = ::handlersManager.loadHandler(::gui_handlers.MPStatScreen,
                    { backSceneFunc = is_from_game? null : ::handlersManager.getLastBaseHandlerStartFunc(),
                      isFromGame = is_from_game
                    })
  if (is_from_game)
    ::statscreen_handler = handler
}

function gui_start_mpstatscreen()
{
  gui_start_mpstatscreen_(false)
  ::handlersManager.setLastBaseHandlerStartFunc(::gui_start_mpstatscreen)
}

function gui_start_mpstatscreen_from_game()
{
  gui_start_mpstatscreen_(true)
  ::handlersManager.setLastBaseHandlerStartFunc(::gui_start_mpstatscreen_from_game)
}

function gui_start_flight_menu_stat()
{
  gui_start_mpstatscreen_from_game()
}

function is_mpstatscreen_active()
{
  if (!::g_login.isLoggedIn())
    return false
  local curHandler = ::handlersManager.getActiveBaseHandler()
  return curHandler != null && (curHandler instanceof ::gui_handlers.MPStatScreen)
}

function build_mp_table(table, markupData, hdr, max_rows)
{
  local numTblRows = table.len()
  local numRows = ::max(numTblRows, max_rows)
  if (numRows <= 0)
    return ""

  local isHeader    = markupData?.is_header ?? false
  local trSize      = markupData?.tr_size   ?? "pw, @baseTrHeight"
  local isRowInvert = markupData?.invert    ?? false
  local colorTeam   = markupData?.colorTeam ?? "blue"

  local markup = markupData.columns

  if (isRowInvert)
  {
    hdr = clone hdr
    hdr.reverse()
  }

  local data = ""

  if (isHeader)
  {
    local headerView = {
      trSize = trSize
      headerCells = []
    }
    for (local i = 0; i < hdr.len(); ++i)
    {
      headerView.headerCells.push({
        cellId = hdr[i]
        cellText = hdr[i]
        hasCellBorder = (i != 0)
      })
    }
    data += ::handyman.renderCached("gui/mpStatistics/mpStatisticsHeader", headerView)
  }

  for (local i = 0; i < numRows; i++)
  {
    local isEmpty = i >= numTblRows
    local trData = format("even:t='%s'; ", (i%2 == 0)? "yes" : "no")
    local trAdd = isEmpty? "inactive:t='yes'; " : ""

    for (local j = 0; j < hdr.len(); ++j)
    {
      local item = ""
      local tdData = ""
      local widthAdd = ((j==0)||(j==(hdr.len()-1)))? "+@tablePad":""
      local textPadding = "style:t='padding:0.005sh,0;'; "
      if (j==0)             textPadding = "style:t='padding:@tablePad,0,0.005sh,0;'; "
      if (j==(hdr.len()-1)) textPadding = "style:t='padding:0.005sh,0,@tablePad,0;'; "

      if (!isEmpty && (hdr[j] in table[i]))
        item = table[i][hdr[j]]

      if (hdr[j] == "hasPassword")
      {
        local icon = item ? "#ui/gameuiskin#password" : ""
        tdData += "size:t='ph"+widthAdd+" ,ph';"  +
          ("img{ pos:t='(pw-w)/2,(ph-h)/2'; position:t='relative'; size:t='@tableIcoSize,@tableIcoSize'; background-image:t='" + (isEmpty ? "" : icon) + "'; }")
      }
      else if (hdr[j] == "team")
      {
        local team = ""
        local teamText = "teamImg{ text { halign:t='center'}} "
        tdData += "size:t='ph"+widthAdd+",ph'; css-hier-invalidate:t='yes'; team:t=''; " + teamText
      }
      else if (hdr[j] == "country" || hdr[j] == "teamCountry")
      {
        local country = ""
        if (hdr[j] == "country")
          country = item
        else
          if (!isEmpty && ("team" in table[i]))
            country = get_mp_country_by_team(table[i].team)

        local icon = ""
        if (!isEmpty && country!= "")
          icon = ::get_country_icon(country)
        tdData += ::format("size:t='ph%s,ph';"
          + "img{ pos:t='(pw-w)/2,(ph-h)/2'; position:t='relative'; size:t='@tableIcoSize,@tableIcoSize';"
          +   "background-image:t='%s'; background-svg-size:t='@cIco, @cIco';"
          + "}",
          widthAdd, icon)
      }
      else if (hdr[j] == "status")
      {
        tdData = ::format("size:t='ph%s,ph'; playerStateIcon { id:t='ready-ico' } ", widthAdd)
      }
      else if (hdr[j] == "name")
      {
        local textDiv = "textareaNoTab"
        local nameWidth = ((hdr[j] in markup)&&("width" in markup[hdr[j]]))?markup[hdr[j]].width:"0.5pw-0.035sh"
        local nameAlign = isRowInvert ? "text-align:t='right' " : ""

        local nameText = platformModule.getPlayerName(item) || ""
        if (!isEmpty && "clanTag" in table[i] && table[i].clanTag != "")
          nameText = table[i].clanTag + " " + nameText

        tdData += format ("width:t='%s'; %s { id:t='name-text'; %s text:t = '%s'; pare-text:t='yes'; width:t='pw'; halign:t='center'; top:t='(ph-h)/2';} %s"
          nameWidth, textDiv, nameAlign, nameText, textPadding
        )

        if (!isEmpty)
        {
          if (("isLocal" in table[i]) && table[i].isLocal)
            trAdd += "mainPlayer:t = 'yes';"
          else if (("isInHeroSquad" in table[i]) && table[i].isInHeroSquad)
            trAdd += "inMySquad:t = 'yes';"
          if (("spectator" in table[i]) && table[i].spectator)
            trAdd += "spectator:t = 'yes';"
        }
      }
      else if (hdr[j] == "unitIcon")
      {
        //creating empty unit class/dead icon and weapons icons, to be filled in update func
        local images = [ "img { id:t='unit-ico'; size:t='@tableIcoSize,@tableIcoSize'; background-image:t=''; shopItemType:t=''; }" ]
        foreach(id, weap in ::getWeaponTypeIcoByWeapon("", ""))
          images.insert(0, ::format("img { id:t='%s-ico'; size:t='0.375@tableIcoSize,@tableIcoSize'; background-image:t=''; margin:t='2@dp, 0' }", id))
        if (isRowInvert)
          images.reverse()
        local cellWidth = markup?[hdr[j]]?.width ?? "@tableIcoSize, @tableIcoSize"
        local divPos = isRowInvert ? "0" : "pw-w"
        tdData += ::format("width:t='%s'; tdiv { pos:t='%s, ph/2-h/2'; position:t='absolute'; %s } ", cellWidth, divPos, ::g_string.implode(images))
      }
      else if (hdr[j] == "rank")
      {
        local prestigeImg = "";
        local rankTxt = ""
        if (!isEmpty && ("exp" in table[i]) && ("prestige" in table[i]))
        {
          rankTxt = get_rank_by_exp(table[i].exp).tostring()
          prestigeImg = "#ui/gameuiskin#prestige" + table[i].prestige
        }
        local rankItem = format("activeText { id:t='rank-text'; text:t='%s'; margin-right:t='%%s' } ", rankTxt)
        local prestigeItem = format("cardImg { id:t='prestige-ico'; background-image:t='%s'; margin-right:t='%%s' } ", prestigeImg)
        local data = isRowInvert ? prestigeItem + rankItem : rankItem + prestigeItem
        tdData += format("width:t='2.2@rows16height%s'; tdiv { pos:t='%s, 0.5(ph-h)'; position:t='absolute'; " + data + " } ",
                    widthAdd, isRowInvert ? "0" : "pw-w-1", "0", "0.003sh")
      }
      else if (hdr[j] == "rowNo")
      {
        local tdProp = ""
        if (hdr[j] in markup)
          tdProp += ::format("width:t='%s'", ::getTblValue("width", markup[hdr[j]], ""))

        trAdd += "winnerPlace:t='none';"
        tdData += ::format("%s activeText { text:t = '%i'; halign:t='center'} "
          tdProp, i+1)
      }
      else if (hdr[j] == "place")
      {
        local width = "width:t='" + ::getTblValue("width", markup[hdr[j]], "1") + "'; "
        tdData += ::format("%s activeText { text:t = '%s'; halign:t='center';} ", width, item)
      }
      else if (::isInArray(hdr[j], [ "aiTotalKills", "assists", "damageZone", "raceFinishTime", "raceLastCheckpoint", "raceLastCheckpointTime", "raceBestLapTime", "missionAliveTime" ]))
      {
        local txt = isEmpty ? "" : ::g_mplayer_param_type.getTypeById(hdr[j]).printFunc(item, table[i])
        tdData += ::format("activeText { text:t='%s' halign:t='center' } ", txt)
        local width = ::getTblValue("width", ::getTblValue(hdr[j], markup, {}), "")
        if (width != "")
          tdData += ::format("width:t='%s'; ", width)
      }
      else if (hdr[j] == "numPlayers")
      {
        local curWidth = ((hdr[j] in markup)&&("width" in markup[hdr[j]]))?markup[hdr[j]].width:"0.15pw"
        local txt = item.tostring()
        local txtParams = "pare-text:t='yes'; max-width:t='pw'; halign:t='center';"
        if (!isEmpty && "numPlayersTotal" in table[i])
        {
          local maxVal = table[i].numPlayersTotal
          txt += "/" + maxVal
          if (item >= maxVal)
            txtParams += "overlayTextColor:t='warning';"
        }
        tdData += "width:t='" + curWidth + "'; activeText { text:t = '" + txt + "'; " + txtParams + " } "
      }
      else
      {
        local tdProp = textPadding
        local textType = "activeText"
        local text = ::locOrStrip(item.tostring())
        local halign = "center"
        local pareText = true
        local imageBg = ""

        if (hdr[j] in markup)
        {
          if ("width" in markup[hdr[j]])
            tdProp += "width:t='" + markup[hdr[j]].width + "'; "
          if ("textDiv" in markup[hdr[j]])
            textType = markup[hdr[j]].textDiv
          if ("halign" in markup[hdr[j]])
            halign =  markup[hdr[j]].halign
          if ("pareText" in markup[hdr[j]])
            pareText =  markup[hdr[j]].pareText
          if (!isEmpty && ("image" in markup[hdr[j]]))
            imageBg = ::format(" team:t='%s'; " +
              "teamImg {" +
              "id:t='%s';" +
              "background-image:t='%s'; ",
              colorTeam, "icon_"+hdr[j], markup[hdr[j]].image
            )
        }
        local textParams = format("halign:t='%s'; ", halign)

        tdData += ::format("%s {" +
          "id:t='%s';" +
          "text:t = '%s';" +
          "max-width:t='pw';" +
          "pare-text:t='%s'; " +
          "%s}",
          tdProp+imageBg+textType, "txt_"+hdr[j], text, (pareText ? "yes" : "no"), textParams+((imageBg=="")?"":"}")
        )
      }

      trData += "td { id:t='td_" + hdr[j] + "'; "
        if (j==0)              trData += "padding-left:t='@tablePad'; "
        if (j>0)               trData += "cellType:t = 'border'; "
        if (j==(hdr.len()-1))  trData += "padding-right:t='@tablePad'; "
      trData += tdData + " }"
    }

    if (trData.len() > 0)
      data += "tr {size:t = '" + trSize + "'; " + trAdd + trData + " text-valign:t='center'; css-hier-invalidate:t='all'; }\n"
  }

  return data
}

function update_team_css_label(nestObj)
{
  if (!::check_obj(nestObj))
    return
  local teamCode = (::SessionLobby.status == lobbyStates.IN_LOBBY)? ::SessionLobby.team : ::get_local_team_for_mpstats()
  nestObj.playerTeam = ::g_team.getTeamByCode(teamCode).cssLabel
}

function set_mp_table(obj_tbl, table, params)
{
  local max_rows = ::getTblValue("max_rows", params, 0)
  local numTblRows = table.len()
  local numRows = numTblRows > max_rows ? numTblRows : max_rows
  local realTblRows = obj_tbl.childrenCount()

  if ((numRows <= 0)||(realTblRows <= 0))
    return ""

  local showAirIcons = ::getTblValue("showAirIcons", params, true)
  local continueRowNum = ::getTblValue("continueRowNum", params, 0)
  local numberOfWinningPlaces = ::getTblValue("numberOfWinningPlaces", params, -1)
  local isInFlight = ::is_in_flight()
  local needColorizeNotInGame = isInFlight

  ::SquadIcon.updateTopSquadScore(table)

  for (local i = 0; i < numRows; i++)
  {
    local objTr = null
    if (realTblRows <= i)
      objTr = obj_tbl.getChild(realTblRows-1).getClone()
    else
      objTr = obj_tbl.getChild(i)

    objTr.inactive = (i >= numTblRows)? "yes" : "no"
    if (i >= numRows)
      continue

    local isEmpty = i >= numTblRows
    local isInGame = true
    if (!isEmpty && needColorizeNotInGame)
    {
      local state = table[i].state
      isInGame = state == ::PLAYER_IN_FLIGHT || state == ::PLAYER_IN_RESPAWN
      objTr.inGame = isInGame ? "yes" : "no"
    }

    local totalCells = objTr.childrenCount()
    for (local idx = 0; idx < totalCells; idx++)
    {
      local objTd = objTr.getChild(idx)
      local id = objTd.id
      if (!id || id.len()<4 || id.slice(0, 3)!="td_")
        continue

      local hdr = id.slice(3)
      local item = ""

      if (!isEmpty && (hdr in table[i]))
        item = table[i][hdr]

      if (hdr == "team")
      {
        local teamText = ""
        local teamStyle = ""
        switch (item)
        {
          case 1:
            teamText = "A"
            teamStyle = "a"
            break
          case 2:
            teamText = "B"
            teamStyle = "b"
            break
          default:
            teamText = "?"
            teamStyle = ""
            break
        }

        if (isEmpty)
        {
          teamText = ""
          teamStyle = ""
        }

        objTd.getChild(0).setValue(teamText)
        objTd["team"] = teamStyle
      }
      else if (hdr == "country" || hdr == "teamCountry")
      {
        local country = ""
        if (hdr == "country")
          country = item
        else
          if (!isEmpty && ("team" in table[i]))
            country = get_mp_country_by_team(table[i].team)

        local objImg = objTd.getChild(0)
        local icon = ""
        if (!isEmpty && country != "")
          icon = ::get_country_icon(country)
        objImg["background-image"] = icon
      }
      else if (hdr == "status")
      {
        local objReady = objTd.findObject("ready-ico")
        if (::check_obj(objReady))
        {
          if (isEmpty)
            objReady["background-image"] = ""
          else
          {
            local playerState = ::g_player_state.getStateByPlayerInfo(table[i])
            objReady["background-image"] = playerState.getIcon(table[i])
            objReady["background-color"] = playerState.getIconColor()
            local desc = playerState.getText(table[i])
            objReady.tooltip = (desc != "") ? (::loc("multiplayer/state") + ::loc("ui/colon") + desc) : ""
          }
        }
      }
      else if (hdr == "name")
      {
        local objName = objTd.findObject("name-text")
        local objDlcImg = objTd.findObject("dlc-ico")
        local nameText = ""

        if (!isEmpty)
        {
          nameText = item
          local prepPlayer = false
          if ("clanTag" in table[i] && table[i].clanTag != "")
            nameText = table[i].clanTag + " " + platformModule.getPlayerName(nameText)
          if (("invitedName" in table[i]) && table[i].invitedName != item)
          {
            local color = ""
            if (obj_tbl.team)
              if (obj_tbl.team == "red")
                color = "teamRedInactiveColor"
              else if (obj_tbl.team == "blue")
                color = "teamBlueInactiveColor"

            local playerName = table[i].invitedName
            if (color != "")
              playerName = ::colorize(color, platformModule.getPlayerName(table[i].invitedName))
            nameText = ::format("%s... %s", platformModule.getPlayerName(nameText), playerName)
          }

          if (objName)
            objName.setValue(nameText)

          if (objDlcImg)
            objDlcImg.show(false)
        }
        else
        {
          if (objName)     objName.setValue("")
          if (objDlcImg)   objDlcImg.show(false)
        }

        if (!isEmpty)
        {
          objTr.mainPlayer = (::is_replay_playing() ? (table[i].userId == ::current_replay_author) : table[i].isLocal) ? "yes" : "no";
          objTr.inMySquad = (("isInHeroSquad" in table[i]) && table[i].isInHeroSquad) ? "yes" : "no";
          objTr.spectator = (("spectator" in table[i]) && table[i].spectator) ? "yes" : "no"
        }
        local tooltip = nameText
        if (!isEmpty && !table[i].isBot && (::get_mission_difficulty() == ::g_difficulty.ARCADE.gameTypeName))
        {
          local data = ::SessionLobby.getBattleRatingParamById(table[i].userId)
          if (data)
          {
            local squadInfo = ::SquadIcon.getSquadInfo(data.squad)
            local isInSquad = squadInfo ? !squadInfo.autoSquad : false
            local ratingTotal = ::calc_battle_rating_from_rank(data.rank)
            tooltip += "\n" + ::loc("debriefing/battleRating/units") + ::loc("ui/colon")
            local showLowBRPrompt = false

            local unitsForTooltip = []
            for (local i = 0; i < min(data.units.len(), 3); ++i)
              unitsForTooltip.push(data.units[i])
            unitsForTooltip.sort(sort_units_for_br_tooltip)
            for (local i = 0; i < unitsForTooltip.len(); ++i)
            {
              local rankUnused = unitsForTooltip[i].rankUnused
              local formatString = rankUnused
                ? "\n<color=@disabledTextColor>(%.1f) %s</color>"
                : "\n<color=@disabledTextColor>(<color=@userlogColoredText>%.1f</color>) %s</color>"
              if (rankUnused)
                showLowBRPrompt = true
              tooltip += ::format(formatString, unitsForTooltip[i].rating, unitsForTooltip[i].name)
            }
            tooltip += "\n" + ::loc(isInSquad ? "debriefing/battleRating/squad" : "debriefing/battleRating/total") +
                              ::loc("ui/colon") + ::format("%.1f", ratingTotal)
            if (showLowBRPrompt)
            {
              local maxBRDifference = 2.0 // Hardcoded till switch to new matching.
              local rankCalcMode = ::SessionLobby.getRankCalcMode()
              if (rankCalcMode)
                tooltip += "\n" + ::loc("multiplayer/lowBattleRatingPrompt/" + rankCalcMode, { maxBRDifference = ::format("%.1f", maxBRDifference) })
            }
          }
        }
        objTr.tooltip = tooltip
      }
      else if (hdr == "unitIcon")
      {
        local unitIco = ""
        local unitIcoColorType = ""
        local unitId = ""
        local weapon = ""

        if (!isEmpty)
        {
          local player = table[i]
          if (isInFlight && !isInGame)
            unitIco = ::g_player_state.HAS_LEAVED_GAME.getIcon(player)
          else if (player?.isDead)
            unitIco = (player?.spectator) ? "#ui/gameuiskin#player_spectator" : "#ui/gameuiskin#dead"
          else if (showAirIcons && ("aircraftName" in player))
          {
            unitId = player.aircraftName
            unitIco = ::getUnitClassIco(unitId)
            unitIcoColorType = ::get_unit_role(unitId)
            weapon = player?.weapon ?? ""
          }
        }

        local obj = objTd.findObject("unit-ico")
        if (::check_obj(obj))
        {
          obj["background-image"] = unitIco
          obj["shopItemType"] = unitIcoColorType
        }

        foreach(id, icon in ::getWeaponTypeIcoByWeapon(unitId, weapon))
        {
          obj = objTd.findObject(id + "-ico")
          if (::check_obj(obj))
            obj["background-image"] = icon
        }
      }
      else if (hdr == "aircraft")
      {
        local objText = objTd.findObject("txt_aircraft")
        if (::checkObj(objText))
        {
          local text = ""
          local tooltip = ""
          if (!isEmpty)
          {
            if (::getTblValue("spectator", table[i], false))
            {
              text = ::loc("mainmenu/btnReferee")
              tooltip = ::loc("multiplayer/state/player_referee")
            }
            else
            {
              local unitId = !isEmpty ? ::getTblValue("aircraftName", table[i], "") : ""
              text = (unitId != "") ? ::loc(::getUnitName(unitId, true)) : ""
              tooltip = (unitId != "") ? ::loc(::getUnitName(unitId, false)) : ""
            }
          }
          objText.setValue(text)
          objText.tooltip = tooltip
        }
      }
      else if (hdr == "rowNo")
      {
        local tablePos = i + 1
        local pos = tablePos + continueRowNum
        objTd.getChild(0).setValue(pos.tostring())
        local winPlace = "none"
        if (!isEmpty && numberOfWinningPlaces > 0 && ::getTblValue("raceLastCheckpoint", table[i], 0) > 0)
        {
          if (tablePos == 1)
            winPlace = "1st"
          else if (tablePos <= numberOfWinningPlaces)
            winPlace = "2nd"
        }
        objTr.winnerPlace = winPlace
      }
      else if (hdr == "place")
      {
        objTd.getChild(0).setValue(item)
      }
      else if (::isInArray(hdr, [ "aiTotalKills", "assists", "damageZone", "raceFinishTime", "raceLastCheckpoint", "raceLastCheckpointTime", "raceBestLapTime", "missionAliveTime" ]))
      {
        local paramType = isEmpty ? null : ::g_mplayer_param_type.getTypeById(hdr)
        local txt = paramType ? paramType.printFunc(item, table[i]) : ""
        local objText = objTd.getChild(0)
        objText.setValue(txt)
        objText.tooltip = paramType ? paramType.getTooltip(item, table[i], txt) : ""
      }
      else if (hdr == "numPlayers")
      {
        local txt = item.tostring()
        if (!isEmpty && "numPlayersTotal" in table[i])
          txt += "/" + table[i].numPlayersTotal
        objTd.getChild(0).setValue(txt)
      }
      else if (hdr == "squad")
      {
        local squadInfo = (!isEmpty && ::SquadIcon.isShowSquad()) ? ::SquadIcon.getSquadInfoByMemberName(::getTblValue("name", table[i], "")) : null
        local squadId = ::getTblValue("squadId", squadInfo, INVALID_SQUAD_ID)
        local labelSquad = squadInfo ? squadInfo.label.tostring() : ""
        local needSquadIcon = labelSquad != ""
        local squadScore = needSquadIcon ? ::getTblValue("squadScore", table[i], 0) : 0
        local isTopSquad = needSquadIcon && squadScore && squadId != INVALID_SQUAD_ID && squadId == ::SquadIcon.getTopSquadId(squadInfo.teamId)

        local cellText = objTd.findObject("txt_"+hdr)
        if (::checkObj(cellText))
          cellText.setValue(needSquadIcon && !isTopSquad ? labelSquad : "")

        local cellIcon = objTd.findObject("icon_"+hdr)
        if (::checkObj(cellIcon))
        {
          cellIcon.show(needSquadIcon)
          if (needSquadIcon)
          {
            cellIcon["iconSquad"] = squadInfo.autoSquad ? "autosquad" : "squad"
            cellIcon["topSquad"] = isTopSquad ? "yes" : "no"
            cellIcon["tooltip"] = ::format("%s %s%s", ::loc("options/chat_messages_squad"), ::loc("ui/number_sign", "#"), labelSquad)
              + "\n" + ::loc("profile/awards") + ::loc("ui/colon") + squadScore
              + (isTopSquad ? ("\n" + ::loc("streaks/squad_best")) : "")
          }
        }
      }
      else
      {
        local txt = item.tostring()
        if (txt.len() > 0 && txt[0] == '#')
          txt = ::loc(txt.slice(1))
        local objText = objTd.findObject("txt_"+hdr)
        if (objText)
        {
          objText.setValue(txt)
          objText.tooltip = txt
        }
      }
    }
  }
}

function sort_units_for_br_tooltip(u1, u2)
{
  if (u1.rating != u2.rating)
    return u1.rating > u2.rating ? -1 : 1
  if (u1.rankUnused != u2.rankUnused)
    return u1.rankUnused ? 1 : -1
  return 0
}

function getCurMpTitle(withMissionName = true, withOperationName = false)
{
  local text = ""
  local gm = ::get_game_mode()

  if (gm == ::GM_DOMINATION)
  {
    local diff = ::get_mission_difficulty_int()
    foreach(mode in ::domination_modes)
      if (diff == mode.diff)
      {
        text = ::loc(mode.name)
        break
      }
  }
  else if (gm==::GM_SKIRMISH)         text = ::loc("multiplayer/skirmishMode")
  else if (gm==::GM_CAMPAIGN)         text = ::loc("mainmenu/btnCampaign")
  else if (gm==::GM_SINGLE_MISSION)   text = ::loc("mainmenu/btnCoop")
  else if (gm==::GM_DYNAMIC)          text = ::loc("mainmenu/btnDynamic")
  else if (gm==::GM_BUILDER)          text = ::loc("mainmenu/btnBuilder")
//  else if (gm==::GM_TOURNAMENT)       text = ::loc("multiplayer/tournamentMode")

  if (withMissionName)
    text += ((text=="")? "" : ", ") + ::loc_current_mission_name()
  else if (withOperationName)
    text += ((text=="")? "" : ", ") + ::loc_current_operation_name()
  return text
}

function getPlayerStateTextId(playerInfo)
{
  if (::getTblValue("isBot", playerInfo, false))
    return "bot_ready"

  switch (::getTblValue("state", playerInfo, ""))
  {
    case ::PLAYER_NOT_EXISTS:
    case ::PLAYER_HAS_LEAVED_GAME:
    case ::PLAYER_IN_LOBBY_NOT_READY:
    case ::PLAYER_IN_LOADING:
      return "player_not_ready"
    case ::PLAYER_IN_STATISTICS_BEFORE_LOBBY:
      return "player_stats"
    case ::PLAYER_IN_LOBBY_READY:
    case ::PLAYER_READY_TO_START:
      return "player_ready"
    case ::PLAYER_IN_FLIGHT:
    case ::PLAYER_IN_RESPAWN:
      return "player_in_game"
  }

  if (::getTblValue("clipSize", playerInfo, 0) > 0)
    return "movie_unlocked"
  return ""
}

function getUnitClassIco(unit)
{
  if (::u.isString(unit))
    unit = ::getAircraftByName(unit)
  if (!unit)
    return ""
  return unit.customClassIco ?? ::get_unit_class_icon_by_unit(unit, unit.name + "_ico")
}

function getUnitClassColor(unit)
{
  if (::is_helicopter(unit))
    return "helicopterColor"
  local role = ::get_unit_role(unit) //  "fighter", "bomber", "assault", "transport", "diveBomber", "none"
  if (role == null || role == "" || role == "none")
    return "white";
  return role + "Color"
}

function getWeaponTypeIcoByWeapon(airName, weapon, tankWeapons = false)
{
  local config = {bomb = "", rocket = "", torpedo = "", additionalGuns = ""}
  local air = getAircraftByName(airName)
  if (!air) return config

  foreach(w in air.weapons)
    if (w.name == weapon)
    {
      local tankRockets = tankWeapons && (::getTblValue("antiTankRocket", w) || ::getTblValue("antiShipRocket", w))
      config.bomb = w.bomb? "#ui/gameuiskin#weap_bomb" : ""
      config.rocket = w.rocket || tankRockets? "#ui/gameuiskin#weap_missile" : ""
      config.torpedo = w.torpedo? "#ui/gameuiskin#weap_torpedo" : ""
      config.additionalGuns = w.additionalGuns ? "#ui/gameuiskin#weap_pod" : ""
      break
    }
  return config
}

function get_weapon_icons_text(unitName, weaponName)
{
  if (!weaponName || ::u.isEmpty(weaponName))
    return ""

  local unit = getAircraftByName(unitName)
  if (!unit)
    return ""

  local weaponIconsText = ""
  foreach(weapon in unit.weapons)
    if (weapon.name == weaponName)
    {
      foreach (paramName in ["bomb", "rocket", "torpedo", "additionalGuns"])
        if (weapon[paramName])
          weaponIconsText += ::loc("weapon/" + paramName + "Icon")
      break
    }

  return ::colorize("weaponPresetColor", weaponIconsText)
}

function get_mp_country_by_team(team)
{
  local info = ::get_mp_session_info()
  if (!info)
    return ""
  if (team==1 && ("alliesCountry" in info))
    return "country_"+info.alliesCountry
  if (team==2 && ("axisCountry" in info))
    return "country_"+info.axisCountry
  return "country_0"
}

function count_width_for_mptable(objTbl, markup)
{
  local guiScene = objTbl.getScene()
  local usedWidth = 0
  local relWidthTotal = 0.0
  foreach (id, col in markup)
  {
    if ("relWidth" in col)
      relWidthTotal += col.relWidth
    else if ("width" in col)
    {
      local width = guiScene.calcString(col.width, objTbl)
      col.width = width.tostring()
      usedWidth += width
    }
  }

  local freeWidth = objTbl.getSize()[0] - usedWidth
  foreach (id, col in markup)
  {
    if (relWidthTotal > 0 && ("relWidth" in col))
    {
      local width = (freeWidth * col.relWidth / relWidthTotal).tointeger()
      col.width <- width.tostring()
      freeWidth -= width
      relWidthTotal -= col.relWidth
      delete col.relWidth
    }
  }
}

class ::gui_handlers.MPStatistics extends ::gui_handlers.BaseGuiHandlerWT
{
  wndControlsAllowMask = CtrlsInGui.CTRL_ALLOW_MP_STATISTICS
                         | CtrlsInGui.CTRL_ALLOW_VEHICLE_KEYBOARD | CtrlsInGui.CTRL_ALLOW_VEHICLE_JOY

  needPlayersTbl = true
  showLocalTeamOnly = false
  isModeStat = false
  isRespawn = false
  isSpectate = false
  isTeam = false
  isStatScreen = true

  isWideScreenStatTbl = false
  showAircrafts = false

  mplayerTable = null
  missionTable = null

  tblSave1 = null
  numRows1 = 0
  tblSave2 = null
  numRows2 = 0

  gameMode = 0
  gameType = 0
  isOnline = false

  isTeamplay    = false
  isTeamsWithCountryFlags = false
  isTeamsRandom = true

  missionObjectives = MISSION_OBJECTIVE.NONE

  wasTimeLeft = -1000
  updateCooldown = 3

  numMaxPlayers = 16  //its only visual max players. no need to scroll when table near empty.
  isApplyPressed = false

  checkRaceDataOnStart = true
  numberOfWinningPlaces = -1

  defaultRowHeaders         = ["squad", "name", "unitIcon", "aircraft", "missionAliveTime", "score", "kills", "groundKills", "navalKills", "aiKills",
                               "aiGroundKills", "aiNavalKills", "aiTotalKills", "assists", "captureZone", "damageZone", "deaths"]
  raceRowHeaders            = ["rowNo", "name", "unitIcon", "aircraft", "raceFinishTime", "raceLap", "raceLastCheckpoint",
                               "raceLastCheckpointTime", "deaths"]
  statTrSize = "pw, 1@baseTrHeight"

  function onActivateOrder()
  {
    ::g_orders.openOrdersInventory(true)
  }

  function updateTimeToKick(dt)
  {
    updateTimeToKickTimer()
    updateTimeToKickAlert(dt)
  }

  function updateTimeToKickTimer()
  {
    local timeToKickObj = getTimeToKickObj()
    if (!::checkObj(timeToKickObj))
      return
    local timeToKickValue = ::get_mp_kick_countdown()
    // Already in battle or it's too early to show the message.
    if (timeToKickValue <= 0 || ::get_time_to_kick_show_timer() < timeToKickValue)
      timeToKickObj.setValue("")
    else
    {
      local timeToKickText = time.secondsToString(timeToKickValue, true, true)
      local locParams = {
        timeToKick = ::colorize("activeTextColor", timeToKickText)
      }
      timeToKickObj.setValue(::loc("respawn/timeToKick", locParams))
    }
  }

  function updateTimeToKickAlert(dt)
  {
    local timeToKickAlertObj = scene.findObject("time_to_kick_alert_text")
    if (!::checkObj(timeToKickAlertObj))
      return
    local timeToKickValue = ::get_mp_kick_countdown()
    if (timeToKickValue < 0 || get_time_to_kick_show_alert() < timeToKickValue || isSpectate)
      timeToKickAlertObj.show(false)
    else
    {
      timeToKickAlertObj.show(true)
      local curTime = ::dagor.getCurTime()
      local prevSeconds = ((curTime - 1000 * dt) / 1000).tointeger()
      local currSeconds = (curTime / 1000).tointeger()
      if (currSeconds != prevSeconds)
        timeToKickAlertObj["_blink"] = "yes"
    }
  }

  function onOrderTimerUpdate(obj, dt)
  {
    ::g_orders.updateActiveOrder()
    if (::checkObj(obj))
    {
      obj.text = ::g_orders.getActivateButtonLabel()
      obj.inactiveColor = !::g_orders.orderCanBeActivated() ? "yes" : "no"
    }
  }

  function setTeamInfoTeam(teamObj, team)
  {
    if (!::checkObj(teamObj))
      return
    teamObj.team = team
  }

  function setTeamInfoTeamIco(teamObj, teamIco = null)
  {
    if (!::checkObj(teamObj))
      return
    local teamImgObj = teamObj.findObject("team_img")
    if (::checkObj(teamImgObj))
      teamImgObj.show(teamIco != null)
    if (teamIco != null)
      teamObj.teamIco = teamIco
  }

  function setTeamInfoText(teamObj, text)
  {
    if (!::checkObj(teamObj))
      return
    local textObj = teamObj.findObject("team_text")
    if (::checkObj(textObj))
      textObj.setValue(text)
  }

  /**
   * Sets country flags visibility based
   * on specified country names list.
   */
  function setTeamInfoCountries(teamObj, enabledCountryNames)
  {
    if (!::checkObj(teamObj))
      return
    foreach (countryName in ::shopCountriesList)
    {
      local countryFlagObj = teamObj.findObject(countryName)
      if (::checkObj(countryFlagObj))
        countryFlagObj.show(::isInArray(countryName, enabledCountryNames))
    }
  }

  /**
   * Places all available country
   * flags into container.
   */
  function initTeamInfoCountries(teamObj)
  {
    if (!::checkObj(teamObj))
      return
    local countriesBlock = teamObj.findObject("countries_block")
    if (!::checkObj(countriesBlock))
      return
    local view = {
      countries = ::u.map(::shopCountriesList, function (countryName) {
        return {
          countryName = countryName
          countryIcon = ::get_country_icon(countryName)
        }
      })
    }
    local result = ::handyman.renderCached("gui/countriesList", view)
    guiScene.replaceContentFromText(countriesBlock, result, result.len(), this)
  }

  function setInfo()
  {
    local timeLeft = ::get_multiplayer_time_left()
    if (timeLeft < 0)
    {
      setGameEndStat(-1)
      return
    }
    local timeDif = wasTimeLeft - timeLeft
    if (timeDif < 0)
      timeDif = -timeDif
    if (timeDif >= 1 || ((wasTimeLeft * timeLeft) < 0))
    {
      setGameEndStat(timeLeft)
      wasTimeLeft = timeLeft
    }
  }

  function initScreen()
  {
    scene.findObject("stat_update").setUserData(this)
    needPlayersTbl = scene.findObject("table_kills_team1") != null

    includeMissionInfoBlocksToGamercard()
    setSceneTitle(getCurMpTitle())
    setInfo()
  }

  function initStats()
  {
    if (!::checkObj(scene))
      return

    gameMode = ::get_game_mode()
    gameType = ::get_game_type()
    isOnline = ::g_login.isLoggedIn()

    isTeamplay = ::is_mode_with_teams(gameType)
    isTeamsWithCountryFlags = isTeamplay &&
      (::get_mission_difficulty_int() > 0 || !(::SessionLobby.getRoomEvent()?.isSymmetric ?? false))
    isTeamsRandom = !isTeamplay || gameMode == ::GM_DOMINATION

    missionObjectives = ::g_mission_type.getCurrentObjectives()

    local playerTeam = ::get_local_team_for_mpstats()
    local friendlyTeam = ::get_player_army_for_hud()
    local teamObj1 = scene.findObject("team1_info")
    local teamObj2 = scene.findObject("team2_info")

    if (!isTeamplay)
    {
      foreach(obj in [teamObj1, teamObj2])
        if (::checkObj(obj))
          obj.show(false)
    }
    else if (needPlayersTbl && playerTeam > 0)
    {
      if (::checkObj(teamObj1))
      {
        setTeamInfoTeam(teamObj1, (playerTeam == friendlyTeam)? "blue" : "red")
        initTeamInfoCountries(teamObj1)
      }
      if (!showLocalTeamOnly && ::checkObj(teamObj2))
      {
        setTeamInfoTeam(teamObj2, (playerTeam == friendlyTeam)? "red" : "blue")
        initTeamInfoCountries(teamObj2)
      }
    }

    if (needPlayersTbl)
    {
      createStats()
      ::gui_bhv.OptionsNavigator.clearSelect(scene.findObject("table_kills_team1"))
      ::gui_bhv.OptionsNavigator.clearSelect(scene.findObject("table_kills_team2"))
    }

    updateCountryFlags()
  }

  function createKillsTbl(objTbl, tbl, tblConfig)
  {
    guiScene.setUpdatesEnabled(false, false)

    local team = ::getTblValue("team", tblConfig, -1)
    local num_rows = ::getTblValue("num_rows", tblConfig, numMaxPlayers)
    local showAircrafts = ::getTblValue("showAircrafts", tblConfig, false)
    local showAirIcons = ::getTblValue("showAirIcons", tblConfig, showAircrafts)
    local invert = ::getTblValue("invert", tblConfig, false)

    local tblData = [] // columns order

    local markupData = {
      tr_size = statTrSize
      invert = invert
      colorTeam = "blue"
      columns = {}
    }

    if (gameType & ::GT_COOPERATIVE)
    {
      tblData = showAirIcons ? [ "unitIcon", "name" ] : [ "name" ]
      foreach(id in tblData)
        markupData.columns[id] <- ::g_mplayer_param_type.getTypeById(id).getMarkupData()

      if ("name" in markupData.columns)
        markupData.columns["name"].width = "fw"
    }
    else
    {
      local sourceHeaders = gameType & ::GT_RACE ? raceRowHeaders : defaultRowHeaders
      foreach (id in sourceHeaders)
        if (::g_mplayer_param_type.getTypeById(id).isVisible(missionObjectives, gameType))
          tblData.append(id)

      if (!showAircrafts)
        ::u.removeFrom(tblData, "aircraft")
      if (!::SquadIcon.isShowSquad())
        ::u.removeFrom(tblData, "squad")

      foreach(name in tblData)
        markupData.columns[name] <- ::g_mplayer_param_type.getTypeById(name).getMarkupData()

      if ("name" in markupData.columns)
      {
        local col = markupData.columns["name"]
        if (isWideScreenStatTbl && ("widthInWideScreen" in col))
          col.width = col.widthInWideScreen
      }

      ::count_width_for_mptable(objTbl, markupData.columns)

      local teamNum = (team==2)? 2 : 1
      local tableObj = scene.findObject("team_table_" + teamNum)
      if (team == 2)
        markupData.colorTeam = "red"
      if (::checkObj(tableObj))
      {
        local rowHeaderData = createHeaderRow(tableObj, tblData, markupData, teamNum)
        local show = rowHeaderData != ""
        guiScene.replaceContentFromText(tableObj, rowHeaderData, rowHeaderData.len(), this)
        tableObj.show(show)
      }
    }

    if (team == -1 || team == 1)
      tblSave1 = tbl
    else
      tblSave2 = tbl

    if (tbl)
    {
      if (!isTeamplay)
        sortTable(tbl)

      local data = ::build_mp_table(tbl, markupData, tblData, num_rows)
      guiScene.replaceContentFromText(objTbl, data, data.len(), this)
      objTbl.num_rows = tbl.len()
    }
    guiScene.setUpdatesEnabled(true, true)
  }

  function sortTable(table)
  {
    table.sort(::mpstat_get_sort_func(gameType))
  }

  function setKillsTbl(objTbl, team, playerTeam, friendlyTeam, showAirIcons=true, customTbl = null)
  {
    if (!::checkObj(objTbl))
      return

    local tbl = null
    guiScene.setUpdatesEnabled(false, false)

    if (customTbl)
    {
      local idx = max(team-1, -1)
      if (idx in customTbl)
        tbl = customTbl[idx]
    }

    local minRow = 0
    if (!tbl)
    {
      if (!isTeamplay)
      {
        local commonTbl = ::get_mplayers_list(::GET_MPLAYERS_LIST, true)
        sortTable(commonTbl)
        if (commonTbl.len() > 0)
        {
          local lastRow = PLAYERS_IN_FIRST_TABLE_IN_FFA - 1
          if (objTbl.id == "table_kills_team2")
          {
            minRow = commonTbl.len() <= PLAYERS_IN_FIRST_TABLE_IN_FFA ? 0 : PLAYERS_IN_FIRST_TABLE_IN_FFA
            lastRow = commonTbl.len()
          }

          tbl = []
          for(local i = lastRow; i >= minRow; --i)
          {
            if (!(i in commonTbl))
              continue

            local block = commonTbl.remove(i)
            block.place <- (i+1).tostring()
            tbl.append(block)
          }
          tbl.reverse()
        }
      }
      else
        tbl = ::get_mplayers_list(team, true)
    }
    else if (!isTeamplay && customTbl && objTbl.id == "table_kills_team2")
      minRow = PLAYERS_IN_FIRST_TABLE_IN_FFA

    if (objTbl.id == "table_kills_team2")
    {
      local shouldShow = true
      if (isTeamplay)
        shouldShow = tbl && tbl.len() > 0
      showSceneBtn("team2-root", shouldShow)
    }

    if (!isTeamplay && minRow >= 0)
    {
      if (minRow == 0)
        tblSave1 = tbl
      else
        tblSave2 = tbl
    }
    else
    {
      if (team == playerTeam || playerTeam == -1 || showLocalTeamOnly)
        tblSave1 = tbl
      else
        tblSave2 = tbl
    }

    if (tbl != null)
    {
      if (!customTbl && isTeamplay)
        sortTable(tbl)

      local numRows = numRows1
      if (team == 2)
        numRows = numRows2

      local params = {
                       max_rows = numRows,
                       showAirIcons = showAirIcons,
                       continueRowNum = minRow,
                       numberOfWinningPlaces = numberOfWinningPlaces
                     }
      ::set_mp_table(objTbl, tbl, params)
      ::update_team_css_label(objTbl)
      objTbl.num_rows = tbl.len()

      if (friendlyTeam > 0 && team > 0)
        objTbl["team"] = (isTeamplay && friendlyTeam == team)? "blue" : "red"
    }
    updateCountryFlags()
    guiScene.setUpdatesEnabled(true, true)
  }

  function isShowEnemyAirs()
  {
    return showAircrafts && ::get_mission_difficulty_int() == 0
  }

  function createStats()
  {
    if (!needPlayersTbl)
      return

    local tblObj1 = scene.findObject("table_kills_team1")
    local tblObj2 = scene.findObject("table_kills_team2")
    local team1Root = scene.findObject("team1-root")

    if (!isTeamplay)
    {
      local tbl1 = ::get_mplayers_list(::GET_MPLAYERS_LIST, true)
      sortTable(tbl1)

      local tbl2 = []
      numRows1 = tbl1.len()
      numRows2 = 0
      if (tbl1.len() >= PLAYERS_IN_FIRST_TABLE_IN_FFA)
      {
        numRows1 = numRows2 = PLAYERS_IN_FIRST_TABLE_IN_FFA

        for(local i = tbl1.len()-1; i >= PLAYERS_IN_FIRST_TABLE_IN_FFA; --i)
        {
          if (!(i in tbl1))
            continue

          local block = tbl1.remove(i)
          block.place <- (i+1).tostring()
          tbl2.append(block)
        }
        tbl2.reverse()
      }

      createKillsTbl(tblObj1, tbl1, {num_rows = numRows1, team = Team.A, showAircrafts = showAircrafts})
      createKillsTbl(tblObj2, tbl2, {num_rows = numRows2, team = Team.B, showAircrafts = showAircrafts})

      if (::checkObj(team1Root))
        team1Root.show(true)
    }
    else if (gameType & ::GT_VERSUS)
    {
      if (showLocalTeamOnly)
      {
        local playerTeam = ::get_local_team_for_mpstats()
        local tbl = ::get_mplayers_list(playerTeam, true)
        numRows1 = numMaxPlayers
        numRows2 = 0
        createKillsTbl(tblObj1, tbl, {num_rows = numMaxPlayers, showAircrafts = showAircrafts})
      }
      else
      {
        local tbl1 = ::get_mplayers_list(1, true)
        local tbl2 = ::get_mplayers_list(2, true)
        local num_in_one_row = ::global_max_players_versus / 2
        if (tbl1.len() <= num_in_one_row && tbl2.len() <= num_in_one_row)
        {
          numRows1 = num_in_one_row
          numRows2 = num_in_one_row
        }
        else if (tbl1.len() > num_in_one_row)
          numRows2 = ::global_max_players_versus - tbl1.len()
        else if (tbl2.len() > num_in_one_row)
          numRows1 = ::global_max_players_versus - tbl2.len()

        if (numRows1 > numMaxPlayers)
          numRows1 = numMaxPlayers
        if (numRows2 > numMaxPlayers)
          numRows2 = numMaxPlayers

        local showEnemyAircrafts = isShowEnemyAirs()
        local tblConfig1 = {tbl = tbl2, team = Team.A, num_rows = numRows2, showAircrafts = showAircrafts, invert = true}
        local tblConfig2 = {tbl = tbl1, team = Team.B, num_rows = numRows1, showAircrafts = showEnemyAircrafts}

        if (::get_local_team_for_mpstats() == Team.A)
        {
          tblConfig1.tbl = tbl1
          tblConfig1.num_rows = numRows1

          tblConfig2.tbl = tbl2
          tblConfig2.num_rows = numRows2
        }

        createKillsTbl(tblObj1, tblConfig1.tbl, tblConfig1)
        createKillsTbl(tblObj2, tblConfig2.tbl, tblConfig2)

        if (::checkObj(team1Root))
          team1Root.show(true)
      }
    }
    else
    {
      numRows1 = (gameType & ::GT_COOPERATIVE)? ::global_max_players_coop : numMaxPlayers
      numRows2 = 0
      local tbl = ::get_mplayers_list(::GET_MPLAYERS_LIST, true)
      createKillsTbl(tblObj2, tbl, {num_rows = numRows1, showAircrafts = showAircrafts})

      tblObj1.show(false)

      if (::checkObj(team1Root))
        team1Root.show(false)

      local headerObj = scene.findObject("team2_header")
      if (::checkObj(headerObj))
        headerObj.show(false)
    }
  }

  function updateTeams(tbl, playerTeam, friendlyTeam)
  {
    if (!tbl)
      return

    local teamObj1 = scene.findObject("team1_info")
    local teamObj2 = scene.findObject("team2_info")

    local playerTeamIdx = ::clamp(playerTeam - 1, 0, 1)
    local teamTxt = ["", ""]
    switch (gameType & (::GT_MP_SCORE | ::GT_MP_TICKETS))
    {
      case ::GT_MP_SCORE:
        if (!needPlayersTbl)
          break

        local scoreFormat = "%s" + ::loc("multiplayer/score") + ::loc("ui/colon") + "%d"
        if (tbl.len() > playerTeamIdx)
        {
          setTeamInfoText(teamObj1, ::format(scoreFormat, teamTxt[0], tbl[playerTeamIdx].score))
          setTeamInfoTeam(teamObj1, (playerTeam == friendlyTeam) ? "blue" : "red")
        }
        if (tbl.len() > 1 - playerTeamIdx && !showLocalTeamOnly)
        {
          setTeamInfoText(teamObj2, ::format(scoreFormat, teamTxt[1], tbl[1-playerTeamIdx].score))
          setTeamInfoTeam(teamObj2, (playerTeam == friendlyTeam)? "red" : "blue")
        }
        break

      case ::GT_MP_TICKETS:
        local rounds = ::get_mp_rounds()
        local curRound = ::get_mp_current_round()

        if (needPlayersTbl)
        {
          local scoreLoc = (rounds > 0) ? ::loc("multiplayer/rounds") : ::loc("multiplayer/airfields")
          local scoreformat = "%s" + ::loc("multiplayer/tickets") + ::loc("ui/colon") + "%d" + ", " +
                                scoreLoc + ::loc("ui/colon") + "%d"

          if (tbl.len() > playerTeamIdx)
          {
            setTeamInfoText(teamObj1, ::format(scoreformat, teamTxt[0], tbl[playerTeamIdx].tickets, tbl[playerTeamIdx].score))
            setTeamInfoTeam(teamObj1, (playerTeam == friendlyTeam) ? "blue" : "red")
          }
          if (tbl.len() > 1 - playerTeamIdx && !showLocalTeamOnly)
          {
            setTeamInfoText(teamObj2, ::format(scoreformat, teamTxt[1], tbl[1 - playerTeamIdx].tickets, tbl[1 - playerTeamIdx].score))
            setTeamInfoTeam(teamObj2, (playerTeam == friendlyTeam)? "red" : "blue")
          }
        }

        local statObj = scene.findObject("gc_mp_tickets_rounds")
        if (::checkObj(statObj))
        {
          local text = ""
          if (rounds > 0)
            text = ::loc("multiplayer/curRound", { round = curRound+1, total = rounds })
          statObj.setValue(text)
        }
        break
    }
  }

  function updateStats(customTbl = null, customTblTeams = null, customPlayerTeam = null, customFriendlyTeam = null)
  {
    local playerTeam   = ::get_local_team_for_mpstats(customPlayerTeam ?? ::get_mp_local_team())
    local friendlyTeam = customFriendlyTeam ?? ::get_player_army_for_hud()
    local tblObj1 = scene.findObject("table_kills_team1")
    local tblObj2 = scene.findObject("table_kills_team2")

    if (needPlayersTbl)
    {
      if (!isTeamplay || (gameType & ::GT_VERSUS))
      {
        if (!isTeamplay)
          playerTeam = Team.A

        setKillsTbl(tblObj1, playerTeam, playerTeam, friendlyTeam, showAircrafts, customTbl)
        if (!showLocalTeamOnly && playerTeam > 0)
          setKillsTbl(tblObj2, 3 - playerTeam, playerTeam, friendlyTeam, isShowEnemyAirs(), customTbl)
      }
      else
        setKillsTbl(tblObj2, -1, -1, -1, showAircrafts, customTbl)
    }

    if (playerTeam > 0)
      updateTeams(customTblTeams || ::get_mp_tbl_teams(), playerTeam, friendlyTeam)

    if (checkRaceDataOnStart && ::is_race_started())
    {
      local chObj = scene.findObject("gc_race_checkpoints")
      if (::checkObj(chObj))
      {
        local totalCheckpointsAmount = ::get_race_checkpioints_count()
        local text = ""
        if (totalCheckpointsAmount > 0)
          text = ::getCompoundedText(::loc("multiplayer/totalCheckpoints") + ::loc("ui/colon"), totalCheckpointsAmount, "activeTextColor")
        chObj.setValue(text)
        checkRaceDataOnStart = false
      }

      numberOfWinningPlaces = ::get_race_winners_count()
    }

    ::update_team_css_label(scene.findObject("num_teams"))
  }

  function updateTables(dt)
  {
    updateCooldown -= dt
    if (updateCooldown <= 0)
    {
      updateStats()
      updateCooldown = 3
    }

    if (isStatScreen || !needPlayersTbl)
      return

    if (isRespawn)
    {
      local selectedObj = getSelectedTable()
      if (!isModeStat)
      {
        local objTbl1 = scene.findObject("table_kills_team1")
        local curRow = objTbl1.getValue()
        if (curRow < 0 || curRow >= objTbl1.childrenCount())
          objTbl1.setValue(0)
      }
      else
        if (selectedObj == null)
        {
          scene.findObject("table_kills_team1").setValue(0)
          updateListsButtons()
        }
    }
    else
    {
      ::gui_bhv.OptionsNavigator.clearSelect(scene.findObject("table_kills_team1"))
      ::gui_bhv.OptionsNavigator.clearSelect(scene.findObject("table_kills_team2"))
    }
  }

  function createHeaderRow(tableObj, hdr, markupData, teamNum)
  {
    if (!markupData
        || typeof markupData != "table"
        || !("columns" in markupData)
        || !markupData.columns.len()
        || !::checkObj(tableObj))
      return ""

    local tblData = clone hdr

    if (::getTblValue("invert", markupData, false))
      tblData.reverse()

    local view = {cells = []}
    foreach(name in tblData)
    {
      local value = markupData.columns?[name]
      if (!value || typeof value != "table")
        continue

      view.cells.append({
        id = ::getTblValue("id", value, name)
        fontIcon = ::getTblValue("fontIcon", value, null)
        tooltip = ::getTblValue("tooltip", value, null)
        width = ::getTblValue("width", value, "")
      })
    }

    local tdData = ::handyman.renderCached(("gui/statistics/statTableHeaderCell"), view)
    local trId = "team-header" + teamNum
    local trSize = ::getTblValue("tr_size", markupData, "0,0")
    local trData = ::format("tr{id:t='%s'; size:t='%s'; %s}", trId, trSize, tdData)
    return trData
  }

  function goBack(obj) {}

  function onUserCard(obj)
  {
    local player = getSelectedPlayer();
    if (!player || player.isBot || !isOnline)
      return;

    ::gui_modal_userCard({ name = player.name /*, id = player.id*/ }); //search by nick no work, but session can be not exist at that moment
  }

  function onUserRClick(obj)
  {
    onClick(obj)
    ::session_player_rmenu(this, getSelectedPlayer())
  }

  function onUserOptions(obj)
  {
    local selectedTableObj = getSelectedTable()
    if (!::check_obj(selectedTableObj))
      return

    onClick(selectedTableObj)
    local selectedPlayer = getSelectedPlayer()
    local orientation = selectedTableObj.id == "table_kills_team1"? RCLICK_MENU_ORIENT.RIGHT : RCLICK_MENU_ORIENT.LEFT
    ::session_player_rmenu(this, selectedPlayer, "", getSelectedRowPos(selectedTableObj, orientation), orientation)
  }

  function getSelectedRowPos(selectedTableObj, orientation)
  {
    local rowNum = selectedTableObj.getValue()
    if (rowNum >= selectedTableObj.childrenCount())
      return null

    local rowObj = selectedTableObj.getChild(rowNum)
    local rowSize = rowObj.getSize()
    local rowPos = rowObj.getPosRC()

    local posX = rowPos[0]
    if (orientation == RCLICK_MENU_ORIENT.RIGHT)
      posX += rowSize[0]

    return [posX, rowPos[1] + rowSize[1]]
  }

  function onFriends()
  {
    if (isApplyPressed)
      return
    local player = getSelectedPlayer()
    if (player != null)
    {
      local id = player.id
      local isBlocked = ::is_player_blocked(id)
      local isFriend = ::is_player_friend(id)
      if (isBlocked)
        return
      if (isFriend)
        ::set_player_friend(id, false)
      else
        ::set_player_friend(id, true)
    }

    updateListsButtons()
  }

  function onBlocklist()
  {
    if (isApplyPressed)
      return
    local player = getSelectedPlayer()
    if (player != null)
    {
      local id = player.id
      local isBlocked = ::is_player_blocked(id)
      local isFriend = ::is_player_friend(id)
      if (isFriend)
        return
      if (isBlocked)
        ::set_player_block(id, false)
      else
        ::set_player_block(id, true)
    }

    updateListsButtons()
  }

  function onMute()
  {
    if (isApplyPressed)
      return
    if (isSpectate)
      return

    local player = getSelectedPlayer()
    if (player != null)
      ::do_mute_player(player.id)
  }

  function onKick()
  {
    if (isApplyPressed)
      return
    if (isSpectate)
      return
    if (!::is_mplayer_host())
      return

    local player = getSelectedPlayer()
    if (player != null)
      ::do_kick_player(player.id)
  }

  function getPlayerInfo(name)
  {
    if (name && name != "")
      foreach (tbl in [tblSave1, tblSave2])
        if (tbl)
          foreach(player in tbl)
            if (player.name == name)
              return player
    return null
  }

  function getSelectedInfo()
  {
    local res = null
    local selectedObj = getSelectedTable()
    if (!selectedObj)
      return res

    if (selectedObj.id == "table_kills_team1" && tblSave1 != null)
    {
      local index = selectedObj.cur_row.tointeger()
      if (index >= 0 && index < tblSave1.len())
        res = tblSave1[index]
    }
    else if (selectedObj.id == "table_kills_team2" && tblSave2 != null)
    {
      local index = selectedObj.cur_row.tointeger()
      if (index >= 0 && index < tblSave2.len())
        res = tblSave2[index]
    }
    return res
  }

  function refreshPlayerInfo()
  {
    local pInfo = getSelectedInfo()
    ::set_mplayer_info(scene, pInfo, isTeam)

    local player = getSelectedPlayer()
    showSceneBtn("btn_user_options", isOnline && player && !player.isBot && !isSpectate && ::show_console_buttons)
    ::SquadIcon.updateListLabelsSquad()
  }

  function onComplain(obj)
  {
    local pInfo = getSelectedInfo()
    if (!pInfo || pInfo.isBot || pInfo.isLocal)
      return

    ::gui_modal_complain(pInfo)
  }

  function updateListsButtons()
  {
    refreshPlayerInfo()
  }

  function onStatTblFocus()
  {
    guiScene.performDelayed(this, function()
    {
      if (::checkObj(scene))
        updateListsButtons()
    })
  }

  function getSelectedPlayer()
  {
    local objTbl1 = scene.findObject("table_kills_team1")
    local objTbl2 = scene.findObject("table_kills_team2")
    if (objTbl1 && objTbl1.isFocused())
      return ::getTblValue(objTbl1.getValue(), tblSave1, null)
    if (objTbl2 && objTbl2.isFocused())
      return ::getTblValue(objTbl2.getValue(), tblSave2, null)
    return null
  }

  function getSelectedTable(onlyFocused = false)
  {
    local objTbl1 = scene.findObject("table_kills_team1")
    local objTbl2 = scene.findObject("table_kills_team2")
    if (objTbl1 && objTbl1.isFocused())
      return objTbl1

    if (objTbl2 && objTbl2.isFocused())
      return objTbl2

    return onlyFocused? null : objTbl1
  }

  function onSwitchPlayersTbl()
  {
    if (isApplyPressed)
      return
    if (!isModeStat || isSpectate)
      return

    local selectedObj = getSelectedTable()
    if (selectedObj == null)
      return
    if (selectedObj.id != "table_kills_team1" && selectedObj.id != "table_kills_team2")
      return

    local val = selectedObj.cur_row.tointeger()
    local numRows = selectedObj.num_rows.tointeger()
    if (numRows < 0)
      numRows = selectedObj.childrenCount()

    local table_name = (selectedObj.id == "table_kills_team2") ? "table_kills_team1" : "table_kills_team2"
    local tblObj = scene.findObject(table_name)
    local numRowsDst = tblObj.num_rows.tointeger()
    if (numRowsDst <= 0)
      return

    if (val >= numRowsDst)
      val = numRowsDst - 1

    ::gui_bhv.OptionsNavigator.clearSelect(selectedObj)
    ::gui_bhv.TableNavigator.selectCell(tblObj, val, 0)
    tblObj.select()
    updateListsButtons()
    ::play_gui_sound("click")
  }

  function onClick(obj)
  {
    if (!needPlayersTbl)
      return
    local table_name = obj.id == "table_kills_team2" ? "table_kills_team1" : "table_kills_team2"
    local tblObj = scene.findObject(table_name)
    ::gui_bhv.OptionsNavigator.clearSelect(tblObj)
    obj.select()
    updateListsButtons()
  }

  function selectLocalPlayer()
  {
    if (!needPlayersTbl)
      return false
    foreach (tblIdx, tbl in [ tblSave1, tblSave2 ])
      if (tbl)
        foreach(playerIdx, player in tbl)
          if (::getTblValue("isLocal", player, false))
            return selectPlayerByIndexes(tblIdx, playerIdx)
    return false
  }

  function selectPlayerByIndexes(tblIdx, playerIdx)
  {
    if (!needPlayersTbl)
      return false
    local selectedObj = getSelectedTable()
    if (selectedObj)
      ::gui_bhv.OptionsNavigator.clearSelect(selectedObj)

    local tblObj = scene.findObject("table_kills_team" + (tblIdx + 1))
    if (!::check_obj(tblObj) || tblObj.num_rows.tointeger() <= playerIdx)
      return false

    tblObj.setValue(playerIdx)
    tblObj.select()
    updateListsButtons()
    return true
  }

  function getMainFocusObj2()
  {
    return getSelectedTable()
  }

  function includeMissionInfoBlocksToGamercard(fill = true)
  {
    if (!::checkObj(scene))
      return

    local blockSample = "textareaNoTab{id:t='%s'; %s overlayTextColor:t='premiumNotEarned'; textShade:t='yes'; text:t='';}"
    local leftBlockObj = scene.findObject("mission_texts_block_left")
    if (::checkObj(leftBlockObj))
    {
      local data = ""
      if (fill)
        foreach(id in ["gc_time_end", "gc_score_limit", "gc_time_to_kick"])
          data += ::format(blockSample, id, "")
      guiScene.replaceContentFromText(leftBlockObj, data, data.len(), this)
    }

    local rightBlockObj = scene.findObject("mission_texts_block_right")
    if (::checkObj(rightBlockObj))
    {
      local data = ""
      if (fill)
        foreach(id in ["gc_spawn_score", "gc_wp_respawn_balance", "gc_race_checkpoints", "gc_mp_tickets_rounds"])
          data += ::format(blockSample, id, "pos:t='pw-w, 0'; position:t='relative';")
      guiScene.replaceContentFromText(rightBlockObj, data, data.len(), this)
    }
  }

  /**
   * Sets country flag visibility for both
   * teams based on players' countries and units.
   */
  function updateCountryFlags()
  {
    local playerTeam = ::get_local_team_for_mpstats()
    if (!needPlayersTbl || playerTeam <= 0)
      return
    local teamObj1 = scene.findObject("team1_info")
    local teamObj2 = scene.findObject("team2_info")
    local countries
    local teamIco

    if (::checkObj(teamObj1))
    {
      countries = isTeamsWithCountryFlags ? getCountriesByTeam(playerTeam) : []
      if (isTeamsWithCountryFlags)
        teamIco = null
      else
        teamIco = isTeamsRandom ? "allies"
          : playerTeam == Team.A ? "allies" : "axis"
      setTeamInfoTeamIco(teamObj1, teamIco)
      setTeamInfoCountries(teamObj1, countries)
    }
    if (!showLocalTeamOnly && ::checkObj(teamObj2))
    {
      countries = isTeamsWithCountryFlags ? getCountriesByTeam(playerTeam == Team.A ? Team.B : Team.A) : []
      if (isTeamsWithCountryFlags)
        teamIco = null
      else
        teamIco = isTeamsRandom ? "axis"
          : playerTeam == Team.A ? "axis" : "allies"
      setTeamInfoTeamIco(teamObj2, teamIco)
      setTeamInfoCountries(teamObj2, countries)
    }
  }

  /**
   * Returns country names list based of players' settings.
   */
  function getCountriesByTeam(team)
  {
    local countries = []
    local players = ::get_mplayers_list(team, true)
    foreach (player in players)
    {
      local country = ::getTblValue("country", player, null)

      // If player/bot has random country we'll
      // try to retrieve country from selected unit.
      // Before spawn bots has wrong unit names.
      if (country == "country_0" && (!player.isDead || player.deaths > 0))
      {
        local unitName = ::getTblValue("aircraftName", player, null)
        local unit = ::getAircraftByName(unitName)
        if (unit != null)
          country = ::getUnitCountry(unit)
      }
      ::u.appendOnce(country, countries, true)
    }
    return countries
  }

  function getEndTimeObj()
  {
    return scene.findObject("gc_time_end")
  }

  function getScoreLimitObj()
  {
    return scene.findObject("gc_score_limit")
  }

  function getTimeToKickObj()
  {
    return scene.findObject("gc_time_to_kick")
  }

  function setGameEndStat(timeLeft)
  {
    local gameEndsObj = getEndTimeObj()
    local scoreLimitTextObj = getScoreLimitObj()

    if (!(gameType & ::GT_VERSUS))
    {
      foreach(obj in [gameEndsObj, scoreLimitTextObj])
        if (::checkObj(obj))
          obj.setValue("")
      return
    }

    if (::get_mp_rounds())
    {
      local rl = ::get_mp_zone_countdown()
      if (rl > 0)
        timeLeft = rl
    }

    if (timeLeft < 0 || (gameType & ::GT_RACE))
    {
      if (!::checkObj(gameEndsObj))
        return

      local val = gameEndsObj.getValue()
      if (typeof val == "string" && val.len() > 0)
        gameEndsObj.setValue("")
    }
    else
    {
      if (::checkObj(gameEndsObj))
        gameEndsObj.setValue(::getCompoundedText(::loc("multiplayer/timeLeft") + ::loc("ui/colon"),
                                                 time.secondsToString(timeLeft, false),
                                                 "activeTextColor"))

      local mp_ffa_score_limit = ::get_mp_ffa_score_limit()
      if (!isTeamplay && mp_ffa_score_limit && ::checkObj(scoreLimitTextObj))
        scoreLimitTextObj.setValue(::getCompoundedText(::loc("options/scoreLimit") + ::loc("ui/colon"),
                                   mp_ffa_score_limit,
                                   "activeTextColor"))
    }
  }
}

class ::gui_handlers.MPStatScreen extends ::gui_handlers.MPStatistics
{
  sceneBlkName = "gui/mpStatistics.blk"
  sceneNavBlkName = "gui/navMpStat.blk"
  shouldBlurSceneBg = true
  keepLoaded = true

  wasTimeLeft = -1
  isFromGame = false
  isWideScreenStatTbl = true
  showAircrafts = true

  function initScreen()
  {
    ::set_mute_sound_in_flight_menu(false)
    ::in_flight_menu(true)

    //!!init debriefing
    isModeStat = true
    isRespawn = true
    isSpectate = false
    isTeam  = true

    local tblObj1 = scene.findObject("table_kills_team1")
    if (tblObj1.childrenCount() == 0)
      initStats()

    if (gameType & ::GT_COOPERATIVE)
    {
      scene.findObject("team1-root").show(false)
      isTeam = false
    }

    includeMissionInfoBlocksToGamercard()
    setSceneTitle(getCurMpTitle())
    tblObj1.setValue(0)
    ::gui_bhv.OptionsNavigator.clearSelect(scene.findObject("table_kills_team2"))

    refreshPlayerInfo()

    showSceneBtn("btn_back", true)

    wasTimeLeft = -1
    scene.findObject("stat_update").setUserData(this)
    isStatScreen = true
    forceUpdate()
    updateListsButtons()

    initFocusArray()
    updateStats()

    showSceneBtn("btn_activateorder", ::g_orders.showActivateOrderButton())
    local ordersButton = scene.findObject("btn_activateorder")
    if (::checkObj(ordersButton))
    {
      ordersButton.setUserData(this)
      ordersButton.inactiveColor = !::g_orders.orderCanBeActivated() ? "yes" : "no"
    }
  }

  function reinitScreen(params)
  {
    setParams(params)
    ::set_mute_sound_in_flight_menu(false)
    ::in_flight_menu(true)
    forceUpdate()
    delayedRestoreFocus()
  }

  function forceUpdate()
  {
    updateCooldown = -1
    onUpdate(null, 0.0)
  }

  function onUpdate(obj, dt)
  {
    local timeLeft = ::get_multiplayer_time_left()
    local timeDif = wasTimeLeft - timeLeft
    if (timeDif < 0)
      timeDif = -timeDif
    if (timeDif >= 1 || ((wasTimeLeft * timeLeft) < 0))
    {
      setGameEndStat(timeLeft)
      wasTimeLeft = timeLeft
    }
    updateTimeToKick(dt)
    updateTables(dt)
  }

  function goBack(obj)
  {
    ::in_flight_menu(false)
    if (isFromGame)
      ::close_ingame_gui()
    else
      ::gui_handlers.BaseGuiHandlerWT.goBack.bindenv(this)()
  }

  function onApply()
  {
    goBack(null)
  }

  function onHideHUD(obj) {}
}

::SquadIcon <- {
  listLabelsSquad = {}
  nextLabel = { team1 = 1, team2 = 1}
  topSquads = {}
}

function SquadIcon::initListLabelsSquad()
{
  listLabelsSquad.clear()
  nextLabel.team1 = 1
  nextLabel.team2 = 1
  topSquads = {}
  updateListLabelsSquad()
}

function SquadIcon::updateListLabelsSquad()
{
  foreach(label in listLabelsSquad)
    label.count = 0;
  local team = ""
  foreach(uid, member in ::SessionLobby.getPlayersInfo())
  {
    team = "team"+member.team
    if (!(team in nextLabel))
      continue

    local squadId = member.squad
    if (squadId == INVALID_SQUAD_ID)
      continue
    if (squadId in listLabelsSquad)
    {
      if (listLabelsSquad[squadId].count < 2)
      {
        listLabelsSquad[squadId].count++
        if (listLabelsSquad[squadId].count > 1 && listLabelsSquad[squadId].label == "")
        {
          listLabelsSquad[squadId].label = nextLabel[team].tostring()
          nextLabel[team]++
        }
      }
    }
    else
      listLabelsSquad[squadId] <- {
        squadId = squadId
        count = 1
        label = ""
        autoSquad = ::getTblValue("auto_squad", member, false)
        teamId = member.team
      }
  }
}

function SquadIcon::getSquadInfo(idSquad)
{
  if (idSquad == INVALID_SQUAD_ID)
    return null
  local squad = (idSquad in listLabelsSquad) ? listLabelsSquad[idSquad] : null
  if (squad == null)
    return null
  else if (squad.count < 2)
    return null
  return squad
}

function SquadIcon::getSquadInfoByMemberName(name)
{
  if (name == "")
    return null
  foreach(uid, member in ::SessionLobby.getPlayersInfo())
    if (member.name == name)
      return getSquadInfo(member.squad)
  return null
}

function SquadIcon::updateTopSquadScore(mplayers)
{
  if (!isShowSquad())
    return
  local teamId = mplayers.len() ? ::getTblValue("team", mplayers[0], null) : null
  if (teamId == null)
    return

  local topSquadId = null

  local topSquadScore = 0
  local squads = {}
  foreach (player in mplayers)
  {
    local squadScore = ::getTblValue("squadScore", player, 0)
    if (!squadScore || squadScore < topSquadScore)
      continue
    local name = ::getTblValue("name", player, "")
    local squadId = ::getTblValue("squadId", getSquadInfoByMemberName(name), INVALID_SQUAD_ID)
    if (squadId == INVALID_SQUAD_ID)
      continue
    if (squadScore > topSquadScore)
    {
      topSquadScore = squadScore
      squads.clear()
    }
    local score = ::getTblValue("score", player, 0)
    if (!(squadId in squads))
      squads[squadId] <- { playerScore = 0, members = 0 }
    squads[squadId].playerScore += score
    squads[squadId].members++
  }

  local topAvgPlayerScore = 0.0
  foreach (squadId, data in squads)
  {
    local avg = data.playerScore * 1.0 / data.members
    if (topSquadId == null || avg > topAvgPlayerScore)
    {
      topSquadId = squadId
      topAvgPlayerScore = avg
    }
  }

  topSquads[teamId] <- topSquadId
}

function SquadIcon::getTopSquadId(teamId)
{
  return ::getTblValue(teamId, topSquads)
}

function SquadIcon::isShowSquad()
{
  if (::SessionLobby.getValueSettings("creator"))
    return false
  return true
}
