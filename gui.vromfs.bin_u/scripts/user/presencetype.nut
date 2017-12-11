enum presenceCheckOrder {
  IN_GAME_WW
  IN_GAME
  IN_QUEUE
  IDLE
}

::g_presence_type <- {
  types = []
}

::g_presence_type.template <- {
  typeName = "" //Generic from type.
  checkOrder = presenceCheckOrder.IDLE
  locId = ""
  isMatch = @() false
  getParams = function() {
    local params = { presenceId = typeName }
    updateParams(params)
    return params
  }
  updateParams = @(params) params
  getLocText = @(presenceParams) ::loc(locId)
}

::g_enum_utils.addTypesByGlobalName("g_presence_type", {
  IDLE = {
    checkOrder = presenceCheckOrder.IDLE
    locId = "status/idle"
    isMatch = @() true
  }

  IN_QUEUE = {
    checkOrder = presenceCheckOrder.IN_QUEUE
    locId = "status/in_queue"
    queueTypeMask = QUEUE_TYPE_BIT.EVENT | QUEUE_TYPE_BIT.DOMINATION | QUEUE_TYPE_BIT.NEWBIE
    isMatch = @() ::queues.isAnyQueuesActive(queueTypeMask)
    updateParams = function(params) {
      local queue = ::queues.getActiveQueueWithType(queueTypeMask)
      params.eventName <- ::events.getEventEconomicName(::queues.getQueueEvent(queue))
      params.country <- ::queues.getQueueCountry(queue)
    }
    getLocText = @(presenceParams) ::loc(locId, {
      gameMode = ::events.getNameByEconomicName(presenceParams?.eventName ?? "")
      country = ::loc(presenceParams?.country ?? "")
    })
  }

  IN_GAME = {
    checkOrder = presenceCheckOrder.IN_GAME
    locId = "status/in_game"
    isMatch = @() ((::is_in_flight() && !::g_mis_custom_state.getCurMissionRules().isWorldWar)
                    || ::SessionLobby.isInRoom())
    updateParams = function(params) {
      params.gameMod <- get_game_mode()
      params.eventName <- ::events.getEventEconomicName(::SessionLobby.getRoomEvent())
      params.country <- ::get_profile_info().country
    }
    getLocText = function (presenceParams) {
      local eventName = presenceParams?.eventName ?? ""
      return ::loc(locId,
        { gameMode = eventName == "" ? ::get_game_mode_loc_name(presenceParams?.gameMod)
          : ::events.getNameByEconomicName(presenceParams?.eventName)
          country = ::loc(presenceParams?.country ?? "")
        })
    }
  }

  IN_QUEUE_WW = {
    checkOrder = presenceCheckOrder.IN_QUEUE
    locId = "status/in_queue_ww"
    queueTypeMask = QUEUE_TYPE_BIT.WW_BATTLE
    isMatch = @() ::queues.isAnyQueuesActive(queueTypeMask)
    updateParams = function(params) {
      local queue = ::queues.getActiveQueueWithType(queueTypeMask)
      local operationId = ::queues.getQueueOperationId(queue)
      local operation = ::g_ww_global_status.getOperationById(operationId)
      if (!operation)
        return
      params.operationId <- operationId
      params.mapId <- operation.getMapId()
      params.country <- ::queues.getQueueCountry(queue)
    }
    getLocText = function(presenceParams) {
      local map = ::g_ww_global_status.getMapByName(presenceParams?.mapId)
      return ::loc(locId,
        { operationName = map
            ? ::WwOperation.getNameTextByIdAndMapName(presenceParams?.operationId, map.getNameText())
            : ""
          country = ::loc(presenceParams?.country ?? "")
        })
    }
  }

  IN_GAME_WW = {
    checkOrder = presenceCheckOrder.IN_GAME_WW
    locId = "status/in_game_ww"
    isMatch = @() ::is_in_flight() && ::g_mis_custom_state.getCurMissionRules().isWorldWar
    updateParams = function(params) {
      local operationId = ::SessionLobby.getOperationId()
      local operation = ::g_ww_global_status.getOperationById(operationId)
      if (!operation)
        return
      params.operationId <- operationId
      params.mapId <- operation.getMapId()
      params.country <- operation.getMyClanCountry() || ::get_profile_info().country
    }
    getLocText = function(presenceParams) {
      local map = ::g_ww_global_status.getMapByName(presenceParams?.mapId)
      return ::loc(locId,
        { operationName = map
            ? ::WwOperation.getNameTextByIdAndMapName(presenceParams?.operationId ?? "", map.getNameText())
            : ""
          country = ::loc(presenceParams?.country ?? "")
        })
    }
  }
}, null, "typeName")

::g_presence_type.types.sort(@(a, b) a.checkOrder <=> b.checkOrder)

function g_presence_type::getCurrent()
{
  foreach(presenceType in types)
    if (presenceType.isMatch())
      return presenceType
  return IDLE
}

function g_presence_type::getByPresenceParams(presenceParams)
{
  return this?[presenceParams?.presenceId] ?? IDLE
}