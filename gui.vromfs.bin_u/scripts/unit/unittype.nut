local enums = ::require("sqStdlibs/helpers/enums.nut")

enum UNIT_TYPE_ORDER
{
  AIRCRAFT
  TANK
  SHIP
  HELICOPTER
  INVALID
}

::g_unit_type <- {
  types = []
  cache = {
    byName = {}
    byNameNoCase = {}
    byEsUnitType = {}
    byArmyId = {}
    byTag = {}
    byBit = {}
  }
}

local crewUnitTypeConfig = {
  [::CUT_INVALID] = {
    crewTag = ""
  },
  [::CUT_AIRCRAFT] = {
    crewTag = "air"
  },
  [::CUT_TANK] = {
    crewTag = "tank"
  },
  [::CUT_SHIP] = {
    crewTag = "ship"
  }
}

::g_unit_type.template <- {
  typeName = "" //filled automatically by typeName
  name = ""
  lowerName = "" //filled automatically by name.tolower()
  tag = ""
  armyId = ""
  esUnitType = ::ES_UNIT_TYPE_INVALID
  bit = 0      //unitType bit for it mask. filled by esUnitType  (bit = 1 << esUnitType)
  bitCrewType = 0 //crewUnitType bit for it mask
  sortOrder = UNIT_TYPE_ORDER.INVALID
  uiSkin = "!#ui/unitskin#"
  uiClassSkin = "#ui/gameuiskin#"
  fontIcon = ""
  testFlightIcon = ""
  testFlightName = ""
  canChangeViewType = false
  hudTypeCode = ::HUD_TYPE_UNKNOWN

  firstChosenTypeUnlockName = null
  crewUnitType = ::CUT_INVALID
  hasAiGunners = false

  isAvailable = function() { return false }
  isVisibleInShop = function() { return isAvailable() }
  isAvailableForFirstChoice = function(country = null) { return isAvailable() }
  isFirstChosen = function()
    { return firstChosenTypeUnlockName != null && ::is_unlocked(-1, firstChosenTypeUnlockName) }
  getTestFlightText = function() { return ::loc("mainmenu/btn" + testFlightName ) }
  getTestFlightUnavailableText = function() { return ::loc("mainmenu/cant" + testFlightName ) }
  getArmyLocName = function() { return ::loc("mainmenu/" + armyId, "") }
  getCrewArmyLocName = @() ::loc("unit_type/" + crewUnitTypeConfig?[crewUnitType]?.crewTag ?? "")
  getCrewTag = @() crewUnitTypeConfig?[crewUnitType]?.crewTag ?? ""
  getLocName = function() { return ::loc(::format("unit_type/%s", tag), "") }
  canUseSeveralBulletsForGun = false
  modClassOrder = []
  isSkinAutoSelectAvailable = @() false
  canSpendGold = @() isAvailable()
  haveAnyUnitInCountry = @(countryName) ::isCountryHaveUnitType(countryName, esUnitType)
}

enums.addTypesByGlobalName("g_unit_type", {
  INVALID = {
    name = "Invalid"
    armyId = ""
    esUnitType = ::ES_UNIT_TYPE_INVALID
    sortOrder = UNIT_TYPE_ORDER.INVALID
    haveAnyUnitInCountry = @() false
  }

  AIRCRAFT = {
    name = "Aircraft"
    tag = "air"
    armyId = "aviation"
    esUnitType = ::ES_UNIT_TYPE_AIRCRAFT
    sortOrder = UNIT_TYPE_ORDER.AIRCRAFT
    fontIcon = ::loc("icon/unittype/aircraft")
    testFlightIcon = "#ui/gameuiskin#slot_testflight.svg"
    testFlightName = "TestFlight"
    hudTypeCode = ::HUD_TYPE_AIRPLANE
    firstChosenTypeUnlockName = "chosen_unit_type_air"
    crewUnitType = ::CUT_AIRCRAFT
    hasAiGunners = true
    isAvailable = @() true
    isAvailableForFirstChoice = function(country = null)
    {
      if (!isAvailable())
        return false
      if (country == "country_italy")
        return ::has_feature("ItalyAircraftsInFirstCountryChoice")
      if (country == "country_france")
        return ::has_feature("FranceAircraftsInFirstCountryChoice")
      return true
    }
    canUseSeveralBulletsForGun = false
    canChangeViewType = true
    modClassOrder = ["lth", "armor", "weapon"]
  }

  TANK = {
    name = "Tank"
    tag = "tank"
    armyId = "army"
    esUnitType = ::ES_UNIT_TYPE_TANK
    sortOrder = UNIT_TYPE_ORDER.TANK
    fontIcon = ::loc("icon/unittype/tank")
    testFlightIcon = "#ui/gameuiskin#slot_testdrive.svg"
    testFlightName = "TestDrive"
    hudTypeCode = ::HUD_TYPE_TANK
    firstChosenTypeUnlockName = "chosen_unit_type_tank"
    crewUnitType = ::CUT_TANK
    isAvailable = function() { return ::has_feature("Tanks") }
    isAvailableForFirstChoice = function(country = null)
    {
      if (!isAvailable() || !::check_tanks_available(true))
        return false

      if (!country)
        return true
      if (country == "country_britain")
        return ::has_feature("BritainTanksInFirstCountryChoice")
      if (country == "country_japan")
        return ::has_feature("JapanTanksInFirstCountryChoice")
      if (country == "country_france")
        return ::has_feature("FranceTanksInFirstCountryChoice")
      return true
    }
    canUseSeveralBulletsForGun = true
    modClassOrder = ["mobility", "protection", "firepower"]
    isSkinAutoSelectAvailable = @() ::has_feature("SkinAutoSelect")
    canSpendGold = @() isAvailable() && ::has_feature("SpendGoldForTanks")
  }

  SHIP = {
    name = "Ship"
    tag = "ship"
    armyId = "fleet"
    esUnitType = ::ES_UNIT_TYPE_SHIP
    sortOrder = UNIT_TYPE_ORDER.SHIP
    fontIcon = ::loc("icon/unittype/ship")
    testFlightIcon = "#ui/gameuiskin#slot_test_out_to_sea.svg"
    testFlightName = "TestSail"
    hudTypeCode = ::HUD_TYPE_TANK
    firstChosenTypeUnlockName = "chosen_unit_type_ship"
    crewUnitType = ::CUT_SHIP
    hasAiGunners = true
    isAvailable = function() { return ::has_feature("Ships") }
    isVisibleInShop = function() { return isAvailable() && ::has_feature("ShipsVisibleInShop") }
    isAvailableForFirstChoice = function(country = null)
      { return isAvailable() && ::has_feature("ShipsFirstChoice") }
    canUseSeveralBulletsForGun = true
    modClassOrder = ["seakeeping", "unsinkability", "firepower"]
    canSpendGold = @() isAvailable() && ::has_feature("SpendGoldForShips")
  }

  HELICOPTER = {
    name = "Helicopter"
    tag = "helicopter"
    armyId = "helicopters"
    esUnitType = ::ES_UNIT_TYPE_HELICOPTER
    sortOrder = UNIT_TYPE_ORDER.HELICOPTER
    fontIcon = ::loc("icon/unittype/helicopter")
    testFlightIcon = "#ui/gameuiskin#slot_heli_testflight.svg"
    testFlightName = "TestFlight"
    hudTypeCode = ::HUD_TYPE_AIRPLANE
    firstChosenTypeUnlockName = "chosen_unit_type_helicopter"
    crewUnitType = ::CUT_AIRCRAFT
    isAvailable = function() { return ::has_feature("Helicopters") }
    isVisibleInShop = function() { return isAvailable() }
    isAvailableForFirstChoice = @(country = null) false
    canUseSeveralBulletsForGun = false
    canChangeViewType = true
    modClassOrder = ["lth", "armor", "weapon"]
  }
},
function()
{
  if (esUnitType != ::ES_UNIT_TYPE_INVALID)
  {
    bit = 1 << esUnitType
    bitCrewType = 1 << crewUnitType
  }
  lowerName = name.tolower()
}, "typeName")


::g_unit_type.types.sort(function(a,b)
{
  if (a.sortOrder != b.sortOrder)
    return a.sortOrder > b.sortOrder ? 1 : -1
  return 0
})

function g_unit_type::getByEsUnitType(esUnitType)
{
  return enums.getCachedType("esUnitType", esUnitType, cache.byEsUnitType, this, INVALID)
}

function g_unit_type::getArrayBybitMask(bitMask)
{
  local typesArray = []
  foreach (type in ::g_unit_type.types)
  {
    if ((type.bit & bitMask) != 0)
      typesArray.append(type)
  }
  return typesArray
}

function g_unit_type::getByBit(bit)
{
  return enums.getCachedType("bit", bit, cache.byBit, this, INVALID)
}

function g_unit_type::getByName(typeName, caseSensitive = true)
{
  local cacheTbl = caseSensitive ? cache.byName : cache.byNameNoCase
  return enums.getCachedType("name", typeName, cacheTbl, this, INVALID, caseSensitive)
}

function g_unit_type::getByArmyId(armyId)
{
  return enums.getCachedType("armyId", armyId, cache.byArmyId, this, INVALID)
}

function g_unit_type::getByTag(tag)
{
  return enums.getCachedType("tag", tag, cache.byTag, this, INVALID)
}

function g_unit_type::getByUnitName(unitId)
{
  local unit = ::getAircraftByName(unitId)
  return unit ? unit.unitType : INVALID
}

function g_unit_type::getTypeMaskByTagsString(listStr, separator = "; ", bitMaskName = "bit")
{
  local res = 0
  local list = ::split(listStr, separator)
  foreach(tag in list)
    res = res | getByTag(tag)[bitMaskName]
  return res
}

function g_unit_type::getEsUnitTypeMaskByCrewUnitTypeMask(crewUnitTypeMask)
{
  local res = 0
  foreach(type in g_unit_type.types)
    if (crewUnitTypeMask & (1 << type.crewUnitType))
      res = res | type.esUnitType
  return res
}

//************************************************************************//
//*********************functions to work with esUnitType******************//
//********************but better to work with g_unit_type*****************//
//************************************************************************//

function getUnitTypeText(esUnitType)
{
  return ::g_unit_type.getByEsUnitType(esUnitType).name
}

function getUnitTypeByText(typeName, caseSensitive = false)
{
  return ::g_unit_type.getByName(typeName, caseSensitive).esUnitType
}

function get_first_chosen_unit_type(defValue = ::ES_UNIT_TYPE_INVALID)
{
  foreach(unitType in ::g_unit_type.types)
    if (unitType.isFirstChosen())
      return unitType.esUnitType
  return defValue
}

function get_unit_class_icon_by_unit(unit, iconName)
{
  local esUnitType = ::get_es_unit_type(unit)
  local type = ::g_unit_type.getByEsUnitType(esUnitType)
  return type.uiClassSkin + iconName
}

function get_unit_icon_by_unit(unit, iconName)
{
  local esUnitType = ::get_es_unit_type(unit)
  local type = ::g_unit_type.getByEsUnitType(esUnitType)
  return type.uiSkin + iconName
}

function get_tomoe_unit_icon(iconName)
{
  return "!#ui/unitskin#tomoe_" + iconName
}

function get_unit_type_font_icon(esUnitType)
{
  return ::g_unit_type.getByEsUnitType(esUnitType).fontIcon
}

function get_army_id_by_es_unit_type(esUnitType)
{
  return ::g_unit_type.getByEsUnitType(esUnitType).armyId
}

function get_unit_type_army_text(esUnitType)
{
  return ::g_unit_type.getByEsUnitType(esUnitType).getArmyLocName()
}
