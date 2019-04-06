local u = ::require("std/u.nut")
local time = require("scripts/time.nut")
local platformModule = require("scripts/clientState/platform.nut")

function gui_start_clan_activity_wnd(playerName = null, clanData = null)
{
  if (!playerName || !clanData)
    return

  ::gui_start_modal_wnd(::gui_handlers.clanActivityModal,
  {
    clanData = clanData
    playerName = playerName
  })

}

class ::gui_handlers.clanActivityModal extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType           = handlerType.MODAL
  sceneBlkName      = "gui/clans/clanActivityModal.blk"
  clanData          = null
  playerName        = null
  hasClanExperience = null

  function initScreen()
  {
    local memberData = u.search.bindenv(this)(clanData.members, @(member) member.nick == playerName)
    local maxActivityPerDay = clanData.rewardPeriodDays > 0
      ? ::round(1.0 * clanData.maxActivityPerPeriod / clanData.rewardPeriodDays)
      : 0
    local isShowPeriodActivity = clanData.expRewardEnabled
    hasClanExperience  = isShowPeriodActivity && ::clan_get_my_clan_id() == clanData.id
    local history = isShowPeriodActivity ? memberData.expActivity : memberData.activityHistory
    local headerTextObj = scene.findObject("clan_activity_header_text")
    headerTextObj.setValue(::format("%s - %s", ::loc("clan/activity"),
      platformModule.getPlayerName(memberData.nick)))

    scene.findObject("clan_activity_today_value").setValue(
      ::format("%d / %d",
        isShowPeriodActivity ? memberData.curPeriodActivity : memberData.curActivity,
        isShowPeriodActivity ? clanData.maxActivityPerPeriod : maxActivityPerDay
      )
    )

    scene.findObject("clan_activity_total_value").setValue(
      ::format("%d / %d",
        isShowPeriodActivity ? memberData.totalPeriodActivity : memberData.totalActivity,
        isShowPeriodActivity ? clanData.maxActivityPerPeriod * history.len() : maxActivityPerDay * history.len()
      )
    )

    fillActivityHistory(history)
  }

  function fillActivityHistory(history)
  {
    local historyArr = []
    foreach (day, data in history)
    {
      historyArr.append({day = day.tointeger(), data = data})
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

    if (hasClanExperience)
      rowHeader.append(
        {
          id       = "clan_activity_exp_col_value",
          text     = ::loc("reward"),
          active   = false
        }
      )

    rowBlock += ::buildTableRowNoPad("row_header", rowHeader, null,
        "inactive:t='yes'; commonTextColor:t='yes'; bigIcons:t='yes'; style:t='height:0.05sh;'; ")

    guiScene.replaceContentFromText(tableHeaderObj, rowBlock, rowBlock.len(), this)

    local tableObj = scene.findObject("clan_member_activity_history_table");

    rowBlock = ""
    /*body*/
    foreach(entry in historyArr)
    {
      local rowParams = [
        { text = time.buildDateStr(time.daysToSeconds(entry.day)) },
        { text = ::format("%d", entry.data?.activity ?? entry.data) }
      ]

      if (hasClanExperience)
        rowParams.append({ text = ::format("%d", entry.data.exp) })

      rowBlock += ::buildTableRowNoPad("row_" + rowIdx, rowParams, null, "")
      rowIdx++
    }
    guiScene.replaceContentFromText(tableObj, rowBlock, rowBlock.len(), this)
  }
}
