function numSpawnsByUnitType_onPlayerConnected(userId, team, country)
{
  dagor.debug("numSpawnsByUnitType_onPlayerConnected")

  local user_blk = ::get_user_custom_state(userId, true)
  local mis = get_current_mission_info_cached()
  user_blk.setFrom(mis.customRules.ruleSet)
}

function numSpawnsByUnitType_get_dbg_line(user_blk)
{
  local debug_string = ""

  for(local i=0; i<user_blk.paramCount(); i++)
  {
    if (debug_string != "")
      debug_string += ", "

    debug_string += user_blk.getParamName(i)+" "+user_blk.getParamValue(i)
  }

  return debug_string
}

function numSpawnsByUnitType_canPlayerSpawn(userId, team, country, unit, weapon, fuel)
{
  local user_blk = ::get_user_custom_state(userId, false)
  local unit_type = get_unit_type_by_unit_name(unit)

  if (user_blk[unit_type+"_numSpawn"] > 0)
    return true

  dagor.debug("Can't spawn: UserId "+userId+", unit "+unit+", unit_type "+unit_type+", "+numSpawnsByUnitType_get_dbg_line(user_blk))
  return false
}

function numSpawnsByUnitType_onPlayerSpawn(userId, team, country, unit, weapon, cost)
{
  local user_blk = ::get_user_custom_state(userId, true)
  local unit_type = get_unit_type_by_unit_name(unit)

  if (user_blk[unit_type+"_numSpawn"] > 0)
    user_blk[unit_type+"_numSpawn"]--

  dagor.debug("numSpawnsByUnitType_onPlayerSpawn: UserId "+userId+", "+numSpawnsByUnitType_get_dbg_line(user_blk))
}