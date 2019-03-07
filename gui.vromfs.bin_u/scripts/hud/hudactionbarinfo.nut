local cachedUnitId = ""
local cache = {}

local cacheActionDescs = function(unitId) {
  local unit = ::getAircraftByName(unitId)
  local ediff = ::get_mission_difficulty_int()
  cachedUnitId = unitId
  cache.clear()
  if (unit.esUnitType == ::ES_UNIT_TYPE_SHIP)
    foreach (triggerGroup in [ "torpedoes", "bombs", "rockets" ])
      cache[triggerGroup] <- ::getWeaponDescTextByTriggerGroup(triggerGroup, unit, ediff)
}

local getActionDesc = function(unitId, triggerGroup) {
  if (unitId != cachedUnitId)
    cacheActionDescs(unitId)
  return cache?[triggerGroup] ?? ""
}

return {
  cacheActionDescs = cacheActionDescs
  getActionDesc = getActionDesc
}
