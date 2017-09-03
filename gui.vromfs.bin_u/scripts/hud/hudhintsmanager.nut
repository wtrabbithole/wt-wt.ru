local time = require("scripts/time.nut")
::g_hud_hints_manager <- {
  [PERSISTENT_DATA_PARAMS] = ["activeHints"]

  nest = null
  scene = null
  guiScene = null

  activeHints = []
  animatedRemovedHints = [] //hints set to remove animation. to be able instant finish them

  timerNest = null

  hintIdx = 0 //used only for unique hint id

  function init(_nest)
  {
    subscribe()

    if (!::checkObj(_nest))
      return
    nest = _nest

    if (!findSceneObjects())
      return
    restoreAllHints()
  }


  function reinit()
  {
    if (!findSceneObjects())
      return
    restoreAllHints()
  }


  function onEventLoadingStateChange(p)
  {
    if (!::is_in_flight())
      activeHints.clear()
    animatedRemovedHints.clear()
  }


  //return false if can't
  function findSceneObjects()
  {
    scene = nest.findObject("hud_hints_nest")
    if (!::checkObj(scene))
      return false

    guiScene = scene.getScene()
    timerNest = nest.findObject("hud_message_timers")

    if (!::checkObj(timerNest))
      return false

    return true
  }


  function restoreAllHints()
  {
    foreach (hintData in activeHints)
      updateHint(hintData)
  }


  function subscribe()
  {
    foreach (hint in ::g_hud_hints.types)
    {
      if (!::u.isNull(hint.showEvent))
        ::g_hud_event_manager.subscribe(hint.showEvent, (@(hint) function (eventData) {
          if (!hint.isCurrent(eventData, false))
            return

          local hintData = findActiveHintFromSameGroup(hint)

          if (hintData)
            if (!hint.hintType.isReplaceable(hint, eventData, hintData.hint, hintData.eventData))
              return
            else if (hint == hintData.hint)
            {
              hideHint(hintData, true)
              updateHintInList(hintData, eventData)
            }
            else
            {
              removeHint(hintData, true)
              hintData = null
            }

          if (!hintData)
            hintData = addToList(hint, eventData)
          showHint(hintData)

          updateHint(hintData)
        })(hint), this)

      if (!::u.isNull(hint.hideEvent))
        ::g_hud_event_manager.subscribe(hint.hideEvent, (@(hint) function (eventData) {
          if (!hint.isCurrent(eventData, true))
            return

          local hintData = findActiveHintFromSameGroup(hint)
          if (!hintData)
            return
          removeHint(hintData, hintData.hint.isInstantHide(eventData))
        })(hint), this)

      if (hint.updateCbs)
        foreach(eventName, func in hint.updateCbs)
          ::g_hud_event_manager.subscribe(eventName, (@(hint, func) function (eventData) {
            if (!hint.isCurrent(eventData, false))
              return

            local hintData = findActiveHintFromSameGroup(hint)
            local needUpdate = func.call(hint, hintData, eventData)
            if (hintData && needUpdate)
              updateHint(hintData)
          })(hint, func), this)
    }
  }

  function findActiveHintFromSameGroup(hint)
  {
    return ::u.search(activeHints, (@(hint) function (hintData) {
      return hint.hintType.isSameReplaceGroup(hintData.hint, hint)
    })(hint))
  }

  function addToList(hint, eventData)
  {
    activeHints.append({
      hint = hint
      hintObj = null
      addTime = ::dagor.getCurTime()
      eventData = eventData
      removeTimer = null
    })

    local addedHint = ::u.last(activeHints)
    updateRemoveTimer(addedHint)
    return addedHint
  }

  function updateRemoveTimer(hintData)
  {
    if (!::checkObj(timerNest))
      return
    if (!hintData.hint.selfRemove)
      return

    local lifeTime = hintData.hint.getLifeTime(hintData.eventData)
    if (hintData.removeTimer)
    {
      if (lifeTime <= 0)
        hintData.removeTimer.destroy()
      else
        hintData.removeTimer.setDelay(lifeTime)
      return
    }

    if (lifeTime <= 0)
      return

    hintData.removeTimer = ::Timer(timerNest, lifeTime, (@(hintData) function () {
      hideHint(hintData, false)
      removeFromList(hintData)
    })(hintData), this)
  }

  function updateHintInList(hintData, eventData)
  {
    hintData.eventData = eventData
    hintData.addTime = ::dagor.getCurTime()
  }

  function removeFromList(hintData)
  {
    local idx = ::u.searchIndex(activeHints, (@(hintData) function (item) { return item == hintData })(hintData) )
    if (idx >= 0)
      activeHints.remove(idx)
  }

  function showHint(hintData)
  {
    if (!::checkObj(nest))
      return

    local hintNestObj = nest.findObject(hintData.hint.getHintNestId())
    if (!::checkObj(hintNestObj))
      return

    checkRemovedHints(hintData.hint) //remove hints with not finished animation if needed

    local id = hintData.hint.name + (++hintIdx)
    local markup = hintData.hint.buildMarkup(hintData.eventData, id)
    guiScene.appendWithBlk(hintNestObj, markup, markup.len(), null)
    hintData.hintObj = hintNestObj.findObject(id)
    setCoutdownTimer(hintData)
  }

  function setCoutdownTimer(hintData)
  {
    if (!hintData.hint.selfRemove)
      return

    local hintObj = hintData.hintObj
    if (!::checkObj(hintObj))
      return

    hintData.secondsUpdater <- ::secondsUpdater(hintObj, (@(hintData) function (obj, params) {
      local textObj = obj.findObject("time_text")
      if (!::checkObj(textObj))
        return false

      local lifeTime = hintData.hint.getLifeTime(hintData.eventData)
      local offset = time.millisecondsToSeconds(::dagor.getCurTime() - hintData.addTime)
      local timeLeft = (lifeTime - offset + 0.5).tointeger()

      if (timeLeft < 0)
        return true

      textObj.setValue(timeLeft.tostring())
      return false
    })(hintData))
  }

  function hideHint(hintData, isInstant)
  {
    local hintObject = hintData.hintObj
    if (!::check_obj(hintObject))
      return

    local needFinalizeRemove = hintData.hint.hideHint(hintObject, isInstant)
    if (needFinalizeRemove)
      animatedRemovedHints.append(clone hintData)
  }

  function removeHint(hintData, isInstant)
  {
    hideHint(hintData, isInstant)
    if (hintData.hint.selfRemove && hintData.removeTimer)
      hintData.removeTimer.destroy()
    removeFromList(hintData)
  }

  function checkRemovedHints(hint)
  {
    for(local i = animatedRemovedHints.len() - 1; i >= 0; i--)
    {
      local hintData = animatedRemovedHints[i]
      if (::check_obj(hintData.hintObj))
      {
        if (!hint.hintType.isSameReplaceGroup(hintData.hint, hint))
          continue
        hintData.hint.hideHint(hintData.hintObj, true)
      }
      animatedRemovedHints.remove(i)
    }
  }

  function updateHint(hintData)
  {
    updateRemoveTimer(hintData)

    local hintObj = hintData.hintObj
    if (!::checkObj(hintObj))
      return showHint(hintData)

    setCoutdownTimer(hintData)

    local timeBarObj = hintObj.findObject("time_bar")
    if (::checkObj(timeBarObj))
    {
      local totaltime = hintData.hint.getTimerTotalTimeSec(hintData.eventData)
      local currentTime = hintData.hint.getTimerCurrentTimeSec(hintData.eventData, hintData.addTime)
      ::g_time_bar.setPeriod(timeBarObj, totaltime)
      ::g_time_bar.setCurrentTime(timeBarObj, currentTime)
    }
  }

  function onEventScriptsReloaded(p)
  {
    foreach(hintData in activeHints)
      hintData.hint = ::g_hud_hints.getByName(hintData.hint.name)
  }
}

::g_script_reloader.registerPersistentDataFromRoot("g_hud_hints_manager")
::subscribe_handler(::g_hud_hints_manager, ::g_listener_priority.DEFAULT_HANDLER)
