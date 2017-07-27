class ::queue_classes.Event extends ::queue_classes.Base
{
  function init()
  {
    name = ::getTblValue("mode", params, "")
  }

  function join(successCallback, errorCallback)
  {
    dagor.debug("enqueue into event session")
    debugTableData(params)
    ::enqueue_in_session(
      getQueryParams(true),
      function(response) {
        if (::checkMatchingError(response))
          successCallback(response)
        else
          errorCallback(response)
      }
    )
  }

  function leave(successCallback, errorCallback, needShowError = false)
  {
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

  function getQueryParams(needPlayers)
  {
    local qp = {
      mode = name
      team = getTeamCode()
    }
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
}