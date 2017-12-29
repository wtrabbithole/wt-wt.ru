local guidParser = require("scripts/guidParser.nut")

class Decorator
{
  id = ""
  blk = null
  decoratorType = null
  unlockId = ""
  unlockBlk = null
  isUGC = false

  category = ""
  catIndex = 0

  limit = -1

  tex = ""
  aspect_ratio = 0

  countries = null
  units = null
  tags = null

  lockedByDLC = null

  cost = null
  forceShowInCustomization = null

  constructor(blkOrId, decType)
  {
    decoratorType = decType
    if (::u.isString(blkOrId))
      id = blkOrId
    else if (::u.isDataBlock(blkOrId))
    {
      blk = blkOrId
      id = blk.getBlockName()
    }

    unlockId = ::getTblValue("unlock", blk, "")
    unlockBlk = ::g_unlocks.getUnlockById(unlockId)
    limit = ::getTblValue("limit", blk, decoratorType.defaultLimitUsage)
    category = ::getTblValue("category", blk, "")

    if (guidParser.isGuid(id))
      isUGC = true

    cost = decoratorType.getCost(id)
    forceShowInCustomization = ::getTblValue("forceShowInCustomization", blk, false)

    tex = blk ? ::get_decal_tex(blk, 1) : id
    aspect_ratio = blk ? decoratorType.getRatio(blk) : 1

    if ("countries" in blk)
    {
      countries = []
      foreach (country, access in blk.countries)
        if (access == true)
          countries.append("country_" + country)
    }

    units = []
    if ("units" in blk)
      units = ::split(blk.units, "; ")

    if ("tags" in blk)
    {
      tags = {}
      foreach (tag, val in blk.tags)
        tags[tag] <- val
    }

    if (!isUnlocked() && !isVisible() && ("showByEntitlement" in unlockBlk))
      lockedByDLC = ::has_entitlement(unlockBlk.showByEntitlement) ? null : unlockBlk.showByEntitlement
  }

  function getName()
  {
    return decoratorType.getLocName(id)
  }

  function getDesc()
  {
    return decoratorType.getLocDesc(id)
  }

  function isUnlocked()
  {
    return decoratorType.isPlayerHaveDecorator(id)
  }

  function isVisible()
  {
    return decoratorType.isVisible(blk, this)
  }

  function isForceVisible()
  {
    return forceShowInCustomization
  }

  function getCost()
  {
    return cost
  }

  function canRecieve()
  {
    return unlockBlk != null || ! getCost().isZero()
  }

  function isLockedByCountry(unit)
  {
    if (countries == null)
      return false

    return !::isInArray(::getUnitCountry(unit), countries)
  }

  function isLockedByUnit(unit)
  {
    if (::u.isEmpty(units))
      return false

    return !::isInArray(unit.name, units)
  }

  function getUnitTypeLockIcon()
  {
    if (::u.isEmpty(units))
      return null

    return ::get_unit_type_font_icon(::get_es_unit_type(::getAircraftByName(units[0])))
  }

  function canBuyUnlock(unit)
  {
    return !isLockedByCountry(unit) && !isLockedByUnit(unit) && !isUnlocked() && !getCost().isZero() && ::has_feature("SpendGold")
  }

  function canUse(unit)
  {
    return isAvailable(unit) && !isOutOfLimit(unit)
  }

  function isAvailable(unit)
  {
    return !isLockedByCountry(unit) && !isLockedByUnit(unit) && isUnlocked()
  }

  function getCountOfUsingDecorator(unit)
  {
    if (decoratorType != ::g_decorator_type.ATTACHABLES || !isUnlocked())
      return 0

    local numUse = 0
    for (local i = 0; i < decoratorType.getAvailableSlots(unit); i++)
      if (id == decoratorType.getDecoratorNameInSlot(i))
        numUse++

    return numUse
  }

  function isOutOfLimit(unit)
  {
    if (limit < 0)
      return false

    if (limit == 0)
      return true

    return limit <= getCountOfUsingDecorator(unit)
  }

  function tostring()
  {
    local string = []
    string.append("id = " + id)
    if (category != "")
      string.append("category = " + category)
    string.append("decoratorType = " + decoratorType.name)
    if (unlockId)
      string.append("unlockId = " + unlockId)

    return "Decorator: " + ::g_string.implode(string, "; ")
  }
}
