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
        ::g_squad_manager.cancelWwBattlePrepare()
      },
    ["worldwar.on_leave_from_battle"] = function(params)
      {
        local queue = ::queues.findQueueByName(::queue_classes.WwBattle.getName(params))
        if (!queue)
          return

        local reason = params?.reason ?? ""
        local isBattleStarted = reason == "battle-started"
        local msgText = !isBattleStarted
          ? ::loc("worldWar/leaveBattle/" + reason, "")
          : ""

        ::queues.afterLeaveQueue(queue, msgText.len() ? msgText : null)
        if (isBattleStarted)
          ::SessionLobby.setWaitForQueueRoom(true)
      },
    ["worldwar.notify"] = function(params)
      {
        local messageType = ::getTblValue("type", params)
        if (!messageType)
          return

        if (messageType == "operation_finished")
        {
          local operationId = ::g_world_war.lastPlayedOperationId
          local operation = ::g_ww_global_status.getOperationById(operationId)
          local text = operation
            ? ::loc("worldwar/operation_complete_battle_results_ignored_full_text",
              {operationInfo = operation.getNameText()})
            : ::loc("worldwar/operation_complete_battle_results_ignored")
          ::chat_system_message(text)
        }
        else (messageType == "wwNotification")
          ::ww_process_server_notification(params)
      }
  })
  ::matching_rpc_subscribe(notificationName, callback)


foreach (notificationName, callback in
  {
    ["worldwar_forced_subscribe"] = function(params)
      {
        local operationId = params?.id
        if (!operationId)
          return

        if (params?.subscribe ?? false)
          ::ww_service.subscribeOperation(operationId)
        else
          ::ww_service.unsubscribeOperation(operationId)
      }
  })
  ::web_rpc.register_handler(notificationName, callback)
