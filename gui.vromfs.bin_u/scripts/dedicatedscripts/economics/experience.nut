//calc ranks for ingame events
::event_target_params_tbl <- {
  [::EXP_EVENT_ASSIST] = "assist",
  [::EXP_EVENT_HIT] = "hit",
  [::EXP_EVENT_CRITICAL_HIT] = "critHit"
}

function unit_exp_conversion(unitName, resUnitName) {
  local wpcost = ::get_wpcost_blk()

  local unit = wpcost[unitName]
  local resUnit = wpcost[resUnitName]
  local prevUnit = (resUnit && ("reqAir" in resUnit)) ? wpcost[resUnit.reqAir] : null

  if (!unit || !resUnit)
    return 1.0

  local econExpBlk = get_economy_config_block("ranks")
  local rBlk = ::get_ranks_blk()
  local unit_type = ::get_unit_type_by_unit_name(unitName)
  if (rBlk == null || econExpBlk == null || econExpBlk[unit_type] == null)
  {
    dagor.debug("ERROR: economy.blk or ranks.blk is broken "+unit_type)
    return 0
  }

  local diff = get_mission_mode()
  local param_name = "expMulWithMode"
  local expMul = econExpBlk[unit_type].getReal(param_name+diff.tostring(), 0.0)
  dagor.debug("unit_exp_conversion. ExpMul = " + expMul + ", researching:" + resUnitName + ", played on " + unitName + ", " + EDifficultiesStr[diff])

  if (prevUnit && resUnit.reqAir == unitName && unitName != null)
  {
    param_name = "prevAirExpMulMode"
    expMul *= rBlk.getReal(param_name+diff.tostring(), 0.0)
    dagor.debug("unit_exp_conversion: with research child mul. ExpMul "+expMul+" prevUnit.name "+resUnit.reqAir+" unit.name "+unitName+" resUnitName "+resUnitName)
  }
  else
  {
    local unitEra = unit.rank
    local resUnitEra = resUnit.rank

    local eraDiff = resUnitEra - unitEra
    param_name = "expMulWithTierDiff"
    if (eraDiff < 0)
      if (::isUnitSpecial(unit))
      {
        eraDiff = 0
      }
      else
      {
        param_name += "Minus"
        eraDiff *= -1
      }
    expMul *= rBlk.getReal(param_name+eraDiff.tostring(), 0.0)
    dagor.debug("unit_exp_conversion: with units era difference. ExpMul "+expMul)
  }

  return expMul
}

function set_exp_award(award) {
  local award = {rank = award, player = award, raw = award, noBonus = award, premAcc = award, premMod = award, booster = award, virtPremAcc = award}
  return award
}

function multiply_exp_award(ret, mul) {
  if (typeof(mul) != "table")
    mul = set_exp_award(mul)
  if (typeof(ret) != "table")
    ret = set_exp_award(ret)

  local res = {raw = ret.raw*mul.raw}
  res.noBonus <- ret.noBonus*mul.noBonus
  res.premAcc <- ret.premAcc*mul.premAcc
  res.premMod <- ret.premMod*mul.premMod
  res.booster <- ret.booster*mul.booster
  res.virtPremAcc <- ret.virtPremAcc*mul.virtPremAcc

  res.rank <- 0
  res.player <- 0

  res = round_award(res)
  res = set_final_exp_award(res)

  return res
}

function set_final_exp_award(ret) {
  local award = ret.noBonus + ret.premAcc + ret.premMod + ret.booster
  ret.rank = award
  ret.player = award

  return ret
}

function get_exp_award_mul(curAir, curAirExp, userId, actionType, xpBoosterPercent, rented) {
  local ret = set_exp_award(0)
  local wp_cost = ::get_wpcost_blk()
  local diff = get_mission_mode()
  local es = ::get_economic_state(userId)
  if (!es)
    return ret

  local rBlk = ::get_ranks_blk()
  local econExpBlk = get_economy_config_block("ranks")
  local econWpBlk = get_economy_config_block("warpoints")
  local unit_type = get_unit_type_by_unit_name(curAir)

  if (econExpBlk[unit_type] == null || econWpBlk[unit_type] == null)
  {
    dagor.debug("ERROR: economy.blk is broken: "+unit_type+ " is missing in warpoints or ranks block")
    return ret
  }

  local numBattles = ::get_played_sessions_count_by_user_id(userId)
  if (battle_is_tutorial_for_player(numBattles))
  {
    dagor.debug("get_exp_award_mul - firstBattleTutorial is on. Exp will be given only from on_battle_finished_tutorial. return 0. numBattles = "+numBattles)
    return ret
  }

  local mis = get_current_mission_info_cached()
  if (mis == null)
  {
    dagor.debug("ERROR: on_player_event_mp - get_current_mission_info == null, returning 0");
    return ret
  }

  if ((mis.gt_race && actionType != "raceFinished" && actionType != "kill") ||
      (mis.constantWPAwardName != null && mis.constantWPAwardName != "" && actionType != "missionEnd")||
      (mis.pveWPAwardName != null && mis.pveWPAwardName != "" && actionType != "missionEnd"))
    return ret

  local unitTypeMul = 1.0
  local mul = 1.0
  if (!(mis.pveWPAwardName != null && mis.pveWPAwardName != ""))
  {
    unitTypeMul = econWpBlk[unit_type].getReal(actionType+"MulMode"+diff, 1.0)
    mul = unitTypeMul
    dagor.debug("get_exp_award_mul - expMul calc step 1. mul = "+mul+". with unitTypeMul. airname "+curAir+" unitTypeMul "+unitTypeMul+" unitType "+unit_type+", actionType "+actionType+", mode "+diff)
  }

  if (actionType == "assist" || actionType == "hit" || actionType == "critHit" || actionType == "scoutCritHit" || actionType == "scoutKill")
    return set_exp_award(mul)

  local unitMul = 1.0
  local rentedPremUnitExpMul = 1.0
  if (wp_cost != null && wp_cost[curAir] != null)
  {
    if (wp_cost[curAir].expMul != null)
      unitMul = wp_cost[curAir].expMul

    if (rented && (wp_cost[curAir].costGold != null || wp_cost[curAir].premPackAir))
    {
      rentedPremUnitExpMul = econExpBlk.getReal("rentedPremUnitExpMul", 0.0)
      unitMul *= rentedPremUnitExpMul
    }
  }

  if (!(mis.pveWPAwardName != null && mis.pveWPAwardName != ""))
  {
    local modeMul = econExpBlk[unit_type].getReal("modeMultiplier"+diff.tostring(), 0.0)
    mul *= modeMul*unitMul
    dagor.debug("get_exp_award_mul - expMul calc step 2. mul = "+mul+". with unit and mode. unitMul "+unitMul+", rented: "+rented+", rentedPremUnitExpMul "+rentedPremUnitExpMul+", modeMul "+modeMul+" mode "+diff)
  }

  ret.raw = mul

  local battlesCount = get_battles_count_on_aircraft(curAir, userId)
  local maxRateBattles = econWpBlk.getInt("xpRateForFirstBattlesOnAircraftCount", 0)
  local xpCountBattlesMul = 1.0
  if (battlesCount <= maxRateBattles)
  {
    xpCountBattlesMul = ::get_first_battle_on_aircraft_xp_rate(userId)
    if (xpCountBattlesMul != 1.0)
    {
      mul *= xpCountBattlesMul
      dagor.debug("get_exp_award_mul - expMul calc step 3. mul = "+mul+". with xpCountBattlesMul. xpCountBattlesMul "+xpCountBattlesMul)
    }
  }

  local airRate = ::wp_get_aircraft_xp_rate(curAir, userId)
  if (airRate.tofloat() != 1.0)
  {
    mul *= airRate
    dagor.debug("get_exp_award_mul - expMul calc step 4. mul = "+mul+". with aircraft xp rate. airRate "+airRate)
  }

  local event_mul = ::event_reward_mul_exp
  if (event_mul.tofloat() != 1.0)
  {
    mul *= event_mul
    dagor.debug("get_exp_award_mul - expMul calc step 5. mul = "+mul+". with event xp rate. event rate "+event_reward_mul_exp)
  }

  local addictionMul = es.antiAddictionMultiplier
  if (addictionMul.tofloat() != 1.0)
  {
    mul *= addictionMul
    dagor.debug("get_exp_award_mul - expMul calc step 6. mul = "+mul+". with anti addiction. anti addiction mul "+addictionMul)
  }

  local firstBattleForDay = ::is_first_battles_for_day(userId)
  local xpBoost = 1.0
  if (firstBattleForDay)
  {
    xpBoost = ::get_first_battle_xp_rate(userId)
     if (xpBoost != 1.0)
     {
       mul *= xpBoost
       dagor.debug("get_exp_award_mul - expMul calc step 7. mul = "+mul+". firstBattleMul. xpBoost "+xpBoost)
     }
  }

  ret.noBonus = mul

  local premMul = es.xpMultiplier
  local specialAir = ::player_has_modification(userId, curAir, "premExpMul");
  local premModMul = 1.0
  if ((specialAir && (rBlk.goldPlaneExpMul != null)) && !(mis.pveWPAwardName != null && mis.pveWPAwardName != ""))
    premModMul = rBlk.goldPlaneExpMul;

  if ("cyberCafeLevel" in es && "numSquadMembersInSameCyberCafe" in es)
  {
    local boostCyberCafeLevel = calc_boost_for_cyber_cafe(es.cyberCafeLevel)
    local boostForSquadsFromSameCyberCafe =
                      calc_boost_for_squads_members_from_same_cyber_cafe(es.numSquadMembersInSameCyberCafe)

    dagor.debug("get_exp_award_mul - modify xpBoosterPercent")
    if (boostCyberCafeLevel.xp > 0)
    {
      xpBoosterPercent += boostCyberCafeLevel.xp
      dagor.debug("get_exp_award_mul - level "+es.cyberCafeLevel.tostring()+" boost "+boostCyberCafeLevel.xp.tostring()+
                  " xpBoosterPercent "+xpBoosterPercent)
    }

    if (boostForSquadsFromSameCyberCafe.xp > 0)
    {
      xpBoosterPercent += boostForSquadsFromSameCyberCafe.xp
      dagor.debug("get_exp_award_mul - num in squads "+es.numSquadMembersInSameCyberCafe.tostring()+
                  " boost "+boostForSquadsFromSameCyberCafe.xp.tostring()+" xpBoosterPercent "+xpBoosterPercent)
    }
  }

  ret.premAcc = (premMul-1)*ret.noBonus
  ret.premMod = (premModMul-1)*ret.noBonus
  ret.booster = xpBoosterPercent*ret.noBonus

  if (ret.premAcc > 0 && ret.premMod > 0)
    ret.premAcc *= 2

  local premMulConfig = 0
  if (ret.premAcc == 0)
  {
    premMulConfig = rBlk.xpMultiplier
    if (premMulConfig > 0)
      ret.virtPremAcc = (premMulConfig-1)*ret.noBonus
  }

  ret = set_final_exp_award(ret)
  dagor.debug("get_exp_award_mul - expMul calc step 8. mul = "+ret.rank+". with premAcc, premMod and Boost. premAccExpMul "+premMul+" booster "+xpBoosterPercent+" premMod "+premModMul+" virtPremAcc "+premMulConfig)

  return ret
}

function on_mission_finished_mp(param) {
  local isWon           = param.isWon
  local fake            = param.fake
  local userId = param.userId
  local airname         = param.airname
  local unit_flight_time = param.time//current unit flighttime
  local total_flight_time    = param.total_flight_time//sum of all units flighttime
  local score           = param.score
  local battleTime      = param.battleTime
  local playerSessionTime     = param.total_mission_time //total time player spent in mission
  // local sessionTime = param.sessionTime // player session time(flighttime + time in respawn screen) - used in on_battle_trophy() function
  local sessionTime = ((stat_get_mission_time()+0.5).tointeger()).tofloat() //it is total mission time
  local xpBoosterPercents = param.xpBoosterPercents
  local rented = param.rented
  local early = param.early

  local ret = set_exp_award(0)

  local gt = ::get_game_type()
  if (!(gt & ::GT_USE_XP))
    return set_exp_award(0)

  local mis = ::get_current_mission_info_cached()
  local gm = ::get_game_mode()
  local econExpBlk = get_economy_config_block("ranks")
  local es = ::get_economic_state(userId)
  if (!es)
    return set_exp_award(0)

  local add = 0

  if (isWon)
    dagor.debug("on_mission_finished_mp won")
  else
    dagor.debug("on_mission_finished_mp lost")

  switch (gm)
  {
    case ::GM_TOURNAMENT:
      add = isWon ? econExpBlk.getInt("expForVictoryTournament", 0) : econExpBlk.getInt("expForPlayingTournament", 0)
      ret = set_exp_award(add)
      dagor.debug("on_mission_finished gm = tournament")
      break
    case ::GM_EVENT:
      add = isWon ? econExpBlk.getInt("expForVictoryEvent", 0) : econExpBlk.getInt("expForPlayingEvent", 0)
      ret = set_exp_award(add)
      dagor.debug("on_mission_finished gm = event")
      break
    case ::GM_DOMINATION:
      local mis = ::get_current_mission_info_cached()
      if (mis.pveXPAwardName != null && mis.pveXPAwardName != "")
      {
        dagor.debug("on_mission_finished_mp - domination PVE "+ mis.pveXPAwardName)
        if (isWon && mis.pveCustomUnlockForVictory != null && mis.pveCustomUnlockForVictory != "") {
          open_unlock_for_user(userId, mis.pveCustomUnlockForVictory)
          dagor.debug("Open custom unlock for victory: "+mis.pveCustomUnlockForVictory+" for user: "+userId)
        }
        add = get_pve_award(isWon, "Exp", mis, sessionTime, total_flight_time, unit_flight_time, score)

        local mul = ::get_exp_award_mul(airname, get_aircraft_exp(airname), userId, "missionEnd", 0, rented)
        ret = multiply_exp_award(add, mul)

        dagor.debug("on_mission_finished_mp - domination PVE. Win: "+isWon+" Exp: "+ret.rank+" playerSessionTime "+playerSessionTime+" missionTimeAward "+add)
        break
      }

      local rBlk = ::get_ranks_blk()
      if (!mis.useFinalResults)
        add = (rBlk.getInt("expForVictoryVersus", 0)+rBlk.getInt("expForPlayingVersus", 0))*0.5
      else
        add = isWon ? rBlk.getInt("expForVictoryVersus", 0) : rBlk.getInt("expForPlayingVersus", 0)
      local missionCostMul = mis.missionCostMul != null ? mis.missionCostMul : 0

      add = (add.tofloat() * missionCostMul)
      local time_mul = unit_flight_time
      if (total_flight_time > 0)
        time_mul /= total_flight_time

      local defaultMissionTime = econExpBlk.getInt("defaultMissionTime", 607)
      local useFinalResultsTimeMul = econExpBlk.getReal("useFinalResultsTimeMul", 3.07)
      if (defaultMissionTime > 0)
      {
        if (sessionTime < defaultMissionTime && defaultMissionTime > 0)
          time_mul *= sessionTime/defaultMissionTime
        else
        if (!mis.useFinalResults && total_flight_time > defaultMissionTime*useFinalResultsTimeMul)
        {
          dagor.debug("on_mission_finished_mp !useFinalResults. useFinalResultsTimeMul = "+useFinalResultsTimeMul);
          time_mul = time_mul*total_flight_time/(defaultMissionTime*useFinalResultsTimeMul)
        }
      }

      add *= time_mul

      dagor.debug("on_mission_finished_mp - domination. Exp calc step 1. Exp: "+add+" playerSessionTime "+playerSessionTime+" time_mul "+time_mul+" total_flight_time "+total_flight_time+" sessionTime "+sessionTime+" defaultMissionTime "+defaultMissionTime)

      if (mis.gt_last_man_standing)
      {
        local ffaMul = battle_royale_award_mul(isWon, "exp")
        add *= ffaMul
        local awardAdd = econExpBlk.getInt("ffaBaseSessionAward", 0)
        add += awardAdd
        dagor.debug("on_mission_finished_mp - domination. battle royale Exp calc step 2. Exp: "+add+" battle_royale_award_mul "+ffaMul+" base session award "+awardAdd)
      }
      
      local scoreTime = get_score_time(unit_flight_time, total_flight_time, sessionTime, mis.useFinalResults, useFinalResultsTimeMul)
      local scoreMul = player_activity_coef(score, scoreTime);
      add *= scoreMul

      dagor.debug("on_mission_finished_mp - domination. Exp calc step 3. Exp: "+add+" player_activity_coef "+scoreMul+" scoreTime "+scoreTime)

      local expDefVictoryAward = 0

      if (add > 0 && add < 10)
        expDefVictoryAward = econExpBlk.getInt("expDefVictoryAward", 0)

      local mul = ::get_exp_award_mul(airname, get_aircraft_exp(airname), userId, "missionEnd", xpBoosterPercents, rented)
      ret = multiply_exp_award(add, mul)

      dagor.debug("on_mission_finished_mp - domination. Exp calc step 4. Exp: "+ret.rank+" expDefVictoryAward "+expDefVictoryAward+" xpMul "+mul)

      break
  }

  return ret
}

function on_player_event_target_mp(evType, tbl, userId) {
  local expClass  = tbl.expClass
  local ai        = tbl.ai
  local isAir     = tbl.isAir
  local curAir    = tbl.curAir
  local curAirExp = tbl.curAirExp
  local targetAir = tbl.targetAir
  local xpBoosterPercent = tbl.xpBoosterPercent
  local rented = tbl.rented
  local dmgParam = tbl.param

  local ret = 0
  local eventMul = 1.0
  local actionType = ::event_target_params_tbl[evType]
  local unitType = get_unit_type_by_unit_name(curAir)
  local manualWeapon = tbl.iParam2

  if (unitType == DS_UT_SHIP && evType == EXP_EVENT_HIT && !manualWeapon) return set_exp_award(0)

  if (is_target_ship(targetAir) && evType != EXP_EVENT_CRITICAL_HIT) {//customize award for hits and assists if target is ship
    if(evType == EXP_EVENT_HIT) {
      return set_exp_award(0)
    }
    else if(evType == EXP_EVENT_ASSIST) {
      actionType = "shipAssist"
      ret = ship_get_damage_award(targetAir, dmgParam, (tbl.fParam2 ?? 0), actionType, "ranks")
    }
  }
  else {
    if (is_target_ship(targetAir) && evType == EXP_EVENT_CRITICAL_HIT) {
      tbl.param = 0
      tbl.fParam2 = 0
    }

    ret = unit_kill_exp_award(userId, evType, tbl)
    ret.delay <- 0
    local econWpBlk = get_economy_config_block("warpoints")
    eventMul = econWpBlk.getReal(actionType+"FromKillMul", 0.0)
  }

  local mul = get_exp_award_mul(curAir, curAirExp, userId, actionType, xpBoosterPercent, rented)
  ret = multiply_exp_award(ret, eventMul)
  ret = multiply_exp_award(ret, mul)

  dagor.debug("on_player_event "+actionType+" - Exp = "+ret.rank+", eventMul "+eventMul)

  return on_action_award_exp_return(ret, userId)
}

function on_player_event_mp(evType, tbl, userId) {
  local param = tbl.param
  local curAir    = tbl.curAir
  local curAirExp = tbl.curAirExp
  local xpBoosterPercent = tbl.xpBoosterPercent
  local actionType = "event"
  local rented = tbl.rented

  local ret = set_exp_award(0)
  local timeAward = 0

  local gt = ::get_game_type()
  if (!(gt & ::GT_USE_XP))
  {
    dagor.debug("on_player_event_mp - !GT_USE_XP")
    return set_exp_award(0)
  }

  local econExpBlk = get_economy_config_block("ranks")

  local es = ::get_economic_state(userId)
  if (!es)
    return set_exp_award(0)

  local add = 0

  if (gt & ::GT_VERSUS)
  {
    switch(evType)
    {
    case ::EXP_EVENT_RACE_FINISHED:
      local rBlk = ::get_ranks_blk()
      local pathLength = tbl.param
      local place = tbl.flags+1
      local isWinner = tbl.iParam2 //0 - false
      local leaderTime = tbl.fParam2
      local mis = get_current_mission_info_cached()
      if (mis == null)
      {
        dagor.debug("ERROR: on_player_event_mp - get_current_mission_info == null, returning 0");
        return set_exp_award(0)
      }
      local maxPlayers = mis.maxPlayers-1
      local maxSessionRank = 25
      if (mis.ranks != null && mis.ranks.max != null)
        maxSessionRank = mis.ranks.max

      if (isWinner)
        add = rBlk.getInt("expForVictoryVersus", 0) * econExpBlk.getReal("expMulForRaceVictory", 0)
      else
        add = rBlk.getInt("expForPlayingVersus", 0) * econExpBlk.getReal("expMulForRacePlay", 0)

      dagor.debug("on_player_event_mp - Race finished. Step 1. Exp: "+ add)

      local race_type = ::DS_UT_AIRCRAFT
      local unit_type = get_unit_type_by_unit_name(curAir)
      if (unit_type != "exp_fighter" && unit_type != "exp_bomber" && unit_type != "exp_assault")
        race_type = ::DS_UT_TANK

      local raceMul = race_finished_mul_calc(place, isWinner, maxPlayers, leaderTime, pathLength, maxSessionRank, race_type)
      add = add * raceMul

      actionType = "raceFinished"
      dagor.debug("on_player_event_mp - Race finished. Step 2. Exp = "+ add+" raceMul "+raceMul)
      break;
    case ::EXP_EVENT_LANDING:
      // param == 0 - landing NOT on airfield
      // param == -1.f - landing on airfield (not carrier)
      // param == 1.f - landing on carrier
      add = (param > 0) ? econExpBlk.getInt("expForCarrierLanding", 0) : econExpBlk.getInt("expForLanding", 0)
      if (param != 0 && roguelike_econMode_players_list[userId.tostring()+"_exp"].rank > add)
      {
        add = roguelike_econMode_players_list[userId.tostring()+"_exp"]
        roguelike_econMode_players_list[userId.tostring()+"_exp"] <- set_exp_award(0)
        dagor.debug("on_player_event_mp - Landing roguelike mode on. You made it! Exp: "+ add.rank)
        return add
      }
      dagor.debug("on_player_event_mp - Exp calc step 1. Landing. Exp: "+ add)
      actionType = "landing"
      break;
    case ::EXP_EVENT_TAKEOFF:
      add = (param > 0) ? econExpBlk.getInt("expForCarrierTakeoff", 0) : econExpBlk.getInt("expForTakeoff", 0)
      dagor.debug("on_player_event_mp - Exp calc step 1. Take off. Exp: "+ add)
      actionType = "takeOff"
      break;
    case ::EXP_EVENT_CAPTURE_ZONE:
      {
        local zone_flags = tbl.flags
        if (zone_flags & ::CAPTURE_ZONE_CAN_CAPTURE_ON_GROUND)
        {
          add = econExpBlk.getInt("expForCaptureLand", 0) * param / 100
          actionType = "captureLand"
        }
        else
        if (zone_flags & ::CAPTURE_ZONE_CAN_CAPTURE_IN_AIR)
        {
          add = econExpBlk.getInt("expForCaptureAir", 0) * param / 100
          actionType = "captureAir"
        }
        else
        if (zone_flags & ::CAPTURE_ZONE_CAN_CAPTURE_BY_GM)
        {
          add = econExpBlk.getInt("expForCaptureLand", 0) * param / 100
          actionType = "captureLand"
        }
        dagor.debug("on_player_event_mp - Exp calc step 1. Capture land. Exp: "+ add + " param " + param + " zone_flags " + zone_flags)
      }
      break;
    case EXP_EVENT_DAMAGE_ZONE:
      local expForBaseDamage = econExpBlk.getReal("expForBaseDamage", 0.0)
      add = ((param > 0) ? expForBaseDamage * param : 0)
      dagor.debug("on_player_event_mp - Exp calc step 1. Base damage. Exp: "+ add+", param "+param+", expForBaseDamage "+expForBaseDamage)
      actionType = "damageBase"
      timeAward = econExpBlk.getReal("timeAward_"+actionType,0.0) * param
      break;
    case EXP_EVENT_DESTROY_ZONE:
      dagor.debug("on_player_event_mp - Destroy Zone called with param "+param)
      local expForBaseDestruction = econExpBlk.getReal("expForBaseDestruction", 0.0)
      add = ((param > 0) ? expForBaseDestruction * param : 0)
      dagor.debug("on_player_event_mp - Exp calc step 1. Base destruction. Exp: "+ add+", param "+param+", expForBaseDestruction "+ expForBaseDestruction)
      actionType = "destroyBase"
      break;
    case ::EXP_EVENT_SIGHT:
        add = econExpBlk.getInt("expForSightingEnemy", 0)
        dagor.debug("on_player_event_mp - Exp calc step 1. Enemy sight. Exp: "+ add)
        actionType = "enemySighting"
      break
    case ::EXP_EVENT_SCOUT:
      add = econExpBlk.getInt("expForScout", 0)
      dagor.debug("on_player_event_mp - Exp calc step 1. Enemy scout. Exp: " + add)
      actionType = "scout"
      break;
    case ::EXP_EVENT_SCOUT_CRITICAL_HIT:
      add = econExpBlk.getInt("expForScoutCritHit", 0)
      dagor.debug("on_player_event_mp - Exp calc step 1. Enemy scoutCritHit. Exp: " + add)
      actionType = "scoutCritHit"
      break;
    case ::EXP_EVENT_SCOUT_KILL:
      add = econExpBlk.getInt("expForScoutKill", 0)
      dagor.debug("on_player_event_mp - Exp calc step 1. Enemy scoutKill. Exp: " + add)
      actionType = "scoutKill"
      break;
    case ::EXP_EVENT_SCOUT_KILL_UNKNOWN:
      add = econExpBlk.getInt("expForScoutKillUnknown", 0)
      dagor.debug("on_player_event_mp - Exp calc step 1. Enemy scoutKillUnknown. Exp: " + add)
      actionType = "scoutKillUnknown"
      break;
    default:
      break;
    }
  }

  if (add < 0)
  {
    dagor.debug("[ERROR] on_local_player_event_mp: EXP = " + add+", param = "+param)
    return set_exp_award(0)
  }

  local mul = ::get_exp_award_mul(curAir, curAirExp, userId, actionType, xpBoosterPercent, rented)
  ret = multiply_exp_award(add, mul)
  ret.delay <- -timeAward.tointeger()

  dagor.debug("on_player_event_mp - Exp calc step 3. Exp: "+ret.rank+" ret.delay "+ret.delay)

  return on_action_award_exp_return(ret, userId)
}

function on_mission_objective_mp(param) {
  local userId = param.userId
  local score = param.score
  local time = param.time
  local isPrimary = param.isPrimary
  local xpBoosterPercents = param.xpBoosterPercents
  local gt = ::get_game_type()

  if (!(gt & ::GT_USE_XP)) {
    dagor.debug("on_player_event_mp - !GT_USE_XP")
    return set_exp_award(0)
  }

  local ret = set_exp_award(0)
  return ret
}

function unit_kill_exp_award(userId, evType, tbl) {
  local expClass = tbl.expClass
  local ai = tbl.ai
  local air = tbl.isAir
  local curAir    = tbl.curAir
  local curAirExp = tbl.curAirExp
  local targetAir = tbl.targetAir
  local xpBoosterPercent = tbl.xpBoosterPercent
  local targetType = "air"
  local rented = tbl.rented
  local dmgParam = tbl.param

  local ret = set_exp_award(0)
  local gt = ::get_game_type()
  if (!(gt & ::GT_USE_XP))
  {
    dagor.debug("unit_kill_exp_award - !GT_USE_XP")
    return set_exp_award(0)
  }

  local gm = ::get_game_mode()
  local blk = ::get_ranks_blk()
  local econExpBlk = get_economy_config_block("ranks")
  local econCommonBlk = get_economy_config_block("common")

  local mul = 1.0

  local exp_class_coef = econCommonBlk.units.getReal(expClass, 0.0)
  local defKillCost = econExpBlk.getInt("defKillCost", 0)

  if (!air)
      targetType = "ground"

  if (is_target_ship(targetAir)) {
    local targetShipSubtype = get_ship_subtype_by_exp_class(targetAir)
    defKillCost = econExpBlk.getInt("defKillCost_"+targetShipSubtype, 0)
    local dmgAward = ship_get_damage_award(targetAir, dmgParam, (tbl.fParam2 ?? 0), "kill", "ranks")
    defKillCost += dmgAward
    dagor.debug("unit_kill_exp_award - Exp calc step 1. Exp: defKillCost "+defKillCost+" award for damage "+dmgAward+" target "+targetShipSubtype)
    targetType = "ship"
  }

  local add = exp_class_coef*defKillCost
  dagor.debug("unit_kill_exp_award - Exp calc step 2. Exp: "+add+" defKillCost "+defKillCost+" exp_class_coef "+exp_class_coef)

  if (add > 0) {
    if (ai) {
      local botMultiplier = econExpBlk.getReal("botMultiplier", 0.0)
      add *= botMultiplier
      dagor.debug("unit_kill_exp_award - Exp calc step 3. Exp: "+add+". Ai and bots only. blk.botMultiplier "+botMultiplier)
    }
    else  {
      if (targetType != "ship") {//ignore rankDiff multiplier for ships because they have another award calculation logic
        local ourRank = ::get_economic_rank_by_unit_name(curAir);
        local targetRank = ::get_economic_rank_by_unit_name(targetAir);
        local x = targetRank - ourRank
        mul = pow(econExpBlk.getReal("rankDiffA", 0.0), x)
        add = (add.tofloat() * mul).tointeger()
        dagor.debug("unit_kill_exp_award - Exp calc step 3. Exp: "+add+". Players only. ourRank "+ourRank+
                    " targetRank "+targetRank+" rankDiff "+x+" rankDiffCoef "+mul)
      }
      local timeAwardKill = econExpBlk.getInt("timeAwardKill", 0)
      ret.delay <- -timeAwardKill
    }

    mul = get_exp_award_mul(curAir, curAirExp, userId, targetType+"Kill", xpBoosterPercent, rented)
    ret = multiply_exp_award(add, mul)

    dagor.debug("unit_kill_exp_award - Exp calc step 4. Exp: "+ret.rank+" mul "+mul.rank)
  }
  else
    dagor.debug("unit_kill_exp_award - Exp calc Error: add <= 0. add "+add)

  return ret
}

function on_unit_killed_mp(evType, tbl, userId) {
  local ret = unit_kill_exp_award(userId, evType, tbl)
  return on_action_award_exp_return(ret, userId)
}

function on_action_award_exp_return(award, userId) {
  award = roguelike_mode_awards(award, "exp", userId)
  return award
}

function on_battle_finished_mp(param)
{
  //calculates EXP for battleTime
  local diff            = get_mission_mode()
  local diff_name       = get_econRank_emode_name(diff)
  local userId = param.userId
  local airname         = param.airname
  local battleTime      = param.battleTime
  local xpBoosterPercents = param.xpBoosterPercents
  local rented = param.rented

  if (battleTime == 0)
  {
    dagor.debug("battleTime for "+airname+" = 0")
    return set_exp_award(0)
  }

  local gt = ::get_game_type()
  if (!(gt & ::GT_USE_XP))
    return set_exp_award(0)

  local econExpBlk = get_economy_config_block("ranks")
  local expForBattleTime = econExpBlk.getReal("expForBattleTime", 0.0)

  local ws_cost = ::get_wpcost_blk()
  if (ws_cost[airname] == null)
  {
    dagor.debug("[ERROR]: No airname "+airname+" in wpcost")
    return set_exp_award(0)
  }

  local avgBattleTime = ws_cost[airname].getReal("battleTime"+diff_name, 120.0)

  if (avgBattleTime < battleTime)
    battleTime = avgBattleTime

  local award = expForBattleTime*battleTime

  local mul = ::get_exp_award_mul(airname, get_aircraft_exp(airname), userId, "battleTime", xpBoosterPercents, rented)
  local ret = multiply_exp_award(award, mul)

  dagor.debug("on_battle_finished_mp. Exp = "+ret.rank+", expMul "+mul.rank+", time "+battleTime+", expForBattleTime "+expForBattleTime+", avgBattleTime "+avgBattleTime)

  return ret
}
dagor.debug("experience script loaded")