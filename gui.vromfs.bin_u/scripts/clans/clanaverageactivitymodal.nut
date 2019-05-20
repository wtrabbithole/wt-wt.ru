local PROGRESS_PARAMS = {
  type = "old"
  rotation = 0
  markerPos = 100
  progressDisplay = "show"
  markerDisplay = "show"
}

class ::gui_handlers.clanAverageActivityModal extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  clanData = null

  static function open(clanData)
  {
    ::gui_start_modal_wnd(
      ::gui_handlers.clanAverageActivityModal, { clanData = clanData })
  }

  function initScreen()
  {
    local view = {
      clan_activity_header_text = ::loc("clan/activity")
      clan_activity_description = ::loc("clan/activity/progress/desc_no_progress")
    }
    local maxMemberActivity = max(clanData.maxActivityPerPeriod, 1)
    if (clanData.maxClanActivity > 0)
    {
      local maxActivity = maxMemberActivity * clanData.members.len()
      local limitClanActivity = min(maxActivity, clanData.maxClanActivity)
      local myActivity = ::u.search(clanData.members,
        @(member) member.uid == ::my_user_id_str)?.curPeriodActivity ?? 0
      local clanActivity = getClanActivity()

      if (clanActivity > 0)
      {
        local percentMemberActivity = min(100.0 * myActivity / maxMemberActivity, 100)
        local percentClanActivity = min(100.0 * clanActivity / maxActivity, 100)
        local myExp = min(min(1, 1.0 * percentMemberActivity/percentClanActivity) * clanActivity, clanData.maxClanActivity)
        local limit = min(100.0 * limitClanActivity / maxActivity, 100)
        local isAllVehiclesResearched = u.search(::all_units,
          @(unit) unit.isSquadronVehicle() && unit.isVisibleInShop() && !::isUnitResearched(unit)) == null

        view = {
          clan_activity_header_text = ::format( ::loc("clan/my_activity_in_period"),
            myActivity + " / " + maxMemberActivity.tostring())
          clan_activity_description = isAllVehiclesResearched
            ? ::loc("clan/activity/progress/desc_all_researched")
            : ::loc("clan/activity/progress/desc")
          rows = [
            {
              title = ::loc("clan/squadron_activity")
              progress = [
                PROGRESS_PARAMS.__merge({type = "new", markerDisplay = "hide"})
                PROGRESS_PARAMS.__merge({
                  value = percentClanActivity * 10
                  markerPos = percentClanActivity
                  text = ::round(percentClanActivity) + "%"
                })
              ]
            }
            {
              title = ::loc("clan/activity_reward")
              widthPercent = limit
              progressDisplay = isAllVehiclesResearched ? "hide" : "show"
              progress = [
                PROGRESS_PARAMS.__merge({type = "new", markerDisplay = "hide"})
                PROGRESS_PARAMS.__merge({
                  text = limitClanActivity
                  rotation = 180
                })
                PROGRESS_PARAMS.__merge({
                  value = min(100 * myExp / limitClanActivity, 100) * 10
                  markerPos = min(100 * myExp / limitClanActivity, 100)
                  text = ::round(myExp)
                  markerDisplay = ::round(myExp) < limitClanActivity ? "show" : "hide"
                })
              ]
            }
            {
              title = ::loc("clan/my_activity"),
              progress = [
                PROGRESS_PARAMS.__merge({type = "new", markerDisplay = "hide"})
                PROGRESS_PARAMS.__merge({
                  value = percentMemberActivity * 10
                  markerPos = percentMemberActivity
                  text = ::round(percentMemberActivity) + "%"
                })
              ]
            }
          ]
        }
      }
    }

    local data = ::handyman.renderCached("gui/clans/clanAverageActivityModal", view)
    guiScene.replaceContentFromText(scene, data, data.len(), this)
  }

  function getClanActivity()
  {
    local res = 0
    foreach (member in clanData.members)
      res += member.curPeriodActivity

    return res
  }
}
