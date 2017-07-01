::g_hud_display_timers <- {
  timersList = [
    {
      id = "repair_status"
      color = "@white"
      icon = "#ui/gameuiskin#repair_status_indicator"
      needTimeText = true
    },
    {
      id = "rearm_status"
      color = "@white"
      icon = "#ui/gameuiskin#slot_weapons"
    },
    {
      id = "rearm_rocket_status"
      color = "@red"
      icon = "#ui/gameuiskin#slot_weapons"
    },
    {
      id = "driver_status"
      color = "@crewTransferColor"
      icon = function () {
        if (::g_hud_display_timers.unitType == ::ES_UNIT_TYPE_SHIP)
          return "#ui/gameuiskin#ship_crew_driver"
        return "#ui/gameuiskin#crew_driver_indicator"
      }
    },
    {
      id = "gunner_status"
      color = "@crewTransferColor"
      icon = function () {
        if (::g_hud_display_timers.unitType == ::ES_UNIT_TYPE_SHIP)
          return "#ui/gameuiskin#ship_crew_gunner"
        return "#ui/gameuiskin#crew_gunner_indicator"
      }
    },
    {
      id = "healing_status"
      color = "@white"
      icon = "#ui/gameuiskin#medic_status_indicator"
    }
  ]

  scene = null
  guiScene = null

  repairUpdater = null
  unitType = ::ES_UNIT_TYPE_INVALID

  function init(_nest, _unitType)
  {
    scene = _nest.findObject("display_timers")
    if (!scene && !::checkObj(scene))
      return

    unitType = _unitType
    guiScene = scene.getScene()
    local blk = ::handyman.renderCached("gui/hud/HudDisplayTimers", getViewData())
    guiScene.replaceContentFromText(scene, blk, blk.len(), this)

    ::g_hud_event_manager.subscribe("TankDebuffs:Rearm", onRearm, this)
    ::g_hud_event_manager.subscribe("TankDebuffs:RearmRocket", onRearm, this)
    ::g_hud_event_manager.subscribe("TankDebuffs:Repair", onRepair, this)
    ::g_hud_event_manager.subscribe("ShipDebuffs:Repair", onRepair, this)

    ::g_hud_event_manager.subscribe("CrewState:CrewState", onCrewState, this)
    ::g_hud_event_manager.subscribe("CrewState:DriverState", onDriverState, this)
    ::g_hud_event_manager.subscribe("CrewState:GunnerState", onGunnerState, this)

    ::g_hud_event_manager.subscribe("LocalPlayerDead", onLocalPlayerDead, this)
    ::g_hud_event_manager.subscribe("MissionResult", onMissionResult, this)

    if (::getTblValue("isDead", ::get_local_mplayer(), false))
      clearAllTimers()
  }


  function reinit()
  {
    if (::getTblValue("isDead", ::get_local_mplayer(), false))
      clearAllTimers()
  }


  function getViewData()
  {
    return {
      timersList = timersList
    }
  }


  function onLocalPlayerDead(eventData)
  {
    clearAllTimers()
  }


  function onMissionResult(eventData)
  {
    clearAllTimers()
  }


  function clearAllTimers()
  {
    if (!::checkObj(scene))
      return

    foreach(timerData in timersList)
    {
      local placeObj = scene.findObject(timerData.id)
      if (!::checkObj(placeObj))
        return

      placeObj.animation = "hide"

      local iconObj = placeObj.findObject("icon")
      iconObj.wink = "no"
    }

    destoyRepairUpdater()
  }


  function onDriverState(newStateData)
  {
    onCrewMemberState("driver", newStateData)
  }


  function onGunnerState(newStateData)
  {
    onCrewMemberState("gunner", newStateData)
  }


  function onCrewMemberState(memberId, newStateData)
  {
    if (!("state" in newStateData))
      return

    local placeObj = scene.findObject(memberId + "_status")
    if (!::checkObj(placeObj))
      return

    local showTimer = newStateData.state == "takingPlace"
    placeObj.animation = showTimer ? "show" : "hide"
    if (!showTimer)
      return

    local timebarObj = placeObj.findObject("timer")
    ::g_time_bar.setPeriod(timebarObj, newStateData.totalTakePlaceTime)
    ::g_time_bar.setCurrentTime(timebarObj, newStateData.totalTakePlaceTime - newStateData.timeToTakePlace)
  }


  function onCrewState(newStateData)
  {
    local placeObj = scene.findObject("healing_status")
    if (!::checkObj(placeObj))
      return

    local showTimer = newStateData.healing
    placeObj.animation = showTimer ? "show" : "hide"
    if (!showTimer)
      return

    local timebarObj = placeObj.findObject("timer")
    ::g_time_bar.setPeriod(timebarObj, newStateData.totalHealingTime + 1)
    ::g_time_bar.setCurrentTime(timebarObj, newStateData.totalHealingTime - newStateData.timeToHeal)
  }


  function onRearm(debuffs_data)
  {
    local placeObj = scene.findObject(debuffs_data.object_name)
    if (!::checkObj(placeObj))
      return

    local showTimer = debuffs_data.state == "rearming"
    placeObj.animation = showTimer ? "show" : "hide"

    if (!showTimer)
      return

    local timebarObj = placeObj.findObject("timer")
    ::g_time_bar.setDirectionForward(timebarObj)
    ::g_time_bar.setPeriod(timebarObj, debuffs_data.timeToLoadOne)
    ::g_time_bar.setCurrentTime(timebarObj, debuffs_data.currentLoadTime)
  }


  function onRepair(debuffs_data)
  {
    local placeObj = scene.findObject("repair_status")
    if (!::checkObj(placeObj))
      return

    local showTimer = debuffs_data.state != "notInRepair"
    placeObj.animation = showTimer ? "show" : "hide"

    destoyRepairUpdater()
    local iconObj = placeObj.findObject("icon")

    if (!showTimer)
    {
      iconObj.wink = "no"
      return
    }

    local timebarObj = placeObj.findObject("timer")
    local timeTextObj = placeObj.findObject("time_text")
    timeTextObj.setValue("")

    placeObj.show(true)

    if (debuffs_data.state == "prepareRepair")
    {
      iconObj.wink = "fast"
      ::g_time_bar.setDirectionBackward(timebarObj)
    }
    else if (debuffs_data.state == "repairing")
    {
      iconObj.wink = "no"
      ::g_time_bar.setDirectionForward(timebarObj)
      local createTime = ::dagor.getCurTime()
      repairUpdater = ::secondsUpdater(timeTextObj, (@(debuffs_data, createTime) function(obj, p) {
        local curTime = ::dagor.getCurTime()
        local timeToShowSeconds = debuffs_data.time - ::milliseconds_to_seconds(curTime - createTime)
        if (timeToShowSeconds < 0)
          return true

        obj.setValue(timeToShowSeconds.tointeger().tostring())
        return false
      })(debuffs_data, createTime))
    }

    ::g_time_bar.setPeriod(timebarObj, debuffs_data.time)
    ::g_time_bar.setCurrentTime(timebarObj, 0)
  }


  function destoyRepairUpdater()
  {
    if (repairUpdater == null)
      return

    repairUpdater.remove()
    repairUpdater = null
  }


  function isValid()
  {
    return ::checkObj(scene)
  }
}
