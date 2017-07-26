class ::gui_handlers.VehiclesWindow extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL

  // Session lobby info or event object.
  teamDataByTeamName = null
  roomSpecialRules = null

  function initScreen()
  {
    local view = {
      headerText = ::loc("lobby/vehicles")
      showOkButton = true
    }
    local data = ::handyman.renderCached("gui/vehiclesWindow", view)
    guiScene.replaceContentFromText(scene, data, data.len(), this)

    foreach (team in ::events.getSidesList())
    {
      local teamName = ::events.getTeamName(team)
      local teamObj = scene.findObject(teamName)
      if(!::checkObj(teamObj))
        continue
      local teamData = ::getTblValue(teamName, teamDataByTeamName, null)
      if (!::events.isTeamDataPlayable(teamData))
        continue

      local unitTypes = ::events.getUnitTypesByTeamDataAndName(teamData, teamName)
      ::events.fillAirsList(this, teamObj, teamData, unitTypes, roomSpecialRules)
    }
  }
}

function update_vehicle_info_button(scene, teamDataByTeamName)
{
  local obj = scene.findObject("vehicles_info_button_block")
  if (::checkObj(obj))
    obj.show(!::events.isEventAllUnitAllowed(teamDataByTeamName))
}
