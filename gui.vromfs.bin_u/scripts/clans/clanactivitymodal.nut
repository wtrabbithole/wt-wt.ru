local u = ::require("std/u.nut")
local time = require("scripts/time.nut")
local platformModule = require("scripts/clientState/platform.nut")

function gui_start_clan_activity_wnd(playerName = null, clanData = null)
{
  if (!playerName || !clanData)
    return

  local memberData = u.search(clanData.members, @(member) member.nick == playerName)
  if (memberData)
    ::gui_start_modal_wnd(::gui_handlers.clanActivityModal, {memberData = memberData })
}

class ::gui_handlers.clanActivityModal extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType      = handlerType.MODAL
  sceneBlkName = "gui/clans/clanActivityModal.blk"

  memberData = null

  function initScreen()
  {
    local headerTextObj = scene.findObject("clan_activity_header_text")
    headerTextObj.setValue(::format("%s - %s", ::loc("clan/activity"), platformModule.getPlayerName(memberData.nick)))

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
      local t = get_time_from_t(time.daysToSeconds(entry.day))
      local rowParams = [
        {
          text = time.buildDateStr(t)
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
