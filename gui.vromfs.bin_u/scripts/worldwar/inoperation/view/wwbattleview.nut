local time = require("scripts/time.nut")


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

  static isControlHelpCentered = true
  static controlHelpDesc = @() hasControlTooltip()
    ? ::loc("worldwar/battle_open_info") : getBattleStatusText()
  static consoleButtonsIconName = @() ::show_console_buttons && hasControlTooltip()
    ? WW_MAP_CONSPLE_SHORTCUTS.LMB_IMITATION : null
  static controlHelpText = @() !::show_console_buttons && hasControlTooltip()
    ? ::loc("key/LMB") : null

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

  function getFullBattleName()
  {
    return getBattleName() + ::loc("ui/comma") + battle.getLocName()
  }

  function defineTeamBlock(playerSide, sides)
  {
    teamBlock = getTeamBlockByIconSize(playerSide, sides, WW_ARMY_GROUP_ICON_SIZE.BASE)
  }

  function getTeamDataBySide(playerSide, sides, iconSize = null)
  {
    iconSize = iconSize || WW_ARMY_GROUP_ICON_SIZE.BASE

    local currentTeamBlock = getTeamBlockByIconSize(playerSide, sides, iconSize, true)
    local teamName = "team" + battle.getTeamNameBySide(playerSide)

    foreach(team in currentTeamBlock)
      if (team.teamName == teamName)
        return team

    return null
  }

  function getTeamBlockByIconSize(playerSide, sides, iconSize, isInBattlePanel = false, param = null)
  {
    if (iconSize == WW_ARMY_GROUP_ICON_SIZE.MEDIUM)
    {
      if (largeArmyGroupIconTeamBlock == null)
        largeArmyGroupIconTeamBlock = getTeamsData(playerSide, sides, iconSize, isInBattlePanel, param)

      return largeArmyGroupIconTeamBlock
    }
    else if (iconSize == WW_ARMY_GROUP_ICON_SIZE.SMALL)
    {
      if (mediumArmyGroupIconTeamBlock == null)
        mediumArmyGroupIconTeamBlock = getTeamsData(playerSide, sides, iconSize, isInBattlePanel, param)

      return mediumArmyGroupIconTeamBlock
    }
    else
    {
      if (teamBlock == null)
        teamBlock = getTeamsData(playerSide, sides, WW_ARMY_GROUP_ICON_SIZE.BASE, isInBattlePanel, param)

      return teamBlock
    }
  }

  function getTeamsData(playerSide, sides, iconSize, isInBattlePanel, param)
  {
    local teams = []
    local maxSideArmiesNumber = 0
    local isVersusTextAdded = false
    local hasArmyInfo = ::getTblValue("hasArmyInfo", param, true)
    local hasVersusText = ::getTblValue("hasVersusText", param)
    local canAlignRight = ::getTblValue("canAlignRight", param, true)
    foreach(sideIdx, side in sides)
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
        {
          local armyView = army.getView()
          armyView.setSelectedSide(playerSide)
          armyViews.append(armyView)
        }
      }

      if (armyViews.len())
      {
        if (hasVersusText && !isVersusTextAdded)
        {
          armyViews.top().setHasVersusText(true)
          isVersusTextAdded = true
        }
        else
          armyViews.top().setHasVersusText(false)
      }

      maxSideArmiesNumber = ::max(maxSideArmiesNumber, armyViews.len())

      local view = {
        army = armyViews
        delimetrRightPadding = hasArmyInfo ? "8*@sf/@pf_outdated" : 0
        reqUnitTypeIcon = true
        hideArrivalTime = true
        showArmyGroupText = false
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
    if (battle.isAutoBattle())
      return ::loc("worldWar/unavailable_for_team")

    local maxPlayers = ::getTblValue("maxPlayers", team)
    if (!maxPlayers)
      return ::loc("worldWar/unavailable_for_team")

    local minPlayers = ::getTblValue("minPlayers", team)
    local curPlayers = ::getTblValue("players", team)
    return battle.isConfirmed() && battle.getMyAssignCountry() ?
      ::loc("worldwar/battle/playersCurMax", { cur = curPlayers, max = maxPlayers }) :
      ::loc("worldwar/battle/playersMinMax", { min = minPlayers, max = maxPlayers })
  }

  function unitsList(wwUnits, isReflected, hasLineSpacing)
  {
    wwUnits.sort(::g_world_war.sortUnitsBySortCodeAndCount)
    wwUnits = ::u.map( wwUnits, @(wwUnit)
      wwUnit.getShortStringView(true, true, true, true, true) )

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

  function hasBattleActivateLeftTime()
  {
    return battle.getBattleActivateLeftTime() > 0
  }

  function getBattleDurationTime()
  {
    local durationTime = battle.getBattleDurationTime()
    if (durationTime > 0)
      return time.hoursToString(time.secondsToHours(durationTime), false, true)

    return ""
  }

  function getBattleActivateLeftTime()
  {
    local durationTime = battle.getBattleActivateLeftTime()
    if (durationTime > 0)
      return time.hoursToString(time.secondsToHours(durationTime), false, true)

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

  function getCanJoinText(side)
  {
    if (side == ::SIDE_NONE)
      return ""

    local currentBattleQueue = ::queues.findQueueByName(battle.getQueueId(), true)
    local canJoinLocKey = ""
    if (currentBattleQueue != null)
      canJoinLocKey = "worldWar/canJoinStatus/in_queue"
    else if (battle.isStarted())
    {
      local cantJoinReasonData = battle.getCantJoinReasonData(side, false)
      if (cantJoinReasonData.canJoin)
        canJoinLocKey = battle.isPlayerTeamFull() ? "worldWar/canJoinStatus/no_free_places"
          : "worldWar/canJoinStatus/can_join"
    }

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

  function getBattleStatusWithCanJoinText(side)
  {
    if (!battle.isValid())
      return ""

    local text = getBattleStatusText()
    local canJoinText = getCanJoinText(side)
    if (!::u.isEmpty(canJoinText))
      text += ::loc("ui/dot") + " " + canJoinText

    return text
  }

  function getStatus()
  {
    if (!battle.isStillInOperation() || battle.status == ::EBS_FINISHED_APPLIED)
      return "Finished"
    if (battle.status == ::EBS_ACTIVE_STARTING || battle.status == ::EBS_ACTIVE_MATCHING)
      return "Active"
    if (battle.status == ::EBS_ACTIVE_AUTO || battle.status == ::EBS_ACTIVE_FAKE)
      return "Fake"
    if (battle.status == ::EBS_ACTIVE_CONFIRMED)
      return battle.isPlayerTeamFull() || !battle.hasAvailableUnits() ? "Full" : "OnServer"

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

  function hasControlTooltip()
  {
    if (battle.isStillInOperation())
    {
      local status = getStatus()
      if (status == "Active" || status == "Full")
        return true
    }
    else
      return true

    return false
  }

  function getReplayBtnTooltip()
  {
    return ::loc("mainmenu/btnViewReplayTooltip", {sessionID = battle.getSessionId()})
  }

  function isAutoBattle()
  {
    return battle.isAutoBattle()
  }

  function hasTeamsInfo()
  {
    return battle.isValid() && battle.isConfirmed()
  }

  function getTotalPlayersInfoText()
  {
    return ::loc("worldwar/totalPlayers") + ::loc("ui/colon") +
      ::colorize("newTextColor", battle.getTotalPlayersNumber())
  }
}
