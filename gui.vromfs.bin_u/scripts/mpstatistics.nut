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

function mpstat_sort_alive(a, b)
{
  if (("ingame" in a) && ("ingame" in b) && a.ingame != b.ingame)
    return a.ingame ? -1 : 1
  if (a.isBot != b.isBot)
    return b.isBot ? -1 : 1
  //if (a.isDead != b.isDead)
  //  return b.isDead ? -1 : 1
  return ::mpstat_sort_rowNo(a, b)
}

function mpstat_sort_rowNo(a, b)
{
  return (a.rowNo > b.rowNo)? 1 : (a.rowNo < b.rowNo ? -1 : 0)
}

function get_local_team_for_mpstats()
{
  return ::get_mp_local_team() != Team.B ? Team.A : Team.B
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
  local curHandler = ::handlersManager.getActiveBaseHandler()
  return curHandler != null && (curHandler instanceof ::gui_handlers.MPStatScreen)
}

function build_mp_table(table, markup, hdr, max_rows)
{
  local numTblRows = table.len()
  local numRows = ::max(numTblRows, max_rows)
  if (numRows <= 0)
    return ""

  local is_header = ::getTblValue("is_header", markup, false)
  local tr_size = ::getTblValue("tr_size", markup, "pw,@baseTrHeight")
  local row_invert = ::getTblValue("invert", markup, false)

  if (row_invert)
  {
    hdr = clone hdr
    hdr.reverse()
  }

  local data = ""

  if (is_header)
  {
    local headerView = {
      trSize = tr_size
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
        tdData += "size:t='ph"+widthAdd+" ,ph';"  +
          ("img{ pos:t='(pw-w)/2,(ph-h)/2'; position:t='relative'; size:t='@tableIcoSize,@tableIcoSize'; background-image:t='" + icon + "'; }")
      }
      else if (hdr[j] == "name")
      {
        local textDiv = "textareaNoTab"
        local nameWidth = ((hdr[j] in markup)&&("width" in markup[hdr[j]]))?markup[hdr[j]].width:"0.5pw-0.035sh"
        local nameAlign = row_invert? "text-align:t='right' " : ""
        local isReady = !isEmpty && (("state" in table[i]) && table[i].state == ::PLAYER_IN_LOBBY_READY)
        local playerImage = "";
        local playerStateDesc = ""
        local needReadyIcon = (!("readyIcon" in markup.name)) || markup.name.readyIcon
        textPadding = "style:t='padding:" + (row_invert? "1.5@tableIcoSize,0,1@tablePad,0" : "1@tablePad,0,1.5@tableIcoSize,0") + ";'"

        if (!isEmpty)
        {
          if (!needReadyIcon)
            trData += (table[i].state != ::PLAYER_IN_FLIGHT && table[i].state != ::PLAYER_IN_RESPAWN) ? "inGame:t='yes'; " : "inGame:t='no'; "
          else
          {
            playerImage = ::getPlayerStateIco(table[i])
            playerStateDesc = ::getPlayerStateDesc(table[i])
          }
        }

        local playerStateTooltip = (playerStateDesc != "") ? (::loc("multiplayer/state") + ::loc("ui/colon") + playerStateDesc) : ""
        local playerIcoDiv = (!needReadyIcon) ? "" :
                                 format("img { id:t='ready-ico'; size:t='@tableIcoSize,@tableIcoSize'; background-image:t='%s'; tooltip:t='%s' } "
                                       playerImage, playerStateTooltip)

        //update air weapons and dead icons
        local isAircraft = (!isEmpty) && ("aircraftName" in table[i])
        local isDead = (!isEmpty) && ("isDead" in table[i]) && table[i].isDead
        local airWeaponIcons = ("name" in markup) && ("airWeaponIcons" in markup.name) && markup.name.airWeaponIcons
        local unitIcoColorType = ""
        local unitIco = ""
        if (isDead)
          unitIco = "#ui/gameuiskin#dead"
        else if (airWeaponIcons && isAircraft)
        {
          local name = table[i].aircraftName;
          unitIco = getUnitClassIco(name);
          unitIcoColorType = ::get_unit_role(name);
        }

        local airImgText = format(
          "img { id:t='aircraft-ico'; size:t='@tableIcoSize,@tableIcoSize'; background-image:t='%s'; shopItemType:t='%s'; } ",
          unitIco, unitIcoColorType)
        local weapText = ""

        if (airWeaponIcons)
        {
          local weaponType = (!isDead && isAircraft && ("weapon" in table[i]))?
                                getWeaponTypeIcoByWeapon(table[i].aircraftName, table[i].weapon)
                                : getWeaponTypeIcoByWeapon("", "")
          foreach(name, weap in weaponType)
            weapText += format("img { id:t='%s-ico'; size:t='0.375@tableIcoSize,@tableIcoSize'; background-image:t='%s'; margin-right:t='2' } ",
                                     name, weap)
        }
        playerIcoDiv += row_invert? airImgText + weapText : weapText + airImgText
        //update icons finished

        if (playerIcoDiv != "")
          playerIcoDiv = format("tdiv { pos:t='%s, 0.5ph-0.5h'; position:t='absolute'; %s} ",
                           row_invert? "0" : "pw-w-1", playerIcoDiv)

        local nameText = item || ""
        if (!isEmpty && "clanTag" in table[i] && table[i].clanTag != "")
          nameText = table[i].clanTag + " " + nameText

        local data = ""
        tdData += format ("width:t='%s'; %s { id:t='name-text'; %s text:t = '%s'; pare-text:t='yes'; width:t='pw'; halign:t='center'; top:t='(ph-h)/2';} %s%s"
          nameWidth, textDiv, nameAlign, nameText, playerIcoDiv, textPadding
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
        local data = row_invert? prestigeItem + rankItem : rankItem + prestigeItem
        tdData += format("width:t='2.2@rows16height%s'; tdiv { pos:t='%s, 0.5(ph-h)'; position:t='absolute'; " + data + " } ",
                    widthAdd, row_invert? "0" : "pw-w-1", "0", "0.003sh")
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
      else if (::isInArray(hdr[j], [ "aiTotalKills", "damageZone", "raceFinishTime", "raceLastCheckpoint", "raceLastCheckpointTime", "raceBestLapTime" ]))
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
              getTblValue("colorTeam", markup, "blue"), "icon_"+hdr[j], markup[hdr[j]].image
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
      data += "tr {size:t = '" + tr_size + "'; " + trAdd + trData + " text-valign:t='center'; css-hier-invalidate:t='all'; }\n"
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

    local totalCells = objTr.childrenCount()
    for (local idx = 0; idx < totalCells; idx++)
    {
      local objTd = objTr.getChild(idx)
      local id = objTd.id
      if (!id || id.len()<4 || id.slice(0, 3)!="td_")
        continue

      local hdr = id.slice(3)
      local item = ""
      local isEmpty = i >= numTblRows

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
      else if (hdr == "name")
      {
        local objName = objTd.findObject("name-text")
        local objReady = objTd.findObject("ready-ico")
        local objDlcImg = objTd.findObject("dlc-ico")
        local objAircraft = objTd.findObject("aircraft-ico")
        local objWeapon = null
        local nameText = ""

        if (!isEmpty)
        {
          nameText = item
          local prepPlayer = false
          if ("clanTag" in table[i] && table[i].clanTag != "")
            nameText = table[i].clanTag + " " + nameText
          if ("invitedName" in table[i])
          {
            local color = ""
            if (obj_tbl.team)
              if (obj_tbl.team == "red")
                color = "teamRedInactiveColor"
              else if (obj_tbl.team == "blue")
                color = "teamBlueInactiveColor"

            local playerName = table[i].invitedName
            if (color != "")
              playerName = "<color=@" + color + ">" + table[i].invitedName + "</color>"
            nameText = ::format("%s... %s", nameText, playerName)
          }

          if (objName)
            objName.setValue(nameText)

          local unitIco = ""
          local unitIcoColorType = ""
          if (::checkObj(objReady) && ("state" in table[i]))
          {
            objReady["background-image"] = ::getPlayerStateIco(table[i])
            local desc = ::getPlayerStateDesc(table[i])
            objReady.tooltip = (desc != "") ? (::loc("multiplayer/state") + ::loc("ui/colon") + desc) : ""
          }
          else
          {
            local inGame = !("state" in table[i]) || (table[i].state == ::PLAYER_IN_FLIGHT) || (table[i].state == ::PLAYER_IN_RESPAWN) ||
              !objAircraft
            objTr["inGame"] = inGame? "yes" : "no"
            if (!inGame)
              unitIco = "#ui/gameuiskin#player_not_ready"
          }

          if (objDlcImg)
            objDlcImg.show(false)

          local isAircraft = "aircraftName" in table[i]
          local isDead = ("isDead" in table[i]) && table[i].isDead
          if (unitIco=="")
          {
            if (isDead)
            {
              if (::getTblValue("spectator", table[i], false))
                unitIco = "#ui/gameuiskin#player_spectator"
              else
                unitIco = "#ui/gameuiskin#dead"
            }
            else if (isAircraft && showAirIcons)
            {
              local name = table[i].aircraftName;
              unitIco = getUnitClassIco(name);
              unitIcoColorType = ::get_unit_role(name);
            }
          }
          if (objAircraft)
          {
            objAircraft["background-image"] = unitIco
            objAircraft["shopItemType"] = unitIcoColorType
          }

          if (showAirIcons)
          {
            local weaponType = (!isDead && isAircraft && ("weapon" in table[i]))?
                                  getWeaponTypeIcoByWeapon(table[i].aircraftName, table[i].weapon)
                                  : getWeaponTypeIcoByWeapon("", "")
            foreach(name, weap in weaponType)
            {
              objWeapon = objTd.findObject(name + "-ico")
              if (objWeapon)
                objWeapon["background-image"] = weap
            }
          }
        }
        else
        {
          if (objReady)
          {
            objReady["background-image"] = ""
            objReady.tooltip = ""
          }
          if (objName)     objName.setValue("")
          if (objDlcImg)   objDlcImg.show(false)
          if (objAircraft) objAircraft["background-image"] = ""
          local weaponType = getWeaponTypeIcoByWeapon("", "")
          foreach(name, weap in weaponType)
          {
            objWeapon = objTd.findObject(name + "-ico")
            if (objWeapon)
              objWeapon["background-image"] = ""
          }
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
      else if (::isInArray(hdr, [ "aiTotalKills", "damageZone", "raceFinishTime", "raceLastCheckpoint", "raceLastCheckpointTime", "raceBestLapTime" ]))
      {
        local txt = isEmpty ? "" : ::g_mplayer_param_type.getTypeById(hdr).printFunc(item, table[i])
        local objText = objTd.getChild(0)
        objText.setValue(txt)
        objText.tooltip = txt
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
        local squadId = ::getTblValue("squadId", squadInfo, ::INVALID_SQUAD_ID)
        local labelSquad = squadInfo ? squadInfo.label.tostring() : ""
        local needSquadIcon = labelSquad != ""
        local squadScore = needSquadIcon ? ::getTblValue("squadScore", table[i], 0) : 0
        local isTopSquad = needSquadIcon && squadScore && squadId != ::INVALID_SQUAD_ID && squadId == ::SquadIcon.getTopSquadId(squadInfo.teamId)

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

function getPlayerStateIco(playerInfo)
{
  local stateTextId = ::getPlayerStateTextId(playerInfo)
  local isSpectator = ::getTblValue("spectator", playerInfo, false)
  if (isSpectator)
    stateTextId = (stateTextId == "player_ready" || stateTextId == "player_in_game") ? "player_spectator" : "player_spectator_not_ready"
  return stateTextId.len() ? ("#ui/gameuiskin#" + stateTextId) : ""
}

function getPlayerStateDesc(playerInfo)
{
  local stateTextId = ::getPlayerStateTextId(playerInfo)
  local isSpectator = ::getTblValue("spectator", playerInfo, false)
  local stateLoc = stateTextId.len() ? ::loc("multiplayer/state/" + stateTextId) : ""
  local roleLoc = isSpectator ? ::loc("multiplayer/state/player_referee") : ""
  return ::implode([ roleLoc, stateLoc ], ::loc("ui/semicolon"))
}

function getUnitClassIco(unit)
{
  if (::u.isString(unit))
    unit = ::getAircraftByName(unit)
  if (!unit)
    return ""

  if ("customClassIco" in unit)
    return unit.customClassIco

  return ::get_unit_icon_by_unit_type(::get_es_unit_type(unit), unit.name + "_ico")
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

function count_width_for_mptable(objTbl, markupData, tblData)
{
  local guiScene = objTbl.getScene()
  local usedWidth = 0
  local relWidthTotal = 0.0
  foreach (id in tblData)
  {
    if ("relWidth" in markupData[id])
      relWidthTotal += markupData[id].relWidth
    else if ("width" in markupData[id])
    {
      local width = guiScene.calcString(markupData[id].width, objTbl)
      markupData[id].width = width.tostring()
      usedWidth += width
    }
  }

  local freeWidth = objTbl.getSize()[0] - usedWidth
  foreach (id in tblData)
  {
    if (relWidthTotal > 0 && ("relWidth" in markupData[id]))
    {
      local cell = markupData[id]
      local width = (freeWidth * cell.relWidth / relWidthTotal).tointeger()
      cell.width <- width.tostring()
      freeWidth -= width
      relWidthTotal -= cell.relWidth
      delete cell.relWidth
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

  missionObjectives = MISSION_OBJECTIVE.NONE

  wasTimeLeft = -1000
  updateCooldown = 3

  numMaxPlayers = 16  //its only visual max players. no need to scroll when table near empty.
  isApplyPressed = false

  checkRaceDataOnStart = true
  numberOfWinningPlaces = -1

  defaultRowHeaders         = ["squad", "name", "aircraft", "score", "kills", "groundKills", "navalKills", "aiKills",
                               "aiGroundKills", "aiNavalKills", "aiTotalKills", "assists", "captureZone", "damageZone", "deaths"]
  raceRowHeaders            = ["rowNo", "name", "aircraft", "raceFinishTime", "raceLap", "raceLastCheckpoint",
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
      local timeToKickText = ::secondsToString(timeToKickValue, true, true)
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

    missionObjectives = ::g_mission_type.getCurrentObjectives()

    local playerTeam = ::get_local_team_for_mpstats()
    local friendlyTeam = ::get_player_army_for_hud()
    local teamObj1 = scene.findObject("team1_info")
    local teamObj2 = scene.findObject("team2_info")
    local countries

    if (gameType & (::GT_RACE | ::GT_FREE_FOR_ALL))
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

    local sourceHeaders = gameType & ::GT_RACE ? raceRowHeaders : defaultRowHeaders
    local tblData = []
    foreach (id in sourceHeaders)
      if (::g_mplayer_param_type.getTypeById(id).isVisible(missionObjectives))
        tblData.append(id)

    if (!showAircrafts)
      ::u.removeFrom(tblData, "aircraft")
    if (!::SquadIcon.isShowSquad())
      ::u.removeFrom(tblData, "squad")

    local markupData = {
      tr_size = statTrSize
      invert = invert
    }

    if (gameType & ::GT_COOPERATIVE)
    {
      tblData = ["name"]
      markupData["name"] <- {width = "pw - ph - 1@tablePad", airWeaponIcons = showAircrafts, readyIcon = false}
    }
    else
    {
      foreach(name in tblData)
        markupData[name] <- ::g_mplayer_param_type.getTypeById(name).getMarkupData()

      if ("name" in markupData)
      {
        markupData["name"].airWeaponIcons = showAirIcons

        if (isWideScreenStatTbl && ("widthInWideScreen" in markupData["name"]))
          markupData["name"].width = markupData["name"].widthInWideScreen
      }

      ::count_width_for_mptable(objTbl, markupData, tblData)

      local teamNum = (team==2)? 2 : 1
      local tableObj = scene.findObject("team_table_" + teamNum)
      if (team == 2)
        markupData.colorTeam <- "red"
      if (::checkObj(tableObj))
      {
        local rowHeaderData = createHeaderRow(tableObj, tblData, markupData, teamNum)
        local show = rowHeaderData != "" && (tbl && tbl.len() > 0)
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
      if (gameType & (::GT_RACE | ::GT_FREE_FOR_ALL))
        sortTable(tbl)

      local data = ::build_mp_table(tbl, markupData, tblData, num_rows)
      guiScene.replaceContentFromText(objTbl, data, data.len(), this)
      objTbl.num_rows = tbl.len()
      objTbl.show(tbl.len() != 0)
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

    local showSecondTable = true
    if (customTbl)
    {
      local idx = max(team-1, -1)
      if (idx in customTbl)
        tbl = customTbl[idx]

      showSecondTable = objTbl.id == "table_kills_team2" && tbl && tbl.len() > 0
    }

    local minRow = 0
    if (!tbl)
    {
      if (gameType & (::GT_RACE | ::GT_FREE_FOR_ALL))
      {
        local commonTbl = ::get_mplayers_list(::GET_MPLAYERS_LIST, true)
        sortTable(commonTbl)
        if (commonTbl.len() > 0)
        {
          if (objTbl.id == "table_kills_team2")
            minRow = commonTbl.len() <= (::global_max_players_versus / 2)? 0 : ::global_max_players_versus / 2
          else
            minRow = 0

          local lastRow = minRow + ::global_max_players_versus / 2 - 1
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
        if (objTbl.id == "table_kills_team2")
          showSecondTable = commonTbl.len() >= ::global_max_players_versus / 2
      }
      else
        tbl = ::get_mplayers_list(team, true)
    }
    else if ((gameType & (::GT_RACE | ::GT_FREE_FOR_ALL)) && customTbl && objTbl.id == "table_kills_team2")
      minRow = ::global_max_players_versus / 2

    local secondTblObj = scene.findObject("team2-root")
    if (::checkObj(secondTblObj))
      secondTblObj.show(showSecondTable)

    if ((gameType & (::GT_RACE | ::GT_FREE_FOR_ALL)) && minRow >= 0)
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
      if (!customTbl && !(gameType & (::GT_RACE | ::GT_FREE_FOR_ALL)))
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

      if (!(gameType & (::GT_RACE | ::GT_FREE_FOR_ALL)) && friendlyTeam > 0 && team > 0)
        objTbl["team"] = (friendlyTeam==team)? "blue" : "red"
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

    if (gameType & (::GT_RACE | ::GT_FREE_FOR_ALL))
    {
      local tbl1 = ::get_mplayers_list(::GET_MPLAYERS_LIST, true)
      tbl1.sort(::mpstat_sort_rowNo)

      local tbl2 = []
      numRows1 = tbl1.len()
      numRows2 = 0
      if (tbl1.len() >= ::global_max_players_versus / 2)
      {
        numRows1 = numRows2 = ::global_max_players_versus / 2

        for(local i = tbl1.len()-1; i >= ::global_max_players_versus / 2; --i)
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

  function updateTeams(tbl)
  {
    if (!tbl)
      return

    local playerTeam = ::get_local_team_for_mpstats()
    local friendlyTeam = ::get_player_army_for_hud()
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

  function updateStats(customTbl = null, customTblTeams = null)
  {
    local playerTeam = ::get_local_team_for_mpstats()
    local friendlyTeam = ::get_player_army_for_hud()
    local tblObj1 = scene.findObject("table_kills_team1")
    local tblObj2 = scene.findObject("table_kills_team2")

    if (needPlayersTbl)
    {
      if (gameType & (::GT_VERSUS | ::GT_RACE | ::GT_FREE_FOR_ALL))
      {
        if (gameType & (::GT_RACE | ::GT_FREE_FOR_ALL))
          playerTeam = Team.A

        setKillsTbl(tblObj1, playerTeam, playerTeam, friendlyTeam, showAircrafts, customTbl)
        if (!showLocalTeamOnly && playerTeam > 0)
          setKillsTbl(tblObj2, 3 - playerTeam, playerTeam, friendlyTeam, isShowEnemyAirs(), customTbl)
      }
      else
        setKillsTbl(tblObj2, -1, -1, -1, showAircrafts, customTbl)
    }

    if (playerTeam > 0)
      updateTeams(customTblTeams || ::get_mp_tbl_teams())

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
        || markupData.len() == 0
        || !::checkObj(tableObj))
      return ""

    local tblData = clone hdr

    if (::getTblValue("invert", markupData, false))
      tblData.reverse()

    local view = {cells = []}
    foreach(name in tblData)
    {
      local value = ::getTblValue(name, markupData)
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

  function onComplain(obj) {}

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
    session_player_rmenu(this, getSelectedPlayer())
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

  function onChangeTeam()
  {

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

    local player = getSelectedPlayer();
    showSceneBtn("btn_usercard", isOnline && player && !player.isBot && !isSpectate)
    showSceneBtn("btn_kick", isOnline && ::is_mplayer_host() && player && !player.isLocal && !player.isBot)
    ::SquadIcon.updateListLabelsSquad()
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
    local teamObj1 = scene.findObject("team1_info")
    local teamObj2 = scene.findObject("team2_info")
    local playerTeam = ::get_local_team_for_mpstats()
    local countries
    local teamIco
    local needCountryFlags = getNeedCountryFlags()
    if (!needPlayersTbl || playerTeam <= 0)
      return
    if (::checkObj(teamObj1))
    {
      countries = needCountryFlags ? getCountriesByTeam(playerTeam) : []
      if (needCountryFlags)
        teamIco = null
      else
        teamIco = playerTeam == Team.A ? "allies" : "axis"
      setTeamInfoTeamIco(teamObj1, teamIco)
      setTeamInfoCountries(teamObj1, countries)
    }
    if (!showLocalTeamOnly && ::checkObj(teamObj2))
    {
      countries = needCountryFlags ? getCountriesByTeam(playerTeam == Team.A ? Team.B : Team.A) : []
      if (needCountryFlags)
        teamIco = null
      else
        teamIco = (playerTeam == Team.A) ? "axis" : "allies"
      setTeamInfoTeamIco(teamObj2, teamIco)
      setTeamInfoCountries(teamObj2, countries)
    }
  }

  /**
   * Returns false if both teams have all countries available.
   */
  function getNeedCountryFlags()
  {
    foreach (team in ::events.getSidesList())
    {
      if (getCountriesByTeam(team).len() < ::shopCountriesList.len())
        return true
    }
    return false
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
      ::append_once(country, countries, true)
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

    if (!(::get_game_type() & ::GT_VERSUS))
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

    if (timeLeft < 0 || (::get_game_type() & ::GT_RACE))
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
                                                 ::secondsToString(timeLeft, false),
                                                 "activeTextColor"))

      local mp_ffa_score_limit = ::get_mp_ffa_score_limit()
      if ((::get_game_type() & ::GT_FREE_FOR_ALL) && mp_ffa_score_limit && ::checkObj(scoreLimitTextObj))
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

  function onComplain(obj)
  {
    local pInfo = getSelectedInfo()
    if (!pInfo || pInfo.isBot || pInfo.isLocal)
      return

    ::gui_modal_complain(pInfo)
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
    if (squadId == ::INVALID_SQUAD_ID)
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
  if (idSquad == ::INVALID_SQUAD_ID)
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
    local squadId = ::getTblValue("squadId", getSquadInfoByMemberName(name), ::INVALID_SQUAD_ID)
    if (squadId == ::INVALID_SQUAD_ID)
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
