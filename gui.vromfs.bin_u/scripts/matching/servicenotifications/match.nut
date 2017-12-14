local platform = require("scripts/clientState/platform.nut")

function notify_clusters_changed(params)
{
  dagor.debug("notify_clusters_changed")
  ::g_clusters.onClustersChanged(params)
}

function notify_game_modes_changed(params)
{
  if (!::is_connected_to_matching())
    return

  if (::is_in_flight()) // do not handle while session is active
  {
    notify_game_modes_changed_rnd_delay(params)
    return
  }

  dagor.debug("notify_game_modes_changed")
  g_matching_game_modes.onGameModesChangedNotify(getTblValue("added", params, null),
                                                 getTblValue("removed", params, null),
                                                 getTblValue("changed", params, null))
}

function notify_game_modes_changed_rnd_delay(params)
{
  local maxFetchDelaySec = 60
  local rndDelaySec = ::math.rnd() % maxFetchDelaySec
  dagor.debug("notify_game_modes_changed_rnd_delay " + rndDelaySec)
  g_delayed_actions.add((@(params) function() { notify_game_modes_changed(params) })(params),
                        rndDelaySec * 1000)
}

function on_queue_info_updated(params)
{
  ::broadcastEvent("QueueInfoRecived", {queue_info = params})
}

function notify_queue_join(params)
{
  local queue = ::queues.createQueue(params)
  ::queues.afterJoinQueue(queue)
}

function notify_queue_leave(params)
{
  ::queues.afterLeaveQueues(params)
}

function fetch_clusters_list(params, cb)
{
  matching_api_func("match.fetch_clusters_list", cb, params)
}

function fetch_game_modes_info(params, cb)
{
  matching_api_func("match.fetch_game_modes_info", cb, params)
}

function fetch_game_modes_digest(params, cb)
{
  matching_api_func("match.fetch_game_modes_digest", cb, params)
}

function leave_session_queue(params, cb)
{
  matching_api_func("match.leave_queue", cb, params)
}

function enqueue_in_session(params, cb)
{
  local missionName = get_forced_network_mission()
  if (missionName.len() > 0)
    params["forced_network_mission"] <- missionName

  if (!platform.isCrossPlayEnabled())
    params["xbox_xplay"] <- false

  matching_api_func("match.enqueue", cb, params)
}

foreach (notificationName, callback in
          {
            ["match.notify_clusters_changed"] = notify_clusters_changed,

            ["match.notify_game_modes_changed"] = notify_game_modes_changed_rnd_delay,

            ["match.update_queue_info"] = on_queue_info_updated,

            ["match.notify_queue_join"] = notify_queue_join,

            ["match.notify_queue_leave"] = notify_queue_leave
          }
        )
  ::matching_rpc_subscribe(notificationName, callback)
