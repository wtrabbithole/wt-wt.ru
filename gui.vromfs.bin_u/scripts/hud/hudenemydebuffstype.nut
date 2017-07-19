::g_hud_enemy_debuffs <- {
  types = []
  cache = {
    byId = {}
  }
}

// ----------------------------------------------------------------------------------------------

local countPartsAlive = function(partsArray, partsCfg)
{
  local count = 0
  foreach (partId in partsArray)
  {
    local dmParts = ::get_tbl_value_by_path_array([ partId, "dmParts" ], partsCfg, {})
    foreach (dmPart in dmParts)
      if (dmPart._hp > 0)
        count++
  }
  return count
}

// ----------------------------------------------------------------------------------------------

::g_hud_enemy_debuffs.template <- {
  id = "" // filled by type name
  unitTypesMask = 0
  parts         = []
  isUpdateOnKnownPartKillsOnly = true
  getLabel      = @(camInfo, unitInfo, partName = null, dmgParams = null) ""
}

::g_enum_utils.addTypesByGlobalName("g_hud_enemy_debuffs", {
  UNKNOWN = {
  }

  SHIP_BUOYANCY = {
    unitTypesMask = ::g_unit_type.SHIP.bit
    getLabel  = function(camInfo, unitInfo, partName = null, dmgParams = null)
    {
      local value = ::getTblValue("buoyancy", camInfo, 0.0)
      local color = value == 1.0 ? "commonTextColor" : "activeTextColor"
      return ::colorize(color, ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(value))
    }
  }

  SHIP_COMPARTMENTS = {
    unitTypesMask = ::g_unit_type.SHIP.bit
    parts     = [ "ship_compartment" ]
    getLabel  = function(camInfo, unitInfo, partName = null, dmgParams = null)
    {
      local total = ::getTblValue("compartmentsTotal", camInfo, 0)
      if (!total)
        return ""
      local alive = unitInfo.isKilled ? 0
        : dmgParams ? countPartsAlive(parts, unitInfo.parts)
        : ::getTblValue("compartmentsAlive", camInfo, 0)
      local aliveMin = ::getTblValue("compartmentsAliveMin", camInfo, 0)

      local value = ::clamp((alive - aliveMin + 1) * 1.0 / (total - aliveMin + 1), 0.0, 1.0)
      local color = alive <= aliveMin ? "badTextColor"
        : value == 1.0 ? "commonTextColor"
        : "activeTextColor"
      return ::colorize(color, ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(value))
    }
  }

  SHIP_CREW = {
    unitTypesMask = ::g_unit_type.SHIP.bit
    isUpdateOnKnownPartKillsOnly = false
    getLabel  = function(camInfo, unitInfo, partName = null, dmgParams = null)
    {
      local total = ::getTblValue("crewTotal", camInfo, 0)
      if (!total)
        return ""
      local alive = unitInfo.isKilled ? 0
        : dmgParams ? ::getTblValue("crewAliveCount", dmgParams, 0)
        : ::getTblValue("crewAlive", camInfo, 0)
      local aliveMin = ::getTblValue("crewAliveMin", camInfo, 0)

      local value = ::clamp((alive - aliveMin + 1) * 1.0 / (total - aliveMin + 1), 0.0, 1.0)
      local color = alive <= aliveMin ? "badTextColor"
        : value == 1.0 ? "commonTextColor"
        : "activeTextColor"
      return ::colorize(color, ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(value))
    }
  }
}, null, "id")

function g_hud_enemy_debuffs::getTypeById(id)
{
  return ::g_enum_utils.getCachedType("id", id, cache.byId, this, UNKNOWN)
}

function g_hud_enemy_debuffs::getTypesArrayByUnitType(unitType)
{
  local unitTypeBit = ::g_unit_type.getByEsUnitType(unitType).bit
  local list = []
  foreach (item in types)
    if (unitTypeBit & item.unitTypesMask)
      list.append(item)
  return list
}

function g_hud_enemy_debuffs::getTrackedPartNamesByUnitType(unitType)
{
  local unitTypeBit = ::g_unit_type.getByEsUnitType(unitType).bit
  local list = []
  foreach (item in types)
    if (unitTypeBit & item.unitTypesMask)
      foreach (partName in item.parts)
        ::append_once(partName, list)
  return list
}
