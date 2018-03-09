local u = ::require("std/u.nut")


const WW_MAX_PLAYERS_DISBALANCE_DEFAULT = 3

local WwGlobalBattle = class extends ::WwBattle
{
  operationId = -1
  sidesByCountry = null

  function updateParams(blk, params)
  {
    sidesByCountry = {}

    local teamsBlk = blk.getBlockByName("teams")
    if (!teamsBlk)
      return

    local countries = params?.countries
    for (local i = 0; i < teamsBlk.blockCount(); i++)
    {
      local teamBlk = teamsBlk.getBlock(i)
      local teamSide = teamBlk.side
      local teamCountry = countries?[teamSide]
      if (teamSide && teamCountry)
        sidesByCountry[teamCountry] <- ::ww_side_name_to_val(teamSide)
    }
  }

  function updateTeamsInfo(blk)
  {
    teams = {}

    local teamsBlk = blk.getBlockByName("teams")
    if (!teamsBlk)
      return

    local updatesBlk = blk.getBlockByName("battleUpdates")
    local updatedTeamsBlk = updatesBlk ? updatesBlk.getBlockByName("teams") : null
    for (local i = 0; i < teamsBlk.blockCount(); ++i)
    {
      local teamBlk = teamsBlk.getBlock(i)
      local teamName = teamBlk.getBlockName() || ""
      if (teamName.len() == 0)
        continue

      local teamSideName = teamBlk.side || ""
      if (teamSideName.len() == 0)
        continue

      local numPlayers = teamBlk.players || 0
      local teamMaxPlayers = teamBlk.maxPlayers || 0
      local teamUnitTypes = []

      local teamUnitsRemain = []
      local unitsRemainBlk = teamBlk.getBlockByName("unitsRemain")
      teamUnitsRemain.extend(::WwUnit.loadUnitsFromBlk(unitsRemainBlk))

      if (updatedTeamsBlk)
      {
        local updatedTeamBlk = updatedTeamsBlk.getBlockByName(teamName)
        if (updatedTeamBlk)
          teamUnitsRemain.extend(
            ::WwUnit.loadUnitsFromBlk(updatedTeamBlk.getBlockByName("unitsAdded")))
      }

      teamUnitsRemain.sort(@(a, b) a.wwUnitType.sortCode <=> b.wwUnitType.sortCode)
      foreach(unit in teamUnitsRemain)
        if (!unit.isControlledByAI())
          ::u.appendOnce(unit.wwUnitType.code, teamUnitTypes)

      local teamInfo = {name = teamName
                        players = numPlayers
                        maxPlayers = teamMaxPlayers
                        minPlayers = minPlayersPerArmy
                        side = ::ww_side_name_to_val(teamSideName)
                        unitsRemain = teamUnitsRemain
                        unitTypes = teamUnitTypes}
      teams[teamName] <- teamInfo
    }
  }

  function isStillInOperation()
  {
    return true
  }

  function hasSideCountry(country)
  {
    return sidesByCountry?[country]
  }

  function getMyAssignCountry()
  {
    local operation = ::g_ww_global_status.getOperationById(operationId)
    return operation ? operation.getMyAssignCountry() : null
  }

  function isVisibleInBattlesList(country)
  {
    return !isHiddenByExcessPlayers(country) && isOperationMapAvaliable()
  }

  function isHiddenByExcessPlayers(country)
  {
    if (getMyAssignCountry())
      return false

    local excessPlayersSide = getExcessPlayersSide()
    if (excessPlayersSide == ::SIDE_NONE)
      return false

    return excessPlayersSide == sidesByCountry?[country]
  }

  function isOperationMapAvaliable()
  {
    local operation = ::g_ww_global_status.getOperationById(operationId)
    if (!operation)
      return false

    local map = operation.getMap()
    if (!map)
      return false

    return map.isVisible()
  }

  function getExcessPlayersSide()
  {
    if (!isConfirmed())
      return ::SIDE_NONE

    local team1Players = getTeamBySide(::SIDE_1)?.players ?? 0
    local team2Players = getTeamBySide(::SIDE_2)?.players ?? 0
    local maxPlayersDisbalance = ::g_world_war.getSetting(
      "maxBattlePlayersDisbalance", WW_MAX_PLAYERS_DISBALANCE_DEFAULT)

    if (::abs(team1Players - team2Players) <= maxPlayersDisbalance)
      return ::SIDE_NONE

    return team1Players > team2Players ? ::SIDE_1 : ::SIDE_2
  }

  function setOperationId(operId)
  {
    operationId = operId
  }

  function getOperationId()
  {
    return operationId
  }

  function getSectorName()
  {
    return ""
  }

  function getSideByCountry(country)
  {
    return sidesByCountry?[country] ?? ::SIDE_NONE
  }

  function hasUnitsToFight(country)
  {
    local side = getSideByCountry(country)
    foreach(teamData in teams)
    {
      if (teamData.side != side)
        continue

      foreach(unitData in teamData.unitsRemain)
      {
        local unit = ::all_units?[unitData.name]
        if (!unit)
          continue

        if (unit.canAssignToCrew(country))
          return true
      }
    }

    return false
  }
}

u.registerClass("WwGlobalBattle", WwGlobalBattle, @(b1, b2) b1.id == b2.id)

return WwGlobalBattle
