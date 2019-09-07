local clanBlackList = [
  { id = "nick", type = ::g_lb_data_type.TEXT },
  { id = "initiator_nick", type = ::g_lb_data_type.TEXT },
  { id = "date", type = ::g_lb_data_type.DATE }]

class ::gui_handlers.clanBlacklistModal extends ::gui_handlers.BaseGuiHandlerWT
{
  function initScreen()
  {
    if(!::my_clan_info)
      return

    myRights = ::clan_get_role_rights(clan_get_admin_editor_mode() ? ::ECMR_CLANADMIN : clan_get_my_role())
    memListModified = false

    blacklistData = ::my_clan_info.blacklist
    updateBlacklistTable()
    local tObj = scene.findObject("clan_title_table")
    if(tObj)
      tObj.setValue(::loc("clan/blacklist"))
  }

  function updateBlacklistTable()
  {
    if (!::checkObj(scene) || !blacklistData)
      return;

    if (curPage > 0 && blacklistData.len() <= curPage * rowsPerPage)
      curPage--

    local tblObj = scene.findObject("candidatesList")
    local data = ""

    local headerRow = []
    foreach(item in clan_blacklist)
    {
      local itemName = (typeof(item) != "table")? item : item.id
      local name = "#clan/"+(itemName == "date"? "bannedDate" : itemName)
      headerRow.append({
        id = itemName,
        text = name,
        tdAlign="center",
      })
    }
    data = buildTableRow("row_header", headerRow, null, "inactive:t='yes'; commonTextColor:t='yes'; bigIcons:t='yes'; style:t='height:0.05sh;'; ")

    local startIdx = curPage * rowsPerPage
    local lastIdx = min((curPage + 1) * rowsPerPage, blacklistData.len())
    for(local i=startIdx; i < lastIdx; i++)
    {
      local rowName = "row_" + i
      local rowData = []

      foreach(item in clan_blacklist)
      {
         local itemName = (typeof(item) != "table")? item : item.id
         rowData.append({
          id = itemName,
          text = "",
         })
      }
      data += buildTableRow(rowName, rowData, (i-curPage*rowsPerPage)%2==0, "")
    }
    guiScene.setUpdatesEnabled(false, false)
    guiScene.replaceContentFromText(tblObj, data, data.len(), this)
    for(local i=startIdx; i < lastIdx; i++)
      fillRow(tblObj, i)

    tblObj.cur_row = "1" //after header
    guiScene.setUpdatesEnabled(true, true);
    selectOptionsNavigatorObj(tblObj)
    onSelect()

    generatePaginator(scene.findObject("paginator_place"), this, curPage, ((blacklistData.len()-1) / rowsPerPage).tointeger())
  }

  function fillRow(tblObj, i)
  {
    local block = blacklistData[i]
    local rowObj = tblObj.findObject("row_"+i)
    if (rowObj)
    {
      local comments = ("comments" in block) ? block.comments : ""
      rowObj.tooltip = comments.len()
        ? ::loc("clan/blacklistRowTooltip", {comments = comments}) : ""

      foreach(item in clanBlackList)
      {
        local vObj = rowObj.findObject("txt_" + item.id)
        local itemValue = (item.id in block)? block[item.id] : 0
        if(vObj)
          vObj.setValue(item.type.getShortTextByValue(itemValue))
      }
    }
  }

  function goToPage(obj)
  {
    curPage = obj.to_page.tointeger()
    updateBlacklistTable()
  }

  function onSelect()
  {
    curCandidate = null;
    if (blacklistData && blacklistData.len()>0)
    {
      local objTbl = scene.findObject("candidatesList");
      local index = objTbl.cur_row.tointeger() + curPage*rowsPerPage - 1; //header
      if (index in blacklistData)
        curCandidate = blacklistData[index];
    }

    showSceneBtn("btn_removeBlacklist", curCandidate != null && ::isInArray("MEMBER_BLACKLIST", myRights))
    showSceneBtn("btn_user_options", curCandidate != null && ::show_console_buttons)
  }

  function onUserCard()
  {
    if (curCandidate)
      ::gui_modal_userCard({ uid = curCandidate.uid })
  }

  function onRequestApprove(){}
  function onRequestReject(){}

  function onDeleteFromBlacklist()
  {
    if (curCandidate)
      ::g_clans.blacklistAction(curCandidate.uid, false)
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
        text = ::loc("msgbox/btn_delete")
        show = ::isInArray("MEMBER_BLACKLIST", myRights)
        action = onDeleteFromBlacklist
      }
      {
        text = ::loc("mainmenu/btnUserCard")
        action = @() ::gui_modal_userCard({ uid = curCandidate.uid })
      }
    ]
    ::gui_right_click_menu(menu, this, position)
  }

  function hideCandidateByName(name)
  {
    if (!name)
      return

    memListModified = true
    foreach(idx, candidate in blacklistData)
      if (candidate.nick == name)
      {
        blacklistData.remove(idx)
        break
      }

    if (blacklistData.len() > 0)
      updateBlacklistTable()
    else
      goBack()
  }

  function onEventClanCandidatesListChanged(p)
  {
    local uid = p?.userId
    local candidate = ::u.search(blacklistData, @(candidate) candidate.uid == uid )
    hideCandidateByName(candidate?.nick)
  }

  function afterModalDestroy()
  {
    //if(memListModified)
    //  ::getMyClanData(true)
  }

  myRights = []
  curCandidate = null
  memListModified = false
  clan_blacklist = ["nick", "initiator_nick", { id="date", type = ::g_lb_data_type.DATE }]
  blacklistData = null

  curPage = 0
  rowsPerPage = 10

  owner = null
  wndType = handlerType.MODAL
  sceneBlkName = "gui/clans/clanRequests.blk"
}
