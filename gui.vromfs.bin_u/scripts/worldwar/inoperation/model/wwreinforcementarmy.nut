local time = require("scripts/time.nut")


class ::WwReinforcementArmy extends ::WwFormation
{
  suppliesEndMillisec = 0
  entrenchEndMillisec = 0
  availableAtMillisec = 0

  constructor(reinforcementBlock)
  {
    units = []
    artilleryAmmo = ::WwArtilleryAmmo()
    update(reinforcementBlock)
  }

  function update(reinforcementBlock)
  {
    if (!reinforcementBlock)
      return

    local armyBlock = reinforcementBlock.army
    name = armyBlock.name
    owner = ::WwArmyOwner(armyBlock.getBlockByName("owner"))

    morale = armyBlock?.morale ?? -1
    availableAtMillisec = reinforcementBlock?.availableAtMillisec ?? 0
    suppliesEndMillisec = armyBlock?.suppliesEndMillisec ?? 0
    entrenchEndMillisec = armyBlock?.entrenchEndMillisec ?? 0

    unitType = ::g_ww_unit_type.getUnitTypeByTextCode(armyBlock?.specs?.unitType).code
    overrideIconId = armyBlock?.iconOverride ?? ""
    units = ::WwUnit.loadUnitsFromBlk(armyBlock.getBlockByName("units"))

    local armyArtilleryParams = ::g_ww_unit_type.isArtillery(unitType) ?
      ::g_world_war.getArtilleryUnitParamsByBlk(armyBlock.getBlockByName("units")) : null
    artilleryAmmo.setArtilleryParams(armyArtilleryParams)
    artilleryAmmo.update(name, armyBlock.getBlockByName("artilleryAmmo"))
  }

  function clear()
  {
    base.clear()

    suppliesEndMillisec = 0
    entrenchEndMillisec = 0
    availableAtMillisec = 0
  }

  function getName()
  {
    return name
  }

  function getFullName()
  {
    local fullName = getName()
    fullName += ::loc("ui/parentheses/space", {text = getDescription()})

    return fullName
  }

  function getDescription()
  {
    local desc = []

    if (morale >= 0)
      desc.push(::loc("worldwar/morale", {morale = (morale + 0.5).tointeger()}))

    if (suppliesEndMillisec > 0)
    {
      local elapsed = ::max(0, (suppliesEndMillisec - ::ww_get_operation_time_millisec()) * 0.001)

      desc.push(::loc("worldwar/suppliesfinishedIn",
          {time = time.hoursToString(time.secondsToHours(elapsed), true, true)}))
    }

    local elapsed = secondsLeftToEntrench();
    if (elapsed == 0)
    {
      desc.push(::loc("worldwar/armyEntrenched"))
    }
    else if (elapsed > 0)
    {
      desc.push(::loc("worldwar/armyEntrenching",
          {time = time.hoursToString(time.secondsToHours(elapsed), true, true)}))
    }

    return ::g_string.implode(desc, "\n")
  }

  function getArrivalTime()
  {
    return ::max(0, (availableAtMillisec - ::ww_get_operation_time_millisec()))
  }

  function isReady()
  {
    return getArrivalTime() == 0
  }

  function getArrivalStatusText()
  {
    local arrivalTime = getArrivalTime()
    if (arrivalTime == 0)
      return ::loc("worldwar/state/reinforcement_ready")

    return time.secondsToString(time.millisecondsToSeconds(arrivalTime), false)
  }

  function getFullDescription()
  {
    local desc = getFullName()
    desc += "\n"
    desc += ::g_string.implode(getUnitsMapFullName(), "\n")
    return desc
  }

  function getUnitsMapFullName()
  {
    return ::u.map(getUnits(), function(unit) { return unit.getFullName() })
  }

  function secondsLeftToEntrench()
  {
    if (entrenchEndMillisec <= 0)
      return -1

    return ::max(0, (entrenchEndMillisec - ::ww_get_operation_time_millisec()) * 0.001)
  }

  function getUnitsViewsArray()
  {
    local res = []
    foreach (unit in units)
      res.append(unit.getShortStringView())

    return res
  }

  static function sortReadyReinforcements(a, b)
  {
    if (a.getArmyGroupIdx() != b.getArmyGroupIdx())
      return a.getArmyGroupIdx() < b.getArmyGroupIdx() ? -1 : 1

    if (a.getUnitType() != b.getUnitType())
      return a.getUnitType() < b.getUnitType() ? -1 : 1
    return 0
  }

  static function sortNewReinforcements(a, b)
  {
    if (a.getArmyGroupIdx() != b.getArmyGroupIdx())
      return a.getArmyGroupIdx() < b.getArmyGroupIdx() ? -1 : 1

    if (a.getArrivalTime() != b.getArrivalTime())
      return a.getArrivalTime() < b.getArrivalTime() ? -1 : 1

    if (a.getUnitType() != b.getUnitType())
      return a.getUnitType() < b.getUnitType() ? -1 : 1

    return 0
  }

  function isFormation()
  {
    return false
  }
}
