function showClanPage(id, name, tag)
{
  ::gui_start_modal_wnd(::gui_handlers.clanPageModal,
    {
      clanIdStrReq = id,
      clanNameReq = name,
      clanTagReq = tag
    })
}

class ::gui_handlers.clanPageModal extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType      = handlerType.MODAL
  sceneBlkName = "gui/clans/clanPageModal.blk"

  clanIdStrReq = ""
  clanNameReq  = ""
  clanTagReq   = ""

  isClanInfo = true
  isMyClan = false
  myRights = []

  statsSortReverse = false
  statsSortBy      = ""
  clanData         = null
  curEra           = ::max_country_rank
  curPlayer        = null
  curClan          = null
  curMode          = 0
  currentFocusItem = 5

  function initScreen()
  {
    if(clanIdStrReq == "" && clanNameReq == "" && clanTagReq == "")
    {
      goBack()
      return
    }
    curMode = getCurDMode()
    reinitClanWindow()
    initFocusArray()
  }

  function setDefaultSort()
  {
    statsSortBy = ::ranked_column_prefix + curEra + ::domination_modes[curMode].clanDataEnding
  }

  function reinitClanWindow()
  {
    if (::is_in_clan() &&
      (::clan_get_my_clan_id() == clanIdStrReq ||
       ::clan_get_my_clan_name() == clanNameReq ||
       ::clan_get_my_clan_tag() == clanTagReq))
    {
      ::getMyClanData()
      if (!::my_clan_info)
        return

      clanData = ::my_clan_info
      setDefaultSort()
      fillClanPage()
      return
    }
    taskId = ::clan_request_info(clanIdStrReq, clanNameReq, clanTagReq)
    if (taskId >= 0)
    {
      ::set_char_cb(this, slotOpCb)
      afterSlotOp = function()
      {
        clanData = ::get_clan_info_table()
        if (!clanData)
          return goBack()

        setDefaultSort()
        fillClanPage()
        ::broadcastEvent("ClanInfoAvailable", {clanId = clanData.id})
      }
      afterSlotOpError = function(result)
      {
        goBack()
        return
      }
    }
    else
    {
      goBack()
      msgBox("unknown_identification", ::loc("charServer/updateError/13"),
        [["ok", function() {} ]], "ok")
      dagor.debug(::format("Failed to find clan by id: %s", clanIdStrReq))
      return
    }
  }

  function onEventClanInfoUpdate(params = {})
  {
    if (clanIdStrReq == clan_get_my_clan_id()
        || (clanData && clanData.id == clan_get_my_clan_id()))
    {
      if (!::my_clan_info)
        return goBack()
      clanData = ::my_clan_info
      clanData = ::getFilteredClanData(clanData)
      fillClanPage()
    }
  }

  function onEventProfileUpdated(p)
  {
    fillClanManagment()
  }

  function fillClanInfoRow(id, text, feature = "")
  {
    local obj = scene.findObject(id)
    if (!::check_obj(obj))
      return

    if (!::u.isEmpty(feature) && !::has_feature(feature))
      text = ""
    text = ::getFilteredChatMessage(text, false)

    obj.setValue(text)
  }

  function fillClanPage()
  {
    if (!::checkObj(scene))
      return

    isMyClan = ::clan_get_my_clan_id() == clanData.id;
    scene.findObject("clan_loading").show(false)

    showSceneBtn("clan-icon", true)

    fillClanInfoRow("clan-region", clanData.region, "ClanRegions")
    fillClanInfoRow("clan-announcement", clanData.announcement, "ClanAnnouncements")
    fillClanInfoRow("clan-motto", clanData.slogan)
    fillClanInfoRow("clan-desc", clanData.desc)

    fillCreatorData()

    scene.findObject("nest_lock_clan_req").clan_locked = clanData.status == "closed" ? "yes" : "no"

        // Showing clan name in special header object if possible.
    local clanName = clanData.tag + " " + clanData.name
    local headerTextObj = scene.findObject("clan_page_header_text")
    local clanTitleObj = scene.findObject("clan-title")
    if (::checkObj(headerTextObj))
    {
      local locId = "clan/clanInfo/" + clanData.type.getTypeName()
      local text = ::colorize(clanData.type.color, ::loc(locId, { clanName = clanName }))
      headerTextObj.setValue(text)
      clanTitleObj.setValue("")
    }
    else
      clanTitleObj.setValue(::colorize(clanData.type.color, clanName))

    local clanDate = clanData.getCreationData()
    scene.findObject("clan-creationDate").setValue(::loc("clan/creationDate")+" "+clanDate);

    local membersCountText = ::g_clans.getClanMembersCount(clanData)
    local text = ::loc("clan/memberListTitle") + ::loc("ui/parentheses/space", {text = membersCountText})
    scene.findObject("clan-memberCount").setValue(text)

    fillClanRequirements()

    local ltm = ::get_local_time()
    local utc = ::get_utc_time()
    local updStatsText = ::format("%d:00", (24 + ltm.hour-utc.hour)%24) //00:00 utc time
    updStatsText = format(::loc("clan/updateStatsTime"), updStatsText)
    scene.findObject("update_stats_info_text").setValue(updStatsText)

    fillModeListBox(scene.findObject("clan_container"), getCurDMode(), true, false, ::get_show_in_squadron_statistics)
    fillClanManagment()

    showSceneBtn("clan_main_stats", true)
    fillClanStats(clanData.astat)
  }

  function fillCreatorData()
  {
    local obj = scene.findObject("clan-prevChanges")
    if (!::check_obj(obj))
      return

    local isVisible = ::has_feature("ClanChangedInfoData")
                      && clanData.changedByUid != ""
                      && clanData.changedByNick != ""
                      && clanData.changedTime

    local text = ""
    if (isVisible)
    {
      text += ::loc("clan/lastChanges") + ::loc("ui/colon")
      if (::my_user_id_str == clanData.changedByUid)
        text += ::colorize("mainPlayerColor", clanData.changedByNick)
      else
        text += clanData.changedByNick

      text += ::loc("ui/comma") + clanData.getInfoChangeDate()
    }
    obj.setValue(text)
  }

  function fillClanRequirements()
  {
    local rawRanksCond = clanData.membershipRequirements.getBlockByName("ranks") || ::DataBlock();

    local ranksConditionTypeText =  (rawRanksCond.type == "or") ?
                                      ::loc("clan/rankReqInfoCondType_or") :
                                      ::loc("clan/rankReqInfoCondType_and");

    local ranksReqText = "";
    local haveRankReq = false;
    foreach( ut in ::unitTypesList )
    {
      local unitType = getUnitTypeText(ut);        // Aircraft, Tank
      local req = rawRanksCond.getBlockByName("rank_"+unitType);
      if ( req &&  (req.type == "rank")  &&  (req.unitType == unitType) )
      {
        local ranksRequired = req.getInt("rank",0);
        if ( ranksRequired > 0 )
        {
          if ( !haveRankReq )
            ranksReqText = ::loc("clan/rankReqInfoHead");
          else
            ranksReqText += " "+ranksConditionTypeText;

          haveRankReq = true;
          ranksReqText += ( " " + ::loc("clan/rankReqInfoRank"+unitType) + " " +
                            ::colorize("activeTextColor", ::getUnitRankName(ranksRequired)) );
        }
      }
    }

    scene.findObject("clan-membershipReqRank").setValue( ranksReqText );

    local battlesConditionTypeText = ::loc("clan/battlesReqInfoCondType_and");
    local battlesReqText = "";
    local haveBattlesReq = false;
    foreach(diff in ::g_difficulty.types)
      if (diff.egdCode != ::EGD_NONE)
      {
        local modeName = diff.getEgdName(false); // arcade, historical, simulation
        local req = clanData.membershipRequirements.getBlockByName("battles_"+modeName);
        if ( req  &&  (req.type == "battles")  &&  (req.difficulty == modeName) )
        {
          local battlesRequired = req.getInt("count", 0);
          if ( battlesRequired > 0 )
          {
            if ( !haveBattlesReq )
              battlesReqText = ::loc("clan/battlesReqInfoHead");
            else
              battlesReqText += " " + ranksConditionTypeText;

            haveBattlesReq = true;
            battlesReqText += ( " " + ::loc("clan/battlesReqInfoMode_"+modeName) + " " +
                                ::colorize("activeTextColor", battlesRequired.tostring()) );
          }
        }
      }

    scene.findObject("clan-membershipReqBattles").setValue( battlesReqText );
  }


  function fillClanManagment()
  {
    if (!clanData)
      return

    local adminMode = clan_get_admin_editor_mode()
    local myClanId = clan_get_my_clan_id();
    local showMembershipsButton = false
    isMyClan = myClanId == clanData.id;

    if (!isMyClan && myClanId == "-1" && clan_get_requested_clan_id() != clanData.id && clanData.status != "closed")
    {
      curClan = clanData.id
      showMembershipsButton = true
    }

    if(isMyClan || adminMode)
      myRights = clan_get_role_rights(adminMode ? ::ECMR_CLANADMIN : clan_get_my_role())
    else
      myRights = []

    local showBtnLock = isMyClan && isInArray("CHANGE_INFO", myRights) || adminMode
    local hasAdminRight = ::is_myself_clan_moderator()
    local hasLeaderRight = isInArray("LEADER", myRights)
    local showMembershipsReqEditorButton = ( ::has_feature("ClansMembershipEditor") ) && (
                                            ( isMyClan && isInArray("CHANGE_INFO", myRights) ) || clan_get_admin_editor_mode() )
    local showClanSeasonRewards = ::has_feature("ClanSeasonRewardsLog") && (clanData.rewardLog.len() > 0)

    local buttonsList = {
      btn_showRequests = ((isMyClan && (isInArray("MEMBER_ADDING", myRights) || isInArray("MEMBER_REJECT", myRights))) || adminMode) && clanData.candidates.len() > 0,
      btn_leaveClan = isMyClan && (!hasLeaderRight || getLeadersCount() > 1),
      btn_edit_clan_info = ::ps4_is_ugc_enabled() && ((isMyClan && isInArray("CHANGE_INFO", myRights)) || adminMode)
      btn_upgrade_clan = clanData.type.getNextType() != ::g_clan_type.UNKNOWN && (adminMode || isMyClan && hasLeaderRight)
      btn_showBlacklist = isMyClan && isInArray("MEMBER_BLACKLIST", myRights) && clanData.blacklist.len()
      btn_lock_clan_req = showBtnLock
      img_lock_clan_req = !showBtnLock && clanData.status == "closed"
      btn_complain = !isMyClan
      btn_membership_req = showMembershipsButton
      btn_log = ::has_feature("ClanLog") && (isMyClan || adminMode)
      btn_season_reward_log = showClanSeasonRewards
      clan_awards_container = showClanSeasonRewards
      btn_clan_membership_req_edit = showMembershipsReqEditorButton
    }
    ::showBtnTable(scene, buttonsList)

    local showRequestsBtn = scene.findObject("btn_showRequests")
    if (::checkObj(showRequestsBtn))
    {
      local isShow = ::getTblValue("btn_showRequests", buttonsList, false)
      showRequestsBtn.setValue(::loc("clan/btnShowRequests")+" ("+clanData.candidates.len()+")")
      showRequestsBtn.wink = isShow ? "yes" : "no"
    }

    if (showClanSeasonRewards)
    {
      local containerObj = scene.findObject("clan_awards_container")
      if (::checkObj(containerObj))
        guiScene.performDelayed(this, (@(containerObj, clanData) function () {
          local count = ::g_dagui_utils.countSizeInItems(containerObj.getParent(), "@clanMedalSizeMin", 1, 0, 0).itemsCountX
          local medals = ::g_clans.getClanPlaceRewardLogData(clanData, count)
          local markup = ""
          foreach (m in medals)
            markup += "layeredIconContainer { size:t='@clanMedalSizeMin, @clanMedalSizeMin'; overflow:t='hidden' " +
              ::LayersIcon.getIconData(m.iconStyle, null, null, null, m.iconParams) + " }"
          guiScene.replaceContentFromText(containerObj, markup, markup.len(), this)
        })(containerObj, clanData))
    }

    updateAdminModeSwitch()
    updateUserOptionButton()
  }

  function updateUserOptionButton()
  {
    local show = false
    if (::show_console_buttons)
    {
      local obj = scene.findObject("clan-membersList")
      show = ::checkObj(obj) && obj.isFocused()
    }
    showSceneBtn("btn_user_options", show)
  }

  function fillClanElo()
  {
    local clanElo = ::getTblValue(::ranked_column_prefix + curEra + ::domination_modes[curMode].clanDataEnding, clanData.astat, 0)
    local eloTextObj = scene.findObject("clan_elo_value")
    local eloIconObj = scene.findObject("clan_elo_icon")
    if (!::checkObj(eloTextObj) || !::checkObj(eloIconObj))
      return
    eloTextObj.setValue(clanElo.tostring())
    eloIconObj["background-image"] = "#ui/gameuiskin#lb_dr_era" + curEra
  }

  function fillClanActivity()
  {
    local activityTextObj = scene.findObject("clan_activity_value")
    local activityIconObj = scene.findObject("clan_activity_icon")
    if (!::checkObj(activityTextObj) || !::checkObj(activityIconObj))
      return

    local showActivity = ::has_feature("ClanActivity")
    if (showActivity)
    {
      local clanActivity = ::getTblValue("activity", clanData.astat, 0)
      activityTextObj.setValue(clanActivity.tostring())
      activityIconObj["background-image"] = "#ui/gameuiskin#lb_activity"
    }
    activityTextObj.show(showActivity)
    activityIconObj.show(showActivity)
  }

  function setCurDMode(mode)
  {
    ::saveLocalByAccount("wnd/clanDiffMode", mode)
  }

  function getCurDMode()
  {
    local diffMode = ::loadLocalByAccount(
      "wnd/clanDiffMode",
      ::get_current_shop_difficulty().diffCode
    )

    local diff = ::g_difficulty.getDifficultyByDiffCode(diffMode)

    if (::get_show_in_squadron_statistics(diff.crewSkillName))
      return diffMode
    return ::g_difficulty.ARCADE.diffCode
  }

  function cp_onStatsModeChange(obj)
  {
    local value = obj.getValue()
    if(value in ::domination_modes)
      curMode = value

    setCurDMode(curMode)
    updateSortingField()
    fillClanMemberList(clanData.members)
    fillClanElo()
    fillClanActivity()
  }

  function updateSortingField()
  {
    if (statsSortBy.len() >= ::ranked_column_prefix.len() &&
        statsSortBy.slice(0, ::ranked_column_prefix.len()) == ::ranked_column_prefix)
      statsSortBy = ::ranked_column_prefix + curEra + ::domination_modes[curMode].clanDataEnding
  }

  function updateAdminModeSwitch()
  {
    local show = isClanInfo && ::is_myself_clan_moderator()
    local enable = ::clan_get_admin_editor_mode()
    local obj = scene.findObject("admin_mode_switch")
    if (!::checkObj(obj))
    {
      if (!show)
        return
      local containerObj = scene.findObject("header_buttons")
      if (!::checkObj(containerObj))
        return
      local text = ::loc("clan/admin_mode")
      local markup = ::create_option_switchbox({
        id = "admin_mode_switch"
        value = enable
        textChecked = text
        textUnchecked = text
        cb = "onSwitchAdminMode"
      })
      guiScene.replaceContentFromText(containerObj, markup, markup.len(), this)
      obj = containerObj.findObject("admin_mode_switch")
      if (!::checkObj(obj))
        return
    }
    else
      obj.setValue(enable)
    obj.show(show)
  }

  function onSwitchAdminMode()
  {
    enableAdminMode(!::clan_get_admin_editor_mode())
  }

  function enableAdminMode(enable)
  {
    if (enable == ::clan_get_admin_editor_mode())
      return
    if (enable && (!isClanInfo || !::is_myself_clan_moderator()))
      return
    clan_set_admin_editor_mode(enable)
    fillClanManagment()
    onSelect()
  }

  function onShowRequests()
  {
    if ((!isMyClan || !isInArray("MEMBER_ADDING", myRights)) && !clan_get_admin_editor_mode())
      return;

    showClanRequests(clanData.candidates, clanData.id, this)
  }

  function onLockNewReqests()
  {
    local clanId = clan_get_admin_editor_mode() ? clanData.id : "-1"
    local locking = clanData.status == "closed" ? false : true

    taskId =  clan_request_close_for_new_members(clanId, locking)
    if (taskId >= 0)
    {
      ::set_char_cb(this, slotOpCb)
      showTaskProgressBox()
      if (clanId == "-1")
        ::sync_handler_simulate_signal("clan_info_reload")
      afterSlotOp = (@(locking) function() {
          if(clan_get_admin_editor_mode())
            reinitClanWindow()

          msgBox("left_clan", ::loc("clan/" + (locking ? "was_closed" : "was_opened")), [["ok", function() {} ]], "ok")
        })(locking)
    }
  }

  function onLeaveClan()
  {
    if (!isMyClan)
      return;

    msgBox("leave_clan", ::loc("clan/leaveConfirmation"),
      [
        ["yes", function()
        {
          leaveClan();
        }],
        ["no",  function() {} ],
      ], "no")
  }

  function leaveClan()
  {
    if (!::is_in_clan())
      return afterClanLeave()

    taskId = clan_request_leave()

    if (taskId >= 0)
    {
      ::set_char_cb(this, slotOpCb)
      showTaskProgressBox()
      ::sync_handler_simulate_signal("clan_info_reload")
      afterSlotOp = function()
        {
          ::update_gamercards()
          msgBox("left_clan", ::loc("clan/leftClan"), [["ok", function() { afterClanLeave() } ]], "ok")
        }
    }
  }

  function afterClanLeave()
  {
    goBack()
  }

  function fillClanStats(data)
  {
    local clanTableObj = scene.findObject("clan_stats_table");
    local rowIdx = 0
    local rowBlock = ""
    local rowHeader = [{width = "0.25pw"}]
    /*header*/
    foreach(item in ::clan_data_list)
    {
      rowHeader.append({
                       image = "#ui/gameuiskin#lb_" + item.id
                       tooltip = "#multiplayer/" + item.id
                       tdAlign="center"
                       active = false
                    })
    }
    rowBlock += ::buildTableRowNoPad("row_" + rowIdx, rowHeader, null, "class:t='smallIconsStyle'")
    rowIdx++

    /*body*/
    local diffItems = ::get_option(::USEROPT_DOMINATION_MODE).items
    foreach(block in diffItems)
    {
      if (!::get_show_in_squadron_statistics(::getTblValue("id", block)))
        continue

      local rowParams = []
      rowParams.append({
                         text = "#" + block.name,
                         active = false,
                         tdAlign="right"
                      })

      foreach(item in ::clan_data_list)
      {
        local dataId = item.field + block.clanDataEnding
        local value = dataId in data? data[dataId] : "0"
        local textCell = item.type.getShortTextByValue(value)

        rowParams.append({
                          text = textCell,
                          active = false,
                          tdAlign="center"
                        })
      }
      rowBlock += ::buildTableRowNoPad("row_" + rowIdx, rowParams, null, "")
      rowIdx++
    }
    guiScene.replaceContentFromText(clanTableObj, rowBlock, rowBlock.len(), this)
  }

  function fillClanMemberList(membersData)
  {
    sortMembers(membersData)
    local tblObj = scene.findObject("clan-membersList")
    local markUp = ""
    local rowIdx = 0

    local headerRow = [{text = "#clan/number", width = "0.1@scrn_tgt_font"}]
    foreach(column in ::clan_member_list)
    {
      if (::getTblValue("myClanOnly", column, false) && !isMyClan)
        continue
      local showByFeature = ::getTblValue("showByFeature", column, null)
      if (showByFeature != null && !::has_feature(showByFeature))
        continue

      local rowData = {
        id       = column.id,
        text     = ::getTblValue("needHeader", column, true) ? "#clan/" + ::getTblValue("loc", column, column.id) : "",
        tdAlign  = ::getTblValue("align", column, "center"),
        callback = "onStatsCategory",
        active   = isSortByColumn(column.id)
        tooltip  = column.tooltip
      }
      // It is important to set width to
      // all rows if column has fixed width.
      // Next two lines fix table layout issue.
      if (::getTblValue("iconStyle", column, false))
        rowData.width <- "0.01@scrn_tgt_font"
      headerRow.append(rowData)
    }
    markUp = ::buildTableRowNoPad("row_header", headerRow, null,
      "inactive:t='yes'; commonTextColor:t='yes'; bigIcons:t='yes'; style:t='height:0.05sh;'; ")

    foreach(member in membersData)
    {
      local rowName = "row_" + rowIdx
      local nick = ::stripTags(member.nick)
      local rowData = [{ text = (rowIdx + 1).tostring() }]
      foreach(column in ::clan_member_list)
      {
        if ((::getTblValue("myClanOnly", column, false) && !isMyClan))
          continue
        local showByFeature = ::getTblValue("showByFeature", column, null)
        if (showByFeature != null && !::has_feature(showByFeature))
          continue

        rowData.append(getClanMembersCell(member, column))
      }
      local isMe = member.nick == ::my_user_name
      markUp += ::buildTableRowNoPad(rowName, rowData, rowIdx % 2 == 0, (isMe ? "mainPlayer:t='yes';" : "") + "player_nick:t='" + nick + "';")
      rowIdx++
    }

    guiScene.setUpdatesEnabled(false, false)
    guiScene.replaceContentFromText(tblObj, markUp, markUp.len(), this)

    guiScene.setUpdatesEnabled(true, true)
    onSelect()
    updateMembersStatus()
    restoreFocus()
  }

  function getFieldNameByColumn(columnId)
  {
    local fieldName = columnId
    if (columnId.len() >= ::ranked_column_prefix.len() &&
        columnId.slice(0, ::ranked_column_prefix.len()) == ::ranked_column_prefix)
    {
      fieldName = ::ranked_column_prefix + curEra + ::domination_modes[curMode].clanDataEnding
    }
    else
    {
      local category = ::u.search(::clan_member_list, (@(columnId) function(category) { return category.id == columnId })(columnId))
      fieldName = ::getTblValue("field", category, columnId)
    }
    return fieldName
  }

  function isSortByColumn(columnId)
  {
    return getFieldNameByColumn(columnId) == statsSortBy
  }

  function getClanMembersCell(member, column)
  {
    local id = getFieldId(column)
    local res = {
      text = ""
      tdAlign = ::getTblValue("align", column, "center")
    }

    if ("getCellTooltipText" in column)
      res.tooltip <- column.getCellTooltipText(member)

    if (::getTblValue("iconStyle", column, false))
    {
      res.id       <- "icon_" + member.nick
      res.needText <- false
      res.imageType <- "contactStatusImg"
      res.image    <- ""
      if (!("tooltip" in res))
        res.tooltip <- ""
      res.width    <- "0.01@scrn_tgt_font"
    }

    res.text = column.type.getShortTextByValue(member[id])
    return res
  }

  function getFieldId(column)
  {
    if (!("field" in column))
      return column.id

    local fieldId = column.field
    if (column.field == ::ranked_column_prefix)
      fieldId += curEra
    if (column.byDifficulty)
      fieldId += ::domination_modes[curMode].clanDataEnding
    return fieldId
  }

  function sortMembers(members)
  {
    if (typeof members != "array")
      return

    local columnData = getColumnDataById(statsSortBy)
    local sortId = ::getTblValue("sortId", columnData, statsSortBy)
    if ("sortPrepare" in columnData)
      foreach(m in members)
        columnData.sortPrepare(m)

    members.sort((@(sortId, statsSortReverse) function(left, right) {
      local res = 0
      if (sortId != "" && sortId != "nick")
      {
        if (left[sortId] < right[sortId])
          res = 1
        else if (left[sortId] > right[sortId])
          res = -1
      }

      if (!res)
      {
        local nickLeft  = left.nick.tolower()
        local nickRight = right.nick.tolower()
        if (nickLeft < nickRight)
          res = 1
        else if (nickLeft > nickRight)
          res = -1
      }
      return statsSortReverse ? -res : res
    })(sortId, statsSortReverse))
  }

  function onEventClanRoomMembersChanged(params = {})
  {
    if (!isMyClan)
      return

    local presence = ::getTblValue("presence", params, ::g_contact_presence.UNKNOWN)
    local nick = ::getTblValue("nick", params, "")

    if (nick == "")
    {
      updateMembersStatus()
      return
    }

    if (!("members" in my_clan_info))
      return

    local member = ::u.search(
      my_clan_info.members,
      (@(nick) function (member) { return member.nick == nick })(nick)
    )

    if (member)
    {
      member.onlineStatus = presence
      drawIcon(nick, presence)
    }
  }

  function onEventClanRquirementsChanged(params)
  {
    fillClanRequirements()
  }

  function updateMembersStatus()
  {
    if (!isMyClan)
      return
    if (!::gchat_is_connected())
      return
    if ("members" in my_clan_info)
      foreach (it in my_clan_info.members)
      {
        it.onlineStatus = ::getMyClanMemberPresence(it.nick)
        drawIcon(it.nick, it.onlineStatus)
      }
  }

  function drawIcon(nick, presence)
  {
    local gObj = scene.findObject("clan-membersList")
    local imgObj = gObj.findObject("img_icon_" + nick)
    if (!::checkObj(imgObj))
      return

    imgObj["background-image"] = presence.getIcon()
    imgObj["background-color"] = presence.getIconColor()
    imgObj["tooltip"] = ::loc(presence.presenceTooltip)
  }

  function getColumnDataById(id)
  {
    return ::u.search(::clan_member_list, (@(id) function(c) { return c.id == id })(id))
  }

  function onStatsCategory(obj)
  {
    if (!obj)
      return
    local value = obj.id
    local sortBy = getFieldNameByColumn(value)

    if (statsSortBy == sortBy)
      statsSortReverse = !statsSortReverse
    else
    {
      statsSortBy = sortBy
      local columnData = getColumnDataById(value)
      statsSortReverse = ::getTblValue("inverse", columnData, false)
    }
    guiScene.performDelayed(this, function() { fillClanMemberList(clanData.members) })
  }

  function onSelect()
  {
    curPlayer = null
    local tblObj = scene.findObject("clan-membersList")
    if (!::checkObj(tblObj) || !clanData)
      return

    local index = tblObj.getValue()
    if (index <= 0 || index >= tblObj.childrenCount())
      return //0 - header selected

    local row = tblObj.getChild(index)
    if (::checkObj(row))
      curPlayer = row.player_nick
  }

  function onDismissMember()
  {
    if ((!isMyClan || !isInArray("MEMBER_DISMISS", myRights)) && !clan_get_admin_editor_mode())
      return;
    if (!curPlayer)
      return;
    local uid = getClanMemberUid(curPlayer);

    ::gui_modal_comment(this, ::loc("clan/writeCommentary"), ::loc("clan/btnDismissMember"), (@(uid) function(comment) {
      taskId = ::clan_request_dismiss_member(uid, comment);

      if (taskId >= 0)
      {
        ::set_char_cb(this, slotOpCb)
        showTaskProgressBox()
        if (!::clan_get_admin_editor_mode())
          ::sync_handler_simulate_signal("clan_info_reload")
        afterSlotOp = function()
          {
            if(clan_get_admin_editor_mode())
              reinitClanWindow()

            if (isMyClan)
              ::sync_handler_simulate_signal("clan_info_reload")

            msgBox("member_dismissed", ::loc("clan/memberDismissed"), [["ok"]], "ok")
          }
      }
    })(uid))
  }

  function onChangeMembershipRequirementsWnd()
  {
    if (::has_feature("Clans") && ::has_feature("ClansMembershipEditor")){
      gui_start_modal_wnd(::gui_handlers.clanChangeMembershipReqWnd,
        {
          clanData = clanData,
          owner = this,
        })
    }
    else
      notAvailableYetMsgBox();
  }

  function onChangeRole()
  {
    if ((!isMyClan || !isInArray("MEMBER_ROLE_CHANGE", myRights)) && !clan_get_admin_editor_mode())
      return;

    if (!curPlayer)
      return;

    if (!clan_get_admin_editor_mode() && curPlayer == ::my_user_name
        && ::isInArray("LEADER", myRights) && getLeadersCount()<=1)
      return msgBox("clan_cant_change_role", ::loc("clan/leader/cant_change_my_role"), [["ok"]], "ok")

    local changeRolePlayer = {
      uid = getClanMemberUid(curPlayer),
      name = curPlayer,
      rank = getClanMemberRank(curPlayer)
    };

    ::gui_start_modal_wnd(::gui_handlers.clanChangeRoleModal,
      {
        changeRolePlayer = changeRolePlayer,
        owner = this,
        clanType = clanData.type
      });
  }

  function onShowMemberActivity()
  {
    if (curPlayer)
      ::gui_start_modal_wnd(::gui_handlers.clanActivityModal,
      {
        clanData = clanData,
        curPlayerName = curPlayer
      })
  }

  function onOpenClanBlacklist()
  {
    ::gui_start_modal_wnd(::gui_handlers.clanBlacklistModal)
  }

  function onUserCard()
  {
    if (curPlayer)
      ::gui_modal_userCard({ name = curPlayer })
  }

  function onUserRClick()
  {
    openUserRClickMenu()
  }

  function openUserRClickMenu(position = null)
  {
    if (!curPlayer)
      return

    local isMe     = curPlayer == ::my_user_name
    local uid      = getPlayerUid(curPlayer)
    local isFriend = uid !=null && ::isPlayerInFriendsGroup(uid)
    local isBlock  = uid !=null && ::isPlayerInContacts(uid, ::EPL_BLOCKLIST)

    local inSquad = ::g_squad_manager.isInSquad()
    local meLeader = ::g_squad_manager.isSquadLeader()
    local inMySquad = ::g_squad_manager.isInMySquad(curPlayer, false)

    local menu = [
      {
        text = ::loc("contacts/message")
        show = !isMe
        action = (@(curPlayer) function() { ::openChatPrivate(curPlayer, this) })(curPlayer)
      }
      {
        text = ::loc("mainmenu/btnUserCard")
        action = (@(curPlayer) function() { ::gui_modal_userCard({ name = curPlayer }) })(curPlayer)
      }
      {
        text = ::loc("clan/activity")
        show = ::has_feature("ClanActivity")
        action = (@(curPlayer) function() { onShowMemberActivity() })(curPlayer)
      }
      {
        text = ::loc("squad/invite_player")
        show = !isMe && ::has_feature("Squad") && !isBlock && ((meLeader && !inMySquad) || !inSquad)
        action = (@(curPlayer) function() {
          ::find_contact_by_name_and_do(curPlayer, ::g_squad_manager,
                                        function(contact)
                                        {
                                          if (contact)
                                            inviteToSquad(contact.uid)
                                        })
        })(curPlayer)
      }
      {
        text = ::loc("squad/remove_player")
        show = !isMe && meLeader && inMySquad
        action = (@(curPlayer) function() { ::g_squad_manager.dismissFromSquadByName(curPlayer) })(curPlayer)
      }
      {
        text = ::loc("contacts/friendlist/add")
        show = !isMe && ::has_feature("Friends") && !isFriend && !isBlock
        action = (@(curPlayer) function() { ::editContactMsgBox({name = curPlayer}, ::EPL_FRIENDLIST, true, this) })(curPlayer)
      }
      {
        text = ::loc("contacts/friendlist/remove")
        show = isFriend
        action = (@(curPlayer) function() { ::editContactMsgBox({name = curPlayer}, ::EPL_FRIENDLIST, false, this) })(curPlayer)
      }
      {
        text = ::loc("contacts/blacklist/add")
        show = !isMe && !isFriend && !isBlock
        action = (@(curPlayer) function() { ::editContactMsgBox({name = curPlayer}, ::EPL_BLOCKLIST, true, this) })(curPlayer)
      }
      {
        text = ::loc("contacts/blacklist/remove")
        show = isBlock
        action = (@(curPlayer) function() { ::editContactMsgBox({name = curPlayer}, ::EPL_BLOCKLIST, false, this) })(curPlayer)
      }
      {
        text = ::loc("clan/btnChangeRole")
        show = (isMyClan
                && isInArray("MEMBER_ROLE_CHANGE", myRights)
                && hasRankToChangeRoles()
                && getClanMemberRank(curPlayer) < clan_get_role_rank(clan_get_my_role())
               )
               || clan_get_admin_editor_mode()
        action = (@(curPlayer) function() { onChangeRole() })(curPlayer)
      }
      {
        text = ::loc("clan/btnDismissMember")
        show = !isMe && isMyClan && isInArray("MEMBER_DISMISS", myRights) && (getClanMemberRank(curPlayer) < clan_get_role_rank(clan_get_my_role()))
               || clan_get_admin_editor_mode()
        action = (@(curPlayer) function() { onDismissMember() })(curPlayer)
      }
    ]

    ::gui_right_click_menu(menu, this, position)
  }

  function getClanMemberUid(name)
  {
    local uid = ""
    foreach(member in clanData.members)
      if (member.nick == name)
      {
        uid = member.uid
        break
      }
    return uid
  }

  function getLeadersCount()
  {
    local count = 0
    foreach(member in clanData.members)
    {
      local rights = ::clan_get_role_rights(member.role)
      if (::isInArray("LEADER", rights) ||
          ::isInArray("DEPUTY", rights))
        count++
    }
    return count
  }

  function getClanMemberRank(name)
  {
    local rank = 0
    foreach(member in clanData.members)
      if (member.nick == name)
      {
        rank = ::clan_get_role_rank(member.role)
        break
      }
    return rank
  }

  function hasRankToChangeRoles()
  {
    local myRank = clan_get_role_rank(clan_get_my_role());
    local rolesNumber = 0;

    for (local role = 0; role<::ECMR_MAX_TOTAL; role++)
    {
       local rank = clan_get_role_rank(role);
       if (rank != 0 && rank < myRank)
         rolesNumber++;
    }

    return (rolesNumber > 1);
  }

  function onMembershipReq(obj = null)
  {
    if (curClan)
      ::clan_membership_request(curClan, this)
  }

  function onClanLog(obj = null)
  {
    if (clanData)
      ::show_clan_log(clanData.id)
  }

  function onClanSeasonRewardLog(obj = null)
  {
    if (clanData)
      ::g_clans.showClanRewardLog(clanData)
  }

  function onEventClanMembershipRequested(p)
  {
    fillClanManagment()
  }

  function complainToClan(clanId)
  {
    if (!::tribunal.canComplaint())
      return
    taskId = ::clan_request_info(clanId, "", "")
    if (taskId >= 0)
    {
      ::set_char_cb(this, slotOpCb)
      showTaskProgressBox()
      afterSlotOp = function(){
        local clanData = ::get_clan_info_table()
        openClanComplainWnd(clanData)
      }
    }
  }

  function openClanComplainWnd(clanData)
  {
    local leaderRoleId = ::ECMR_LEADER
    local leader = null
    foreach(member in clanData.members)
      if(member.role == leaderRoleId)
      {
        leader = member
        break
      }
    if(leader == null)
      leader = clanData.members[0]
    ::gui_modal_complain({name = leader.nick, userId = leader.uid, clanData = clanData})
  }

  function onEditClanInfo()
  {
    gui_modal_edit_clan(clanData, this)
  }

  function onUpgradeClan()
  {
    gui_modal_upgrade_clan(clanData, this)
  }

  function onClanComplain()
  {
    openClanComplainWnd(clanData)
  }

  function onClanAction(obj)
  {
    if (!::checkObj(obj))
      return

    local value = obj.getValue()
    local buttonObj = obj.getChild(value)
    if ("on_click" in buttonObj)
      return this[buttonObj.on_click]()
    else if ("_on_click" in buttonObj)
      return this[buttonObj._on_click]()
  }

  function goBack()
  {
    if(clan_get_admin_editor_mode())
      clan_set_admin_editor_mode(false)
    base.goBack()
  }

  function getSelectedRowPos()
  {
    local objTbl = scene.findObject("clan-membersList")
    local rowNum = objTbl.getValue()
    if(rowNum >= objTbl.childrenCount())
      return null
    local rowObj = objTbl.getChild(rowNum)
    local topLeftCorner = rowObj.getPosRC()
    return [topLeftCorner[0], topLeftCorner[1] + rowObj.getSize()[1]]
  }

  function onUserOption()
  {
    openUserRClickMenu(getSelectedRowPos())
  }

  function onMembersListFocus(obj)
  {
    guiScene.performDelayed(this, function() {
      if (::checkObj(scene))
        updateUserOptionButton()
    })
  }

  function onEventClanMembersUpgraded(p)
  {
    if (clan_get_admin_editor_mode() && p.clanId == clanIdStrReq)
      reinitClanWindow()
  }

  function getMainFocusObj()
  {
    return scene.findObject("btn_lock_clan_req")
  }

  function getMainFocusObj2()
  {
    return getClanActionObjForSelect()
  }

  function getMainFocusObj3()
  {
    return scene.findObject("modes_list")
  }

  function getMainFocusObj4()
  {
    return scene.findObject("clan-membersList")
  }

  function getClanActionObjForSelect()
  {
    local obj =  scene.findObject("clan_actions")
    if (::checkObj(obj) && is_obj_have_active_childs(obj))
      return obj

    return null
  }

  function getWndHelpConfig()
  {
    local res = {
      textsBlk = "gui/clans/clanPageModalHelp.blk"
      objContainer = scene.findObject("clan_container")
    }

    local links = [
      { obj = ["clan_activity_icon", "clan_activity_value"]
        msgId = "hint_clan_activity"
      }

      { obj = ["clan_elo_icon", "clan_elo_value"]
        msgId = "hint_clan_elo"
      }

      { obj = "img_td_1"
        msgId = "hint_air_kills"
      }

      { obj = "img_td_2"
        msgId = "hint_ground_kills"
      }

      { obj = "img_td_3"
        msgId = "hint_death"
      }

      { obj = "img_td_4"
        msgId = "hint_time_pvp_played"
      }

      { obj = "txt_activity"
        msgId = "hint_membership_activity"
      }
    ]

    res.links <- links
    return res
  }
}
