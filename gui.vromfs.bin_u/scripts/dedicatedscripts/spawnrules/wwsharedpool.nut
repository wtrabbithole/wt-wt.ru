//---- WorldWar shared units pool BEGIN ----


::wwSharedPoolInitialArmiesBlk <- null
::wwSharedPoolTotalWpReward <- 0

function wwBattleChangePlayerTeam(suid, playersBlk, teamName)
{
  local playerData = ::DataBlock()

  for (local i = 0; i < playersBlk.blockCount(); i++)
  {
    local teamBlk = playersBlk.getBlock(i)
    if (suid in teamBlk)
    {
      playerData.setFrom(teamBlk[suid])
      teamBlk.removeBlock(suid)
    }
  }

  playersBlk.addBlock(teamName).addBlock(suid).setFrom(playerData)
}


function wwBattleSetPlayerTeam(userId, team)
{
  local suid = userId.tostring()
  local teamName = get_team_name_by_mp_team(team)
  local misblk = ::get_mission_custom_state(true)

  // current players
  local players = misblk.addBlock("players")
  wwBattleChangePlayerTeam(suid, players, teamName)

  // all players
  local allPlayers = misblk.addBlock("allPlayers")
  wwBattleChangePlayerTeam(suid, allPlayers, teamName)
}


function wwBattleGetPlayerTeamName(userId)
{
  local suid = userId.tostring()
  local misblk = ::get_mission_custom_state(false)
  local allPlayers = misblk.allPlayers || ::DataBlock()

  for (local i = 0; i < allPlayers.blockCount(); i++)
  {
    local teamBlk = allPlayers.getBlock(i)
    if (suid in teamBlk)
      return teamBlk.getBlockName()
  }

  return get_team_name_by_mp_team(::MP_TEAM_NEUTRAL)
}


function wwBattleRemovePlayer(userId)
{
  local suid = userId.tostring();
  local misblk = ::get_mission_custom_state(true)
  local players = misblk.addBlock("players")

  for (local i = 0; i < players.blockCount(); i++)
  {
    local teamBlk = players.getBlock(i)
    if (suid in teamBlk)
      teamBlk.removeBlock(suid)
  }
}


function wwBattleSetWpEarned(userId, wpEarned)
{
  local suid = userId.tostring();
  local misblk = ::get_mission_custom_state(true)
  local allPlayers = misblk.addBlock("allPlayers")

  for (local i = 0; i < allPlayers.blockCount(); i++)
  {
    local teamBlk = allPlayers.getBlock(i)
    if (suid in teamBlk)
    {
      local playerBlk = teamBlk[suid]
      playerBlk.setInt("wpEarned", wpEarned)
      return
    }
  }
}


function wwBattleBuildUpdateBlk(dst)
{
  dst.setStr("battleType", "wwSharedPool")
  dst.setInt("currentTime", ::get_charserver_time_sec())
  dst.setInt("updateApplied", ::wwLastUpdateApplied)
  dst.setStr("sessionId", ::get_mp_session_id())

  local customRulesBlk = dst.addBlock("customRules")
  customRulesBlk.setFrom(::get_mission_custom_state(false))
  dst.setStr("operationId", customRulesBlk.getStr("operationId", ""))
  dst.setStr("battleId", customRulesBlk.getStr("battleId", ""))

  local totalPlayers = 0

  if ("players" in customRulesBlk && "teams" in customRulesBlk)
  {
    local playersBlk = customRulesBlk.players

    for (local i = 0; i < playersBlk.blockCount(); i++)
    {
      local playersTeamBlk = playersBlk.getBlock(i)
      local teamName = playersTeamBlk.getBlockName()
      local teamPopulation = playersTeamBlk.blockCount()

      if (teamName in customRulesBlk.teams)
        customRulesBlk.teams[teamName].setInt("playersCount", teamPopulation)

      totalPlayers += teamPopulation
    }
  }

  customRulesBlk.setInt("totalPlayersCount", totalPlayers)
}

function wwBattlePeriodicSendState()
{
  dagor.debug("wwBattlePeriodicSendState")
  ::wwBattleLastPeriodicSendTime = ::get_charserver_time_sec()

  local blk = ::DataBlock()
  local bodyBlk = blk.addBlock("body")
  wwBattleBuildUpdateBlk(bodyBlk)

  blk["operationId"] = bodyBlk["operationId"]
  blk["unitUpdatesAware"] = true


  ::char_request_blk_from_server("hst_ww_periodic_update", blk)
}

function onPeriodicUpdateCompleted(responseBlk)
{
  dagor.debug("onPeriodicUpdateCompleted called. wwLastUpdateApplied " + ::wwLastUpdateApplied)
  if ("unitUpdates" in responseBlk)
  {
    local unitUpdates = responseBlk.unitUpdates % "update"
    foreach (updateBlk in unitUpdates)
    {
      local updateId = updateBlk.getInt("updateId", 0);
      dagor.debug("updateBlk with updateId " + updateId)

      if (::wwLastUpdateApplied >= updateId)
        continue

      ::wwLastUpdateApplied = updateId;

      dagor.debug("set wwLastUpdateApplied as " + updateId)

      foreach (teamName, playersTeamBlk in updateBlk)
      {
        if (typeof(playersTeamBlk) == "instance")
        {
          local unitParamsUpdate = playersTeamBlk.unitsParamsList
          foreach (unitName, numToAdd in playersTeamBlk)
          {
            if (typeof(numToAdd) == "instance")
              continue

            local inactiveToAdd = 0
            if (typeof(unitParamsUpdate) == "instance" && unitName in unitParamsUpdate)
            {
              addUnitToUnitsParamsList(teamName, unitName, unitParamsUpdate[unitName])
              inactiveToAdd = unitParamsUpdate[unitName].getInt("inactive", 0)
            }

            dagor.debug("new units arrived team: " + teamName + " unit " + unitName +
                        " num " + numToAdd + " inactive " + inactiveToAdd)
            
            modTeamSpawnLimits(teamName, unitName, numToAdd - inactiveToAdd, true)
            resetTeamUnitsDeckShort(teamName, getCountryForUnit(unitName))
          }
        }
      }
    }
  }
  if ("initialArmies" in responseBlk)
  {
    ::wwSharedPoolInitialArmiesBlk.setFrom(responseBlk.initialArmies)
  }
}

function onCharRequestBlkFromServerComplete(taskId, requestName, blk, result)
{
  if (result == ::YU2_OK && "hst_ww_periodic_update" == requestName)
    onPeriodicUpdateCompleted(blk)
}


function wwBattleSendUpdateIfNeeded()
{
  if (!::wwBattleUpdatesEnabled)
    return;

  local curTimestamp = ::get_charserver_time_sec()
  if (curTimestamp - ::wwBattleLastPeriodicSendTime > ::wwBattleSendMinPeriodSec)
  {
    ::periodic_task_reset_period(::wwSharedPoolPeriodicTaskId)
    wwBattlePeriodicSendState()
  }
}

function wwBattlePeriodicUpdateTask(dt)
{
  wwBattlePeriodicSendState()
}


function wwBattleCopyStat(dstBlk, srcBlk, statName)
{
  dstBlk.addInt(statName, srcBlk ? srcBlk.getInt(statName, 0) : 0)
}


function wwBattleFillPlayersStats(wwBattleResultBlk, winsAndDefeatsBlk)
{
  local allPlayersBlk = wwBattleResultBlk.getBlockByName("allPlayers")
  if (!allPlayersBlk)
    return

  local userStatsBlk = winsAndDefeatsBlk.getBlockByName(::BLK_USER_STATS)
  if (!userStatsBlk)
    userStatsBlk = ::DataBlock()

  for (local i = 0; i < allPlayersBlk.blockCount(); i++)
  {
    local teamBlk = allPlayersBlk.getBlock(i)
    for (local j = 0; j < teamBlk.blockCount(); j++)
    {
      local playerBlk = teamBlk.getBlock(j)
      local suid = playerBlk.getBlockName()
      local statsBlk = userStatsBlk.getBlockByName(suid)

      wwBattleCopyStat(playerBlk, statsBlk, ::EVENT_STAT_AKILLS)
      wwBattleCopyStat(playerBlk, statsBlk, ::EVENT_STAT_GKILLS)
      wwBattleCopyStat(playerBlk, statsBlk, ::EVENT_STAT_AKILLS_PLAYER)
      wwBattleCopyStat(playerBlk, statsBlk, ::EVENT_STAT_GKILLS_PLAYER)
      wwBattleCopyStat(playerBlk, statsBlk, ::EVENT_STAT_DEATHS)
      wwBattleCopyStat(playerBlk, statsBlk, ::EVENT_STAT_TIMES_PLAYED)
    }
  }
}


function wwSharedPool_onSessionStart()
{
  dagor.debug("wwSharedPool_onSessionStart")
  unitsDeck_onSessionStart()

  local misblk = ::get_mission_custom_state(true)
  local currentTime = ::get_charserver_time_sec()
  misblk.setInt("startTimestamp", currentTime)

  local misInfoBlk = ::DataBlock()
  ::get_current_mission_info(misInfoBlk)
  local timeLimitMinutes = misInfoBlk.getInt("timeLimit", 0)
  if (timeLimitMinutes < 0) // auto
  {
    misInfoBlk.setInt("timeLimitType", 0)
  }
  else if (timeLimitMinutes > 10000) // unlimited
  {
    misInfoBlk.setInt("timeLimitType", 1)
  }
  else
  {
    misInfoBlk.setInt("timeLimitType", 2)
    misInfoBlk.setInt("timeLimitSec", timeLimitMinutes * 60)
  }

  ::wwBattleLastPeriodicSendTime <- currentTime

  ::wwBattleSendMinPeriodSec <- misblk.getInt("sendMinPeriodSec", 10)
  local sendMaxPeriodSec = misblk.getInt("sendMaxPeriodSec", 60)

  if (::wwSharedPoolInitialArmiesBlk == null)
    ::wwSharedPoolInitialArmiesBlk <- ::DataBlock()
  if ("initialArmies" in misblk)
    ::wwSharedPoolInitialArmiesBlk.setFrom(misblk.initialArmies)

  ::wwSharedPoolPeriodicTaskId <-
      ::periodic_task_register_ex(this,
                                  wwBattlePeriodicUpdateTask,
                                  sendMaxPeriodSec,
                                  ::EPTF_EXECUTE_IMMEDIATELY | ::EPTF_IN_FLIGHT,
                                  ::EPTT_BEST_EFFORT,
                                  true)
  dagor.debug(format("wwSharedPool periodic update task: %d", ::wwSharedPoolPeriodicTaskId))

  ::wwBattleUpdatesEnabled <- true
  ::wwLastUpdateApplied <- -1
}
function wwSharedPool_onSessionEnd()
{
  dagor.debug("wwSharedPool_onSessionEnd")
  unitsDeck_onSessionEnd()

  ::periodic_task_unregister(::wwSharedPoolPeriodicTaskId)
  ::wwBattleUpdatesEnabled = false
}
function wwSharedPool_onPlayerConnected(userId, team, country)
{
  dagor.debug("wwSharedPool_onPlayerConnected")
  wwBattleSetPlayerTeam(userId, team)
  unitsDeck_init(userId, team, country, 0, 0, 0) //rating. to be implemented later

  wwBattleSendUpdateIfNeeded()
}
function wwSharedPool_onPlayerDisconnected(userId)
{
  dagor.debug("wwSharedPool_onPlayerDisconnected")
  unitsDeck_onPlayerDisconnected(userId)

  wwBattleRemovePlayer(userId)

  wwBattleSendUpdateIfNeeded()
}
function wwSharedPool_onBotSpawn(playerIdx, team, country, unit, weapon)
{
  unitsDeck_onBotSpawn(playerIdx, team, country, unit, weapon)
  wwBattleSendUpdateIfNeeded()
}
function wwSharedPool_onPlayerSpawn(userId, team, country, unit, weapon, cost)
{
  dagor.debug("wwSharedPool_onPlayerSpawn "+unit)

  unitsDeck_onPlayerSpawn(userId, team, country, unit, weapon, cost)

  wwBattleSetPlayerTeam(userId, team)

  wwBattleSendUpdateIfNeeded()
}
function wwSharedPool_onUnitKilled(userId, team, unit, isAiUnit)
{
  dagor.debug("wwSharedPool_onUnitKilled "+unit)

  local teamName = get_team_name_by_mp_team(team)
  if (userId < 0)
  {
    // AI or bot
    if (isAiUnit)
    {
      casualtiesHelper_onAIUnitKilled(teamName, unit)
    }
    else
    {
      casualtiesHelper_onUnitKilled(teamName, unit)
    }
  }
}
function wwSharedPool_onBailoutOnAirfield(userId, team, country, unit, weapon)
{
  dagor.debug("wwSharedPool_onBailoutOnAirfield "+unit)
  unitsDeck_onBailoutOnAirfield(userId, team, country, unit, weapon)

  wwBattleSetPlayerTeam(userId, team)

  wwBattleSendUpdateIfNeeded()
}

function wwSharedPool_canPlayerSpawn(userId, team, country, unit, weapon, fuel)
{
  dagor.debug("wwSharedPool_canPlayerSpawn "+unit)
  return unitsDeck_canPlayerSpawn(userId, team, country, unit, weapon, fuel)
}

function wwSharedPool_canBotSpawn(team, unit, weapon, fuel)
{
  return unitsDeck_canBotSpawn(team, unit, weapon, fuel)
}

function wwSharedPool_onDeath(userId, team, country, unit, weapon, nw, na, dmg)
{
  dagor.debug("wwSharedPool_onDeath "+unit)
  unitsDeck_onDeathCommon(userId, team, country, unit, weapon, nw, na, dmg, 0, 1000, 500) //rating. to be implemented later
  if (dmg == 1)
    casualtiesHelper_onUnitKilled(get_team_name_by_mp_team(team), unit)

  wwBattleSendUpdateIfNeeded()
}

function wwSharedPool_onSurvive(userId, team, country, unit, weapon, nw, na, dmg)
{
  unitsDeck_onSurvive(userId, team, country, unit, weapon, nw, na, dmg)
}

function wwSharedPool_onBotSurvive(userId, team, country, unit, weapon)
{
  unitsDeck_onBotSurvive(userId, team, country, unit, weapon)
}

function wwSharedPool_onBattleResult(resultBlk, winnerTeam)
{
  dagor.debug("wwSharedPool_onBattleResult")
  local commonInfoBlk = resultBlk.addBlock("commonInfo")
  local wwBattleResultBlk = commonInfoBlk.addBlock("wwBattleResult")
  wwBattleBuildUpdateBlk(wwBattleResultBlk)
  wwBattleResultBlk.addInt("wpForRewardPool", ::wwSharedPoolTotalWpReward)
  local customRulesBlk = wwBattleResultBlk.customRules

  if ("teams" in customRulesBlk)
  {
    local winnerTeamName = get_team_name_by_mp_team(winnerTeam)
    local teamsBlk = customRulesBlk.teams
    for (local i = 0; i < teamsBlk.blockCount(); i++)
    {
      local teamBlk = teamsBlk.getBlock(i)
      local teamName = teamBlk.getBlockName()
      teamBlk.setStr("result", (teamName == winnerTeamName) ? "win" : "lose")
    }
  }

  local winsAndDefeatsBlk = commonInfoBlk.getBlockByName(::BULK_WINS_AND_DEFEATS_INFO)
  if (!winsAndDefeatsBlk)
    winsAndDefeatsBlk = ::DataBlock()
  wwBattleFillPlayersStats(customRulesBlk, winsAndDefeatsBlk)
}


function wwSharedPool_onModifySessionUserLog(userId, userLogBody)
{
  local misblk = ::get_mission_custom_state(false)

  local wwSharedPoolBlk = userLogBody.addBlock("wwSharedPool")
  wwSharedPoolBlk["operationId"] = misblk["operationId"]
  wwSharedPoolBlk["battleId"] = misblk["battleId"]
  wwSharedPoolBlk["operationMap"] = misblk["operationMap"]
  wwSharedPoolBlk["localTeam"] = wwBattleGetPlayerTeamName(userId)

  local casualtiesBlk = misblk.getBlockByName("casualties")
  if (!casualtiesBlk)
    casualtiesBlk = ::DataBlock()
  local dstBlk = wwSharedPoolBlk.addBlock("casualties")
  for (local i = 0; i < casualtiesBlk.blockCount(); i++)
  {
    local srcTeamBlk = casualtiesBlk.getBlock(i)
    local teamName = srcTeamBlk.getBlockName()
    local dstTeamBlk = dstBlk.addBlock(teamName)

    foreach (unitName, count in srcTeamBlk)
      dstTeamBlk.setInt(unitName, ceil(count).tointeger())
  }

  if (::wwSharedPoolInitialArmiesBlk != null)
  {
    local initialArmiesBlk = wwSharedPoolBlk.addBlock("initialArmies")
    initialArmiesBlk.setFrom(::wwSharedPoolInitialArmiesBlk)
  }

  local wpEarned = userLogBody.getInt("wpEarned", 0)
  wwBattleSetWpEarned(userId, wpEarned)
}


function wwSharedPool_onModifyEarlyLeaveUserLog(userId, userLogBody)
{
  wwSharedPool_onModifySessionUserLog(userId, userLogBody)
}


function wwSharedPool_addWpToOperationPool(amount)
{
  ::wwSharedPoolTotalWpReward = ::wwSharedPoolTotalWpReward + amount
}


//---- WorldWar shared units pool END ----
dagor.debug("wwSharedPool script loaded successfully")