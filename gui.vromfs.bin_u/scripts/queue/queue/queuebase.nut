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
  queueUidsList = null // { <queueUid> = <clusterName> }
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
      queueUidsList[queueUid] <- cluster

    if (::isInArray(cluster, params.clusters))
      return false

    params.clusters.append(cluster)
    return true
  }

  function getTeamCode()
  {
    return ::getTblValue("team", params, Team.Any)
  }

  function join(successCallback, errorCallback) {}
  function leave(successCallback, errorCallback, needShowError = false) {}
  static function leaveAll(successCallback, errorCallback, needShowError = false) {}
}