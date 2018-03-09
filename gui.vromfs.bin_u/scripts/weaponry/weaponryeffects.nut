local enums = ::require("std/enums.nut")
local string = ::require("std/string.nut")

const GOOD_COLOR = "@goodTextColor"
const BAD_COLOR = "@badTextColor"
const NEUTRAL_COLOR = "@activeTextColor"

const MEASURE_UNIT_SPEED = 0
const MEASURE_UNIT_ALT = 1
const MEASURE_UNIT_CLIMB_SPEED = 3

local presetsList = {
  SPEED = {
    measureType = MEASURE_UNIT_SPEED
    validateValue = @(value) ::fabs(value) * 3.6 > 1.0 ? value : null
  }
  CLIMB_SPEED = {
    measureType = MEASURE_UNIT_CLIMB_SPEED
    validateValue = @(value) ::fabs(value) > 0.1 ? value : null
  }
  PERCENT_FLOAT = {
    measureType = "percent"
    validateValue = @(v) 100.0 * v
  }
  TANK_RESPAWN_COST = {
    measureType = "percent"
    validateValue = @(v) 100.0 * v
    isInverted = true
    canShowForUnit = @(unit) ::has_feature("TankModEffect")
    getText = function (unit, effects, modeId)
    {
      if (!canShowForUnit(unit))
        return ""
      local value = getValue(unit, effects, modeId)
      local value2 = effects?[modeId]?[id+"_base"]
      if (value2 != null)
        value2 = validateValue(value2)
      if (value != null && value2 != null)
        return ::loc(getLocId(unit, effects),
                  {
                    valueWithMod = valueToString(value),
                    valueWithoutMod = valueToString(value2)
                  })
      return ""
    }
  }
}

local effectTypeTemplate = {
  id = ""
  measureType = ""
  presize = 1
  shouldColorByValue = true
  isInverted = false //when isInverted, negative values are better than positive
  preset = null //set of parameter to override on type creation

  getLocId = @(unit, effects) "modification/" + id + "_change"
  validateValue = @(value) value  //return null if no need to show effect
  canShowForUnit = @(unit) true

  valueToString = function(value)
  {
    local isNumeric = ::is_numeric(value)
    local res = ""
    if (!::u.isString(measureType))
      res = countMeasure(measureType, isNumeric ? value : 0.0)
    else
      res = (isNumeric ? string.roundedFloatToString(::round_by_value(value, presize), presize) : value)
        + (measureType.len() ? ::loc("measureUnits/" + measureType) : "")
    if (!isNumeric)
      return res

    if (value > 0)
      res = "+" + res
    if (value != 0)
      res = ::colorize(
        !shouldColorByValue ? NEUTRAL_COLOR
          : (value < 0 == isInverted) ? GOOD_COLOR
          : BAD_COLOR,
        res)
    return res
  }

  getValue = function(unit, effects, modeId)
  {
    local value = effects?[modeId]?[id] ?? effects?[id]
    if (value == null)
      return value
    value = validateValue(value)
    if (value == null)
      return value
    return ::fabs(value / presize) > 0.5 ? value : null
  }

  getText = function(unit, effects, modeId)
  {
    if (!canShowForUnit(unit))
      return ""
    local value = getValue(unit, effects, modeId)
    if (value != null)
      return ::format(::loc(getLocId(unit, effects)), valueToString(value))
    return ""
  }
}

local function effectTypeConstructor()
{
  if (preset in presetsList)
    foreach(key, value in presetsList[preset])
      this[key] <- value
}


/**************************************** USUAL EFFECTS ******************************************************/

local effectsType = {
  types = []
  template = effectTypeTemplate
}

enums.addTypes(effectsType, [
  { id = "armor",                  measureType = "percent" }
  { id = "cutProbability",         measureType = "percent" }
  { id = "overheadCooldown",       measureType = "percent", isInverted = true }
  { id = "mass",                   measureType = "kg", isInverted = true, presize = 0.1
    validateValue = @(value) ::fabs(value) > 0.5 ? value : null
  }
  { id = "oswalds",                measureType = "percent", presize = 0.001 }
  { id = "cdMinFusel",             measureType = "", isInverted = true, presize = 0.00001 }
  { id = "cdMinTail",              measureType = "", isInverted = true, presize = 0.00001 }
  { id = "cdMinWing",              measureType = "", isInverted = true, presize = 0.00001 }

  { id = "ailThrSpd",              preset = "SPEED" }
  { id = "ruddThrSpd",             preset = "SPEED" }
  { id = "elevThrSpd",             preset = "SPEED" }

  { id = "horsePowers",             measureType = "hp", presize = 0.1
    canShowForUnit = @(unit) !isTank(unit) || ::has_feature("TankModEffect")
    getLocId = function(unit, effects) {
      local key = effects?.modifName == "new_tank_transmission" ? "horsePowersTransmission" : "horsePowers"
      return "modification/" + key + "_change"
    }
  }
  { id = "thrust",                 measureType = "kgf", presize = 0.1
    validateValue = @(value) value / KGF_TO_NEWTON
  }
  { id = "cdParasite",             measureType = "kgf", isInverted = true, presize = 0.00001 }
  { id = "speed",                  preset = "SPEED" }
  { id = "climb",                  preset = "CLIMB_SPEED" }
  { id = "roll",                   measureType = "deg_per_sec", presize = 0.1 }
  { id = "virage",                 measureType = "seconds", isInverted = true, presize = 0.1
    validateValue = @(value) fabs(value) < 20.0 ? value : null
  }
  { id = "blackoutG",              measureType = "", presize = 0.01 }
  { id = "redoutG",                measureType = "", presize = 0.01, isInverted = true }

  /****************************** TANK EFFECTS ***********************************************/
  { id = "turnTurretSpeedK",       preset = "PERCENT_FLOAT"
    canShowForUnit = @(unit) ::has_feature("TankModEffect")
  }
  { id = "gunPitchSpeedK",         preset = "PERCENT_FLOAT"
    canShowForUnit = @(unit) ::has_feature("TankModEffect")
  }
  { id = "maxInclination",         measureType = "deg"
    canShowForUnit = @(unit) ::has_feature("TankModEffect")
    validateValue = @(value) value * 180.0 / PI
  }
  { id = "maxDeltaAngleK",         preset = "PERCENT_FLOAT", isInverted = true
    canShowForUnit = @(unit) ::has_feature("TankModEffect")
  }
  { id = "maxDeltaAngleVerticalK", preset = "PERCENT_FLOAT", isInverted = true
    canShowForUnit = @(unit) ::has_feature("TankModEffect")
  }
  { id = "maxBrakeForceK",         preset = "PERCENT_FLOAT"
    canShowForUnit = @(unit) ::has_feature("TankModEffect")
  }
  { id = "suspensionDampeningForceK", preset = "PERCENT_FLOAT"
    canShowForUnit = @(unit) ::has_feature("TankModEffect")
  }
  { id = "timeToBrake",            measureType = "seconds", isInverted = true, presize = 0.1
    canShowForUnit = @(unit) ::has_feature("TankModEffect")
  }
  { id = "distToBrake",            measureType = MEASURE_UNIT_ALT, isInverted = true, presize = 0.1
    canShowForUnit = @(unit) ::has_feature("TankModEffect")
  }
  { id = "accelTime",              measureType = "seconds", isInverted = true, presize = 0.1
    canShowForUnit = @(unit) ::has_feature("TankModEffect")
  }
  { id = "partHpMult",             preset = "PERCENT_FLOAT"
    canShowForUnit = @(unit) ::has_feature("TankModEffect")
  }
  { id = "viewDist",               preset = "PERCENT_FLOAT"
    canShowForUnit = @(unit) ::has_feature("TankModEffect")
  }
  { id = "respawnCost_killScore_exp_fighter",  preset = "TANK_RESPAWN_COST" }
  { id = "respawnCost_killScore_exp_assault", preset = "TANK_RESPAWN_COST"  }
  { id = "respawnCost_killScore_exp_bomber",  preset = "TANK_RESPAWN_COST"  }
  { id = "respawnCost_hitScore_exp_fighter",  preset = "TANK_RESPAWN_COST"  }
  { id = "respawnCost_hitScore_exp_assault",  preset = "TANK_RESPAWN_COST"  }
  { id = "respawnCost_hitScore_exp_bomber",   preset = "TANK_RESPAWN_COST"  }
  { id = "respawnCost_scoutScore_exp_fighter", preset = "TANK_RESPAWN_COST"  }
  { id = "respawnCost_scoutScore_exp_assault", preset = "TANK_RESPAWN_COST"  }
  { id = "respawnCost_scoutScore_exp_bomber",  preset = "TANK_RESPAWN_COST"  }
  { id = "respawnCost_killScore_aircrafts",  preset = "TANK_RESPAWN_COST"  }
  { id = "respawnCost_hitScore_aircrafts",  preset = "TANK_RESPAWN_COST"  }
  { id = "respawnCost_scoutScore_aircrafts", preset = "TANK_RESPAWN_COST"  }

  /****************************** SHIP EFFECTS ***********************************************/
  { id = "waterMassVelTime",       measureType = "hours", isInverted = true, presize = 0.1
    canShowForUnit = @(unit) ::has_feature("Ships")
  }
  { id = "speedYawK",              preset = "PERCENT_FLOAT"
    canShowForUnit = @(unit) ::has_feature("Ships")
  }
  { id = "speedPitchK",            preset = "PERCENT_FLOAT"
    canShowForUnit = @(unit) ::has_feature("Ships")
  }
  { id = "shipDistancePrecision",  preset = "PERCENT_FLOAT"
    canShowForUnit = @(unit) ::has_feature("Ships")
  }
  { id = "turnRadius",             preset = "PERCENT_FLOAT", isInverted = true
    canShowForUnit = @(unit) ::has_feature("Ships")
  }
  { id = "turnTime",               preset = "PERCENT_FLOAT", isInverted = true
    canShowForUnit = @(unit) ::has_feature("Ships")
  }
  { id = "distToLiveTorpedo",      measureType = "meters_alt", shouldColorByValue = false
    canShowForUnit = @(unit) ::has_feature("Ships")
  }
  { id = "maxSpeedInWaterTorpedo", measureType = "metersPerSecond_climbSpeed", shouldColorByValue = false
    canShowForUnit = @(unit) ::has_feature("Ships")
  }
  { id = "diveDepthTorpedo",       measureType = "meters_alt", shouldColorByValue = false
    canShowForUnit = @(unit) ::has_feature("Ships")
  }
  { id = "speedShip",              preset = "SPEED"
    canShowForUnit = @(unit) ::has_feature("Ships")
  }
  { id = "reverseSpeed",           preset = "SPEED"
    canShowForUnit = @(unit) ::has_feature("Ships")
  }
  { id = "timeToMaxSpeed",         measureType = "seconds", isInverted = true
    canShowForUnit = @(unit) ::has_feature("Ships")
  }
  { id = "timeToMaxReverseSpeed",  measureType = "seconds", isInverted = true
    canShowForUnit = @(unit) ::has_feature("Ships")
  }
],
effectTypeConstructor)


/**************************************** WEAPONS EFFECTS ******************************************************/

local weaponEffectsType = {
  types = []
  template = effectTypeTemplate
}

enums.addTypes(weaponEffectsType, [
  { id = "spread",                 measureType = MEASURE_UNIT_ALT, isInverted = true }
  { id = "overheat",               preset = "PERCENT_FLOAT" }
],
effectTypeConstructor)


/**************************************** FULL DESC GENERATION ******************************************************/

local startTab = ::nbsp + ::nbsp + ::nbsp + ::nbsp
local getEffectsStackFunc = function(unit, effectsConfig, modeId)
{
  return function(eType, res) {
    local text = eType.getText(unit, effectsConfig, modeId)
    if (text.len())
      res += "\n" + startTab + text
    return res
  }
}

local function getDesc(unit, effects)
{
  local res = ""
  local modeId = ::get_current_shop_difficulty().crewSkillName

  local desc = ::u.reduce(effectsType.types, getEffectsStackFunc(unit, effects, modeId), "")
  if (desc != "")
    res = "\n" + ::loc("modifications/specs_change") + ::loc("ui/colon") + desc

  if ("weaponMods" in effects)
    foreach(w in effects.weaponMods)
    {
      desc = ::u.reduce(weaponEffectsType.types, getEffectsStackFunc(unit, w, modeId), "")
      if (desc.len())
        res += "\n" + ::loc(w.name) + ::loc("ui/colon") + desc
    }

  if(res != "")
    res += "\n" + "<color=@fadedTextColor>" + ::loc("weaponry/modsEffectsNotification") + "</color>"
  return res
}

return {
  getDesc = getDesc //(unit, effects)  //eefects - is effects table generated by calculate_mod_or_weapon_effect
}