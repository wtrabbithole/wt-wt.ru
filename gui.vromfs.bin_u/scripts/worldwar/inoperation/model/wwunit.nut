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
    count = ::getTblValue("count", blk, -1) - inactiveCount
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
      isPriceForcedHidden = true
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

    local res = {
      isShow = count > 0 || !hideZeroCount
      unitType = getUnitTypeText()
      wwUnitType = wwUnitType
      name = getName()
      count = addCount ? count.tostring() : null
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

  static function loadUnitsFromBlk(blk)
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
