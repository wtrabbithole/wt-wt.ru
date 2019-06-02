local enums = ::require("sqStdlibs/helpers/enums.nut")
::g_unit_class_type <- {
  types = []
}

function g_unit_class_type::_getName()
{
  return ::loc(::format("mainmenu/type_%s", name))
}

function g_unit_class_type::_checkCode(codeMask)
{
  if (code < 0)
    return false
  codeMask = codeMask.tointeger()
  return (codeMask & (1 << code)) != 0
}

function g_unit_class_type::_getExpClass()
{
  return ::format("exp_%s", name)
}

::g_unit_class_type.template <- {
  code = -1
  name = ""
  expClassName = "" //filled automatically
  unitTypeCode = ::ES_UNIT_TYPE_INVALID
  checkOrder = -1

  /** Returns localized name of unit class type. */
  getName = ::g_unit_class_type._getName

  /** Check code against specified code mask. */
  checkCode = ::g_unit_class_type._checkCode

  /** Check if it is valid type. */
  isValid = @() code >= 0

  /** Returns unit exp class written in wpcost.blk. */
  getExpClass = ::g_unit_class_type._getExpClass

  /** Returns a related basic role font icon. */
  getFontIcon = @() ::get_unit_role_icon(name)
}

local checkOrder = 0
enums.addTypesByGlobalName("g_unit_class_type", {
  UNKNOWN = {
    name = "unknown"
  }

  FIGHTER = {
    code = ::EUCT_FIGHTER
    name = "fighter"
    unitTypeCode = ::ES_UNIT_TYPE_AIRCRAFT
    checkOrder = checkOrder++
  }

  BOMBER = {
    code = ::EUCT_BOMBER
    name = "bomber"
    unitTypeCode = ::ES_UNIT_TYPE_AIRCRAFT
    checkOrder = checkOrder++
  }

  ASSAULT = {
    code = ::EUCT_ASSAULT
    name = "assault"
    unitTypeCode = ::ES_UNIT_TYPE_AIRCRAFT
    checkOrder = checkOrder++
  }

  TANK = {
    code = ::EUCT_TANK
    name = "tank"
    unitTypeCode = ::ES_UNIT_TYPE_TANK
    checkOrder = checkOrder++

    getName = @() ::loc("mainmenu/type_medium_tank") + ::loc("ui/slash") + ::loc("mainmenu/type_light_tank")
    getFontIcon = @() ::get_unit_role_icon("medium_tank")
  }

  HEAVY_TANK = {
    code = ::EUCT_HEAVY_TANK
    name = "heavy_tank"
    unitTypeCode = ::ES_UNIT_TYPE_TANK
    checkOrder = checkOrder++
  }

  TANK_DESTROYER = {
    code = ::EUCT_TANK_DESTROYER
    name = "tank_destroyer"
    unitTypeCode = ::ES_UNIT_TYPE_TANK
    checkOrder = checkOrder++
  }

  SPAA = {
    code = ::EUCT_SPAA
    name = "spaa"
    unitTypeCode = ::ES_UNIT_TYPE_TANK
    checkOrder = checkOrder++

    getExpClass = function ()
    {
      // Name in uppercase.
      return "exp_SPAA"
    }
  }

  SHIP = {
    code = ::EUCT_SHIP
    name = "ship"
    unitTypeCode = ::ES_UNIT_TYPE_SHIP
    checkOrder = checkOrder++
  }

  TORPEDO_BOAT = {
    code = ::EUCT_TORPEDO_BOAT
    name = "torpedo_boat"
    unitTypeCode = ::ES_UNIT_TYPE_SHIP
    checkOrder = checkOrder++
  }

  GUN_BOAT = {
    code = ::EUCT_GUN_BOAT
    name = "gun_boat"
    unitTypeCode = ::ES_UNIT_TYPE_SHIP
    checkOrder = checkOrder++
  }

  TORPEDO_GUN_BOAT = {
    code = ::EUCT_TORPEDO_GUN_BOAT
    name = "torpedo_gun_boat"
    unitTypeCode = ::ES_UNIT_TYPE_SHIP
    checkOrder = checkOrder++
  }

  SUBMARINE_CHASER = {
    code = ::EUCT_SUBMARINE_CHASER
    name = "submarine_chaser"
    unitTypeCode = ::ES_UNIT_TYPE_SHIP
    checkOrder = checkOrder++
  }

  DESTROYER = {
    code = ::EUCT_DESTROYER
    name = "destroyer"
    unitTypeCode = ::ES_UNIT_TYPE_SHIP
    checkOrder = checkOrder++
  }

  NAVAL_FERRY_BARGE = {
    code = ::EUCT_NAVAL_FERRY_BARGE
    name = "naval_ferry_barge"
    unitTypeCode = ::ES_UNIT_TYPE_SHIP
    checkOrder = checkOrder++
  }

  HELICOPTER = {
    code = ::EUCT_HELICOPTER
    name = "helicopter"
    unitTypeCode = ::ES_UNIT_TYPE_HELICOPTER
    checkOrder = checkOrder++
  }

  CRUISER = {
    code = ::EUCT_CRUISER
    name = "cruiser"
    unitTypeCode = ::ES_UNIT_TYPE_SHIP
    checkOrder = checkOrder++
  }
},
function()
{
  expClassName = code == ::EUCT_SPAA ? name.toupper() : name
})

::g_unit_class_type.types.sort(@(a, b) a.checkOrder <=> b.checkOrder)

function g_unit_class_type::getTypesFromCodeMask(codeMask)
{
  local resultTypes = []
  foreach (t in types)
    if (t.checkCode(codeMask))
      resultTypes.push(t)
  return resultTypes
}

function g_unit_class_type::getTypeByExpClass(expClass)
{
  return enums.getCachedType("getExpClass", expClass, ::g_unit_class_type_cache.byExpClass,
    ::g_unit_class_type, ::g_unit_class_type.UNKNOWN)
}

function g_unit_class_type::getTypesByEsUnitType(esUnitType = null) //null if all unit types
{
  return types.filter(@(idx, t) (esUnitType == null && t.unitTypeCode != ::ES_UNIT_TYPE_INVALID)
    || t.unitTypeCode == esUnitType)
}

::g_unit_class_type_cache <- {
  byExpClass = {}
}
