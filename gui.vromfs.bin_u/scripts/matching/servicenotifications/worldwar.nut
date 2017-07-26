foreach (notificationName, callback in
          {
            ["worldwar.on_leave_from_battle"] = function(params)
              {
                local battleId = ::getTblValue("battleId", params, "").tostring()
                local operationId = ::getTblValue("operationId", params, "").tostring()

                local queue = ::queues.findQueueByName(operationId + "_" + battleId)
                if (queue == null)
                  return

                ::queues.getOnLeaveQueueSuccessCallback(queue, null)
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