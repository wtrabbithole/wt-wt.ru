local time = require("scripts/time.nut")


class ::WwArmy extends ::WwFormation
{
  suppliesEndMillisec = 0
  entrenchEndMillisec = 0
  stoppedAtMillisec = 0
  pathTracker = null
  savedArmyBlk = null
  armyIsDead = false
  deathReason = ""
  armyFlags = 0

  constructor(armyName, blk = null)
  {
    savedArmyBlk = blk
    units = []
    owner = ::WwArmyOwner()
    pathTracker = ::WwPathTracker()
    artilleryAmmo = ::WwArtilleryAmmo()
    update(armyName)
  }

  function update(armyName)
  {
    if (!armyName)
      return

    name = armyName
    owner = ::WwArmyOwner()

    local blk = savedArmyBlk ? savedArmyBlk : getBlk(name)
    owner.update(blk.getBlockByName("owner"))
    pathTracker.update(blk.getBlockByName("pathTracker"))

    local unitTypeTextCode = blk?.specs.unitType ?? ""
    unitType = ::g_ww_unit_type.getUnitTypeByTextCode(unitTypeTextCode).code
    morale = ::getTblValue("morale", blk, -1)
    armyIsDead = ::get_blk_value_by_path(blk, "specs/isDead", false)
    deathReason = ::get_blk_value_by_path(blk, "specs/deathReason", "")
    armyFlags = ::get_blk_value_by_path(blk, "specs/flags", 0)
    suppliesEndMillisec = ::getTblValue("suppliesEndMillisec", blk, 0)
    entrenchEndMillisec = ::getTblValue("entrenchEndMillisec", blk, 0)
    stoppedAtMillisec = ::getTblValue("stoppedAtMillisec", blk, 0)
    overrideIconId = ::getTblValue("iconOverride", blk, "")

    local armyArtilleryParams = ::g_ww_unit_type.isArtillery(unitType) ?
      ::g_world_war.getArtilleryUnitParamsByBlk(blk.getBlockByName("units")) : null
    artilleryAmmo.setArtilleryParams(armyArtilleryParams)
    artilleryAmmo.update(name, blk.getBlockByName("artilleryAmmo"))
  }

  static _loadingBlk = ::DataBlock()
  function getBlk(armyName)
  {
    _loadingBlk.reset()
    ::ww_get_army_info(armyName, _loadingBlk)
    return _loadingBlk
  }

  function isValid()
  {
    return name != "" && owner.isValid()
  }

  function clear()
  {
    base.clear()

    suppliesEndMillisec = 0
    entrenchEndMillisec = 0
    stoppedAtMillisec = 0
    pathTracker = null
    armyFlags = 0
  }

  function updateUnits()
  {
    if (isUnitsValid || name.len() <= 0)
      return

    isUnitsValid = true
    local blk = savedArmyBlk ? savedArmyBlk : getBlk(name)

    units.extend(::WwUnit.loadUnitsFromBlk(blk.getBlockByName("units")))
    units.extend(::WwUnit.getFakeUnitsArray(blk))
  }

  function getName()
  {
    return name
  }

  function getArmyFlags()
  {
    return armyFlags
  }

  function getUnitType()
  {
    return unitType
  }

  function getFullName()
  {
    local fullName = name

    local group = getArmyGroup()
    if (group)
      fullName += " " + group.getFullName()

    fullName += ::loc("ui/parentheses/space", {text = getDescription()})

    return fullName
  }

  function isDead()
  {
    return armyIsDead
  }

  function getMoral()
  {
    return (morale + 0.5).tointeger()
  }

  function getDescription()
  {
    local desc = []

    local recalMoral = getMoral()
    if (recalMoral >= 0)
      desc.push(::loc("worldwar/morale", {morale = recalMoral}))

    local suppliesEnd = getSuppliesFinishTime()
    if (suppliesEnd > 0)
    {
      local timeText = time.hoursToString(time.secondsToHours(suppliesEnd), true, true)
      local suppliesEndLoc = "worldwar/suppliesfinishedIn"
      if (::g_ww_unit_type.isAir(unitType))
        suppliesEndLoc = "worldwar/returnToAirfieldIn"
      desc.push( ::loc(suppliesEndLoc, { time = timeText }) )
    }

    local entrenchTime = secondsLeftToEntrench()
    if (entrenchTime == 0)
    {
      desc.push(::loc("worldwar/armyEntrenched"))
    }
    else if (entrenchTime > 0)
    {
      desc.push(::loc("worldwar/armyEntrenching",
          {time = time.hoursToString(time.secondsToHours(entrenchTime), true, true)}))
    }

    return ::g_string.implode(desc, "\n")
  }

  function getFullDescription()
  {
    local desc = getFullName()
    desc += "\n"
    desc += ::g_string.implode(getUnitsFullNamesList(), "\n")
    return desc
  }

  function getUnitsFullNamesList()
  {
    return ::u.map(getUnits(), function(unit) { return unit.getFullName() })
  }

  function getSuppliesFinishTime()
  {
    local finishTimeMillisec = 0
    if (suppliesEndMillisec > 0)
      finishTimeMillisec = suppliesEndMillisec - ::ww_get_operation_time_millisec()
    else if (isInBattle() && suppliesEndMillisec < 0)
      finishTimeMillisec = -suppliesEndMillisec

    return time.millisecondsToSeconds(finishTimeMillisec).tointeger()
  }

  function secondsLeftToEntrench()
  {
    if (entrenchEndMillisec <= 0)
      return -1

    local leftToEntrenchTime = entrenchEndMillisec - ::ww_get_operation_time_millisec()
    return time.millisecondsToSeconds(leftToEntrenchTime).tointeger()
  }

  function secondsLeftToFireEnable()
  {
    if (stoppedAtMillisec <= 0)
      return -1

    local coolDownMillisec = artilleryAmmo.getCooldownAfterMoveMillisec()
    local leftToFireEnableTime = stoppedAtMillisec + coolDownMillisec - ::ww_get_operation_time_millisec()
    return ::max(time.millisecondsToSeconds(leftToFireEnableTime).tointeger(), 0)
  }

  function needUpdateDescription()
  {
    return getSuppliesFinishTime() >= 0 ||
           secondsLeftToEntrench() >= 0 ||
           getNextAmmoRefillTime() >= 0 ||
           secondsLeftToFireEnable() >= 0 ||
           hasStrike()
  }

  function isEntrenched()
  {
    return entrenchEndMillisec > 0
  }

  function isMove()
  {
    return pathTracker.isMove()
  }

  function canFire()
  {
    if (!::g_ww_unit_type.isArtillery(unitType))
      return false

    if (isIdle() && secondsLeftToFireEnable() == -1)
      return false

    local hasCoolDown = secondsLeftToFireEnable() > 0
    return hasAmmo() && !isMove() && !hasStrike() && !hasCoolDown
  }

  function isIdle()
  {
    return !isEntrenched() && !isMove() && !isInBattle()
  }

  function isSurrounded()
  {
    return ::g_ww_unit_type.canBeSurrounded(unitType) && getSuppliesFinishTime() > 0
  }

  function isStatusEqual(army)
  {
    return getActionStatus() == army.getActionStatus() && isSurrounded() == army.isSurrounded()
  }

  function getActionStatus()
  {
    if (isMove())
      return WW_ARMY_ACTION_STATUS.IN_MOVE
    if (isInBattle())
      return WW_ARMY_ACTION_STATUS.IN_BATTLE
    if (isEntrenched())
      return WW_ARMY_ACTION_STATUS.ENTRENCHED
    return WW_ARMY_ACTION_STATUS.IDLE
  }

  function getTooltipId()
  {
    return ::g_tooltip_type.WW_MAP_TOOLTIP_TYPE_ARMY.getTooltipId(name, {armyName = name})
  }

  function getPosition()
  {
    if (!pathTracker)
      return null

    return pathTracker.getCurrentPos()
  }

  function isStrikePreparing()
  {
    return hasStrike() && artilleryAmmo.isStrikePreparing()
  }

  function isStrikeInProcess()
  {
    return hasStrike() && !artilleryAmmo.isStrikePreparing()
  }

  function isStrikeOnCooldown()
  {
    return secondsLeftToFireEnable() > 0
  }

  function isFormation()
  {
    return false
  }

  static function sortArmiesByUnitType(a, b)
  {
    return a.getUnitType() - b.getUnitType()
  }

  static function getCasualtiesCount(blk)
  {
    if (!::g_world_war.artilleryUnits)
      ::g_world_war.updateArtilleryUnits()

    local unitsCount = 0
    for (local i = 0; i < blk.casualties.paramCount(); i++)
      if (!::g_ww_unit_type.isArtillery(unitType) ||
          blk.casualties.getParamName(i) in ::g_world_war.artilleryUnits)
        unitsCount += blk.casualties.getParamValue(i)

    return unitsCount
  }
}
