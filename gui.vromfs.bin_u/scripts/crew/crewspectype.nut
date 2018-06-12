local enums = ::require("std/enums.nut")
::g_crew_spec_type <- {
  types = []
}

function g_crew_spec_type::_getNextType()
{
  return ::g_crew_spec_type.getTypeByCode(nextCode)
}

function g_crew_spec_type::_isCrewTrained(crew, unit)
{
  return ::g_crew_spec_type.getTrainedSpecCode(crew, unit) >= code
}

function g_crew_spec_type::_getUpgradeCostByCrewAndByUnit(crew, unit, upgradeToSpecCode = -1)
{
  if (upgradeToSpecCode < 0)
    upgradeToSpecCode = code + 1

  local cost = ::Cost()
  for(local specCode = code; specCode < upgradeToSpecCode; specCode++)
  {
    cost.wp += ::wp_get_specialization_cost(specCode, unit.name, crew.id, -1)
    cost.gold += ::wp_get_specialization_cost_gold(specCode, unit.name, crew.id, -1)
  }
  return cost
}

function g_crew_spec_type::_getUpgradeCostByUnitAndExp(unit, exp)
{
  return ::Cost(::wp_get_specialization_cost(code, unit.name, 0, exp),
                ::wp_get_specialization_cost_gold(code, unit.name, 0, exp))
}

function g_crew_spec_type::_getName()
{
  return ::loc(getNameLocId(), "")
}

function g_crew_spec_type::_hasNextType()
{
  return getNextType() != ::g_crew_spec_type.UNKNOWN
}

function g_crew_spec_type::_getButtonLabel()
{
  return ::loc("crew/qualifyIncrease" + code, "")
}

function g_crew_spec_type::_getDiscountTooltipByValue(discountValue)
{
  if (!::u.isString(discountValue))
    discountValue = discountValue.tostring()
  local locId = ::format("discount/%s/tooltip", specName)
  return ::format(::loc(locId), discountValue)
}

function g_crew_spec_type::_getNameLocId()
{
  return ::format("crew/qualification/%d", code)
}

function g_crew_spec_type::_getDiscountValueByUnitNames(unitNames)
{
  local priceBlk = ::get_price_blk()
  return ::getDiscountByPath(["aircrafts", unitNames, "specialization", specName], priceBlk)
}

function g_crew_spec_type::_getPrevType()
{
  foreach (type in ::g_crew_spec_type.types)
    if (type.nextCode == code)
      return type
  return ::g_crew_spec_type.UNKNOWN
}

function g_crew_spec_type::_hasPrevType()
{
  return getPrevType() != ::g_crew_spec_type.UNKNOWN
}

function g_crew_spec_type::_getMulValue(prevSpecTypeCode = 0)
{
  local skillsBlk = ::get_skills_blk()
  local addPct = 0.0
  for(local specCode = code; specCode > prevSpecTypeCode; specCode--)
    addPct += skillsBlk[::format("specialization%d_add", specCode + 1)] || 0
  return 0.01 * addPct
}

function g_crew_spec_type::_getFullBonusesText(unitType, prevSpecTypeCode = -1)
{
  ::load_crew_skills_once()

  if (prevSpecTypeCode < 0)
    prevSpecTypeCode = code - 1
  local specMul = getMulValue(prevSpecTypeCode)
  local rowsArray = []
  foreach(page in ::crew_skills)
  {
    if (!page.isVisible(unitType))
      continue

    local textsArray = []
    foreach(item in page.items)
      if (item.isVisible(unitType) && item.useSpecializations)
      {
        local skillCrewLevel = ::g_crew.getSkillCrewLevel(item, specMul * ::g_crew.getMaxSkillValue(item))
        local skillText = ::loc("crew/" + item.name) + " "
                          + ::colorize("goodTextColor", "+" + skillCrewLevel)
        textsArray.append(::stringReplace(skillText, " ", ::nbsp))
      }

    if (!textsArray.len())
      continue

    rowsArray.append(::colorize("activeTextColor", ::loc("crew/" + page.id))
                     + ::loc("ui/colon") + ::g_string.implode(textsArray, ", ") + ::loc("ui/dot"))
  }
  return ::g_string.implode(rowsArray, "\n")
}

function g_crew_spec_type::_getReqCrewLevelByCode(unit, upgradeFromCode)
{
  ::load_crew_skills_once()
  local reqTbl = ::getTblValue(::get_es_unit_type(unit), ::crew_air_train_req)
  local ranksTbl = ::getTblValue(upgradeFromCode, reqTbl)
  return ::getTblValue(unit.rank, ranksTbl, 0)
}

function g_crew_spec_type::_getReqCrewLevel(unit)
{
  return _getReqCrewLevelByCode(unit, code - 1)
}

function g_crew_spec_type::_getUpgradeReqCrewLevel(unit)
{
  return _getReqCrewLevelByCode(unit, code)
}

function g_crew_spec_type::_getNextMaxAvailableType(unit, crewLevel)
{
  local resType = this
  local nextType = null
  while ((nextType = resType.getNextType()) != ::g_crew_spec_type.UNKNOWN)
    if (nextType.getReqCrewLevel(unit) <= crewLevel)
      resType = nextType
    else
      break
  return resType
}

function g_crew_spec_type::_getIcon(crewTypeCode, crewLevel, unit)
{
  if (crewTypeCode >= code)
    return icon

  if (unit && getReqCrewLevel(unit) <= crewLevel)
    return iconCanBuy
  return iconInactive
}

function g_crew_spec_type::_isExpUpgradableByUnit(unit)
{
  return false
}


function g_crew_spec_type::_getExpLeftByCrewAndUnit(crew, unit)
{
  return -1
}

function g_crew_spec_type::_getTotalExpByUnit(unit)
{
  return -1
}

function g_crew_spec_type::_getExpUpgradeDiscountData()
{
  return []
}

function g_crew_spec_type::_needShowExpUpgrade(crew, unit)
{
  return isExpUpgradableByUnit(unit)
}

//return empty string when level is enough
function g_crew_spec_type::_getReqLevelText(crew, unit)
{
  local reqLevel = getReqCrewLevel(unit)
  local crewLevel = ::g_crew.getCrewLevel(crew, ::get_es_unit_type(unit))
  if (reqLevel <= crewLevel)
    return ""

  local res = ::loc("crew/qualifyRequirement/full",
                     {
                       wantedQualify = ::colorize("activeTextColor", getName())
                       unitName = ::colorize("activeTextColor", ::getUnitName(unit))
                       reqLevel = ::colorize("activeTextColor", reqLevel)
                     })
  return ::colorize("badTextColor", res)
}

function g_crew_spec_type::_getBaseTooltipText(crew, unit)
{
  local tooltipText = ::loc("crew/qualification/tooltip")
  local isShowExpUpgrade = needShowExpUpgrade(crew, unit)
  if (hasNextType())
  {
    local nextType = getNextType()
    local nextSpecName = nextType.getName()
    tooltipText += ::format(
      "\n\n%s: %s",
      ::loc("crew/qualification/nextSpec"),
      ::colorize("activeTextColor", nextSpecName))


    local reqLevelText = nextType.getReqLevelText(crew, unit)
    if (reqLevelText.len())
      tooltipText += "\n" + reqLevelText
    else
    {
      local specDescriptionPart = isShowExpUpgrade ?
        ::loc("crew/qualification/specDescriptionPart", {
          expAmount = ::Cost().setRp(getTotalExpByUnit(unit)).tostring()
        })
        : ""
      local specDescription = ::loc(
        "crew/qualification/specDescriptionMain", {
          specName = ::colorize("activeTextColor", nextSpecName)
          trainCost = getUpgradeCostByCrewAndByUnit(crew, unit).tostring()
          descPart = specDescriptionPart
        })
      tooltipText += "\n" + specDescription
    }
  }
  if (isShowExpUpgrade)
  {
    tooltipText += ::format(
      "\n%s: %s / %s",
      ::loc("crew/qualification/expUpgradeLabel"),
      ::Cost().setRp(getExpLeftByCrewAndUnit(crew, unit)).toStringWithParams({isRpAlwaysShown = true}),
      ::Cost().setRp(getTotalExpByUnit(unit)).tostring())
  }
  return tooltipText
}

function g_crew_spec_type::_getTooltipContent(crew, unit)
{
  local progressBarValue = 1000 * getExpLeftByCrewAndUnit(crew, unit)
    / getTotalExpByUnit(unit)
  local view = {
    tooltipText = getBaseTooltipText(crew, unit)
    hasExpUpgrade = needShowExpUpgrade(crew, unit)
    markers = []
    progressBarValue = progressBarValue.tointeger()
  }

  // Discount markers.
  local expUpgradeText = ""
  local totalExp = getTotalExpByUnit(unit)
  foreach (i, dataItem in getExpUpgradeDiscountData())
  {
    local romanNumeral = ::get_roman_numeral(i + 1)
    local markerView = {
      markerRatio = dataItem.percent.tofloat() / 100
      markerText = romanNumeral
    }
    view.markers.push(markerView)

    if (expUpgradeText.len() > 0)
      expUpgradeText += "\n"
    local expAmount = (dataItem.percent * totalExp / 100).tointeger()
    local trainCost = getUpgradeCostByUnitAndExp(unit, expAmount)
    local locParams = {
      romanNumeral = romanNumeral
      trainCost = trainCost.tostring()
      expAmount = ::Cost().setRp(expAmount).toStringWithParams({isRpAlwaysShown = true})
    }
    expUpgradeText += ::loc("crew/qualification/expUpgradeMarkerCaption", locParams)
  }

  // Marker at 100% progress.
  local romanNumeral = ::get_roman_numeral(view.markers.len() + 1)
  view.markers.push({
    markerRatio = 1
    markerText = romanNumeral
  })
  if (expUpgradeText.len() > 0)
    expUpgradeText += "\n"
  local locParams = {
    romanNumeral = romanNumeral
    specName = ::colorize("activeTextColor", getNextType().getName())
    expAmount = ::Cost().setRp(getTotalExpByUnit(unit)).toStringWithParams({isRpAlwaysShown = true})
  }
  expUpgradeText += ::loc("crew/qualification/expUpgradeFullUpgrade", locParams)

  view.expUpgradeText <- expUpgradeText

  return ::handyman.renderCached("gui/crew/crewUnitSpecUpgradeTooltip", view)
}

function g_crew_spec_type::_getBtnBuyTooltipId(crew, unit)
{
  return ::g_tooltip.getIdBuyCrewSpec(crew.id, unit.name, code)
}

function g_crew_spec_type::_getBtnBuyTooltipContent(crew, unit)
{
  local view = {
    tooltipText = ""
    tinyTooltipText = ""
  }

  if (isCrewTrained(crew, unit) || !hasPrevType())
  {
    view.tooltipText = ::loc("crew/trained") + ::loc("ui/colon")
                     + ::colorize("activeTextColor", getName())
  } else
  {
    local curSpecType = ::g_crew_spec_type.getTypeByCrewAndUnit(crew, unit)
    view.tooltipText = getReqLevelText(crew, unit)
    if (!view.tooltipText.len())
      view.tooltipText = ::loc("crew/qualification/buy",
                           {
                             qualify = ::colorize("activeTextColor", getName())
                             unitName = ::colorize("activeTextColor", ::getUnitName(unit))
                             cost = ::colorize("activeTextColor", 
                                               curSpecType.getUpgradeCostByCrewAndByUnit(crew, unit, code).tostring())
                           })

    view.tinyTooltipText = ::loc("shop/crewQualifyBonuses",
                                 {
                                   qualification = ::colorize("userlogColoredText", getName())
                                   bonuses = getFullBonusesText(::get_es_unit_type(unit), curSpecType.code)
                                 })
  }
  view.tooltipText += "\n\n" + ::loc("crew/qualification/tooltip")

  return ::handyman.renderCached("gui/crew/crewUnitSpecUpgradeTooltip", view)
}

::g_crew_spec_type.template <- {
  code = -1
  specName = ""
  nextCode = -1
  icon = ""
  iconInactive = ""
  iconCanBuy = ""
  trainedIcon = ""
  expUpgradableFeature = null

  getNextType = ::g_crew_spec_type._getNextType
  isCrewTrained = ::g_crew_spec_type._isCrewTrained

  /**
   * Returns cost of upgrade to next spec type.
   */
  getUpgradeCostByCrewAndByUnit = ::g_crew_spec_type._getUpgradeCostByCrewAndByUnit
  getUpgradeCostByUnitAndExp = ::g_crew_spec_type._getUpgradeCostByUnitAndExp

  getName = ::g_crew_spec_type._getName
  hasNextType = ::g_crew_spec_type._hasNextType

  /**
   * Returns button label about next type upgrade.
   * E.g. "Upgrade qualification to Expert" for BASIC spec type.
   */
  getButtonLabel = ::g_crew_spec_type._getButtonLabel

  getDiscountTooltipByValue = ::g_crew_spec_type._getDiscountTooltipByValue
  getNameLocId = ::g_crew_spec_type._getNameLocId
  getDiscountValueByUnitNames = ::g_crew_spec_type._getDiscountValueByUnitNames

  /**
   * Returns spec type such that type.nextCode == this.code.
   * Returns UNKNOWN spec type if no such type found.
   */
  getPrevType = ::g_crew_spec_type._getPrevType

  /**
   * Returns true if this type can be upgraded from some other type.
   */
  hasPrevType = ::g_crew_spec_type._hasPrevType

  getMulValue = ::g_crew_spec_type._getMulValue
  getFullBonusesText = ::g_crew_spec_type._getFullBonusesText

  _getReqCrewLevelByCode = ::g_crew_spec_type._getReqCrewLevelByCode
  getReqCrewLevel = ::g_crew_spec_type._getReqCrewLevel
  getUpgradeReqCrewLevel = ::g_crew_spec_type._getUpgradeReqCrewLevel
  getNextMaxAvailableType = ::g_crew_spec_type._getNextMaxAvailableType

  getIcon = ::g_crew_spec_type._getIcon
  isExpUpgradableByUnit = ::g_crew_spec_type._isExpUpgradableByUnit
  getExpLeftByCrewAndUnit = ::g_crew_spec_type._getExpLeftByCrewAndUnit
  getTotalExpByUnit = ::g_crew_spec_type._getTotalExpByUnit
  getExpUpgradeDiscountData = ::g_crew_spec_type._getExpUpgradeDiscountData

  needShowExpUpgrade = ::g_crew_spec_type._needShowExpUpgrade
  getReqLevelText = ::g_crew_spec_type._getReqLevelText
  getBaseTooltipText = ::g_crew_spec_type._getBaseTooltipText
  getTooltipContent = ::g_crew_spec_type._getTooltipContent
  getBtnBuyTooltipId = ::g_crew_spec_type._getBtnBuyTooltipId
  getBtnBuyTooltipContent = ::g_crew_spec_type._getBtnBuyTooltipContent
}

enums.addTypesByGlobalName("g_crew_spec_type", {
  UNKNOWN = {
    specName    = "unknown"
    trainedIcon = "#ui/gameuiskin#spec_icon1_place"
  }

  BASIC = {
    code = 0
    specName    = "spec_basic"
    nextCode    = 1
    trainedIcon = "#ui/gameuiskin#spec_icon1_can_buy"
  }

  EXPERT = {
    code = 1
    specName = "spec_expert"
    nextCode = 2
    icon          = "#ui/gameuiskin#spec_icon1"
    iconInactive  = "#ui/gameuiskin#spec_icon1_place"
    iconCanBuy    = "#ui/gameuiskin#spec_icon1_can_buy"
    trainedIcon   = "#ui/gameuiskin#spec_icon1"
    expUpgradableFeature = "ExpertToAce"

    isExpUpgradableByUnit = function (unit)
    {
      if (expUpgradableFeature && !::has_feature(expUpgradableFeature))
        return false
      return getTotalExpByUnit(unit) > 0
    }

    getExpLeftByCrewAndUnit = function (crew, unit)
    {
      local crewId = ::getTblValue("id", crew)
      local unitName = ::getTblValue("name", unit)
      return ::expert_to_ace_get_unit_exp(crewId, unitName)
    }

    getTotalExpByUnit = function (unit)
    {
      return ::getTblValue("train3Cost_exp", unit) || -1
    }

    getExpUpgradeDiscountData = function ()
    {
      local discountData = []
      if (expUpgradableFeature && !::has_feature(expUpgradableFeature))
        return discountData

      local warpointsBlk = ::get_warpoints_blk()
      if (warpointsBlk == null)
        return discountData

      local reduceBlk = warpointsBlk.expert_to_ace_cost_reduce
      if (reduceBlk == null)
        return discountData

      foreach (stageBlk in reduceBlk % "stage")
        discountData.push(::buildTableFromBlk(stageBlk))
      discountData.sort(function (a, b) {
        local percentA = ::getTblValue("percent", a, 0)
        local percentB = ::getTblValue("percent", b, 0)
        if (percentA != percentB)
          return percentA > percentB ? 1 : -1
        return 0
      })
      return discountData
    }
  }

  ACE = {
    code = 2
    specName = "spec_ace"
    icon          = "#ui/gameuiskin#spec_icon2"
    iconInactive  = "#ui/gameuiskin#spec_icon2_place"
    iconCanBuy    = "#ui/gameuiskin#spec_icon2_can_buy"
    trainedIcon   = "#ui/gameuiskin#spec_icon2"
  }
})

::g_crew_spec_type.types.sort(function(a, b) {
  return a.code < b.code ? -1 : (a.code > b.code ? 1 : 0)
})

function g_crew_spec_type::getTypeByCode(code)
{
  return enums.getCachedType("code", code, ::g_crew_spec_type_cache.byCode,
    ::g_crew_spec_type, ::g_crew_spec_type.UNKNOWN)
}

function g_crew_spec_type::getTrainedSpecCode(crew, unit)
{
  if (!unit)
    return -1

  return getTrainedSpecCodeByUnitName(crew, unit.name)
}

function g_crew_spec_type::getTrainedSpecCodeByUnitName(crew, unitName)
{
  return crew?.trainedSpec?[unitName] ?? -1
}

function g_crew_spec_type::getTypeByCrewAndUnit(crew, unit)
{
  local code = getTrainedSpecCode(crew, unit)
  return ::g_crew_spec_type.getTypeByCode(code)
}

function g_crew_spec_type::getTypeByCrewAndUnitName(crew, unitName)
{
  local code = getTrainedSpecCodeByUnitName(crew, unitName)
  return ::g_crew_spec_type.getTypeByCode(code)
}

::g_crew_spec_type_cache <- {
  byCode = {}
}
