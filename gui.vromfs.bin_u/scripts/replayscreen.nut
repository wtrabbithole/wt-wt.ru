local time = require("scripts/time.nut")


const REPLAY_SESSION_ID_MIN_LENGHT = 16

::autosave_replay_max_count <- 100
::autosave_replay_prefix <- "#"
::replays_per_page <- 20

::current_replay <- ""
::current_replay_author <- null
::back_from_replays <- null

::g_script_reloader.registerPersistentData("ReplayScreenGlobals", ::getroottable(), ["current_replay", "current_replay_author"])

function gui_start_replays()
{
  ::gui_start_modal_wnd(::gui_handlers.ReplayScreen)
}

function gui_start_menuReplays()
{
  ::gui_start_mainmenu()
  ::gui_start_replays()
}

function gui_start_worldWar()
{
  ::g_world_war.openMainWnd()
}

function gui_start_replay_battle(sessionId, backFunc)
{
  ::back_from_replays = backFunc
  ::req_unlock_by_client("view_replay", false)
  ::current_replay = ::get_replay_url_by_session_id(sessionId)
  ::current_replay_author = null
  ::on_view_replay(::current_replay)
}

function get_replay_url_by_session_id(sessionId)
{
  local sessionIdText = ::format("%0" + REPLAY_SESSION_ID_MIN_LENGHT + "s", sessionId.tostring())
  return ::loc("url/server_wt_game_replay", {sessionId = sessionIdText})
}

function gui_modal_rename_replay(base_name, base_path, func_owner, after_rename_func, after_func = null)
{
  ::gui_start_modal_wnd(::gui_handlers.RenameReplayHandler, {
                                                              baseName = base_name
                                                              basePath = base_path
                                                              funcOwner = func_owner
                                                              afterRenameFunc = after_rename_func
                                                              afterFunc = after_func
                                                            })
}

function gui_modal_name_and_save_replay(func_owner, after_func)
{
  local baseName = ::get_new_replay_filename();
  local basePath = ::get_replays_dir() + "\\" + baseName;
  ::gui_modal_rename_replay(baseName, basePath, func_owner, null, after_func);
}

function autosave_replay()
{
  if (::is_replay_saved())
    return;
  if (!::get_option_autosave_replays())
    return;
  if (::get_game_mode() == ::GM_BENCHMARK)
    return;

  local replays = ::get_replays_list();
  local autosaveCount = 0;
  for (local i = 0; i < replays.len(); i++)
  {
    if (replays[i].name.slice(0,1) == ::autosave_replay_prefix)
      autosaveCount++;
  }
  local toDelete = autosaveCount - (::autosave_replay_max_count - 1);
  for (local d = 0; d < toDelete; d++)
  {
    local indexToDelete = -1;
    for (local i = 0; i < replays.len(); i++)
    {
      if (replays[i].name.slice(0,1) != ::autosave_replay_prefix)
        continue;

      if ((("corrupted" in replays[i]) && replays[i].corrupted) ||
        ("isVersionMismatch" in replays[i]) && replays[i].isVersionMismatch)
      {
        indexToDelete = i;
        break;
      }
    }
    if (indexToDelete < 0)
    {
      //sort by time
      local oldestDate = null;
      for (local i = 0; i < replays.len(); i++)
      {
        if (replays[i].name.slice(0,1) != ::autosave_replay_prefix)
          continue;

        if (!oldestDate || time.cmpDate(replays[i].dateTime, oldestDate) < 0)
        {
          oldestDate = replays[i].dateTime;
          indexToDelete = i;
        }
      }
    }

    if (indexToDelete >= 0)
    {
      ::on_del_replay(replays[indexToDelete].path);
      replays.remove(indexToDelete);
    }
  }

  local name = ::autosave_replay_prefix + ::get_new_replay_filename();
  ::on_save_replay(name); //ignore errors
}

class ::gui_handlers.ReplayScreen extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/chapterModal.blk"
  sceneNavBlkName = "gui/navReplays.blk"
  replays = null
  isReplayPressed = false
  curPage = 0

  statsColumnsOrderPvp  = [ "team", "name", "missionAliveTime", "score", "kills", "groundKills", "awardDamage", "navalKills", "aiKills",
                            "aiGroundKills", "aiNavalKills", "aiTotalKills", "assists", "captureZone", "damageZone", "deaths" ]
  statsColumnsOrderRace = [ "team", "rowNo", "name", "raceFinishTime", "raceLap", "raceLastCheckpoint", "raceBestLapTime", "deaths" ]

  markup_mptable = {
    invert = false
    colorTeam = ""
    columns = {
      name = { width = "1@nameWidth +1@tablePad" }
    }
  }

  function initScreen()
  {
    ::set_presence_to_player("menu")
    scene.findObject("chapter_name").setValue(::loc("mainmenu/btnReplays"))
    scene.findObject("chapter_include_block").show(true)
    showSceneBtn("btn_open_folder", ::is_platform_windows)

    ::update_gamercards()
    getReplays()

    local selItem = 0
    if (::current_replay != "")
    {
      foreach(index, replay in replays)
        if (replay.path == ::current_replay)
        {
          curPage = index / ::replays_per_page
          selItem = index
          break
        }
      ::current_replay = ""
      ::current_replay_author = null
    }

    refreshList(selItem)
  }

  function goToPage(obj)
  {
    curPage = obj.to_page.tointeger()
    refreshList()
  }

  function getReplays()
  {
    replays = ::get_replays_list()
    replays.sort(@(a,b) b.startTime <=> a.startTime)
  }

  function refreshList(selItem = 0)
  {
    local listObj = scene.findObject("items_list")
    if (!::checkObj(listObj))
      return

    if (selItem == 0)
    {
      local index = listObj.getValue()
      if (index >= 0 && index < listObj.childrenCount())
      {
        index--
        if (index < 0)
          index = 0
        selItem = index
      }
      selItem += curPage * ::replays_per_page
    }

    local view = { items = [] }
    local lastIdx = ::min(replays.len(), ((curPage + 1) * ::replays_per_page))
    for (local i = curPage * ::replays_per_page; i < lastIdx; i++)
    {
      local iconName = "";
      local autosave = ::g_string.startsWith(replays[i].name, ::autosave_replay_prefix)
      local corrupted = (("corrupted" in replays[i]) && replays[i].corrupted) ||
        ("isVersionMismatch" in replays[i]) && replays[i].isVersionMismatch
      if (corrupted)
        iconName = "#ui/gameuiskin#icon_primary_fail"
      else if (autosave)
        iconName = "#ui/gameuiskin#slot_modifications.svg"

      view.items.append({
        itemIcon = iconName
        id = "replay_" + i
        isSelected = i == selItem
      })
    }

    local data = ::handyman.renderCached("gui/missions/missionBoxItemsList", view)
    guiScene.replaceContentFromText(listObj, data, data.len(), this)

    //* - text addition is ok
    //depends on ::get_new_replay_filename() format
    local defaultReplayNameMask =
      regexp2(@"2\d\d\d\.[0-3]\d\.[0-3]\d [0-2]\d\.[0-5]\d\.[0-5]\d*");
    for (local i = curPage * ::replays_per_page; i < lastIdx; i++)
    {
      local obj = scene.findObject("txt_replay_" + i);
      local name = replays[i].name;
      local hasDateInName = ::g_string.startsWith(name, ::autosave_replay_prefix) || defaultReplayNameMask.match(name)
      local isCorrupted = ::getTblValue("corrupted", replays[i], false) || ::getTblValue("isVersionMismatch", replays[i], false)
      if (!hasDateInName && !isCorrupted)
      {
        local startTime = ::getTblValue("startTime", replays[i], 0) || (("dateTime" in replays[i]) ? ::mktime(replays[i].dateTime) : 0)
        if (startTime)
        {
          local date = time.buildDateTimeStr(::get_time_from_t(startTime))
          name += ::colorize("fadedTextColor", ::loc("ui/parentheses/space", { text = date }))
        }
      }
      obj.setValue(name);
    }

    scene.findObject("optionlist-include").show(replays.len()>0)
    scene.findObject("info-text").setValue(replays.len()? "" : ::loc("mainmenu/noReplays"))
    if (replays.len() > 0)
    {
      doOpenInfo(selItem)
      doSelectList()
      showSceneBtn("btn_del_replay", true)
    }
    else
      foreach(btnName in ["btn_view_replay", "btn_upload_replay", "btn_rename_replay", "btn_del_replay"])
        showSceneBtn(btnName, false)

    ::generatePaginator(scene.findObject("paginator_place"),
                        this,
                        curPage,
                        ((replays.len() - 1) / ::replays_per_page).tointeger())
  }

  function doOpenInfo(index)
  {
    local objDesc = scene.findObject("item_desc")
    //local objPic = objDesc.findObject("item_picture")
    //if (objPic != null)
    //{
    //  objPic["background-color"] = "#FFFFFFFF"
    //  objPic["background-image"] = pic
    //}

    if (index < 0 || index >= replays.len())
    {
      objDesc.findObject("item_desc_text").setValue("")
      return
    }

    local replayInfo = null
    replayInfo = ::get_replay_info(replays[index].path)
    if (replayInfo == null)
    {
      objDesc.findObject("item_name").setValue(replays[index].name)
      objDesc.findObject("item_desc_text").setValue(::loc("msgbox/error_header"))
    }
    else
    {
      local corrupted = ::getTblValue("corrupted", replayInfo, false) // Any error reading headers (including version mismatch).
      local isVersionMismatch = ::getTblValue("isVersionMismatch", replayInfo, false) // Replay was recorded for in older game version.
      local isHeaderUnreadable = corrupted && !isVersionMismatch // Failed to read header (file not found or incomplete).

      local canWatch  = ::is_replay_turned_on() && (!corrupted || ::is_dev_version) && !::is_in_leaderboard_menu
      local canUpload = ::is_replay_turned_on() && !corrupted && ::is_in_leaderboard_menu && ::can_upload_replay()
      showSceneBtn("btn_view_replay", canWatch)
      showSceneBtn("btn_upload_replay", canUpload)
      showSceneBtn("btn_rename_replay", true)

      local headerText = ""
      local text = ""
      if (corrupted)
      {
        text = ::loc(isVersionMismatch ? "replays/versionMismatch" : "replays/corrupted")
        if (::is_dev_version && ("error" in replays[index]))
          text += ::colorize("warningTextColor", "\nDEBUG: " + replays[index].error) + "\n\n"

        if (!::is_dev_version || isHeaderUnreadable)
        {
          objDesc.findObject("item_name").setValue(replays[index].name)
          objDesc.findObject("item_desc_text").setValue(text)
          local tableObj = scene.findObject("session_results")
          if (::checkObj(tableObj))
            tableObj.show(false)
          return
        }
      }

      local startTime = ::getTblValue("startTime", replayInfo, 0) || (("dateTime" in replayInfo) ? ::mktime(replayInfo.dateTime) : 0)
      if (startTime)
        text += ::loc("options/mission_start_time") + ::loc("ui/colon") + time.buildDateTimeStr(::get_time_from_t(startTime)) + "\n"

      if (replayInfo.multiplayerGame)
        headerText += ::loc("mainmenu/btnMultiplayer")
      if (replayInfo.missionName.len() > 0)
      {
        if (replayInfo.multiplayerGame)
          headerText += ::loc("ui/colon");
        headerText += get_mission_name(replayInfo.missionName, replayInfo)
      }
      text += ::loc("options/time") + ::loc("ui/colon") + ::get_mission_time_text(replayInfo.environment) + "\n"
      text += ::loc("options/weather") + ::loc("ui/colon") + ::loc("options/weather" + replayInfo.weather) + "\n"
      text += ::loc("options/difficulty") + ::loc("ui/colon") + ::loc("difficulty" + replayInfo.difficulty) + "\n"

/*      local limits = ""
      if (replayInfo.isLimitedFuel && replayInfo.isLimitedAmmo)
        limits = ::loc("options/limitedFuelAndAmmo")
      else if (replayInfo.isLimitedFuel)
        limits = ::loc("options/limitedFuel")
      else if (replayInfo.isLimitedAmmo)
        limits = ::loc("options/limitedAmmo")
      else
        limits = ::loc("options/unlimited")

      text += ::loc("options/fuel_and_ammo") + ::loc("ui/colon") + limits + "\n" */
      local autosave = ::g_string.startsWith(replays[index].name, ::autosave_replay_prefix) //not replayInfo
      if (autosave)
        text += ::loc("msg/autosaveReplayDescription") + "\n"
      text += createSessionResultsTable(replayInfo)
      if ("sessionId" in replayInfo)
        text += ::loc("options/session") + ::loc("ui/colon") + replayInfo.sessionId + "\n"

      local fps = replays[index].text
      if (fps.len())
        text += fps + (::g_string.endsWith(fps, "\n") ? "" : "\n")

      objDesc.findObject("item_name").setValue(headerText)
      objDesc.findObject("item_desc_text").setValue(text)
    }
  }

  function createSessionResultsTable(replayInfo)
  {
    local addDescr = ""
    local tables = ""
    if (::has_feature("extendedReplayInfo") && "comments" in replayInfo)
    {
      local gameType = replayInfo?.gameType ?? 0
      local gameMode = replayInfo?.gameMode
      local replayResultsTable = gatherReplayCommentData(replayInfo, gameType, gameMode)
      addDescr = ::getTblValue("addDescr", replayResultsTable, "")

      foreach (name in replayResultsTable.tablesArray)
      {
        local rows = replayResultsTable.playersRows[name]
        tables += ::format("table{id:t='%s_table'; width:t='pw'; baseRow:t='yes' %s}",
          name, rows + ::getTblValue(name, replayResultsTable.addTableParams, ""))
      }
    }
    local tablesObj = scene.findObject("session_results")
    if (::checkObj(tablesObj))
    {
      tablesObj.show(tables!="")
      guiScene.replaceContentFromText(tablesObj.findObject("results_table_place"), tables, tables.len(), this)
    }

    return addDescr
  }

  function gatherReplayCommentData(replayInfo, gameType, gameMode)
  {
    local replayComments = ::getTblValue("comments", replayInfo)
    if (!replayComments)
      return

    local data = {
      addDescr = ""
      playersRows = {}
      markups = {}
      headerArray = {}
      tablesArray = []
      rowHeader = {}
      addTableParams = {}
    }
    local playersTables = {}
    local addTableParams = {teamA = {}, teamB = {}}
    local replayParams = ["timePlayed", "author"]

    local isRace = !!(gameType & ::GT_RACE)
    local columnsOrder = isRace ? statsColumnsOrderRace : statsColumnsOrderPvp

    foreach(name in replayParams)
    {
      local value = ::getTblValue(name, replayComments)
      if (!value)
        continue

      if (name == "timePlayed")
        value = time.secondsToString(value)
      data.addDescr += (::loc("options/" + name) + ::loc("ui/colon") + value + "\n")
    }

    local authorUserId = ::getTblValue("authorUserId", replayComments, "-1")

    if (replayComments.blockCount() > 0)
    {
      local playersList = []
      for (local i = 0; i < replayComments.blockCount(); i++)
      {
        local block = replayComments.getBlock(i)
        if (::getTblValue("nick", block, "") == "")
          continue

        // Fixing player data to match get_mplayers_list() data format, for sorting.
        if (!block.name)
        {
          block.name = block.nick
          block.clanTag = ""
          block.nick = null
        }
        if (!block.kills)
        {
          block.kills = block.airKills || 0
          block.airKills = null
        }
        block.isLocal = block.userId == authorUserId
        block.isBot = ::u.isString(block.userId) && ::g_string.startsWith(block.userId, "-")
        block.state = ::PLAYER_HAS_LEAVED_GAME

        playersList.append(block)
      }

      playersList.sort(::mpstat_get_sort_func(gameType))

      foreach (block in playersList)
      {
        local teamName = ""
        local team = ::getTblValue("team", block, Team.none)
        if (team == Team.A)
          teamName = "teamA"
        else if (team == Team.B)
          teamName = "teamB"

        if (!(teamName in playersTables))
        {
          playersTables[teamName] <- []
          data.tablesArray.append(teamName)
          data.markups[teamName] <- clone markup_mptable
          data.markups[teamName].invert = false
          data.markups[teamName].colorTeam = teamName != ""? (teamName == "teamB"? "red" : "blue") : ""
        }

        if (block.isLocal && teamName != "")
        {
          addTableParams[teamName].team <- "blue"
          addTableParams[teamName == "teamA"? "teamB" : "teamA"].team <- "red"
        }

        local eqBlock = ::buildTableFromBlk(block)
        foreach(id in columnsOrder)
          if (!(id in eqBlock))
            eqBlock[id] <- ::g_mplayer_param_type.getTypeById(id).defVal
        playersTables[teamName].append(eqBlock)
      }

      foreach(team, paramsTable in addTableParams)
      {
        local params = ""
        foreach(name, value in paramsTable)
          params += ::format("%s:t='%s'", name, value)
        data.addTableParams[team] <- params
      }
    }

    local missionName = ::getTblValue("missionName", replayInfo, "")
    local missionObjectivesMask = ::g_mission_type.getTypeByMissionName(missionName).getObjectives(
      { isWorldWar = ::getTblValue("isWorldWar", replayInfo, false) })

    local rowHeader = []
    local headerArray = []
    foreach(id in columnsOrder)
    {
      local paramType = ::g_mplayer_param_type.getTypeById(id)
      if (!paramType.isVisible(missionObjectivesMask, gameType, gameMode))
        continue

      headerArray.append(id)
      rowHeader.append({
        tooltip       = paramType.tooltip
        fontIcon      = paramType.fontIcon
        fontIconType  = "fontIcon32"
        text          = paramType.fontIcon ? null : paramType.tooltip
        tdAlign       = "center"
        active        = false
      })
    }

    if (data.tablesArray.len() == 2 && addTableParams[data.tablesArray[1]].team == "blue")
      data.tablesArray.reverse()

    foreach(name in data.tablesArray)
    {
      data.rowHeader[name] <- rowHeader
      data.headerArray[name] <- headerArray

      if (name == "teamA" || name == "teamB")
      {
        local teamImg = {
                          image = "#ui/gameuiskin#" + (name == "teamA"? "team_allies_icon" : "team_axis_icon")
                          tooltip = "#multiplayer/" + name
                          tdAlign="center"
                          active = false
                        }
        data.rowHeader[name][0] = teamImg
      }
      if (data.markups[name].invert)
        data.rowHeader[name].reverse()

      data.playersRows[name] <- ::buildTableRowNoPad("row_header", data.rowHeader[name], null, "class:t='smallIconsStyle'")
      data.playersRows[name] += ::build_mp_table(playersTables[name], data.markups[name], data.headerArray[name], playersTables[name].len())
    }

    return data
  }

  function getCurrentReplayIndex()
  {
    local list = scene.findObject("items_list")
    return list.getValue() + ::replays_per_page * curPage
  }

  function onItemSelect(obj)
  {
    doOpenInfo(getCurrentReplayIndex())
  }

  function onStart()
  {
    onViewReplay()
  }

  function doSelectList()
  {
    local list = scene.findObject("items_list")
    if (list != null)
      list.select()
  }

  function goBack()
  {
    if (isReplayPressed)
      return
    isReplayPressed = true
    ::HudBattleLog.reset()
    base.goBack()
  }

  function onViewReplay()
  {
    if (!::g_squad_utils.canJoinFlightMsgBox())
      return

    ::set_presence_to_player("replay")
    guiScene.performDelayed(this, function()
    {
      if (isReplayPressed)
        return
      local index = getCurrentReplayIndex()
      if (index >= 0 && index < replays.len())
      {
        if (::getTblValue("corrupted", replays[index], false) && !::is_dev_version)
        {
          if (("isVersionMismatch" in replays[index]) && replays[index].isVersionMismatch)
          {
            msgBox("replay_corrupted", ::loc("replays/versionMismatch"),
            [["ok", function(){} ]], "ok")
          }
          else
          {
            msgBox("replay_corrupted", ::loc("replays/corrupted"),
            [["ok", function(){} ]], "ok")
          }
        }
        else
        {
          dagor.debug("gui_nav ::back_from_replays = ::gui_start_replays");
          ::back_from_replays = ::gui_start_menuReplays
          ::req_unlock_by_client("view_replay", false)
          ::current_replay = replays[index].path
          local replayInfo = ::get_replay_info(::current_replay)
          local comments = ::getTblValue("comments", replayInfo)
          ::current_replay_author = comments ? ::getTblValue("authorUserId", comments, null) : null
          ::on_view_replay(::current_replay)
          isReplayPressed = false
        }
      }
    })
  }

  function doDelReplay()
  {
    local index = getCurrentReplayIndex()
    if (index >= 0 && index < replays.len())
    {
      ::on_del_replay(replays[index].path)
      replays.remove(index)
      refreshList()
    }
  }

  function onRenameReplay()
  {
    local index = getCurrentReplayIndex()
    if (index >= 0 && index < replays.len())
    {
      local afterRenameFunc = function(newName)
      {
        getReplays()
        refreshList()

        foreach(idx, replay in replays)
          if (replay.name == newName)
          {
            local list = scene.findObject("items_list")
            if (::checkObj(list))
              list.setValue(idx)
          }
      }

      ::gui_modal_rename_replay(replays[index].name, replays[index].path, this, afterRenameFunc);
    }
  }

  function onDelReplay()
  {
    msgBox("del_replay", ::loc("mainmenu/areYouSureDelReplay"),
    [
      ["yes", doDelReplay],
      ["no", doSelectList]
    ], "no")
  }

  function onOpenFolder()
  {
    ::on_open_replays_folder()
  }

  function onChapterSelect(obj) {}
  function onSelect(obj) {}

  function goBack()
  {
    back_from_replays = null
    base.goBack()
  }
}

////////////////////////////////////////////////////////////////////////////////////////////////////

class ::gui_handlers.RenameReplayHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  function initScreen()
  {
    if (!scene)
      return goBack();

    baseName = baseName || ""
    baseName = ::g_string.startsWith(baseName, ::autosave_replay_prefix) ?
      baseName.slice(::autosave_replay_prefix.len()) : baseName
    scene.findObject("edit_box_window_header").setValue(::loc("mainmenu/replayName"));

    local editBoxObj = scene.findObject("edit_box_window_text")
    editBoxObj.show(true)
    editBoxObj.enable(true)
    editBoxObj.setValue(baseName)
    editBoxObj.select()
  }

  function checkName(newName)
  {
    if (!newName || newName == "")
      return false;
    foreach(c in "\\|/<>:?*\"")
      if (newName.find(c.tochar()) != null)
        return false
    if (::g_string.startsWith(newName, ::autosave_replay_prefix))
      return false;
    return true;
  }

  function onChangeValue(obj)
  {
    local newName = scene.findObject("edit_box_window_text").getValue()
    local btnOk = scene.findObject("btn_ok")
    if (::checkObj(btnOk))
      btnOk.inactiveColor = checkName(newName) ? "no" : "yes"
  }

  function onOk()
  {
    local newName = scene.findObject("edit_box_window_text").getValue();
    if (!checkName(newName))
    {
      msgBox("RenameReplayHandler_invalidName",::loc("msgbox/invalidReplayFileName"),
        [["ok", function() {} ]], "ok");
      return;
    }
    if (newName && newName != "")
    {
      if (afterRenameFunc && newName != baseName)
      {
        if (::rename_file(basePath, newName))
          afterRenameFunc.call(funcOwner, newName);
        else
          msgBox("RenameReplayHandler_error",::loc("msgbox/cantRenameReplayFile"),
            [["ok", function() {} ]], "ok");
      }

      if (afterFunc)
        afterFunc.call(funcOwner, newName);
    }
    goBack();
  }

  scene = null

  baseName = null
  basePath = null
  funcOwner = null
  afterRenameFunc = null
  afterFunc = null

  wndType = handlerType.MODAL
  sceneBlkName = "gui/editBoxWindow.blk"
}
