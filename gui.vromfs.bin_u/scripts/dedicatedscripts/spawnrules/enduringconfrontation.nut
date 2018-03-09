//---- Enduring Confrontation specials ----

function bots_for_ec(blk)
{
  blk.allowedTanks = ::DataBlock()
  blk.allowedAircrafts = ::DataBlock()
  blk.allowedShips = ::DataBlock()

  local gm = ::get_matching_game_mode_info()

  local mis = get_current_mission_info_cached()
  local wpcost = ::get_wpcost_blk()

  local minrank = ((mis.ranks != null) ? mis.ranks.min : 0)
  local maxrank = ((mis.ranks != null) ? mis.ranks.max : 25)
  local minr = calc_battle_rating_from_rank(minrank)
  local maxr = calc_battle_rating_from_rank(maxrank)

  local diff = get_mission_mode()

  local out_tbl = {}

  local teams = {}

  if (gm)
  {
    foreach (team in ["teamA", "teamB"])
      if (team in gm)
        if ("countries" in gm[team])
          foreach (country in gm[team].countries) //format is country_ussr
          {
            out_tbl[country] <- []
            teams[country] <- team
          }
  }
  else if (mis.country_allies && mis.country_axis)
  {
    out_tbl["country_"+mis.country_allies] <- []
    out_tbl["country_"+mis.country_axis] <- []
  }

    foreach (airName, airBlk in wpcost)
    {
      local country = airBlk.country
      if (!(country in out_tbl))
        continue

      local c = get_unit_type_by_unit_name(airName)
      if (c != DS_UT_AIRCRAFT)
        continue

      local br = get_unit_blk_battle_rating_by_mode(airBlk, diff)

      //check_unit_by_mode_info from ranks_ds, used in timeDelay
      local check = true
      if (gm)
        check  = ::check_unit_by_mode_info(gm, country, (teams[country] == "teamB" ? 2 : 1), airName, airBlk)

      if (check)
      {
        if (br >= minr && br <= maxr)
        {
          local weight = 1.0 //TODO
          if (maxr - minr > 0.01)
          {
            local x = (br - minr) / (maxr - minr)
            x = (x*2.0)-1.0 // -1 .. 1
            local y = 1.0 - (x*x)
            weight = 0.5 + 1.5*y // 0.5 .. 2.0 , 1.0 for medium br's
          }
          //dagor.debug(" ok");
          dagor.debug("bots_for_ec adding "+airName+" weight "+weight + "("+minr+"<="+br+"<="+maxr+")");
          out_tbl[country].append({name = airName, weight = weight})
        }
      }
    }

  //convert to blk and return
  local cPrefixLen = "country_".len()

  foreach (country, ar in out_tbl)
    foreach (a in ar)
    {
      local cb = ::DataBlock()
      cb.name = a.name
      cb.weight = a.weight
      cb.country = country.slice(cPrefixLen)
      blk.allowedAircrafts.aircraft <- cb
    }
  //uncomment for local testing:
  //blk.saveToTextFile("bots.blk")
}

::ec_start_spawnscore <- {}

//name:t=enduringConfrontation
function enduringConfrontation_onSessionStart()
{
}

function enduringConfrontation_onSessionEnd()
{
}

function enduringConfrontation_onPlayerConnected(userId, team, country)
{
}

function enduringConfrontation_onPlayerDisconnected(userId)
{
}

function enduringConfrontation_onPlayerSpawn(userId, team, country, unit, weapon, cost)
{
}

function enduringConfrontation_onBailoutOnAirfield(userId, team, country, unit, weapon)
{
  local mis = get_current_mission_info_cached()
  local cost = ec_get_unit_spawn_score(userId, unit)
  if (cost > 0)
    inc_player_spawn_score(userId, cost);
}

function enduringConfrontation_canPlayerSpawn(userId, team, country, unit, weapon, fuel)
{
  return true
}

ec_max_spawn_score <- 450

function enduringConfrontation_onPlayerFinished(userId, country, log)
{
  log.ecSpawnScore = 0
  if (!(userId.tostring() in ec_start_spawnscore))
    return
  local start = ec_start_spawnscore[userId.tostring()]
  local end = get_player_spawn_score(userId);

  dagor.debug("[EC] "+userId.tostring()+"("+country+") initial spawn score = "+start+", at end = "+end);

  local overflow = end - start
  if (overflow > 0)
  {
    local ws = get_warpoints_blk();

    local limit_mul = get_spawn_score_param("max_spawn_score_overflow_mul", 2.0)
    local limit = ::ec_max_spawn_score * limit_mul
    limit = get_spawn_score_param("max_spawn_score_overflow", limit)
    if (overflow > limit)
      overflow = limit

    overflow = overflow.tointeger()
    local blk = get_es_custom_blk(userId)
    local key = "ecss_"+country
    blk[key] = overflow
    log.ecSpawnScore = overflow
    dagor.debug("[EC] "+userId.tostring()+"("+country+") stored spawn score = "+blk[key]);
  }
}

//prepareUnitListFunction
function ec_get_avail_unit_list_cached(modeInfo, playerCountry, team)
{
  return get_avail_unit_list_cached(modeInfo, playerCountry, team)
}

//getSpawnDelayFunction
function ec_get_unit_spawn_delay(modeInfo, unitname, minRank, maxRank)
{
  local ret = get_unit_spawn_delay(modeInfo, unitname, minRank, maxRank)
  dagor.debug("[EC] "+unitname+" spawnDelayAfterDeath = "+ret.spawnDelayAfterDeath);
  return { spawnDelay=0.0 , spawnDelayAfterDeath = ret.spawnDelayAfterDeath.tofloat() }
}

//getUnitNoDelayFunction
function ec_get_no_delay_unit_cached(playerCountry, team)
{
  return get_no_delay_unit_cached(playerCountry, team)
}

::ec_spawn_score_mul <- {}

//getSpawnScoreFunction
function ec_get_unit_spawn_score(userId, unitname)
{
  local raw = get_unit_spawn_score(userId, unitname)
  local mis = get_current_mission_info_cached()
  local minrank = ((mis.ranks != null) ? mis.ranks.min : 0)
  local maxrank = ((mis.ranks != null) ? mis.ranks.max : 25)

  local initial = get_max_spawn_score(userId, maxrank)

  local ret = raw - initial
  if (ret < 0)
    ret = 0

  dagor.debug("[EC] "+unitname+" raw spawn score = "+raw+" initial "+initial+" spawn score "+ret);


  if (!(unitname in ec_spawn_score_mul))
  {
    local mul = 0.0

    local minr = calc_battle_rating_from_rank(minrank)
    local maxr = calc_battle_rating_from_rank(maxrank)
    local diff = get_mission_mode()
    local wpcost = ::get_wpcost_blk()
    if (wpcost[unitname])
    {
      if (maxr - minr > 0.01)
      {
        local br = get_unit_blk_battle_rating_by_mode(wpcost[unitname], diff)
        local t = (br - minr)/(maxr-minr)
        if (t > 1.0)
          t = 1.0
        else if (t < 0.0)
          t = 0.0

        local mulMin = get_spawn_score_param("award_mul_min", 0.1)
        local mulMax = get_spawn_score_param("award_mul_max", 1.0)

        mul = mulMin + (mulMax-mulMin)*(1.0-t)
      }
      else
        mul = 1.0
    }
    ec_spawn_score_mul[unitname] <- mul
    dagor.debug("[EC] "+unitname+" spawn score increase multiplier = "+mul);
  }


  return ret
}

//initSpawnScoreFunction
function ec_get_max_spawn_score(userId, sessionRank)
{
  ::ec_max_spawn_score <- get_max_spawn_score(userId, sessionRank)
  local ret = 0 //get_max_spawn_score(userId, sessionRank)
  ec_start_spawnscore[userId.tostring()] <- ret
  dagor.debug("[EC] "+userId.tostring()+" initial spawn score = "+ret);
  local blk = get_es_custom_blk(userId)
  if (!blk)
    return ret
  local country = get_es_country(userId)
  local key = "ecss_"+country
  if (key in blk)
  {
    dagor.debug("[EC] "+userId.tostring()+"("+country+") added spawn score = "+blk[key]);
    ret = ret + blk[key]
    blk[key] = 0
  }
  return ret
}

//updateSpawnScoreFunction
function ec_update_unit_spawn_score(userId, unitname)
{
// no double cost in EC, do nothing
//  update_unit_spawn_score(userId, unitname)
}

//spawnScoreIncFunction
function ec_spawn_score_inc(unitname)
{
  if (!(unitname in ec_spawn_score_mul))
    return 0.0
  return ec_spawn_score_mul[unitname]
}


//---- Enduring Confrontation specials END ----
dagor.debug("enduringConfrontation script loaded")