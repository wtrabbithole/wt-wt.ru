class ::WwBattleView
{
  id = ""
  battle = null

  missionName = ""
  name = ""
  desc = ""
  maxPlayersPerArmy = -1

  teamBlock = null
  largeArmyGroupIconTeamBlock = null
  mediumArmyGroupIconTeamBlock = null

  showBattleStatus = false
  hideDesc = false

  sceneTplArmyViewsName = "gui/worldWar/worldWarMapArmyItem"
  unitStringTpl = "gui/commonParts/shortUnitString"

  constructor(_battle = null)
  {
    battle = _battle || ::WwBattle()

    missionName = battle.getMissionName()
    name = battle.isStarted() ? battle.getLocName() : ""
    desc = battle.getLocDesc()
    maxPlayersPerArmy = battle.maxPlayersPerArmy
  }

  function getId()
  {
    return battle.id
  }

  function getMissionName()
  {
    return name
  }

  function getShortBattleName()
  {
    return ::loc("worldWar/shortBattleName", {number = battle.getOrdinalNumber()})
  }

  function getBattleName()
  {
    if (!battle.isValid())
      return null

    return ::loc("worldWar/battleName", {number = battle.getOrdinalNumber()})
  }

  function defineTeamBlock()
  {
    teamBlock = getTeamBlockByIconSize(WW_ARMY_GROUP_ICON_SIZE.BASE)
  }

  function getTeamDataBySide(side, iconSize = null)
  {
    iconSize = iconSize || WW_ARMY_GROUP_ICON_SIZE.BASE

    local currentTeamBlock = getTeamBlockByIconSize(iconSize, true)
    local teamName = "team" + battle.getTeamNameBySide(side)

    foreach(team in currentTeamBlock)
      if (team.teamName == teamName)
        return team

    return null
  }

  function getTeamBlockByIconSize(iconSize, isInBattlePanel = false, param = null)
  {
    if (iconSize == WW_ARMY_GROUP_ICON_SIZE.MEDIUM)
    {
      if (largeArmyGroupIconTeamBlock == null)
        largeArmyGroupIconTeamBlock = getTeamsData(iconSize, isInBattlePanel, param)

      return largeArmyGroupIconTeamBlock
    }
    else if (iconSize == WW_ARMY_GROUP_ICON_SIZE.SMALL)
    {
      if (mediumArmyGroupIconTeamBlock == null)
        mediumArmyGroupIconTeamBlock = getTeamsData(iconSize, isInBattlePanel, param)

      return mediumArmyGroupIconTeamBlock
    }
    else
    {
      if (teamBlock == null)
        teamBlock = getTeamsData(WW_ARMY_GROUP_ICON_SIZE.BASE, isInBattlePanel, param)

      return teamBlock
    }
  }

  function getTeamsData(iconSize, isInBattlePanel, param)
  {
    local teams = []
    local maxSideArmiesNumber = 0
    local isVersusTextAdded = false
    local hasArmyInfo = ::getTblValue("hasArmyInfo", param, true)
    local hasVersusText = ::getTblValue("hasVersusText", param)
    local canAlignRight = ::getTblValue("canAlignRight", param, true)
    foreach(sideIdx, side in ::g_world_war.getSidesOrder())
    {
      local team = battle.getTeamBySide(side)
      if (!team)
        continue

      local armies = {
        countryIcon = ""
        countryIconBig = ""
        armyViews = ""
        maxSideArmiesNumber = 0
      }

      local armyViews = []
      foreach (country, armiesArray in team.countries)
      {
        armies.countryIcon = ::get_country_icon(country)
        armies.countryIconBig = ::get_country_icon(country, true)
        foreach(army in armiesArray)
          armyViews.append(army.getView())
      }

      if (hasVersusText && !isVersusTextAdded)
      {
        armyViews.top().setHasVersusText(true)
        isVersusTextAdded = true
      }
      else
        armyViews.top().setHasVersusText(false)

      maxSideArmiesNumber = ::max(maxSideArmiesNumber, armyViews.len())

      local view = {
        army = armyViews
        delimetrRightPadding = hasArmyInfo ? "8*@sf/@pf_outdated" : 0
        reqUnitTypeIcon = true
        hideArrivalTime = true
        showArmyGroupText = false
        hasTextAfterIcon = true
        battleDescriptionIconSize = iconSize
        isArmyAlwaysUnhovered = true
        needShortInfoText = hasArmyInfo
        hasTextAfterIcon = hasArmyInfo
        isAlignRight = canAlignRight && sideIdx != 0
      }

      armies.armyViews = ::handyman.renderCached(sceneTplArmyViewsName, view)
      local invert = sideIdx != 0

      local avaliableUnits = []
      local aiUnits = []
      foreach (unit in team.unitsRemain)
        if (unit.isControlledByAI())
          aiUnits.append(unit)
        else
          avaliableUnits.append(unit)

      teams.append({
        invert = invert
        teamName = team.name
        armies = armies
        teamSizeText = getTeamSizeText(team)
        haveUnitsList = avaliableUnits.len()
        unitsList = unitsList(avaliableUnits, invert && isInBattlePanel, isInBattlePanel)
        haveAIUnitsList = aiUnits.len()
        aiUnitsList = unitsList(aiUnits, invert && isInBattlePanel, isInBattlePanel)
      })
    }

    foreach (team in teams)
      team.armies.maxSideArmiesNumber = maxSideArmiesNumber

    return teams
  }

  function getTeamSizeText(team)
  {
    local minPlayers = ::getTblValue("minPlayers", team)
    local maxPlayers = ::getTblValue("maxPlayers", team)
    if (!minPlayers || !maxPlayers)
      return ::loc("worldWar/unavailable_for_team")

    local curPlayers = ::getTblValue("players", team)
    return battle.isConfirmed() ?
      ::loc("worldwar/battle/playersCurMax", { cur = curPlayers, max = maxPlayers }) :
      ::loc("worldwar/battle/playersMinMax", { min = minPlayers, max = maxPlayers })
  }

  function unitsList(wwUnits, isReflected, hasLineSpacing)
  {
    wwUnits.sort(::g_world_war.sortUnitsBySortCodeAndCount)
    wwUnits = ::u.map( wwUnits, function(wwUnit) { return wwUnit.getShortStringView(true, false) })

    local view = {
      columns = [{unitString = wwUnits}]
      multipleColumns = false
      reflect = isReflected
      isShowTotalCount = true
      hasSpaceBetweenUnits = hasLineSpacing
    }
    return ::handyman.renderCached("gui/worldWar/worldWarMapArmyInfoUnitsList", view)
  }

  function isStarted()
  {
    return battle.isStarted()
  }

  function hasBattleDurationTime()
  {
    return battle.getBattleDurationTime() > 0
  }

  function getBattleDurationTime()
  {
    local durationTime = battle.getBattleDurationTime()
    if (durationTime > 0)
      return ::hoursToString(::seconds_to_hours(durationTime), false, true)

    return ""
  }

  function getBattleStatusTextLocId()
  {
    if (!battle.isStillInOperation())
      return "worldwar/battle_finished"

    if (battle.isWaiting() ||
        battle.status == ::EBS_ACTIVE_STARTING)
      return "worldwar/battleNotActive"

    if (battle.status == ::EBS_ACTIVE_MATCHING)
      return "worldwar/battleIsStarting"

    if (battle.isAutoBattle())
      return "worldwar/battleIsInAutoMode"

    if (battle.isConfirmed())
    {
      if (battle.isPlayerTeamFull())
        return "worldwar/battleIsFull"
      else
        return "worldwar/battleIsActive"
    }

    return "worldwar/battle_finished"
  }

  function getBattleStatusText()
  {
    return battle.isValid() ? ::loc(getBattleStatusTextLocId()) : ""
  }

  function getBattleStatusDescText()
  {
    return battle.isValid() ? ::loc(getBattleStatusTextLocId() + "/desc") : ""
  }

  function getCanJoinText()
  {
    local currentBattleQueue = ::queues.findQueueByName(battle.getQueueId(), true)
    local canJoinLocKey = ""
    if (currentBattleQueue != null)
      canJoinLocKey = "worldWar/canJoinStatus/in_queue"
    else if (battle.isStarted())
      canJoinLocKey = battle.isPlayerTeamFull() ?
        "worldWar/canJoinStatus/no_free_places" :
        "worldWar/canJoinStatus/can_join"

    return ::u.isEmpty(canJoinLocKey) ? "" : ::loc(canJoinLocKey)
  }

  function getBattleStatusWithTimeText()
  {
    local text = getBattleStatusText()
    local durationText = getBattleDurationTime()
    if (!::u.isEmpty(durationText))
      text += ::loc("ui/colon") + durationText

    return text
  }

  function getBattleStatusWithCanJoinText()
  {
    if (!battle.isValid())
      return ""

    local text = getBattleStatusText()
    local canJoinText = getCanJoinText()
    if (!::u.isEmpty(canJoinText))
      text += ::loc("ui/dot") + " " + canJoinText

    return text
  }

  function getStatus()
  {
    if (!battle.isStillInOperation())
      return "Finished"
    if (battle.status == ::EBS_ACTIVE_STARTING || battle.status == ::EBS_ACTIVE_MATCHING)
      return "Active"
    if (battle.status == ::EBS_ACTIVE_AUTO || battle.status == ::EBS_ACTIVE_FAKE)
      return "Fake"
    if (battle.status == ::EBS_ACTIVE_CONFIRMED)
      return battle.isPlayerTeamFull() ? "Full" : "OnServer"

    return "Inactive"
  }

  function getIconImage()
  {
    return getStatus() == "Full" ?
      "#ui/gameuiskin#battles_closed" : "#ui/gameuiskin#battles_open"
  }

  function getIconColor()
  {
    local status = getStatus()
    if (status == "OnServer")
      return "@battleColorOnServer"
    if (status == "Active")
      return "@battleColorActive"

    return "@battleColorInactive"
  }

  function getTooltip()
  {
    if (battle.isStillInOperation())
    {
      local status = getStatus()
      if (status == "Active" || status == "Full")
        return ::loc("worldwar/battle_open_info")
    }
    else
      return ::loc("worldwar/battle_open_info")

    return getBattleStatusText()
  }

  function getReplayBtnTooltip()
  {
    return ::loc("mainmenu/btnViewReplayTooltip", {sessionID = battle.getSessionId()})
  }

  function isAutoBattle()
  {
    return battle.isAutoBattle()
  }
}
