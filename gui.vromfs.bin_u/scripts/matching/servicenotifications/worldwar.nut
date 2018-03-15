foreach (notificationName, callback in
  {
    ["worldwar.on_join_to_battle"] = function(params)
      {
        local operationId = params?.operationId ?? ""
        local team = params?.team ?? ::SIDE_1
        local country = params?.country ?? ""
        local battleIds = ::getTblValue("battleIds", params, [])
        foreach (battleId in battleIds)
        {
          local queue = ::queues.createQueue({
              operationId = operationId
              battleId = battleId
              country = country
              team = team
            }, true)
          ::queues.afterJoinQueue(queue)
        }
      },
    ["worldwar.on_leave_from_battle"] = function(params)
      {
        local queue = ::queues.findQueueByName(::queue_classes.WwBattle.getName(params))
        if (queue)
        {
          local reason = params?.reason
          local msg = reason ? ::loc("worldWar/leaveBattle/" + reason, "") : ""
          ::queues.afterLeaveQueue(queue, msg.len() ? msg : null)
        }
      },
    ["worldwar.notify"] = function(params)
      {
        local messageType = ::getTblValue("type", params)
        if (!messageType)
          return

        if (messageType == "operation_finished")
          ::chat_system_message(::loc("worldwar/operation_complete_battle_results_ignored"))
        else (messageType == "wwNotification")
          ::ww_process_server_notification(params)
      }
  }
)
::matching_rpc_subscribe(notificationName, callback)