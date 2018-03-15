function on_battle_trophy(param, blk) {
  dagor.debug("on_battle_trophy_wp started")

  local mis = get_current_mission_info_cached()
  local res = {}
  local econWpBlk = get_economy_config_block("warpoints")

  if (mis.disableTrophyAward)
  {
    dagor.debug("Trophy awards are disabled for this game mode")
    return res
  }

  local wp_cost = ::get_wpcost_blk()
  local air_rank = 0
  local max_unit_rank = 0
  local air_count = 0
  local air_hp = 0
  local air_score = 0
  local blk_error = 0
  local country = ""

  if (wp_cost != null)
  {
    foreach (airname, airblock in param.aircrafts)
    {
      air_count ++
      if (wp_cost[airname] != null)
      {
        if (wp_cost[airname].rank != null)
        {
          air_rank += wp_cost[airname].rank
          if (wp_cost[airname].rank > max_unit_rank)
            max_unit_rank = wp_cost[airname].rank
        }
        else
          blk_error = 1

        if (country == "")
          if (wp_cost[airname].country != null)
            country = wp_cost[airname].country
          else
            blk_error = 1

        air_hp += airblock.hp
        air_score += airblock.score

      }
      else
        blk_error = 1

      if (blk_error == 1)
        break
    }
  }
  else
    blk_error = 1

  if (blk_error == 1)
  {
    dagor.debug("Warpoints blk error. Can't calculate award")
    return res
  }

  local missionTime = ((stat_get_mission_time()+0.5).tointeger()).tofloat() //it is total mission time
  local activity_coef = player_activity_coef(air_score, missionTime)

  if (mis.pveTrophyName != null && mis.pveTrophyName != "")
  {
    local pveTrophyMinSessionTime = econWpBlk.getInt("pveTrophyMinSessionTime", 360000)
    local ws = ::get_warpoints_blk()
    
    if (missionTime < pveTrophyMinSessionTime)
    {
      dagor.debug("PVE mission: not enough player session time. "+missionTime+" < "+pveTrophyMinSessionTime)
      return res
    }
    local min_activity = ws.getReal("pveTrophyMinActivity", 1.0)
    if(activity_coef < min_activity)
    {
      dagor.debug("PVE mission: player activity is too low to get trophy for this session. "+activity_coef+" < "+min_activity)
      return res
    }

    local pveTrophyName = mis.pveTrophyName

    local canReceivePVETrophy = ::can_receive_pve_trophy(param.userId, pveTrophyName)
    if (!canReceivePVETrophy)
    {
      dagor.debug("PVE battle trophy is given only once a day. Previous PVE session was after reset time")
      return res
    }

    
    local trophyName = get_pve_trophy_name(missionTime, param.success)

    if (trophyName == null)
      return res

    res.trophies <- {}
    res.trophies[trophyName] <- 1

    dagor.debug("First PVE battle for today: get battle trophy as a reward: "+trophyName)
    ::set_pve_event_was_played(param.userId, pveTrophyName)

    return res
  }


  local count_last_zero_rewards = function(map)
  {
    for (local i = 0; i < 32; i++)
      if ((map & (1 << i)) != 0)
        return i;
    return 32;
  }
  local get_updated_reward_map = function(old_map, got_reward)
  {
    return ((old_map << 1) | (got_reward ? 1 : 0));
  }

  local rewardMap = 0
  if (blk.rewardMap != null)
    rewardMap = blk.rewardMap
  else
    blk.rewardMap <- 0

  local timesGotNoAwardAtAll = count_last_zero_rewards(rewardMap)

  local award = 0
  local gotAward = false
  // ... calculations here
  //param.userId
  //param.curWP
  //param.curGold
  //param.sessionTime
  //param.numEnemies
  //param.aircrafts = { il-2 = {hp = 0.0, score = 300.4 }, pe-2={...} ... }

  // blk is part of profile - host can read/store weights of awards there


  dagor.debug("param.curWP "+param.curWP+", param.sessionTime "+param.sessionTime+", param.numEnemies "+param.numEnemies)
  foreach (airname, airblock in param.aircrafts)
  {
    dagor.debug(airname+" hp "+airblock.hp+" score "+airblock.score)
  }

  local trophyMinPlayers = econWpBlk.getInt("trophyMinPlayers", 100)
  //always false if confings returning null
  if (param.numEnemies < trophyMinPlayers)
  {
    dagor.debug("Not enough players for trophy award. "+param.numEnemies+" < "+trophyMinPlayers)
    return res
  }
  local trophyMinSessionTime = econWpBlk.getInt("trophyMinSessionTime", 3600000)
  //always false if confings returning null
  if (param.sessionTime < trophyMinSessionTime)
  {
    dagor.debug("Not enough player session time. "+param.sessionTime+" < "+trophyMinSessionTime)
    return res
  }

  if (air_count > 0)
  {
    air_rank /= air_count
    air_hp /= air_count
  }
  else
  {
    dagor.debug("No flyouts -> no reward")
    return res
  }

  if (air_rank > 15)
    air_rank = 15

  dagor.debug("Air rank "+air_rank)

  local trophyMaxSessionAirHP = econWpBlk.getReal("trophyMaxSessionAirHP", -1)
  if (air_hp > trophyMaxSessionAirHP)
  {
    dagor.debug("No pain, no gain. Air avg hp "+air_hp+" > "+trophyMaxSessionAirHP)
    return res
  }
  
  local trophyMinActivityCoef = econWpBlk.getReal("trophyMinActivityCoef", 1.0)

  if (activity_coef < trophyMinActivityCoef)
  {
    dagor.debug("Who does not work shall not eat. Activity coef "+activity_coef+" < "+trophyMinActivityCoef)
    return res
  }

  local trophyNoAwardChance = econWpBlk.getReal("trophyNoAwardChance", 1)
  local trophyMaxNoAwardStreak = econWpBlk.getInt("trophyMaxNoAwardStreak", 10000)
  local trophyMinNoAwardSessionsTime = econWpBlk.getInt("trophyMinNoAwardSessionsTime", 100)
  local trophyAvgSessionTime = econWpBlk.getInt("trophyAvgSessionTime", 600)
  local trophyStreakCoef  = econWpBlk.getReal("trophyStreakCoef", 0.02)

  if (blk.avgSesssionTime != null)
    blk.avgSesssionTime += (param.sessionTime).tointeger()
  else
    blk.avgSesssionTime <- (param.sessionTime).tointeger()

  local day_in_seconds = 24 * 60 * 60
  local currentDay = (::get_charserver_time_sec() / day_in_seconds).tointeger() + 1
  local ugcRewardTimePeriodMinutes = econWpBlk.getInt("ugcRewardTimePeriodMinutes", 480)
  local ugcMaxTrophiesPerDay = econWpBlk.getInt("ugcMaxTrophiesPerDay", 0)
  local ugcMaxTrophiesPerWeek = econWpBlk.getInt("ugcMaxTrophiesPerWeek", 0)
  local ugcMinSetupRank = econWpBlk.getInt("ugcMinSetupRank", 6)
  if (ugcMaxTrophiesPerWeek < ugcMaxTrophiesPerDay)
    ugcMaxTrophiesPerWeek = ugcMaxTrophiesPerDay 

  if (blk.ugcNumByDate == null)
    blk.ugcNumByDate <- DataBlock()
  if (blk.ugcNumByWeek == null)
    blk.ugcNumByWeek <- DataBlock()
  
  if (blk.ugcNumByDate.day < currentDay) {
    blk.ugcNumByDate.day = currentDay
    blk.ugcNumByDate.num = 0
  }

  if (blk.ugcNumByWeek.day <= currentDay - 7) {
    blk.ugcNumByWeek.day = currentDay
    blk.ugcNumByWeek.num = 0
  }

  if (player_has_feature(param.userId, "UgcAfterBattleTrophy", false) && max_unit_rank >= ugcMinSetupRank)
    if (blk.ugcNumByDate.num < ugcMaxTrophiesPerDay && blk.ugcNumByWeek.num < ugcMaxTrophiesPerWeek)
    {
      if (blk.ugcSessionTime != null)
        blk.ugcSessionTime += (param.sessionTime).tointeger()
      else 
        blk.ugcSessionTime <- (param.sessionTime).tointeger()

      if (blk.ugcSessionTime > ugcRewardTimePeriodMinutes * 60) {
        dagor.debug("Give ugc trophy. combined session time "+blk.ugcSessionTime+", todays trophies count "+blk.ugcNumByDate.num+", this week "+blk.ugcNumByWeek.num)
        blk.ugcSessionTime = 0
        blk.ugcNumByDate.num++
        blk.ugcNumByWeek.num++
        blk.avgSesssionTime = 0

        local itemDefId = econWpBlk.ugcMainTrophyId

        if (itemDefId > 0)
          gotAward = inventory_add_item(param.userId, itemDefId)

        blk.rewardMap = get_updated_reward_map(rewardMap, gotAward)
        return res
      }
    }

  if (timesGotNoAwardAtAll > trophyMaxNoAwardStreak && blk.avgSesssionTime > trophyMinNoAwardSessionsTime) {
    trophyNoAwardChance = -1
    dagor.debug("No award > "+trophyMaxNoAwardStreak+", give 100% award")
  }
  else if (timesGotNoAwardAtAll == 0) {
    trophyNoAwardChance = 1.1
    dagor.debug("Last one was award, give no award")
  }
  else {
    trophyNoAwardChance += (trophyMaxNoAwardStreak-timesGotNoAwardAtAll)*trophyStreakCoef
    dagor.debug("trophyNoAwardChance "+trophyNoAwardChance+", trophyMaxNoAwardStreak "+trophyMaxNoAwardStreak+", timesGotNoAwardAtAll "+timesGotNoAwardAtAll)
    if (trophyAvgSessionTime != 0)
      trophyNoAwardChance = 1-(1-trophyNoAwardChance)*param.sessionTime*1.0/trophyAvgSessionTime
    if (trophyNoAwardChance < 0.5)
      trophyNoAwardChance = 0.5
    dagor.debug("trophyNoAwardChance "+trophyNoAwardChance+", sessionTime "+param.sessionTime+", trophyAvgSessionTime "+trophyAvgSessionTime)
  }

  local rnd1 = ::math.frnd()
  dagor.debug("random "+rnd1)
  if (rnd1 > 1.0) {
    dagor.debug("RND calc ERROR "+rnd1+" > 1.0")
    return res
  }

  if (rnd1 >= trophyNoAwardChance) {
    local trophyName = "after_battle_trophy_"+country+"_rank"+max_unit_rank
    dagor.debug("give award. trophyNoAwardChance "+trophyNoAwardChance+" "+trophyName)

    blk.avgSesssionTime = 0

    gotAward = true
    blk.rewardMap = get_updated_reward_map(rewardMap, gotAward)

    res.trophies <- {}
    res.trophies[trophyName] <- 1

    //res.wpTrophy <- 10000
    //res.items.booster_shop_rp_500_10mp <- 5
    //res.trophies.us_m46_patton_73_armor_bat_trophy <- 4

  }

  blk.rewardMap = get_updated_reward_map(rewardMap, gotAward)

  if ("test_dump_blk" in getroottable())
    test_dump_blk(blk)

  return res
}

dagor.debug("battleTrophy script loaded")