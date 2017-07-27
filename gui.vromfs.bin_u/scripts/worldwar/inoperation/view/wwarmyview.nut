class ::WwArmyView
{
  redrawData = null
  formation = null
  customId = null
  name = ""

  static unitsInArmyRowsMax = 5

  constructor(_formation)
  {
    formation = _formation
    name = formation.name
    setRedrawArmyStatusData()
  }

  function getName()
  {
    return name
  }

  function setId(id)
  {
    customId = id
  }

  function getId()
  {
    if (customId)
      return customId

    return "commander_block_" + formation.getArmyCountry() + "_" + formation.getArmySide() + "_" + formation.getArmyGroupIdx() + "_" + formation.name
  }

  function getUnitTypeText()
  {
    return ::g_ww_unit_type.getUnitTypeFontIcon(formation.getUnitType())
  }

  function getUnitTypeCustomText()
  {
    local overrideIcon = "getOverrideIcon" in formation ? formation.getOverrideIcon() : null
    return overrideIcon || getUnitTypeText()
  }

  function getDescription()
  {
    return formation.getDescription()
  }

  function unitsList()
  {
    local view = { columns = [], multipleColumns = false, hasSpaceBetweenUnits = true}
    local wwUnits = ::u.reduce(formation.getUnits(), function (unit, memo) {
      if (unit.getActiveCount())
        memo.append(unit)
      return memo
    }, [])
    wwUnits = ::u.map( wwUnits, function(wwUnit) { return wwUnit.getShortStringView() })
    wwUnits.sort(::g_world_war.sortUnitsBySortCodeAndCount)

    if (wwUnits.len() <= unitsInArmyRowsMax)
      view.columns.append({ unitString = wwUnits })
    else
    {
      view.columns.append({ unitString = wwUnits.slice(0, unitsInArmyRowsMax), first = true })
      view.columns.append({ unitString = wwUnits.slice(unitsInArmyRowsMax) })
    }

    view.multipleColumns = view.columns.len() > 1
    return ::handyman.renderCached("gui/worldWar/worldWarMapArmyInfoUnitsList", view)
  }

  /** exclude infantry */
  function unitsCount(excludeInfantry = true, onlyArtillery = false)
  {
    local unitsCount = 0
    foreach (unit in formation.getUnits(excludeInfantry))
      unitsCount += (!onlyArtillery || unit.isArtillery()) ? unit.getActiveCount() : 0

    return unitsCount
  }

  function inactiveUnitsCount(excludeInfantry = true, onlyArtillery = false)
  {
    local unitsCount = 0
    foreach (unit in formation.getUnits(excludeInfantry))
      unitsCount += (!onlyArtillery || unit.isArtillery()) ? unit.inactiveCount : 0

    return unitsCount
  }

  function isDead()
  {
    return "isDead" in formation ? formation.isDead() : false
  }

  function isInfantry()
  {
    return ::g_ww_unit_type.isInfantry(formation.getUnitType())
  }

  function isArtillery()
  {
    return ::g_ww_unit_type.isArtillery(formation.getUnitType())
  }

  function getUnitsCountText()
  {
    return unitsCount(true, isArtillery())
  }

  function getInactiveUnitsCountText()
  {
    return inactiveUnitsCount(true, isArtillery())
  }

  function hasManageAccess()
  {
    return formation.hasManageAccess()
  }

  function getArmyGroupIdx()
  {
    return formation.getArmyGroupIdx()
  }

  function clanId()
  {
    return formation.getClanId()
  }

  function clanTag()
  {
    return formation.getClanTag()
  }

  function getTextAfterIcon()
  {
    return clanTag()
  }

  function showArmyGroupText()
  {
    return formation.showArmyGroupText()
  }

  function isBelongsToMyClan()
  {
    return formation.isBelongsToMyClan()
  }

  function getTeamColor()
  {
    return formation.isMySide(::ww_get_player_side())? "blue" : "red"
  }

  function getReinforcementArrivalTime()
  {
    return "getArrivalStatusText" in formation? formation.getArrivalStatusText() : null
  }

  function getMoral()
  {
    return "getMoral" in formation ? formation.getMoral() : ""
  }

  function getSuppliesFinishTime()
  {
    local time = "getSuppliesFinishTime" in formation? formation.getSuppliesFinishTime() : 0
    if (time > 0)
      return ::hoursToString(::seconds_to_hours(time), false, true) + " " + ::loc("icon/timer")

    return null
  }

  function getAirFuelLastTime()
  {
    if (::g_ww_unit_type.isAir(formation.getUnitType()))
      return getSuppliesFinishTime()
    return ""
  }

  function getAmmoRefillTime()
  {
    local time = formation.getNextAmmoRefillTime()
    if (time > 0)
      return ::hoursToString(::seconds_to_hours(time), false, true) + " " +
        ::loc("weapon/torpedoIcon")
    return ""
  }

  function getGroundSurroundingTime()
  {
    if (::g_ww_unit_type.canBeSurrounded(formation.getUnitType()))
      return getSuppliesFinishTime()
    return null
  }

  function getActionStatusTime()
  {
    if ("secondsLeftToEntrench" in formation)
    {
      local entrenchTime = formation.secondsLeftToEntrench()
      if (entrenchTime >= 0)
        return ::hoursToString(::seconds_to_hours(entrenchTime), false, true)
    }

    return ""
  }

  function getActionStatusIcon()
  {
    local statusText = ""
    if (::g_ww_unit_type.isArtillery(formation.getUnitType()) && formation.hasStrike())
      statusText += ::loc("worldWar/iconStrike")
    if (formation.isInBattle())
      statusText += ::loc("worldWar/iconBattle")
    if (formation.isEntrenched())
      statusText += ::loc("worldWar/iconEntrenched")
    if (formation.isMove())
      statusText = ::loc("worldWar/iconMove")
    return statusText.len() ? statusText : ::loc("worldWar/iconIdle")
  }

  function getActionStatusIconTooltip()
  {
    local tooltipText = ""
    if (::g_ww_unit_type.isArtillery(formation.getUnitType()) && formation.hasStrike())
      tooltipText += "\n" + ::loc("worldWar/iconStrike") + " " + ::loc("worldwar/tooltip/army_deals_strike")
    if (formation.isInBattle())
      tooltipText += "\n" + ::loc("worldWar/iconBattle") + " " + ::loc("worldwar/tooltip/army_in_battle")
    if (formation.isEntrenched())
      tooltipText += "\n" + ::loc("worldWar/iconEntrenched") + " " + ::loc("worldwar/tooltip/army_is_entrenched")
    if (formation.isMove())
      tooltipText += "\n" + ::loc("worldWar/iconMove") + " " + ::loc("worldwar/tooltip/army_is_moving")
    if (!tooltipText.len())
      tooltipText += "\n" + ::loc("worldWar/iconIdle") + " " + ::loc("worldwar/tooltip/army_is_waiting")

    return ::loc("worldwar/tooltip/army_status") + ::loc("ui/colon") + tooltipText
  }

  function getMoraleIconTooltip()
  {
    return ::loc("worldwar/tooltip/army_morale") + ::loc("ui/colon") + getMoral()
  }

  function getAmmoTooltip()
  {
    return ::loc("worldwar/tooltip/ammo_amount")
  }

  function getUnitsIconTooltip()
  {
    return ::loc("worldwar/tooltip/vehicle_amount") + ::loc("ui/colon") + getUnitsCountText()
  }

  function getArmyReturnTimeTooltip()
  {
    return ::loc("worldwar/tooltip/army_return_time")
  }

  function getAmmoRefillTimeTooltip()
  {
    return ::loc("worldwar/tooltip/ammo_refill_time")
  }

  function getCountryIcon(big = false)
  {
    return ::get_country_icon(formation.getArmyCountry(), big)
  }

  function getClanId()
  {
    return formation.getClanId()
  }

  function getClanTag()
  {
    return formation.getClanTag()
  }

  function getTooltipId()
  {
    return ("getTooltipId" in formation) ? formation.getTooltipId() : null
  }

  function isEntrenched()
  {
    return ("isEntrenched" in formation) ? formation.isEntrenched() :false
  }

  function getFormationID()
  {
    return formation.getFormationID()
  }

  function isFormation()
  {
    return "isFormation" in formation ? formation.isFormation() : false
  }

  function getTooltipId()
  {
    return ::g_tooltip_type.WW_MAP_TOOLTIP_TYPE_GROUP.getTooltipId(getClanId(), {})
  }

  function getArmyAlertText()
  {
    if (isDead())
      return ::loc("debriefing/ww_army_state_dead")

    local groundSurroundingTime = getGroundSurroundingTime()
    if (groundSurroundingTime)
      return ::loc("worldwar/groundsurrended") + ::loc("ui/colon") + groundSurroundingTime

    local inactiveUnitsCountText = getInactiveUnitsCountText()
    if (inactiveUnitsCountText)
      return ::loc("worldwar/active_units", {
        active = unitsCount(true, isArtillery()),
        inactive = inactiveUnitsCountText
      })

    return null
  }

  function getArmyInfoText()
  {
    if (!isArtillery())
      return null

    local cant_tire_text = ::loc("worldwar/artillery/cant_fire")

    if (formation.isMove())
      return ::loc("worldwar/artillery/is_move")

    if (!formation.hasAmmo())
      return ::loc("worldwar/artillery/no_ammo")

    if (formation.isStrikePreparing())
    {
      local timeToPrepareStike = formation.artilleryAmmo.getTimeToNextStrike()
      return ::loc("worldwar/artillery/aiming") + ::loc("ui/colon") +
             ::hoursToString(::seconds_to_hours(timeToPrepareStike), false, true)
    }

    if (formation.isStrikeInProcess())
    {
      local timeToFinishStike = formation.artilleryAmmo.getTimeToCompleteStrikes()
      return ::loc("worldwar/artillery/firing") + ::loc("ui/colon") +
             ::hoursToString(::seconds_to_hours(timeToFinishStike), false, true)
    }

    if (formation.isStrikeOnCooldown())
      return ::loc("worldwar/artillery/preparation") + ::loc("ui/colon") +
             ::hoursToString(::seconds_to_hours(formation.secondsLeftToFireEnable()), false, true)

    return ::loc("worldwar/artillery/can_fire")
  }

  function isAlert()
  {
    if (isDead() || getGroundSurroundingTime())
      return "yes"

    return "no"
  }

  function getActionStatusTimeText()
  {
    return getActionStatusTime() + " " + getActionStatusIcon()
  }

  function getUnitsCountTextIcon()
  {
    return isInfantry() ? "" : getUnitsCountText() + " " + getUnitTypeText()
  }

  function getMoralText()
  {
    return getMoral() + " " + ::loc("worldWar/iconMoral")
  }

  function getAmmoText()
  {
    return formation.getAmmoCount() + "/" + formation.getMaxAmmoCount() + " " +
      ::loc("weapon/torpedoIcon")
  }

  function getVehiclesAmountText()
  {
    local text = getUnitsCountTextIcon()
    return ::u.isEmpty(text) ? "" : ::loc("ui/parentheses", { text = text })
  }

  function setRedrawArmyStatusData()
  {
    redrawData = {
      army_status_time = getActionStatusTimeText
      army_count = getUnitsCountTextIcon
      army_morale = getMoralText
      army_return_time = getAirFuelLastTime
      army_ammo = getAmmoText
      army_ammo_refill_time = getAmmoRefillTime
      army_alert_text = getArmyAlertText
      army_info_text = getArmyInfoText
    }
  }

  function getRedrawArmyStatusData()
  {
    return redrawData
  }

  function getMapObjectName()
  {
    return formation.getMapObjectName()
  }
}
