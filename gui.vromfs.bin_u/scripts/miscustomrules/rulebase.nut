class ::mission_rules.Base
{
  missionParams = null
  isSpawnDelayEnabled = false
  isScoreRespawnEnabled = false
  isTeamScoreRespawnEnabled = false
  isWarpointsRespawnEnabled = false
  hasRespawnCost = false
  needShowLockedSlots = true
  isWorldWar = false

  needLeftRespawnOnSlots = false

  fullUnitsLimitData = null

  constructor()
  {
    initMissionParams()
  }

  function initMissionParams()
  {
    missionParams = ::DataBlock()
    ::get_current_mission_desc(missionParams)

    local isVersus = ::is_gamemode_versus(::get_game_mode())
    isSpawnDelayEnabled = isVersus && ::getTblValue("useSpawnDelay", missionParams, false)
    isTeamScoreRespawnEnabled = isVersus && ::getTblValue("useTeamSpawnScore", missionParams, false)
    isScoreRespawnEnabled = isTeamScoreRespawnEnabled || (isVersus && ::getTblValue("useSpawnScore", missionParams, false))
    isWarpointsRespawnEnabled = isVersus && ::getTblValue("multiRespawn", missionParams, false)
    hasRespawnCost = isScoreRespawnEnabled || isWarpointsRespawnEnabled
    isWorldWar = isVersus && ::getTblValue("isWorldWar", missionParams, false)

    //Add hack for ps4, fix was in .cpp file, remove after 1.61.1.X update, and return default value to 'true'
    local tempDefaultNeedShowLockedSlotsValue = ::getTblValueByPath("customRules/name", missionParams, "", "/") != "unitsDeck"
    ////
    needShowLockedSlots = ::getTblValue("needShowLockedSlots", missionParams, tempDefaultNeedShowLockedSlotsValue)
  }

  function onMissionStateChanged()
  {
    fullUnitsLimitData = null
  }

  /*************************************************************************************************/
  /*************************************PUBLIC FUNCTIONS *******************************************/
  /*************************************************************************************************/

  function getMaxRespawns()
  {
    return ::RESPAWNS_UNLIMITED
  }

  function getLeftRespawns()
  {
    local res = ::RESPAWNS_UNLIMITED
    if (!isScoreRespawnEnabled && ::getTblValue("maxRespawns", missionParams, 0) > 0)
      res = ::get_respawns_left() //code return spawn score here when spawn score enabled instead of respawns left
    return res
  }

  function hasCustomUnitRespawns()
  {
    return false
  }

  function getUnitLeftRespawns(unit, teamDataBlk = null)
  {
    if (!unit)
      return 0
    return getUnitLeftRespawnsByTeamDataBlk(unit, teamDataBlk || getMyTeamDataBlk())
  }

  function getRespawnInfoTextForUnit(unit)
  {
    local unitLeftRespawns = getUnitLeftRespawns(unit)
    if (unitLeftRespawns == ::RESPAWNS_UNLIMITED)
      return ""
    return ::loc("respawn/leftTeamUnit", { num = unitLeftRespawns })
  }

  function getSpecialCantRespawnMessage(unit)
  {
    return null
  }

  //return bitmask is crew can respawn by mission custom state for more easy check is it changed
  function getCurCrewsRespawnMask()
  {
    local res = 0
    if (!hasCustomUnitRespawns() || !getLeftRespawns())
      return res

    local crewsList = ::get_crews_list_by_country(::get_local_player_country())
    local myTeamDataBlk = getMyTeamDataBlk()
    if (!myTeamDataBlk)
      return (1 << crewsList.len()) - 1

    foreach(idx, crew in crewsList)
      if (getUnitLeftRespawns(::g_crew.getCrewUnit(crew), myTeamDataBlk) != 0)
        res = res | (1 << idx)

    return res
  }

  /*
    {
      defaultUnitRespawnsLeft = 0 //respawns left for units not in list
      unitLimits = [] //::g_unit_limit_classes.LimitBase
    }
  */
  function getFullUnitLimitsData()
  {
    if (!fullUnitsLimitData)
      fullUnitsLimitData = calcFullUnitLimitsData()
    return fullUnitsLimitData
  }

  function getEventDescByRulesTbl(rulesTbl)
  {
    return ""
  }

  function isStayOnRespScreen()
  {
    return ::stay_on_respawn_screen()
  }

  function isAnyUnitHaveRespawnBases()
  {
    local country = ::get_local_player_country()

    local crewsInfo = ::get_crew_info()
    foreach(crew in crewsInfo)
      if (crew.country == country)
        foreach (slot in crew.crews)
        {
          local airName = ("aircraft" in slot) ? slot.aircraft : ""
          local air = ::getAircraftByName(airName)
          if (air &&
              ::is_crew_available_in_session(slot.idInCountry, false) &&
              ::is_crew_slot_was_ready_at_host(slot.idInCountry, airName, true)
             )
          {
            local respBases = ::get_available_respawn_bases(air.tags)
            if (respBases.len() != 0)
              return true
          }
        }
    return false
  }

  function getCurSpawnScore()
  {
    if (isTeamScoreRespawnEnabled)
      return ::getTblValue("teamSpawnScore", ::get_local_mplayer(), 0)
    return isScoreRespawnEnabled ? ::getTblValue("spawnScore", ::get_local_mplayer(), 0) : 0
  }

  function getMinimalRequiredSpawnScore()
  {
    local minScore = -1
    if (!isScoreRespawnEnabled)
      return minScore

    local country = ::get_local_player_country()
    local crewsInfo = ::get_crew_info()
    foreach(crew in crewsInfo)
      if (crew.country == country)
        foreach (slot in crew.crews)
        {
          local airName = ("aircraft" in slot) ? slot.aircraft : ""
          local air = ::getAircraftByName(airName)
          if (air && ::is_crew_available_in_session(slot.idInCountry, false) && ::is_crew_slot_was_ready_at_host(slot.idInCountry, airName, true))
          {
            local reqScore = ::shop_get_spawn_score(airName, "")
            minScore = minScore >= 0? ::min(reqScore, minScore) : reqScore
          }
        }
    return minScore
  }

  /*
  return [
    {
      unit = unit
      comment  = "" //what need to do to spawn on that unit
    }
    ...
  ]
  */
  function getAvailableToSpawnUnitsData()
  {
    local res = []
    if (!(get_game_type() & (::GT_VERSUS | ::GT_COOPERATIVE)))
      return res
    if (get_game_mode() == ::GM_SINGLE_MISSION || get_game_mode() == ::GM_DYNAMIC)
      return res
    if (!::g_mis_loading_state.isCrewsListReceived())
      return res
    if (getLeftRespawns() == 0)
      return res

    local crews = ::get_crews_list_by_country(::get_local_player_country(), true)
    if (!crews)
      return res

    local curSpawnScore = getCurSpawnScore()
    foreach (c in crews)
    {
      local comment = ""
      local unit = ::g_crew.getCrewUnit(c)
      if (!unit)
        continue

      if (!::is_crew_available_in_session(c.idInCountry, false)
          || !::is_crew_slot_was_ready_at_host(c.idInCountry, unit.name, true)
          || !::get_available_respawn_bases(unit.tags).len()
          || !getUnitLeftRespawns(unit))
        continue

      if (isScoreRespawnEnabled && curSpawnScore >= 0)
      {
        if (curSpawnScore < ::shop_get_spawn_score(unit.name, ""))
          continue
        if (curSpawnScore < ::shop_get_spawn_score(unit.name, ::get_last_weapon(unit.name)))
          comment = ::loc("respawn/withCheaperWeapon")
      }

      res.append({
        unit = unit
        comment = comment
      })
    }

    return res
  }

  function getUnitFuelPercent(unitName) //return 0 when fuel amount not fixed
  {
    local unitsFuelPercentList = ::getTblValue("unitsFuelPercentList", getCustomRulesBlk())
    return ::getTblValue(unitName, unitsFuelPercentList, 0)
  }

  function hasWeaponLimits()
  {
    return getWeaponsLimitsBlk() != null
  }

  function isUnitWeaponAllowed(unit, weapon)
  {
    return getUnitWeaponRespawnsLeft(unit, weapon) != 0
  }

  function getUnitWeaponRespawnsLeft(unit, weapon)
  {
    local limitsBlk = getWeaponsLimitsBlk()
    return limitsBlk ? getWeaponRespawnsLeftByLimitsBlk(unit, weapon, limitsBlk) : -1
  }

  /*************************************************************************************************/
  /************************************PRIVATE FUNCTIONS *******************************************/
  /*************************************************************************************************/

  function getMisStateBlk()
  {
    return ::get_mission_custom_state(false)
  }

  function getMyStateBlk()
  {
    return ::get_user_custom_state(::my_user_id_int64, false)
  }

  function getCustomRulesBlk()
  {
    return ::getTblValue("customRules", ::get_current_mission_info_cached())
  }

  function getTeamDataBlk(team, keyName)
  {
    local teamsBlk = ::getTblValue(keyName, getMisStateBlk())
    if (!teamsBlk)
      return null

    local res = ::getTblValue(::get_team_name_by_mp_team(team), teamsBlk)
    return ::u.isDataBlock(res) ? res : null
  }

  function getMyTeamDataBlk(keyName = "teams")
  {
    return getTeamDataBlk(::get_mp_local_team(), keyName)
  }

  //return -1 when unlimited
  function getUnitLeftRespawnsByTeamDataBlk(unit, teamDataBlk)
  {
    return ::RESPAWNS_UNLIMITED
  }

  function calcFullUnitLimitsData()
  {
    return {
      defaultUnitRespawnsLeft = ::RESPAWNS_UNLIMITED
      unitLimits = [] //::g_unit_limit_classes.LimitBase
    }
  }

  function minRespawns(respawns1, respawns2)
  {
    if (respawns1 == ::RESPAWNS_UNLIMITED)
      return respawns2
    if (respawns2 == ::RESPAWNS_UNLIMITED)
      return respawns1
    return ::min(respawns1, respawns2)
  }

  function getWeaponsLimitsBlk()
  {
    return ::getTblValue("weaponList", getMyStateBlk())
  }

  //return -1 when unlimited
  function getWeaponRespawnsLeftByLimitsBlk(unit, weapon, weaponLimitsBlk)
  {
    if (::getAmmoCost(unit.name, weapon.name, AMMO.WEAPON).isZero())
      return -1

    foreach(blk in weaponLimitsBlk % unit.name)
      if (blk.name == weapon.name)
        return ::max(blk.respawnsLeft || 0, 0)
    return 0
  }
}

//just for case when empty rules will not the same as base
class ::mission_rules.Empty extends ::mission_rules.Base
{
}