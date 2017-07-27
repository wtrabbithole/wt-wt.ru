enum qTypeCheckOrder {
  COMMON
  ANY_EVENT
  UNKNOWN
}

::g_queue_type <- {
  types = []
}

function g_queue_type::addClusterToQueueByParams(queue, params, needEvent = true)
{
  if (!("cluster" in params))
    return

  local cluster = params.cluster
  local queueUid = ::getTblValue("queueId", params)
  if (queueUid != null)
    queue.queueUidsList[queueUid] <- cluster

  if (!::isInArray(cluster, queue.params.clusters))
  {
    queue.params.clusters.append(cluster)
    if (needEvent)
      ::broadcastEvent("QueueClustersChanged", queue)
  }
}

::g_queue_type.template <- {
  typeName = "" //filled automatically by typeName
  bit = QUEUE_TYPE_BIT.UNKNOWN
  checkOrder = qTypeCheckOrder.COMMON
  useSlots = true
  useClusters = true

  prepareQueueParams = function(params)
  {
    if (useSlots)
      if(!("slots" in params))
        params.slots <- ::getSelSlotsTable()

    if (useClusters)
      if(!("clusters" in params))
        params.clusters <- ::get_current_clusters()

    return params
  }

  createQueue = function(queueId, params) {
    local newQueue = getDefaultQueue(queueId, params)

    if (useClusters)
    {
      local clusters = ::u.isArray(::getTblValue("clusters", params)) ? params.clusters : []
      newQueue.params.clusters <- clusters
      ::g_queue_type.addClusterToQueueByParams(newQueue, params, false)
    }

    return newQueue
  }

  getDefaultQueue = @(queueId, params) getBaseQueue(queueId, params)

  /**
    queue params, cant be null at least table (overrides in createQueue func)
    params = { clusters = array of strings, mode = string, country = string, team = int}
    params.members = { [uid] = { country, slots } }
  **/
  getBaseQueue = function(queueId, params) {
    return {
      id = queueId
      typeBit = bit
      queueType = this
      name = ::getTblValue("mode", params, "")
      state = queueStates.NOT_IN_QUEUE
      activateTime = -1
      params = params ? params : {}
      queueUidsList = {} // { <queueUid> = <clusterName> }
      queueStats = null //created on first stats income. We dont know stats version before
      selfActivated = ::getTblValue("queueSelfActivated", params, false)
    }
  }

  join = function(queue, params, successCallback, errorCallback)
  {
    dagor.debug("enqueue into session")
    debugTableData(params)
    ::enqueue_in_session(
      ::g_queue_utils.getQueryParams(queue, true, params),
      (@(successCallback, errorCallback) function(response) {
        if (::checkMatchingError(response))
          successCallback(response)
        else
          errorCallback(response)
      })(successCallback, errorCallback)
    )
  }

  leave = function(queue, successCallback, errorCallback, showError = false) {
    ::leave_session_queue(
      ::g_queue_utils.getQueryParams(queue, false),
      (@(successCallback, errorCallback, showError) function(response) {
        if (::checkMatchingError(response, showError))
          successCallback(response)
        else
          errorCallback(response)
      })(successCallback, errorCallback, showError)
    )
  }

  updateInfo = function(successCallback, errorCallback, showError = false) {}
  isParamsCorresponds = @(params) true
}

::g_enum_utils.addTypesByGlobalName("g_queue_type",
  {
    UNKNOWN = {
      checkOrder = qTypeCheckOrder.UNKNOWN
    }

    EVENT = {
      bit = QUEUE_TYPE_BIT.EVENT
      checkOrder = qTypeCheckOrder.ANY_EVENT
      isParamsCorresponds = @(params) !::u.isEmpty(::getTblValue("mode", params))
    }

    NEWBIE = {
      bit = QUEUE_TYPE_BIT.NEWBIE
      isParamsCorresponds = @(params) ("mode" in params) && ::my_stats.isNewbieEventId(params.mode)
    }

    DOMINATION = {
      bit = QUEUE_TYPE_BIT.DOMINATION
      isParamsCorresponds = @(params) ("mode" in params) && ::events.isEventRandomBattlesById(params.mode)
    }

    WW_BATTLE = {
      bit = QUEUE_TYPE_BIT.WW_BATTLE
      useSlots = false
      useClusters = false

      isParamsCorresponds = @(params) "battleId" in params
      prepareQueueParams = function(params) {
        return params
      }

      getDefaultQueue = function(queueId, params) {
        local newQueue = getBaseQueue(queueId, params)
        newQueue.name = ::getTblValue("operationId", params, "") + "_"
                        + ::getTblValue("battleId", params, "")
        return newQueue
      }

      join = function(queue, params, successCallback, errorCallback) {
        ::request_matching(
          "worldwar.join_battle",
          successCallback,
          errorCallback,
          params
        )
      }

      leave = function(queue, successCallback, errorCallback, showError = false) {
        ::request_matching(
          "worldwar.leave_battle",
          successCallback,
          errorCallback,
          null,
          { showError = showError }
        )
      }

      updateInfo = function(successCallback, errorCallback, showError = false) {
        ::request_matching(
          "worldwar.get_queue_info",
          (@(successCallback) function(response) {
            local queuesInfo = {}
            local responseQueues = ::getTblValue("queues", response, [])
            foreach(battleQueueInfo in responseQueues)
              queuesInfo[battleQueueInfo.battleId] <- battleQueueInfo

            if (successCallback != null)
              successCallback(queuesInfo)
          })(successCallback),
          errorCallback,
          null,
          { showError = showError }
        )
      }
    }
  },
  null,
  "typeName"
)

::g_queue_type.types.sort(@(a, b) a.checkOrder <=> b.checkOrder)

function g_queue_type::getQueueTypeByParams(params)
{
  if (!params)
    return UNKNOWN
  foreach(qType in types)
    if (qType.isParamsCorresponds(params))
      return qType
  return UNKNOWN
}
