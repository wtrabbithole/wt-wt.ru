//
// Unit crew data cache.
// Used to speed up 'get_aircraft_crew_by_id' calls.
//

::g_unit_crew_cache <- {
  lastUnitCrewData = null
  lastUnitCrewId = -1
}

g_unit_crew_cache.getUnitCrewDataById <- function getUnitCrewDataById(crewId)
{
  if (crewId != lastUnitCrewId)
  {
    lastUnitCrewId = crewId
    local unitCrewBlk = ::get_aircraft_crew_by_id(lastUnitCrewId)
    lastUnitCrewData = ::buildTableFromBlk(unitCrewBlk)
  }
  return lastUnitCrewData
}

g_unit_crew_cache.initCache <- function initCache()
{
  ::add_event_listener("CrewSkillsChanged", onEventCrewSkillsChanged,
    this, ::g_listener_priority.UNIT_CREW_CACHE_UPDATE)
  ::add_event_listener("CrewChanged", onEventCrewChanged,
    this, ::g_listener_priority.UNIT_CREW_CACHE_UPDATE)
}

g_unit_crew_cache.onEventCrewSkillsChanged <- function onEventCrewSkillsChanged(params)
{
  lastUnitCrewId = -1
}

g_unit_crew_cache.onEventCrewChanged <- function onEventCrewChanged(params)
{
  lastUnitCrewId = -1
}

::g_unit_crew_cache.initCache()
