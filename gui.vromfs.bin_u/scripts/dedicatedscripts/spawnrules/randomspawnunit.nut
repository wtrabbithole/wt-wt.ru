
// ------------- randomSpawnUnit BEGIN -------------------

function randomSpawnUnit_onSessionStart()
{
  dagor.debug("randomSpawnUnit_onSessionStart")
  local gblk = ::get_mission_custom_state(true)
  local mis_blk = get_current_mission_info_cached()
  gblk.setFrom(mis_blk.customRules)
  ::multiRespawn <- mis_blk.multiRespawn || false
  ::random_unit_spawnscore_tbl <- {}
}

function randomSpawnUnit_onPlayerConnected(userId, team, country)
{
  generateRandomUnitList(userId)
  setRandomUnits(userId)
}

function randomSpawnUnit_canPlayerSpawn(userId, team, country, unit, weapon, fuel)
{
  local user_blk = ::get_user_custom_state(userId, false)
  if (isRandomUnitsNull(userId, user_blk, "randomSpawnUnit_canPlayerSpawn")) return false
  foreach (unitType, unitList in user_blk["random_units"]) {
    if (unit in unitList) {
      dagor.debug("randomSpawnUnit_canPlayerSpawn. userId " + userId + ": unit " + unit +
                  " in unitList (" + unitType + ") with status " + unitList[unit])
      return unitList[unit]
    }
  }
  return true
}

function randomSpawnUnit_onDeath(userId, team, country, unit, weapon, nw, na, dmg)
{
  local mis_blk = ::get_mission_custom_state(false)
  local user_blk = ::get_user_custom_state(userId, true)
  if (isRandomUnitsNull(userId, user_blk, "randomSpawnUnit_onDeath")) return
  local isRandomUnitInList = false
  local randomUnitType = ""

  foreach (unitType, unitList in user_blk["random_units"]) {
    if (unit in unitList) {
      isRandomUnitInList = true
      randomUnitType = unitType
      if (multiRespawn) unitList.setBool(unit, false)
      else unitList.removeParam(unit)
      break
    }
  }

  if (isRandomUnitInList) {
    local randomUnitCostMul = mis_blk.randomUnitCostMul || 1.0
    local wpcost = ::get_wpcost_blk()
    local diff_name = get_econRank_emode_name(get_mission_mode())
    local cost = wpcost[unit]["repairCost"+diff_name]

    local rounded_cost = ((cost * randomUnitCostMul) + 0.5).tointeger()
    local spent = ::spend_repair_cost(userId, unit, rounded_cost)
    if (spent) dagor.debug("randomSpawnUnit_onDeath. spend repair cost for random unit (" + unit +
                           ") = rCost (" + cost + ") * mul (" + randomUnitCostMul + ") = " + rounded_cost)
    else dagor.debug("randomSpawnUnit_onDeath. couldn't spend repair cost for random unit (" + unit + ")")

    if (user_blk["random_units_limit"][randomUnitType] > 0) {
      user_blk["random_units_limit"][randomUnitType] --
      dagor.debug("randomSpawnUnit_onDeath. limit for " + randomUnitType +
                  " decrease to " + user_blk["random_units_limit"][randomUnitType])
      setRandomUnits(userId, randomUnitType)
    }
  }
}

function generateRandomUnitList(userId)
{
  local user_blk = ::get_user_custom_state(userId, true)
  if (user_blk["random_units"]) return
  local mis_blk = ::get_mission_custom_state(false)
  local country = get_es_country(userId)

  if (mis_blk.randomSpawnUnitList && mis_blk.randomSpawnUnitList[country]) {
    copyFromDataBlock(mis_blk.randomSpawnUnitList[country], user_blk)
  }

  local userUnits = ::get_player_matching_info(userId).userUnits
  dagor.debug("randomSpawnUnit. user " + userId + ": units list loaded, count = " + userUnits.len())

  local full_mis_blk = get_current_mission_info_cached()
  local keepOwnUnits = full_mis_blk.editSlotbar?[country]?.keepOwnUnits || false

  local tempUserBlk = DataBlock()

  foreach (unitType, unitList in user_blk["random_units"]) {
    tempUserBlk[unitType] <- unitList
    if (keepOwnUnits) {
      foreach (unitName, status in unitList) {
        if (userUnits.find(unitName) > -1) {
          tempUserBlk[unitType].removeParam(unitName)
          dagor.debug("randomSpawnUnit. user " + userId + " have " + unitName + ", remove it from list")
        }
      }
    }
    local unitTypeLimit = user_blk?["random_units_limit"]?[unitType]
    if (!multiRespawn && ( unitTypeLimit > tempUserBlk[unitType].paramCount() )) {
      dagor.debug("randomSpawnUnit. random units limit (" + unitTypeLimit +
                  ") set to user units count (" + tempUserBlk[unitType].paramCount() + ") for " + unitType)
      user_blk["random_units_limit"][unitType] = tempUserBlk[unitType].paramCount()
    }
    if (tempUserBlk[unitType].paramCount() == 0) tempUserBlk.removeBlock(unitType)
  }

  user_blk["random_units"].setFrom(tempUserBlk)

  if (full_mis_blk.useSpawnScore) {
    ::random_unit_spawnscore_tbl[userId] <- {}
    foreach (unitType, unitList in user_blk["random_units"]) {
      local spawnscore = 0
      foreach (unit, status in unitList) spawnscore += get_unit_spawn_score(userId, unit)
      if (unitList.paramCount() > 0) spawnscore = (spawnscore / unitList.paramCount()).tointeger()
      dagor.debug("randomSpawnUnit. user " + userId + ": spawnscore for random " + unitType + " = " + spawnscore)
      foreach (unit, status in unitList) ::random_unit_spawnscore_tbl[userId][unit] <- spawnscore
    }
  }
}

function setRandomUnits(userId, randomUnitType = "ALL")
{
  local user_blk = ::get_user_custom_state(userId, true)
  if (isRandomUnitsNull(userId, user_blk, "setRandomUnits")) return
  foreach (unitType, unitList in user_blk["random_units"]) {
    if (user_blk["random_units_limit"][unitType] > 0 &&
        (randomUnitType == "ALL" || randomUnitType == unitType)) {
      local unitsCount = unitList.paramCount()
      local rnd = (unitsCount * ::math.frnd()).tointeger()
      local random_unit = unitList.getParamName(rnd)
      dagor.debug("randomSpawnUnit_setRandomUnit. userId " + userId + ": unitType = " + unitType + ", unitsCount = " +
                   unitsCount + ", rnd = " + rnd + ", random_unit = " + random_unit)
      unitList.setBool(random_unit, true)
    }
  }
}

function randomSpawnUnit_get_unit_spawn_score(userId, unitname)
{
  generateRandomUnitList(userId)

  local spawnCost = 0
  local unitType = getRandomUnitType(userId, unitname)
  if ((unitname in ::random_unit_spawnscore_tbl[userId]) && unitType) {
    local score = ::random_unit_spawnscore_tbl[userId][unitname]
    local user_blk = ::get_user_custom_state(userId, false)
    local spawn_mul = getUnitSpawnScoreMul(userId, user_blk["random_units"][unitType].getParamName(0))
    spawnCost = ((score * spawn_mul * 0.1).tointeger() * 10).tointeger()
    dagor.debug("randomSpawnUnit_get_unit_spawn_score unit " + unitname + " spawnCost " + spawnCost +
                " score " + score + " spawn_mul " + spawn_mul)
  }
  else spawnCost = get_unit_spawn_score(userId, unitname)

  return spawnCost
}

function getRandomUnitType(userId, unitname)
{
  local user_blk = ::get_user_custom_state(userId, false)
  if (isRandomUnitsNull(userId, user_blk, "getRandomUnitType")) return
  foreach (unitType, unitList in user_blk["random_units"])
    if (unitname in unitList) return unitType
}

function isRandomUnitsNull(userId, user_blk, caller_func_name)
{
  if (!user_blk?.random_units) {
    dagor.debug("ERROR: " + caller_func_name + ". userId " + userId + " random_units is null")
    return true
  }
}

// ------------- randomSpawnUnit END -------------------
dagor.debug("randomSpawnUnit script loaded successfully")