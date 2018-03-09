local u = require("std/u.nut")
::event_reward_mul_wp <- 1.0
::event_reward_mul_exp <- 1.0

local tm = ::get_local_time()
::math.init_rnd(tm.sec + tm.min + tm.hour)

::spawn_score_scout_mul <- {}

function get_economic_rank_by_unit_name(unitName)
{
  local economicRank = 0
  local wpcost = get_wpcost_blk()
  local missionMode = ::get_mission_mode()
  if (wpcost && wpcost[unitName])
    economicRank = ::get_unit_blk_economic_rank_by_mode(wpcost[unitName], missionMode)

  return economicRank
}

function get_unit_blk_battle_rating_by_mode(unitBlk, ediff)
{
  return ::calc_battle_rating_from_rank(::get_unit_blk_economic_rank_by_mode(unitBlk, ediff))
}

function schema_validate(obj, schema)
{
  foreach (k, v in obj)
  {
    if (!(k in schema))
    {
      dagor.debug("key " + k + " not in schema");
      delete obj[k]
      continue
    }
    foreach (pred, param in schema[k])
    {
      if (pred == "type")
      {
        if (typeof v != param)
          throw ("bad type for " + k + ": " + typeof v + ", must be " + param)
      }
      else if (pred == "anyOf")
      {
        if (param.find(v) < 0)
          throw (k + ": value '" + v + "' is not valid")
      }
      else if (pred == "range")
      {
        if (v < param.min || v > param.max)
          throw (k + ": value '" + v + "' out of valid range")
      }
    }
  }
}


function set_event_rewards(reward_mul_wp, reward_mul_exp)
{
  local econWpBlk = get_economy_config_block("warpoints")

  dagor.debug("set_event_rewards: "+reward_mul_wp+" "+reward_mul_exp)

  if (reward_mul_wp >= 0.0)
    if (reward_mul_wp > 1.0)
    {
      if (reward_mul_wp <= 3.0 || econWpBlk.getBool("canUseBigMulInEvents", false))
        ::event_reward_mul_wp = reward_mul_wp
    }
    else
    {
      ::event_reward_mul_wp = reward_mul_wp
    }

  if (reward_mul_exp >= 0.0)
    if (reward_mul_exp > 1.0)
    {
      if (reward_mul_exp <= 3.0 || econWpBlk.getBool("canUseBigMulInEvents", false))
        ::event_reward_mul_exp = reward_mul_exp
    }
    else
    {
      ::event_reward_mul_exp = reward_mul_exp
    }
}

function check_mission_params(mission_decl)
{
  local mission_decl_schema = {
    keepProfileOnReconnect = { type = "bool" }
    _gameMode     = {
                      type  = "integer"
                      anyOf = [::GM_SKIRMISH,
                               ::GM_DYNAMIC,
                               ::GM_SINGLE_MISSION]
                    }
    _gameType     = {
                      type  = "integer"
                    }

    difficulty    = {
                      type = "string"
                      anyOf = ["arcade", "realistic", "hardcore", "custom"]
                    }
    custDifficulty = { type = "string" }

    environment   = {
                      type = "string"
                      anyOf = ["Noon", "Dawn", "Dusk", "Day", "Morning", "Evening", "Night", "7", "8", "9", "10", "11", "12", "13","14","15","16","17","18"]
                    }
    weather       = {
                      type = "string"
                      anyOf = ["clear", "good", "hazy", "thin_clouds","cloudy", "poor", "blind", "rain", "thunder"]
                    }
    isBotsAllowed   = { type = "bool" }
    useTankBots     = { type = "bool" }
    useShipBots     = { type = "bool" }

    isAirplanesAllowed = { type = "bool" }
    isTanksAllowed = { type = "bool" }
    isShipsAllowed = { type = "bool" }

    allowedKillStreaks = { type = "bool" }
    maxBots         = { type = "integer"}
    isLimitedAmmo   = { type = "bool" }
    isLimitedFuel   = { type = "bool" }
    optionalTakeOff = { type = "bool" }
    dedicatedReplay = { type = "bool" }
    useKillStreaks  = { type = "bool" }
    allowTeamRepairAssist = { type = "bool" }
    disableAirfields = { type = "bool" }
    spawnAiTankOnTankMaps = { type = "bool" }
    takeoffMode     = {
                        type = "integer"
                        range = {
                          min = 0
                          max = 2
                        }
                      }

    currentMissionIdx={
                        type = "integer"
                        range = {
                          min = -1
                          max = 100
                        }
                      }

    maxRespawns   =   {
                        type = "integer"
                        range = {
                          min = -2
                          max = 5
                        }
                      }

    timeLimit       = {
                        type = "integer"
                        range = {
                          min = 3
                          max = 360
                        }
                      }

    killLimit     = {
                        type = "integer"
                        anyOf = [3, 5, 7, 10, 20]
                    }

    scoreLimit =    {
                        type = "integer"
                        range = {
                          min = 0
                          max = 100000
                        }
                    }

    raceLaps =      { type = "integer"
                      range = { min = 1, max = 10 }
                    }
    raceWinners =   { type = "integer"
                      range = { min = 1, max = 10 }
                    }
    raceForceCannotShoot ={ type = "bool" }

    name = {
      type = "string"
    }

    loc_name = {
      type = "string"
    }

    originalMissionName = {
      type = "string"
    }

    postfix = {
      type = "string"
    }

//    overrideSlotbar = {}
//    editSlotbar = {}
    customSpawnScore = {}
    limits = {}
    spawnTypes = {}
    customRules = {}
    spawnScoreMul = {type = "float"}
    spawnScoreForTeamMul = {type = "float"}

    repeatsNumber = { type = "integer" }
    multiSlot = { type = "bool" }
    multiRespawn = { type = "bool" }
    multiRespawnNoRepair = { type = "bool" }
    slotMultiSpawn = { type = "bool" }
    useSpawnScore = { type = "bool" }
    useTeamSpawnScore = { type = "bool" }
    useSpawnDelay = { type = "bool" }
    cluster   = { type = "string" }
    maxPlayers =   { type = "integer"
                      range = { min = 1, max = 64 } }
    customDifficulty = {type = "table"}
    ranks = {}
    singleSpawnByTypeTechnics = {type = "table"}
    updateSpawnDelayOnlyForCurrentUnit = {type = "bool"}
    timeToKickAfk = { type = "integer" }
    timeToKickAfkInSession = { type = "integer" }
    autoBalance = { type = "bool" }
    allowEmptyTeams = { type = "bool" }
    allowedTagsPreset = { type = "string" }
  }

  try
  {
    schema_validate(mission_decl, mission_decl_schema)
  }
  catch (e)
  {
    dagor.debug("[ERROR] failed to validate mission: " + e)
    return null
  }
  return mission_decl
}

::economyConfig <- null
function get_economy_config()
{
  if (::economyConfig == null)
  {
    ::economyConfig = DataBlock()
    if (!::economyConfig.load("config/economy.blk"))
    {
      dagor.debug("[ERROR] failed to load config/economy.blk, trying the old name");
      if (!::economyConfig.load("config/economics.blk"))
        dagor.debug("[ERROR] failed to load config/economics.blk either! More errors expected");
      else
        dagor.debug("Loaded 'economy' config as config/economics.blk");
    }
    else
      dagor.debug("Loaded 'economy' config as config/economy.blk");
  }
  return ::economyConfig
}

function get_economy_config_block(blockname)
{
  local econBlk = get_economy_config()
  local econonomyConfigBlock = DataBlock()
  if (econBlk[blockname] != null)
  {
    econonomyConfigBlock = econBlk[blockname]
  }
  else
  {
    dagor.debug("[ERROR] failed to load '"+blockname+"' block from economy.blk")
  }
  return econonomyConfigBlock
}



local round_number_award = @(add, roundType) (add+roundType).tointeger()

function round_award(add)
{
  if (typeof(add) == "table")
  {
    local rounding_type = 0.5
    local base_award = 0
    local rounded_base_award = 0

    if (add["noBonus"] != null)
    {
      base_award = add["noBonus"]
      rounded_base_award = round_number_award(base_award, rounding_type)
    }

    foreach(awardName, award in add)
    {
      local awardDiv = 0
      if ((awardName == "premAcc" || awardName == "premMod" || awardName == "booster") && award > 0)
        awardDiv = base_award / award

      add[awardName] = round_number_award(award, rounding_type)
      if (add[awardName] * awardDiv < rounded_base_award && awardDiv > 0)
        add[awardName] = round_number_award(add[awardName], 1.0)
    }
  }
  else
    add = round_number_award(add, 0.5)

  return add
}

function on_mission_started_mp()
{
  dagor.debug("on_mission_started_mp - HOST")
  ::clear_spawn_score();
  ::cur_mission_mode <- -1
}

function roguelike_mode_awards(award, reward_type, userId)
{
  local landing_award_part = 0
  local misBlk = ::get_current_mission_info_cached()
  if (misBlk != null)
    landing_award_part = misBlk.getReal("roguelikeLandingAwardPart_"+reward_type, 0.0)
  else
    dagor.debug("[ERROR]: Mission blk is broken")

  if (landing_award_part < 0.05)
    return award

  if (landing_award_part > 1)
    landing_award_part = 1

  local multiplier_function = multiply_exp_award
  local mainAwardName = "rank"
  if (reward_type == "wp")
  {
    multiplier_function = multiply_wp_award
    mainAwardName = "wp"
  }

  if (award[mainAwardName] > 0 && landing_award_part > 0 && landing_award_part <= 1 &&
      (userId.tostring()+"_"+reward_type) in roguelike_econMode_players_list)
  {
    local landing_award = multiplier_function(award, landing_award_part)
    award = multiplier_function(award, (1.0-landing_award_part))

    if (reward_type == "wp")
    {
      award.effCoef += landing_award.effCoef
      landing_award.effCoef = 0
    }

    foreach (paramName, currentAward in roguelike_econMode_players_list[userId.tostring()+"_"+reward_type])
      roguelike_econMode_players_list[userId.tostring()+"_"+reward_type][paramName] += landing_award[paramName]

    award.pending <- roguelike_econMode_players_list[userId.tostring()+"_"+reward_type][mainAwardName]
    dagor.debug("roguelike_mode_awards "+reward_type+" award "+award[mainAwardName]+" landing_award_part "+landing_award_part+" userId "+userId+" new landing award "+roguelike_econMode_players_list[userId.tostring()+"_"+reward_type][mainAwardName])
  }

  return award
}

is_target_ship <- @(targetName) (get_unit_type_by_unit_name(targetName) == DS_UT_SHIP || ::mapWpUnitClassToWpUnitType?[targetName] == DS_UT_SHIP)


function race_finished_mul_calc(place, isWinner, maxPlayers, leaderTime, pathLength, sessionRank, race_type)
{
  local s_blk = ::get_game_settings_blk()
  local econExpBlk = get_economy_config_block("ranks")

  local placeMul = 1.0
  local placeDiff = econExpBlk.getReal("expRacePlaceDiff", 0.5)
  local placeDiffMul = econExpBlk.getReal("expRacePlaceDiffMul", 4.0)
  local placeDiv = econExpBlk.getReal("expRacePlaceDiv", 8)
  if (placeDiv*placeDiffMul > 0)
    placeDiff = placeDiff * maxPlayers / (placeDiv * placeDiffMul)

  if (placeDiff > 1.0)
    placeDiff = 1.0
  else
  if (placeDiff < 0.0)
    placeDiff = 0.0

  dagor.debug("race_finished_mul_calc. Step 1. place "+place+" isWinner "+isWinner+" leaderTime "+leaderTime+" maxPlayers "+maxPlayers)

  if (isWinner)
  {
    if (placeDiv > 0)
    {
      placeMul = maxPlayers / placeDiv - 1.0
      dagor.debug("race_finished_mul_calc. Step 2a. placeMul "+placeMul+" placeDiv "+placeDiv)

      if (placeMul > 0)
        placeMul = (1.0 - (place - 1.0) / placeMul * 2.0) * placeDiff

      dagor.debug("race_finished_mul_calc. Step 3a. placeMul "+placeMul+" placeDiff "+placeDiff)
    }
  }
  else
  {
    if (placeDiv > 0)
    {
      placeMul = maxPlayers * (1.0 - 1.0 / placeDiv) - 1.0
      dagor.debug("race_finished_mul_calc. Step 2b. placeMul "+placeMul+" placeDiv "+placeDiv)

      if (placeMul > 0)
        placeMul = (1.0 - (place - maxPlayers * 1.0 / placeDiv - 1.0) / placeMul * 2.0) * placeDiff

      dagor.debug("race_finished_mul_calc. Step 3b. placeMul "+placeMul+" placeDiff "+placeDiff)
    }
  }
  if (placeMul > 1.0)
    placeMul = 1.0

  placeMul += 1.0

  if (placeMul < 0)
    placeMul = 0.0

  dagor.debug("race_finished_mul_calc. Step 4. placeMul "+placeMul)

  local time_mul = 1.0
  local raceTime = pathLength
  local avgAirSpeed = 1100
  local speed_table = s_blk["avg"+race_type+"RankSpeed"]
  if (s_blk != null && speed_table != null && speed_table["rank"+sessionRank] != null && speed_table["rank"+sessionRank] > 0)
    avgAirSpeed = speed_table["rank"+sessionRank]

  raceTime = raceTime / avgAirSpeed * 3.6

  local maxTimeError = s_blk.getReal("maxTimeError", 1.5)
  if (leaderTime*maxTimeError < raceTime)
    raceTime = leaderTime

  dagor.debug("race_finished_mul_calc. Step 5. raceTime "+raceTime+" leaderTime "+leaderTime+" maxTimeError "+maxTimeError+" pathLength "+pathLength+" avgAirSpeed "+avgAirSpeed+" sessionRank "+sessionRank)

  local defaultMissionTime = econExpBlk.getInt("defaultMissionTime", 607)
  if (defaultMissionTime > 0)
    time_mul = raceTime/defaultMissionTime

  local maxRaceTimeMul = econExpBlk.getReal("maxRaceTimeMul", 6.0)
  if (time_mul > maxRaceTimeMul)
    time_mul = maxRaceTimeMul

  dagor.debug("race_finished_mul_calc. Step 6. time_mul "+time_mul+" raceTime "+raceTime+" defaultMissionTime "+defaultMissionTime+" maxRaceTimeMul "+maxRaceTimeMul)

  return time_mul*placeMul
}

::roguelike_econMode_players_list <- {}

::battle_royale_active_players <- 0
::battle_royale_total_players <- 0

function on_player_spawn(userId)
{
  roguelike_econMode_players_list[userId.tostring()+"_exp"] <- set_exp_award(0)
  roguelike_econMode_players_list[userId.tostring()+"_wp"] <- set_wp_award(0)

  local mis = get_current_mission_info_cached()
  if (mis.gt_last_man_standing)
  {
    battle_royale_active_players++
    battle_royale_total_players++
    dagor.debug("on_player_spawn . BattleRoyale player spawned: "+userId+", active players number: "+battle_royale_active_players", total players number: "+battle_royale_total_players)
  }
}


function get_score_time(unit_flight_time, total_flight_time, sessionTime, useFinalResults, useFinalResultsTimeMul = 3.07)
{
  local scoreTime = unit_flight_time
  if (total_flight_time > 0)
    if (useFinalResults)
      scoreTime *= sessionTime/total_flight_time
    else
      scoreTime *= useFinalResultsTimeMul
  dagor.debug("get_score_time "+scoreTime+" unit_flight_time "+unit_flight_time+" sessionTime "+sessionTime+" total_flight_time "+total_flight_time+" useFinalResults "+useFinalResults)
  return scoreTime
}


function get_player_place_in_leaderboard(userId) {

  local gt = ::get_game_type()
  local players = ::get_mplayers_list(GET_MPLAYERS_LIST, true)
  players.sort(::mpstat_get_sort_func(gt))

  local playerPos = u.searchIndex(players, @(s) s.userId == userId.tostring()) + 1
  return playerPos
}

function versus_apply_damage(dmg, airname, lifetime, params)
{
  local deathReason = params.deathReason
  local teamKill = params.teamKill
  local leftMission = params.leftMission
  local diedOnGround = params.diedOnGround
  local dmgRepairs = params.dmgRepairs
  local currentAward = params.currentAward
  local air_table = params.aircrafts
  local userId = params.userId

  local es = ::get_economic_state(userId)
  if (!es)
    return 1

  local ws = ::get_warpoints_blk()
  local ws_cost = ::get_wpcost_blk()
  local econWpBlk = get_economy_config_block("warpoints")

  if (ws_cost[airname] == null)
  {
    dagor.debug("[ERROR]: No airname "+airname+" in wpcost.blk")
    return 1
  }

  local time = 1

  local diff = get_mission_mode()
  local mode_name = get_emode_name(diff)
  local diff_name = get_econRank_emode_name(diff)
  local gameModeCustomDmg = -1.0
  local multiRespawnNoRepair = false
  local misBlk = ::get_current_mission_info_cached()
  if (misBlk != null)
  {
    if (misBlk.tournament_mode == "TM_ELO_PERSONAL")
      return 0
    else
    {
      if (misBlk.gt_race != null && misBlk.gt_race)
        gameModeCustomDmg = econWpBlk.getReal("gt_raceRepairMul"+diff, -1.0)
      else
        gameModeCustomDmg = misBlk.getReal("gameModeCustomDmg", -1.0)

      multiRespawnNoRepair = misBlk.getBool("multiRespawnNoRepair", false)
    }
  }
  else
    dagor.debug("[ERROR]: Mission blk is broken")

  local aircrashDmgMul = econWpBlk.getReal("aircrashDmgMul", 1.0)
  local bailoutDmgMul = econWpBlk.getReal("bailoutDmgMul", 1.0)
  local landingCrashDmgMul = econWpBlk.getReal("landingCrashDmgMul", 1.0)
  local teamKillDmgMul = econWpBlk.getReal("teamKillDmgMul", 0.5)
  local airfieldRepairMul = econWpBlk.getReal("airfieldRepairMul", 0.2)
  local airfieldRepairMax = econWpBlk.getReal("airfieldRepairMax", 0.3)

  local baseDamage = econWpBlk.getReal("baseDamage"+mode_name, 0.5)

  if (ws_cost[airname]["lifeTime"+mode_name] != null)
    time = ws_cost[airname]["lifeTime"+mode_name]
  else
    time = econWpBlk.getReal("lifeTime"+mode_name, 80.0)

  if (time < 1)
    time = 1


  dagor.debug("versus_apply_damage called. Initial dmg "+dmg+", mode_name "+mode_name+", repairedDmg "+dmgRepairs);

  if (dmgRepairs > 0)
  {
    dmgRepairs = dmgRepairs*airfieldRepairMul
    if (dmgRepairs > airfieldRepairMax)
      dmgRepairs = airfieldRepairMax
    dmg += dmgRepairs
  }

  if (dmg > 1.0)
    dmg = 1.0
  if (fabs(dmg-1.0) < 0.0001)
    if (!multiRespawnNoRepair)
    {

      local avg_award_sum = 0
      local premMul = es.xpMultiplier
      if (econWpBlk.getBool("rcost_wpr", false))
      {
        foreach (air_name, air_wp in air_table)
        {
          local wpBlkAvgAward = ws_cost[air_name].getInt("avgAward"+diff_name, 0)
          local wpBlkBattleTimeAward = ws_cost[air_name].getInt("battleTimeAward"+diff_name, 0)
          local premActionsMul = ws.getReal("wpMultiplier", 1.0)
          local premBattleTimeMul = ws.getReal("battleTimePremMul", 1.0)

          if (wpBlkAvgAward > 0)
          {
            if (premMul > 1.0)
            {
              wpBlkAvgAward = (wpBlkAvgAward+wpBlkBattleTimeAward*(premBattleTimeMul-1))*premActionsMul
              dagor.debug("wpBlkAvgAward "+wpBlkAvgAward+", wpBlkBattleTimeAward "+wpBlkBattleTimeAward+
                          ", premBattleTimeMul "+premBattleTimeMul+", premActionsMul "+premActionsMul)
            }


            avg_award_sum += wpBlkAvgAward

          }
          else
          {
            avg_award_sum = -1
            dagor.debug("Award calc ERROR. warpoints.blk is incorrect.")
            continue
          }
        }

        local winK = ws.getReal("winK", 0)
        if (avg_award_sum > 0)
        {

          time = lifetime / time
          if (time > 1)
            time = 1

          local awardK = (currentAward*(winK*0.5+1.0)+avg_award_sum*time)*0.5/avg_award_sum
          if (awardK > 1.0)
            awardK = 1.0

          local minDmgK = econWpBlk.getReal("minDmgK", 1.0)
          local air_rank = ws_cost[airname].getInt("rank", 0)
          local minDmgRankCoef = econWpBlk.getInt("minDmgRankCoef", 0)
          local minDmgRankMul = econWpBlk.getReal("minDmgRankMul", 0)
          local avgAward = ws_cost[airname].getInt("avgAward"+diff_name, 0)
          local rCost = ws_cost[airname].getInt("repairCost"+diff_name, 0)
          local wpBalanceCoef = 0

          if (rCost > 0)
            wpBalanceCoef = avgAward*1.0/rCost

          wpBalanceCoef += (air_rank-minDmgRankCoef)*minDmgRankMul

          dagor.debug("wpBalanceCoef "+wpBalanceCoef+", air_rank "+air_rank+", minDmgRankCoef "+minDmgRankCoef+
                      ", minDmgRankMul "+minDmgRankMul+", avgAward "+avgAward+", rCost "+rCost+", lifetime "+lifetime+", time "+time)

          if (wpBalanceCoef < 1.0)
          {
            if (wpBalanceCoef > 0)
              minDmgK = minDmgK/wpBalanceCoef
            else
            {
              minDmgK = -1
              dagor.debug("minDmgK calc ERROR. wpBalanceCoef "+wpBalanceCoef+". Check rankCoef multipliers")
            }
          }

          local medRCostKMul = econWpBlk.getReal("medRCostKMul", 0.0)
          local medRCostKAdd = econWpBlk.getReal("medRCostKAdd", 1.0)
          local highRCostKMul = econWpBlk.getReal("highRCostKMul", 0.0)
          local highRCostKAdd = econWpBlk.getReal("highRCostKAdd", 0.0)

          local medRCostK = awardK*medRCostKMul+medRCostKAdd
          local highRCostK = awardK*highRCostKMul+highRCostKAdd

          dmg = ws.getReal("avgRepairMul", 1.0)

          local lowRCostPK = econWpBlk.getReal("lowRCostPK", 1.0)
          local lowRCostP = minDmgK*dmg+awardK*lowRCostPK
          local highRCostP = econWpBlk.getReal("highRCostP", 1.0)

          local lowRCostDiff = econWpBlk.getReal("lowRCostDiff", 1.0)
          local medRCostDiff = econWpBlk.getReal("medRCostDiff", 1.0)
          local highRCostDiff = econWpBlk.getReal("highRCostDiff", 1.0)

          local medRCostP = awardK*(1.0-medRCostDiff)

          local rnd = ::math.frnd()
          local rnd2 = ::math.frnd()


          if (gameModeCustomDmg < 0)
          {
            if (rnd < highRCostK)
              dmg = highRCostP*(1+(rnd2-0.5)*2*highRCostDiff)
            else if (rnd < medRCostK+highRCostK)
              dmg = medRCostP*(1+(rnd2-0.5)*2*medRCostDiff)
            else
              dmg = lowRCostP*(1+(rnd2-0.5)*2*lowRCostDiff)

            dagor.debug("Dmg from award. Dmg "+dmg+", awardK "+awardK+", minDmgK "+minDmgK+", currentAward "+currentAward+", avg_award_sum "+avg_award_sum)
            dagor.debug("repairCostRK "+rnd+", repairCostRK2 "+rnd2+", highRCostK "+highRCostK+", medRCostK "+medRCostK+", lowRCostP "+lowRCostP
                       +", medRCostP "+medRCostP+", highRCostP "+highRCostP+", lowRCostPK "+lowRCostPK)
          }
          else
          {
            dmg = gameModeCustomDmg * (1 + ((rnd2-0.5)*2*medRCostDiff))
            dagor.debug("dmg from gameModeCustomDmg. Dmg "+dmg+", gameModeCustomDmg "+gameModeCustomDmg+", medRCostDiff "+medRCostDiff)
          }
        }
        else
        {
          dagor.debug("avg_award_sum =< 0. dmg = 1.0")
          dmg = 1.0
        }
      }
      else
      {
        time = lifetime / time
        if (time > 1)
          time = 1

        dmg = time
      }

      switch (deathReason)
        {
          case 4:
            dmg *= aircrashDmgMul
            break

          case 14:
            dmg *= bailoutDmgMul
            break

          case 2:
            dmg *= landingCrashDmgMul
            break
        }

      if (teamKill)
        dmg *= teamKillDmgMul

      if (dmg < baseDamage && gameModeCustomDmg < 0)
        dmg = baseDamage

      if (dmg > 1.0)
      {
        dmg = 1.0
        dagor.debug("Dmg calc ERROR "+dmg+" > 1.0. Check death reasons multipliers")
      }

      dagor.debug("Dmg "+dmg+", death reason "+deathReason+
                  ", teamKill? "+teamKill+", baseDamage "+baseDamage+", dmgRepairs "+dmgRepairs);
    }
    else
    {
      if (gameModeCustomDmg >= 0)
        dmg = gameModeCustomDmg
      dagor.debug("multiRespawnNoRepair mode on. Dmg "+dmg+" gameModeCustomDmg "+gameModeCustomDmg)
    }

  return dmg
}

function calc_pvp_rating(rating, wp)
{
  local newRating = rating
  if (wp > rating)
  {
    local econExpBlk = get_economy_config_block("ranks")
    local sessionCountMul = econExpBlk.getReal("sessionCountMul", 0.01)
    newRating += (wp - rating) * sessionCountMul
  }

  return newRating
}
calcPvpRating <- calc_pvp_rating // alias for compatibility

function get_initial_team_spawn_score()
{
  return 0.0;
}

function get_unit_battle_rating(unitname) //CALLED FROM CODE, DO NOT REMOVE!
{
  local mr = get_economic_rank_by_unit_name(unitname)
  return calc_battle_rating_from_rank(mr)
}

function get_unit_spawn_delay(modeInfo, unitname, minRank, maxRank)
{
  local ret = { spawnDelay=-1.0 , spawnDelayAfterDeath = -1.0 }

  dagor.debug("get_unit_spawn_delay for "+unitname+" minRank = "+minRank + ", maxRank = "+maxRank)

  local ws = get_warpoints_blk();

  local wpcost = ::get_wpcost_blk()
  if (wpcost[unitname] == null)
  {
    dagor.debug("ERROR: get_unit_spawn_delay - no "+unitname+" in wpcost")
    return ret
  }

  local unitClass = wpcost[unitname].unitClass
  if (unitClass == null)
  {
    dagor.debug("ERROR: get_unit_spawn_delay - no unitClass for "+unitname+" in wpcost")
    return ret
  }

  local spawnCfg = ws.respawn_points
  if (spawnCfg == null)
  {
    dagor.debug("ERROR: get_unit_spawn_delay - no ws.respawn_points")
    return ret
  }

  local diff = get_mission_mode()
  local cb = spawnCfg[get_emode_name(diff)]
  local cbm_name = "spawn_delay_add_by_exp_class"
  local cbm = (cb != null && cb[cbm_name] != null) ? cb[cbm_name] : null
  if (cbm == null)
  {
    dagor.debug("ERROR: get_unit_spawn_delay - no "+cbm_name+" in config for "+get_emode_name(diff))
    return ret
  }

  local classAdd = cbm.getInt(unitClass, 0.0)
  if (classAdd < 0)
  {
    dagor.debug("ERROR: get_unit_spawn_delay - negative classAdd for "+unitClass)
    return ret
  }

  cbm_name = "spawn_delay_mul_by_exp_class"
  local cbm = (cb != null && cb[cbm_name] != null) ? cb[cbm_name] : null
  if (cbm == null)
  {
    dagor.debug("ERROR: get_unit_spawn_delay - no "+cbm_name+" in config for "+get_emode_name(diff))
    return ret
  }

  local classMul = cbm.getReal(unitClass, 0.0)
  if (classMul < 0)
  {
    dagor.debug("ERROR: get_unit_spawn_delay - negative mul for "+unitClass)
    return ret
  }

  local mis = get_current_mission_info_cached()
  if (mis == null)
  {
    dagor.debug("ERROR: get_unit_spawn_delay - get_current_mission_info == null");
    return ret
  }

  local unitMRank = get_economic_rank_by_unit_name(unitname)
  if (unitMRank < minRank)
    unitMRank = minRank

  local rankMul = 0.0
  local mRankPow = mis.getReal("delaySpawnMRankPow", 1.5)
  if (maxRank - minRank > 0)
    rankMul = pow((unitMRank - minRank)*1.0 / (maxRank - minRank), mRankPow)
  if (rankMul < 0.0)
    rankMul = 0.0
  if (rankMul > 1.0)
    rankMul = 1.0

  dagor.debug("get_unit_spawn_delay rankMul = "+rankMul+" classMul = "+classMul+" classAdd = "+classAdd+" mRankPow "+mRankPow+" unitMRank "+unitMRank+" minRank "+minRank)

  local delayForMaxRankMinutes = mis.getInt("delayForMaxRankMinutes", 45)
  ret.spawnDelay = delayForMaxRankMinutes * rankMul * classMul + classAdd
  local delayTimeRoundConstant = mis.getInt("delayTimeRoundConstant", 1)
  if (delayTimeRoundConstant != 0)
    ret.spawnDelay = ((ret.spawnDelay*1.0/delayTimeRoundConstant)+0.5).tointeger()*delayTimeRoundConstant

  ret.spawnDelay *= 60
  ret.spawnDelayAfterDeath = ret.spawnDelay
  local afterDeathDelayOnly = mis.getBool("afterDeathDelayOnly", false)
  if (afterDeathDelayOnly)
    ret.spawnDelay = -1.0

  dagor.debug("get_unit_spawn_delay spawnDelay = "+ret.spawnDelay+" spawnDelayAfterDeath = "+ret.spawnDelayAfterDeath+", delayForMaxRankMinutes "+delayForMaxRankMinutes+
              ", delayTimeRoundConstant "+delayTimeRoundConstant+", afterDeathDelayOnly "+afterDeathDelayOnly)

  return ret
}

function is_unit_match(ar, airName, airBlk)
{
  foreach (f in ar)
  {
    if ("name" in f)
    {
      if (f.name == airName)
        return true;
    }
    else
    {
      if ("ranks" in f)
      {
        local rank = airBlk.rank
        if (rank < f.ranks.min)
          return false
        if (rank > f.ranks.max)
          return false
      }
      if ("class" in f)
      {
        local c = get_unit_type_by_unit_name(airName)
        if (c in ::dsClassToMatchingClass)
          c = ::dsClassToMatchingClass[c]
        if (f["class"] != c)
          return false
      }
      if ("type" in f)
      {
        local unitClass = airBlk.unitClass
        if (unitClass != ("exp_"+f["type"]))
          return false
      }
      return true
    }
  }

  return false
}

function check_unit_by_mode_info(modeInfo, playerCountry, team, airName, airBlk)
{
  if (airBlk.country != playerCountry)
    return false

  if (airBlk.showOnlyWhenBought == true)
    return false

  if (airBlk.premPackAir == true || airBlk.costGold > 0 || airBlk.gift != null)
    return false

  local teamName = (team == 2) ? "teamB" : "teamA"
  if (!(teamName in modeInfo))
    return false

  local teamTbl = modeInfo[teamName]

  if ("forbiddenCrafts" in teamTbl)
    if (is_unit_match(teamTbl.forbiddenCrafts, airName, airBlk))
      return false

  if ("allowedCrafts" in teamTbl)
    return is_unit_match(teamTbl.allowedCrafts, airName, airBlk)

  return true
}

::cached_avail_unit_list <- [{},{},{}]

function get_avail_unit_list_cached(modeInfo, playerCountry, team)
{
  dagor.debug("LIST "+playerCountry+" "+team);
  if (!(playerCountry in ::cached_avail_unit_list[team]))
  {
    local ar = []

    local wpcost = ::get_wpcost_blk()
    local misBlk = ::get_current_mission_info_cached()

    local minrank = ((misBlk.ranks != null) ? misBlk.ranks.min : 0)
    local maxrank = ((misBlk.ranks != null) ? misBlk.ranks.max : 25)

    local diff = get_mission_mode()

    local no_delay_unit = ""

    for (local mr = minrank; mr >= 0; mr--)
    {
      dagor.debug("LIST trying minrank "+mr)
      ar = []
      local minr = calc_battle_rating_from_rank(mr)
      local maxr = calc_battle_rating_from_rank(maxrank)
      foreach (airName, airBlk in wpcost)
      {
        local br = get_unit_blk_battle_rating_by_mode(airBlk, diff)

        if (::check_unit_by_mode_info(modeInfo, playerCountry, team, airName, airBlk))
        {
          if (br < minr || br > maxr)
          {
            dagor.debug("LIST "+airName+" skipped by br "+br.tostring() +" ("+minr.tostring()+" - "+maxr.tostring()+")")
            continue
          }
          dagor.debug("LIST ["+team.tostring()+"]["+playerCountry+"] "+airName)
          ar.append(airName)
          if (no_delay_unit == "")
          {
            local tb = get_unit_spawn_delay(modeInfo, airName, minrank, maxrank);
            if (tb.spawnDelay < 1.0)
            {
              no_delay_unit = airName
              dagor.debug("LIST found no_delay_unit "+airName)
            }
            else
              dagor.debug("LIST tb.spawnDelay "+tb.spawnDelay+" for "+airName)
          }
        }
      }
      if (no_delay_unit != "")
        break
    }
    ::cached_avail_unit_list[team][playerCountry] <- {}
    ::cached_avail_unit_list[team][playerCountry].list <- ar
    ::cached_avail_unit_list[team][playerCountry].no_delay_unit <- no_delay_unit
  }
  return ::cached_avail_unit_list[team][playerCountry].list
}

function get_no_delay_unit_cached(playerCountry, team)
{
  if (!(playerCountry in ::cached_avail_unit_list[team]))
  {
    dagor.debug("get_no_delay_unit_cached - no cache for "+playerCountry+" team "+team)
    return ""
  }
  dagor.debug("get_no_delay_unit_cached - "+::cached_avail_unit_list[team][playerCountry].no_delay_unit)
  return ::cached_avail_unit_list[team][playerCountry].no_delay_unit
}

function get_max_spawn_score(userId, sessionRank)
{
  local misBlk = ::get_current_mission_info_cached()
  if (misBlk.customSpawnScore != null)
    if (misBlk.customSpawnScore.initial_spawn_score != null)
      return misBlk.customSpawnScore.initial_spawn_score.tointeger()

  local ws = get_warpoints_blk();
  local spawnCfg = ws.respawn_points
  if (spawnCfg == null)
    return 0
  local baseCoef = spawnCfg.getInt("base_respawn_points_coef", 100)
  local mul = 1.0
  if (misBlk.customSpawnScore != null)
  {
    if (misBlk.customSpawnScore["base_respawn_points_coef"] != null)
      baseCoef = misBlk.customSpawnScore["base_respawn_points_coef"].tointeger()
  }
  else
  {
    local diff = get_mission_mode()
    local cb = spawnCfg[get_emode_name(diff)]
    mul = (cb != null) ? cb.getReal("maxRespawnPointsMul", 1.0) : 1.0
  }

  return (baseCoef.tofloat() * mul).tointeger();
}

function get_unit_spawn_score(userId, unitname)
{
  local ws = get_warpoints_blk();
  local misBlk = ::get_current_mission_info_cached()

  local spawnCfg = ws.respawn_points
  if (spawnCfg == null)
    return 0

  local baseCoef = get_spawn_score_param("base_respawn_points_coef", 100)

  local diff = get_mission_mode()

  local wpcost = ::get_wpcost_blk()
  if (wpcost[unitname] == null)
    return 0

  local unitClass = wpcost[unitname].unitClass
  if (unitClass == null)
    return 0

  local unit_type = get_unit_type_by_unit_name(unitname)
  if (unit_type == "exp_zero")
    unit_type = ""
  else
    unit_type = "_"+unit_type

  local mul = get_spawn_score_param(unitname, -1)
  if (mul == -1)
    mul = get_spawn_score_param(unitClass, 1.0)

  local br_diff = 1.0
  local br_diff_mul = 1 - get_spawn_score_param("br_diff_mul"+unit_type, 1.0)
  if (br_diff_mul < 0)
    br_diff_mul = 0

  local min_br = 0 //0(min possible) session rank
  local max_br = 9.3 //25(max possible) session rank
  if (misBlk.ranks != null) //not PS4
  {
    min_br = calc_battle_rating_from_rank(misBlk.ranks.min)
    max_br = calc_battle_rating_from_rank(misBlk.ranks.max)
    br_diff = max_br - min_br
  }
  
  local unit_br = get_unit_blk_battle_rating_by_mode(wpcost[unitname], diff)
  if (unit_br < min_br)
    unit_br = min_br

  local br_mul = 1.0
  if (br_diff > 0)
    br_mul = (unit_br - min_br) / br_diff * (1 - br_diff_mul) + br_diff_mul

  if (br_mul < 0)
    br_mul = 0

  dagor.debug("get_unit_spawn_score unit "+unitname+" base br "+unit_br+" br_mul "+br_mul+" max_br "+max_br+ " br_diff_mul "+br_diff_mul+" br_diff "+br_diff+" unit_type "+unit_type)

  local score = (br_mul * baseCoef.tofloat() * mul).tointeger()  

  if (misBlk.customSpawnScore != null)
    if (misBlk.customSpawnScore.costs != null)
      if (unitname in misBlk.customSpawnScore.costs)
        score = misBlk.customSpawnScore.costs[unitname]

  local spawn_mul = getUnitSpawnScoreMul(userId, unitname)

  local spawnCost = ((score*spawn_mul*0.1).tointeger()*10).tointeger()
  dagor.debug("get_unit_spawn_score spawnCost "+spawnCost+" score "+score+" baseCoef "+baseCoef+ " mul "+mul+" spawn_mul "+spawn_mul)

  return spawnCost
}

function getUnitSpawnScoreMul(userId, unitname)
{
  local spawn_mul = 1.0
  local spawn_pow = get_spawn_score_param("spawn_pow", 1.0)
  local spawnType = ::get_unit_spawn_type(unitname)
  if (spawnType) {
    if (spawnType in ::spawn_score_tbl?[userId]) spawn_mul = 1.0 + (::spawn_score_tbl[userId][spawnType]).tofloat()
    spawn_mul = pow(spawn_mul, spawn_pow)
  }
  local scout_mul = ::spawn_score_scout_mul?[userId]?[unitname] ?? 1.0
  dagor.debug("getUnitSpawnScoreMul spawnType " + spawnType + " spawn_pow " + spawn_pow + " spawn_mul " + spawn_mul + " scout_mul " + scout_mul)
  return spawn_mul * scout_mul
}

function update_unit_spawn_score(userId, unitname)
{
  dagor.debug("update_unit_spawn_score 1")

  local misBlk = ::get_current_mission_info_cached()
  if (misBlk.useTeamSpawnScore)
  {
    dagor.debug("update_unit_spawn_score - disabled in useTeamSpawnScore mode")
    return
  }

  local wpcost = ::get_wpcost_blk()
  if (wpcost[unitname] == null)
  {
    dagor.debug("update_unit_spawn_score no unit "+unitname.tostring())
    return
  }

  local spawnType = ::get_unit_spawn_type(unitname);
  if (spawnType == null)
  {
    dagor.debug("update_unit_spawn_score no spawnType")
    return
  }

  if (!(userId in ::spawn_score_tbl))
    ::spawn_score_tbl[userId] <- {}

  if (!(spawnType in ::spawn_score_tbl[userId]))
    ::spawn_score_tbl[userId][spawnType] <- 0

  ::spawn_score_tbl[userId][spawnType] = ::spawn_score_tbl[userId][spawnType] + 1
  dagor.debug("update_unit_spawn_score player "+userId.tostring()+" spawnType "+spawnType+" = "+::spawn_score_tbl[userId][spawnType])
}

function on_scout_event(param)
{
  local wpcost = ::get_wpcost_blk()
  local ws = ::get_warpoints_blk()

  local userId = param.userId;
  if (!(userId in ::spawn_score_scout_mul))
    ::spawn_score_scout_mul[userId] <- {}

  foreach (unitName in param.slotUnits)
  {
    local expclass = wpcost[unitName].unitClass
    local expclass_mul = ws.rs_base?[expclass] ?? 1
    local mul = 1 - param.score * (1 - expclass_mul)
    if (unitName in ::spawn_score_scout_mul[userId])
      ::spawn_score_scout_mul[userId][unitName] *= mul;
    else
      ::spawn_score_scout_mul[userId][unitName] <- mul;
  }
}

// ==== default economic event handlers

function default_onSessionStart()
{
}

function default_onSessionEnd()
{
}

function default_onPlayerConnected(userId, team, country)
{
}

function default_onPlayerDisconnected(userId)
{
}

function default_onPlayerSpawn(userId, team, country, unit, weapon, cost)
{
}

function default_onBotSpawn(playerIdx, team, country, unit, weapon)
{
}

function default_onDeath(userId, team, country, unit, weapon, nw, na, dmg)
{
  local mis = get_current_mission_info_cached()

  if (mis.gt_last_man_standing) {
    local position = get_player_place_in_leaderboard(userId)

    battle_royale_open_unlock_for_user(userId, position, false)

    battle_royale_active_players--
    dagor.debug("default_onDeath. BattleRoyale player dropped out: "+userId+" active players left: "+battle_royale_active_players+" took "+position+" place")
  }
}

function default_onSurvive(userId, team, country, unit, weapon, nw, na, dmg)
{
}

function default_onBailoutOnAirfield(userId, team, country, unit, weapon)
{
}

function default_canPlayerSpawn(userId, team, country, unit, weapon, fuel)
{
  return true
}

function default_onPlayerFinished(userId, country, log)
{
}

function default_onBattleResult(resultBlk, winnerTeam)
{
}

function null_get_unit_spawn_delay(modeInfo, unitname, minRank, maxRank)
{
  local ret = { spawnDelay=-1.0 , spawnDelayAfterDeath = -1.0 }
  return ret
}

function is_boosters_enabled(numBattlesPlayed)
{
  local mis = get_current_mission_info_cached()
  if (mis != null && !mis.getBool("isBoosterEnabled", true))
  {
    dagor.debug("is_boosters_enabled: boosters are disabled for this game mode")
    return false
  }
  else
  if (battle_is_tutorial_for_player(numBattlesPlayed))
  {
    dagor.debug("is_boosters_enabled: boosters are disabled for economic tutorial missions")
    return false
  }

  dagor.debug("is_boosters_enabled: boosters are enabled")
  return true
}

function is_wagers_enabled()
{
  local mis = get_current_mission_info_cached()
  if (mis != null && !mis.getBool("gt_use_unlocks", true))
  {
    dagor.debug("is_wagers_enabled: wagers are disabled for this game mode")
    return false
  }

  dagor.debug("is_wagers_enabled: wagers are enabled")
  return true
}

function copyFromDataBlock(fromDataBlock, toDataBlock, override = true)
{
  if (!fromDataBlock || !toDataBlock) {
    dagor.debug("ERROR: copyFromDataBlock: fromDataBlock or toDataBlock doesn't exist")
    return
  }
  for (local i = 0; i < fromDataBlock.blockCount(); i++) {
    local block = fromDataBlock.getBlock(i)
    local blockName = block.getBlockName()
    if (!toDataBlock[blockName]) toDataBlock[blockName] <- block
    else if (override) toDataBlock[blockName].setFrom(block)
  }
  for (local i = 0; i < fromDataBlock.paramCount(); i++) {
    local paramName = fromDataBlock.getParamName(i)
    if (!toDataBlock[paramName]) toDataBlock[paramName] <- fromDataBlock[paramName]
    else if (override) toDataBlock[paramName] = fromDataBlock[paramName]
  }
}
dagor.debug("shared script loaded")