function set_wp_award(award) {
  local award = {wp = award, raw = award, noBonus = award, premAcc = award, booster = award, effCoef = award, virtPremAcc = award}
  return award
}

function on_action_award_wp_return(award, userId) {
  award = roguelike_mode_awards(award, "wp", userId)
  return award
}

function multiply_wp_award(ret, mul) {
  if (typeof(mul) != "table")
    mul = set_wp_award(mul)
  if (typeof(ret) != "table")
    ret = set_wp_award(ret)

  local res = {raw = ret.raw*mul.raw}
  res.noBonus <- ret.noBonus*mul.noBonus
  res.premAcc <- ret.premAcc*mul.premAcc
  res.booster <- ret.booster*mul.booster
  res.virtPremAcc <- ret.virtPremAcc*mul.virtPremAcc
  res.wp <- 0

  res = round_award(res)
  res = set_final_wp_award(res)

  res.effCoef <- ret.effCoef*mul.effCoef

  return res
}

function set_final_wp_award(ret) {
  local award = ret.noBonus + ret.premAcc + ret.booster
  ret.wp = award

  return ret
}

function get_wp_award_mul(airname, actionType, userId, wpBoosterPercents, friendly, rented) {
  local ret = set_wp_award(0)
  local mul = 1.0
  local ws = ::get_warpoints_blk()
  local ws_cost = ::get_wpcost_blk()
  local diff = get_mission_mode()
  local diff_name = get_econRank_emode_name(diff)
  local unit_type = get_unit_type_by_unit_name(airname)
  local econWpBlk = get_economy_config_block("warpoints")

  local es = ::get_economic_state(userId)
  if (!es)
    return set_wp_award(0)

  if (ws_cost[airname] == null)
  {
    dagor.debug("ERROR: No airname "+airname+" in wpcost.blk")
    return set_wp_award(0)
  }

  if (unit_type == ::DS_UT_SHIP) {
    unit_type = get_ship_subtype_by_exp_class(ws_cost[airname]["unitClass"])
  }


  if (econWpBlk[unit_type] == null)
  {
    dagor.debug("ERROR: economy.blk is broken "+unit_type)
    return set_wp_award(0)
  }

  local mis = get_current_mission_info_cached()
  if (mis == null)
  {
    dagor.debug("ERROR: on_player_event_mp - get_current_mission_info == null, returning 0");
    return set_wp_award(0)
  }

  if ("cyberCafeLevel" in es && "numSquadMembersInSameCyberCafe" in es)
  {
    local boostCyberCafeLevel = calc_boost_for_cyber_cafe(es.cyberCafeLevel)
    local boostForSquadsFromSameCyberCafe =
                      calc_boost_for_squads_members_from_same_cyber_cafe(es.numSquadMembersInSameCyberCafe)

    dagor.debug("get_wp_award_mul - modify wpBoosterPercents")
    if (boostCyberCafeLevel.wp > 0)
    {
      wpBoosterPercents += boostCyberCafeLevel.wp
      dagor.debug("get_wp_award_mul - level "+es.cyberCafeLevel.tostring()+" boost "+boostCyberCafeLevel.wp.tostring()+
                  " wpBoosterPercents "+wpBoosterPercents)
    }

    if (boostForSquadsFromSameCyberCafe.wp > 0)
    {
      wpBoosterPercents += boostForSquadsFromSameCyberCafe.wp
      dagor.debug("get_wp_award_mul - num in squads "+es.numSquadMembersInSameCyberCafe.tostring()+
                  " boost "+boostForSquadsFromSameCyberCafe.wp.tostring()+" wpBoosterPercents "+wpBoosterPercents)
    }
  }

  dagor.debug("get_wp_award_mul step 1. Air "+airname+", actionType "+actionType+", unit_type "+unit_type)

  if ((mis.gt_race && actionType != "raceFinished") ||
      (mis.constantWPAwardName != null && mis.constantWPAwardName != "" && actionType != "missionEnd") ||
      (mis.pveWPAwardName != null && mis.pveWPAwardName != "" && actionType != "missionEnd"))
    return set_wp_award(0)

  local diffMul = econWpBlk[unit_type].getReal(actionType+"MulMode"+diff.tostring(), 1.0)
  if (diffMul.tofloat() != 1.0)
  {
    mul *= diffMul
    dagor.debug("get_wp_award_mul step 2. mul = "+mul+" withModeMul. mode "+diff+" diffMul "+diffMul+" unit_type "+unit_type)
  }

  if (actionType == "assist" || actionType == "hit" || actionType == "critHit"  || actionType == "scoutCritHit" || actionType == "scoutKill")
    return set_wp_award(mul)

  ret.effCoef = 0

  local premAccMull = es.wpMultiplier
  local premMulConfig = ws.wpMultiplier != null ? ws.wpMultiplier : 0
  if (actionType == "battleTime")
  {
    local wpMul = ((ws.battleTimePremMul != null) ? ws.battleTimePremMul : 1.0)
    if (premAccMull > 1)
      premAccMull *= wpMul
    else
     premMulConfig *= wpMul
  }
  else
  if (actionType != "missionEnd" && actionType != "raceFinished")
  {
    ret.effCoef = mul
    
    local wpMul = ((ws_cost[airname]["rewardMul"+diff_name] != null) ? ws_cost[airname]["rewardMul"+diff_name] : 1.0)
    local rentedPremUnitWPMul = 1.0
    if (rented && (ws_cost[airname].costGold != null || ws_cost[airname].premPackAir))
    {
      rentedPremUnitWPMul = econWpBlk.getReal("rentedPremUnitWPMul", 1.0)
      wpMul *= rentedPremUnitWPMul
    }

    if (wpMul.tofloat() != 1.0)
    {
      mul *= wpMul
      dagor.debug("get_wp_award_mul step 3. mul = "+mul+" withAirMul. airMul "+wpMul+", rented: "+rented+", rentedPremUnitWPMul "+rentedPremUnitWPMul)
    }
  }

  ret.raw = mul

  local airRate = ::wp_get_aircraft_wp_rate(airname, userId)
  if (airRate.tofloat() != 1.0 && !friendly)
  {
    mul *= airRate
    dagor.debug("get_wp_award_mul step 4. mul = "+mul+". withRates. airRate "+airRate)
  }

  if (event_reward_mul_wp.tofloat() != 1.0 && !friendly)
  {
    mul *= event_reward_mul_wp
    dagor.debug("get_wp_award_mul step 5. mul = "+mul+". with event rates. event Rate "+event_reward_mul_wp)
  }

  local mulAAS = es.antiAddictionMultiplier
  if (mulAAS.tofloat() != 1.0)
  {
    if (friendly)
      mulAAS = 1.0

    mul *= mulAAS
    dagor.debug("get_wp_award_mul step 6. mul = "+mul+". with aas. anti addict wp "+mulAAS+" friendly "+friendly)
  }

  local firstBattleForDay = ::is_first_battles_for_day(userId)
  local wpBoost = 1.0
  if (firstBattleForDay)
  {
    wpBoost = get_first_battle_wp_rate(userId)
    if (wpBoost.tofloat() != 1.0)
    {
      mul *= wpBoost
      dagor.debug("get_wp_award_mul step 7. mul = "+mul+" firstBattle. wpBoost "+wpBoost)
    }
  }

  ret.noBonus = mul

  if (!friendly)
  {
    ret.premAcc = (premAccMull-1)*ret.noBonus
    ret.booster = wpBoosterPercents*ret.noBonus

    if (ret.premAcc > 0)
      premMulConfig = 0
    else
      ret.virtPremAcc = (premMulConfig-1)*ret.noBonus

    ret = set_final_wp_award(ret)
    dagor.debug("get_wp_award_mul step 8. mul = "+ret.wp+". with prem and boosters. wpPremMul "+premAccMull+" actionType "+actionType+" booster percents "+wpBoosterPercents+" virtPremAcc "+premMulConfig)
  }
  else
  {
    ret.wp = ret.noBonus
    ret.effCoef = 0
    ret.raw = 0
    dagor.debug("get_wp_award_mul step 8. skip prem and booster for friendly fire")
  }

  return ret
}

function kill_award_calc(userId, targetName, myairname, wpBoosterPercents, friendly, ai, targetType, rented, dmgTbl = null) {
  local gt = ::get_game_type()
  if (!(gt & ::GT_USE_WP))
    return set_wp_award(0)

  local ws_cost = ::get_wpcost_blk()
  local econWpBlk = get_economy_config_block("warpoints")
  local econCommonBlk = get_economy_config_block("common")

  local classMult = 0.0
  local groundKillMul = 1.0

  local award = 1.0
  local aiKillK = econWpBlk.getReal("aiKillK", 0.0)
  if (ai)
    award *= aiKillK
  local aKill = econWpBlk.getReal("aKill", 0.0)

  if (targetType == "air") {
    if (ws_cost[targetName] != null && ws_cost[targetName].unitClass != null)
      classMult = econCommonBlk.units.getReal(ws_cost[targetName].unitClass, 0.0)
  }
  else if (is_target_ship(targetName)) {
    local targetShipSubtype = get_ship_subtype_by_exp_class(targetName)
    aKill = econWpBlk.getReal("aKill_"+targetShipSubtype, 0.0)
    local dmgAward = ship_get_damage_award(targetName, dmgTbl?["playerDamage"], dmgTbl?["totalDamage"], "kill")
    aKill += dmgAward
    targetType = "ship"
    classMult = econCommonBlk.units.getReal(targetName, 0.0)
    dagor.debug("kill_award_calc. Ship. Step 1. aKill "+aKill+" award for damage: "+dmgAward+" target "+targetShipSubtype)
  }
  else {
    if (ws_cost[myairname] != null && ws_cost[myairname].groundKillMul != null)
      groundKillMul = ws_cost[myairname].groundKillMul

    classMult = econCommonBlk.units.getReal(targetName, 0.0)
  }

  award *= aKill
  award *= classMult
  local friendlyKillK = econWpBlk.getReal("friendlyKillK", -5)
  if (friendly)
    award *= friendlyKillK


  local mul = get_wp_award_mul(myairname, targetType+"Kill", userId, wpBoosterPercents, friendly, rented)
  award = multiply_wp_award(award, mul)
  dagor.debug("kill_award_calc Wp = "+award.wp+" mul "+mul.wp+", classMult "+classMult+
              " groundKillMul "+groundKillMul+" target "+targetName+" ai "+ai+" aiKillK "+aiKillK+
              " friendlyKillK "+friendlyKillK+" friendly "+friendly+" targetType "+targetType+" effCoef "+award.effCoef)

  return award
}

function versus_air_kill_award(userId, tbl) {
  local airname = tbl.targetAirName
  local weapon = tbl.weapon
  local myKill = tbl.myKill
  local friendly = tbl.friendly
  local myairname = tbl.curAir
  local ai = tbl.ai
  local wpBoosterPercents = tbl.wpBoosterPercents
  local rented = tbl.rented

  local gt = ::get_game_type()
  if (!(gt & ::GT_USE_WP))
    return set_wp_award(0)

  if (!myKill)
    return set_wp_award(0)

  local award = kill_award_calc(userId, airname, myairname, wpBoosterPercents, friendly, ai, "air", rented)
  return on_action_award_wp_return(award, userId)
}

function versus_ground_kill_award(userId, tbl) {
  local expclass = tbl.expclass
  local airname = tbl.curAir
  local friendly = tbl.friendly
  local ai = tbl.ai
  local wpBoosterPercents = tbl.wpBoosterPercents
  local rented = tbl.rented
  local damageTbl = {
    totalDamage = tbl.fParam2
    playerDamage = tbl.param
  }

  local award = kill_award_calc(userId, expclass, airname, wpBoosterPercents, friendly, ai, "ground", rented, damageTbl)
  return on_action_award_wp_return(award, userId)
}

function on_warpoint_event_mp(evType, tbl, userId) {
  local param     = tbl.param
  local isAir     = tbl.isAir
  local targetAir = tbl.targetAir
  local ai        = tbl.ai
  local curAir    = tbl.curAir
  local curWeap   = tbl.curWeap
  local wpBoosterPercents = tbl.wpBoosterPercents
  local actionType = "event"
  local friendly = false
  local rented = tbl.rented
  local targetType = "air"
  local manualWeapon = tbl.iParam2

  if (!isAir)
    targetType = "ground"

  local gt = ::get_game_type()

  if (!(gt & ::GT_USE_WP))
    return set_wp_award(0)

  local es = ::get_economic_state(userId)
  if (!es)
    return set_wp_award(0)

  local wp_cost = ::get_wpcost_blk()
  local econWpBlk = get_economy_config_block("warpoints")

  local wpForCaptureLandAdd = econWpBlk.getInt("wpForCaptureLandAdd", 0);
  local wpMul = 1.0

  local award = 0
  if (gt & ::GT_VERSUS)
  {
    switch(evType)
    {
    case ::EXP_EVENT_RACE_FINISHED:
      {
        local pathLength = tbl.param
        local place = tbl.flags+1
        local isWinner = tbl.iParam2 //0 - false
        local leaderTime = tbl.fParam2
        local mis = get_current_mission_info_cached()

        if (mis == null)
        {
          dagor.debug("ERROR: on_player_event_mp - get_current_mission_info == null, returning 0");
          return set_wp_award(0)
        }
        local maxPlayers = mis.maxPlayers-1
        local maxSessionRank = 25
        if (mis.ranks != null && mis.ranks.max != null)
          maxSessionRank = mis.ranks.max

        local unitRank = ::get_economic_rank_by_unit_name(curAir)
        local baseAwardPow = econWpBlk.getReal("baseRaceAwardPow", 0.0)
        local baseAwardMul = econWpBlk.getInt("baseRaceAwardMul", 0)
        local baseAwardAdd = econWpBlk.getInt("baseRaceAwardAdd", 0)

        award = pow(unitRank, baseAwardPow) * baseAwardMul + baseAwardAdd

        dagor.debug("on_warpoint_event_mp - Wp calc step 1. Race finished. Wp: "+ award+" unitRank "+unitRank+" baseAwardPow "+baseAwardPow+" baseAwardMul "+baseAwardMul+" baseAwardAdd "+baseAwardAdd)

        local winRaceAwardMul = econWpBlk.getReal("winRaceAwardMul", 0.0)
        local winRaceAwardPow = econWpBlk.getReal("winRaceAwardPow", 0.0)
        winRaceAwardMul *= pow(maxPlayers*1.0 / 32, winRaceAwardPow)
        if (isWinner)
          award *= winRaceAwardMul


        local race_type = get_unit_type_by_unit_name(curAir)
        local raceMul = race_finished_mul_calc(place, isWinner, maxPlayers, leaderTime, pathLength, maxSessionRank, race_type)
        award *= raceMul
        dagor.debug("on_warpoint_event_mp - Wp calc step 2. Race finished. Wp: "+ award+" isWinner "+isWinner+" winRaceAwardMul "+winRaceAwardMul+" raceMul "+raceMul)

        actionType = "raceFinished"
      }
      break;
    case ::EXP_EVENT_CAPTURE_ZONE:
      award = ((param > 0) ? wpForCaptureLandAdd * param : econWpBlk.getReal("wpForCaptureAir", 0.0) * (-param)) / 100
      actionType = "captureLand"
      dagor.debug("on_warpoint_event_mp - Wp calc step 1. Capture zone. Wp: " + award+" param "+param)
      break;

    case ::EXP_EVENT_DESTROY_ZONE:
      local tier = wp_cost[curAir] != null ? wp_cost[curAir].rank : 0
      local param_name = "wpForDestroyBase_tier"+tier
      local wpForDestroyBase = econWpBlk.getReal(param_name, 0.0)
      award = (wpForDestroyBase * (param > 0 ? param : ((-param) * econWpBlk.getReal("friendlyKillK", -5))))  //param is negative for friendly zone

      actionType = "destroyBase"
      dagor.debug("on_warpoint_event_mp - Wp calc step 1. Destroy zone. Wp: " + award+" param "+param+", wpForDestroyBase = "+wpForDestroyBase+", unit tier "+tier)
      break;

    case ::EXP_EVENT_DAMAGE_ZONE:
      local tier = wp_cost[curAir] != null ? wp_cost[curAir].rank : 0
      local param_name = "wpForDamageBase_tier"+tier
      local wpForDamageBase = econWpBlk.getReal(param_name, 0.0)
      award = (wpForDamageBase * (param > 0 ? param : ((-param) * econWpBlk.getReal("friendlyKillK", -5))))  //param is negative for friendly zone

      actionType = "damageBase"
      dagor.debug("on_warpoint_event_mp - Wp calc step 1. Damage zone. Wp: " + award+" param "+param+", wpForDamageBase = "+wpForDamageBase+", unit tier "+tier)
      break;

    case ::EXP_EVENT_CRITICAL_HIT:
      award = kill_award_calc(userId, targetAir.tostring(), curAir.tostring(), wpBoosterPercents, false, ai, targetType, rented, { "playerDamage" : 0, "totalDamage" : 0 })

      actionType = "critHit"
      local critHitFromKillMul = econWpBlk.getReal("critHitFromKillMul", 0.0)
      award = multiply_wp_award(award, critHitFromKillMul)
      dagor.debug("on_warpoint_event_mp - Wp calc step 1. Critical Hit. Wp: " + award.wp+" critHitFromKillMul "+critHitFromKillMul)
      break;
    case ::EXP_EVENT_HIT:
      local unitType = get_unit_type_by_unit_name(curAir)
      if (is_target_ship(targetAir)) {
        actionType = "shipHit"
        award = ship_get_damage_award(targetAir, param, 0, actionType)
      }
      else if(!manualWeapon && unitType == DS_UT_SHIP) {
        return set_wp_award(0)
      }
      else {
        award = kill_award_calc(userId, targetAir.tostring(), curAir.tostring(), wpBoosterPercents, false, ai, targetType, rented)
        local hitFromKillMul = econWpBlk.getReal("hitFromKillMul", 0.0)
        award = multiply_wp_award(award, hitFromKillMul)
        actionType = "hit"
        dagor.debug("on_warpoint_event_mp - Wp calc step 1. Hit. Wp: " + award.wp+" hitFromKillMul "+hitFromKillMul)
      }

      break;
    case ::EXP_EVENT_ASSIST:
      if (is_target_ship(targetAir)) {

        local totalDamageInflicted = tbl.fParam2
        local playerDamage = tbl.param
        actionType = "shipAssist"

        award = ship_get_damage_award(targetAir, playerDamage, totalDamageInflicted, actionType)
      }
      else {

        award = kill_award_calc(userId, targetAir.tostring(), curAir.tostring(), wpBoosterPercents, false, ai, targetType, rented)

        local assistFromKillMul = econWpBlk.getReal("assistFromKillMul", 0.0)
        award = multiply_wp_award(award, assistFromKillMul)
        actionType = "assist"
        dagor.debug("on_warpoint_event_mp - Wp calc step 1. Assist. Wp: " + award.wp+" assistFromKillMul "+assistFromKillMul)
      }

      break;
    case ::EXP_EVENT_LANDING:
      if (param != 0 && roguelike_econMode_players_list[userId.tostring()+"_wp"].wp > 0)
      {
        award = roguelike_econMode_players_list[userId.tostring()+"_wp"]
        roguelike_econMode_players_list[userId.tostring()+"_wp"] <- set_wp_award(0)
        dagor.debug("on_warpoint_event_mp - Landing roguelike mode on. You made it! Wp: " + award.wp)
        return award
      }
      return set_wp_award(0)
    case ::EXP_EVENT_SCOUT:
      award = econWpBlk.getReal("wpForScout", 0)
      actionType = "scout"
      award = multiply_wp_award(award, 1.0)
      dagor.debug("on_warpoint_event_mp - Wp calc step 1. Scout. Wp: " + award.wp)
      break;
    case ::EXP_EVENT_SCOUT_CRITICAL_HIT:
      award = kill_award_calc(userId, targetAir.tostring(), curAir.tostring(), wpBoosterPercents, false, ai, targetType, rented)
      
      local scoutCritHitMul = econWpBlk.getReal("scoutCritHitMul", 0.0)
      actionType = "scoutCritHit"
      award = multiply_wp_award(award, scoutCritHitMul)
      dagor.debug("on_warpoint_event_mp - Wp calc step 1. ScoutCritHit. Wp: " + award.wp + ", scoutCritHitMul " + scoutCritHitMul)
      break;
    case ::EXP_EVENT_SCOUT_KILL:
      award = kill_award_calc(userId, targetAir.tostring(), curAir.tostring(), wpBoosterPercents, false, ai, targetType, rented)

      local scoutKillMul = econWpBlk.getReal("scoutKillMul", 0.0)
      actionType = "scoutKill"
      award = multiply_wp_award(award, scoutKillMul)
      dagor.debug("on_warpoint_event_mp - Wp calc step 1. ScoutKill. Wp: " + award.wp + ", scoutKillMul " + scoutKillMul)
      break;
    case ::EXP_EVENT_SCOUT_KILL_UNKNOWN:
      award = econWpBlk.getReal("wpForScoutKillUnknown", 0)
      actionType = "scoutKillUnknown"
      award = multiply_wp_award(award, 1.0)
      dagor.debug("on_warpoint_event_mp - Wp calc step 1. ScoutKillUnknown. Wp: " + award.wp)
      break;
    default:
      return set_wp_award(0)
    }
  }

  if (typeof(award) != "table")
    award = set_wp_award(award)

  if (award.wp < 0)
    friendly = true
  local mul = get_wp_award_mul(curAir.tostring(), actionType, userId, wpBoosterPercents, friendly, rented)
  award = multiply_wp_award(award, mul)

  dagor.debug("on_warpoint_event_mp - Wp calc final WP = " + award.wp+" unit "+curAir+" mul "+mul.wp+" effCoef "+award.effCoef)

  return on_action_award_wp_return(award, userId)
}

function versus_battle_time_award(param, userId) {
//WP battleTime award

  local gt = ::get_game_type()
  if (!(gt & ::GT_USE_WP))
    return set_wp_award(0)

  local airname    = param.airname
  local battleTime = param.battleTime
  local playerAliveTime = param.playerAliveTime

  local ws_cost = ::get_wpcost_blk()
  local diff = get_mission_mode()
  local diff_name = get_econRank_emode_name(diff)
  local mis = get_current_mission_info_cached()

  if (ws_cost[airname] == null)
  {
    dagor.debug("[ERROR]: No airname "+airname+" in wpcost.blk")
    return set_wp_award(0)
  }

  local battleTimeAdd = ws_cost[airname].getInt("battleTimeAward"+diff_name, 0.0)

  local avgBattleTime = ws_cost[airname].getReal("battleTime"+diff_name, 120.0)

  local award = 0
  local timeCoef = 1.0
  //get modified award for Battle Royale game mode
  if (mis.gt_last_man_standing)
  {
    award = battle_royale_time_award_wp(avgBattleTime, battleTimeAdd, playerAliveTime)
  }
  else
  {
    timeCoef = battleTime / avgBattleTime
    if (timeCoef > 1)
      timeCoef = 1

    award = battleTimeAdd*timeCoef
  }

  local mul = get_wp_award_mul(airname, "battleTime", userId, param.wpBoosterPercents, false, param.rented)

  award = multiply_wp_award(award, mul)

  dagor.debug("versus_battle_time_award. WP = "+award.wp+", battleTime "+battleTime+", timeCoef "+timeCoef+", avgBattleTime "+avgBattleTime+", battleTimeAdd "+battleTimeAdd+" wpMultiplier "+mul.wp+" diff "+diff_name)

  return award

}

function on_mission_objective_wp(param) {
  local userId = param.userId
  local score = param.score
  local time = param.time
  local isPrimary = param.isPrimary
  local gt = ::get_game_type()

  if (!(gt & ::GT_USE_WP))
  {
    dagor.debug("on_player_event_mp - !GT_USE_XP")
    return set_wp_award(0)
  }

  local award = set_wp_award(award)
  return award
}

function versus_mission_end_award(param, userId) {
  local airname              = param.airname
  local time                 = param.time
  local success              = param.success
  local early                = param.early
  local by_time_left         = param.by_time_left
  local total_mission_time   = param.total_mission_time
  local total_flight_time    = param.total_flight_time
  local score                = param.score
  local battleTime           = param.battleTime
  local award                = param.currentAward
  local wpBoosterPercents    = param.wpBoosterPercents
  local rented               = param.rented

  local ws = ::get_warpoints_blk()
  local econWpBlk = get_economy_config_block("warpoints")
  local mis = get_current_mission_info_cached()

  dagor.debug("versus_mission_end_award called with award WP = "+award.wp+", effCoef = "+award.effCoef)

  if (mis.constantWPAwardName != null && mis.constantWPAwardName != "")
  {
    local zeroScoreTournamentAwardMul = econWpBlk.getReal(mis.constantWPAwardName+"ZeroScoreMul", 0.0)

    if (success)
    {
      award = econWpBlk.getInt(mis.constantWPAwardName+"Win", 0)
      if (score == 0)
        award *= zeroScoreTournamentAwardMul
    }
    else
      award = econWpBlk.getInt(mis.constantWPAwardName+"Lose", 0)

    local mul = get_wp_award_mul(airname, "missionEnd", userId, param.wpBoosterPercents, false, rented)
    award = multiply_wp_award(award, mul)

    dagor.debug("versus_mission_end_award WP = "+award.wp+", win? "+success+", score "+score+", constantWPAwardName "+mis.constantWPAwardName)
  }
  else
  if (mis.pveWPAwardName != null && mis.pveWPAwardName != "")
  {
    local sessionTime = ((stat_get_mission_time()+0.5).tointeger()).tofloat()
    local missionTimeAward = get_pve_award(success, "Wp", mis, sessionTime, total_flight_time, time, score)
    local mul = get_wp_award_mul(airname, "missionEnd", userId, 0, false, rented)
    award = multiply_wp_award(missionTimeAward, mul)
    dagor.debug("versus_mission_end_award PVE. WP = "+award.wp+", win? "+success+", missionTime "+total_mission_time+", pveWPAwardName "+mis.pveWPAwardName)
  }
  else
  if (mis.gt_last_man_standing)
  {
    local mul = battle_royale_award_mul(success, "wp")
    award = multiply_wp_award(award, mul)
    dagor.debug("versus_mission_end_award Battle Royale. WP = "+award.wp+", win? "+success)

    if (success) battle_royale_open_unlock_for_user(userId, 1, true)
  }
  else
  {
    local winK = ws.getReal("winK", 0.0)
    if (!success)
      winK = 0
    if (!mis.useFinalResults)
      winK *= 0.5

    award = multiply_wp_award(award, winK)
    dagor.debug("versus_mission_end_award WP = "+award.wp+", win? "+success+", winK "+winK+", mis.useFinalResults "+mis.useFinalResults)

    if (mis.wwarEconomics)
    {
      local operationPart = econWpBlk.getReal("wwarOperationPart", 0.0)
      local operationReward = (param.currentAward.wp + award.wp) * operationPart
      wwSharedPool_addWpToOperationPool(operationReward)

      dagor.debug("wwar_versus_mission_end_award operationReward " + operationReward + ", operationPart " + operationPart)
    }
  }
  
  award.effCoef = 0

  return award
}

dagor.debug("warpoints script loaded")