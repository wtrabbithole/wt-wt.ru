//---- Shared units pool BEGIN ----
function sharedPool_onSessionStart()
{
  dagor.debug("sharedPool_onSessionStart")

  local gblk = ::get_mission_custom_state(true)
  local mis = get_current_mission_info_cached()
  gblk.setFrom(mis.customRules)
  sharedPool_validateCustomRules() 
}

function sharedPool_onSessionEnd()
{
  dagor.debug("sharedPool_onSessionEnd")
}

function sharedPool_onPlayerConnected(userId, team, country)
{
  dagor.debug("sharedPool_onPlayerConnected")
}

function sharedPool_onPlayerDisconnected(userId)
{
  dagor.debug("sharedPool_onPlayerDisconnected")
}

function sharedPool_validateCustomRules()
{
  local rules_blk = ::get_mission_custom_state(true)
  local unitLimitsBlocks = [{ name="limitedUnits",   paramsType="integer", paramsDefaultValue=1},
                            { name="unlimitedUnits", paramsType="bool",    paramsDefaultValue=true}]
  foreach(team_name, team in rules_blk.teams)
  {
    foreach(check_block in unitLimitsBlocks)
    {
      if(team[check_block.name] != null)
      {
        local validBlock = DataBlock()
        foreach(param_name, param in team[check_block.name])
        {
          if(typeof(param) != check_block.paramsType)
          {
            dagor.debug("ERROR: sharedPool config error. Param "+param_name+" in "+check_block.name+" block has wrong type. It should be of type "+check_block.paramsType+". Set to default value.")
            validBlock[param_name] <- check_block.paramsDefaultValue
          }
          else
          {
             validBlock[param_name] <- team[check_block.name][param_name]
          }
        }
        team[check_block.name].setFrom(validBlock)
      }
    }
  }
}

function sharedPool_internal_modify_unit(misblk, teamName, unit, add, allowCreateUnit)
{
  dagor.debug("sharedPool_internal_modify_unit "+unit+" action=" + (add < 0 ? "spawn":"restore"))

  if ("teams" in misblk)
  {
    if (teamName in misblk.teams)
    {
      if ("limitedUnits" in misblk.teams[teamName])
      {
        if (allowCreateUnit && !(unit in misblk.teams[teamName].limitedUnits) )
        {
          misblk = ::get_mission_custom_state(true)
          misblk.teams[teamName].limitedUnits.setInt(unit, 0);
          dagor.debug("sharedPool_internal_modify_unit new unit type added: "+unit+" for "+teamName)
        }

        if (unit in misblk.teams[teamName].limitedUnits)
        {
          local num = misblk.teams[teamName].limitedUnits[unit] + add
          misblk = ::get_mission_custom_state(true)
          misblk.teams[teamName].limitedUnits[unit] = num
          dagor.debug("sharedPool_internal_modify_unit "+unit+" count for "+teamName+" is now "+num)
        }
      }

      if ("limitedClasses" in misblk.teams[teamName])
      {
        local unitClass = getWpcostUnitClass(unit)
        if (unitClass in misblk.teams[teamName].limitedClasses)
        {
          local num = misblk.teams[teamName].limitedClasses[unitClass] + add
          misblk = ::get_mission_custom_state(true)
          misblk.teams[teamName].limitedClasses[unitClass] = num
          dagor.debug("sharedPool_internal_modify_unit "+unitClass+" count for "+teamName+" is now "+num)
        }
      }

      if ("limitedTags" in misblk.teams[teamName])
      {
        foreach (tag, val in misblk.teams[teamName].limitedTags)
        {
          if (unitHasTag(unit, tag))
          {
            local num = val + add
            misblk = ::get_mission_custom_state(true)
            misblk.teams[teamName].limitedTags[tag] = num
            dagor.debug("sharedPool_internal_modify_unit "+tag+" count for "+teamName+" is now "+num)
          }
        }
      }
    }
  }
}


function modTeamSpawnLimits(teamName, unit, add, allowCreateUnit)
{
  dagor.debug("modTeamSpawnLimits "+unit+" action=" + (add < 0 ? "spawn":"restore"))
  local misblk = ::get_mission_custom_state(false)
  sharedPool_internal_modify_unit(misblk, teamName, unit, add, allowCreateUnit)

  if ("teams" in misblk)
  {
    if (teamName in misblk.teams)
    {
      if ("spawnLimit" in misblk.teams[teamName])
      {
        local num = misblk.teams[teamName].spawnLimit +add
        misblk = ::get_mission_custom_state(true)
        misblk.teams[teamName].spawnLimit = num
        dagor.debug("modTeamSpawnLimits spawn limit for "+teamName+" is now "+num)
      }
    }
  }
}

function sharedPool_onPlayerSpawn_internal(userId, team, country, unit, weapon, add)
{
  dagor.debug("sharedPool_onPlayerSpawn "+unit+" action=" + (add < 0 ? "spawn":"restore"))
  local misblk = ::get_mission_custom_state(false)
  local teamName = get_team_name_by_mp_team(team)

  modTeamSpawnLimits(teamName, unit, add, false)

  if ("teams" in misblk)
  {
    if (teamName in misblk.teams)
    {
      if ("playerMaxSpawns" in misblk.teams[teamName])
      {
        if (!("spawns" in misblk))
          misblk["spawns"] = ::DataBlock();
        local suid = userId.tostring();
        local num = 0
        if (suid in misblk.spawns)
          num = misblk.spawns[suid]
        num = num - add
        ::dagor.assertf(num >= 0, "num of spawns for " + teamName + " less zero " + num)
        misblk = ::get_mission_custom_state(true)
        misblk.spawns[suid] = num
        dagor.debug("sharedPool_onPlayerSpawn "+suid+" global count is now "+num)
      }
    }
  }
}

function sharedPool_onPlayerSpawn(userId, team, country, unit, weapon, cost)
{
  sharedPool_onPlayerSpawn_internal(userId, team, country, unit, weapon, -1)
  sharedPool_addActiveClass_internal(team, unit)
}

function sharedPool_addActiveClass_internal(team, unit)
{
  local misblk = ::get_mission_custom_state(false)
  local teamName = get_team_name_by_mp_team(team)
  if ("teams" in misblk)
  {
    if (teamName in misblk.teams)
    {
      if ("limitedActiveClasses" in misblk.teams[teamName])
      {
        local unitClass = getWpcostUnitClass(unit)
        misblk = ::get_mission_custom_state(true)
        if (!("activeClasses" in misblk.teams[teamName]))
          misblk.teams[teamName].activeClasses = ::DataBlock()
        if (!(unitClass in misblk.teams[teamName].activeClasses))
          misblk.teams[teamName].activeClasses[unitClass] = 1;
        else
          misblk.teams[teamName].activeClasses[unitClass] += 1;
        dagor.debug("sharedPool added active class "+unitClass+" to a total of "+
          misblk.teams[teamName].activeClasses[unitClass] + " due to spawn on "+unit);
      }
    }
  }
}

function sharedPool_removeActiveClass_internal(team, unit)
{
  local misblk = ::get_mission_custom_state(false)
  local teamName = get_team_name_by_mp_team(team)
  if ("teams" in misblk)
  {
    if (teamName in misblk.teams)
    {
      if ("limitedActiveClasses" in misblk.teams[teamName])
      {
        local unitClass = getWpcostUnitClass(unit)
        misblk = ::get_mission_custom_state(true)
        if (!("activeClasses" in misblk.teams[teamName]))
        {
          dagor.debug("sharedPool internal error: removing class "+unitClass+" which never was added")
          return
        }
        if (!(unitClass in misblk.teams[teamName].activeClasses))
        {
          dagor.debug("sharedPool internal error: removing class "+unitClass+" which never was added")
          return
        }
        if (misblk.teams[teamName].activeClasses[unitClass] <= 0)
        {
          dagor.debug("sharedPool internal error: removing class "+unitClass+" below zero")
          return
        }
        misblk.teams[teamName].activeClasses[unitClass] -= 1;
        dagor.debug("sharedPool decrement active class "+unitClass+" to a total of "+
          misblk.teams[teamName].activeClasses[unitClass] + " due to despawn of "+unit);
      }
    }
  }
}

function sharedPool_onDeath(userId, team, country, unit, weapon, nw, na, dmg)
{
  sharedPool_removeActiveClass_internal(team, unit)
}

function sharedPool_onBailoutOnAirfield(userId, team, country, unit, weapon)
{
  sharedPool_onPlayerSpawn_internal(userId, team, country, unit, weapon, 1)
  local mis = get_current_mission_info_cached()
  if (mis.useSpawnScore || mis.useTeamSpawnScore)
  {
    local cost = get_unit_spawn_score(userId, unit)
    if (cost > 0)
      inc_player_spawn_score(userId, cost);
  }
}

function sharedPool_canPlayerSpawn(userId, team, country, unit, weapon, fuel)
{
  dagor.debug("sharedPool_canPlayerSpawn "+unit)
  local misblk = ::get_mission_custom_state(false)
  local teamName = get_team_name_by_mp_team(team)

  if ("teams" in misblk)
  {
    if (teamName in misblk.teams)
    {
      local foundLimitedUnit = false
      if ("limitedUnits" in misblk.teams[teamName])
      {
        if (unit in misblk.teams[teamName].limitedUnits)
        {
          if (misblk.teams[teamName].limitedUnits[unit] <= 0)
          {
            dagor.debug("sharedPool_canPlayerSpawn "+unit+" - count exceeded for "+
                        teamName+", return false")
            return false
          }
          foundLimitedUnit = true
        }
      }

      if (!foundLimitedUnit && ("unlimitedUnits" in misblk.teams[teamName]))
      {
        if (!(unit in misblk.teams[teamName].unlimitedUnits))
        {
          dagor.debug("sharedPool_canPlayerSpawn "+unit+" - unit not listed for "+
                      teamName+", return false")
          return false
        }
      }

      if ("limitedClasses" in misblk.teams[teamName])
      {
        local unitClass = getWpcostUnitClass(unit)
        if (unitClass in misblk.teams[teamName].limitedClasses)
        {
          if (misblk.teams[teamName].limitedClasses[unitClass] <= 0)
          {
            dagor.debug("sharedPool_canPlayerSpawn "+unitClass+" - count exceeded for "+
                        teamName+", return false")
            return false
          }
        }
      }

      if ("limitedActiveClasses" in misblk.teams[teamName])
      {
        local unitClass = getWpcostUnitClass(unit)
        local checkNum = false
        local checkPerc = false
        local value = 0
        if (unitClass in misblk.teams[teamName].limitedActiveClasses)
        {
          checkNum = true
          value = misblk.teams[teamName].limitedActiveClasses[unitClass]
        }
        else if ((unitClass+"_perc") in misblk.teams[teamName].limitedActiveClasses)
        {
          checkPerc = true
          value = misblk.teams[teamName].limitedActiveClasses[unitClass+"_perc"]
        }
        if (checkNum || checkPerc)
        {
          local count = 0
          if ("activeClasses" in misblk.teams[teamName])
            if (unitClass in misblk.teams[teamName].activeClasses)
              count = misblk.teams[teamName].activeClasses[unitClass]

          if (checkPerc)
          {
            local playersCount = get_mplayers_list(team, false).len()
            value = (playersCount.tofloat()*value/100.0).tointeger()
          }

          if (count >= value)
          {
            dagor.debug("sharedPool_canPlayerSpawn "+unitClass+
            " - active count ("+count+" >= "+value+") "+
              "exceeded for "+teamName+", return false")
            return false;
          }
        }
      }

      if ("limitedTags" in misblk.teams[teamName])
      {
        foreach (tag, val in misblk.teams[teamName].limitedTags)
        {
          if (unitHasTag(unit, tag))
            if (val <= 0)
            {
              dagor.debug("sharedPool_canPlayerSpawn "+tag+" - count exceeded for "+
                          teamName+", return false")
              return false
            }
        }
      }

      if ("spawnLimit" in misblk.teams[teamName])
      {
        if (misblk.teams[teamName].spawnLimit <= 0)
        {
          dagor.debug("sharedPool_canPlayerSpawn - spawn limit exceeded for "+
                      teamName+", return false")
          return false
        }
      }

      if ("playerMaxSpawns" in misblk.teams[teamName])
      {
        if ("spawns" in misblk)
        {
          local suid = userId.tostring();
          if (suid in misblk.spawns)
          {
            if (misblk.spawns[suid] >= misblk.teams[teamName].playerMaxSpawns)
            {
              dagor.debug("sharedPool_canPlayerSpawn "+suid+" - count exceeded, return false")
              return false
            }
          }
        }
      }
    }
  }
  return true
}

//---- Shared units pool END ----
dagor.debug("sharedPool loaded successful")