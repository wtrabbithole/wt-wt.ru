//---- Unit deck BEGIN ----
function unitsDeck_onSessionStart()
{
  dagor.debug("unitsDeck_onSessionStart")

  local rulesBlk = ::get_mission_custom_state(true)
  local mis = get_current_mission_info_cached()
  rulesBlk.setFrom(mis.customRules)
}

function unitsDeck_onSessionEnd()
{
  dagor.debug("unitsDeck_onSessionEnd")
  local rulesBlk = ::get_mission_custom_state(true)
  local unitsParamsList = rulesBlk.unitsParamsList

  if (rulesBlk == null || rulesBlk.teams == null)
  {
    dagor.debug("ERROR: rulesBlk.teams not found")
    return
  }
  
  foreach (sharedGroupName, sharedGroup in unitsSharedGroups)
  {
    local team = sharedGroup.team
    local teamName = get_team_name_by_mp_team(team)
    if (rulesBlk.teams[teamName] == null || rulesBlk.teams[teamName].limitedUnits == null)
    {
      dagor.debug("ERROR:" + teamName + " limitedUnits list not found")
      return
    }

    foreach (unit, count in sharedGroup.limitedUnits)
      if (rulesBlk.teams[teamName].limitedUnits[unit] != null)
      {
        local oldCount = rulesBlk.teams[teamName].limitedUnits[unit]
        rulesBlk.teams[teamName].limitedUnits[unit] = oldCount + count
        local weaponList = sharedGroup.weaponList

        dagor.debug("unitsDeck_onSessionEnd " + unit + " is still in slot, return to deck. " + oldCount +
                    " -> " + rulesBlk.teams[teamName].limitedUnits[unit])
                
        if (weaponList != null && weaponList[unit] != null && weaponList[unit].respawnsLeft > 0)
          modParamInUnitsParamsList(team, unit, "weapon.count", weaponList[unit].respawnsLeft, true)
      }
  }
  
  if (unitsParamsList != null)
  {
    local wpcost = get_wpcost_blk()

    foreach (teamName, teamBlock in unitsParamsList)
      if (rulesBlk.teams[teamName] != null && rulesBlk.teams[teamName].limitedUnits != null)
      {  
        local unitDeckFull = rulesBlk.teams[teamName].limitedUnits

        foreach (unitname, unitBlock in teamBlock)
        {
          local unitClass = getWpcostUnitClass(unitname)
          dagor.debug("unitsDeck_onSessionEnd " + unitname + " " + unitClass)

          if (unitClass == "exp_assault" || unitClass == "exp_bomber")
          {
            if (unitBlock.weapon != null && unitBlock.weapon.count != null)
            {
              local currentWeaponCount = unitBlock.weapon.count            
              local unitCount = unitDeckFull.getInt(unitname, 0)

              dagor.debug("unitsDeck_onSessionEnd units = " + unitCount + ", weapons " +
                          currentWeaponCount)

              if (currentWeaponCount < 0)
                currentWeaponCount = 0

              if (unitCount > currentWeaponCount)
              {
                local weaponLostInSession = unitCount - currentWeaponCount
                if (unitBlock.inactive > 0)
                  unitBlock.inactive += weaponLostInSession
                else
                  unitBlock.inactive = weaponLostInSession
              }
            }
          }
          else
          if (unitClass == "exp_fighter")
          {
            local ammoSpent = unitBlock.ammoSpent

            if (ammoSpent > 0 && wpcost[unitname] != null && wpcost[unitname].maxAmmo > 0)
            {
              local maxAmmoCount = wpcost[unitname].maxAmmo
              local unitsWithoutAmmoCount = (ammoSpent * 1.0 / maxAmmoCount).tointeger()

              dagor.debug("unitsDeck_onSessionEnd unitsWithoutAmmo " + unitsWithoutAmmoCount +
                          " ammoSpent " + ammoSpent + ", max " + maxAmmoCount)

              local unitCount = unitDeckFull.getInt(unitname, 0)
              if (unitsWithoutAmmoCount < unitCount)
                unitsWithoutAmmoCount = unitCount

              if (unitBlock.inactive > 0)
                unitBlock.inactive += unitsWithoutAmmoCount
              else
                unitBlock.inactive = unitsWithoutAmmoCount
            }
          }
        }
      }
      else
        dagor.debug("ERROR:" + teamName + " limitedUnits list not found")
  }
}

function unitsDeck_onPlayerConnected(userId, team, country)
{
  dagor.debug("unitsDeck_onPlayerConnected")
  unitsDeck_init(userId, team, country, 0, 0, 0)
}

function unitsDeck_onPlayerDisconnected(userId)
{
  dagor.debug("unitsDeck_onPlayerDisconnected")

  local sharedGroup = usersSharedGroupList?[userId]
  if (!sharedGroup) {
    dagor.debug("unitsDeck_onPlayerDisconnected. ERROR: user " + userId + " haven't sharedGroup.")
    return
  }
  local team = ::get_player_matching_info(userId).team
  local user_blk = ::get_user_custom_state(userId, false)
  local usersInSharedGroup = 0

  foreach(userId, userSharedGroup in usersSharedGroupList)
    if (sharedGroup == userSharedGroup) usersInSharedGroup++

  if (usersInSharedGroup <= 1) {
    local groupLimitedUnits = unitsSharedGroups?[sharedGroup]?.limitedUnits
    local groupWeaponList = unitsSharedGroups?[sharedGroup]?.weaponList

    if (groupLimitedUnits && groupWeaponList) {
      foreach(unitName, unitCount in groupLimitedUnits) {
        local weaponName = ""
        local weaponCount = groupWeaponList?[unitName]?.respawnsLeft ?? 0
        if (weaponCount > 0) {
          weaponName = groupWeaponList[unitName].name ?? ""
          modParamInUnitsParamsList(team, unitName, "weapon.count", weaponCount, true)
        }
        if (unitCount > 0) modUnitListInSharedGroup(userId, unitName, -unitCount, team, weaponName, true)
      }
    }
  }
  delete usersSharedGroupList[userId]
}

function unitsDeck_canPlayerSpawn(userId, team, country, unit, weapon, fuel)
{
  return unitsDeck_canPlayerSpawnCommon(userId, team, country, unit, weapon, fuel)
}

function checkUnitFuel(unit, fuel)
{
  local rulesBlk = ::get_mission_custom_state(false)
  local fuelList = rulesBlk.unitsFuelPercentList
  if (fuelList != null && fuelList[unit] != null && fabs(fuelList[unit] - fuel) > 0.001)
    return false
  else
    return true
}

function unitsDeck_canPlayerSpawnCommon(userId, team, country, unit, weapon, fuel)
{
  local canSpawnForFree = checkUnitListInUserState(userId, unit, -1)
                          && checkWeaponListInUserState(userId, unit, weapon)

  local canSpawnForSpawnScore = false
  local unitSpawnScore = wwGetSpawnScore(userId, unit)
  if (!canSpawnForFree && (unitSpawnScore > 0)) {
    local userSpawnScore = get_player_spawn_score(userId)
    local unitsDeckFull = getBlockFromTeamBlkByName(team, "limitedUnits")
    local unitCount = unitsDeckFull?[unit]
    local weaponCount = modParamInUnitsParamsList(team, unit, "weapon.count", 0, false)

    canSpawnForSpawnScore = ((userSpawnScore >= unitSpawnScore) && (unitCount > 0) && (weaponCount != 0))
  }

  dagor.debug("unitsDeck_canPlayerSpawn userId " + userId + " " + unit + " canSpawnForFree " + canSpawnForFree +
              " canSpawnForSpawnScore " + canSpawnForSpawnScore + " fuel " + fuel + " weapon " + weapon)
  return ((canSpawnForFree || canSpawnForSpawnScore) && checkUnitFuel(unit, fuel))
}

function getCountryForUnit(unit)
{
  local wpcost = get_wpcost_blk()
  if (wpcost != null && wpcost[unit] != null && wpcost[unit].country != null)
    return wpcost[unit].country

  return ""
}

function unitsDeck_canBotSpawn(team, unit, weapon, fuel)
{
  local unitsDeckFull = getBlockFromTeamBlkByName(team, "limitedUnits")
  if (unitsDeckFull?[unit] > 0) return true

  return false
}

function unitsDeck_onBotSpawn(playerIdx, team, country, unit, weapon)
{
  country = getCountryForUnit(unit) //bots have country_0
  
  dagor.debug("unitsDeck_onBotSpawn playerIdx " + playerIdx + " " + unit + " team " + team +
              " country " + country)
  local rulesBlk = ::get_mission_custom_state(true)
  local unitsDeckFull = getBlockFromTeamBlkByName(team, "limitedUnits")
  local unitsDeckShort = getUnitsDeckShortBlk(team, country)

  local shortUnitsCount = 0
  if (unitsDeckShort?[unit] > 0) shortUnitsCount = unitsDeckShort[unit]

  dagor.debug("unitsDeck_onBotSpawn prev full " + unitsDeckFull?[unit] + ", short " + shortUnitsCount)
  if (unitsDeckFull?[unit] > 0)
  {
    local weaponCount = modParamInUnitsParamsList(team, unit, "weapon.count", 0, false)
    if (unitsDeckFull[unit] <= weaponCount)
      modParamInUnitsParamsList(team, unit, "weapon.count", -1, true)

    unitsDeckFull[unit]--
  }
  if (unitsDeckShort?[unit] > 0)
  {
    unitsDeckShort[unit]--
    shortUnitsCount = unitsDeckShort[unit]
  }
  dagor.debug("unitsDeck_onBotSpawn after full " + unitsDeckFull?[unit] + ", short " + shortUnitsCount)
}

function setDelayBetweenSpawns(userId, team)
{
  local rulesBlk = ::get_mission_custom_state(false)
  local delay = rulesBlk.getInt("delayBetweenSpawnsSec", 0)
  local unitsDeckFull = getBlockFromTeamBlkByName(team, "limitedUnits")

  dagor.debug("setDelayBetweenSpawns delay " + delay)
  if (unitsDeckFull && delay > 0)
    foreach(unit, count in unitsDeckFull)
    {
      dagor.debug("setDelayBetweenSpawns set delay for " + unit)
      set_player_unit_spawn_delay(userId, unit, delay, 0)
    }
}

::wwarEconTbl <- {}
function unitsDeck_onPlayerSpawn(userId, team, country, unit, weapon, cost)
{
  setDelayBetweenSpawns(userId, team)

  if (cost < 0)
    cost = 0

  if (!("teamSpawnCost" in wwarEconTbl))
    wwarEconTbl.teamSpawnCost <- {}

  if (!(team in wwarEconTbl.teamSpawnCost))
    wwarEconTbl.teamSpawnCost[team] <- cost
  else
    wwarEconTbl.teamSpawnCost[team] += cost

  if (!("userTeam" in wwarEconTbl))
    wwarEconTbl.userTeam <- {}
  wwarEconTbl.userTeam[userId] <- team

  local user_blk = ::get_user_custom_state(userId, false)
  if (user_blk?.ownAvailableUnits?[unit] && user_blk?.limitedUnits?[unit] <= 0) {
    local unitsDeckShort = getUnitsDeckShortBlk(team, country)
    local unitsDeckFull = getBlockFromTeamBlkByName(team, "limitedUnits")
    if (unitsDeckShort?[unit] > 0) unitsDeckShort[unit]--
    if (unitsDeckFull?[unit] > 0) unitsDeckFull[unit]--
    modParamInUnitsParamsList(team, unit, "weapon.count", -1, true)
  }
  else modUnitListInSharedGroup(userId, unit, -1, team, weapon)
  dagor.debug("unitsDeck_onPlayerSpawn userId " + userId + " " + unit + " team " + team +
              ", cost " + wwarEconTbl.teamSpawnCost[team] + " weapon " + weapon)
}

function unitsDeck_onBailoutOnAirfield(userId, team, country, unit, weapon)
{
  dagor.debug("unitsDeck_onBailoutOnAirfield userId " + userId + " " + unit + " team " + team)
}

function unitsDeck_onDeath(userId, team, country, unit, weapon, nw, na, dmg)
{
  unitsDeck_onDeathCommon(userId, team, country, unit, weapon, nw, na, dmg, 0, 1000, 500)
}

function addUnitToUnitsParamsList(teamName, unitName, unitParams)
{  
  local rulesBlk = ::get_mission_custom_state(true)
  local unitsParamsList = rulesBlk.unitsParamsList

  if (unitsParamsList != null && unitsParamsList[teamName] != null &&
      unitsParamsList[teamName][unitName] == null)
  {
    unitsParamsList[teamName][unitName] <- DataBlock()
    unitsParamsList[teamName][unitName].setFrom(unitParams)
  }
}

function modParamInUnitsParamsList(team, unit, path, num, mod)
{
  local teamName = get_team_name_by_mp_team(team)
  local rulesBlk = ::get_mission_custom_state(true)
  local unitsParamsList = rulesBlk.unitsParamsList
  if (unitsParamsList != null && unitsParamsList[teamName] != null &&
      unitsParamsList[teamName][unit] != null)
  {
    local param_name =""
    local param = unitsParamsList[teamName][unit]
    while (path.len() > 0)
    {
      param_name = path
      if (path.find(".") > -1)
      {
        param_name = path.slice(0, path.find("."))
        path = path.slice(path.find(".") + 1, path.len())
        if (param[param_name] == null)
        {
          dagor.debug("modParamInUnitsParamsList["+teamName+"]["+unit+"][" + param_name + "] not found")
          return null
        }
        else
          param = param[param_name]
      }
      else
        path = ""
    }
    
    if (param[param_name] == null)
    {
      if (!mod)
        return null
      
      param[param_name] = 0
    }
    
    if (mod)
    {
      dagor.debug("modParamInUnitsParamsList modify "+param_name+" "+param[param_name]+" + " + num)
      param[param_name] += num
    }

    return param[param_name]
  }  
}

function unitsDeck_onDeathCommon(userId, team, country, unit, weapon, nw, na, dmg, minRating, maxRating, playerRating)
{
  dagor.debug("unitsDeck_onDeathCommon userId " + userId + " " + unit + " nw " + nw + " na " + na +
              " dmg " + dmg)
  unitsDeck_unitDraw(userId, team, country, minRating, maxRating, playerRating, false)

  if (dmg < 1)
  {
    modParamInUnitsParamsList(team, unit, "ammoSpent", na, true)
    
    if (nw < 1 && modParamInUnitsParamsList(team, unit, "weapon.name", 0, false) == weapon)
      modParamInUnitsParamsList(team, unit, "weapon.count", 1, true)
  }
}

function unitsDeck_onSurvive(userId, team, country, unit, weapon, nw, na, dmg)
{
  dagor.debug("unitsDeck_onSurvive userId " + userId + " " + unit + " nw " + nw + " na " + na +
              " dmg " + dmg)
  modParamInUnitsParamsList(team, unit, "ammoSpent", na, true)

  local rulesBlk = ::get_mission_custom_state(true)
  local unitDeckFull = getBlockFromTeamBlkByName(team, "limitedUnits")
  if (unitDeckFull?[unit])
  {
    local unitCount = unitDeckFull[unit]
    unitDeckFull[unit]++
    dagor.debug("unitsDeck_onSurvive " + unit + " survived. " + unitCount + " -> " + unitDeckFull[unit])
  }

  if (nw < 1 && modParamInUnitsParamsList(team, unit, "weapon.name", 0, false) == weapon)
    modParamInUnitsParamsList(team, unit, "weapon.count", 1, true)
}

function unitsDeck_onBotSurvive(userId, team, country, unit, weapon)
{
  local mis = get_current_mission_info_cached()
  local wpcost = get_wpcost_blk()
  if (wpcost[unit] == null)
    return

  local maxAmmo = wpcost[unit].getInt("maxAmmo", 0)
  local botSurviveAmmoLostPercent = mis.getReal("botSurviveAmmoLostPercent", 0)
  local na = (maxAmmo * botSurviveAmmoLostPercent).tointeger()

  local nw = 0
  local rnd = ::math.frnd()
  local botSurviveWeaponLostPercent = mis.getReal("botSurviveWeaponLostPercent", 0)
  if (botSurviveWeaponLostPercent > 0 && rnd <= botSurviveWeaponLostPercent)
    nw = 1

   dagor.debug("unitsDeck_onBotSurvive " + unit + " maxAmmo " + maxAmmo + " botSurviveWeaponLostPercent " + botSurviveWeaponLostPercent +
               " rnd " + rnd + " botSurviveAmmoLostPercent " + botSurviveAmmoLostPercent)
  
   local weapon = modParamInUnitsParamsList(team, unit, "weapon.name", 0, false)
   if (weapon == null)
     weapon = ""
   
   unitsDeck_onSurvive(userId, team, country, unit, weapon, nw, na, 0)
}

function unitsDeck_init(userId, team, country, minRating, maxRating, playerRating)
{
  local misBlk = ::get_current_mission_info_cached()
  local rulesBlk = ::get_mission_custom_state(false)
  local teamsBlk = rulesBlk.teams
  local teamName = get_team_name_by_mp_team(team)

  addOwnAvailableUnitsBlockToUserBlk(userId, teamsBlk, teamName)

  local unitDeckFull = getBlockFromTeamBlkByName(team, "limitedUnits")
  if (unitDeckFull == null)
    dagor.debug("unitsDeck spawn config is broken, can't find limitedUnits block for " +
                team +" " +country)
  else
  if (teamsBlk[teamName].distributedUnits == null) teamsBlk[teamName].distributedUnits <- DataBlock()

  unitsDeck_setUnitsSharedGroup(userId, team)

  local startUnitsCount = teamsBlk[teamName].getInt("startUnitsCount", 0)
  dagor.debug("unitsDeck_init userId " + userId + " startUnitsCount " + startUnitsCount)

  local sharedGroup = usersSharedGroupList?[userId]
  if (!sharedGroup) {
    dagor.debug("unitsDeck_init. ERROR: user " + userId + " haven't sharedGroup.")
    return
  }
  local userSharedGroup = unitsSharedGroups[sharedGroup]
  local unitsCountInSharedGroup = getUnitListUnitCount(userSharedGroup.limitedUnits)
  local unitsDeckShort = getUnitsDeckShortBlk(team, country)
  local unitsCount = 0
  if (unitsDeckShort) unitsCount = getUnitListUnitCount(unitsDeckShort)

  if (unitsCount == 0 && unitsCountInSharedGroup > 0) {
    dagor.debug("unitsDeck_init don't give unit. sharedGroup " + sharedGroup + " already have "
                + unitsCountInSharedGroup + " units and unitsDeckShort is empty")
    updateUserBlk(userId)
  }
  else {
    for (local i = 0; i < startUnitsCount; i++) {
      if (i == 0) unitsDeck_unitDraw(userId, team, country, minRating, maxRating, playerRating, true)
      else unitsDeck_unitDraw(userId, team, country, minRating, maxRating, playerRating, false)
    }
  }
}

function addOwnAvailableUnitsBlockToUserBlk(userId, teamsBlk, teamName)
{
  local user_blk = ::get_user_custom_state(userId, true)
  if (!user_blk.ownAvailableUnits) user_blk.ownAvailableUnits <- DataBlock()
  local userUnits = ::get_player_matching_info(userId)?.userUnits
  if (!userUnits) {
    dagor.debug("addOwnAvailableUnitsBlockToUserBlk ERROR: userUnits is NULL")
    return
  }
  if (teamsBlk[teamName].limitedUnits) {
    foreach(unitname, unitCount in teamsBlk[teamName].limitedUnits) {
      if (userUnits.find(unitname) > -1) user_blk.ownAvailableUnits.setBool(unitname, true)
      else user_blk.ownAvailableUnits.setBool(unitname, false)
    }
  }
}

function getBlockFromTeamBlkByName(team, blockName)
{
  local rulesBlk = ::get_mission_custom_state(false)
  local teamsBlk = rulesBlk.teams
  local teamName = get_team_name_by_mp_team(team)
  return teamsBlk?[teamName]?[blockName]
}

::unitDeckServerBlk <- null
function getUnitsDeckShortBlk(team, country)
{
  local teamName = get_team_name_by_mp_team(team)
  if (unitDeckServerBlk != null && unitDeckServerBlk.teams != null &&
      unitDeckServerBlk.teams[teamName] != null &&
      unitDeckServerBlk.teams[teamName][country] != null)
    return unitDeckServerBlk.teams[teamName][country].limitedUnitsShort

  return null
}

function resetTeamUnitsDeckShort(teamName, country)
{
  local emptyBlock = DataBlock()

  if (unitDeckServerBlk != null && unitDeckServerBlk.teams != null && 
      unitDeckServerBlk.teams[teamName] != null &&
      unitDeckServerBlk.teams[teamName][country] != null &&
      unitDeckServerBlk.teams[teamName][country].limitedUnitsShort != null &&
      unitDeckServerBlk.teams[teamName][country].limitedUnitsShort.paramCount() > 0)
  {    
    dagor.debug("resetTeamUnitsDeckShort for team " + teamName +" country " + country)
    unitDeckServerBlk.teams[teamName][country].limitedUnitsShort.setFrom(emptyBlock)
  }
}

function getUnitListUnitCount(unitList)
{
  local unitsCount = 0
  if (unitList == null)
    return 0

  foreach(unitname, unitCount in unitList)
    unitsCount += unitCount

  return unitsCount
}

function get_unit_country(unitname)
{
  local wp_cost = ::get_wpcost_blk()
  if (wp_cost != null && wp_cost[unitname] != null && wp_cost[unitname].country != null)
    return wp_cost[unitname].country
  return ""
}

function setUnitsDeckShortBlk(team, country)
{
  local unitDeckFull = getBlockFromTeamBlkByName(team, "limitedUnits")
  if (unitDeckFull == null)
  {
    dagor.debug("unitsDeck spawn config is broken, can't find limitedUnits block for " +
                team)
    return null
  }

  local teamName = get_team_name_by_mp_team(team)
  local rulesBlk = ::get_mission_custom_state(false)
  local deckShortSize = rulesBlk.getInt("deckShortSize", 16)
  local unitsCount = getUnitListUnitCount(unitDeckFull)
  local unitsDeckShort = DataBlock()
  foreach(unitname, unitCount in unitDeckFull)
  {
    /*dagor.debug("setUnitsDeckShortBlk " + unitname + " " + get_unit_country(unitname)  + " =? " +
                country + " unitCount" + unitCount)*/
    if (unitCount > 0 && get_unit_country(unitname) == country)
    {
      unitsDeckShort[unitname] = (unitCount * 1.0 / unitsCount * deckShortSize + 0.5).tointeger()
      if (unitsDeckShort[unitname] < 1)
        unitsDeckShort[unitname] = 1
      if (unitsDeckShort[unitname] > unitCount)
        unitsDeckShort[unitname] = unitCount
    }
    else
      unitsDeckShort[unitname] = 0
  }

  if (unitDeckServerBlk == null)
    unitDeckServerBlk <- DataBlock()
  if (unitDeckServerBlk.teams == null)
    unitDeckServerBlk.teams <- DataBlock()
  if (unitDeckServerBlk.teams[teamName] == null)
    unitDeckServerBlk.teams[teamName] <- DataBlock()
  if (unitDeckServerBlk.teams[teamName][country] == null)
    unitDeckServerBlk.teams[teamName][country] <- DataBlock()  
  if (unitDeckServerBlk.teams[teamName][country].limitedUnitsShort == null)
    unitDeckServerBlk.teams[teamName][country].limitedUnitsShort <- DataBlock()
  unitDeckServerBlk.teams[teamName][country].limitedUnitsShort.setFrom(unitsDeckShort)
}

function getAvgUnitsRank(unitList)
{
  local totalRank = 0
  local unitTypeCount = 0

  foreach(unitname, unitCount in unitList)
    if (unitCount > 0)
    {
      totalRank += get_economic_rank_by_unit_name(unitname)
      unitTypeCount++
    }

  local avgRank = 0
  if (unitTypeCount > 0)
    avgRank = totalRank * 1.0 / unitTypeCount

  return avgRank
}

function sortParamsInDataBlock(data_block)
{
  local param_count = data_block.paramCount()
  local sort_list = array(param_count, 0)
  local sorted_data_block = DataBlock()
  local i = 0
  foreach (param_name, param in data_block)
  {
    sort_list[i] = param
    i++
  }
  sort_list.sort()

  for(local j = 0; j < param_count; j++)
    if (j == 0 || sort_list[j] != sort_list[j-1])
      foreach(param_name, param in data_block)
        if (param == sort_list[j])
          sorted_data_block[param_name] <- param

  return sorted_data_block
}

function getUnitsDeckUnitsPreference(team)
{
  local rulesBlk = ::get_mission_custom_state(false)
  local unitsPreferenceList = rulesBlk.unitsDeckUnitsPreference
  if (unitsPreferenceList == null)
    return null  

  return unitsPreferenceList[get_team_name_by_mp_team(team)]
}

function checkUserListOnPreferredUnit(userId, team)
{
  local unitsPreferenceList = getUnitsDeckUnitsPreference(team)
  if (unitsPreferenceList == null)
    return true

  local unitDeckFull = getBlockFromTeamBlkByName(team, "limitedUnits")
  if (unitDeckFull == null)
  {
    dagor.debug("unitsDeck spawn config is broken, can't find limitedUnits block for " + team)
    return true
  }
  
  local isAtLeastOneUnitPresented = false
  foreach(unitname, unitCount in unitDeckFull)
    foreach(unitClass, unitClassMul in unitsPreferenceList)
      if (getWpcostUnitClass(unitname) == unitClass && unitCount > 0) {
        isAtLeastOneUnitPresented = true
        break
      }

  if (!isAtLeastOneUnitPresented)
    return true

  
  local user_blk = ::get_user_custom_state(userId, false)
  if (user_blk == null || user_blk.limitedUnits == null)
    return false

  foreach(unitname, unitCount in user_blk.limitedUnits)
    foreach(unitClass, unitClassMul in unitsPreferenceList)
      if (getWpcostUnitClass(unitname) == unitClass && unitCount > 0)
        return true

  return false
}

function setPreferencesInUnitsDeckShort(unitList, team)
{
  dagor.debug("setPreferencesInUnitsDeckShort modify unitsDeckShort to give preferred unit")
  local unitsDeckShort = DataBlock()
  unitsDeckShort.setFrom(unitList)

  local totalUnitCount = getUnitListUnitCount(unitsDeckShort)

  local unitsPreferenceList = getUnitsDeckUnitsPreference(team)
  if (unitsPreferenceList == null)
    return unitsDeckShort
  
  foreach(unitname, unitCount in unitsDeckShort)
  {
    if (unitCount <= 0)
      continue

    local unitClassFound = false
    foreach(unitClass, unitClassMul in unitsPreferenceList)
      if (getWpcostUnitClass(unitname) == unitClass)
      {
        unitsDeckShort[unitname] = (unitCount * unitClassMul).tointeger()
        if (unitsDeckShort[unitname] <= 0)
          unitsDeckShort[unitname] = 1

        unitClassFound = true
        break
      }

    if (!unitClassFound)
      unitsDeckShort[unitname] = 0
  }

  return unitsDeckShort
}

function setForcedUnitsList(unitsDeckShort)
{
  local forcedUnitsDeckShort = DataBlock()
  dagor.debug("setForcedUnitsList started")
  if (unitsDeckShort != null)
    foreach (unitname, unitCount in unitsDeckShort)
      forcedUnitsDeckShort[unitname] = 1

  return forcedUnitsDeckShort
}

function unitsDeck_unitDraw(userId, team, country, minRating, maxRating, playerRating, forceUnitDraw)
{
  local debug_str = "unitsDeck_unitDraw userId " + userId + " " + get_team_name_by_mp_team(team) +
                    " " + country

  local rulesBlk = ::get_mission_custom_state(false)
  local teamsBlk = rulesBlk.teams
  local teamName = get_team_name_by_mp_team(team)

  local sharedGroup = usersSharedGroupList?[userId]
  if (!sharedGroup) {
    dagor.debug("unitsDeck_unitDraw. ERROR: user " + userId + " haven't sharedGroup.")
    return
  }

  local userSharedGroup = unitsSharedGroups[sharedGroup]
  updateUserBlk(userId)

  local unitsCountInSharedGroup = getUnitListUnitCount(userSharedGroup.limitedUnits)
  local usersInSharedGroup = 0
  local startUnitsCount = teamsBlk[teamName].getInt("startUnitsCount", 0)

  foreach(userId, userSharedGroup in usersSharedGroupList)
    if (sharedGroup == userSharedGroup) usersInSharedGroup++

  local hasPreferredUnit = checkUserListOnPreferredUnit(userId, team)
  if (hasPreferredUnit && (unitsCountInSharedGroup >= startUnitsCount * usersInSharedGroup)) {
    dagor.debug("unitsDeck_unitDraw. sharedGroup " + sharedGroup + " already have enough units count (" + 
                unitsCountInSharedGroup + ") for " + usersInSharedGroup + " players. Don't give unit.")
    return
  }

  local unitsDeckShort = getUnitsDeckShortBlk(team, country)
  local unitsCount = getUnitListUnitCount(unitsDeckShort)
  local unitsDeckShortLocal = DataBlock()
  local unitsDeckShortWasForced = false

  if (unitsDeckShort == null || unitsCount <= 0)
  {
    setUnitsDeckShortBlk(team, country)
    unitsDeckShort = getUnitsDeckShortBlk(team, country)
    unitsCount = getUnitListUnitCount(unitsDeckShort)
    
    if (unitsDeckShort == null || unitsCount <= 0)
      if (!forceUnitDraw)
      {
        dagor.debug(debug_str)
        dagor.debug("unitsDeck_unitDraw unitsDeckShort is empty, unitsCount = " + unitsCount)
        return
      }
      else
      {
        unitsDeckShortLocal.setFrom(setForcedUnitsList(unitsDeckShort))
        unitsDeckShortWasForced = true
      }
  }

  if (!unitsDeckShortWasForced)
    unitsDeckShortLocal.setFrom(unitsDeckShort)

  if (!hasPreferredUnit || unitsDeckShortWasForced) {
    unitsDeckShortLocal.setFrom(setPreferencesInUnitsDeckShort(unitsDeckShortLocal, team))
    unitsCount = getUnitListUnitCount(unitsDeckShortLocal)
    
    if (unitsCount <= 0) {
      setUnitsDeckShortBlk(team, country)
      unitsDeckShort = getUnitsDeckShortBlk(team, country)
      unitsDeckShortLocal.setFrom(setPreferencesInUnitsDeckShort(unitsDeckShort, team))
      unitsCount = getUnitListUnitCount(unitsDeckShortLocal)
    }
  }
  
  local avgUnitsRank = getAvgUnitsRank(unitsDeckShortLocal)
  local weightUnitList = DataBlock()
  local weightRndPart = rulesBlk.getReal("weightRndPart", 0)

  if (playerRating < minRating)
    playerRating = minRating
  if (playerRating > maxRating)
    playerRating = maxRating

  local playerRatingMul = 0.0
  if (maxRating > minRating)
    playerRatingMul = playerRating * 1.0 / (maxRating - minRating)

  if (weightRndPart < 0.0)
    weightRndPart = 0.0
  if (weightRndPart > 1.0)
    weightRndPart = 1.0

  unitsCount = getUnitListUnitCount(unitsDeckShortLocal)
  
  foreach(unitname, unitCount in unitsDeckShortLocal)
    if (unitCount > 0)
    {
      local unitRank = get_economic_rank_by_unit_name(unitname)
      if (avgUnitsRank <= unitRank)
      {
        weightUnitList[unitname] = unitCount * 1.0 / unitsCount *
                                   (1 - weightRndPart * playerRatingMul)
      }
    }
  local goodUnitsTotalWeight = getUnitListUnitCount(weightUnitList)
  dagor.debug(debug_str + " unitsCount " + unitsCount + " avgUnitsRank " + avgUnitsRank + ", goodUnitsTotalWeight " +
                    goodUnitsTotalWeight)


  local prevUnitWeight = 0
  foreach(unitname, unitCount in unitsDeckShortLocal)
    if (unitCount > 0)
    {
      local unitRank = get_economic_rank_by_unit_name(unitname)
      local minWeight = unitCount * 1.0 / unitsCount * (1 - weightRndPart * playerRatingMul)
      local maxWeight = minWeight
      if (avgUnitsRank <= unitRank && goodUnitsTotalWeight > 0)
        maxWeight += weightUnitList[unitname] / goodUnitsTotalWeight * weightRndPart

      weightUnitList[unitname] = minWeight + (maxWeight - minWeight) * playerRatingMul
      weightUnitList[unitname] += prevUnitWeight
      prevUnitWeight = weightUnitList[unitname]

      //print(weightUnitList[unitname]+", minWeight = "+minWeight+", maxWeight = "+maxWeight+"\n")
    }
    else
      weightUnitList[unitname] = 0

  weightUnitList = sortParamsInDataBlock(weightUnitList)

  local rnd = ::math.frnd()

  foreach(unitname, unitWeight in weightUnitList)
    if (rnd <= unitWeight + 0.0001 && unitWeight > 0) {
      local unitsDeckFull = getBlockFromTeamBlkByName(team, "limitedUnits")
      if (unitsDeckFull?[unitname] && unitsDeckFull[unitname] <= 0 && !forceUnitDraw) {
        dagor.debug("ERROR: unitsDeck try to give unit that is not presented in unitsDeckFull list anymore")
        return
      }

      dagor.debug("unitsDeck_unitDraw give " + unitname + ", rnd " + rnd)
      modUnitListInSharedGroup(userId, unitname, 1, team, "")
      if (unitsDeckFull[unitname] > 0) unitsDeckFull[unitname]--
      if (unitsDeckShort[unitname] > 0) unitsDeckShort[unitname]--
      return
    }
}

function modDistributedUnitsBlk(unit, team, num, needReturnUnitsToDeck = false)
{
  local distributedUnitsBlk = getBlockFromTeamBlkByName(team, "distributedUnits")
  if (distributedUnitsBlk == null)
  {
    dagor.debug("unitsDeck spawn error. DistributedUnitsBlk is null")
    return
  }

  local newnum = num
  if (distributedUnitsBlk[unit] != null)
    newnum += distributedUnitsBlk[unit]

  if (newnum < 0)
    dagor.debug("unitsDeck spawn error. trying to remove " + unit +
                " from distributedUnitsList that is not presented there. newnum = " + newnum +
                ", num = " + num)
  else {
    distributedUnitsBlk[unit] = newnum
    if (needReturnUnitsToDeck) {
      local unitsDeckFull = getBlockFromTeamBlkByName(team, "limitedUnits")
      if (unitsDeckFull?[unit]) unitsDeckFull[unit] -= num
    }
  }
}

function weaponAvailableCount(team, unit, num)
{
  local weaponCount = modParamInUnitsParamsList(team, unit, "weapon.count", 0, false)
  local weaponAvailable = weaponCount
  if (weaponCount >= num)
    weaponAvailable = num

  if (weaponAvailable < 0)
    weaponAvailable = 0

  dagor.debug("weaponAvailableCount = " + weaponAvailable + "; total " + weaponCount + ", needed  "  + num)

  return weaponAvailable
}

::unitsSharedGroups <- DataBlock()
::usersSharedGroupList <- {}
function unitsDeck_setUnitsSharedGroup(userId, team)
{
  local matchingInfo = get_player_matching_info(userId)
  local squadId = -1
  local squadronId = -1
  if (matchingInfo != null)
  {
    squadId = matchingInfo.squadId
    squadronId = matchingInfo.clanId
  }
  else
    dagor.debug("unitsDeck_setUnitsSharedGroup error. matchingInfo for user "+userId+" == null")

  local rulesBlk = ::get_mission_custom_state(false)
  local squadronShare = rulesBlk.getBool("squadronShare", false)
  local squadShare = rulesBlk.getBool("squadShare", false)
  local sharedGroup = "user_" + userId

  if (squadShare && squadId > 0)
    sharedGroup = "squad_" + squadId
  else
  if (squadronShare && squadronId > 0)
    sharedGroup = "squadron_" + squadronId

  usersSharedGroupList[userId] <- sharedGroup
  dagor.debug("unitsDeck_setUnitsSharedGroup " + sharedGroup + " userId " + userId + ", squadron " +
              squadronId + ", squad " + squadId + ", team " + team)

  if (unitsSharedGroups[sharedGroup] == null)
    unitsSharedGroups[sharedGroup] <- DataBlock()
  if (unitsSharedGroups[sharedGroup].limitedUnits == null)
    unitsSharedGroups[sharedGroup].limitedUnits <- DataBlock()
  if (unitsSharedGroups[sharedGroup].team == null)  
    unitsSharedGroups[sharedGroup].team = team
}

function modUnitListInSharedGroup(userId, unit, num, team, weapon, needReturnUnitsToDeck = false)
{
  if (userId in usersSharedGroupList)
  {
    local sharedGroup = usersSharedGroupList[userId]
    if (unitsSharedGroups[sharedGroup].limitedUnits[unit] == null)
      unitsSharedGroups[sharedGroup].limitedUnits[unit] <- 0

    local weaponName = modParamInUnitsParamsList(team, unit, "weapon.name", 0, false)
    local weaponCount = 0
    local oldWeaponCount = 0
    local newWeaponCount = 0

    local wpcost = ::get_wpcost_blk()
    if (wpcost[unit] && wpcost[unit].weapons) {
      if (!weaponName || !wpcost[unit].weapons[weaponName]) {
        local incorrectWeaponName = weaponName
        foreach (weapon in wpcost[unit].weapons)
          if (weapon.value == 0) {
            weaponName = weapon.getBlockName()
            dagor.debug("modUnitListInSharedGroup weapon validator - for unit = " + unit +
                        " incorrect weapon (" + incorrectWeaponName + ") replaced by: " + weaponName)
            break
          }
      }
    }
    else
      dagor.debug("modUnitListInSharedGroup weapon validator error - could not load wpcost for unit = " + unit)

    if (weaponName != null)
    {
      if (unitsSharedGroups[sharedGroup].weaponList == null)
        unitsSharedGroups[sharedGroup].weaponList <- DataBlock()
      local weaponList = unitsSharedGroups[sharedGroup].weaponList

      if (weaponList[unit] == null)
        weaponList[unit] <- DataBlock()
      weaponList[unit].name = weaponName
      if (weaponList[unit].respawnsLeft == null)
        weaponList[unit].respawnsLeft = 0

      oldWeaponCount = weaponList[unit].respawnsLeft

      if (num > 0)
      {
        weaponCount = weaponAvailableCount(team, unit, num)
        weaponList[unit].respawnsLeft += weaponCount
        modParamInUnitsParamsList(team, unit, "weapon.count", -weaponCount, true)
      }
      else
      if (unitsSharedGroups[sharedGroup].limitedUnits[unit] == weaponList[unit].respawnsLeft ||
          weapon == weaponName)
        weaponList[unit].respawnsLeft += num

      if (weaponList[unit].respawnsLeft < 0)
        weaponList[unit].respawnsLeft = 0

      newWeaponCount = weaponList[unit].respawnsLeft
    }

    dagor.debug("modUnitListInSharedGroup " + sharedGroup + " unit " + unit + " = " +
                unitsSharedGroups[sharedGroup].limitedUnits[unit] + " + " + num + " weapon " + weaponName +
                " " + oldWeaponCount + " -> " + newWeaponCount)

    if (unitsSharedGroups[sharedGroup].limitedUnits[unit] + num < 0)
    {
      dagor.debug("unitsDeck spawn error. final unit < 0")
      return
    }

    if (num != 0)
    {
      unitsSharedGroups[sharedGroup].limitedUnits[unit] += num

      foreach(childId, childGroup in usersSharedGroupList)
        if (childGroup == sharedGroup) {
          updateUserBlk(childId)
          update_spawn_score(childId)
        }

      modDistributedUnitsBlk(unit, team, num, needReturnUnitsToDeck)
    }
  }
}

function isFreeWeaponPreset(unit, weapon)
{
  local wpcost = ::get_wpcost_blk()
  if (wpcost[unit] == null || wpcost[unit].weapons == null ||
      wpcost[unit].weapons[weapon] == null || wpcost[unit].weapons[weapon].value == null ||
      wpcost[unit].weapons[weapon].value == 0)
    return true

  return false
}

function checkWeaponListInUserState(userId, unit, weapon)
{
  local user_blk = ::get_user_custom_state(userId, false)
  if (isFreeWeaponPreset(unit, weapon) || user_blk.weaponList == null)
    return true

  if (user_blk.weaponList[unit] == null || user_blk.weaponList[unit].name != weapon)
  {
    dagor.debug("unitsDeck spawn error. userId " + userId + " " + unit + " " + weapon +
                " not found in user_blk.weaponList")
    return false
  }

  if (user_blk.weaponList[unit].respawnsLeft <= 0)
  {
    dagor.debug("unitsDeck spawn error. userId " + userId + " user_blk " + unit + " " + weapon +
                " count = " + user_blk.weaponList[unit].respawnsLeft + " <= 0")
    return false
  }

  return true
}

function checkUnitListInUserState(userId, unit, num)
{
  local user_blk = ::get_user_custom_state(userId, false)

  if (user_blk.limitedUnits == null || user_blk.limitedUnits[unit] == null)
  {
    dagor.debug("unitsDeck spawn error. userId " + userId + " " + unit + " not found in user_blk.limitedUnits")
    return false
  }

  if (user_blk.limitedUnits[unit] + num < 0)
  {
    dagor.debug("unitsDeck spawn error. userId " + userId + " user_blk " + unit + "=" +
                user_blk.limitedUnits[unit] + " + num=" + num + " < 0")
    return false
  }

  return true
}

function updateUserBlk(userId)
{
  local sharedGroup = usersSharedGroupList?[userId]
  if (!sharedGroup) {
    dagor.debug("updateUserBlk. ERROR: user " + userId + " haven't sharedGroup.")
    return
  }
  local userSharedGroup = unitsSharedGroups?[sharedGroup]
  local user_blk = ::get_user_custom_state(userId, true)
  if (userSharedGroup && user_blk) {
    if (!user_blk.limitedUnits) user_blk.limitedUnits <- DataBlock()
    if (userSharedGroup.limitedUnits) user_blk.limitedUnits.setFrom(userSharedGroup.limitedUnits)
    if (!user_blk.weaponList) user_blk.weaponList <- DataBlock()
    if (userSharedGroup.weaponList) user_blk.weaponList.setFrom(userSharedGroup.weaponList)
  }
}

function wwInitSpawnScore(userId, sessionRank)
{
  local userSpawnScore = 0
  local esBlk = get_es_custom_blk(userId)
  if (esBlk?.wwSpawnScore) {
    dagor.debug("wwInitSpawnScore " + userId + " added spawn score = " + esBlk.wwSpawnScore)
    userSpawnScore += esBlk.wwSpawnScore
    esBlk.wwSpawnScore = 0
  }
  return userSpawnScore
}

function wwGetSpawnScore(userId, unitname)
{
  local unitSpawnScore = 0
  local user_blk = ::get_user_custom_state(userId, false)

  if (user_blk?.ownAvailableUnits?[unitname] && user_blk?.limitedUnits?[unitname] <= 0) {
    unitSpawnScore = get_unit_spawn_score(userId, unitname)
  }

  dagor.debug("wwGetSpawnScore userId " + userId + " unitname " + unitname + " unitSpawnScore " + unitSpawnScore)
  return unitSpawnScore
}
//---- Unit deck END ----
dagor.debug("unitsDeck loaded")