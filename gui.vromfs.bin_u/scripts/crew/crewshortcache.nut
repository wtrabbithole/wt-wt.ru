/*
 Short tie cache for current viewing crew with selected unit
 saved only for one crew,
 Reset on:
   * save data for another crew
   * crew skills change
   * crew new skills change
   * crew unit change
*/

::g_crew_short_cache <- {
  cache = {}
  cacheCrewid = -1
  cacheUnitName = ""
}

function g_crew_short_cache::resetCache(newCrewId)
{
  cache.clear()
  cacheCrewid = newCrewId
  local crewUnit = ::g_crew.getCrewUnit(::get_crew_by_id(cacheCrewid))
  cacheUnitName = ::getTblValue("name", crewUnit, "")
}

function g_crew_short_cache::getData(crewId, cacheUid)
{
  if (crewId != cacheCrewid)
    return null
  return ::getTblValue(cacheUid, cache)
}

function g_crew_short_cache::setData(crewId, cacheUid, data)
{
  if (crewId != cacheCrewid)
    resetCache(crewId)
  cache[cacheUid] <- data
}

function g_crew_short_cache::onEventCrewSkillsChanged(params)
{
  resetCache(cacheCrewid)
}

function g_crew_short_cache::onEventCrewNewSkillsChanged(params)
{
  resetCache(cacheCrewid)
}

function g_crew_short_cache::onEventCrewTakeUnit(params)
{
  resetCache(cacheCrewid)
}

function g_crew_short_cache::onEventQualificationIncreased(params)
{
  resetCache(cacheCrewid)
}

function g_crew_short_cache::onEventCrewSkillsReloaded(params)
{
  resetCache(cacheCrewid)
}

::subscribe_handler(::g_crew_short_cache, ::g_listener_priority.UNIT_CREW_CACHE_UPDATE)