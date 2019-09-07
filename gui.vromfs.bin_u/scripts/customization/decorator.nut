local guidParser = require("scripts/guidParser.nut")
local itemRarity = require("scripts/items/itemRarity.nut")
local contentPreview = require("scripts/customization/contentPreview.nut")

class Decorator
{
  id = ""
  blk = null
  decoratorType = null
  unlockId = ""
  unlockBlk = null
  isLive = false
  group = ""

  category = ""
  catIndex = 0

  limit = -1

  tex = ""
  aspect_ratio = 0

  countries = null
  units = null

  tags = null
  rarity = null

  lockedByDLC = null

  cost = null
  forceShowInCustomization = null

  isToStringForDebug = true

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
    group = ::getTblValue("group", blk, "")

    if (guidParser.isGuid(id))
      isLive = true // Only decorators from live.warthunder.com has GUID as id.

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

    rarity  = itemRarity.get(blk?.item_quality, blk?.name_color)

    if (!isUnlocked() && !isVisible() && ("showByEntitlement" in unlockBlk))
      lockedByDLC = ::has_entitlement(unlockBlk.showByEntitlement) ? null : unlockBlk.showByEntitlement
  }

  function getName()
  {
    local name = decoratorType.getLocName(id)
    return isRare() ? ::colorize(getRarityColor(), name) : name
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
    if (decoratorType == ::g_decorator_type.SKINS)
      return unit?.name != ::g_unlocks.getPlaneBySkinId(id)

    if (::u.isEmpty(units))
      return false

    return !::isInArray(unit?.name, units)
  }

  function getUnitTypeLockIcon()
  {
    if (::u.isEmpty(units))
      return null

    return ::get_unit_type_font_icon(::get_es_unit_type(::getAircraftByName(units[0])))
  }

  function getTypeDesc()
  {
    return decoratorType.getTypeDesc(this)
  }

  function getRestrictionsDesc()
  {
    if (decoratorType == ::g_decorator_type.SKINS)
      return ""

    local important = []
    local common    = []

    if (!::u.isEmpty(units))
    {
      local visUnits = ::u.filter(units, @(u) ::getAircraftByName(u)?.isInShop)
      important.append(::loc("options/unit") + ::loc("ui/colon") +
        ::g_string.implode(::u.map(visUnits, @(u) ::getUnitName(u)), ::loc("ui/comma")))
    }

    if (countries)
    {
      local visCountries = ::u.filter(countries, @(c) ::isInArray(c, ::shopCountriesList))
      important.append(::loc("events/countres") + " " +
        ::g_string.implode(::u.map(visCountries, @(c) ::loc(c)), ::loc("ui/comma")))
    }

    if (limit != -1)
      common.append(::loc("mainmenu/decoratorLimit", { limit = limit }))

    return ::colorize("warningTextColor", ::g_string.implode(important, "\n")) +
      (important.len() ? "\n" : "") + ::g_string.implode(common, "\n")
  }

  function getSmallIcon()
  {
    return decoratorType.getSmallIcon(this)
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
      if (id == decoratorType.getDecoratorNameInSlot(i) || (group != "" && group == decoratorType.getDecoratorGroupInSlot(i)))
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

  function isRare()
  {
    return rarity.isRare
  }

  function getRarity()
  {
    return rarity.value
  }

  function getRarityColor()
  {
    return  rarity.color
  }

  function getTagsLoc()
  {
    local res = rarity.tag ? [ rarity.tag ] : []
    local tagsVisibleBlk = ::configs.GUI.get().decorator_tags_visible
    if (tagsVisibleBlk && tags)
      foreach (tagBlk in tagsVisibleBlk % "i")
        if (tags?[tagBlk.tag])
          res.append(::loc("content/tag/" + tagBlk.tag))
    return res
  }

  function updateFromItemdef(itemDef)
  {
    rarity = itemRarity.get(itemDef?.item_quality, itemDef?.name_color)
    tags = itemDef?.tags
  }

  function _tostring()
  {
    return format("Decorator(%s, %s%s)", ::toString(id), decoratorType.name,
      unlockId == "" ? "" : (", unlock=" + unlockId))
  }

  function getLocParamsDesc()
  {
    return decoratorType.getLocParamsDesc(this)
  }

  function canPreview()
  {
    return isLive ? decoratorType.canPreviewLiveDecorator() : true
  }

  function doPreview()
  {
    if (canPreview())
      contentPreview.showResource(id, decoratorType.resourceType)
  }
}
