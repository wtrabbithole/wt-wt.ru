local time = require("scripts/time.nut")
local clanContextMenu = ::require("scripts/clans/clanContextMenu.nut")

// how many top places rewards are displayed in clans list window
::CLAN_SEASONS_TOP_PLACES_REWARD_PREVIEW <- 3

class ::gui_handlers.ClansModalHandler extends ::gui_handlers.clanPageModal
{
  wndType = handlerType.MODAL
  sceneBlkName   = "gui/clans/ClansModal.blk"
  pages          = ["clans_list", "my_clan"]
  startPage      = ""
  curPage        = ""
  curPageObj     = null
  tabsObj        = null

  isClanInfo     = false
  isSearchMode   = false
  searchRequest  = ""

  clanLbInited   = false

  myClanInited   = false
  myClanLbData   = null

  clansPerPage   = -1
  requestingClansCount = -1
  isLastPage     = false
  clanByRow      = {}
  clansLbSort    = null
  curClanLbPage  = 0
  curPageData    = null
  currentFocusItem = 5

  rowsTexts      = {}
  tooltips       = {}

  function initScreen()
  {
    if (startPage == "")
      startPage = (::clan_get_my_clan_id() == "-1")? "clans_list" : "my_clan"

    initLbTable()

    local pageIdx = find_in_array(pages, startPage)
    pageIdx = pageIdx == -1 ? 0 : pageIdx
    tabsObj = scene.findObject("clans_sheet_list")
    tabsObj.setValue(pageIdx)

    if (::g_clans.isNonLatinCharsAllowedInClanName())
      scene.findObject("search_edit")["char-mask"] = null

    curPage = pages[pageIdx]
    curMode = getCurDMode()
    onSheetChange()
  }

  function showCurPage()
  {
    if(curPage == "my_clan")
      showMyClanPage()
    else
      enableAdminMode(false)

    if(curPage == "clans_list")
      showLb()

    updateAdminModeSwitch()
  }

  function getMainFocusObj()
  {
    return curPage == "clans_list" ? null : scene.findObject("btn_lock_clan_req")
  }

  function getMainFocusObj2()
  {
    return curPage == "clans_list" ? "search_edit" : "clan_actions"
  }

  function getMainFocusObj3()
  {
    local parentObj = scene.findObject(curPage == "clans_list" ? "clans_list_content" : "clan_container")
    return parentObj.findObject("modes_list")
  }

  function getMainFocusObj4()
  {
    local focusId = curPage == "clans_list"
      ? "clan_lboard_table"
      : isWorldWarMode
        ? "lb_table"
        : "clan_members_list"
    return scene.findObject(focusId)
  }

  function onSheetChange()
  {
    clearPage()
    curPage = pages[tabsObj.getValue()]
    isClanInfo = curPage == "my_clan"
    showCurPage()
  }

  function clearPage()
  {
    if(curPageObj == null || !curPageObj.isValid())
      return

    curPageObj.show(false)
    curPageObj.enable(false)
  }

  function initClanLeaderboards()
  {
    clanLbInited = true
    curPageData = null
    curClanLbPage = 0
    clanByRow = {}
    isLastPage = false
    curEra = CLAN_RANK_ERA
    clansLbSort = getCurrentSortField()
  }

  function calculateRowNumber()
  {
    local reserveY = "0.05sh" + (::my_clan_info != null ? " + 1.7@leaderboardTrHeight" : "")
    local clanLboard = scene.findObject("clan_lboard_table")
    clansPerPage = ::g_dagui_utils.countSizeInItems(clanLboard, 1, "@leaderboardTrHeight", 0, 0, 0, reserveY).itemsCountY
    requestingClansCount = clansPerPage + 1
  }

  function getCurrentSortField()
  {
    local fieldName = ::ranked_column_prefix + curEra
    foreach (field in ::clan_leaderboards_list)
      if (("field" in field ? field.field : field.id) == fieldName)
        return field
    return null
  }

  function initMyClanPage()
  {
    myClanInited = true
    setDefaultSort()
    local myClanPages = {
      clan_info_not_in_clan = false
      clan_container = false
    }
    foreach(pageId, status in myClanPages)
      ::showBtn(pageId, status, scene)


    if(::my_clan_info != null)
    {
      clanIdStrReq = ::my_clan_info.id
      reinitClanWindow()
    }
  }

  function afterClanLeave() {} //page will update after clan info update

  function showLb()
  {
    curPageObj = scene.findObject("clans_list_content")
    if(!curPageObj)
      return goBack()
    curPageObj.show(true)
    curPageObj.enable(true)

    if(!clanLbInited ||
       (::my_clan_info == null && myClanLbData != null) ||
       (::my_clan_info != null && myClanLbData == null))
      initClanLeaderboards()

    fillModeListBox(curPageObj, getCurDMode(), get_show_in_squadron_statistics)
    initFocusArray()
  }

  function onStatsModeChange(obj)
  {
    if (!::checkObj(obj))
      return
    local value = obj.getValue()
    local diff = ::g_difficulty.getDifficultyByDiffCode(value)
    if(!::get_show_in_squadron_statistics(diff.crewSkillName))
      return

    curMode = value
    setCurDMode(curMode)
    fillClanReward()
    calculateRowNumber()
    getClansLbData(true)
  }

  function onEraChange(obj)
  {
    if (!::checkObj(obj))
      return
    curEra = obj.getValue() + 1
    clansLbSort = getCurrentSortField()
    if (clanLbInited)
      getClansLbData(true)
  }

  function showMyClanPage(forceReinit = null)
  {
    if(!myClanInited || forceReinit)
      initMyClanPage()

    curPageObj = scene.findObject(::my_clan_info ? "clan_container" : "clan_info_not_in_clan")
    if(!curPageObj)
      return

    curPageObj.show(true)
    curPageObj.enable(true)

    if(!::my_clan_info)
    {
      local requestSent = false
      if(::clan_get_requested_clan_id() != "-1" && clan_get_my_clan_name() != "")
      {
        requestSent = true
        curPageObj.findObject("req_clan_name").setValue(::clan_get_my_clan_tag() + " " + clan_get_my_clan_name())
      }
      curPageObj.findObject("reques_to_clan_sent").show(requestSent)
      curPageObj.findObject("how_to_get_membership").show(!requestSent)
    }
    else {
      clanData = ::my_clan_info
      local modesObj = curPageObj.findObject("modes_list")
      if (!::check_obj(modesObj))
        return

      requestWwMembersList()
      updateModesTabsContent(modesObj, {
        tabs = getModesTabsView(getCurDMode(), ::get_show_in_squadron_statistics).append({
          id = "worldwar_mode"
          hidden = (curWwMembers?.len() ?? 0) <= 0
          tabName = ::loc("userlog/page/worldWar")
          selected = false
          isWorldWarMode = true
          tooltip = ::loc("worldwar/ClanMembersLeaderboard/tooltip")
        })
      })
    }
    initFocusArray()
  }

  function getClansLbFieldName(lbCategory = null, mode = null)
  {
    local actualCategory = lbCategory || clansLbSort
    local fieldName = ("field" in actualCategory ? actualCategory.field : actualCategory.id)
    if (actualCategory.byDifficulty)
      fieldName += ::g_difficulty.getDifficultyByDiffCode(mode ?? curMode).clanDataEnding
    return fieldName
  }

  function getClanLBPage(seasonOrdinalNumber, onSuccessCb = null, onErrorCb = null)
  {
    local requestBlk = ::DataBlock()
    requestBlk["start"] <- curClanLbPage * clansPerPage
    requestBlk["count"] <- requestingClansCount
    requestBlk["seasonOrdinalNumber"] <- seasonOrdinalNumber
    requestBlk["sortField"] <- getClansLbFieldName()
    requestBlk["shortMode"] <- "on"
    return ::g_tasker.charRequestBlk("cln_clan_get_leaderboard", requestBlk, null, onSuccessCb, onErrorCb)
  }

  function getClanLBPosition(fieldName, seasonOrdinalNumber, onSuccessCb = null, onErrorCb = null)
  {
    local requestBlk= ::DataBlock()
    requestBlk["clanId"] <- ::clan_get_my_clan_id()
    requestBlk["seasonOrdinalNumber"] <- seasonOrdinalNumber
    requestBlk["sortField"] <- fieldName
    requestBlk["shortMode"] <- "on"
    return ::g_tasker.charRequestBlk("cln_clan_get_leaderboard", requestBlk, null, onSuccessCb, onErrorCb)
  }

  function findClanByPrefix(prefix, onSuccessCb = null, onErrorCb = null)
  {
    local requestBlk = ::DataBlock()
    requestBlk["namePrefix"] <- prefix
    requestBlk["tagPrefix"] <- prefix
    requestBlk["start"] <- curClanLbPage * clansPerPage
    requestBlk["count"] <- requestingClansCount
    requestBlk["shortMode"] <- "on"
    return ::g_tasker.charRequestBlk("cln_clan_find_by_prefix", requestBlk, null, onSuccessCb, onErrorCb)
  }

  function getClansLbData(updateMyClanRow = false, seasonOrdinalNumber = -1)
  {
    showEmptySearchResult(false)
    if (::clan_get_my_clan_id() == "-1" && myClanLbData != null)
      myClanLbData = null
    if (updateMyClanRow && ::clan_get_my_clan_id() != "-1")
    {
      local cbSuccess = ::Callback((@(seasonOrdinalNumber) function(myClanRowBlk) {
                                      local myClanId = ::clan_get_my_clan_id()
                                      local found = false
                                      foreach(row in myClanRowBlk % "clan")
                                        if(row._id == myClanId)
                                        {
                                          myClanLbData = ::buildTableFromBlk(row)
                                          myClanLbData.astat <- ::buildTableFromBlk(row.astat)
                                          found = true
                                          break
                                        }
                                      if(!found)
                                        myClanLbData = null
                                      requestLbData(seasonOrdinalNumber)
                                    })(seasonOrdinalNumber), this)

      getClanLBPosition(getClansLbFieldName(), seasonOrdinalNumber, cbSuccess)
    }
    else
      requestLbData(seasonOrdinalNumber)
  }

  function requestLbData(seasonOrdinalNumber)
  {
    local cbSuccess = ::Callback(function(data)
                                 {
                                   lbDataCb(data)
                                 }, this)

    if (isSearchMode && searchRequest.len() > 0)
      findClanByPrefix(searchRequest, cbSuccess)
    else
      getClanLBPage(seasonOrdinalNumber, cbSuccess)
  }

  function onSearchStart()
  {
    curClanLbPage = 0
    searchRequest = scene.findObject("search_edit").getValue()
    searchRequest = searchRequest.len() > 0 ? ::clearBorderSymbols(searchRequest, [" "]) : ""
    isSearchMode = searchRequest.len() > 0
    showEmptySearchResult(false)
    if(isSearchMode)
      requestLbData(-1)
    else
      return getClansLbData()
  }

  function onBackToClanlist()
  {
    curClanLbPage = 0
    searchRequest = ""
    isSearchMode = false
    getClansLbData()
  }

  function lbDataCb(lbBlk)
  {
    if (!::checkObj(scene))
      return

    local lbPageObj = scene.findObject("clans_list_content")
    if (!::checkObj(lbPageObj))
      return

    ::showBtn("btn_back_to_clanlist", isSearchMode, lbPageObj)

    if (isSearchMode && !("clan" in lbBlk))
    {
      showEmptySearchResult(true)
      clanByRow.clear()
      updateButtons()
      return
    }

    printLeaderboards(lbBlk)

    local paginatorObj = lbPageObj.findObject("mid_nav_bar")
    local myPage = (myClanLbData != null && "pos" in myClanLbData) ? floor(myClanLbData.pos / clansPerPage) : null
    generatePaginator(paginatorObj, this, curClanLbPage, curClanLbPage + (isLastPage? 0 : 1), myPage)
  }

  function showEmptySearchResult(show)
  {
    scene.findObject("search_status").display = show ? "show" : "hide"
    local lbTableObj = scene.findObject("clan_lboard_table")
    guiScene.replaceContentFromText(lbTableObj, "", 0, this)
  }

  function printLeaderboards(clanLbBlk)
  {
    local lbPageObj = scene.findObject("clans_list_content")
    if (!::checkObj(lbPageObj))
      return

    local lbTableObj = lbPageObj.findObject("clan_lboard_table")
    local data = ""
    rowsTexts = {}
    tooltips = {}
    clanByRow.clear()
    local rowIdx = 0
    isLastPage = true
    foreach(name, rowBlk in clanLbBlk % "clan")
    {
      if (typeof(rowBlk) != "instance")
        continue

      if (rowIdx >= clansPerPage)
      {
        isLastPage = false
        continue
      }

      data += generateRowTableData(rowBlk, rowIdx++)
      clanByRow[rowIdx.tostring()] <- rowBlk._id.tostring()
    }

    local lastRowIdx = lbTableObj.getValue()
    if (rowIdx < clansPerPage)
    {
      lastRowIdx = ::min(rowIdx,lastRowIdx)
      for(local i = rowIdx; i < clansPerPage; i++)
      {
        data += buildTableRow("row_" + rowIdx++, [], rowIdx % 2 == 0, "inactive:t='yes';")
        clanByRow[rowIdx.tostring()] <- null
      }
    }

    if(myClanLbData != null)
    {
      data += buildTableRow("row_" + clansPerPage, ["..."], null, "inactive:t='yes'; commonTextColor:t='yes'; style:t='height:0.7@leaderboardTrHeight;'; ")
      rowIdx++
      data += generateRowTableData(myClanLbData, clansPerPage + 1)
      rowIdx++
      clanByRow[rowIdx.tostring()] <- myClanLbData._id.tostring()
    }
    local headerRow = [{text = "#multiplayer/place", width = "0.1@sf"}, {text = ""}, { text = "#clan/clan_name", tdAlign = "left",  width = "@clanNameTableWidth"}]
    foreach(item in ::clan_leaderboards_list)
    {
      if (!isColForDisplay(item))
        continue
      local block = {
        id = item.id
        image = item.icon
        tooltip = item.tooltip
        active = clansLbSort.id == item.id
        needText = false
      }
      if(!("field" in item) || !item.sort)
        block.rawParam <- "no-hover:t='yes';"
      if(item.sort)
        block.callback <- "onCategory"
      headerRow.append(block)
    }
    data = buildTableRow("row_header", headerRow, null, "inactive:t='yes'; commonTextColor:t='yes'; bigIcons:t='yes'; style:t='height:0.05sh;'; ") + data
    guiScene.setUpdatesEnabled(false, false)
    guiScene.replaceContentFromText(lbTableObj, data, data.len(), this)
    foreach(rowName, row in rowsTexts)
      foreach(name, value in row)
        lbTableObj.findObject(rowName).findObject(name).setValue(value)
    foreach(rowName, row in tooltips)
      foreach(name, value in row)
        lbTableObj.findObject(rowName).findObject(name).tooltip = value
    guiScene.setUpdatesEnabled(true, true)

    if (curPage == "clans_list")
    {
      restoreFocus()
      lbTableObj.setValue(lastRowIdx)
      onSelectLb()
    }
  }

  function generateRowTableData(rowBlk, rowIdx)
  {
    local slogan = rowBlk.slogan == "" ? "" : rowBlk.slogan == " " ? "" : rowBlk.slogan
    local desc = rowBlk.desc == "" ? "" : rowBlk.desc == " " ? "" : rowBlk.desc
    local rowName = "row_" + rowIdx
    desc = ::g_chat.filterMessageText(desc, false)
    slogan = ::g_chat.filterMessageText(slogan, false)
    local tooltipText = ::ps4CheckAndReplaceContentDisabledText(slogan + (slogan != "" && desc != ""? "\n" : "") + desc)
    local clanType = ::g_clan_type.getTypeByName(::getTblValue("type", rowBlk, ""))
    local highlightRow = myClanLbData != null && myClanLbData._id == rowBlk._id ? true : false
    rowsTexts[rowName] <- {
      txt_name = colorizeClanText(clanType, ::ps4CheckAndReplaceContentDisabledText(rowBlk.name), highlightRow)
      txt_tag = colorizeClanText(clanType, ::checkClanTagForDirtyWords(rowBlk.tag), highlightRow)
    }
    tooltips[rowName] <- { name = tooltipText}
    local rowData = [
      rowBlk.pos + 1
      {
        id = "tag"
        tdAlign = "right"
        textType = "textareaNoTab"
      }
      {
        id = "name"
        tdAlign = "left"
        textType = "textareaNoTab"
      }
    ]
    foreach(item in ::clan_leaderboards_list)
      if (isColForDisplay(item))
        rowData.append(getItemCell(item, rowBlk, rowName))

    ::dagor.assertf(typeof(rowBlk._id) == "string", "leaderboards receive _id type " + typeof(rowBlk._id) + ", instead of string on clan_request_page_of_leaderboard")
    return buildTableRow(rowName, rowData, rowIdx % 2 == 0, highlightRow ? "mainPlayer:t='yes';" : "")
  }

  function colorizeClanText(clanType, clanText, isMainPlayer)
  {
    return isMainPlayer ? clanText : ::colorize(clanType.color, clanText)
  }

  function getItemCell(item, rowBlk, rowName)
  {
    local itemId = getClansLbFieldName(item)

    if(!("astat" in rowBlk) && !rowBlk.astat)
      rowBlk.astat = ::DataBlock()
    local value = itemId == "members_cnt"
                  ? ("members_cnt" in rowBlk && rowBlk.members_cnt ? rowBlk.members_cnt : 0)
                  : (itemId in rowBlk.astat && rowBlk.astat[itemId] ? rowBlk.astat[itemId] : 0)

    local res = ::getLbItemCell(item.id, value, item.type)
    res.active <- clansLbSort.id == item.id
    if ("tooltip" in res)
    {
      if (!(rowName in tooltips))
        tooltips[rowName] <- {}
      tooltips[rowName][item.id] <- res.rawdelete("tooltip")
    }
    return res
  }

  function isColForDisplay(column)
  {
    local colName = column.id
    if (colName.len() < ::ranked_column_prefix.len() ||
        colName.slice(0, ::ranked_column_prefix.len()) != ::ranked_column_prefix)
    {
      local showByFeature = ::getTblValue("showByFeature", column, null)
      if (showByFeature != null && !::has_feature(showByFeature))
        return false

      return true
    }

    return colName == ::ranked_column_prefix + curEra
  }

  function onCategory(obj)
  {
    if (!::check_obj(obj))
      return

    if (isClanInfo && isWorldWarMode)
    {
      if (curWwCategory?.id != obj.id)
      {
        curWwCategory = ::g_lb_category.getTypeById(obj.id)
        fillClanWwMemberList()
      }
      return
    }

    foreach(idx, category in ::clan_leaderboards_list)
      if (obj.id == category.id)
      {
        clansLbSort = category
        break
      }
    curClanLbPage = 0
    getClansLbData(true)
  }

  function onCancelSearchEdit(obj)
  {
    if(obj.getValue().len() > 0)
      obj.setValue("")
    else
      goBack();
  }

  function onSelectLb()
  {
    guiScene.performDelayed(this, (function () {
      if (isValid())
        updateButtons()
    }))
  }

  function updateButtons()
  {
    local clansTableObj = scene.findObject("clan_lboard_table")
    local clan = getCurClan()

    local buttons = {
      btn_clan_info = clan != null && clansTableObj && clansTableObj.isFocused()
      btn_membership_req = !::is_in_clan() && clan != null && ::clan_get_requested_clan_id() != clan
        && clansTableObj && clansTableObj.isFocused()
      mid_nav_bar = clanByRow.len() > 0
    }

    ::showBtnTable(curPageObj, buttons)

    local reqButton = curPageObj.findObject("btn_membership_req")
    if(::checkObj(reqButton))
    {
      local opened = true
      if(curPageData)
        foreach(rowBlk in curPageData % "clan")
          if(rowBlk._id == clan)
          {
            opened = rowBlk.status != "closed"
            break
          }
      reqButton.enable(opened)
      reqButton.tooltip = opened ? "" : ::loc("clan/was_closed")
    }
  }

  function getCurClan()
  {
    local objTbl = curPageObj.findObject("clan_lboard_table")
    if (!::check_obj(objTbl))
      return null

    return clanByRow?[objTbl.getValue().tostring()]
  }

  function onEventClanMembershipRequested(p)
  {
    updateButtons()
  }

  function onEventClanMembershipCanceled(p)
  {
    showMyClanPage()
  }

  function onClanInfo()
  {
    local clan = getCurClan()
    if (clan == null)
      return

    showClanPage(clan, "", "")
  }

  function onSelectClansList()
  {
    onSelectLb()
  }

  function goToPage(obj)
  {
    curClanLbPage = obj.to_page.tointeger()
    getClansLbData()
  }

  function onCreateClanWnd()
  {
    if (::has_feature("Clans")){
      if (!::ps4_is_ugc_enabled())
        ::ps4_show_ugc_restriction()
      else
        ::gui_modal_new_clan()
    }
    else
      msgBox("not_available", ::loc("msgbox/notAvailbleYet"), [["ok", function() {} ]], "ok", { cancel_fn = function() {}})
  }

  function onEventClanInfoUpdate(params = {})
  {
    initMyClanPage()
    onSheetChange()
  }

  function onClanRclick(position = null)
  {
    local clanId = getCurClan()
    if (!clanId)
      return

    local menu = clanContextMenu.getClanActions(clanId)
    ::gui_right_click_menu(menu, this, position)
  }

  function onCancelRequest()
  {
    msgBox("cancel_request_question",
           ::loc("clan/cancel_request_question"),
           [
             ["ok", @() ::g_clans.cancelMembership()],
             ["cancel", @() null]
           ],
           "ok",
           { cancel_fn = @() null }
          )
  }

  function fillClanReward()
  {
    local objFrameBlock = scene.findObject("clan_battle_season_frame_block")
    if (!::checkObj(objFrameBlock))
      return

    //Don't show any rewards if seasons disabled
    local seasonsEnabled = ::g_clan_seasons.isEnabled()
    objFrameBlock.show(seasonsEnabled)
    scene.findObject("clan_battle_season_coming_soon").show(!seasonsEnabled)
    if (!seasonsEnabled)
    {
      //fallback to older seasons version
      fillClanReward_old()
      return
    }

    local showAttributes = ::has_feature("ClanSeasonAttributes")

    local seasonName = ::g_clan_seasons.getSeasonName()
    local diff = ::g_difficulty.getDifficultyByDiffCode(getCurDMode())

    //Fill current season name
    local objSeasonName = scene.findObject("clan_battle_season_name")
    if (::checkObj(objSeasonName) && showAttributes)
      objSeasonName.setValue(::loc("clan/battle_season/title") + ::loc("ui/colon") + ::colorize("userlogColoredText", seasonName))

    //Fill season logo medal
    local objTopMedal = scene.findObject("clan_battle_season_logo_medal")
    if (::checkObj(objTopMedal) && showAttributes)
    {
      objTopMedal.show(true)
      local iconStyle = "clan_season_logo_" + diff.egdLowercaseName
      local iconParams = { season_title = { text = seasonName } }
      ::LayersIcon.replaceIcon(objTopMedal, iconStyle, null, null, null, iconParams)
    }

    //Fill current seasons end date
    local objEndsDuel = scene.findObject("clan_battle_season_ends")
    if (::checkObj(objEndsDuel))
    {
      local endDateText = ::loc("clan/battle_season/ends") + ::loc("ui/colon") + "\n" + ::g_clan_seasons.getSeasonEndDate()
      objEndsDuel.setValue(endDateText)
    }

    //Fill top rewards
    local clanTableObj = scene.findObject("clan_battle_season_reward_table")
    if (::checkObj(clanTableObj))
    {
      local rewards = ::g_clan_seasons.getFirstPrizePlacesRewards(
        ::CLAN_SEASONS_TOP_PLACES_REWARD_PREVIEW,
        diff
      )
      local rowBlock = ""
      foreach (placeIndex, reward in rewards)
      {
        local placeText = (reward.place >= 1 && reward.place <= 3) ?
          ::loc("clan/season_award/place/place" + reward.place) :
          ::loc("clan/season_award/place/placeN", { placeNum = reward.place })

        local rowData = []
        rowData.append({
          text = placeText,
          active = false,
          tdAlign ="right"
        })

        local rewardText = ::Cost(0, reward.gold).tostring()
        rowData.append({
          needText = false,
          rawParam = @"text {
            text-align:t='right';
            text:t='" + rewardText + @"';
            size:t='pw, ph';
            margin-left:t='1@blockInterval'
            style:t='re-type:textarea;behaviour:textarea;';
          }",
          active = false
        })

        rowBlock += ::buildTableRowNoPad("row_" + placeIndex, rowData, null, "")
      }
      guiScene.replaceContentFromText(clanTableObj, rowBlock, rowBlock.len(), this)
    }

    local objInfoBtn = scene.findObject("clan_battle_season_info_btn")
    if (::checkObj(objInfoBtn) && showAttributes)
      objInfoBtn.show(true)
  }

  function fillClanReward_old()
  {
    if (!::checkObj(scene))
      return
    local objFrameBlock = scene.findObject("clan_battle_season_frame_block_old")
    if (!::checkObj(objFrameBlock))
      return

    local battleSeasonAvailable = ::has_feature("ClanBattleSeasonAvailable")
    objFrameBlock.show(battleSeasonAvailable)
    scene.findObject("clan_battle_season_coming_soon").show(!battleSeasonAvailable)
    if (!battleSeasonAvailable)
      return

    local dateDuel = ::clan_get_current_season_info().rewardDay
    if (dateDuel <= 0)
    {
      objFrameBlock.show(false)
      return
    }
    local endsDate = time.buildDateTimeStr(dateDuel, false, false)
    local objEndsDuel = scene.findObject("clan_battle_season_ends")
    if (::checkObj(objEndsDuel))
      objEndsDuel.setValue(::loc("clan/battle_season/ends") + ::loc("ui/colon") + endsDate)

    local blk = ::get_game_settings_blk()
    if (!blk)
      return
    local curMode = getCurDMode()
    local topPlayersRewarded = ::get_blk_value_by_path(blk, "clanDuel/reward/topPlayersRewarded", 10)
    local diff = ::g_difficulty.getDifficultyByDiffCode(curMode)
    local rewardPath = "clanDuel/reward/" + diff.egdLowercaseName + "/era5"
    local rewards = ::get_blk_value_by_path(blk, rewardPath)
    if (!rewards)
      return

    objFrameBlock.show(true)
    local rewObj = scene.findObject("clan_battle_season_reward_description")
    if (::checkObj(rewObj))
      rewObj.setValue(::format(::loc("clan/battle_season/reward_description"), topPlayersRewarded))

    local clanTableObj = scene.findObject("clan_battle_season_reward_table");
    if (!::checkObj(clanTableObj))
      return

    local rowBlock = ""
    for (local i=1; i<=3; i++)
    {
      local rowData = []
      rowData.append({text = ::loc("clan/battle_season/place_"+i), active = false, tdAlign="right"})
      rowData.append({
        needText=false,
        rawParam="text { text-align:t='right'; text:t='" +
          ::Cost(0, ::getTblValue("place"+i+"Gold", rewards, 0)).tostring() +
          "'; size:t='pw,ph'; style:t='re-type:textarea; behaviour:textarea;'; }",
        active = false
      })
      rowBlock += ::buildTableRowNoPad("row_"+i, rowData, null, "")
    }
    guiScene.replaceContentFromText(clanTableObj, rowBlock, rowBlock.len(), this)
  }

  function onClanSeasonInfo()
  {
    if (!::g_clan_seasons.isEnabled() || !::has_feature("ClanSeasonAttributes"))
      return
    local diff = ::g_difficulty.getDifficultyByDiffCode(getCurDMode())
    ::show_clan_season_info(diff)
  }

  function getWndHelpConfig()
  {
    local res = {}
    if (curPage == "clans_list")
    {
      res.textsBlk <- "gui/clans/clansModalHandlerListHelp.blk"
      res.objContainer <- scene.findObject("clans_list_content")

      local links = [
        { obj = ["img_dr_era1", "img_dr_era2", "img_dr_era3", "img_dr_era4", "img_dr_era5"]
          msgId = "hint_dr_era_column_header"
        }

        { obj = "img_members_cnt"
          msgId = "hint_members_cnt"
        }

        { obj = "img_air_kills"
          msgId = "hint_air_kills"
        }

        { obj = "img_ground_kills"
          msgId = "hint_ground_kills"
        }

        { obj = "img_deaths"
          msgId = "hint_deaths"
        }

        { obj = "img_time_pvp_played"
          msgId = "hint_time_pvp_played"
        }

        { obj = "img_activity"
          msgId = "hint_activity"
        }
      ]

      res.links <- links
      return res
    }
    else if (curPage == "my_clan")
      return base.getWndHelpConfig()
    return res
  }

  function updateWwMembersList()
  {
    if (!isClanInfo)
      return

    if(isWorldWarMode)
      fillClanWwMemberList()
    else
      showSceneBtn("worldwar_mode", (curWwMembers?.len() ?? 0) > 0)
  }
}
