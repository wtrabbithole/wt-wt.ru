class ::queue_classes.Base
{
  id = 0
  name = ""
  typeBit = QUEUE_TYPE_BIT.UNKNOWN //FIX ME: should to rename this also
  queueType = ::g_queue_type.UNKNOWN
  state = queueStates.NOT_IN_QUEUE

  params = null //params = { clusters = array of strings, mode = string, country = string, team = int}
                //params.members = { [uid] = { country, slots } }
  activateTime = -1
  queueUidsList = null // { <queueUid> = <getQueueData> }
  queueStats = null //created on first stats income. We dont know stats version before
  selfActivated = false

  constructor(queueId, _queueType, _params)
  {
    id = queueId
    queueType = _queueType
    params = _params || {}

    typeBit = queueType.bit
    queueUidsList = {}
    selfActivated = ::getTblValue("queueSelfActivated", params, false)

    if (queueType.useClusters)
    {
      if (!::u.isArray(::getTblValue("clusters", params)))
        params.clusters <- []
      addClusterByParams(params)
    }

    init()
  }

  function init() {}

  //return <is clusters list changed>
  function addClusterByParams(qParams)
  {
    if (!("cluster" in qParams))
      return false

    local cluster = qParams.cluster
    local queueUid = ::getTblValue("queueId", qParams)
    if (queueUid != null)
      queueUidsList[queueUid] <- getQueueData(qParams)

    if (::isInArray(cluster, params.clusters))
      return false

    params.clusters.append(cluster)
    return true
  }

  //return true if queue changed
  function onLeaveQueue(leaveData)
  {
    local queueUid = ::getTblValue("queueId", leaveData)
    if (queueUid == null || (queueUid in queueUidsList && queueUidsList.len() == 1)) //leave all queues
    {
      queueUidsList.clear()
      params.clusters.clear()
      return true
    }

    if (!(queueUid in queueUidsList))
      return false

    local cluster = queueUidsList[queueUid].cluster
    delete queueUidsList[queueUid]

    if (!::u.search(queueUidsList, @(q) q.cluster == cluster))
    {
      local idx = params.clusters.find(cluster)
      if (idx != -1)
        params.clusters.remove(idx)
    }
    return true
  }

  function isActive()
  {
    return queueUidsList.len() > 0
  }

  function getQueueData(qParams)
  {
    return { cluster = qParams.cluster }
  }

  function getTeamCode()
  {
    return ::getTblValue("team", params, Team.Any)
  }

  function join(successCallback, errorCallback) {}
  function leave(successCallback, errorCallback, needShowError = false) {}
  static function leaveAll(successCallback, errorCallback, needShowError = false) {}

  function hasCustomMode() { return false }
  //is already exist queue with custom mode.
  //custom mode can be switched off, but squad leader can set to queue with custom mode.
  function isCustomModeQUeued() { return false }
  //when custom mode switched on, it will be queued automatically
  function isCustomModeSwitchedOn() { return false }
  function switchCustomMode(shouldQueue) {}
  function isAllowedToSwitchCustomMode()
    { return !::g_squad_manager.isInSquad() || ::g_squad_manager.isSquadLeader() }
}