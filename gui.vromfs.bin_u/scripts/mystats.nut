local seenTitles = ::require("scripts/seen/seenList.nut").get(SEEN.TITLES)

/*
my_stats API
   getStats()  - return stats or null if stats not recived yet, and request stats update when needed.
                 broadcast event "MyStatsUpdated" after result receive.
   markStatsReset() - mark stats to reset to update it with the next request.
   isStatsLoaded()

   isMeNewbie()   - bool, count is player newbie depends n stats
   isNewbieEventId(eventId) - bool  - is event in newbie events list in config
*/

local summaryNameArray = [
  "pvp_played"
  "skirmish_played"
  "dynamic_played"
  "campaign_played"
  "builder_played"
  "other_played"
  "single_played"
]

::my_stats <-{
  updateDelay = 3600000 //once per 1 hour, we have force update after each battle or debriefing.

  _my_stats = null
  _last_update = -10000000
  _is_in_update = false
  _resetStats = false

  _newPlayersBattles = {}

  newbie = false
  newbieNextEvent = {}
  _needRecountNewbie = true
  _unitTypeByNewbieEventId = {}
  _maxUnitsUsedRank = null

  function getStats()
  {
    updateMyPublicStatsData()
    return _my_stats
  }

  function getTitles(showHidden = false)
  {
    local titles = ::getTblValue("titles", _my_stats, [])
    if (showHidden)
      return titles

    for (local i = titles.len() - 1; i >= 0 ; i--)
    {
      local titleUnlock = ::g_unlocks.getUnlockById(titles[i])
      if (!titleUnlock || titleUnlock.hidden)
        titles.remove(i)
    }

    return titles
  }

  function updateMyPublicStatsData()
  {
    if (!::g_login.isLoggedIn())
      return
    local time = ::dagor.getCurTime()
    if (_is_in_update && time - _last_update < 45000)
      return
    if (!_resetStats && _my_stats && time - _last_update < updateDelay) //once per 15min
      return

    _is_in_update = true
    _last_update = time
    ::add_bg_task_cb(::req_player_public_statinfo(::my_user_id_str),
                     function () {
                       _is_in_update = false
                       _resetStats = false
                       _needRecountNewbie = true
                       _update_my_stats()
                     }.bindenv(this))
  }

  function _update_my_stats()
  {
    local blk = ::DataBlock()
    ::get_player_public_stats(blk)

    if (!blk)
      return

    _my_stats = ::get_player_stats_from_blk(blk)

    seenTitles.onListChanged()
    ::broadcastEvent("MyStatsUpdated")
  }

  function isStatsLoaded()
  {
    return _my_stats != null
  }

  function clearStats()
  {
    _my_stats = null
  }

  function markStatsReset()
  {
    _resetStats = true
  }

  function onEventUnitBought(p)
  {
    //need update bought units list
    markStatsReset()
  }

  function onEventAllModificationsPurchased(p)
  {
    markStatsReset()
  }

  //newbie stats
  function onEventInitConfigs(p)
  {
    local settingsBlk = ::get_game_settings_blk()
    local blk = settingsBlk && settingsBlk.newPlayersBattles
    if (!blk)
      return

    foreach (unitType in ::g_unit_type.types)
    {
      local data = {
        minKills = 0
        battles = []
      }
      local list = blk % unitType.lowerName
      foreach(ev in list)
      {
        _unitTypeByNewbieEventId[ev.event] <- unitType.esUnitType
        if (!ev.event)
          continue

        data.battles.append({
          event       = ev.event
          kills       = ev.kills || 1
          timePlayed  = ev?.timePlayed || 0
          unitRank    = ev.unitRank || 0
        })
        data.minKills = ::max(data.minKills, ev.kills)
      }
      if (data.minKills)
        _newPlayersBattles[unitType.esUnitType] <- data
    }
  }

  function onEventScriptsReloaded(p)
  {
    onEventInitConfigs(p)
  }

  function checkRecountNewbie()
  {
    local statsLoaded = isStatsLoaded()  //when change newbie recount, dont forget about check stats loaded for newbie tutor
    if (!_needRecountNewbie || !statsLoaded)
    {
      if (!statsLoaded || newbie)
        updateMyPublicStatsData()
      return
    }
    _needRecountNewbie = false

    newbie = __isNewbie()
    newbieNextEvent.clear()
    foreach(unitType, config in _newPlayersBattles)
    {
      local event = null
      local kills = getKillsOnUnitType(unitType)
      local timePlayed = getTimePlayedOnUnitType(unitType)
      foreach(evData in config.battles)
      {
        if (kills >= evData.kills)
          continue
        if (timePlayed >= evData.timePlayed)
          continue
        if (evData.unitRank && checkUnitInSlot(evData.unitRank, unitType))
          continue
        event = ::events.getEvent(evData.event)
        if (event)
          break
      }
      if (event)
        newbieNextEvent[unitType] <- event
    }
  }

  function checkUnitInSlot(requiredUnitRank, unitType)
  {
    if (_maxUnitsUsedRank == null)
      _maxUnitsUsedRank = calculateMaxUnitsUsedRanks()

    if (requiredUnitRank <= ::getTblValue(unitType.tostring(), _maxUnitsUsedRank, 0))
      return true

    return false
  }

  /**
   * Checks am i newbie, looking to my stats.
   *
   * Internal usage only. If there is no stats
   * result will be unconsistent.
   */
  function __isNewbie()
  {
    foreach (unitType in ::g_unit_type.types)
    {
      local newbieProgress = ::getTblValue(unitType.esUnitType, _newPlayersBattles)
      local killsReq = (newbieProgress && newbieProgress.minKills) || 0
      local kills = getKillsOnUnitType(unitType.esUnitType)
      if (kills >= killsReq)
        return false
    }
    return true
  }

  function onEventEventsDataUpdated(params)
  {
    _needRecountNewbie = true
  }

  function onEventCrewTakeUnit(params)
  {
    local unitType = ::get_es_unit_type(params.unit)
    local unitRank = ::getUnitRank(params.unit)
    local lastMaxRank = ::getTblValue(unitType.tostring(), _maxUnitsUsedRank, 0)
    if (lastMaxRank >= unitRank)
      return

    if (_maxUnitsUsedRank == null)
      _maxUnitsUsedRank = calculateMaxUnitsUsedRanks()

    _maxUnitsUsedRank[unitType.tostring()] = unitRank
    ::saveLocalByAccount("tutor/newbieBattles/unitsRank", _maxUnitsUsedRank)
    _needRecountNewbie = true
  }

  /**
   * Returns summ of specified fields in players statistic.
   * @summaryName - game mode. Available values:
   *  pvp_played
   *  skirmish_played
   *  dynamic_played
   *  campaign_played
   *  builder_played
   *  other_played
   *  single_played
   * @filter - table config.
   *   {
   *     addArray - array of fields to summ
   *     subtractArray - array of fields to subtract
   *     unitType - unit type filter; if not specified - get both
   *   }
   */
  function getSummary(summaryName, filter = {})
  {
    local res = 0
    local pvpSummary = ::getTblValue(summaryName, ::getTblValue("summary", _my_stats))
    if (!pvpSummary)
      return res

    local roles = ::u.map(::g_unit_class_type.getTypesByEsUnitType(filter?.unitType),
       function (type) { return type.expClassName })

    foreach(idx, diffData in pvpSummary)
      foreach(unitRole, data in diffData)
      {
        if (!::isInArray(unitRole, roles))
          continue

        foreach(param in ::getTblValue("addArray", filter, []))
          res += ::getTblValue(param, data, 0)
        foreach(param in ::getTblValue("subtractArray", filter, []))
          res -= ::getTblValue(param, data, 0)
      }
    return res
  }

  function getPvpRespawns()
  {
    return getSummary("pvp_played", {addArray = ["respawns"]})
  }

  function getKillsOnUnitType(unitType)
  {
    return getSummary("pvp_played", {
                                      addArray = ["air_kills", "ground_kills", "naval_kills"],
                                      subtractArray = ["air_kills_ai", "ground_kills_ai", "naval_kills_ai"]
                                      unitType = unitType
                                    })
  }

  function getTimePlayedOnUnitType(unitType)
  {
    return getSummary("pvp_played", {
                                      addArray = ["timePlayed"]
                                      unitType = unitType
                                    })
  }

  function getClassFlags(unitType)
  {
    if (unitType == ::ES_UNIT_TYPE_AIRCRAFT)
      return ::CLASS_FLAGS_AIRCRAFT
    if (unitType == ::ES_UNIT_TYPE_TANK)
      return ::CLASS_FLAGS_TANK
    if (unitType == ::ES_UNIT_TYPE_SHIP)
      return ::CLASS_FLAGS_SHIP
    if (unitType == ::ES_UNIT_TYPE_HELICOPTER)
      return ::CLASS_FLAGS_HELICOPTER
    return (1 << ::EUCT_TOTAL) - 1
  }

  function getSummaryFromProfile(func, unitType = null, diff = null, mode = 1 /*domination*/)
  {
    local res = 0.0
    local classFlags = getClassFlags(unitType)
    for(local i = 0; i < ::EUCT_TOTAL; i++)
      if (classFlags & (1 << i))
      {
        if (diff != null)
          res += func(diff, i, mode)
        else
          for(local d = 0; d < 3; d++)
            res += func(d, i, mode)
      }
    return res
  }

  function getTimePlayed(unitType = null, diff = null)
  {
    return getSummaryFromProfile(stat_get_value_time_played, unitType, diff)
  }

  function isMeNewbie() //used in code
  {
    checkRecountNewbie()
    return newbie
  }

  function getNextNewbieEvent(country = null, unitType = null, checkSlotbar = true) //return null when no newbie event
  {
    checkRecountNewbie()
    if (!country)
      country = ::get_profile_country_sq()

    if (unitType == null)
    {
      unitType = ::get_first_chosen_unit_type(::ES_UNIT_TYPE_AIRCRAFT)
      if (checkSlotbar)
      {
        local unitTypes = getSlotbarUnitTypes(country)
        if (unitTypes.len() && !::isInArray(unitType, unitTypes))
          unitType = unitTypes[0]
      }
    }
    return ::getTblValue(unitType, newbieNextEvent)
  }

  function isNewbieEventId(eventName)
  {
    foreach(config in _newPlayersBattles)
      foreach(evData in config.battles)
        if (eventName == evData.event)
          return true
    return false
  }

  function getUnitTypeByNewbieEventId(eventId)
  {
    return ::getTblValue(eventId, _unitTypeByNewbieEventId, ::ES_UNIT_TYPE_INVALID)
  }

  function calculateMaxUnitsUsedRanks()
  {
    local needRecalculate = false
    local loadedBlk = ::loadLocalByAccount("tutor/newbieBattles/unitsRank", ::DataBlock())
    foreach (unitType in ::g_unit_type.types)
      if (unitType.isAvailable()
        && (loadedBlk[unitType.esUnitType.tostring()] ?? 0) < ::max_country_rank)
      {
        needRecalculate = true
        break
      }

    if (!needRecalculate)
      return loadedBlk

    local saveBlk = ::DataBlock()
    saveBlk.setFrom(loadedBlk)
    local countryCrewsList = ::g_crews_list.get()
    foreach(countryCrews in countryCrewsList)
      foreach (crew in ::getTblValue("crews", countryCrews, []))
      {
        local unit = ::g_crew.getCrewUnit(crew)
        if (unit == null)
          continue

        local curUnitType = ::get_es_unit_type(unit)
        saveBlk[curUnitType.tostring()] = ::max(::getTblValue(curUnitType.tostring(), saveBlk, 0), ::getUnitRank(unit))
      }

    if (!::u.isEqual(saveBlk, loadedBlk))
      ::saveLocalByAccount("tutor/newbieBattles/unitsRank", saveBlk)

    return saveBlk
  }

  function getMissionsComplete()
  {
    local res = 0
    local myStats = getStats()
    foreach (summaryName in summaryNameArray)
    {
      local summary = myStats?.summary?[summaryName] ?? {}
      foreach(diffData in summary)
        res += diffData?.missionsComplete ?? 0
    }
    return res
  }
}

seenTitles.setListGetter(@() ::my_stats.getTitles())

::subscribe_handler(::my_stats, ::g_listener_priority.DEFAULT_HANDLER)

function is_me_newbie() //used in code
{
  return ::my_stats.isMeNewbie()
}
