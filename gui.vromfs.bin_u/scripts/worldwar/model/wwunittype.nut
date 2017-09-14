::g_ww_unit_type <- {
  types = []
  cache = {
    byName = {}
    byCode = {}
    byTextCode = {}
    byEsUnitCode = {}
  }
}

::g_ww_unit_type.template <- {
  code = -1
  textCode = ""
  sortCode = WW_UNIT_SORT_CODE.UNKNOWN
  esUnitCode = ::ES_UNIT_TYPE_INVALID
  name = ""
  fontIcon = ""
  moveSound = ""
  deploySound = ""
  expClass = null
  canBeControlledByPlayer = false
}

::g_enum_utils.addTypesByGlobalName("g_ww_unit_type", {
  UNKNOWN = {
  }
  AIR = {
    code = ::UT_AIR
    textCode = "UT_AIR"
    sortCode = WW_UNIT_SORT_CODE.AIR
    esUnitCode = ::ES_UNIT_TYPE_AIRCRAFT
    name = "Aircraft"
    fontIcon = ::loc("worldwar/iconAir")
    moveSound = "ww_unit_move_airplanes"
    deploySound = "ww_unit_move_airplanes"
    canBeControlledByPlayer = true
  }
  GROUND = {
    code = ::UT_GROUND
    textCode = "UT_GROUND"
    sortCode = WW_UNIT_SORT_CODE.GROUND
    esUnitCode = ::ES_UNIT_TYPE_TANK
    name = "Tank"
    fontIcon = ::loc("worldwar/iconGround")
    moveSound = "ww_unit_move_tanks"
    deploySound = "ww_unit_move_tanks"
    canBeControlledByPlayer = true
  }
  WATER = {
    code = ::UT_WATER
    textCode = "UT_WATER"
    sortCode = WW_UNIT_SORT_CODE.WATER
    esUnitCode = ::ES_UNIT_TYPE_SHIP
    name = "Ship"
    fontIcon = ::loc("worldwar/iconWater")
    canBeControlledByPlayer = true
  }
  INFANTRY = {
    code = ::UT_INFANTRY
    textCode = "UT_INFANTRY"
    sortCode = WW_UNIT_SORT_CODE.INFANTRY
    name = "Infantry"
    fontIcon = ::loc("worldwar/iconInfantry")
    expClass = "infantry"
    moveSound = "ww_unit_move_infantry"
    deploySound = "ww_unit_move_infantry"
  }
  ARTILLERY = {
    code = ::UT_ARTILLERY
    textCode = "UT_ARTILLERY"
    sortCode = WW_UNIT_SORT_CODE.ARTILLERY
    name = "Artillery"
    fontIcon = ::loc("worldwar/iconArtillery")
    expClass = "artillery"
    moveSound = "ww_unit_move_artillery"
    deploySound = "ww_unit_move_artillery"
  }
})


function g_ww_unit_type::getUnitTypeByCode(wwUnitTypeCode)
{
  return ::g_enum_utils.getCachedType(
    "code",
    wwUnitTypeCode,
    cache.byCode,
    this,
    UNKNOWN
  )
}


function g_ww_unit_type::getUnitTypeByTextCode(wwUnitTypeTextCode)
{
  return ::g_enum_utils.getCachedType(
    "textCode",
    wwUnitTypeTextCode,
    cache.byTextCode,
    this,
    UNKNOWN
  )
}


function g_ww_unit_type::getUnitTypeByEsUnitCode(esUnitCode)
{
  return ::g_enum_utils.getCachedType(
    "esUnitCode",
    esUnitCode,
    cache.byEsUnitCode,
    this,
    UNKNOWN
  )
}


function g_ww_unit_type::getUnitTypeByWwUnit(wwUnit)
{
  if (wwUnit.name in cache.byName)
    return cache.byName[wwUnit.name]

  local esUnitType = ::get_es_unit_type(wwUnit.unit)
  if (esUnitType != ::ES_UNIT_TYPE_INVALID)
    return ::g_ww_unit_type.getUnitTypeByEsUnitCode(esUnitType)
  else if (wwUnit.isInfantry())
    return ::g_ww_unit_type.INFANTRY
  else if (wwUnit.isArtillery())
    return ::g_ww_unit_type.ARTILLERY

  return ::g_ww_unit_type.UNKNOWN
}


function g_ww_unit_type::getUnitTypeFontIcon(wwUnitTypeCode)
{
  return getUnitTypeByCode(wwUnitTypeCode).fontIcon
}


function g_ww_unit_type::isAir(wwUnitTypeCode)
{
  return wwUnitTypeCode == AIR.code
}


function g_ww_unit_type::isGround(wwUnitTypeCode)
{
  return wwUnitTypeCode == GROUND.code
}


function g_ww_unit_type::isWater(wwUnitTypeCode)
{
  return wwUnitTypeCode == WATER.code
}


function g_ww_unit_type::isInfantry(wwUnitTypeCode)
{
  return wwUnitTypeCode == INFANTRY.code
}


function g_ww_unit_type::isArtillery(wwUnitTypeCode)
{
  return wwUnitTypeCode == ARTILLERY.code
}

function g_ww_unit_type::canBeSurrounded(wwUnitTypeCode)
{
  return isGround(wwUnitTypeCode) ||
         isInfantry(wwUnitTypeCode) ||
         isArtillery(wwUnitTypeCode)
}
