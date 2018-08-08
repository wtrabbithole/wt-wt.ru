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
  unitTypeCode = ::ES_UNIT_TYPE_INVALID

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

enums.addTypesByGlobalName("g_unit_class_type", {
  UNKNOWN = {
    name = "unknown"
  }

  FIGHTER = {
    code = ::EUCT_FIGHTER
    name = "fighter"
    unitTypeCode = ::ES_UNIT_TYPE_AIRCRAFT
  }

  BOMBER = {
    code = ::EUCT_BOMBER
    name = "bomber"
    unitTypeCode = ::ES_UNIT_TYPE_AIRCRAFT
  }

  ASSAULT = {
    code = ::EUCT_ASSAULT
    name = "assault"
    unitTypeCode = ::ES_UNIT_TYPE_AIRCRAFT
  }

  TANK = {
    code = ::EUCT_TANK
    name = "tank"
    unitTypeCode = ::ES_UNIT_TYPE_TANK

    getName = @() ::loc("mainmenu/type_medium_tank") + ::loc("ui/slash") + ::loc("mainmenu/type_light_tank")
    getFontIcon = @() ::get_unit_role_icon("medium_tank")
  }

  HEAVY_TANK = {
    code = ::EUCT_HEAVY_TANK
    name = "heavy_tank"
    unitTypeCode = ::ES_UNIT_TYPE_TANK
  }

  TANK_DESTROYER = {
    code = ::EUCT_TANK_DESTROYER
    name = "tank_destroyer"
    unitTypeCode = ::ES_UNIT_TYPE_TANK
  }

  SPAA = {
    code = ::EUCT_SPAA
    name = "spaa"
    unitTypeCode = ::ES_UNIT_TYPE_TANK

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
  }
})

function g_unit_class_type::getTypesFromCodeMask(codeMask)
{
  local resultTypes = []
  foreach (type in types)
    if (type.checkCode(codeMask))
      resultTypes.push(type)
  return resultTypes
}

function g_unit_class_type::getTypeByExpClass(expClass)
{
  return enums.getCachedType("getExpClass", expClass, ::g_unit_class_type_cache.byExpClass,
    ::g_unit_class_type, ::g_unit_class_type.UNKNOWN)
}

::g_unit_class_type_cache <- {
  byExpClass = {}
}
