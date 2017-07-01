function showClanRequests(candidatesData, clanId, owner)
{
  ::gui_start_modal_wnd(::gui_handlers.clanRequestsModal,
    {
      candidatesData = candidatesData,
      owner = owner
      clanId = clanId
    });
    ::g_clans.markClanCandidatesAsViewed()
}

class ::gui_handlers.clanRequestsModal extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/clans/clanRequests.blk";
  owner = null;
  rowTexts = [];
  candidatesData = null;
  candidatesList = [];
  myRights = [];
  curCandidate = null;
  memListModified = false
  curPage = 0
  rowsPerPage = 10
  clanId = "-1"

  function initScreen()
  {
    myRights = clan_get_role_rights(clan_get_admin_editor_mode() ? ::ECMR_CLANADMIN : clan_get_my_role())
    memListModified = false
    local isMyClan = !::my_clan_info ? false : (::my_clan_info.id == clanId ? true : false)
    clanId = isMyClan ? "-1" : clanId
    fillRequestList()
    initFocusArray()
  }

  function fillRequestList()
  {
    rowTexts = [];
    candidatesList = [];

    foreach(candidate in candidatesData)
    {
      local rowTemp = {};
      foreach(item in ::clan_candidate_list)
      {
        local value = item.id in candidate ? candidate[item.id] : 0
        rowTemp[item.id] <- {value = value, text = item.type.getShortTextByValue(value)}
      }
      candidatesList.append({nick = candidate.nick, uid = candidate.uid });
      rowTexts.append(rowTemp);
    }
    //dlog("GP: candidates texts");
    //debugTableData(rowTexts);

    updateRequestList()
  }

  function updateRequestList()
  {
    if (!::checkObj(scene))
      return;

    if (curPage > 0 && rowTexts.len() <= curPage * rowsPerPage)
      curPage--

    local tblObj = scene.findObject("candidatesList");
    local data = "";

    local headerRow = [];
    foreach(item in ::clan_candidate_list)
    {
      local name = "#clan/" + (item.id == "date" ? "requestDate" : item.id);
      headerRow.append({
        id = item.id,
        text = name,
        tdAlign="center",
      });
    }
    data = buildTableRow("row_header", headerRow, null, "inactive:t='yes'; commonTextColor:t='yes'; bigIcons:t='yes'; style:t='height:0.05sh;'; ");

    local startIdx = curPage * rowsPerPage
    local lastIdx = min((curPage + 1) * rowsPerPage, rowTexts.len())
    for(local i=startIdx; i < lastIdx; i++)
    {
      local candidate = rowTexts[i]
      local rowName = "row_"+i;
      local rowData = [];

      foreach(item in ::clan_candidate_list)
      {
        rowData.append({
          id = item.id,
          text = "",
        });
      }
      data += buildTableRow(rowName, rowData, (i-startIdx)%2==0, "");
    }

    guiScene.setUpdatesEnabled(false, false);
    guiScene.replaceContentFromText(tblObj, data, data.len(), this);

    for(local i=startIdx; i < lastIdx; i++)
    {
      local row = rowTexts[i]
      foreach(item, itemValue in row)
        tblObj.findObject("row_"+i).findObject("txt_"+item).setValue(itemValue.text);
    }

    tblObj.cur_row = "1" //after header
    guiScene.setUpdatesEnabled(true, true);
    selectOptionsNavigatorObj(tblObj)
    onSelect()

    generatePaginator(scene.findObject("paginator_place"), this, curPage, ((rowTexts.len()-1) / rowsPerPage).tointeger())
  }

  function goToPage(obj)
  {
    curPage = obj.to_page.tointeger()
    updateRequestList()
  }

  function onSelect()
  {
    curCandidate = null;
    if (candidatesList && candidatesList.len()>0)
    {
      local objTbl = scene.findObject("candidatesList");
      local index = objTbl.cur_row.tointeger() + curPage*rowsPerPage - 1; //header
      if (index in candidatesList)
        curCandidate = candidatesList[index];
    }
    showSceneBtn("btn_approve", !::show_console_buttons && curCandidate != null && (isInArray("MEMBER_ADDING", myRights) || clan_get_admin_editor_mode()))
    showSceneBtn("btn_reject", !::show_console_buttons && curCandidate != null && isInArray("MEMBER_REJECT", myRights))
    showSceneBtn("btn_user_options", curCandidate != null && ::show_console_buttons)
  }

  function onUserCard()
  {
    if (curCandidate)
      ::gui_modal_userCard({ uid = curCandidate.uid })
  }

  function clanBlacklistAction(uid, actionAdd)
  {
    ::gui_modal_comment(this, ::loc("clan/writeCommentary"), ::loc("msgbox/btn_ok"), (@(uid, actionAdd) function(comment) {
      taskId = ::clan_request_edit_black_list(uid, actionAdd, comment)
      ::sync_handler_simulate_signal("clan_info_reload")

      if (taskId >= 0)
      {
        ::set_char_cb(this, slotOpCb)
        showTaskProgressBox()
        local msgText = actionAdd? ::loc("clan/blacklistAddSuccess") : ::loc("clan/blacklistRemoveSuccess")
        afterSlotOp = (@(msgText) function() {
            hideCurCandidate()

            msgBox("blacklist_action",
              msgText,
              [["ok", function() { goBack() } ]], "ok")
          })(msgText)
      }
    })(uid, actionAdd))
  }

  function onUserRClick()
  {
    openUserPopupMenu()
  }

  function onUserAction()
  {
    local table = scene.findObject("candidatesList")
    if (!::checkObj(table))
      return

    local index = table.getValue()
    if (index < 0 || index > table.childrenCount())
      return

    local position = table.getChild(index).getPosRC()
    openUserPopupMenu(position)
  }

  function openUserPopupMenu(position = null)
  {
    if (!curCandidate)
      return

    local menu = [
      {
        text = ::loc("clan/requestApprove")
        show = isInArray("MEMBER_ADDING", myRights) || clan_get_admin_editor_mode()
        action = function() { onRequestApprove() }
      }
      {
        text = ::loc("clan/requestReject")
        show = isInArray("MEMBER_REJECT", myRights) || clan_get_admin_editor_mode()
        action = function() { onRequestReject() }
      }
      {
        text = ::loc("clan/blacklistAdd")
        show = isInArray("MEMBER_BLACKLIST", myRights)
        action = (@(curCandidate) function() { clanBlacklistAction(curCandidate.uid, true) })(curCandidate)
      }
      {
        text = ::loc("contacts/message")
        action = (@(curCandidate) function() { ::openChatPrivate(curCandidate.nick, this) })(curCandidate)
      }
      {
        text = ::loc("mainmenu/btnUserCard")
        action = (@(curCandidate) function() { ::gui_modal_userCard({ uid = curCandidate.uid }) })(curCandidate)
      }
    ]
    ::gui_right_click_menu(menu, this, position);
  }

  function onRequestApprove()
  {
    if (!curCandidate)
      return

    taskId = clan_request_accept_membership_request(clanId, curCandidate.uid, "REGULAR", false);
    if (taskId >= 0)
    {
      ::set_char_cb(this, slotOpCb)
      showTaskProgressBox()
      ::sync_handler_simulate_signal("clan_info_reload")
      afterSlotOp = function()
        {
          msgBox("request_approved", ::loc("clan/requestApproved"), [["ok", function() { hideCurCandidate() } ]], "ok")
        }
    }
  }

  function onRequestReject()
  {
    if (!curCandidate)
      return;
    local uid = curCandidate.uid

    ::gui_modal_comment(this, ::loc("clan/writeCommentary"), ::loc("clan/requestReject"), (@(uid) function(comment) {
      taskId = clan_request_reject_membership_request(uid, comment);

      if (taskId >= 0)
      {
        ::set_char_cb(this, slotOpCb)
        showTaskProgressBox()
        ::sync_handler_simulate_signal("clan_info_reload")
        afterSlotOp = function()
          {
            msgBox("request_rejected", ::loc("clan/requestRejected"), [["ok", function() { hideCurCandidate() } ]], "ok")
          }
      }
    })(uid))
  }

  function hideCurCandidate()
  {
    if (!curCandidate)
      return;

    memListModified = true
    foreach(idx, candidate in rowTexts)
      if (candidate.nick.value == curCandidate.nick)
      {
        rowTexts.remove(idx);
        foreach(idx, player in candidatesList)
          if (player.nick == curCandidate.nick)
            candidatesList.remove(idx);
      }

    if (rowTexts.len() > 0)
      updateRequestList()
    else
      goBack();
  }

  function afterModalDestroy()
  {
    if(memListModified)
    {
      if(clan_get_admin_editor_mode() && (owner && "reinitClanWindow" in owner))
        owner.reinitClanWindow()
      //else
      //  ::getMyClanData(true)
    }
  }

  function onDeleteFromBlacklist(){}

  function getMainFocusObj()
  {
    return scene.findObject("candidatesList")
  }
}
