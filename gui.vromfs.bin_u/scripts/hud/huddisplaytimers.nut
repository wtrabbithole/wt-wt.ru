local time = require("scripts/time.nut")

::g_hud_display_timers <- {
  timersList = [
    {
      id = "repair_status"
      color = "#787878"
      icon = "#ui/gameuiskin#icon_repair_in_progress"
      needTimeText = true
    },
    {
      id = "repair_auto_status"
      color = "#787878"
      icon = function () {
        if (::g_hud_display_timers.unitType == ::ES_UNIT_TYPE_SHIP)
          return "#ui/gameuiskin#ship_crew_driver"
        return "#ui/gameuiskin#track_state_indicator"
      }
      needTimeText = true
    },
    {
      id = "rearm_status"
      color = "@white"
      icon = "#ui/gameuiskin#icon_weapons_in_progress"
    },
    {
      id = "rearm_rocket_status"
      color = "@white"
      icon = "#ui/gameuiskin#icon_rocket_in_progress"
    },
    {
      id = "rearm_smoke_status"
      color = "@white"
      icon = "#ui/gameuiskin#icon_smoke_screen_in_progress"
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
    },
    {
      id = "repair_breaches_status"
      color = "#787878"
      icon = "#ui/gameuiskin#icon_repair_in_progress"
      needTimeText = true
    },
    {
      id = "unwatering_status"
      color = "#787878"
      icon = "#ui/gameuiskin#unwatering_in_progress"
      needTimeText = true
    },
    {
      id = "cancel_repair_breaches_status"
      color = "#787878"
      icon = "#ui/gameuiskin#icon_repair_in_progress"
      needTimeText = true
    },
    {
      id = "extinguish_status"
      color = "#DD1111"
      icon = "#ui/gameuiskin#fire_indicator"
      needTimeText = true
    },
    {
      id = "cancel_extinguish_status"
      color = "#DD1111"
      icon = "#ui/gameuiskin#fire_indicator"
      needTimeText = true
    }
  ]

  scene = null
  guiScene = null

  repairUpdater = null
  repairBreachesUpdater = null
  extinguishUpdater = null
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
    ::g_hud_event_manager.subscribe("TankDebuffs:Repair", onRepair, this)
    ::g_hud_event_manager.subscribe("ShipDebuffs:Repair", onRepair, this)
    ::g_hud_event_manager.subscribe("ShipDebuffs:RepairBreaches", onRepairBreaches, this)
    ::g_hud_event_manager.subscribe("ShipDebuffs:Extinguish", onExtinguish, this)
    ::g_hud_event_manager.subscribe("ShipDebuffs:CancelRepairBreaches", onCancelRepairBreaches, this)
    ::g_hud_event_manager.subscribe("ShipDebuffs:CancelExtinguish", onCancelExtinguish, this)

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
    destoyRepairBreachesUpdater()
    destoyExtinguishUpdater()
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
    destoyRepairUpdater()
    hideAnimTimer("repair_status")
    hideAnimTimer("repair_auto_status")

    if (debuffs_data.state == "notInRepair")
      return

    local objId = debuffs_data.state == "repairingAuto" ? "repair_auto_status" : "repair_status"
    local placeObj = scene.findObject(objId)
    if (!::checkObj(placeObj))
      return

    placeObj.animation = "show"

    local iconObj = placeObj.findObject("icon")
    local timebarObj = placeObj.findObject("timer")
    local timeTextObj = placeObj.findObject("time_text")
    timeTextObj.setValue("")

    placeObj.show(true)

    if (debuffs_data.state == "prepareRepair")
    {
      iconObj.wink = "fast"
      ::g_time_bar.setDirectionBackward(timebarObj)
    }
    else if (debuffs_data.state == "repairing" || debuffs_data.state == "repairingAuto")
    {
      iconObj.wink = "no"
      ::g_time_bar.setDirectionForward(timebarObj)
      local createTime = ::dagor.getCurTime()
      repairUpdater = ::secondsUpdater(timeTextObj, (@(debuffs_data, createTime) function(obj, p) {
        local curTime = ::dagor.getCurTime()
        local timeToShowSeconds = debuffs_data.time - time.millisecondsToSeconds(curTime - createTime)
        if (timeToShowSeconds < 0)
          return true

        obj.setValue(timeToShowSeconds.tointeger().tostring())
        return false
      })(debuffs_data, createTime))
    }

    ::g_time_bar.setPeriod(timebarObj, debuffs_data.time)
    ::g_time_bar.setCurrentTime(timebarObj, 0)
  }

  function hideAnimTimer(objId)
  {
    local placeObj = scene.findObject(objId)
    if (!::checkObj(placeObj))
      return
    placeObj.animation = "hide"
    placeObj.findObject("icon").wink = "no"
  }

  function onCancelAction(debuffs_data, placeObj)
  {
    placeObj.animation = debuffs_data.time > 0 ? "show" : "hide"
    placeObj.show(true)

    local timebarObj = placeObj.findObject("timer")
    local iconObj = placeObj.findObject("icon")
    iconObj.wink = "no"
    local timeTextObj = placeObj.findObject("time_text")
    timeTextObj.show(false)

    if (debuffs_data.time > 0)
      ::g_time_bar.setDirectionBackward(timebarObj)

    ::g_time_bar.setPeriod(timebarObj, debuffs_data.time)
    ::g_time_bar.setCurrentTime(timebarObj, 0)
  }

  function onRepairBreaches(debuffs_data)
  {
    if (debuffs_data.state == "notInRepair")
    {
      destoyRepairBreachesUpdater()
      hideAnimTimer("unwatering_status")
      hideAnimTimer("repair_breaches_status")
      return
    }

    local objId = debuffs_data.state == "unwatering" ? "unwatering_status" : "repair_breaches_status"
    local placeObj = scene.findObject(objId)
    if (!::checkObj(placeObj))
      return


    placeObj.animation = "show"

    destoyRepairBreachesUpdater()
    local iconObj = placeObj.findObject("icon")
    local timebarObj = placeObj.findObject("timer")
    local timeTextObj = placeObj.findObject("time_text")
    timeTextObj.setValue("")

    placeObj.show(true)

    if (debuffs_data.state == "repairing" || debuffs_data.state == "unwatering")
    {
      iconObj.wink = "no"
      ::g_time_bar.setDirectionForward(timebarObj)
      local createTime = ::dagor.getCurTime()
      repairBreachesUpdater = ::secondsUpdater(timeTextObj, (@(debuffs_data, createTime) function(obj, p) {
        local curTime = ::dagor.getCurTime()
        local timeToShowSeconds = debuffs_data.time - time.millisecondsToSeconds(curTime - createTime)
        if (timeToShowSeconds < 0)
          return true

        obj.setValue(timeToShowSeconds.tointeger().tostring())
        return false
      })(debuffs_data, createTime))
    }

    ::g_time_bar.setPeriod(timebarObj, debuffs_data.time)
    ::g_time_bar.setCurrentTime(timebarObj, 0)
  }

  function onCancelRepairBreaches(debuffs_data)
  {
    local placeObj = scene.findObject("cancel_repair_breaches_status")
    if (!::checkObj(placeObj))
      return

    onCancelAction(debuffs_data, placeObj)
  }

  function onExtinguish(debuffs_data)
  {
    local placeObj = scene.findObject("extinguish_status")
    if (!::checkObj(placeObj))
      return

    local showTimer = debuffs_data.state != "notInExtinguish"
    placeObj.animation = showTimer ? "show" : "hide"

    destoyExtinguishUpdater()
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

    if (debuffs_data.state == "extinguish")
    {
      iconObj.wink = "no"
      ::g_time_bar.setDirectionForward(timebarObj)
      local createTime = ::dagor.getCurTime()
      extinguishUpdater = ::secondsUpdater(timeTextObj, (@(debuffs_data, createTime) function(obj, p) {
        local curTime = ::dagor.getCurTime()
        local timeToShowSeconds = debuffs_data.time - time.millisecondsToSeconds(curTime - createTime)
        if (timeToShowSeconds < 0)
          return true

        obj.setValue(timeToShowSeconds.tointeger().tostring())
        return false
      })(debuffs_data, createTime))
    }

    ::g_time_bar.setPeriod(timebarObj, debuffs_data.time)
    ::g_time_bar.setCurrentTime(timebarObj, 0)
  }

  function onCancelExtinguish(debuffs_data)
  {
    local placeObj = scene.findObject("cancel_extinguish_status")
    if (!::checkObj(placeObj))
      return

    onCancelAction(debuffs_data, placeObj)
  }

  function destoyRepairUpdater()
  {
    if (repairUpdater == null)
      return

    repairUpdater.remove()
    repairUpdater = null
  }

  function destoyRepairBreachesUpdater()
  {
    if (repairBreachesUpdater == null)
      return

    repairBreachesUpdater.remove()
    repairBreachesUpdater = null
  }

  function destoyExtinguishUpdater()
  {
    if (extinguishUpdater == null)
      return

    extinguishUpdater.remove()
    extinguishUpdater = null
  }

  function isValid()
  {
    return ::checkObj(scene)
  }
}
