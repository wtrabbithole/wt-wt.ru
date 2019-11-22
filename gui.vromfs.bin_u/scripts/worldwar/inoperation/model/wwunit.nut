class ::WwUnit
{
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
    return wwUnitType.getUnitName(name)
  }

  function getFullName()
  {
    return ::format("%d %s", count, getName())
  }

  function getWwUnitType()
  {
    return wwUnitType
  }

  getShortStringView = ::kwarg(function getShortStringViewImpl(
    addIcon = true, addPreset = true, hideZeroCount = true, needShopInfo = false, hasIndent = false)
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
      hasIndent = hasIndent
      country = unit?.shopCountry ?? ""
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
  })

  function isInfantry()
  {
    return ::g_ww_unit_type.isInfantry(wwUnitType.code)
  }

  function isArtillery()
  {
    return ::g_ww_unit_type.isArtillery(wwUnitType.code)
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
    return wwUnitType.getUnitClassIcon(unit)
  }

  function getUnitRole()
  {
    local unitRole = wwUnitType.getUnitRole(unit)
    if (unitRole == "")
    {
      ::dagor.debug("WWar: Army Class: Not found role for unit " + name + ". Set unknown")
      unitRole = "unknown"
    }

    return unitRole
  }
}
