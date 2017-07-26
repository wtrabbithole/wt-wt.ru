::g_queue_utils <- {}

function g_queue_utils::getQueryParams(queue, needPlayers, params = null)
{
  if (::u.isEmpty(queue))
    return {}

  local qp = {
    mode = ::queues.getQueueMode(queue)
    clusters = ::queues.getQueueClusters(queue)
    team = ::queues.getQueueTeam(queue)
    msquad = ::getTblValue("msquad", queue, false)
  }
  if (!needPlayers)
    return qp

  qp.players <- {
    [::my_user_id_str] = {
      country = ::queues.getQueueCountry(queue)
      slots = ::queues.getQueueSlots(queue)
    }
  }
  if ("members" in queue.params && queue.params.members)
    foreach(uid, m in queue.params.members)
    {
      qp.players[uid] <- {
        country = ("country" in m)? m.country : ::queues.getQueueCountry(queue)
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