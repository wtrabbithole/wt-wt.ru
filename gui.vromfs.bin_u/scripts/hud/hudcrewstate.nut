local enums = ::require("sqStdlibs/helpers/enums.nut")
::g_hud_crew_member <- {
  types = []
}

function g_hud_crew_member::_setCrewMemberState(crewIconObj, newStateData)
{
  if (!("state" in newStateData))
    return

  if (newStateData.state == "ok")
  {
    crewIconObj.state = "ok"
  }
  else if (newStateData.state == "takingPlace" || newStateData.state == "healing")
  {
    local timeBarObj = crewIconObj.findObject("transfere_indicatior")
    ::g_time_bar.setPeriod(timeBarObj, newStateData.totalTakePlaceTime)
    ::g_time_bar.setCurrentTime(timeBarObj, newStateData.totalTakePlaceTime - newStateData.timeToTakePlace)
    crewIconObj.state = "transfere"
    crewIconObj.tooltip = ::loc(tooltip)
  }
  else if (newStateData.state == "dead")
  {
    crewIconObj.state = "dead"
    crewIconObj.tooltip = ::loc(tooltip)
  }
  else
  {
    crewIconObj.state = "none"
  }
}

::g_hud_crew_member.template <- {
  hudEventName = ""
  sceneId = ""
  tooltip = ""

  setCrewMemberState = ::g_hud_crew_member._setCrewMemberState
}

enums.addTypesByGlobalName("g_hud_crew_member", {
  GUNNER = {
    hudEventName = "CrewState:GunnerState"
    sceneId = "crew_gunner"
    tooltip = "hud_tank_crew_gunner_out_of_action"
  }

  DRIVER = {
    hudEventName = "CrewState:DriverState"
    sceneId = "crew_driver"
    tooltip = "hud_tank_crew_driver_out_of_action"
  }

  CREW_COUNT = {
    hudEventName = "CrewState:CrewState"
    sceneId = "crew_count"
    setCrewMemberState = function (iconObj, newStateData) {
      if (newStateData.total <= 0)
      {
        iconObj.show(false)
        return
      }
      else
        iconObj.show(true)

      local text = newStateData.current.tostring()
      if (newStateData.current <= 2 && newStateData.total > 2)
        text = ::colorize("badTextColorDark", text)
      iconObj.findObject("crew_count_text").setValue(text)
    }
  }
})

::g_hud_crew_state <- {
  scene = null
  guiScene = null

  function init(_nest) {
    if (!::has_feature("TankDetailedDamageIndicator"))
      return

    scene = _nest.findObject("crew_state")

    if (!::checkObj(scene))
      return

    guiScene = scene.getScene()
    local blk = ::load_template_text("gui/hud/hudCrewState")
    guiScene.replaceContentFromText(scene, blk, blk.len(), this)

    foreach (crewMemberType in ::g_hud_crew_member.types)
    {
      ::g_hud_event_manager.subscribe(crewMemberType.hudEventName,
        (@(crewMemberType) function (eventData) {
          local crewObj = scene.findObject(crewMemberType.sceneId)
          if (::checkObj(crewObj))
            crewMemberType.setCrewMemberState(crewObj, eventData)
        })(crewMemberType), this)
    }

    ::hud_request_hud_crew_state()
  }

  function reinit()
  {
    ::hud_request_hud_crew_state()
  }

  function isValid()
  {
    return ::checkObj(scene)
  }
}
