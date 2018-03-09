local u = ::require("std/u.nut")

local ModificationBase = class extends ::BaseItem
{
  modsList = null
  unitTypes = null
  countries = null
  rankRange = null

  shouldAlwaysShowRank = false

  constructor(blk, invBlk = null, slotData = null)
  {
    base.constructor(blk, invBlk, slotData)

    local conditionsBlk = getConditionsBlk(blk)
    if (u.isDataBlock(conditionsBlk))
      initConditions(conditionsBlk)
  }

  getConditionsBlk = @(configBlk) null

  function initConditions(conditionsBlk)
  {
    if ("mod" in conditionsBlk)
      modsList = conditionsBlk % "mod"
    if ("unitType" in conditionsBlk)
      unitTypes = conditionsBlk % "unitType"
    if ("country" in conditionsBlk)
      countries = conditionsBlk % "country"

    local minRank = conditionsBlk.minRank
    local maxRank = conditionsBlk.maxRank
    if (shouldAlwaysShowRank || minRank || maxRank)
      rankRange = ::Point2(minRank || 1, maxRank || ::max_country_rank)
  }

  getDescriptionIntroArray = @() null
  getDescriptionOutroArray = @() null

  function getDescription()
  {
    local textParts = [base.getDescription()]

    local intro = getDescriptionIntroArray()
    if (intro)
      textParts.extend(intro)

    if (modsList)
    {
      local locMods = ::u.map(modsList,
        function(mod)
        {
          local res = ::loc("modification/" + mod + "/short", "")
          if (!res.len())
            res = ::loc("modification/" + mod)
          return res
        })
      textParts.push(::loc("multiAward/type/modification") + ::loc("ui/colon")
          + ::colorize("activeTextColor", ::g_string.implode(locMods, ", ")))
    }

    if (countries)
    {
      local locCountries = ::u.map(countries, @(country) ::loc("unlockTag/" + country))
      textParts.push(::loc("trophy/unlockables_names/country") + ::loc("ui/colon")
          + ::colorize("activeTextColor", ::g_string.implode(locCountries, ", ")))
    }
    if (unitTypes)
    {
      local locUnitTypes = ::u.map(unitTypes, @(unitType) ::loc("mainmenu/type_" + unitType))
      textParts.push(::loc("mainmenu/btnUnits") + ::loc("ui/colon")
          + ::colorize("activeTextColor", ::g_string.implode(locUnitTypes, ", ")))
    }

    local rankText = getRankText()
    if (rankText.len())
      textParts.push(::loc("sm_rank") + ::loc("ui/colon") + ::colorize("activeTextColor", rankText))

    local outro = getDescriptionOutroArray()
    if (outro)
      textParts.extend(outro)

    return ::g_string.implode (textParts, "\n")
  }

  function getRankText()
  {
    if (rankRange)
      return ::getUnitRankName(rankRange.x) + ((rankRange.x != rankRange.y) ? "-" + ::getUnitRankName(rankRange.y) : "")
    return ""
  }
}

return ModificationBase