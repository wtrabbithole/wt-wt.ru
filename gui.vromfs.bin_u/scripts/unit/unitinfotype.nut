local enums = ::require("sqStdlibs/helpers/enums.nut")
local time = require("scripts/time.nut")
local stdMath = require("std/math.nut")
local { getUnitRole, getUnitBasicRole, getRoleText, getUnitTooltipImage,
  getFullUnitRoleText, getShipMaterialTexts } = require("scripts/unit/unitInfoTexts.nut")
local { countMeasure } = ::require("scripts/options/optionsMeasureUnits.nut")


local UNIT_INFO_ARMY_TYPE  = {
  AIR        = ::g_unit_type.AIRCRAFT.bit
  TANK       = ::g_unit_type.TANK.bit
  SHIP       = ::g_unit_type.SHIP.bit
  HELICOPTER = ::g_unit_type.HELICOPTER.bit

  AIR_TANK   = ::g_unit_type.AIRCRAFT.bit | ::g_unit_type.TANK.bit
  ALL        = ::g_unit_type.AIRCRAFT.bit | ::g_unit_type.TANK.bit
               | ::g_unit_type.SHIP.bit | ::g_unit_type.HELICOPTER.bit
}
enum UNIT_INFO_ORDER{
  TRAIN_COST = 0,
  FREE_REPAIRS,
  FULL_REPAIR_COST,
  FULL_REPAIR_TIME_CREW,
  MAX_SPEED,
  MAX_SPEED_ALT,
  MAX_ALTITUDE,
  TURN_TIME,
  CLIMB_SPEED,
  AIRFIELD_LEN,
  WEAPON_PRESETS,
  MASS_PER_SEC,
  MASS,
  HORSE_POWERS,
  MAX_SPEED_TANK,
  MAX_INCLINATION,
  TURN_TURRET_SPEED,
  MIN_ANGLE_VERTICAL_GUIDANCE,
  MAX_ANGLE_VERTICAL_GUIDANCE,
  ARMOR_THICKNESS_HULL_FRONT,
  ARMOR_THICKNESS_HULL_REAR,
  ARMOR_THICKNESS_HULL_BACK,
  ARMOR_THICKNESS_TURRET_FRONT,
  ARMOR_THICKNESS_TURRET_REAR,
  ARMOR_THICKNESS_TURRET_BACK,
  ARMOR_PIERCING_100,
  ARMOR_PIERCING_500,
  ARMOR_PIERCING_1000,
  SHOT_FREQ,
  RELOAD_TIME,
  VISIBILITY,
  WEAPON_PRESET_TANK,
  SHIP_SPEED,
  DISPLACEMENT,
  ARMOR_THICKNESS_CITADEL_FRONT,
  ARMOR_THICKNESS_CITADEL_REAR,
  ARMOR_THICKNESS_CITADEL_BACK,
  ARMOR_THICKNESS_TOWER_FRONT,
  ARMOR_THICKNESS_TOWER_REAR,
  ARMOR_THICKNESS_TOWER_BACK,
  HULL_MATERIAL,
  SUPERSTRUCTURE_MATERIAL,
  WEAPON_INFO_TEXT
}
const COMPARE_MORE_BETTER = "more"
const COMPARE_LESS_BETTER = "less"
const COMPARE_NO_COMPARE = "no"

::g_unit_info_type <- {
  types = []
}

::g_unit_info_type.template <- {
  id = ""
  infoArmyType = UNIT_INFO_ARMY_TYPE.ALL
  headerLocId = null
  getValue = function(unit)            { return null }
  getValueText = function(value, unit)
  {
    if (value == null)
      return null
    return ::u.isString(value) ? value : ::toString(value)
  }
  compare = COMPARE_NO_COMPARE
  order = -1
  addToExportTankDataBlock = function(blk, unit)
  {
    blk.value = ::DataBlock()
    blk.valueText = ::DataBlock()
    foreach(diff in ::g_difficulty.types)
      if (diff.egdCode != ::EGD_NONE)
      {
        local mode = diff.getEgdName()
        local currentParams = unit.modificators[diff.crewSkillName];
        addToExportTankDataBlockValues(blk, currentParams, mode)
      }
  }

  addToExportTankDataBlockValues = function(blk, params, mode){}

  exportToDataBlock = function(unit)
  {
    local blk = ::DataBlock()
    if (!(unit.unitType.bit & infoArmyType))
    {
        blk.hide = true
        return blk
    }
    local value = getValue(unit)
    if (value != null)
      blk.value = value
    local valueText = getValueText(value, unit)
    if (valueText != null)
      blk.valueText = valueText
    addToExportDataBlock(blk, unit)
    return blk
  }

  exportCommonToDataBlock = function()
  {
    local blk = ::DataBlock()

    if (headerLocId)
      blk.header = ::loc(headerLocId)

    blk.compare = compare
    blk.order = order
    return blk
  }

  addToExportDataBlock = function(blk, unit) {} //for unique data to export.
  addToBlkFromParams = function(blk,unit, item)
  {
    blk.value = ::DataBlock()
    blk.valueText = ::DataBlock()
    foreach(diff in ::g_difficulty.types)
      if (diff.egdCode != ::EGD_NONE)
      {
        local mode = diff.getEgdName()
        local characteristicArr = ::getCharacteristicActualValue(unit, [item.id, item.id2], function(value){return ""}, diff.crewSkillName, false)
        blk.value[mode] = characteristicArr[2]
        blk.valueText[mode] = item.prepareTextFunc(characteristicArr[2])
      }
  }

  addSingleValue = function(blk, unit, value, valueText)
  {
    blk.value = ::DataBlock()
    blk.valueText = ::DataBlock()
    foreach(diff in ::g_difficulty.types)
      if (diff.egdCode != ::EGD_NONE)
      {
        local mode = diff.getEgdName()
        blk.value[mode] = value
        blk.valueText[mode] = valueText
      }
  }
}

enums.addTypesByGlobalName("g_unit_info_type", [
  {
    id = "name"
    getValueText = function(value, unit) { return ::getUnitName(unit) }
  }
  {
    id = "image"
    addToExportDataBlock = function(blk, unit)
    {
      blk.image = getUnitTooltipImage(unit)
      blk.cardImage = ::image_for_air(unit)
      blk.icon = ::getUnitClassIco(unit)
      blk.iconColor = ::get_main_gui_scene().getConstantValue(::getUnitClassColor(unit)) || ""
    }
  }

  {
    id = "role"
    infoArmyType = UNIT_INFO_ARMY_TYPE.AIR_TANK
    addToExportDataBlock = function(blk, unit)
    {
        blk.stringValue = getUnitRole(unit)
    }
    getValueText = function(value, unit) { return getFullUnitRoleText(unit) }
  }

  {
    id = "role"
    infoArmyType = UNIT_INFO_ARMY_TYPE.SHIP
    addToExportDataBlock = function(blk, unit)
    {
        blk.stringValue = getUnitBasicRole(unit)
    }
    getValueText = function(value, unit) { return getRoleText(getUnitBasicRole(unit)) }
  }

  {
    id = "tags"
    addToExportDataBlock = function(blk, unit)
    {
      foreach (t in unit.tags)
        blk.tag <- t
    }
  }
/*  {
    id = "description"
    getValueText = function(value, unit)
    {
      return ::loc(format("encyclopedia/%s/desc", unit.name))
    }
  }*/
  {
    id = "battle_rating"
    headerLocId = "shop/battle_rating"
    addToExportDataBlock = function(blk, unit)
    {
      blk.value = ::DataBlock()
      blk.valueText = ::DataBlock()
      foreach(diff in ::g_difficulty.types)
        if (diff.egdCode != ::EGD_NONE)
        {
          local mode = diff.getEgdName()
          blk.value[mode] = unit.getBattleRating(diff.getEdiff())
          blk.valueText[mode] = format("%.1f", blk.value[mode])
        }
    }
  }
  {
    id = "price"
    headerLocId = "ugm/price"
    addToExportDataBlock = function(blk, unit)
    {
      local valueText = ::getUnitCost(unit).getUncoloredText()
      if(valueText == "")
      {
          blk.hide = true
          return
      }
      blk.valueText = ::DataBlock()
      foreach(diff in ::g_difficulty.types)
        if (diff.egdCode != ::EGD_NONE)
          blk.valueText[diff.getEgdName()] = valueText

      local cost = ::getUnitCost(unit)
      blk.wp = cost.wp
      blk.gold = cost.gold
    }
  }
  {
    id = "wp_bonus"
    getHeader = function(unit)
    {
      return ::loc("reward") + ::loc("ui/parentheses/space", { text = ::loc("charServer/chapter/warpoints") }) + ":"
    }
    addToExportDataBlock = function(blk, unit)
    {
      blk.value = ::DataBlock()
      blk.valueText = ::DataBlock()
      foreach(diff in ::g_difficulty.types)
        if (diff.egdCode != ::EGD_NONE)
        {
          local mode = diff.getEgdName()
          local wpMuls = unit.getWpRewardMulList(diff)
          local value = (wpMuls.wpMul * wpMuls.premMul * 100.0 + 0.5).tointeger()
          blk.value[mode] = value
          blk.valueText[mode] = ::format("%d%%", value)
        }
    }
  }
  {
    id = "exp_bonus"
    getHeader = function(unit)
    {
      return ::loc("reward") + ::loc("ui/parentheses/space", { text = ::loc("currency/researchPoints/name") }) + ":"
    }
    addToExportDataBlock = function(blk, unit)
    {
      local talismanMul = isUnitSpecial(unit) ? (::get_ranks_blk()?.goldPlaneExpMul ?? 1.0) : 1.0
      local value = (unit.expMul * talismanMul * 100.0 + 0.5).tointeger()
      if (value == 100)
      {
        blk.hide = true
        return
      }
      local valueText = ::format("%d%%", value)
      blk.value = ::DataBlock()
      blk.valueText = ::DataBlock()
      foreach(diff in ::g_difficulty.types)
        if (diff.egdCode != ::EGD_NONE)
        {
          local mode = diff.getEgdName()
          blk.value[mode] = value
          blk.valueText[mode] = valueText
        }
    }
  }

  {
    id = "train_cost"
    compare = COMPARE_LESS_BETTER
    order = UNIT_INFO_ORDER.FREE_REPAIRS
    headerLocId = "shop/crew_train_cost"
    addToExportDataBlock = function(blk, unit)
    {
      local value = unit.trainCost
      if (value == 0)
      {
        blk.hide = true
        return
      }
      local valueText = ::Cost(value).getUncoloredText()
      blk.value = ::DataBlock()
      blk.valueText = ::DataBlock()
      foreach(diff in ::g_difficulty.types)
        if (diff.egdCode != ::EGD_NONE)
        {
          local mode = diff.getEgdName()
          blk.value[mode] = value
          blk.valueText[mode] = valueText
        }
    }
  }
  {
    id = "full_repair_cost"
    order = UNIT_INFO_ORDER.FULL_REPAIR_COST
    compare = COMPARE_LESS_BETTER
    headerLocId = "shop/full_repair_cost"
    addToExportDataBlock = function(blk, unit)
    {
      blk.value = ::DataBlock()
      blk.valueText = ::DataBlock()
      foreach(diff in ::g_difficulty.types)
        if (diff.egdCode != ::EGD_NONE)
        {
          local mode = diff.getEgdName()
          local field = "repairCost" + mode
          local value = ::get_wpcost_blk()?[unit.name]?[field] ?? 0
          value =  value * (::get_warpoints_blk()?.avgRepairMul ?? 1.0) //avgRepairMul same as in tooltip
          blk.value[mode] = value
          blk.valueText[mode] = value ? ::Cost(value).getUncoloredText() : ::loc("shop/free")
        }
    }
  }
  {
    id = "free_repairs"
    order = UNIT_INFO_ORDER.FREE_REPAIRS
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/free_repairs"
    addToExportDataBlock = function(blk, unit)
    {
      if(::is_default_aircraft(unit.name))
      {
        blk.hide = true
        return
      }
      local value = ::getTblValue("freeRepairs", unit)
      local valueText = ::toString(value)
      blk.value = ::DataBlock()
      blk.valueText = ::DataBlock()
      foreach(diff in ::g_difficulty.types)
        if (diff.egdCode != ::EGD_NONE)
        {
          local mode = diff.getEgdName()
          blk.value[mode] = value
          blk.valueText[mode] = valueText
        }
    }
  }
  {
    id = "full_repair_time_crew"
    order = UNIT_INFO_ORDER.FULL_REPAIR_TIME_CREW
    compare = COMPARE_LESS_BETTER
    headerLocId = "shop/full_repair_time"
    addToExportDataBlock = function(blk, unit)
    {
      blk.value = ::DataBlock()
      blk.valueText = ::DataBlock()
      foreach(diff in ::g_difficulty.types)
        if (diff.egdCode != ::EGD_NONE)
        {
          local mode = diff.getEgdName()
          local field = "repairTimeHrs" + mode
          local value = ::get_wpcost_blk()?[unit.name]?[field] ?? 0.0
          if(value == 0.0)
          {
            blk.hide = true
            return
          }
          blk.value[mode] = value
          blk.valueText[mode] = time.hoursToString(value, false)
        }
    }
  }
  {
    id = "weapon_info_text"
    order = UNIT_INFO_ORDER.WEAPON_INFO_TEXT
    getValueText = function(value, unit)
    {
      local valueText = ::DataBlock()
      foreach(diff in ::g_difficulty.types)
        if (diff.egdCode != ::EGD_NONE)
          valueText[diff.getEgdName()] = ::getWeaponInfoText(unit.name)
      return valueText
    }
  }
  {
    id = "max_speed"
    order = UNIT_INFO_ORDER.MAX_SPEED
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/max_speed"
    infoArmyType = UNIT_INFO_ARMY_TYPE.AIR
    addToExportDataBlock = function(blk, unit)
    {
      local item = {id = "maxSpeed", id2 = "speed", prepareTextFunc = @(value) countMeasure(0, value)}
      addToBlkFromParams(blk, unit, item)
    }
  }
  {
    id = "max_speed_alt"
    order = UNIT_INFO_ORDER.MAX_SPEED_ALT
    headerLocId = "shop/max_speed_alt"
    infoArmyType = UNIT_INFO_ARMY_TYPE.AIR
    getValueText = function(value, unit)
    {
      local valueText = ::DataBlock()
      foreach(diff in ::g_difficulty.types)
        if (diff.egdCode != ::EGD_NONE)
          valueText[diff.getEgdName()] = countMeasure(1, unit.shop.maxSpeedAlt)
      return valueText
    }
  }
  {
    id = "turn_time"
    order = UNIT_INFO_ORDER.TURN_TIME
    compare = COMPARE_LESS_BETTER
    headerLocId = "shop/turn_time"
    infoArmyType = UNIT_INFO_ARMY_TYPE.AIR
    addToExportDataBlock = function(blk, unit)
    {
      local item = {id = "turnTime", id2 = "virage", prepareTextFunc = function(value){return format("%.1f %s", value, ::loc("measureUnits/seconds"))}}
      addToBlkFromParams(blk, unit, item)
    }
  }
  {
    id = "climb_speed"
    order = UNIT_INFO_ORDER.CLIMB_SPEED
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/max_climbSpeed"
    infoArmyType = UNIT_INFO_ARMY_TYPE.AIR

    addToExportDataBlock = function(blk, unit)
    {
      local item = {id = "climbSpeed", id2 = "climb", prepareTextFunc = @(value) countMeasure(3, value)}
      addToBlkFromParams(blk, unit, item)
    }
  }
  {
    id = "max_altitude"
    order = UNIT_INFO_ORDER.MAX_ALTITUDE
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/max_altitude"
    infoArmyType = UNIT_INFO_ARMY_TYPE.AIR

    addToExportDataBlock = function(blk, unit)
    {
      local value = unit.shop.maxAltitude
      local valueText = countMeasure(1, value)
      addSingleValue(blk, unit, value, valueText)
    }
  }
  {
    id = "airfield_len"
    order = UNIT_INFO_ORDER.AIRFIELD_LEN
    compare = COMPARE_LESS_BETTER
    headerLocId = "shop/airfieldLen"
    infoArmyType = UNIT_INFO_ARMY_TYPE.AIR

    addToExportDataBlock = function(blk, unit)
    {
      local value = unit.shop.airfieldLen
      local valueText = countMeasure(1, value)
      addSingleValue(blk, unit, value, valueText)
    }
  }
  {
    id = "weapon_presets"
    order = UNIT_INFO_ORDER.WEAPON_PRESETS
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/weaponPresets"
    infoArmyType = UNIT_INFO_ARMY_TYPE.AIR
    addToExportDataBlock = function(blk, unit)
    {
      local value = 0
      if (unit.weapons.len() > 0)
      {
        foreach(idx, weapon in unit.weapons)
        {
          if (::isWeaponAux(weapon))
            continue
          value++
        }
      }
      local valueText = value.tostring()
      addSingleValue(blk, unit, value, valueText)
    }
  }
  {
    id = "mass_per_sec"
    order = UNIT_INFO_ORDER.MASS_PER_SEC
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/massPerSec"
    infoArmyType = UNIT_INFO_ARMY_TYPE.AIR
    addToExportDataBlock = function(blk, unit)
    {
      local lastPrimaryWeaponName = ::get_last_primary_weapon(unit)
      local lastPrimaryWeapon = ::getModificationByName(unit, lastPrimaryWeaponName)
      local massPerSecValue = ::getTblValue("mass_per_sec_diff", lastPrimaryWeapon, 0)

      local weaponIndex = -1
      if (unit.weapons.len() > 0)
      {
        local lastWeapon = ::get_last_weapon(unit.name)
        weaponIndex = 0
        foreach(idx, weapon in unit.weapons)
        {
          if (::isWeaponAux(weapon))
            continue
          if (lastWeapon == weapon.name && "mass_per_sec" in weapon)
            weaponIndex = idx
        }
      }
      if (weaponIndex != -1)
      {
        local weapon = unit.weapons[weaponIndex]
        massPerSecValue += ::getTblValue("mass_per_sec", weapon, 0)
      }
      local valueText = massPerSecValue == 0? "" : format("%.2f %s", massPerSecValue, ::loc("measureUnits/kgPerSec"))
      addSingleValue(blk, unit, massPerSecValue, valueText)
    }
  }
  {
    id = "mass"
    order = UNIT_INFO_ORDER.MASS
    compare = COMPARE_LESS_BETTER
    headerLocId = "shop/tank_mass"
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportDataBlock = function(blk, unit)
    {
      local item = {id = "mass", id2 = "mass", prepareTextFunc = function(value){return format("%.1f %s", (value / 1000.0), ::loc("measureUnits/ton"))}}
      addToBlkFromParams(blk, unit, item)
    }
  }
  {
    id = "horse_powers"
    order = UNIT_INFO_ORDER.HORSE_POWERS
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/horsePowers"
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportTankDataBlockValues = function(blk, params, mode)
    {
        local horsePowers = params.horsePowers;
        local horsePowersRPM = params.maxHorsePowersRPM;

        blk.value[mode] = horsePowers
        blk.valueText[mode] = ::format("%s %s %d %s",
          ::g_measure_type.HORSEPOWERS.getMeasureUnitsText(horsePowers),
          ::loc("shop/unitValidCondition"), horsePowersRPM.tointeger(), ::loc("measureUnits/rpm"))
    }

    addToExportDataBlock = function(blk, unit)
    {
      addToExportTankDataBlock(blk, unit)
    }
  }
  {
    id = "max_speed_tank"
    order = UNIT_INFO_ORDER.MAX_SPEED_TANK
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/max_speed"
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportDataBlock = function(blk, unit)
    {
      local item = {id = "maxSpeed", id2 = "maxSpeed", prepareTextFunc = @(value) countMeasure(0, value)}
      addToBlkFromParams(blk, unit, item)
    }
  }
  {
    id = "max_inclination"
    order = UNIT_INFO_ORDER.MAX_INCLINATION
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/max_inclination"
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportDataBlock = function(blk, unit)
    {
      local item = {id = "maxInclination", id2 = "maxInclination", prepareTextFunc = function(value){return format("%d%s", (value*180.0/PI).tointeger(), ::loc("measureUnits/deg"))}}
      addToBlkFromParams(blk, unit, item)
    }
  }
  {
    id = "turn_turret_speed"
    order = UNIT_INFO_ORDER.TURN_TURRET_SPEED
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/turnTurretTime"
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportDataBlock = function(blk, unit)
    {
      local item = {id = "turnTurretTime", id2 = "turnTurretSpeed", prepareTextFunc = function(value){return format("%.1f%s", value.tofloat(), ::loc("measureUnits/deg_per_sec"))}}
      addToBlkFromParams(blk, unit, item)
    }
  }
  {
    id = "min_angle_vertical_guidance"
    order = UNIT_INFO_ORDER.MIN_ANGLE_VERTICAL_GUIDANCE
    compare = COMPARE_LESS_BETTER
    headerLocId = "shop/angleVerticalGuidance"
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportTankDataBlockValues = function(blk, params, mode)
    {
      local angles = params.angleVerticalGuidance;
      blk.value[mode] = angles[0].tointeger()
      blk.valueText[mode] = format("%d%s", angles[0].tointeger(), ::loc("measureUnits/deg"))
    }
    addToExportDataBlock = function(blk, unit)
    {
      addToExportTankDataBlock(blk, unit)
    }
  }
  {
    id = "max_angle_vertical_guidance"
    order = UNIT_INFO_ORDER.MAX_ANGLE_VERTICAL_GUIDANCE
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/angleVerticalGuidance"
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportTankDataBlockValues = function(blk, params, mode)
    {
      local angles = params.angleVerticalGuidance;
      blk.value[mode] = angles[1].tointeger()
      blk.valueText[mode] = format("%d%s", angles[1].tointeger(), ::loc("measureUnits/deg"))
    }
    addToExportDataBlock = function(blk, unit)
    {
      addToExportTankDataBlock(blk, unit)
    }
  }
  {
    id = "armor_thickness_hull_front"
    order = UNIT_INFO_ORDER.ARMOR_THICKNESS_HULL_FRONT
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/armorThicknessHull"
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportTankDataBlockValues = function(blk, params, mode)
    {
      local thickness = params.armorThicknessHull;
      blk.value[mode] = thickness[0].tointeger()
      blk.valueText[mode] = format("%d %s", thickness[0].tointeger(), ::loc("measureUnits/mm"))
    }
    addToExportDataBlock = function(blk, unit)
    {
      addToExportTankDataBlock(blk, unit)
    }
  }
  {
    id = "armor_thickness_hull_rear"
    order = UNIT_INFO_ORDER.ARMOR_THICKNESS_HULL_REAR
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/armorThicknessHull"
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportTankDataBlockValues = function(blk, params, mode)
    {
      local thickness = params.armorThicknessHull;
      blk.value[mode] = thickness[1].tointeger()
      blk.valueText[mode] = format("%d %s", thickness[1].tointeger(), ::loc("measureUnits/mm"))
    }
    addToExportDataBlock = function(blk, unit)
    {
      addToExportTankDataBlock(blk, unit)
    }
  }
  {
    id = "armor_thickness_hull_back"
    order = UNIT_INFO_ORDER.ARMOR_THICKNESS_HULL_BACK
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/armorThicknessHull"
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportTankDataBlockValues = function(blk, params, mode)
    {
      local thickness = params.armorThicknessHull;
      blk.value[mode] = thickness[2].tointeger()
      blk.valueText[mode] = format("%d %s", thickness[2].tointeger(), ::loc("measureUnits/mm"))
    }
    addToExportDataBlock = function(blk, unit)
    {
      addToExportTankDataBlock(blk, unit)
    }
  }
  {
    id = "armor_thickness_turret_front"
    order = UNIT_INFO_ORDER.ARMOR_THICKNESS_TURRET_FRONT
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/armorThicknessTurret"
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportTankDataBlockValues = function(blk, params, mode)
    {
      local thickness = params.armorThicknessTurret;
      blk.value[mode] = thickness[0].tointeger()
      blk.valueText[mode] = format("%d %s", thickness[0].tointeger(), ::loc("measureUnits/mm"))
    }
    addToExportDataBlock = function(blk, unit)
    {
      addToExportTankDataBlock(blk, unit)
    }
  }
  {
    id = "armor_thickness_turret_rear"
    order = UNIT_INFO_ORDER.ARMOR_THICKNESS_TURRET_REAR
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/armorThicknessTurret"
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportTankDataBlockValues = function(blk, params, mode)
    {
      local thickness = params.armorThicknessTurret;
      blk.value[mode] = thickness[1].tointeger()
      blk.valueText[mode] = format("%d %s", thickness[1].tointeger(), ::loc("measureUnits/mm"))
    }
    addToExportDataBlock = function(blk, unit)
    {
      addToExportTankDataBlock(blk, unit)
    }
  }
  {
    id = "armor_thickness_turret_back"
    order = UNIT_INFO_ORDER.ARMOR_THICKNESS_TURRET_BACK
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/armorThicknessTurret"
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportTankDataBlockValues = function(blk, params, mode)
    {
      local thickness = params.armorThicknessTurret;
      blk.value[mode] = thickness[2].tointeger()
      blk.valueText[mode] = format("%d %s", thickness[2].tointeger(), ::loc("measureUnits/mm"))
    }
    addToExportDataBlock = function(blk, unit)
    {
      addToExportTankDataBlock(blk, unit)
    }
  }
  {
    id = "armor_piercing_100"
    order = UNIT_INFO_ORDER.ARMOR_PIERCING_100
    compare = COMPARE_MORE_BETTER
    getHeader = function(unit)
    {
      return ::format("%s (%s 100 %s)", ::loc("shop/armorPiercing"), ::loc("shop/armorPiercingDist"), ::loc("measureUnits/meters_alt"))
    }
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportTankDataBlockValues = function(blk, params, mode)
    {
      if(blk.hide)
        return
      local armorPiercing = params.armorPiercing;
      if(armorPiercing.len() > 2)
      {
        local val = stdMath.round(armorPiercing[0]).tointeger()
        blk.value[mode] = val
        blk.valueText[mode] = format("%d %s", val, ::loc("measureUnits/mm"))
      }
      else
      {
        blk.hide = true
      }
    }
    addToExportDataBlock = function(blk, unit)
    {
      addToExportTankDataBlock(blk, unit)
    }
  }
  {
    id = "armor_piercing_500"
    order = UNIT_INFO_ORDER.ARMOR_PIERCING_500
    compare = COMPARE_MORE_BETTER
    getHeader = function(unit)
    {
      return ::format("%s (%s 500 %s)", ::loc("shop/armorPiercing"), ::loc("shop/armorPiercingDist"), ::loc("measureUnits/meters_alt"))
    }
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportTankDataBlockValues = function(blk, params, mode)
    {
      if(blk.hide)
        return
      local armorPiercing = params.armorPiercing;
      if(armorPiercing.len() > 2)
      {
        local val = stdMath.round(armorPiercing[1]).tointeger()
        blk.value[mode] = val
        blk.valueText[mode] = format("%d %s", val, ::loc("measureUnits/mm"))
      }
      else
      {
        blk.hide = true
      }
    }
    addToExportDataBlock = function(blk, unit)
    {
      addToExportTankDataBlock(blk, unit)
    }
  }
  {
    id = "armor_piercing_1000"
    order = UNIT_INFO_ORDER.ARMOR_PIERCING_1000
    compare = COMPARE_MORE_BETTER
    getHeader = function(unit)
    {
      return ::format("%s (%s 1000 %s)", ::loc("shop/armorPiercing"), ::loc("shop/armorPiercingDist"), ::loc("measureUnits/meters_alt"))
    }

    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportTankDataBlockValues = function(blk, params, mode)
    {
      if(blk.hide)
        return
      local armorPiercing = params.armorPiercing;
      if(armorPiercing.len() > 2)
      {
        local val = stdMath.round(armorPiercing[2]).tointeger()
        blk.value[mode] = val
        blk.valueText[mode] = format("%d %s", val, ::loc("measureUnits/mm"))
      }
      else
      {
        blk.hide = true
      }
    }
    addToExportDataBlock = function(blk, unit)
    {
      addToExportTankDataBlock(blk, unit)
    }
  }
  {
    id = "shot_freq"
    order = UNIT_INFO_ORDER.SHOT_FREQ
    headerLocId = "shop/shotFreq"
    compare = COMPARE_MORE_BETTER
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportTankDataBlockValues = function(blk, params, mode)
    {
      if(blk.hide)
        return
      local shotFreq = params.shotFreq;
      if(shotFreq > 0)
      {
        local perMinute = stdMath.roundToDigits(shotFreq * 60, 3)
        blk.value[mode] = perMinute
        blk.valueText[mode] = format("%s %s", perMinute.tostring(), ::loc("measureUnits/shotPerMinute"))
      }
      else
      {
        blk.hide = true
      }
    }
    addToExportDataBlock = function(blk, unit)
    {
      addToExportTankDataBlock(blk, unit)
    }
  }
  {
    id = "reload_time"
    order = UNIT_INFO_ORDER.RELOAD_TIME
    headerLocId = "bullet_properties/cooldown"
    getHeader = function(unit)
    {
      return ::format("%s:", ::loc("bullet_properties/cooldown"))
    }
    compare = COMPARE_LESS_BETTER
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportTankDataBlockValues = function(blk, params, mode)
    {
      if(blk.hide)
        return
      local reloadTime = params.reloadTime;
      if(reloadTime > 0)
      {
        blk.value[mode] = reloadTime
        blk.valueText[mode] = format("%.1f %s", reloadTime, ::loc("measureUnits/seconds"))
      }
      else
      {
        blk.hide = true
      }
    }
    addToExportDataBlock = function(blk, unit)
    {
      addToExportTankDataBlock(blk, unit)
    }
  }
  {
    id = "weapon_presets_tank"
    order = UNIT_INFO_ORDER.WEAPON_PRESET_TANK
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/weaponPresets"
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportDataBlock = function(blk, unit)
    {
      local value = 0
      if (unit.weapons.len() > 0)
      {
        foreach(idx, weapon in unit.weapons)
        {
          if (::isWeaponAux(weapon))
            continue
          value++
        }
      }
      local valueText = value.tostring()
      addSingleValue(blk, unit, value, valueText)
    }
  }
  {
    id = "visibility"
    order = UNIT_INFO_ORDER.VISIBILITY
    compare = COMPARE_LESS_BETTER
    headerLocId = "shop/visibilityFactor"
    infoArmyType = UNIT_INFO_ARMY_TYPE.TANK
    addToExportTankDataBlockValues = function(blk, params, mode)
    {
      if(blk.hide)
        return
      if(!("visibilityFactor" in params) || params.visibilityFactor <= 0)
      {
        blk.hide = true
      }
      else
      {
        local visibilityFactor = params.visibilityFactor
        blk.value[mode] = visibilityFactor
        blk.valueText[mode] = format("%d %%", visibilityFactor)
      }

    }
    addToExportDataBlock = function(blk, unit)
    {
      addToExportTankDataBlock(blk, unit)
    }
  }
  {
    id = "displacement"
    order = UNIT_INFO_ORDER.DISPLACEMENT
    compare = COMPARE_MORE_BETTER
    headerLocId = "info/ship/displacement"
    infoArmyType = UNIT_INFO_ARMY_TYPE.SHIP
    addToExportDataBlock = function(blk, unit)
    {
      local value = ::get_full_unit_blk(unit.name)?.ShipPhys?.mass?.TakeOff
      local valueText = ""
      if (value != null)
      {
        valueText = ::g_measure_type.SHIP_DISPLACEMENT_TON.getMeasureUnitsText(value/1000, true)
        addSingleValue(blk, unit, value, valueText)
      }
      else
      {
        blk.hide = true
      }
    }
  }

  {
    id = "ship_speed"
    order = UNIT_INFO_ORDER.SHIP_SPEED
    compare = COMPARE_MORE_BETTER
    headerLocId = "shop/max_speed"
    infoArmyType = UNIT_INFO_ARMY_TYPE.SHIP
    addToExportDataBlock = function(blk, unit)
    {
      local value = ::get_unittags_blk()?[unit.name].Shop.maxSpeed ?? 0
      if(value > 0)
      {
        local valueText = ::g_measure_type.SPEED.getMeasureUnitsText(value)
        addSingleValue(blk, unit, value, valueText)
      }
      else
      {
        blk.hide = true
      }
    }
  }
  {
    id = "armor_thickness_citadel_front"
    order = UNIT_INFO_ORDER.ARMOR_THICKNESS_CITADEL_FRONT
    compare = COMPARE_MORE_BETTER
    headerLocId = "info/ship/citadelArmor"
    infoArmyType = UNIT_INFO_ARMY_TYPE.SHIP
    addToExportDataBlock = function(blk, unit)
    {
      local armorThicknessCitadel = ::get_unittags_blk()?[unit.name]?.Shop?.armorThicknessCitadel

      if(armorThicknessCitadel != null)
      {
        local value = stdMath.round(armorThicknessCitadel.x).tointeger()
        local valueText =  format("%d %s", value, ::loc("measureUnits/mm"))
        addSingleValue(blk, unit, value, valueText)
      }
      else
      {
        blk.hide = true
      }
    }
  }
  {
    id = "armor_thickness_citadel_rear"
    order = UNIT_INFO_ORDER.ARMOR_THICKNESS_CITADEL_REAR
    compare = COMPARE_MORE_BETTER
    headerLocId = "info/ship/citadelArmor"
    infoArmyType = UNIT_INFO_ARMY_TYPE.SHIP
    addToExportDataBlock = function(blk, unit)
    {
      local armorThicknessCitadel = ::get_unittags_blk()?[unit.name]?.Shop?.armorThicknessCitadel

      if(armorThicknessCitadel != null)
      {
        local value = stdMath.round(armorThicknessCitadel.y).tointeger()
        local valueText =  format("%d %s", value, ::loc("measureUnits/mm"))
        addSingleValue(blk, unit, value, valueText)
      }
      else
      {
        blk.hide = true
      }
    }
  }
  {
    id = "armor_thickness_citadel_back"
    order = UNIT_INFO_ORDER.ARMOR_THICKNESS_CITADEL_BACK
    compare = COMPARE_MORE_BETTER
    headerLocId = "info/ship/citadelArmor"
    infoArmyType = UNIT_INFO_ARMY_TYPE.SHIP
    addToExportDataBlock = function(blk, unit)
    {
      local armorThicknessCitadel = ::get_unittags_blk()?[unit.name]?.Shop?.armorThicknessCitadel

      if(armorThicknessCitadel != null)
      {
        local value = stdMath.round(armorThicknessCitadel.z).tointeger()
        local valueText =  format("%d %s", value, ::loc("measureUnits/mm"))
        addSingleValue(blk, unit, value, valueText)
      }
      else
      {
        blk.hide = true
      }
    }
  }
  {
    id = "armor_thickness_tower_front"
    order = UNIT_INFO_ORDER.ARMOR_THICKNESS_TOWER_FRONT
    compare = COMPARE_MORE_BETTER
    headerLocId = "info/ship/mainFireTower"
    infoArmyType = UNIT_INFO_ARMY_TYPE.SHIP
    addToExportDataBlock = function(blk, unit)
    {
      local armorThicknessMainFireTower = ::get_unittags_blk()?[unit.name]?.Shop?.armorThicknessTurretMainCaliber

      if(armorThicknessMainFireTower != null)
      {
        local value = stdMath.round(armorThicknessMainFireTower.x).tointeger()
        local valueText =  format("%d %s", value, ::loc("measureUnits/mm"))
        addSingleValue(blk, unit, value, valueText)
      }
      else
      {
        blk.hide = true
      }
    }
  }
  {
    id = "armor_thickness_tower_rear"
    order = UNIT_INFO_ORDER.ARMOR_THICKNESS_TOWER_REAR
    compare = COMPARE_MORE_BETTER
    headerLocId = "info/ship/mainFireTower"
    infoArmyType = UNIT_INFO_ARMY_TYPE.SHIP
    addToExportDataBlock = function(blk, unit)
    {
      local armorThicknessMainFireTower = ::get_unittags_blk()?[unit.name]?.Shop?.armorThicknessTurretMainCaliber

      if(armorThicknessMainFireTower != null)
      {
        local value = stdMath.round(armorThicknessMainFireTower.y).tointeger()
        local valueText =  format("%d %s", value, ::loc("measureUnits/mm"))
        addSingleValue(blk, unit, value, valueText)
      }
      else
      {
        blk.hide = true
      }
    }
  }
  {
    id = "armor_thickness_tower_back"
    order = UNIT_INFO_ORDER.ARMOR_THICKNESS_TOWER_BACK
    compare = COMPARE_MORE_BETTER
    headerLocId = "info/ship/mainFireTower"
    infoArmyType = UNIT_INFO_ARMY_TYPE.SHIP
    addToExportDataBlock = function(blk, unit)
    {
      local armorThicknessMainFireTower = ::get_unittags_blk()?[unit.name]?.Shop?.armorThicknessTurretMainCaliber

      if(armorThicknessMainFireTower != null)
      {
        local value = stdMath.round(armorThicknessMainFireTower.z).tointeger()
        local valueText =  format("%d %s", value, ::loc("measureUnits/mm"))
        addSingleValue(blk, unit, value, valueText)
      }
      else
      {
        blk.hide = true
      }
    }
  }
  {
    id = "hull_material"
    order = UNIT_INFO_ORDER.HULL_MATERIAL
    compare = COMPARE_NO_COMPARE
    headerLocId = "info/ship/part/hull"
    infoArmyType = UNIT_INFO_ARMY_TYPE.SHIP
    addToExportDataBlock = function(blk, unit)
    {
      local value = (::get_wpcost_blk()?[unit.name]?.Shop?.hullThickness ?? 0).tointeger()
      local valueText = getShipMaterialTexts(unit.name)?.hullValue ?? ""
      if (valueText != "")
        addSingleValue(blk, unit, value, valueText)
      else
        blk.hide = true
    }
  }
  {
    id = "superstructure_material"
    order = UNIT_INFO_ORDER.SUPERSTRUCTURE_MATERIAL
    compare = COMPARE_NO_COMPARE
    headerLocId = "info/ship/part/superstructure"
    infoArmyType = UNIT_INFO_ARMY_TYPE.SHIP
    addToExportDataBlock = function(blk, unit)
    {
      local value = (::get_wpcost_blk()?[unit.name]?.Shop?.superstructureThickness ?? 0).tointeger()
      local valueText = getShipMaterialTexts(unit.name)?.superstructureValue ?? ""
      if (valueText != "")
        addSingleValue(blk, unit, value, valueText)
      else
        blk.hide = true
    }
  }
])
