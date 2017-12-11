class ::gui_handlers.CampaignResults extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName = "gui/debriefingCamp.blk"

  loses = ["fighters", "bombers", "tanks", "infantry", "ships", "artillery"]

  function initScreen()
  {
    guiScene["campaign-status"].setValue(
        (::dynamic_result == ::MISSION_STATUS_SUCCESS) ? ::loc("DYNAMIC_CAMPAIGN_SUCCESS") : ::loc("DYNAMIC_CAMPAIGN_FAIL")
      )
    guiScene["campaign-result"].setValue(
        (::dynamic_result == ::MISSION_STATUS_SUCCESS) ? ::loc("missions/dynamic_success") : ::loc("missions/dynamic_fail")
      );

    local wpdata = ::get_session_warpoints()

    guiScene["info-dc-wins"].setValue(wpdata.dcWins.tostring())
    guiScene["info-dc-fails"].setValue(wpdata.dcFails.tostring())

    if (wpdata.nDCWp>0)
    {
      guiScene["info-dc-text"].setValue(::loc("debriefing/dc"))
      guiScene["info-dc-wp"].setValue(::Cost(wpdata.nDCWp).toStringWithParams(
        {isWpAlwaysShown = true, isColored = false}))
    }

    local info = DataBlock()
    ::dynamic_get_visual(info)
    local stats = ["bombers", "fighters", "infantry", "tanks", "artillery","ships"]
    local sides = ["ally","enemy"]
    for (local i = 0; i < stats.len(); i++)
    {
      for (local j = 0; j < sides.len(); j++)
      {
        local value = info.getInt("loss_"+sides[j]+"_"+stats[i], 0)
        if (value > 10000)
          value = "" + ((value/1000).tointeger()).tostring() + "K"
        guiScene["info-"+stats[i]+j.tostring()].text = value
      }
    }

  }
  function onSelect()
  {
    dagor.debug("::gui_handlers.CampaignResults onSelect")
    save()
  }
  function afterSave()
  {
    dagor.debug("::gui_handlers.CampaignResults afterSave")
    goForward(::gui_start_mainmenu)
  }
  function onBack()
  {
    dagor.debug("::gui_handlers.CampaignResults goBack")
    goBack()
  }
}