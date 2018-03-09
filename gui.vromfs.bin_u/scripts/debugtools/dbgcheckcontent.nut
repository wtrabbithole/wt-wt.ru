local skinLocations = ::require("scripts/customization/skinLocations.nut")

function debug_check_unlocalized_resources()
{
  if (!::is_dev_version) return

  dlog("debug_check_unlocalized_resources() // " + ::get_current_language() +" // listed in log")
  local count = 0

  // Units
  dagor.debug("UNITS")
  count = 0
  foreach (unit in ::all_units)
    if (unit.isInShop)
      foreach (suffix in ["_shop", "_0", "_1", "_2"])
      {
        local localeId = unit.name + suffix
        if (::loc(localeId, "") == "")
        {
          dagor.debug("    " + localeId)
          count++
        }
      }
  dlog(count + " units")

  // Unit Descriptions
  dagor.debug("UNITDESC")
  count = 0
  local placeholder = ::loc("encyclopedia/no_unit_description")
  foreach (unit in ::all_units)
    if (unit.isInShop)
    {
      local localeId = "encyclopedia/" + unit.name + "/desc"
      local text = ::loc(localeId, "")
      if (text == "" || text == placeholder)
      {
        dagor.debug("    " + localeId)
        count++
      }
    }
  dlog(count + " unitdescs")

  // Skins
  dagor.debug("SKINS")
  count = 0
  foreach (unit in ::all_units)
    if (unit.isInShop)
    {
      if (unit.skins.len() == 0)
        unit.skins = get_skins_for_unit(unit.name) //always returns at least one entry

      foreach (skin in unit.skins)
        if (skin.name.len())
        {
          local localeId = unit.name + "/" + skin.name
          if (::loc(localeId, "") == "")
          {
            dagor.debug("    " + localeId)
            count++
          }
        }
    }
  dlog(count + " skins")

  // Decals
  dagor.debug("DECALS")
  count = 0
  local blk = ::get_decals_blk()
  local total = blk.blockCount()
  for (local i = 0; i < total; i++)
  {
    local dblk = blk.getBlock(i)
    local localeId = "decals/" + dblk.getBlockName()
    if (::loc(localeId, "") == "")
    {
      dagor.debug("    " + localeId)
      count++
    }
  }
  dlog(count + " decals")
}

function debug_check_unit_naming()
{
  if (!::is_dev_version) return

  local unitIds = []
  local names = {}
  local suffixes = ["_shop", "_0", "_1", "_2"]
  local count = 0
  local total = 0
  local brief = []

  brief.append("debug_check_unit_naming() // " + ::get_current_language())
  dagor.debug(brief[brief.len() - 1])

  foreach (unit in ::all_units)
    if (unit.isInShop)
      unitIds.append(unit.name)
  foreach (suffix in suffixes)
    names[suffix] <- []

  dagor.debug("UNLOCALIZED UNIT NAMES:")
  count = 0
  foreach (unitId in unitIds)
    foreach (suffix in suffixes)
    {
      local locId = unitId + suffix
      local locName = ::loc(locId)
      if (locName == locId)
      {
        locName = ""
        dagor.debug(::format("    '%s' - not found in localization", locId))
        count++
      }
      names[suffix].append(locName)
    }
  brief.append(count + " unlocalized unit names")
  dagor.debug(brief[brief.len() - 1])
  total += count

  dagor.debug("NAME_SHOP CONFLICTS (IMPORTANT!):")
  count = 0
  for (local i = 0; i < unitIds.len(); i++)
    for (local j = i + 1; j < unitIds.len(); j++)
      if (names._shop[i] != "" && names._shop[j] != "" && names._shop[i] == names._shop[j])
      {
        dagor.debug(::format("    '%s_shop', '%s_shop' - both units named '%s'", unitIds[i], unitIds[j], names._shop[i]))
        count++
      }
  brief.append(count + " name_shop conflicts:")
  dagor.debug(brief[brief.len() - 1])
  total += count

  dagor.debug("NAME_0 CONFLICTS:")
  count = 0
  for (local i = 0; i < unitIds.len(); i++)
    for (local j = i + 1; j < unitIds.len(); j++)
      if (names._0[i] != "" && names._0[j] != "" && names._0[i] == names._0[j])
      {
        dagor.debug(::format("    '%s_0', '%s_0' - both units named '%s'", unitIds[i], unitIds[j], names._0[i]))
        count++
      }
  brief.append(count + " name_0 conflicts")
  dagor.debug(brief[brief.len() - 1])
  total += count

  dagor.debug("MIXED-UP _SHOP AND _0 NAMES:")
  count = 0
  for (local i = 0; i < unitIds.len(); i++)
    if (names._shop[i] != "" && names._0[i] != "" && ::utf8_strlen(names._shop[i]) > ::utf8_strlen(names._0[i]))
    {
      dagor.debug(::format("    '%s_shop' ('%s') is longer than '%s_0' ('%s'), probably names are mixed up", unitIds[i], names._shop[i], unitIds[i], names._0[i]))
      count++
    }
  brief.append(count + " _shop and _0 names mixed-up")
  dagor.debug(brief[brief.len() - 1])
  total += count

  dagor.debug("MIXED-UP _SHOP AND _1 NAMES:")
  count = 0
  for (local i = 0; i < unitIds.len(); i++)
    if (names._shop[i] != "" && names._1[i] != "" && ::utf8_strlen(names._1[i]) > ::utf8_strlen(names._shop[i]))
    {
      dagor.debug(::format("    '%s_1' ('%s') is longer than '%s_shop' ('%s'), probably names are mixed up", unitIds[i], names._1[i], unitIds[i], names._shop[i]))
      count++
    }
  brief.append(count + " _shop and _1 names mixed-up")
  dagor.debug(brief[brief.len() - 1])
  total += count

  dagor.debug("NAMES WITH WASTED SPACE:")
  count = 0
  foreach (idx, unitId in unitIds)
    foreach (suffix in suffixes)
    {
      local name = names[suffix][idx]
      local fixed = regexp2(@"\s\s").replace(" ", strip(name))
      if (name.len() > fixed.len())
      {
        dagor.debug(::format("    '%s%s' - need to trim space characters here: '%s'", unitId, suffix, name))
        count++
      }
    }
  brief.append(count + " names with wasted space")
  dagor.debug(brief[brief.len() - 1])
  total += count

  brief.append("TOTAL: " + total)
  dagor.debug(brief[brief.len() - 1])
  foreach (str in brief)
    dagor.screenlog(str)
  return total
}

function debug_cur_level_auto_skins()
{
  local level = ::is_in_flight() ? ::get_current_mission_info_cached()?.level : null
  local fullDebugtext = "Auto skins for " + (level || "TestFlight")
  if (level)
    fullDebugtext += " ( " + skinLocations.debugLocationMask(skinLocations.getMaskByLevel(level)) + " )"

  local total = 0
  foreach(unit in ::all_units)
    if (unit.unitType.isSkinAutoSelectAvailable())
    {
      total++
      fullDebugtext += "\n" + unit.name + " -> "
        + ::g_string.implode(::g_decorator.getBestSkinsList(unit.name, true), ", ")
    }

  dagor.debug(fullDebugtext)
  return "Total units found = " + total
}

function debug_all_skins_without_location_mask()
{
  local totalList = []
  foreach(unit in ::all_units)
    if (unit.unitType.isSkinAutoSelectAvailable())
      foreach(skin in unit.getSkins())
      {
        if (skin.name == "")
          continue
        local mask = skinLocations.getSkinLocationsMask(skin.name, unit.name)
        if (!mask)
          ::u.appendOnce(skin.name, totalList)
      }
  return "Total skins without location mask = " + totalList.len() + "\n" + ::g_string.implode(totalList, ", ")
}