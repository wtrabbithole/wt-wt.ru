local SecondsUpdater = require("sqDagui/timer/secondsUpdater.nut")
local DaguiSceneTimers = require("sqDagui/timer/daguiSceneTimers.nut")
local time = require("scripts/time.nut")

const TIMERS_CHECK_INTEVAL = 0.25

enum HintShowState {
  NOT_MATCH = 0
  SHOW_HINT = 1
  DISABLE   = 2
}

::g_hud_hints_manager <- {
  [PERSISTENT_DATA_PARAMS] = ["activeHints"]

  nest = null
  scene = null
  guiScene = null

  activeHints = []
  animatedRemovedHints = [] //hints set to remove animation. to be able instant finish them

  timers = DaguiSceneTimers(TIMERS_CHECK_INTEVAL, "hudHintsTimers")

  hintIdx = 0 //used only for unique hint id

  lastShowedTimeDict = {} // key = maskId, value = lastShowedTime

  delayedShowTimers = {} // key = hint.name, value = timer

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
    {
      activeHints.clear()
      timers.reset()
    } else
    {
      local hintOptionsBlk = ::DataBlock()
      foreach (hint in ::g_hud_hints.types)
        hint.updateHintOptionsBlk(hintOptionsBlk)
      ::set_hint_options_by_blk(hintOptionsBlk)
    }
    animatedRemovedHints.clear()
  }


  function onLocalPlayerDead()
  {
    local hints = ::u.filter(activeHints, @(hintData) hintData.hint.isHideOnDeath)
    foreach (hintData in hints)
      removeHint(hintData, true)
  }


  //return false if can't
  function findSceneObjects()
  {
    scene = nest.findObject("hud_hints_nest")
    if (!::checkObj(scene))
      return false

    guiScene = scene.getScene()
    timers.setUpdaterObj(scene)
    return true
  }


  function restoreAllHints()
  {
    foreach (hintData in activeHints)
      updateHint(hintData)
  }


  function subscribe()
  {
    ::g_hud_event_manager.subscribe("LocalPlayerDead", function (eventData) {
      onLocalPlayerDead()
    }, this)

    foreach (hint in ::g_hud_hints.types)
    {
      if(!hint.isEnabled() || isHintShowCountExceeded(hint))
      {
        dagor.debug("Hints: " + (hint?.showEvent ?? "_") + " is disabled")
        continue
      }

      if (!::u.isNull(hint.showEvent))
        ::g_hud_event_manager.subscribe(hint.showEvent, (@(hint) function (eventData) {
          if(isHintShowCountExceeded(hint))
            return

          if(hint.delayTime > 0)
            showDelayed(hint, eventData)
          else
            onShowEvent(hint, eventData)
        })(hint), this)

      if (!::u.isNull(hint.hideEvent))
        ::g_hud_event_manager.subscribe(hint.hideEvent, (@(hint) function (eventData) {
          if (!hint.isCurrent(eventData, true))
            return

          removeDelayedShowTimer(hint)

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
      lifeTimerWeak = null
    })

    local addedHint = ::u.last(activeHints)
    return addedHint
  }

  function updateRemoveTimer(hintData)
  {
    if (!hintData.hint.selfRemove)
      return

    local lifeTime = hintData.hint.getLifeTime(hintData.eventData)
    if (hintData.lifeTimerWeak)
    {
      if (lifeTime <= 0)
        timers.removeTimer(hintData.lifeTimerWeak)
      else
        timers.setTimerTime(hintData.lifeTimerWeak, lifeTime)
      return
    }

    if (lifeTime <= 0)
      return

    hintData.lifeTimerWeak = timers.addTimer(lifeTime, ::Callback(function () {
      hideHint(hintData, false)
      removeFromList(hintData)
      removeDelayedShowTimer(hintData.hint)
    }, this)).weakref()
  }

  function removeDelayedShowTimer(hint)
  {
    if(delayedShowTimers?[hint.name])
    {
      timers.removeTimer(delayedShowTimers[hint.name])
      delete delayedShowTimers[hint.name]
    }
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

  function onShowEvent(hint, eventData)
  {
    if (!hint.isCurrent(eventData, false))
      return

    local res = checkHintInterval(hint)
    if (res == HintShowState.DISABLE)
    {
      ::disable_hint(hint.mask)
      return
    }
    else if (res == HintShowState.NOT_MATCH)
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

    lastShowedTimeDict[hintData.hint.maskId] <- ::dagor.getCurTime()
    ::increase_hint_show_count(hintData.hint.maskId)
  }

  function setCoutdownTimer(hintData)
  {
    if (!hintData.hint.selfRemove)
      return

    local hintObj = hintData.hintObj
    if (!::checkObj(hintObj))
      return

    hintData.secondsUpdater <- SecondsUpdater(hintObj, (@(hintData) function (obj, params) {
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
    if (hintData.hint.selfRemove && hintData.lifeTimerWeak)
      timers.removeTimer(hintData.lifeTimerWeak)
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


  function checkHintInterval(hint)
  {
    local interval = hint.getTimeInterval()
    if (interval == HINT_INTERVAL.ALWAYS_VISIBLE)
      return HintShowState.SHOW_HINT
    else if (interval == HINT_INTERVAL.HIDDEN)
      return HintShowState.DISABLE

    if (!(hint.maskId in lastShowedTimeDict))
    {
      return HintShowState.SHOW_HINT
    }
    else
    {
      local ageSec = (::dagor.getCurTime() - lastShowedTimeDict[hint.maskId]) * 0.001
      return ageSec >= interval ? HintShowState.SHOW_HINT : HintShowState.NOT_MATCH
    }

    return HintShowState.NOT_MATCH
  }

  function isHintShowCountExceeded(hint)
  {
    if(hint.maskId >= 0 || (hint?.totalCount ?? 0) > 0)
      dagor.debug("Hints: " + (hint?.showEvent ?? "_")
      + " maskId = " + hint.maskId
      + " totalCount = " + (hint?.totalCount ?? "_")
      + " showedCount = " + ::get_hint_seen_count(hint.maskId))

    return (hint.totalCount > 0
      && ::get_hint_seen_count(hint.maskId) > hint.totalCount)
  }

  function showDelayed(hint, eventData)
  {
    if (hint.delayTime <= 0)
      return
    if(delayedShowTimers?[hint.name])
      return

    delayedShowTimers[hint.name] <- timers.addTimer(hint.delayTime, ::Callback(function () {
      if(delayedShowTimers?[hint.name])
        onShowEvent(hint, eventData)
    }, this)).weakref()
  }
}

::g_script_reloader.registerPersistentDataFromRoot("g_hud_hints_manager")
::subscribe_handler(::g_hud_hints_manager, ::g_listener_priority.DEFAULT_HANDLER)
