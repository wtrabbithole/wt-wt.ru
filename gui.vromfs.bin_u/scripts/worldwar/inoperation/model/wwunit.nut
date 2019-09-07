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

  function getShortStringView(addIcon = true, addPreset = true, addCount = true,
                              hideZeroCount = true, needShopInfo = false)
  {
    local presetData = ::getWeaponTypeIcoByWeapon(name, addPreset ? weaponPreset : "")
    local presetText = !addPreset || weaponPreset == "" ? "" :
      ::getWeaponInfoText(unit,
        { isPrimary = false, weaponPreset = weaponPreset, detail = INFO_DETAIL.SHORT, needTextWhenNoWeapons = false })

    local nameText = getName()
    if (needShopInfo && unit && !isControlledByAI() && !unit.canUseByPlayer())
    {
      local nameColor = ::isUnitSpecial(unit) ? "@hotkeyColor" : "@weaponWarning"
      nameText = ::colorize(nameColor, nameText)
    }

    local activeCount = getActiveCount()
    local totalCount = getCount()
    local res = {
      id = name
      isShow = count > 0 || !hideZeroCount
      unitType = getUnitTypeText()
      wwUnitType = wwUnitType
      name = nameText
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
      tooltipId = ::g_tooltip.getIdUnit(name, {
        showLocalState = needShopInfo
        needShopInfo = needShopInfo
      })
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
    return name == fakeInfantryUnitName || name in ::g_world_war.getInfantryUnits()
  }

  function isArtillery()
  {
    return name in ::g_world_war.getArtilleryUnits()
  }

  function isAir()
  {
    return ::g_ww_unit_type.isAir(wwUnitType.code)
  }

  function isControlledByAI()
  {
    return isForceControlledByAI || !wwUnitType.canBeControlledByPlayer
  }

  function getUnitClassData(weapPreset = null)
  {
    local res = {
      unitClass = WW_UNIT_CLASS.UNKNOWN
      flyOutUnitClass = WW_UNIT_CLASS.UNKNOWN
    }

    if (!isAir())
      return res

    if (expClass == "fighter")
    {
      res.unitClass = WW_UNIT_CLASS.FIGHTER
      res.flyOutUnitClass = WW_UNIT_CLASS.FIGHTER
      if (weapPreset)
      {
        local wpcostBlk = ::get_wpcost_blk()
        local weaponmask = wpcostBlk?[name]?.weapons?[weapPreset]?.weaponmask ?? 0
        local requiredWeaponmask = ::g_world_war.getWWConfigurableValue("fighterToAssaultWeaponMask", 0)
        local isFighter = !(weaponmask & requiredWeaponmask)
        res.unitClass = isFighter ? WW_UNIT_CLASS.FIGHTER : WW_UNIT_CLASS.ASSAULT
        res.flyOutUnitClass = isFighter ? WW_UNIT_CLASS.FIGHTER : WW_UNIT_CLASS.BOMBER
      }
    }
    else if (expClass == "bomber")
    {
      res.unitClass = WW_UNIT_CLASS.BOMBER
      res.flyOutUnitClass = WW_UNIT_CLASS.BOMBER
    }
    else
    {
      res.unitClass = WW_UNIT_CLASS.ASSAULT
      res.flyOutUnitClass = WW_UNIT_CLASS.BOMBER
    }

    return res
  }

  static function getUnitClassText(unitClass)
  {
    if (unitClass == WW_UNIT_CLASS.FIGHTER)
      return "fighter"

    if (unitClass == WW_UNIT_CLASS.BOMBER)
      return "bomber"

    if (unitClass == WW_UNIT_CLASS.ASSAULT)
      return "assault"

    return "unknown"
  }

  static function getUnitClassIconText(unitClass)
  {
    if (unitClass == WW_UNIT_CLASS.FIGHTER)
      return ::loc("worldWar/iconAirFighter")

    if (unitClass == WW_UNIT_CLASS.BOMBER)
      return ::loc("worldWar/iconAirBomber")

    if (unitClass == WW_UNIT_CLASS.ASSAULT)
      return ::loc("worldWar/iconAirAssault")

    return ""
  }

  function getUnitClassTooltipText(unitClass)
  {
    if (expClass == "fighter" )
      return unitClass == WW_UNIT_CLASS.FIGHTER
        ? ::loc("mainmenu/type_fighter")
        : ::loc("mainmenu/type_assault_fighter")

    if (unitClass == WW_UNIT_CLASS.BOMBER)
      return ::loc("mainmenu/type_bomber")

    if (unitClass == WW_UNIT_CLASS.ASSAULT)
      return ::loc("mainmenu/type_assault")

    return ""
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

    local maxFlyTime = (unit && unit.getUnitWpCostBlk()?.maxFlightTimeMinutes) ||
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
    foreach(_name, _count in tbl)
    {
      ::WwUnit._loadingBlk["name"] = _name
      ::WwUnit._loadingBlk["count"] = _count

      local unit = ::WwUnit(::WwUnit._loadingBlk)
      if (unit.isValid())
        units.push(unit)
    }

    return units
  }

  static function getFakeUnitsArray(blk)
  {
    if (!blk?.fakeInfantry)
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
    local res = 0
    foreach (wwUnit in units)
      res += wwUnit.count
    return res
  }
}
