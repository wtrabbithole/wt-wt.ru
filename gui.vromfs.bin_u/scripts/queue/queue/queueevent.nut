class ::queue_classes.Event extends ::queue_classes.Base
{
  shouldQueueCustomMode = false

  isQueueLeaved = false
  isCustomModeInTransition = false
  leaveQueueData = null

  function init()
  {
    name = ::getTblValue("mode", params, "")
    shouldQueueCustomMode = getShouldQueueCustomMode(name)
  }

  static function getCustomModeSaveId(eventName) { return "queue/customEvent/" + eventName }
  static function getShouldQueueCustomMode(eventName)
  {
    return ::load_local_account_settings(::queue_classes.Event.getCustomModeSaveId(eventName), false)
  }
  static function setShouldQueueCustomMode(eventName, shouldSave)
  {
    return ::save_local_account_settings(::queue_classes.Event.getCustomModeSaveId(eventName), shouldSave)
  }

  static function getCustomMgm(eventName)
  {
    return ::events.getCustomGameMode(::events.getEvent(eventName))
  }

  static function hasCustomModeByEventName(eventName)
  {
    return ::has_feature("QueueCustomEventRoom") && !!::queue_classes.Event.getCustomMgm(eventName)
  }

  static function hasOptions(eventName)
  {
    return ::queue_classes.Event.hasCustomModeByEventName(eventName)
      && ::queue_classes.Event.isAllowedToSwitchCustomMode()
      && !::queues.findQueueByName(eventName, true)
  }

  static function getOptions(eventName)
  {
    if (!::queue_classes.Event.hasOptions(eventName))
      return null
    return {
      options = [[::USEROPT_QUEUE_EVENT_CUSTOM_MODE]]
      context = { eventName = eventName }
    }
  }

  function join(successCallback, errorCallback)
  {
    dagor.debug("enqueue into event session")
    debugTableData(params)
    _joinQueueImpl(getQueryParams(true), successCallback, errorCallback)
  }

  function _joinQueueImpl(queryParams, successCallback, errorCallback, needShowError = true)
  {
    ::enqueue_in_session(
      queryParams,
      function(response) {
        if (::checkMatchingError(response, needShowError))
        {
          if (this && shouldQueueCustomMode)
            switchCustomMode(shouldQueueCustomMode, true)
          successCallback(response)
        }
        else
          errorCallback(response)
      }.bindenv(this)
    )
  }

  function leave(successCallback, errorCallback, needShowError = false)
  {
    if (isCustomModeInTransition)
    {
      leaveQueueData = {
        successCallback = successCallback
        errorCallback = errorCallback
        needShowError = needShowError
      }
      return
    }
    _leaveQueueImpl(getQueryParams(false), successCallback, errorCallback, needShowError)
  }

  static function leaveAll(successCallback, errorCallback, needShowError = false)
  {
    ::queue_classes.Event._leaveQueueImpl({}, successCallback, errorCallback, needShowError)
  }

  static function _leaveQueueImpl(queryParams, successCallback, errorCallback, needShowError = false)
  {
    ::matching_api_func(
      "match.leave_queue"
      function(response) {
        if (::checkMatchingError(response, needShowError))
          successCallback(response)
        else
          errorCallback(response)
      }
      queryParams
    )
  }

  function getQueryParams(isForJoining, customMgm = null)
  {
    local qp = {}
    if (customMgm)
      qp.game_mode_id <- customMgm.gameModeId
    else
      qp.mode <- name

    if (!isForJoining)
      return qp

    qp.team <- getTeamCode()

    if (queueType.useClusters)
      qp.clusters <- params.clusters

    qp.players <- {
      [::my_user_id_str] = {
        country = ::queues.getQueueCountry(this)  //FIX ME: move it out of manager
        slots = ::queues.getQueueSlots(this)
      }
    }
    local members = ::getTblValue("members", params)
    if (members)
      foreach(uid, m in members)
      {
        qp.players[uid] <- {
          country = ("country" in m)? m.country : ::queues.getQueueCountry(this)
        }
        if ("slots" in m)
          qp.players[uid].slots <- m.slots
      }
    local option = ::get_option_in_mode(::USEROPT_QUEUE_JIP, ::OPTIONS_MODE_GAMEPLAY)
    qp.jip <- option.value
    local option = ::get_option_in_mode(::USEROPT_AUTO_SQUAD, ::OPTIONS_MODE_GAMEPLAY)
    qp.auto_squad <- option.value

    if (params)
      foreach (key in ["team", "roomId", "gameQueueId"])
        if (key in params)
          qp[key] <- params[key]

    return qp
  }

  function getQueueData(qParams)
  {
    local res = base.getQueueData(qParams)
    res.gameModeId <- ::getTblValue("gameModeId", qParams, -1)
    return res
  }

  function hasCustomMode()
  {
    return hasCustomModeByEventName(name)
  }

  function isCustomModeQUeued()
  {
    local customMgm = getCustomMgm(name)
    if (!customMgm)
      return false
    return !!::u.search(queueUidsList, @(q) q.gameModeId == customMgm.gameModeId )
  }

  function isCustomModeSwitchedOn()
  {
    return shouldQueueCustomMode
  }

  function switchCustomMode(shouldQueue, needForceRequest = false)
  {
    if (!isAllowedToSwitchCustomMode()
      || (!needForceRequest && shouldQueue == shouldQueueCustomMode))
      return

    shouldQueueCustomMode = shouldQueue
    setShouldQueueCustomMode(name, shouldQueueCustomMode)

    if (isCustomModeInTransition)
      return

    local queue = this
    local cb = function(res)
    {
      queue.isCustomModeInTransition = false
      queue.afterCustomModeQueueChanged(shouldQueue)
    }
    isCustomModeInTransition = true
    if (shouldQueueCustomMode)
      _joinQueueImpl(getQueryParams(true, getCustomMgm(name)), cb, cb, false)
    else
      _leaveQueueImpl(getQueryParams(false, getCustomMgm(name)), cb, cb, false)
  }

  function afterCustomModeQueueChanged(wasShouldQueue)
  {
    if (leaveQueueData)
    {
      leave(leaveQueueData.successCallback, leaveQueueData.errorCallback, leaveQueueData.needShowError)
      return
    }

    if (wasShouldQueue != shouldQueueCustomMode)
      switchCustomMode(shouldQueueCustomMode, true)
  }
}