::stats_fm <- ["fighter", "bomber", "assault"]
::stats_tanks <- ["tank", "tank_destroyer", "heavy_tank", "SPAA"]
::stats_fm.extend(::stats_tanks)
::stats_config <- [
  {
    name = "mainmenu/titleVersus"
    header = true
  }
  {
    id = "victories"
    name = "stats/missions_wins"
    mode = "pvp_played"  //!! mode incoming by ::get_player_public_stats
  }
  {
    id = "missionsComplete"
    name = "stats/missions_completed"
    mode = "pvp_played"
  }
  {
    id = "respawns"
    name = "stats/flights"
    mode = "pvp_played"
  }
  {
    id = "timePlayed"
    name = "stats/time_played"
    mode = "pvp_played"
    separateRowsByFm = true
    timeFormat = true
  }
  {
    id = "air_kills"
    name = "stats/kills_air"
    mode = "pvp_played"
  }
  {
    id = "ground_kills"
    name = "stats/kills_ground"
    mode = "pvp_played"
  }
  {
    id = "naval_kills"
    name = "stats/kills_naval"
    mode = "pvp_played"
    reqFeature = ["Ships"]
  }

  {
    name = "mainmenu/btnSkirmish"
    header = true
  }
  {
    id = "victories"
    name = "stats/missions_wins"
    mode = "skirmish_played"
  }
  {
    id = "missionsComplete"
    name = "stats/missions_completed"
    mode = "skirmish_played"
  }
  {
    id = "timePlayed"
    name = "stats/time_played"
    mode = "skirmish_played"
    timeFormat = true
  }

  {
    name = "mainmenu/btnPvE"
    header = true
  }
  {
    id = "victories"
    name = "stats/missions_wins"
    mode = ["dynamic_played", "builder_played", "single_played"] //"campaign_played"
  }
  {
    id = "missionsComplete"
    name = "stats/missions_completed"
    mode = ["dynamic_played", "builder_played", "single_played"]
  }
  {
    id = "timePlayed"
    name = "stats/time_played"
    mode = ["dynamic_played", "builder_played", "single_played"]
    timeFormat = true
  }
]

::default_summary_item <- {
  id = ""
  name = ""
  mode = null
  fm = null
  header = false
  separateRowsByFm = false
  timeFormat = false
  reqFeature = null
}
foreach(idx, stat in ::stats_config)
  foreach(param, value in ::default_summary_item)
    if (!(param in stat))
      ::stats_config[idx][param] <- value


function gui_modal_userCard(playerInfo)  // uid, id (in session), name
{
  ::gui_start_modal_wnd(::gui_handlers.UserCardHandler, {info = playerInfo})
}

class ::gui_handlers.UserCardHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneCheckBoxListTpl = "gui/profile/checkBoxList"

  function initScreen()
  {
    if (!scene || !info || !(("uid" in info) || ("id" in info) || ("name" in info)))
      return goBack()

    player = {}
    foreach(pName in ["name", "uid", "id"])
      if (pName in info)
        player[pName] <- info[pName]
    if (!("name" in player))
      player.name <- ""

    scene.findObject("profile-name").setValue(player.name)
    scene.findObject("profile-container").show(false)

    initStatsParams()
    initTabs()

    taskId = -1

    local isMyPage = false
    if ("uid" in player)
    {
      taskId = ::req_player_public_statinfo(player.uid)
      if (::my_user_id_str == player.uid)
        isMyPage = true
      else
      ::externalIDsService.reqPlayerExternalIDsByUserId(player.uid)
    }
    else if ("id" in player)
    {
      taskId = ::req_player_public_statinfo_by_player_id(player.id)
      local selfPlayerId = ::getTblValue("uid", ::get_local_mplayer())
      if (selfPlayerId != null && selfPlayerId == player.id)
        isMyPage = true
      else
        ::externalIDsService.reqPlayerExternalIDsByPlayerId(player.id)
    }
    else
    {
      searchPlayerByNick = true
      taskId = ::find_nicks_by_prefix(player.name, 1, false)
    }

    if (isMyPage)
      fillExternalIds(::externalIDsService.getSelfExternalIds())

    if (taskId < 0)
      return notFoundPlayerMsg()

    ::set_char_cb(this, slotOpCb)
    afterSlotOp = getUserStats
    afterSlotOpError = function(result) { /* notFoundPlayerMsg() */ goBack() }

    fillGamercard()
    initLeaderboardModes()
    updateButtons()
  }

  function initTabs()
  {
    local view = { tabs = [] }
    foreach(idx, sheet in sheetsList)
    {
      view.tabs.append({
        id = sheet
        tabImage = tabImageNamePrefix + sheet.tolower()
        tabName = tabLocalePrefix + sheet
        navImagesText = ::get_navigation_images_text(idx, sheetsList.len())
      })
    }

    local data = ::handyman.renderCached("gui/frameHeaderTabs", view)
    local sheetsListObj = scene.findObject("profile_sheet_list")
    guiScene.replaceContentFromText(sheetsListObj, data, data.len(), this)
    sheetsListObj.setValue(0)
    sheetsListObj.show(false)
  }

  function initStatsParams()
  {
    curMode = ::get_current_wnd_difficulty()
    statsType = ::loadLocalByAccount("leaderboards_type", ::ETTI_VALUE_INHISORY)
  }

  function goBack()
  {
    base.goBack()
  }

  function notFoundPlayerMsg()
  {
    msgBox("incorrect_user", ::loc("chat/error/item-not-found", { nick = ("name" in player)? player.name : "" }),
        [
          ["ok", function() { goBack() } ]
        ], "ok")
  }

  function onSearchResult()
  {
    searchPlayerByNick = false

    local searchRes = ::DataBlock()
    searchRes = ::get_nicks_find_result_blk()
    foreach(uid, nick in searchRes)
      if (nick == player.name)
      {
        player.uid <- uid
        taskId = ::req_player_public_statinfo(player.uid)
        if (taskId < 0)
          return notFoundPlayerMsg()
        ::set_char_cb(this, slotOpCb)
        return
      }
    return notFoundPlayerMsg()
  }

  function getUserStats()
  {
    if (searchPlayerByNick)
      return onSearchResult()

    if (!::checkObj(scene))
      return;

    local blk = ::DataBlock()
    ::get_player_public_stats(blk)

    if (!blk.nick || blk.nick == "") //!!FIX ME: Check incorrect user by no uid in answer.
    {
      msgBox("user_not_played", ::loc("msg/player_not_played_our_game"),
        [
          ["ok", function() { goBack() } ]
        ], "ok")
      return
    }

    player = ::get_player_stats_from_blk(blk);

    infoReady = true
    scene.findObject("profile-container").show(true)
    scene.findObject("profile_sheet_list").show(true)
    onSheetChange(null)
    initFocusArray()
    fillLeaderboard()
  }

  function showSheetDiv(name)
  {
    foreach(div in ["profile", "stats"])
    {
      local show = div == name
      local divObj = scene.findObject(div + "-container")
      if (::checkObj(divObj))
      {
        divObj.show(show)
        if (show)
          updateDifficultySwitch(divObj)
      }
    }
  }

  function onSheetChange(obj)
  {
    if (!infoReady)
      return

    if (getCurSheet() == "Statistics")
    {
      showSheetDiv("stats")
      fillStatistics()
    }
    else
    {
      showSheetDiv("profile")
      fillProfile()
    }
    updateButtons()
    focusCurSheetObj()
  }

  function fillProfile()
  {
    if (!::checkObj(scene))
      return

    fillTitleName(player.title, false)

    fillClanInfo(player)
    fillModeListBox(scene.findObject("profile-container"), curMode)
    ::fill_gamer_card(player, true, "profile-", scene)
    fillShortCountryStats(player)
    scene.findObject("profile_loading").show(false)
  }

  function fillTitleName(name, setEmpty = true)
  {
    if(name == "")
    {
      if (!setEmpty)
        return

      name = "empty_title"
    }
    fillAdditionalName(::get_unlock_name_text(::UNLOCKABLE_TITLE, name), "title")
  }

  function onProfileStatsModeChange(obj)
  {
    if (!::checkObj(scene))
      return
    local value = obj.getValue()

    curMode = value
    ::set_current_wnd_difficulty(curMode)
    updateCurrentStatsMode(curMode)
    ::fill_profile_summary(scene.findObject("stats_table"), player.summary, curMode)
  }

  function onEventUpdateExternalsIDsTexts(params)
  {
    if (!("request" in params) || !("externalIds"in params))
      return

    if (("uid" in player && "uid" in params.request && player.uid == params.request.uid) ||
        ("id" in player && "playerId" in params.request && player.id == params.request.playerId))
      fillExternalIds(params.externalIds)
  }

  function fillExternalIds(externalIds)
  {
    fillAdditionalName(::getTblValue("steamName", externalIds, ""), "steamName")
    fillAdditionalName(::getTblValue("facebookName", externalIds, ""), "facebookName")
//    if (::get_platform() == "ps4")
//      fillAdditionalName(::getTblValue("psnName", externalIds, ""), "psnName")
  }

  function fillAdditionalName(name, link)
  {
    if (!::checkObj(scene))
      return

    local nameObj = scene.findObject("profile-currentUser-" + link)
    local data = ""
    if (name != "")
      data = format(::loc("profile/" + link), name)
    if (::checkObj(nameObj))
      nameObj.setValue(data)
  }

  function fillClanInfo(playerData)
  {
    local clanTagObj = scene.findObject("profile-clanTag");
    if (playerData.clanTag != "" && clanTagObj)
    {
      local clanType = ::g_clan_type.getTypeByCode(playerData.clanType)
      local text = ::checkClanTagForDirtyWords(playerData.clanTag);
      clanTagObj.setValue(::colorize(clanType.color, text));
      clanTagObj.tooltip = ::ps4CheckAndReplaceContentDisabledText(playerData.clanName);
    }
  }

  function fillShortCountryStats(profile)
  {
    local countryStatsNest = scene.findObject("country_stats_nest")
    if (!::checkObj(countryStatsNest))
      return

    local view = {
      rows = []
    }

    local columns = ["unitsCount", "eliteUnitsCount"]
    if (::has_feature("ProfileMedals"))
    {
      columns.append("medalsCount")
      view.hasMedals <- true
    }

    foreach (country in shopCountriesList)
    {
      local row = {
        icon = ::get_country_icon(country)
        nums = []
      }
      foreach (param in columns)
        row.nums.append({num = profile.countryStats[country][param]})
     view.rows.append(row)
    }

    local blk = ::handyman.renderCached(("gui/profile/country_stats_table"), view)
    guiScene.replaceContentFromText(countryStatsNest, blk, blk.len(), this)
  }

  function updateCurrentStatsMode(value)
  {
    local diffItems = ::get_option(::USEROPT_DOMINATION_MODE).items
    if (!(value in diffItems))
      return

    statsMode = diffItems[value].leaderboardsId
  }

  function updateDifficultySwitch(parentObj)
  {
    if (!::checkObj(parentObj))
      return

    local switchObj = parentObj.findObject("modes_list")
    if (!::checkObj(switchObj))
      return

    switchObj.setValue(curMode)
  }

  function onStatsModeChange(obj)
  {
    if (!::checkObj(obj))
      return

    local value = obj.getValue()
    if (curMode == value)
      return

    curMode = value
    ::set_current_wnd_difficulty(curMode)
    updateCurrentStatsMode(value)
    fillAirStats()
  }

  function onStatsUnitChange(obj)
  {
    if (!obj)
      return
    local armyId = obj.id
    local value = obj.getValue()
    if (value && !isInArray(armyId, statsUnits))
    {
      statsUnits.append(armyId)
    }
    else
      if (!value)
      {
        for(local i=statsUnits.len()-1; i>=0; i--)
          if (armyId == statsUnits[i])
            statsUnits.remove(i)
      }
    fillAirStats()
  }

  function getPlayerStats()
  {
    return player
  }

  function onStatsTypeChange(obj)
  {
    if (!obj) return
    statsType = obj.getValue()? ::ETTI_VALUE_INHISORY : ::ETTI_VALUE_TOTAL
    ::saveLocalByAccount("leaderboards_type", statsType)
    fillLeaderboard()
  }

  function onLbModeSelect(obj)
  {
    if (!::checkObj(obj) || lbModesList == null)
      return

    local val = obj.getValue()

    if (val >= 0 && val < lbModesList.len() && lbMode != lbModesList[val])
    {
      lbMode = lbModesList[val]
      fillLeaderboard()
    }
  }

  function fillStatistics()
  {
    if (!::checkObj(scene))
      return

    showSheetDiv("stats")
    fillAirStats()
  }

  function fillAirStats()
  {
    if (!::checkObj(scene))
      return

    if (!airStatsInited)
      return initAirStats()

    fillAirStatsScene(player.userstat)
  }

  function initAirStats()
  {
    statsCountries = []
    foreach(country in ::shopCountriesList)
      statsCountries.append(country)
    initAirStatsScene(player.userstat)
  }

  function initAirStatsScene(airStats)
  {
    local sObj = scene.findObject("stats-container")

    sObj.findObject("stats_loading").show(false)

    local modesObj = sObj.findObject("modes_list")
    local data = ""
    local sel = -1
    local diffItems = ::get_option(::USEROPT_DOMINATION_MODE).items

    local view = { items = [] }
    foreach(idx, mode in diffItems)
    {
      view.items.append({ text = mode.text })
      if (statsMode == mode.leaderboardsId)
        sel = idx
    }

    if (sel < 0)
    {
      sel = 0
      statsMode = diffItems[0].leaderboardsId
    }

    local data = ::handyman.renderCached("gui/commonParts/shopFilter", view)
    guiScene.replaceContentFromText(modesObj, data, data.len(), this)
    modesObj.setValue(sel)

    fillUnitListCheckBoxes(sObj)
    fillCountriesCheckBoxes(sObj)

    airStatsInited = true
    fillAirStats()
  }

  function fillUnitListCheckBoxes(sObj)
  {
    local fillStatsUnits = false
    if (statsUnits.len() == 0)
      fillStatsUnits = true

    local unitsObj = sObj.findObject("units_boxes")
    local unitsView = { checkBoxes = [] }
    foreach(unitType in ::g_unit_type.types)
    {
      if (!unitType.isAvailable())
        continue

      local armyId = unitType.armyId
      if (fillStatsUnits)
        statsUnits.append(armyId)

      unitsView.checkBoxes.append(
        {
          id = armyId
          title = unitType.getArmyLocName()
          value = ::isInArray(armyId, statsUnits)? "yes" : "no"
          onChangeFunction = "onStatsUnitChange"
        }
      )
    }

    if (unitsView.checkBoxes.len() > 0)
      unitsView.checkBoxes[unitsView.checkBoxes.len()-1].isLastCheckBox <- true

    local unitsMarkUpData = ::handyman.renderCached(sceneCheckBoxListTpl, unitsView)
    guiScene.replaceContentFromText(unitsObj, unitsMarkUpData, unitsMarkUpData.len(), this)
  }

  function fillCountriesCheckBoxes(sObj)
  {
    if (!statsCountries)
      statsCountries = [::get_profile_info().country]

    local countriesObj = sObj.findObject("countries_boxes")
    local countriesView = { checkBoxes = [] }
    foreach(country in ::shopCountriesList)
      countriesView.checkBoxes.append(
        {
          id = country
          title = "#" + country
          value = ::isInArray(country, statsCountries)? "yes" : "no"
          onChangeFunction = "onStatsCountryChange"
        }
      )

    local countiesMarkUpData = ::handyman.renderCached(sceneCheckBoxListTpl, countriesView)
    guiScene.replaceContentFromText(countriesObj, countiesMarkUpData, countiesMarkUpData.len(), this)
  }

  function fillAirStatsScene(airStats)
  {
    if (!::checkObj(scene))
      return

    airStatsList = []
    local checkList = []
    local typeName = "total"
    local modeName = statsMode
    if ((modeName in airStats) && (typeName in airStats[modeName]))
      checkList = airStats[modeName][typeName]
    foreach(item in checkList)
    {
      local air = ::getAircraftByName(item.name)
      local unitTypeShopId = ::get_army_id_by_es_unit_type(::get_es_unit_type(air))
      if (!::isInArray(unitTypeShopId, statsUnits))
          continue
      if (!("country" in item))
      {
        item.country <- air? air.shopCountry : ""
        item.rank <- air? air.rank : 0
      }
      if (::isInArray(item.country, statsCountries))
        airStatsList.append(item)
    }

    if (statsSortBy=="")
      statsSortBy = "victories"
    airStatsList.sort((@(statsSortBy, statsSortReverse) function(a,b) {
        local res = 0
        if (a[statsSortBy] < b[statsSortBy]) res = 1
        else if (a[statsSortBy] > b[statsSortBy]) res = -1
          else
            if (statsSortBy!="name")
              if (a.name < b.name) res = 1
              else if (a.name > b.name) res = -1
        return statsSortReverse? -res : res
      })(statsSortBy, statsSortReverse))

    curStatsPage = 0
    updateStatPage()
  }

  function initStatsPerPage()
  {
    if (statsPerPage > 0)
      return

    local listObj = scene.findObject("airs_stats_table")
    local size = listObj.getSize()
    local rowsHeigt = size[1] -guiScene.calcString("@leaderboardHeaderHeight", null)
    statsPerPage =   ::max(1, (rowsHeigt / guiScene.calcString("@leaderboardTrHeight",  null)).tointeger())
  }

  function updateStatPage()
  {
    if (!airStatsList)
      return

    initStatsPerPage()

    local data = ""
    local posWidth = "0.05@scrn_tgt"
    local rcWidth = "0.04@scrn_tgt"
    local nameWidth = "0.2@scrn_tgt"
    local headerRow = [
      { width=posWidth }
      { id="rank", width=rcWidth, text="#sm_rank", tdAlign="split", cellType="splitRight", callback = "onStatsCategory", active = statsSortBy=="rank" }
      { id="rank", width=rcWidth, cellType="splitLeft", callback = "onStatsCategory" }
      { id="name", width=rcWidth, cellType="splitRight", callback = "onStatsCategory" }
      { id="name", width=nameWidth, text="#options/unit", tdAlign="left", cellType="splitLeft", callback = "onStatsCategory", active = statsSortBy=="name" }
    ]
    foreach(item in ::air_stats_list)
    {
      if ("reqFeature" in item && !::has_feature_array(item.reqFeature))
        continue

      if (isOwnStats || !("ownProfileOnly" in item) || !item.ownProfileOnly)
        headerRow.append({
          id = item.id
          image = "#ui/gameuiskin#" + (("icon" in item)? item.icon : "lb_"+item.id)
          tooltip = ("text" in item)? "#" + item.text : "#multiplayer/"+item.id
          callback = "onStatsCategory"
          active = statsSortBy==item.id
          needText = false
        })
    }
    data += buildTableRow("row_header", headerRow, null, "inactive:t='yes'; commonTextColor:t='yes'; bigIcons:t='yes'; ")

    local tooltips = {}
    local fromIdx = curStatsPage*statsPerPage
    local toIdx = (curStatsPage+1)*statsPerPage-1
    if (toIdx >= airStatsList.len()) toIdx = airStatsList.len()-1

    for(local idx = fromIdx; idx <= toIdx; idx++)
    {
      local airData = airStatsList[idx]
      local unitTooltip = ::loc("mainmenu/type_" + ::get_unit_role(airData.name)) + ::loc("ui/colon") + ::getUnitName(airData.name)

      local rowName = "row_"+idx
      local rowData = [
        { text = (idx+1).tostring(), width=posWidth },
        { id="rank", width=rcWidth, text = airData.rank.tostring(), tdAlign="right", cellType="splitRight", active = statsSortBy=="rank" }
        { id="country", width=rcWidth, image=::get_country_icon(airData.country), cellType="splitLeft", needText = false }
        {
          id="unit",
          width=rcWidth,
          image=getUnitClassIco(airData.name),
          tooltip = unitTooltip,
          cellType="splitRight",
          needText = false
        }
        { id="name", text = ::getUnitName(airData, true), tdAlign="left", active = statsSortBy=="name", cellType="splitLeft", tooltip = unitTooltip }
      ]
      foreach(item in ::air_stats_list)
      {
        if ("reqFeature" in item && !::has_feature_array(item.reqFeature))
          continue

        if (isOwnStats || !("ownProfileOnly" in item) || !item.ownProfileOnly)
        {
          local cell = ::getLbItemCell(item.id, airData[item.id], item.type)
          cell.active <- statsSortBy == item.id
          if ("tooltip" in cell)
          {
            if (!(rowName in tooltips))
              tooltips[rowName] <- {}
            tooltips[rowName][item.id] <- cell.rawdelete("tooltip")
          }
          rowData.append(cell)
        }
      }
      data += buildTableRow(rowName, rowData, idx%2==0)
    }

    local tblObj = scene.findObject("airs_stats_table")
    guiScene.replaceContentFromText(tblObj, data, data.len(), this)
    foreach(rowName, row in tooltips)
    {
      local rowObj = tblObj.findObject(rowName)
      if (rowObj)
        foreach(name, value in row)
          rowObj.findObject(name).tooltip = value
    }
    local nestObj = scene.findObject("paginator_place")
    ::generatePaginator(nestObj, this, curStatsPage, floor((airStatsList.len() - 1)/statsPerPage))
    updateButtons()
  }

  function goToPage(obj)
  {
    curStatsPage = obj.to_page.tointeger()
    updateStatPage()
  }

  function checkLbRowVisibility(row)
  {
    return ::leaderboardModel.checkLbRowVisibility(row, this)
  }

  function fillLeaderboard()
  {
    local stats = getPlayerStats()
    if (!stats || !("leaderboard" in stats) || !stats.leaderboard.len())
      return

    local typeProfileObj = scene.findObject("stats_type_profile")
    if (::checkObj(typeProfileObj))
    {
      typeProfileObj.show(true)
      typeProfileObj.setValue(statsType == ::ETTI_VALUE_INHISORY)
    }

    local tblObj = scene.findObject("profile_leaderboard")
    local rowIdx = 0
    local data = ""
    local tooltips = {}

    //add header row
    local headerRow = [""]
    foreach(lbCategory in ::leaderboards_list)
      if (checkLbRowVisibility(lbCategory))
        headerRow.append({
          id = lbCategory.id
          image = lbCategory.headerImage
          tooltip = lbCategory.headerTooltip
          active = true
          needText = false
        })

    data = buildTableRow("row_header", headerRow, null, "commonTextColor:t='yes'; bigIcons:t='yes';style:t='height:0.06sh;';  ")

    local rows = [
      {
        text = "#mainmenu/btnLeaderboards"
        showLbPlaces = false
      }
      {
        text = "#multiplayer/place"
        showLbPlaces = true
      }
    ]

    local valueFieldName = (statsType == ::ETTI_VALUE_TOTAL)
                           ? "value_total"
                           : "value_inhistory"
    local lb = ::getTblValue(valueFieldName, ::getTblValue(lbMode, stats.leaderboard), {})
    local standartRow = {}

    foreach (idx, fieldTbl in lb)
    {
      standartRow[idx] <- ::getTblValue(valueFieldName, fieldTbl, -1)
    }

    foreach (row in rows)
    {
      local rowName = "row_" + rowIdx
      local rowData = [{ text = row.text, tdAlign="left" }]
      local res = {}

      foreach(lbCategory in ::leaderboards_list)
        if (checkLbRowVisibility(lbCategory))
        {
          if (lbCategory.field in lb)
          {
            if (!row.showLbPlaces)
              res = lbCategory.getItemCell(standartRow[lbCategory.field], standartRow)
            else
            {
              local value = (lb[lbCategory.field].idx < 0) ? -1 : lb[lbCategory.field].idx + 1
              res = lbCategory.getItemCell(value, null, false, ::g_lb_data_type.PLACE)
            }
          }
          else
          {
            if (!row.showLbPlaces)
              res = lbCategory.getItemCell(lbCategory.type == ::g_lb_data_type.PERCENT ? -1 : 0)
            else
              res = lbCategory.getItemCell(-1, null, false, ::g_lb_data_type.PLACE)
          }

          if ("tooltip" in res)
          {
            if (!(rowName in tooltips))
              tooltips[rowName] <- {}
            tooltips[rowName][lbCategory.id] <- res.rawdelete("tooltip")
          }

          rowData.append(res)
        }

      rowIdx++
      data += buildTableRow(rowName, rowData, rowIdx % 2 == 0, "")
    }
    guiScene.replaceContentFromText(tblObj, data, data.len(), this)

    foreach(rowName, row in tooltips)
      foreach(name, value in row)
        tblObj.findObject(rowName).findObject(name).tooltip = value
  }

  function onChangePilotIcon(obj) {}
  function getNewTitles() {}

  function getCurSheet()
  {
    local obj = scene.findObject("profile_sheet_list")
    local sheetIdx = obj.getValue()
    if ((sheetIdx < 0) || (sheetIdx >= obj.childrenCount()))
      return ""

    return obj.getChild(sheetIdx).id
  }

  function initLeaderboardModes()
  {
    lbMode      = ""
    lbModesList = []

    local data  = ""

    foreach(idx, mode in ::leaderboard_modes)
    {
      local diffCode = ::getTblValue("diffCode", mode)
      if (!::g_difficulty.isDiffCodeAvailable(diffCode, ::GM_DOMINATION))
        continue
      local reqFeature = ::getTblValue("reqFeature", mode)
      if (!::has_feature_array(reqFeature))
        continue

      lbModesList.push(mode.mode)
      data += format("option {text:t='%s'}", mode.text)
    }

    local modesObj = showSceneBtn("leaderboard_modes_list", true)
    guiScene.replaceContentFromText(modesObj, data, data.len(), this)
    modesObj.setValue(0)
  }

  function updateButtons()
  {
    if (!::checkObj(scene))
      return

    local fText = ""
    local bText = ""
    local canBan = false
    local isMe = true

    if (infoReady && ::has_feature("Friends") && ("uid" in player) && ::checkObj(scene))
      if (::my_user_id_str!=player.uid)
      {
        local isFriend = ::isPlayerInFriendsGroup(player.uid)
        local isBlock = ::isPlayerInContacts(player.uid, ::EPL_BLOCKLIST)
        canBan = ::myself_can_devoice() || ::myself_can_ban()
        isMe = false
        if (!isBlock)  fText = isFriend? ::loc("contacts/friendlist/remove") : ::loc("contacts/friendlist/add")
        if (!isFriend) bText = isBlock? ::loc("contacts/blacklist/remove") : ::loc("contacts/blacklist/add")
      }

    local canShowPsn = ::is_platform_ps4 && ::getTblValue("psnName", player, "") != "" && ::isInMenu()

    local sheet = getCurSheet()
    local showStatBar = infoReady && sheet=="Statistics"
    local showProfBar = infoReady && !showStatBar
    local buttonsList = {
                          paginator_place = showStatBar && (airStatsList != null) && (airStatsList.len() > statsPerPage)
                          btn_friendAdd = showProfBar && fText!=""
                          btn_blacklistAdd = showProfBar && bText!=""
                          btn_moderatorBan = showProfBar && canBan && !::is_platform_ps4
                          btn_psnProfile = showProfBar && canShowPsn
                          btn_complain = showProfBar && !isMe
                        }

    local obj = null

    foreach(id, isShow in buttonsList)
    {
      obj = scene.findObject(id)
      if(obj)
      {
        if(id == "btn_friendAdd")
          obj.setValue(fText)
        else if(id == "btn_blacklistAdd")
          obj.setValue(bText)
        obj.show(isShow)
      }
    }
  }

  function onBlacklistBan()
  {
    local clanTag = ::getTblValue("clanTag", player, "")
    local playerName = ::getTblValue("name", player, "")
    local userId = ::getTblValue("uid", player, "")

    ::gui_modal_ban({ name = playerName, uid = userId, clanTag = clanTag }, "")
  }

  function modifyPlayerInList(listName)
  {
    ::editContactMsgBox(player, listName, !::isPlayerInContacts(player.uid, listName),
                        this, updateButtons)
  }

  function onFriendAdd()
  {
    modifyPlayerInList(::EPL_FRIENDLIST)
  }

  function onBlacklistAdd()
  {
    modifyPlayerInList(::EPL_BLOCKLIST)
  }

  function onPsnProfile()
  {
    ::ps4_show_profile(player.psnName)
  }

  function onComplain()
  {
    if (infoReady && ("uid" in player))
      ::gui_modal_complain(player)
  }

  function onStatsCountryChange(obj)
  {
    if (!obj) return
    local country = obj.id
    local value = obj.getValue()
    if (value && !isInArray(country, statsCountries))
      statsCountries.append(country)
    else
      if (!value)
      {
        for(local i=statsCountries.len()-1; i>=0; i--)
          if (country == statsCountries[i])
            statsCountries.remove(i)
      }
    fillAirStats()
  }

  function onStatsCategory(obj)
  {
    if (!obj) return
    local value = obj.id
    if (statsSortBy==value)
      statsSortReverse = !statsSortReverse
    else
    {
      statsSortBy = value
      statsSortReverse = false
    }
    guiScene.performDelayed(this, function() { fillAirStats() })
  }

  function getMainFocusObj()
  {
    local curSheet = getCurSheet()
    if (curSheet == "Profile")
    {
      local obj = scene.findObject("profile-container")
      return obj.findObject("modes_list")
    }
    if (curSheet == "Statistics")
    {
      local obj = scene.findObject("stats-container")
      return obj.findObject("modes_list")
    }
    return null
  }

  function getMainFocusObj2()
  {
    local curSheet = getCurSheet()
    if (curSheet == "Statistics")
      return getObj("countries_boxes")
    if (curSheet == "Profile")
      return getObj("leaderboards_stats_row")
    return null
  }

  function getMainFocusObj3()
  {
    local curSheet = getCurSheet()
    if (curSheet == "Statistics")
      return getObj("units_boxes")
    return null
  }

  function focusCurSheetObj()
  {
    local focusObj = getMainFocusObj()
    if (focusObj)
      focusObj.select()
  }

  isOwnStats = false

  scene = null
  info = null
  sheetsList = ["Profile", "Statistics"]

  tabImageNamePrefix = "#ui/gameuiskin#sh_"
  tabLocalePrefix = "#mainmenu/btn"

  statsPerPage = 0
  showLbPlaces = 0

  airStatsInited = false
  profileInited = false

  airStatsList = null
  statsType = ::ETTI_VALUE_INHISORY
  statsMode = ""
  statsCountries = null
  statsUnits = []
  statsSortBy = ""
  statsSortReverse = false
  curStatsPage = 0

  player = null
  searchPlayerByNick = false
  infoReady = false

  curMode = ::DIFFICULTY_ARCADE
  lbMode  = ""
  lbModesList = null

  wndType = handlerType.MODAL
  sceneBlkName = "gui/userCard.blk"
}

function fill_countries_exp(cObj, profileData=null)
{
  if (!::checkObj(cObj)) return

  local guiScene = cObj.getScene()
  guiScene.replaceContentFromText(cObj, "", 0, this)
  foreach(country in ::shopCountriesList)
  {
    local id = country + "_exp"
    local data = format("country_exp_div { id:t='%s' }", id)
    guiScene.appendWithBlk(cObj, data, this)
    local countryObj = cObj.findObject(id)
    guiScene.replaceContent(countryObj, "gui/countryExpItem.blk", this)
    fillCountryInfo(countryObj, country, 0, true, profileData)
  }
}

function calcStat(func, diff, mode, fm_idx = null) {
  local value = 0

  for (local idx = 0; idx < 3; idx++) //difficulty
    if (idx == diff || diff < 0)

      for(local pm=0; pm < 2; pm++)  //players
        if (mode == pm || mode < 0)

          if (fm_idx!=null)
            value += func(idx, fm_idx, pm)
          else
            value += func(idx, pm)

  return value
}

function build_profile_summary_rowData(config, summary, diff, textId = "")
{
  local row = [{ id = textId, text = "#" + config.name, tdAlign = "left" }]
  local modeList = (typeof config.mode == "array") ? config.mode : [config.mode]
  if (diff < 0)
    return

  local diffItems = ::get_option(::USEROPT_DOMINATION_MODE).items
  local value = 0
  foreach(mode in modeList)
    if ((mode in summary) && (diffItems[diff].statisticsId in summary[mode]))
    {
      local sumData = summary[mode][diffItems[diff].statisticsId]

      if (config.fm == null)
      {
        if (config.id in sumData)
          value += sumData[config.id]
        else
          for (local i = 0; i < ::stats_fm.len(); i++)
            if ((::stats_fm[i] in sumData) && (config.id in sumData[::stats_fm[i]]))
              value += sumData[::stats_fm[i]][config.id]
      } else
        if ((config.fm in sumData) && (config.id in sumData[config.fm]))
          value += sumData[config.fm][config.id]
    }
  local s = config.timeFormat? ::hoursToString(value.tofloat() / TIME_HOUR_IN_SECONDS, false) : value
  local tooltip = diffItems[diff].text
  row.append({text = s.tostring(), tooltip = tooltip})
  return buildTableRowNoPad("", row)
}

function fill_profile_summary(sObj, summary, diff)
{
  if (!::checkObj(sObj))
    return

  local guiScene = sObj.getScene()
  local data = ""
  local textsToSet = {}
  foreach(idx, item in ::stats_config)
  {
    if (!::has_feature_array(item.reqFeature))
      continue

    if (item.header)
      data += buildTableRowNoPad("", ["#" + item.name], null,
                  format("headerRow:t='%s'; ", idx? "yes" : "first"))
    else if (item.separateRowsByFm)
      for (local i = 0; i < ::stats_fm.len(); i++)
      {
        if (::isInArray(::stats_fm[i], ::stats_tanks) && !::has_feature("Tanks"))
          continue
        local rowId = "row_" + idx + "_" + i
        item.fm = ::stats_fm[i]
        data += ::build_profile_summary_rowData(item, summary, diff, rowId)
        textsToSet["txt_" + rowId] <- ::loc(item.name) + " (" + ::loc("mainmenu/type_"+ ::stats_fm[i].tolower()) +")"
      }
    else
      data += ::build_profile_summary_rowData(item, summary, diff)
  }

  guiScene.replaceContentFromText(sObj, data, data.len(), this)
  foreach(id, text in textsToSet)
    sObj.findObject(id).setValue(text)
}

function get_player_stats_from_blk(blk)
{
  local player = {};

  if (blk.userid!=null)
    player.uid <- blk.userid

  player.name <- blk.nick
  player.lastDay <- blk.lastDay
  player.registerDay <- blk.registerDay

  player.title <- "title" in blk? blk.title : ""
  player.titles <- ("titles" in blk && blk.titles)? blk.titles % "name" : []

  player.clanTag <- blk.clanTag? blk.clanTag : ""
  player.clanName <- blk.clanName? blk.clanName : ""
  player.clanType <- blk.clanType ? blk.clanType : 0

  player.exp <- blk.exp || 0
  player.rank <- ::get_rank_by_exp(player.exp)
  player.rankProgress <- ::calc_rank_progress(player)

  player.prestige <- ::get_prestige_by_rank(player.rank)

  //unlocks
  player.unlocks <- {}
  if (blk.unlocks != null)
    foreach(unlock, uBlk in blk.unlocks)
    {
      local uType = uBlk.type
      if (!uType)
        continue

      if (!(uType in player.unlocks))
        player.unlocks[uType] <- {}
      player.unlocks[uType][unlock] <- (uBlk.stage!=null)? uBlk.stage : 1
    }

  player.countryStats <- {}
  foreach(i, country in ::shopCountriesList)
  {
    local cData = {}
    cData.medalsCount <- ::countCountryMedals(country, player)
    cData.unitsCount <- 0
    cData.eliteUnitsCount <- 0
    if (blk.aircrafts && blk.aircrafts[country])
    {
      cData.unitsCount = blk.aircrafts[country].paramCount()
      foreach(unitName, unitEliteStatus in blk.aircrafts[country])
        if (unitEliteStatus == ::ES_UNIT_ELITE_STAGE2)
          cData.eliteUnitsCount++
    }
    player.countryStats[country] <- cData
  }

  player.icon <- "cardicon_default"
  if (blk.icon != null)
    player.icon = ::get_pilot_icon_by_id(blk.icon)

  //aircrafts list
  player.aircrafts <- []
  if (blk.aircrafts != null)
    foreach(airName, airRank in blk.aircrafts)
      player.aircrafts.append(airName)

  //same with ::crews_list
  player.crews <- []
  if (blk.slots != null)
    foreach(country, crewBlk in blk.slots)
    {
      local countryData = { country = country, crews = [] }
      foreach(airName, rank in crewBlk)
        countryData.crews.append({ aircraft = airName })
      player.crews.append(countryData)
    }


  //stats & leaderboards
  player.summary <- blk.summary? ::buildTableFromBlk(blk.summary) : {}
  player.userstat <- blk.userstat? ::get_airs_stats_from_blk(blk.userstat) : {}
  player.leaderboard <- blk.leaderboard? ::buildTableFromBlk(blk.leaderboard) : {}

  return player
}

::externalIDsService <- {
  function reqPlayerExternalIDsByPlayerId(playerId)
  {
    local taskId = ::req_player_external_ids_by_player_id(playerId)
    ::externalIDsService.requestExternalIDsFromServer(taskId, {playerId = playerId})
  }

  function reqPlayerExternalIDsByUserId(uid)
  {
    local taskId = ::req_player_external_ids(uid)
    ::externalIDsService.requestExternalIDsFromServer(taskId, {uid = uid})
  }

  function getSelfExternalIds()
  {
    local table = {}

  //STEAM
    local steamId = ::get_my_external_id(::EPL_STEAM)
    if (steamId != null)
      table.steamName <- ::steam_get_name_by_id(steamId)

  //FACEBOOK
    if (::facebook_is_logged_in() && ::no_dump_facebook_friends)
    {
      local fId = ::get_my_external_id(::EPL_FACEBOOK)
      if (fId in ::no_dump_facebook_friends)
        table.facebookName <- ::no_dump_facebook_friends[fId]
    }

  //PLAYSTATION NETWORK
    local psnId = ::get_my_external_id(::EPL_PSN)
    if (psnId != null)
      table.psnName <- psnId

    return table
  }

  function requestExternalIDsFromServer(taskId, request, noisy = false)
  {
    local progressBox = null
    if (noisy)
      progressBox = ::scene_msg_box("char_connecting", null,
                                    ::loc("charServer/purchase"),
                                    null, null)
    ::add_bg_task_cb(taskId, (@(progressBox, request) function() {
        ::externalIDsService.updateExternalIDsTable(request)
        ::destroyMsgBox(progressBox)
      })(progressBox, request)
    )
  }

  function updateExternalIDsTable(request)
  {
    local blk = ::DataBlock()
    ::get_player_external_ids(blk)

    local eIDtable = ::getTblValue("externalIds", blk, null)
    if (!eIDtable)
      return

    local table = {}
  //STEAM
    if (::EPL_STEAM in eIDtable && "id" in eIDtable[::EPL_STEAM] && ::steam_is_running())
      table.steamName <- ::steam_get_name_by_id(blk.externalIds[::EPL_STEAM].id)

  //FACEBOOK
    if (::EPL_FACEBOOK in eIDtable && "id" in eIDtable[::EPL_FACEBOOK] && ::facebook_is_logged_in() && ::no_dump_facebook_friends)
    {
      local fId = eIDtable[::EPL_FACEBOOK].id
      if (fId in ::no_dump_facebook_friends)
        table.facebookName <- ::no_dump_facebook_friends[fId]
    }

  //PLAYSTATION NETWORK
    if (::EPL_PSN in eIDtable && "id" in eIDtable[::EPL_PSN])
      table.psnName <- eIDtable[::EPL_PSN].id

    ::broadcastEvent("UpdateExternalsIDsTexts", {externalIds = table, request = request})
  }
}
