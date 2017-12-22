local time = require("scripts/time.nut")
local systemMsg = ::require("scripts/utils/systemMsg.nut")

class ::WwBattle
{
  id = ""
  status = 0
  teams = null
  pos = null
  maxPlayersPerArmy = null
  minPlayersPerArmy = null
  opponentsType = null
  updateAppliedOnHost = -1
  missionName = ""
  localizeConfig = null
  missionInfo = null
  battleStartMillisec = 0
  ordinalNumber = 0
  sessionId = ""

  queueInfo = null

  constructor(blk = ::DataBlock(), params = null)
  {
    id = blk.id || blk.getBlockName() || ""
    status = blk.status? ::ww_battle_status_name_to_val(blk.status) : 0
    pos = blk.pos ? ::Point2(blk.pos.x, blk.pos.y) : ::Point2()
    maxPlayersPerArmy = blk.maxPlayersPerArmy || 0
    minPlayersPerArmy = blk.minTeamSize || 0
    battleStartMillisec = blk.battleStartTimestamp || 0
    ordinalNumber = blk.ordinalNumber || 0
    opponentsType = blk.opponentsType || -1
    updateAppliedOnHost = blk.updateAppliedOnHost || -1
    missionName = blk.desc ? blk.desc.missionName : ""
    sessionId = blk.desc ? blk.desc.sessionId : ""
    missionInfo = ::get_mission_meta_info(missionName)

    createLocalizeConfig(blk.desc)

    updateParams(blk, params)
    updateTeamsInfo(blk)
    applyBattleUpdates(blk)
  }

  function updateParams(blk, params) {}

  function applyBattleUpdates(blk)
  {
    local updatesBlk = blk.getBlockByName("battleUpdates")
    if (!updatesBlk)
      return

    for (local i = 0; i < updatesBlk.blockCount(); i++)
    {
      local updateBlk = updatesBlk.getBlock(i)
      if (updateBlk.updateId <= updateAppliedOnHost)
        continue

      local teamsBlk = updateBlk.getBlockByName("teams")
      for (local j = 0; j < teamsBlk.blockCount(); j++)
      {
        local teamBlk = teamsBlk.getBlock(j)
        if (teamBlk == null)
          continue

        local teamName = teamBlk.getBlockName() || ""
        if (teamName.len() == 0)
          continue

        local unitsAddedBlock = teamBlk.getBlockByName("unitsAdded")
        local team = teams[teamName]
        local newUnits = []

        for(local k = 0; k < unitsAddedBlock.blockCount(); k++)
        {
          local unitBlock = unitsAddedBlock.getBlock(k)
          if (unitBlock == null)
            continue

          local unitName = unitBlock.getBlockName() || ""
          if (unitName.len() == 0)
            continue

          local hasUnit = false
          foreach(idx, wwUnit in team.unitsRemain)
            if (wwUnit.name == unitName)
            {
              hasUnit = true
              wwUnit.count += unitBlock.count
              break
            }

          if (!hasUnit)
            newUnits.append(unitBlock)
        }

        foreach(idx, unitBlk in newUnits)
          team.unitsRemain.append(::WwUnit(unitBlk))
      }
    }
  }

  function isValid()
  {
    return id.len() > 0
  }

  function isWaiting()
  {
    return status == ::EBS_WAITING ||
           status == ::EBS_STALE
  }

  function isActive()
  {
    return status == ::EBS_ACTIVE_STARTING ||
           status == ::EBS_ACTIVE_MATCHING ||
           status == ::EBS_ACTIVE_CONFIRMED
  }

  function isStarted()
  {
    return status == ::EBS_ACTIVE_MATCHING ||
           status == ::EBS_ACTIVE_CONFIRMED
  }

  function isConfirmed()
  {
    return status == ::EBS_ACTIVE_CONFIRMED
  }

  function isFullSessionByTeam(side = null)
  {
    side = side || ::ww_get_player_side()
    local team = getTeamBySide(side)
    return !team || team.players == team.maxPlayers
  }

  function getLocName()
  {
    return localizeConfig ? ::get_locId_name(localizeConfig, "locName") : id
  }

  function getOrdinalNumber()
  {
    return ordinalNumber
  }

  function getLocDesc()
  {
    return localizeConfig ? ::get_locId_name(localizeConfig, "locDesc") : id
  }

  function getMissionName()
  {
    return !::u.isEmpty(missionName) ? missionName : ""
  }

  function getView()
  {
    return ::WwBattleView(this)
  }

  function getSessionId()
  {
    return sessionId
  }

  function createLocalizeConfig(descBlk)
  {
    localizeConfig = {
      locName = descBlk ? (descBlk.locName || "") : ""
      locDesc = descBlk ? (descBlk.locDesc || "") : ""
    }
  }

  function updateTeamsInfo(blk)
  {
    teams = {}

    local teamsBlk = blk.getBlockByName("teams")
    local descBlk = blk.getBlockByName("desc")
    local waitingTeamsBlk = descBlk ? descBlk.getBlockByName("teamsInfo") : null
    if (!teamsBlk || isWaiting() && !waitingTeamsBlk)
      return

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

      local armyNamesBlk = teamBlk.getBlockByName("armyNames")
      local teamArmyNames = []
      local teamUnitTypes = []
      local firstArmyCountry = ""
      local countries = {}
      if (armyNamesBlk)
      {
        for (local j = 0; j < armyNamesBlk.paramCount(); ++j)
        {
          local armyName = armyNamesBlk.getParamValue(j) || ""
          if (armyName.len() == 0)
            continue

          local army = g_world_war.getArmyByName(armyName)
          if (!army)
          {
            ::script_net_assert_once("WW can't find army", "ww: can't find army " + armyName)
            continue
          }

          if (!(army.owner.country in countries))
            countries[army.owner.country] <- []
          countries[army.owner.country].append(army)

          if (firstArmyCountry.len() == 0)
            firstArmyCountry = army.owner.country

          teamArmyNames.push(armyName)
          ::u.appendOnce(army.unitType, teamUnitTypes)
        }
      }

      local teamUnitsRemain = []
      if (!isWaiting())
      {
        local unitsRemainBlk = teamBlk.getBlockByName("unitsRemain")
        local aiUnitsBlk = teamBlk.getBlockByName("aiUnits")
        teamUnitsRemain.extend(::WwUnit.loadUnitsFromBlk(unitsRemainBlk, aiUnitsBlk))
        teamUnitsRemain.extend(::WwUnit.getFakeUnitsArray(teamBlk))
      }

      local teamInfo = {name = teamName
                        players = numPlayers
                        maxPlayers = teamMaxPlayers
                        minPlayers = minPlayersPerArmy
                        side = ::ww_side_name_to_val(teamSideName)
                        country = firstArmyCountry
                        countries = countries
                        armyNames = teamArmyNames
                        unitsRemain = teamUnitsRemain
                        unitTypes = teamUnitTypes}
      teams[teamName] <- teamInfo
    }
  }

  function getCantJoinReasonData(side, needCheckSquad = true)
  {
    local res = {
      code = WW_BATTLE_CANT_JOIN_REASON.CAN_JOIN
      canJoin = false
      reasonText = ""
      shortReasonText = ""
    }

    if (!isValid())
    {
      res.code = WW_BATTLE_CANT_JOIN_REASON.NOT_ACTIVE
      res.reasonText = ::loc("worldWar/battleNotSelected")
      return res
    }

    if (!isActive())
    {
      res.code = WW_BATTLE_CANT_JOIN_REASON.NOT_ACTIVE
      res.reasonText = ::loc(isStillInOperation() ? "worldwar/battleNotActive" : "worldwar/battle_finished")
      return res
    }

    if (::ww_get_player_side() != ::SIDE_NONE && ::ww_get_player_side() != side)
    {
      res.code = WW_BATTLE_CANT_JOIN_REASON.WRONG_SIDE
      res.reasonText = ::loc("worldWar/cant_fight_for_enemy_side")
      return res
    }

    if (side == ::SIDE_NONE)
    {
      ::script_net_assert_once("WW check battle without player side", "ww: check battle without player side")
      res.code = WW_BATTLE_CANT_JOIN_REASON.UNKNOWN_SIDE
      res.reasonText = ::loc("msgbox/internal_error_header")
      return res
    }

    local team = getTeamBySide(side)
    if (!team)
    {
      ::script_net_assert_once("WW can't find team in battle", "ww: can't find team in battle")
      res.code = WW_BATTLE_CANT_JOIN_REASON.NO_TEAM
      res.reasonText = ::loc("msgbox/internal_error_header")
      return res
    }

    if (!team.country)
    {
      ::script_net_assert_once("WW can't get country",
                               "ww: can't get country for team "+team.name)
      res.code = WW_BATTLE_CANT_JOIN_REASON.NO_COUNTRY_IN_TEAM
      res.reasonText = ::loc("msgbox/internal_error_header")
      return res
    }

    local countryName = getCountryNameBySide(side)
    if (!countryName)
    {
      ::script_net_assert_once("WW can't get country",
                  "ww: can't get country for team "+team.name+" from "+team.country)
      res.code = WW_BATTLE_CANT_JOIN_REASON.NO_COUNTRY_BY_SIDE
      res.reasonText = ::loc("msgbox/internal_error_header")
      return res
    }

    local teamName = getTeamNameBySide(side)
    if (!teamName)
    {
      ::script_net_assert_once("WW can't get team",
              "ww: can't get team for team "+team.name+" for battle "+id)
      res.code = WW_BATTLE_CANT_JOIN_REASON.NO_TEAM_NAME_BY_SIDE
      res.reasonText = ::loc("msgbox/internal_error_header")
      return res
    }

    if (team.players >= team.maxPlayers)
    {
      res.code = WW_BATTLE_CANT_JOIN_REASON.TEAM_FULL
      res.reasonText = ::loc("worldwar/army_full")
      return res
    }

    local remainUnits = getTeamRemainUnits(team)
    local myCheckingData = ::g_squad_utils.getMemberAvailableUnitsCheckingData(::g_user_utils.getMyStateData(), remainUnits, team.country)
    if (myCheckingData.joinStatus != memberStatus.READY)
    {
      res.code = WW_BATTLE_CANT_JOIN_REASON.UNITS_NOT_ENOUGH_AVAILABLE
      res.reasonText = ::loc(::g_squad_utils.getMemberStatusLocId(myCheckingData.joinStatus))
      return res
    }

    if (needCheckSquad && ::g_squad_manager.isInSquad())
    {
      updateCantJoinReasonDataBySquad(team, res)
      if (!::u.isEmpty(res.reasonText))
        return res
    }

    res.canJoin = true

    return res
  }

  function isPlayerTeamFull()
  {
    local team = getTeamBySide(::ww_get_player_side())
    if (team)
      return team.players >= team.maxPlayers
    return false
  }

  function isStillInOperation()
  {
    local battles = ::g_world_war.getBattles(
        (@(id) function(checkedBattle) {
          return checkedBattle.id == id
        })(id)
      )
    return battles.len() > 0
  }

  function updateCantJoinReasonDataBySquad(team, reasonData)
  {
    if (!::g_squad_manager.isSquadLeader())
    {
      reasonData.code = WW_BATTLE_CANT_JOIN_REASON.SQUAD_NOT_LEADER
      reasonData.reasonText = ::loc("worldwar/squad/onlyLeaderCanJoinBattle")
      return reasonData
    }

    if (!::g_squad_utils.canJoinByMySquad(null, team.country))
    {
      reasonData.code = WW_BATTLE_CANT_JOIN_REASON.SQUAD_WRONG_SIDE
      reasonData.reasonText = ::loc("worldWar/squad/membersHasDifferentSide")
      return reasonData
    }

    if ((team.players + ::g_squad_manager.getOnlineMembersCount()) > team.maxPlayers)
    {
      reasonData.code = WW_BATTLE_CANT_JOIN_REASON.SQUAD_TEAM_FULL
      reasonData.reasonText = ::loc("worldwar/squad/army_full")
      return reasonData
    }

    if (!::g_squad_manager.readyCheck(false))
    {
      reasonData.code = WW_BATTLE_CANT_JOIN_REASON.SQUAD_NOT_ALL_READY
      reasonData.reasonText = ::loc("squad/not_all_ready")
      return reasonData
    }

    if (::has_feature("WorldWarSquadInfo") && !::g_squad_manager.crewsReadyCheck())
    {
      reasonData.code = WW_BATTLE_CANT_JOIN_REASON.SQUAD_NOT_ALL_CREWS_READY
      reasonData.reasonText = ::loc("squad/not_all_crews_ready")
      return reasonData
    }

    local remainUnits = getTeamRemainUnits(team)
    local membersCheckingDatas = ::g_squad_utils.getMembersAvailableUnitsCheckingData(remainUnits, team.country)

    local langConfig = []
    local shortMessage = ""
    foreach (idx, data in membersCheckingDatas)
    {
      if (data.joinStatus != memberStatus.READY && data.memberData.online == true)
      {
        local memberLangConfig = [
          systemMsg.makeColoredValue(COLOR_TAG.USERLOG, data.memberData.name),
          "ui/colon",
          ::g_squad_utils.getMemberStatusLocId(data.joinStatus)
        ]
        langConfig.append(memberLangConfig)
        if (!shortMessage.len())
          shortMessage = systemMsg.configToLang(memberLangConfig) || ""
      }

      if (!langConfig.len())
        data.unitsCountUnderLimit <- getAvailabelUnitsCountUnderLimit(data.unbrokenAvailableUnits,
                                                                      remainUnits, ::g_squad_manager.getSquadSize())
    }

    if (langConfig.len())
    {
      reasonData.code = WW_BATTLE_CANT_JOIN_REASON.SQUAD_MEMBER_ERROR
      reasonData.reasonText = systemMsg.configToLang(langConfig, null, "\n") || ""
      reasonData.shortReasonText = shortMessage
      return reasonData
    }

    if (!checkAvailableSquadUnitsAdequacy(membersCheckingDatas, remainUnits))
    {
      reasonData.code = WW_BATTLE_CANT_JOIN_REASON.SQUAD_UNITS_NOT_ENOUGH_AVAILABLE
      reasonData.reasonText = ::loc("worldwar/squad/insufficiently_available_units")
      return reasonData
    }

    if (!::g_squad_manager.readyCheck(true))
    {
      reasonData.code = WW_BATTLE_CANT_JOIN_REASON.SQUAD_HAVE_UNACCEPTED_INVITES
      reasonData.reasonText = ::loc("squad/revoke_non_accept_invites")
      reasonData.shortReasonText = ::loc("squad/has_non_accept_invites")
      return reasonData
    }
  }

  function tryToJoin(side)
  {
    local cantJoinReasonData = getCantJoinReasonData(side, true)
    if (!cantJoinReasonData.canJoin)
    {
      ::showInfoMsgBox(cantJoinReasonData.reasonText)
      return
    }

    local joinCb = ::Callback(@() join(side), this)
    local warningReasonData = getWarningReasonData(side)
    if (warningReasonData.needShow && !::g_squad_manager.isInSquad() &&
        !::loadLocalByAccount(WW_SKIP_BATTLE_WARNINGS_SAVE_ID, false))
    {
      ::gui_start_modal_wnd(::gui_handlers.SkipableMsgBox,
        {
          parentHandler = this
          message = warningReasonData.warningText
          ableToStartAndSkip = true
          onStartPressed = joinCb
          skipFunc = @(value) ::saveLocalByAccount(WW_SKIP_BATTLE_WARNINGS_SAVE_ID, value)
        })
      return
    }

    joinCb()
  }

  function join(side)
  {
    local opId = ::ww_get_operation_id()
    local countryName = getCountryNameBySide(side)
    local teamName = getTeamNameBySide(side)

    dagor.debug("ww: join ww battle op:" + opId.tostring() + ", battle:" + id +
                ", country:" + countryName + ", team:" + teamName)

    ::WwBattleJoinProcess(this, side)
    ::ww_event("JoinBattle", {battleId = id})
  }

  function checkAvailableSquadUnitsAdequacy(membersCheckingDatas, remainUnits)
  {
    membersCheckingDatas.sort(function(a, b) {
                                if (a.unitsCountUnderLimit != b.unitsCountUnderLimit)
                                  return a.unitsCountUnderLimit > b.unitsCountUnderLimit ? -1 : 1
                                return 0
                              })

    for (local i = membersCheckingDatas.len() - 1; i >= 0; i--)
      if (membersCheckingDatas[i].unitsCountUnderLimit >= membersCheckingDatas.len())
        membersCheckingDatas.remove(i)

    local unbrokenAvailableUnits = []
    foreach (idx, data in membersCheckingDatas)
      unbrokenAvailableUnits.append(data.unbrokenAvailableUnits)

    return ::g_squad_utils.checkAvailableUnits(unbrokenAvailableUnits, remainUnits)
  }

  function getAvailabelUnitsCountUnderLimit(availableUnits, remainUnits, limit)
  {
    local unitsSummary = 0
    foreach(idx, name in availableUnits)
    {
      unitsSummary += remainUnits[name]
      if (unitsSummary >= limit)
        break
    }

    return unitsSummary
  }

  function isArmyJoined(armyName)
  {
    foreach(teamData in teams)
      if (::isInArray(armyName, teamData.armyNames))
        return true
    return false
  }

  function getWarningReasonData(side)
  {
    local res = {
        needShow = false
        warningText = ""
      }

    if (!isValid())
    {
      return res
    }

    local team = getTeamBySide(side)
    local countryCrews = ::get_country_crews(team.country)
    local hasSlotWithUnavailableUnit = false
    local availableUnits = getTeamRemainUnits(team)
    local crewNames = []
    foreach(idx, crew in countryCrews)
    {
      local crewUnit = ::g_crew.getCrewUnit(crew)
      if (crewUnit != null)
        crewNames.append(crewUnit.name)

      if (crewUnit == null || !(crewUnit.name in availableUnits))
        hasSlotWithUnavailableUnit = true
    }

    if (hasSlotWithUnavailableUnit)
      foreach(unitName, count in availableUnits)
        if (!isInArray(unitName, crewNames) && ::can_crew_take_unit(::getAircraftByName(unitName)))
        {
          res.needShow = true
          res.warningText = ::loc("worldWar/warning/can_insert_more available_units")
          return res
        }

    return res
  }

  function getTeamRemainUnits(team)
  {
    local availableUnits = {}
    foreach(unit in team.unitsRemain)
      if (unit.count > 0 && !unit.isForceControlledByAI)
        availableUnits[unit.name] <- unit.count

    return availableUnits
  }

  function getCountryNameBySide(side = -1)
  {
    if (side == -1)
      side = ::ww_get_player_side()

    local team = getTeamBySide(side)
    return team?.country
  }

  function getTeamNameBySide(side = -1)
  {
    if (side == -1)
      side = ::ww_get_player_side()

    local team = getTeamBySide(side)
    return ::g_string.cutPrefix(team.name, "team")
  }

  function getTeamBySide(side)
  {
    return ::u.search(teams,
                      (@(side) function (team) {
                        return team.side == side
                      })(side)
                     )
  }

  function getQueueId()
  {
    return ::ww_get_operation_id() + "_" + id
  }

  function getAvailableUnitTypes()
  {
    switch(opponentsType)
    {
      case "BUT_AIR":
        return [::ES_UNIT_TYPE_AIRCRAFT]

      case "BUT_GROUND":
        return [::ES_UNIT_TYPE_TANK]

      case "BUT_AIR_GROUND":
      case "BUT_ARTILLERY_AIR":
        return [::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_TANK]

      case "BUT_INFANTRY":
      case "BUT_ARTILLERY_GROUND":
        return []
    }

    return []
  }

  function getSectorName()
  {
    if (!isValid())
      return ""

    local sectorIdx = ::ww_get_zone_idx_world(pos)
    return sectorIdx >= 0 ? ::ww_get_zone_name(sectorIdx) : ""
  }

  function getBattleDurationTime()
  {
    if (battleStartMillisec)
    {
      local millisec = ::ww_get_operation_time_millisec() - battleStartMillisec
      return time.millisecondsToSeconds(millisec).tointeger()
    }

    return 0
  }

  function isTanksCompatible()
  {
    return ::isInArray(opponentsType, ["BUT_GROUND", "BUT_AIR_GROUND", "BUT_ARTILLERY_AIR"])
  }

  function isAutoBattle()
  {
    if (!isStillInOperation())
      return false

    if (status == ::EBS_ACTIVE_AUTO ||
        status == ::EBS_ACTIVE_FAKE)
      return true

    switch(opponentsType)
    {
      case "BUT_INFANTRY":
      case "BUT_ARTILLERY_GROUND":
        return true
    }

    return false
  }
}
