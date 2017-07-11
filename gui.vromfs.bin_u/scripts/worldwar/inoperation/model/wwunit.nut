class ::WwUnit
{
  static fakeInfantryUnitName = "fake_infantry"

  name  = ""
  unit = null
  count = -1
  inactiveCount = 0
  weaponPreset = ""
  weaponCount = 0

  wwUnitType = null
  role = ""
  expClass = ""
  stengthGroupExpClass = ""
  isForceControlledByAI = false

  constructor(blk)
  {
    if (!blk)
      return

    name = blk.getBlockName() || ::getTblValue("name", blk, "")
    unit = ::getAircraftByName(name)

    role = ::g_world_war.getUnitRole(name)
    wwUnitType = ::g_ww_unit_type.getUnitTypeByWwUnit(this)
    expClass = wwUnitType.expClass || (unit? unit.expClass.name : "")
    stengthGroupExpClass = ::getTblValue(expClass, ::strength_unit_expclass_group, expClass)

    inactiveCount = ::getTblValue("inactiveCount", blk, 0)
    count = ::getTblValue("count", blk, -1)
    weaponPreset = ::getTblValue("weaponPreset", blk, "")
    weaponCount = ::getTblValue("weaponCount", blk, 0)
  }

  function isValid()
  {
    return name.len() >  0 &&
           count      >= 0
  }

  function getId()
  {
    return name
  }

  function getCount()
  {
    return count
  }

  function setCount(val)
  {
    count = val
  }

  function setForceControlledByAI(val)
  {
    isForceControlledByAI = val
  }

  function getActiveCount()
  {
    return count - inactiveCount
  }

  function getName()
  {
    if (::g_ww_unit_type.isInfantry(wwUnitType.code))
      return ::loc("mainmenu/type_infantry")
    if (::g_ww_unit_type.isArtillery(wwUnitType.code))
      return ::loc("mainmenu/type_artillery")
    return ::getUnitName(name)
  }

  function getFullName()
  {
    return ::format("%d %s", count, getName())
  }

  function getItemMarkUp(canUse = false)
  {
    return ::build_aircraft_item(name, unit {
      status = canUse ? "owned" : "locked"
      inactive = true
      isLocalState = false
      tooltipParams = { showLocalState = false }
    })
  }

  function getWwUnitType()
  {
    return wwUnitType
  }

  function getShortStringView(addIcon = true, addPreset = true, addCount = true, hideZeroCount = true)
  {
    local presetData = ::getWeaponTypeIcoByWeapon(name, addPreset ? weaponPreset : "")
    local presetText = !addPreset || weaponPreset == "" ? "" :
      ::getWeaponInfoText(unit, false, weaponPreset, " ", INFO_DETAIL.SHORT, true)

    local activeCount = getActiveCount()
    local totalCount = getCount()
    local res = {
      isShow = count > 0 || !hideZeroCount
      unitType = getUnitTypeText()
      wwUnitType = wwUnitType
      name = getName()
      activeCount = activeCount ? activeCount.tostring() : null
      count = totalCount ? totalCount.tostring() : null
      isControlledByAI = isControlledByAI()
      weapon = presetText.len() > 0 ? ::colorize("@activeTextColor", presetText) : ""
      hasBomb = presetData.bomb.len() > 0
      hasRocket = presetData.rocket.len() > 0
      hasTorpedo = presetData.torpedo.len() > 0
      hasAdditionalGuns = presetData.additionalGuns.len() > 0
      hasPresetWeapon = (presetText.len() > 0) && (weaponCount > 0)
      presetCount = addPreset && weaponCount < count ? weaponCount : null
      tooltipId = ::g_tooltip.getIdUnit(name, { showLocalState = false })
    }

    if (addIcon)
    {
      res.icon <- getWwUnitClassIco()
      res.shopItemType <- getUnitRole()
    }
    return res
  }

  function isInfantry()
  {
    if (!::g_world_war.infantryUnits)
      ::g_world_war.updateInfantryUnits()

    return name == fakeInfantryUnitName || name in ::g_world_war.infantryUnits
  }

  function isArtillery()
  {
    if (!::g_world_war.artilleryUnits)
      ::g_world_war.updateArtilleryUnits()

    return name in ::g_world_war.artilleryUnits
  }

  function isAir()
  {
    return ::g_ww_unit_type.isAir(wwUnitType.code)
  }

  function isControlledByAI()
  {
    return isForceControlledByAI || !wwUnitType.canBeControlledByPlayer
  }

  function getUnitClass()
  {
    if (!isAir())
      return WW_UNIT_CLASS.UNKNOWN

    if (expClass == "fighter")
      return WW_UNIT_CLASS.FIGHTER

    return WW_UNIT_CLASS.BOMBER
  }

  static function getUnitClassText(unitClass)
  {
    if (unitClass == WW_UNIT_CLASS.FIGHTER)
      return "fighter"

    if (unitClass == WW_UNIT_CLASS.BOMBER)
      return "bomber"

    return "unknown"
  }

  function getUnitTypeText()
  {
    return ::get_role_text(expClass)
  }

  function getUnitStrengthGroupTypeText()
  {
    return ::get_role_text(stengthGroupExpClass)
  }

  function getWwUnitClassIco()
  {
    if (::g_ww_unit_type.isInfantry(wwUnitType.code))
      return "#ui/gameuiskin#icon_infantry"
    else if (::g_ww_unit_type.isArtillery(wwUnitType.code))
      return "#ui/gameuiskin#icon_artillery"

    return ::getUnitClassIco(unit)
  }

  function getUnitRole()
  {
    local unitRole = ::get_unit_role(unit)
    if (unitRole == "")
    {
      if (::g_ww_unit_type.isInfantry(wwUnitType.code))
        unitRole = "infantry"
      else if (::g_ww_unit_type.isArtillery(wwUnitType.code))
        unitRole = "artillery"
      else
      {
        ::dagor.debug("WWar: Army Class: Not found role for unit " + name + ". Set unknown")
        unitRole = "unknown"
      }
    }

    return unitRole
  }

  function getMaxFlyTime()
  {
    if (!::g_ww_unit_type.isAir(wwUnitType.code))
      return 0

    local maxFlyTime = ::getTblValue("maxFlightTimeMinutes", unit) ||
      ::g_world_war.getWWConfigurableValue("defaultMaxFlightTimeMinutes", 0)
    return (maxFlyTime * 60 / ::ww_get_speedup_factor()).tointeger()
  }

  static function loadUnitsFromBlk(blk, aiUnitsBlk = null)
  {
    if (!blk)
      return []

    local units = []
    for (local i = 0; i < blk.blockCount(); i++)
    {
      local unitBlk = blk.getBlock(i)
      local unit    = ::WwUnit(unitBlk)

      if (unit.isValid())
        units.push(unit)

      if (aiUnitsBlk)
      {
        local aiUnitData = ::getTblValue(unitBlk.getBlockName(), aiUnitsBlk)
        if (aiUnitData)
        {
          local aiUnit = ::WwUnit(unitBlk)
          aiUnit.setCount(getTblValue("count", aiUnitData, -1))
          aiUnit.setForceControlledByAI(true)
          units.push(aiUnit)
        }
      }
    }
    return units
  }

  static _loadingBlk = ::DataBlock()
  static function loadUnitsFromNameCountTbl(tbl)
  {
    if (::u.isEmpty(tbl))
      return []

    local units = []
    ::WwUnit._loadingBlk.reset()
    foreach(name, count in tbl)
    {
      ::WwUnit._loadingBlk["name"] = name
      ::WwUnit._loadingBlk["count"] = count

      local unit = ::WwUnit(::WwUnit._loadingBlk)
      if (unit.isValid())
        units.push(unit)
    }

    return units
  }

  static function getFakeUnitsArray(blk)
  {
    if (!blk || !blk.fakeInfantry)
      return []

    local resArray = []
    ::WwUnit._loadingBlk.reset()
    ::WwUnit._loadingBlk.changeBlockName("fake_infantry")
    ::WwUnit._loadingBlk.count <- blk.fakeInfantry
    local fakeUnit = ::WwUnit(::WwUnit._loadingBlk)
    if (fakeUnit.isValid())
      resArray.append(fakeUnit)

    return resArray
  }

  static function unitsCount(units = [])
  {
    local unitsCount = 0
    foreach (wwUnit in units)
      unitsCount += wwUnit.count

    return unitsCount
  }
}
