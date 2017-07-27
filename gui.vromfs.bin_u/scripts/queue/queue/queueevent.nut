class ::queue_classes.Event extends ::queue_classes.Base
{
  shouldQueueCustomMode = false

  isQueueLeaved = false
  isCustomModeInTransition = false
  leaveQueueData = null

  function init()
  {
    name = ::getTblValue("mode", params, "")
    shouldQueueCustomMode = ::load_local_account_settings(getCustomModeSaveId(), false)
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
        if (::checkMatchingError(response))
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
    ::leave_session_queue(
      queryParams,
      function(response) {
        if (::checkMatchingError(response, needShowError))
          successCallback(response)
        else
          errorCallback(response)
      }
    )
  }

  function getQueryParams(needPlayers, customMgm = null)
  {
    local qp = {
      team = getTeamCode()
    }
    if (customMgm)
      qp.game_mode_id <- customMgm.gameModeId
    else
      qp.mode <- name

    if (queueType.useClusters)
      qp.clusters <- params.clusters

    if (!needPlayers)
      return qp

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

  function getCustomModeSaveId() { return "queue/customEvent/" + name }

  function getCustomMgm()
  {
    return ::events.getCustomGameMode(::events.getEvent(name))
  }

  function hasCustomMode() { return ::has_feature("QueueCustomEventRoom") && !!getCustomMgm() }

  function isCustomModeQUeued()
  {
    local customMgm = getCustomMgm()
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
    ::save_local_account_settings(getCustomModeSaveId(), shouldQueueCustomMode)

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
      _joinQueueImpl(getQueryParams(true, getCustomMgm()), cb, cb, true)
    else
      _leaveQueueImpl(getQueryParams(false, getCustomMgm()), cb, cb, true)
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