::g_hud_hints_manager <- {
  [PERSISTENT_DATA_PARAMS] = ["activeHints"]

  nest = null
  scene = null
  guiScene = null

  activeHints = []

  timerNest = null

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
          local hintData = findActiveHintFromSameGroup(hint)

          if (!hintData)
          {
            hintData = addToList(hint, eventData)
            showHint(hintData)
          }
          else if (hint.hintType.isReplaceable(hint, eventData, hintData.hint, hintData.eventData))
          {
            hideHint(hintData)
            hintData.eventData = eventData
            showHint(hintData)
          }
          else
            updateHintInList(hintData, eventData)

          updateHint(hintData)
        })(hint), this)

      if (!::u.isNull(hint.hideEvent))
        ::g_hud_event_manager.subscribe(hint.hideEvent, (@(hint) function (eventData) {
          local hintData = findActiveHintFromSameGroup(hint)
          if (!hintData)
            return
          hideHint(hintData)
          if (hintData.hint.selfRemove && hintData.removeTimer)
            hintData.removeTimer.destroy()
          removeFromList(hintData)
        })(hint), this)

      if (hint.updateCbs)
        foreach(eventName, func in hint.updateCbs)
          ::g_hud_event_manager.subscribe(eventName, (@(hint, func) function (eventData) {
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
    addRemoveTimer(addedHint)
    return addedHint
  }

  function addRemoveTimer(hintData)
  {
    if (!::checkObj(timerNest))
      return
    if (!hintData.hint.selfRemove || hintData.removeTimer != null)
      return

    local lifeTime = hintData.hint.getLifeTime(hintData.eventData)
    hintData.removeTimer = ::Timer(timerNest, lifeTime, (@(hintData) function () {
      hideHint(hintData)
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
    if (idx != null)
      activeHints.remove(idx)
  }

  function showHint(hintData)
  {
    if (!::checkObj(nest))
      return

    local hintNestObj = nest.findObject(hintData.hint.getHintNestId())
    if (!::checkObj(hintNestObj))
      return

    local id = hintData.hint.name
    local markup = hintData.hint.buildMarkup(hintData.eventData)
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
      local offset = ::milliseconds_to_seconds(::dagor.getCurTime() - hintData.addTime)
      local timeLeft = (lifeTime - offset + 0.5).tointeger()

      if (timeLeft < 0)
        return true

      textObj.setValue(timeLeft.tostring())
      return false
    })(hintData))
  }

  function hideHint(hintData)
  {
    local hintObject = hintData.hintObj
    if (!::checkObj(hintObject))
      return

    guiScene.destroyElement(hintObject)
  }

  function updateHint(hintData)
  {
    addRemoveTimer(hintData)

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
