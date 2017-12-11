::unitTypesList <- [::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_TANK] //!!FIX ME: use g_unit_type instead

enum UNIT_TYPE_ORDER
{
  AIRCRAFT
  TANK
  SHIP
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

::g_unit_type.template <- {
  typeName = "" //filled automatically by typeName
  name = ""
  tag = ""
  armyId = ""
  esUnitType = ::ES_UNIT_TYPE_INVALID
  bit = 0      //unitType bit for it mask. filled by esUnitType  (bit = 1 << esUnitType)
  sortOrder = UNIT_TYPE_ORDER.INVALID
  uiSkin = "!#ui/unitskin#"
  uiClassSkin = "!#ui/gameuiskin#"
  fontIcon = ""
  testFlightIcon = ""
  testFlightName = ""
  canChangeViewType = false
  hudTypeCode = ::HUD_TYPE_UNKNOWN

  firstChosenTypeUnlockName = null

  isAvailable = function() { return false }
  isVisibleInShop = function() { return isAvailable() }
  isAvailableForFirstChoice = function(country = null) { return isAvailable() }
  isFirstChosen = function()
    { return firstChosenTypeUnlockName != null && ::is_unlocked(-1, firstChosenTypeUnlockName) }
  getTestFlightText = function() { return ::loc("mainmenu/btn" + testFlightName ) }
  getTestFlightUnavailableText = function() { return ::loc("mainmenu/cant" + testFlightName ) }
  getArmyLocName = function() { return ::loc("mainmenu/" + armyId, "") }
  getLocName = function() { return ::loc(::format("unit_type/%s", tag), "") }
  canUseSeveralBulletsForGun = false
}

::g_enum_utils.addTypesByGlobalName("g_unit_type", {
  INVALID = {
    name = "Invalid"
    armyId = ""
    esUnitType = ::ES_UNIT_TYPE_INVALID
    sortOrder = UNIT_TYPE_ORDER.INVALID
  }

  AIRCRAFT = {
    name = "Aircraft"
    tag = "air"
    armyId = "aviation"
    esUnitType = ::ES_UNIT_TYPE_AIRCRAFT
    sortOrder = UNIT_TYPE_ORDER.AIRCRAFT
    uiSkin = "!#ui/unitskin#"
    uiClassSkin = "!#ui/gameuiskin#"
    fontIcon = ::loc("icon/unittype/aircraft")
    testFlightIcon = "#ui/gameuiskin#slot_testflight.svg"
    testFlightName = "TestFlight"
    hudTypeCode = ::HUD_TYPE_AIRPLANE
    firstChosenTypeUnlockName = "chosen_unit_type_air"
    isAvailable = function() { return true }
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
  }

  TANK = {
    name = "Tank"
    tag = "tank"
    armyId = "army"
    esUnitType = ::ES_UNIT_TYPE_TANK
    sortOrder = UNIT_TYPE_ORDER.TANK
    uiSkin = "!#ui/unitskin#"
    uiClassSkin = "!#ui/gameuiskin#"
    fontIcon = ::loc("icon/unittype/tank")
    testFlightIcon = "#ui/gameuiskin#slot_testdrive.svg"
    testFlightName = "TestDrive"
    hudTypeCode = ::HUD_TYPE_TANK
    firstChosenTypeUnlockName = "chosen_unit_type_tank"
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
      return true
    }
    canUseSeveralBulletsForGun = true
  }

  SHIP = {
    name = "Ship"
    tag = "ship"
    armyId = "fleet"
    esUnitType = ::ES_UNIT_TYPE_SHIP
    sortOrder = UNIT_TYPE_ORDER.SHIP
    uiSkin = "!#ui/unitskin#"
    uiClassSkin = "!#ui/gameuiskin#"
    fontIcon = ::loc("icon/unittype/ship")
    testFlightIcon = "#ui/gameuiskin#slot_test_out_to_sea.svg"
    testFlightName = "TestSail"
    hudTypeCode = ::HUD_TYPE_TANK
    firstChosenTypeUnlockName = "chosen_unit_type_ship"
    isAvailable = function() { return ::has_feature("Ships") }
    isVisibleInShop = function() { return isAvailable() && ::has_feature("ShipsVisibleInShop") }
    isAvailableForFirstChoice = function(country = null)
      { return isAvailable() && ::has_feature("ShipsFirstChoice") }
    canUseSeveralBulletsForGun = true
  }
},
function()
{
  if (esUnitType != ::ES_UNIT_TYPE_INVALID)
    bit = 1 << esUnitType
}, "typeName")


::g_unit_type.types.sort(function(a,b)
{
  if (a.sortOrder != b.sortOrder)
    return a.sortOrder > b.sortOrder ? 1 : -1
  return 0
})

function g_unit_type::getByEsUnitType(esUnitType)
{
  return ::g_enum_utils.getCachedType("esUnitType", esUnitType, cache.byEsUnitType, this, INVALID)
}

function g_unit_type::getByBit(bit)
{
  return ::g_enum_utils.getCachedType("bit", bit, cache.byBit, this, INVALID)
}

function g_unit_type::getByName(typeName, caseSensitive = true)
{
  local cacheTbl = caseSensitive ? cache.byName : cache.byNameNoCase
  return ::g_enum_utils.getCachedType("name", typeName, cacheTbl, this, INVALID, caseSensitive)
}

function g_unit_type::getByArmyId(armyId)
{
  return ::g_enum_utils.getCachedType("armyId", armyId, cache.byArmyId, this, INVALID)
}

function g_unit_type::getByTag(tag)
{
  return ::g_enum_utils.getCachedType("tag", tag, cache.byTag, this, INVALID)
}

function g_unit_type::getByUnitName(unitId)
{
  local unit = ::getAircraftByName(unitId)
  return unit ? unit.unitType : INVALID
}

function g_unit_type::getTypeMaskByTagsString(listStr, separator = "; ")
{
  local res = 0
  local list = ::split(listStr, separator)
  foreach(tag in list)
    res = res | getByTag(tag).bit
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
