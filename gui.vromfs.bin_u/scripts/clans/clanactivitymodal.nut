class ::gui_handlers.clanActivityModal extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType      = handlerType.MODAL
  sceneBlkName = "gui/clans/clanActivityModal.blk"

  clanData         = null
  curPlayerName    = null

  function initScreen()
  {
    if (!clanData || !curPlayerName)
    {
      goBack()
      return
    }

    local memberData = null
    foreach (member in clanData.members)
      if (member.nick == curPlayerName)
      {
        memberData = member
        break
      }

    if (!memberData)
    {
      goBack()
      return
    }

    local headerTextObj = scene.findObject("clan_activity_header_text")
    headerTextObj.setValue(::format("%s - %s", ::loc("clan/activity"), curPlayerName))

    local history = memberData.activityHistory

    scene.findObject("clan_activity_total_text").setValue(
        ::loc("clan/activity_total", {count = history.len()}))

    scene.findObject("clan_activity_today_value").setValue(
        ::format("%d", ::getTblValue("curActivity", memberData, 0)))

    scene.findObject("clan_activity_total_value").setValue(
        ::format("%d", ::getTblValue("totalActivity", memberData, 0)))

    fillActivityHistory(history)
  }

  function fillActivityHistory(history)
  {
    local historyArr = []
    foreach (day, value in history)
    {
      historyArr.append({day = day.tointeger(), value = value})
    }
    historyArr.sort(function(left, right)
    {
      return right.day - left.day
    })

    local tableHeaderObj = scene.findObject("clan_member_activity_history_table_header");
    local rowIdx = 1
    local rowBlock = ""
    local rowHeader = [
      {
        id       = "clan_activity_history_col_day",
        text     = ::loc("clan/activity/day"),
        active   = false
      },
      {
        id       = "clan_activity_history_col_value",
        text     = ::loc("clan/activity"),
        active   = false
      }
     ];

    rowBlock += ::buildTableRowNoPad("row_header", rowHeader, null,
        "inactive:t='yes'; commonTextColor:t='yes'; bigIcons:t='yes'; style:t='height:0.05sh;'; ")

    guiScene.replaceContentFromText(tableHeaderObj, rowBlock, rowBlock.len(), this)

    local tableObj = scene.findObject("clan_member_activity_history_table");

    rowBlock = ""
    /*body*/
    foreach(entry in historyArr)
    {
      local t = get_time_from_t(entry.day * TIME_DAY_IN_SECONDS)
      local rowParams = [
        {
          text = ::build_date_str(t)
        },
        {
          text = ::format("%d", entry.value)
        }
      ];

      rowBlock += ::buildTableRowNoPad("row_" + rowIdx, rowParams, null, "")
      rowIdx++
    }
    guiScene.replaceContentFromText(tableObj, rowBlock, rowBlock.len(), this)
  }

}
