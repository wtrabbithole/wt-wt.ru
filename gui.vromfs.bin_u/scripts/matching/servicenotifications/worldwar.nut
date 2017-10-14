foreach (notificationName, callback in
  {
    ["worldwar.on_join_to_battle"] = function(params)
      {
        local operationId = ::getTblValue("operationId", params, "")
        local battleIds = ::getTblValue("battleIds", params, [])
        foreach (battleId in battleIds)
        {
          local queue = ::queues.createQueue({
              operationId = operationId
              battleId = battleId
            }, true)
          ::queues.afterJoinQueue(queue)
        }
      },
    ["worldwar.on_leave_from_battle"] = function(params)
      {
        local queue = ::queues.findQueueByName(::queue_classes.WwBattle.getName(params))
        if (queue)
          ::queues.afterLeaveQueue(queue, null)
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