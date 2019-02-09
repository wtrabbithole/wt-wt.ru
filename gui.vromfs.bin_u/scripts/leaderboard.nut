local time = require("scripts/time.nut")
local platformModule = require("scripts/clientState/platform.nut")
local playerContextMenu = ::require("scripts/user/playerContextMenu.nut")

::leaderboards_list <- [
  ::g_lb_category.VICTORIES_BATTLES
  ::g_lb_category.AVERAGE_RELATIVE_POSITION
  ::g_lb_category.PVP_RATIO
  ::g_lb_category.AIR_KILLS
  ::g_lb_category.GROUND_KILLS
  ::g_lb_category.NAVAL_KILLS
  ::g_lb_category.AVERAGE_ACTIVE_KILLS_BY_SPAWN
  ::g_lb_category.AVERAGE_SCRIPT_KILLS_BY_SPAWN
  ::g_lb_category.AVERAGE_SCORE
]

::leaderboard_modes <- [
  {
    // Arcade Battles
    text = "#mainmenu/arcadeInstantAction"
    mode = "arcade"
    diffCode = ::DIFFICULTY_ARCADE
  }
  {
    // Realistic Battles
    text = "#mainmenu/instantAction"
    mode = "historical"
    diffCode = ::DIFFICULTY_REALISTIC
  }
  {
    // Simulator Battles
    text = "#mainmenu/fullRealInstantAction"
    mode = "simulation"
    diffCode = ::DIFFICULTY_HARDCORE
  }

  {
    // Air Arcade Battles
    text = "#missions/air_event_arcade"
    mode = "air_arcade"
    diffCode = ::DIFFICULTY_ARCADE
  }
  {
    // Air Realistic Battles
    text = "#missions/air_event_historical"
    mode = "air_realistic"
    diffCode = ::DIFFICULTY_REALISTIC
  }
  {
    // Air Simulator Battles
    text = "#missions/air_event_simulator"
    mode = "air_simulation"
    diffCode = ::DIFFICULTY_HARDCORE
  }
  {
    // Tank Arcade Battles
    text = "#missions/tank_event_arcade"
    mode = "tank_arcade"
    diffCode = ::DIFFICULTY_ARCADE
    reqFeature = [ "Tanks" ]
  }
  {
    // Tank Realistic Battles
    text = "#missions/tank_event_historical"
    mode = "tank_realistic"
    diffCode = ::DIFFICULTY_REALISTIC
    reqFeature = [ "Tanks" ]
  }
  {
    // Tank Simulator Battles
    text = "#missions/tank_event_simulator"
    mode = "tank_simulation"
    diffCode = ::DIFFICULTY_HARDCORE
    reqFeature = [ "Tanks" ]
  }
  {
    // Ship Arcade Battles
    text = "#missions/ship_event_arcade"
    mode = "test_ship_arcade"
    diffCode = ::DIFFICULTY_ARCADE
    reqFeature = [ "Ships" ]
  }
  {
    // Ship Realistic Battles
    text = "#missions/ship_event_historical"
    mode = "test_ship_realistic"
    diffCode = ::DIFFICULTY_REALISTIC
    reqFeature = [ "Ships" ]
  }
  {
    // Helicopter Arcade Battles
    text = "#missions/helicopter_event"
    mode = "helicopter_arcade"
    diffCode = ::DIFFICULTY_ARCADE
    reqFeature = [ "HiddenLeaderboardRows" ]
  }
]

function gui_modal_leaderboards(lb_presets = null)
{
  gui_start_modal_wnd(::gui_handlers.LeaderboardWindow, {lb_presets = lb_presets})
}

function gui_modal_event_leaderboards(eventId = null)
{
  gui_start_modal_wnd(::gui_handlers.EventsLeaderboardWindow, {eventId = eventId})
}

::leaderboardModel <-
{
  selfRowData       = null
  leaderboardData   = null
  lastRequestData   = null
  lastRequestSRData = null //last self row request
  canRequestLb      = true

  defaultRequest =
  {
    lbType = ::ETTI_VALUE_INHISORY
    lbField = "each_player_victories"
    rowsInPage = 1
    pos = 0
    lbMode = ""
  }

  function reset()
  {
    selfRowData       = null
    leaderboardData   = null
    lastRequestData   = null
    lastRequestSRData = null
    canRequestLb      = true
  }

  /**
   * Function requests leaderboards asynchronously and puts result
   * as argument to callback function
   */
  function getLeaderboard(requestData, callback, context = null)
  {
    requestData = validateRequestData(requestData)

    //trigging callback if data is lready here
    if(leaderboardData && compareRequests(lastRequestData, requestData))
      return context ? callback.call(context, leaderboardData) : callback(leaderboardData)

    requestData.callBack <- ::Callback(callback, context)
    loadLeaderboard(requestData)
  }

  /**
   * Function requests self leaderboard row asynchronously and puts result
   * as argument to callback function
   */
  function getSelfRow(requestData, callback, context = null)
  {
    requestData = validateRequestData(requestData)
    if(lastRequestSRData)
      lastRequestSRData.pos <- requestData.pos

    //trigging callback if data is lready here
    if(selfRowData && compareRequests(lastRequestSRData, requestData))
      return context ? callback.call(context, selfRowData) : callback(selfRowData)

    requestData.callBack <- ::Callback(callback, context)
    loadSeflRow(requestData)
  }

  function loadLeaderboard(requestData)
  {
    lastRequestData = requestData
    if(!canRequestLb)
      return

    canRequestLb = false

    local taskId = ::request_page_of_leaderboard(requestData.lbType,
                                                 requestData.lbField,
                                                 requestData.rowsInPage,
                                                 requestData.pos,
                                                 requestData.lbMode)

    ::add_bg_task_cb(taskId, (@(requestData) function() {
      ::leaderboardModel.handleLbRequest(requestData)
    })(requestData))
  }

  function loadSeflRow(requestData)
  {
    lastRequestSRData = requestData
    if(!canRequestLb)
      return
    canRequestLb = false

    local taskId = ::request_me_in_leaderboard(requestData.lbType,
                                               requestData.lbField,
                                               0,
                                               requestData.lbMode)

    ::add_bg_task_cb(taskId, (@(requestData) function() {
      ::leaderboardModel.handleSelfRowLbRequest(requestData)
    })(requestData))
  }

  function handleLbRequest(requestData)
  {
    local LbBlk = get_leaderboard_blk()
    leaderboardData = {}
    leaderboardData["rows"] <- lbBlkToArray(LbBlk, requestData)
    canRequestLb = true
    if (!compareRequests(lastRequestData, requestData))
      getLeaderboard(lastRequestData,
                     ::getTblValue("callBack", requestData),
                     ::getTblValue("handler", requestData))
    else
      if ("callBack" in requestData)
      {
        if ("handler" in requestData)
          requestData.callBack.call(requestData.handler, leaderboardData)
        else
          requestData.callBack(leaderboardData)
      }
  }

  function handleSelfRowLbRequest(requestData)
  {
    local sefRowblk = get_leaderboard_blk()
    selfRowData = lbBlkToArray(sefRowblk, requestData)
    canRequestLb = true
    if (!compareRequests(lastRequestSRData, requestData))
      loadSeflRow(lastRequestSRData)
    else
      if ("callBack" in requestData)
      {
        if ("handler" in requestData)
          requestData.callBack.call(requestData.handler, selfRowData)
        else
          requestData.callBack(selfRowData)
      }
  }

  function lbBlkToArray(blk, requestData)
  {
    local res = []
    local valueKey = (requestData.lbType == ::ETTI_VALUE_INHISORY) ? "value_inhistory" : "value_total"
    for (local i = 0; i < blk.blockCount(); i++)
    {
      local table = {}
      local row = blk.getBlock(i)
      table.name <- row.getBlockName()
      table.pos <- row.idx != null ? row.idx : -1
      for(local j = 0; j < row.blockCount(); j++)
      {
        local param = row.getBlock(j)
        if(param.paramCount() <= 0 || param[valueKey] == null)
          continue
        table[param.getBlockName()] <- param[valueKey]
      }
      res.append(table)
    }
    return res
  }

  function validateRequestData(requestData)
  {
    foreach(name, field in defaultRequest)
      if(!(name in requestData))
        requestData[name] <- field
    return requestData
  }

  function compareRequests(req1, req2)
  {
    foreach(name, field in defaultRequest)
    {
      if ((name in req1) != (name in req2))
        return false
      if (!(name in req1)) //no name in both req
        continue
      if (req1[name] != req2[name])
        return false
    }
    return true
  }

  function checkLbRowVisibility(row, params = {})
  {
    // check ownProfileOnly
    if (::getTblValue("ownProfileOnly", row, false) && !::getTblValue("isOwnStats", params, false))
      return false

    // check reqFeature
    if (!row.isVisibleByFeature())
      return false

    // check modesMask
    local lbMode = ::getTblValue("lbMode", params)
    if (!row.isVisibleByLbModeName(lbMode))
      return false

    return true
  }
}

::leaderboarsdHelpers <-
{
  /**
   * Comapares two lb row with the same fields and returns
   * a table of diff for each field.
   * Result table containes only fields with different values
   * The first argument is base of comarsion. In other words a is now and b is
   * was.
   * If a.f1 > b.f1 and a.f1 - b.f1 == 3
   * the result will looks like
   * res.f1 = 3
   * String fields are ignored
   */
  function getLbDiff(a, b)
  {
    local res = {}
    foreach (fieldId, fieldValue in a)
    {
      if (fieldId == "_id")
        continue
      if (typeof fieldValue == "string")
        continue
      local compareToValue = ::getTblValue(fieldId, b, 0)
      if (fieldValue != compareToValue)
        res[fieldId] <- fieldValue - compareToValue
    }
    return res
  }
}

/**
 * Generates view for leaderbord item
 *
 * @param field_config  - item of ::leaderboards_list
 *                        or ::events.eventsTableConfig
 * @param lb_value      - value of specified field as it comes from char
 * @param lb_value_diff - optional, diff data, generated
 *                        with ::leaderboarsdHelpers.getLbDiff(...)
 *
 * @return view for getLeaderboardItemWidgets(...)
 */
function getLeaderboardItemView(lbCategory, lb_value, lb_value_diff = null, params = null)
{
  local view = lbCategory.getItemCell(lb_value)
  view.name <- lbCategory.headerTooltip
  view.icon <- lbCategory.headerImage

  view.width  <- ::getTblValue("width",  params)
  view.pos    <- ::getTblValue("pos",    params)
  view.margin <- ::getTblValue("margin", params)

  if (lb_value_diff)
  {
    view.progress <- {
      positive = lb_value_diff > 0
      diff = lbCategory.getItemCell(lb_value_diff, null, true)
    }
  }

  return view
}

/**
 * Generates view for leaderbord items array
 * @param view  - { items = array of ::getLeaderboardItemView(...) }
 * @return markup ready for insertion into scene
 */
function getLeaderboardItemWidgets(view)
{
  return ::handyman.renderCached("gui/leaderboardItemWidget", view)
}

class ::gui_handlers.LeaderboardWindow extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/leaderboard.blk"

  lbType        = ::ETTI_VALUE_INHISORY
  curLbCategory = null
  lbField       = ""
  lbModel       = null
  lbMode        = ""
  lbModesList   = null
  lb_presets    = null
  lbData        = null
  forClans      = false

  pos         = 0
  rowsInPage  = 16
  isLastPage  = false
  maxRows     = 1000

  request = {
    lbType     = null
    lbField    = null
    rowsInPage = null
    pos        = null
    lbMode     = ""
  }
  pageData    = null
  selfRowData = null

  afterLoadSelfRow = null

  function initScreen()
  {
    ::add_big_query_record("global_leaderboard.open", "")

    ::req_unlock_by_client("view_leaderboards", false)
    if (!lbModel)
    {
      lbModel = ::leaderboardModel
      lbModel.reset()
    }
    if (!lb_presets)
      lb_presets = ::leaderboards_list

    curLbCategory = lb_presets[0]
    lbType = ::loadLocalByAccount("leaderboards_type", ::ETTI_VALUE_INHISORY)
    pos = 0
    rowsInPage  = 16

    initModes()
    initTopItems()
    fetchLbData()
    updateButtons()
    initFocusArray()
  }

  //----CONTROLLER----//
  function getSelfPos()
  {
    if (!selfRowData || selfRowData.len() <= 0)
      return -1

    return selfRowData[0].pos
  }

  function requestSelfPage(selfPos)
  {
    if (!selfPos)
    {
      pos = 0
      return
    }
    local selfPagePos = rowsInPage * floor(selfPos / rowsInPage)
    pos = selfPagePos / rowsInPage < maxRows ? selfPagePos : 0
  }

  function goToPage(obj)
  {
    pos = obj.to_page.tointeger() * rowsInPage
    fetchLbData()
  }

  function noLbDataError()
  {
    guiScene.replaceContentFromText(scene.findObject("lb_players_table"), "", 0, this)
    dagor.debug("Error: Empty leaderboard block without endOfList")
    msgBox("not_available", ::loc("multiplayer/lbError"), [["ok", function() { goBack() } ]], "ok")
  }

  function getSelectedRowData()
  {
    if (!::checkObj(scene) || !pageData)
      return null

    local objTbl = scene.findObject("lb_table")
    local idx = objTbl.getValue() - 1 //header row
    local row = ::getTblValue(idx, getLbRows())
    if (row)
      return row

    if (idx == rowsInPage + 1 && selfRowData && selfRowData.len())
      return selfRowData[0]

    return null
  }

  function onSelect()
  {
    updateButtons()
  }

  function updateButtons()
  {
    local rowData = getSelectedRowData()
    local showPlayer = rowData != null && !forClans
    local showClan = rowData != null && forClans

    ::showBtnTable(scene, {
      btn_usercard = showPlayer
      btn_clan_info = showClan
      btn_membership_req = showClan && !::is_in_clan() && ::clan_get_requested_clan_id() != getLbClanUid(rowData)
    })
  }

  function getLbPlayerUid(rowData)
  {
    return ::getTblValue("_id", rowData)
  }

  function getLbPlayerName(rowData)
  {
    return ::getTblValue("name", rowData, "")
  }

  function getLbClanUid(rowData)
  {
    return ::getTblValue("_id", rowData)
  }

  function onUserCard()
  {
    local rowData = getSelectedRowData()
    if (!rowData)
      return

    //not event leaderboards dont have player uids, so if no uid, we will search player by name
    local params = { name = getLbPlayerName(rowData) }
    local uid = getLbPlayerUid(rowData)
    if (uid)
      params.uid <- uid
    ::gui_modal_userCard(params)
  }

  function onUserDblClick()
  {
    forClans ? onClanInfo() : onUserCard()
  }

  function onUserRClick()
  {
    local rowData = getSelectedRowData()
    if (!rowData || forClans)
      return

    playerContextMenu.showMenu(null, this, {
      playerName = getLbPlayerName(rowData)
      uid = getLbPlayerUid(rowData)
      canInviteToChatRoom = false
    })
  }

  function onClanInfo()
  {
    local rowData = getSelectedRowData()
    if (rowData)
      ::showClanPage(getLbClanUid(rowData), "", "")
  }

  function onMembershipReq()
  {
    local rowData = getSelectedRowData()
    if (rowData)
      ::g_clans.requestMembership(getLbClanUid(rowData))
  }

  function onEventClanMembershipRequested(p)
  {
    updateButtons()
  }

  function onModeSelect(obj)
  {
    if (!::checkObj(obj) || lbModesList == null)
      return

    local val = obj.getValue()

    if (val >= 0 && val < lbModesList.len() && lbMode != lbModesList[val])
    {
      lbMode = lbModesList[val]

      // check modesMask
      if (!curLbCategory.isVisibleByLbModeName(lbMode))
        curLbCategory = lb_presets[0]

      afterLoadSelfRow = requestSelfPage
      fetchLbData()

      ::add_big_query_record("global_leaderboard.select_mode", lbMode);
    }
  }

  function prepareRequest()
  {
    local newRequest = {}
    foreach(fieldName, field in request)
      newRequest[fieldName] <- (fieldName in this) ? this[fieldName] : field
    foreach (tableConfigRow in lb_presets)
      if (tableConfigRow.field == newRequest.lbField)
        newRequest.inverse <- tableConfigRow.inverse
    return newRequest
  }

  function onChangeType(obj)
  {
    if (!::checkObj(obj))
      return

    lbType = obj.getValue() ? ::ETTI_VALUE_INHISORY : ::ETTI_VALUE_TOTAL
    ::saveLocalByAccount("leaderboards_type", lbType)
    fetchLbData()
  }

  function onCategory(obj)
  {
    if (!::checkObj(obj))
      return

    if (curLbCategory.id == obj.id)
    {
      local selfPos = getSelfPos()
      local selfPagePos = rowsInPage * floor(selfPos / rowsInPage)
      if (pos != selfPagePos)
        requestSelfPage(selfPos)
      else
        pos = 0
    }
    else
    {
      curLbCategory = ::g_lb_category.getTypeById(obj.id)
      pos = 0
    }
    fetchLbData()
  }

  function getMainFocusObj()
  {
    return scene.findObject("btn_type")
  }

  function getMainFocusObj2()
  {
    return scene.findObject("lb_table")
  }
  //----END_CONTROLLER----//

  //----VIEW----//
  function initModes()
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

    local modesObj = showSceneBtn("modes_list", true)
    guiScene.replaceContentFromText(modesObj, data, data.len(), this)
    modesObj.setValue(0)
  }

  function getTopItemsTplView()
  {
    local res = {
      monthCheckbox = [
        {
          monthCbValue = ((lbType == ::ETTI_VALUE_INHISORY) ? "yes" : "no")
        }
      ]
    }
    return res
  }

  function initTopItems()
  {
    local holder = scene.findObject("top_holder")
    if (!::checkObj(holder))
      return

    local tplView = getTopItemsTplView()
    local data = ::handyman.renderCached("gui/leaderboardTopItem", tplView)

    guiScene.replaceContentFromText(holder, data, data.len(), this)
  }

  function fetchLbData()
  {
    lbField = curLbCategory.field
    lbModel.getSelfRow(
                      prepareRequest(),
                      function (self_row_data)
                      {
                        selfRowData = self_row_data
                        if(!selfRowData)
                          return
                        if(afterLoadSelfRow)
                          afterLoadSelfRow(getSelfPos())
                        afterLoadSelfRow = null
                        lbModel.getLeaderboard(prepareRequest(),
                                              function (leaderboard_data) {
                                                pageData = leaderboard_data
                                                fillLeaderboard(pageData)
                                              },
                                              this)
                      },
                      this)
  }

  function getLbRows()
  {
    return ::getTblValue("rows", pageData, [])
  }

  function fillLeaderboard(pageData)
  {
    if (!::checkObj(scene))
      return
    local lbWrapObj = scene.findObject("lb_wrap")
    local lbTable = lbWrapObj.findObject("lb_table")
    local lbWaitBox = lbWrapObj.findObject("msgWaitAnimation")
    local noLbText = lbWrapObj.findObject("no_leaderboads_text")

    local tableData = ""
    isLastPage = false

    local lbRows = getLbRows()

    local showHeader = pageData != null
    local showTable = (pos > 0 || lbRows.len() > 0) && selfRowData != null

    lbWaitBox.show(!showTable && !pageData)
    noLbText.show(!showTable && pageData)

    local data = ""

    if (showHeader)
    {
      local headerRow = [{ text = "#multiplayer/place", width = "0.1@sf"},
                         { text = forClans ? "#clan/clan_name" : "#multiplayer/name", tdAlign = "center" }
                        ]
      foreach(lbCategory in lb_presets)
      {
        if (!lbModel.checkLbRowVisibility(lbCategory, this))
          continue
        local block = {
          id = lbCategory.id
          image = lbCategory.headerImage
          tooltip = lbCategory.headerTooltip
          needText = false
          active = curLbCategory == lbCategory
          callback = "onCategory"
        }
        headerRow.append(block)
      }
      data += buildTableRow("row_header", headerRow, null, "inactive:t='yes'; commonTextColor:t='yes'; bigIcons:t='yes'; ")
    }

    if (showTable)
    {
      local rowIdx = 0
      foreach(row in lbRows)
        data += generateRowTableData(row, rowIdx++)

      if (rowIdx < rowsInPage)
      {
        for(local i = rowIdx; i<rowsInPage; i++)
          data += buildTableRow("row_"+i, [], i%2==0, "inactive:t='yes';")
        isLastPage = true
      }

      data += generateSelfRow()
    }

    guiScene.replaceContentFromText(lbTable, data, data.len(), this)

    if(showTable)
    {
      lbTable.select()
      fillPagintator()
      onSelect()
    } else
      ::hidePaginator(scene.findObject("paginator_place"))

    fillAdditionalLeaderboardInfo(pageData)
  }

  function fillAdditionalLeaderboardInfo(pageData)
  {
  }

  function generateRowTableData(row, rowIdx)
  {
    local rowName = "row_" + rowIdx
    local rowData = [
      {
        text = row.pos >= 0 ? (row.pos + 1).tostring() : ::loc("leaderboards/notAvailable")
      }
      {
        id = "name"
        tdAlign = "left"
        text = platformModule.getPlayerName(row?.name ?? "")
      }
    ]
    foreach(lbCategory in lb_presets)
    {
      if (!lbModel.checkLbRowVisibility(lbCategory, this))
        continue

      rowData.append(getItemCell(lbCategory, row))
    }
    local highlightRow = getSelfPos() == row.pos && row.pos >= 0
    local data = buildTableRow(rowName, rowData, rowIdx % 2 == 0, highlightRow ? "mainPlayer:t='yes';" : "")
    return data
  }

  function getItemCell(lbCategory, row)
  {
    local value = lbCategory.field in row ? row[lbCategory.field] : 0
    local res = lbCategory.getItemCell(value, row)
    res.active <- curLbCategory == lbCategory
    return res
  }

  function generateSelfRow()
  {
    if (!selfRowData || selfRowData.len() <= 0)
      return ""
    local emptyRow = buildTableRow("row_"+rowsInPage, ["..."], null, "inactive:t='yes'; commonTextColor:t='yes'; style:t='height:0.7@leaderboardTrHeight;'; ")
    return emptyRow + generateRowTableData(selfRowData[0], rowsInPage+1)
  }

  function fillPagintator()
  {
    local nestObj = scene.findObject("paginator_place")
    local curPage = (pos / rowsInPage).tointeger()
    if(isLastPage && (curPage == 0))
      ::hidePaginator(nestObj)
    else
    {
      local lastPageNumber = curPage + (isLastPage? 0 : 1)
      local myPlace = getSelfPos()
      local myPage = myPlace >= 0 ? floor(myPlace / rowsInPage) : null
      ::generatePaginator(nestObj, this, curPage, lastPageNumber, myPage)
    }
  }
  //----END_VIEW----//
}

class ::gui_handlers.EventsLeaderboardWindow extends ::gui_handlers.LeaderboardWindow
{
  eventId  = null
  inverse  = false

  request = null

  function initScreen()
  {
    local eventData = ::events.getEvent(eventId)
    if (!eventData)
      return goBack()

    request = ::events.getMainLbRequest(eventData)
    if (!lbModel)
      lbModel = ::events

    forClans = ::getTblValue("forClans", request, forClans)
    if (lb_presets == null)
      lb_presets = ::events.eventsTableConfig

    local sortLeaderboard = ::getTblValue("sort_leaderboard", eventData, null)
    curLbCategory = (sortLeaderboard != null)
      ? ::g_lb_category.getTypeByField(sortLeaderboard)
      : ::events.getTableConfigShortRowByEvent(eventData)

    initTopItems()

    fetchLbData()

    local headerName = scene.findObject("lb_name")
    headerName.setValue(::events.getEventNameText(eventData))

    updateButtons()
    initFocusArray()
  }

  function getTopItemsTplView()
  {
    local res = {
      updateTime = [
        dummy = 1
      ]
    }
    return res
  }


  function fillAdditionalLeaderboardInfo(pageData)
  {
    local updateTime = ::getTblValue("updateTime", pageData, 0)
    local updateTimeTbl = ::get_time_from_t(updateTime)
    local timeStr = updateTime > 0
                    ? ::format("%s %s %d:%02d",
                               ::loc("mainmenu/lbUpdateTime"),
                               time.buildDateStr(updateTimeTbl),
                               updateTimeTbl.hour,
                               updateTimeTbl.min)
                    : ""
    local lbUpdateTime = scene.findObject("lb_update_time")
    if (!::checkObj(lbUpdateTime))
      return
    lbUpdateTime.setValue(timeStr)
  }
}

function getLbItemCell(id, value, dataType, allowNegative = false)
{
  local res = {
    id   = id
    text = dataType.getShortTextByValue(value, allowNegative)
  }

  local tooltipText =  dataType.getPrimaryTooltipText(value, allowNegative)
  if (tooltipText != "")
    res.tooltip <- tooltipText

  return res
}
