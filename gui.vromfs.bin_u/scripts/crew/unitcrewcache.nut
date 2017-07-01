//
// Unit crew data cache.
// Used to speed up 'get_aircraft_crew_by_id' calls.
//

::g_unit_crew_cache <- {
  lastUnitCrewData = null
  lastUnitCrewId = -1
}

function g_unit_crew_cache::getUnitCrewDataById(crewId)
{
  if (crewId != lastUnitCrewId)
  {
    lastUnitCrewId = crewId
    local unitCrewBlk = ::get_aircraft_crew_by_id(lastUnitCrewId)
    lastUnitCrewData = ::buildTableFromBlk(unitCrewBlk)
  }
  return lastUnitCrewData
}

function g_unit_crew_cache::initCache()
{
  ::add_event_listener("CrewSkillsChanged", onEventCrewSkillsChanged,
    this, ::g_listener_priority.UNIT_CREW_CACHE_UPDATE)
  ::add_event_listener("CrewChanged", onEventCrewChanged,
    this, ::g_listener_priority.UNIT_CREW_CACHE_UPDATE)
}

function g_unit_crew_cache::onEventCrewSkillsChanged(params)
{
  lastUnitCrewId = -1
}

function g_unit_crew_cache::onEventCrewChanged(params)
{
  lastUnitCrewId = -1
}

::g_unit_crew_cache.initCache()
