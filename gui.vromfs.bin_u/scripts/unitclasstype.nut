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

  /** Returns unit exp class written in wpcost.blk. */
  getExpClass = ::g_unit_class_type._getExpClass
}

::g_enum_utils.addTypesByGlobalName("g_unit_class_type", {
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
  return ::g_enum_utils.getCachedType("getExpClass", expClass, ::g_unit_class_type_cache.byExpClass,
    ::g_unit_class_type, ::g_unit_class_type.UNKNOWN)
}

::g_unit_class_type_cache <- {
  byExpClass = {}
}
