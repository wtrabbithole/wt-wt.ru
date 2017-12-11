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
  local unit_class = getWpcostUnitClass(unit)

  local rule = user_blk["restriction_rule"] || "type"

  local can_spawn = false
  switch (rule) {
    case "class":
      can_spawn = (user_blk[unit_class] > 0)
      break
    case "type_and_class":
      can_spawn = (user_blk[unit_type + "_numSpawn"] > 0 && user_blk[unit_class] > 0)
      break
    default:
      can_spawn = (user_blk[unit_type + "_numSpawn"] > 0)
      break
  }

  if (!can_spawn) dagor.debug("Can't spawn: UserId " + userId + ", unit " + unit +  ", unit_type " + unit_type +
                              ", unit_class " + unit_class + ", " + numSpawnsByUnitType_get_dbg_line(user_blk))
  return can_spawn
}

function numSpawnsByUnitType_onPlayerSpawn(userId, team, country, unit, weapon, cost)
{
  local user_blk = ::get_user_custom_state(userId, true)
  local unit_type = get_unit_type_by_unit_name(unit)
  local unit_class = getWpcostUnitClass(unit)

  if (user_blk[unit_type+"_numSpawn"] > 0) user_blk[unit_type+"_numSpawn"]--
  if (user_blk[unit_class] > 0) user_blk[unit_class]--

  dagor.debug("numSpawnsByUnitType_onPlayerSpawn: UserId "+userId+", "+numSpawnsByUnitType_get_dbg_line(user_blk))
}

// ------------- activeUnitsPool BEGIN -------------------
function activeUnitsPool_onSessionStart()
{
  dagor.debug("activeUnitsPool_onSessionStart")
  local gblk = ::get_mission_custom_state(true)
  local mis_blk = get_current_mission_info_cached()
  gblk.setFrom(mis_blk.customRules)
  ::usersList <- {"teamA": [], "teamB": [] }
}

function activeUnitsPool_onPlayerConnected(userId, team, country)
{
  dagor.debug("activeUnitsPool_onPlayerConnected")

  local user_blk = ::get_user_custom_state(userId, true)
  local mis_blk = ::get_mission_custom_state(false)
  local teamName = get_team_name_by_mp_team(team)
  user_blk.setFrom(mis_blk.teams[teamName].limitedUnits)
  if (teamName in usersList) usersList[teamName].push(userId)
  dagor.debug("activeUnitsPool_onPlayerConnected. Push user " + userId + " in usersList " + teamName)
}

function activeUnitsPool_canPlayerSpawn(userId, team, country, unit, weapon, fuel)
{
  local mis_blk = ::get_mission_custom_state(false)
  local teamName = get_team_name_by_mp_team(team)

  if (mis_blk.teams[teamName].limitedUnits[unit] > 0) {
    dagor.debug("activeUnitsPool_canPlayerSpawn. UserId " + userId + " unit " + unit +
                " count = " + mis_blk.teams[teamName].limitedUnits[unit])
    return true
  }
  if (mis_blk.teams[teamName].unlimitedUnits[unit]) {
    dagor.debug("activeUnitsPool_canPlayerSpawn. UserId " + userId + " unit " + unit +
                " is unlimited")
    return true
  }

  dagor.debug("activeUnitsPool_canPlayerSpawn. Can't spawn: UserId " + userId + " unit " + unit +
              " count = " + mis_blk.teams[teamName].limitedUnits[unit] +
              " isUnlimited = " + mis_blk.teams[teamName].unlimitedUnits[unit])
  return false
}

function modCurrentSpawnLimits(team, unit, add)
{
  local mis_blk = ::get_mission_custom_state(true)
  local teamName = get_team_name_by_mp_team(team)

  if (unit in mis_blk.teams[teamName].limitedUnits) {
    local num = mis_blk.teams[teamName].limitedUnits[unit] + add
    mis_blk.teams[teamName].limitedUnits[unit] = num
    dagor.debug("modCurrentSpawnLimits. unit " + unit +
                " count + (" + add + ") = " + mis_blk.teams[teamName].limitedUnits[unit])
    for (local j = 0; j < usersList[teamName].len(); j++) {
      local user_blk = ::get_user_custom_state(usersList[teamName][j], true)
      if (user_blk != null) user_blk.setFrom(mis_blk.teams[teamName].limitedUnits)
    }
  }
}

function activeUnitsPool_onPlayerSpawn(userId, team, country, unit, weapon, cost)
{
  modCurrentSpawnLimits(team, unit, -1)
}

function activeUnitsPool_onDeath(userId, team, country, unit, weapon, nw, na, dmg)
{
  modCurrentSpawnLimits(team, unit, 1)
}

function activeUnitsPool_get_unit_spawn_delay(modeInfo, unit, minRank, maxRank)
{
  local mis_blk = ::get_mission_custom_state(false)
  local delay = 0.0
  if (!(unit in mis_blk.teams["teamA"].unlimitedUnits) && !(unit in mis_blk.teams["teamB"].unlimitedUnits)
      && mis_blk.spawnDelayAfterDeath) delay = mis_blk.spawnDelayAfterDeath
  return { spawnDelay = 0.0 , spawnDelayAfterDeath = delay }
}

function activeUnitsPool_onPlayerDisconnected(userId)
{
  dagor.debug("activeUnitsPool_onPlayerDisconnected")
  foreach(teamName, team in usersList) {
    local usedIdx = team.find(userId)
    if (usedIdx >= 0) {
      team.remove(usedIdx)
      dagor.debug("activeUnitsPool_onPlayerDisconnected. user " + userId + " is removed from usersList " + teamName)
    }
  }
}