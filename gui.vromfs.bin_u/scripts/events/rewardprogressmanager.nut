/**
 * Caches data from leaderbord to provide allways
 * actual values of reward progress.
 *
 * Usege:
 * Jast call getProgress function and it will provide actual value
 * getProgress(event, field, callback, context = null)
 *   @event    - tournament event
 *   @field    - name of leaderbord fild you want to get
 *   @callback - callback function, which recives
 *               a value as an argument (null if there is no value)
 *   @contest  - scope for callback execution
 */
::g_reward_progress_manager <- {
  __cache = {}

  function getProgress(event, field, callback, context = null)
  {
    local cb = ::Callback(callback, context)
    local eventEconomicName = ::events.getEventEconomicName(event)

    //Try to get from cache
    if (eventEconomicName in __cache && __cache[eventEconomicName])
      return cb(::getTblValue(field, __cache[eventEconomicName]))

    //Try to get from userlog
    if (fetchRowFromUserlog(event))
      return cb(::getTblValue(field, __cache[eventEconomicName]))

    //Try to get from leaderbords
    local request = ::events.getMainLbRequest(event)
    if (request.forClans)
      request.tournament_mode = GAME_EVENT_TYPE.TM_ELO_GROUP_DETAIL

    ::events.getSelfRow(request, (@(__cache, cb, event, field, callback, eventEconomicName) function (selfRow) {
      if (!selfRow.len())
        return cb(null)

      __cache[eventEconomicName] <- selfRow[0]
      if (field in selfRow[0])
        callback(selfRow[0][field])
      else
      {
        local msgToSend = ::format("Error: no field '%s' in leaderbords for event '%s' , economic name '%s'",
                                   field, event.name, eventEconomicName)
        ::dagor.debug(msgToSend)
      }
    })(__cache, cb, event, field, callback, eventEconomicName))
  }

  function onEventEventBattleEnded(params)
  {
    local event = ::events.getEvent(::getTblValue("eventId", params))
    if (event)
      fetchRowFromUserlog(event)
  }

  function fetchRowFromUserlog(event)
  {
    local userLogs = ::getUserLogsList({
      show = [
        ::EULT_SESSION_RESULT
      ]
    })

    foreach (log in userLogs)
    {
      local eventEconomicName = ::events.getEventEconomicName(event)
      if (::getTblValue("eventId", log) != eventEconomicName)
        continue

      local leaderbordRow = ::getTblValueByPath("newStat.tournamentResult", log)
      if (!leaderbordRow)
        return false

      __cache[eventEconomicName] <- leaderbordRow
      return true
    }
  }
}

::add_event_listener("EventBattleEnded", ::g_reward_progress_manager.onEventEventBattleEnded, ::g_reward_progress_manager)
