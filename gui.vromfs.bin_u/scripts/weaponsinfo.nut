local time = require("scripts/time.nut")
local stdMath = require("std/math.nut")
local countMeasure = ::require("scripts/options/optionsMeasureUnits.nut").countMeasure

global const KGF_TO_NEWTON = 9.807

::UNIT_WEAPONS_ZERO    <- 0
::UNIT_WEAPONS_WARNING <- 1
::UNIT_WEAPONS_READY   <- 2

global enum AMMO {
  PRIMARY = 0, //bullets, modifications
  MODIFICATION = 0,
  SECONDARY = 1,  //weapon presets
  WEAPON = 1
}

global enum WEAPON_TYPE {
  GUN             = 0
  ROCKET          = 1 // Rocket
  AAM             = 2 // Air-to-Air Missile
  AGM             = 3 // Air-to-Ground Missile, Anti-Tank Guided Missile
  FLARES          = 4 // Flares (countermeasure)
  SMOKE_SCREEN    = 5
  TORPEDO         = 6
  DEPTH_CHARGE    = 7
}

if (!("_set_last_weapon" in ::getroottable()))
  ::_set_last_weapon <- ::set_last_weapon
::set_last_weapon <- function set_last_weapon(unitName, weaponName)
{
  if (weaponName == ::get_last_weapon(unitName))
    return
  ::_set_last_weapon(unitName, weaponName)
  ::broadcastEvent("UnitWeaponChanged", { unitName = unitName, weaponName = weaponName })
}

if (!("_get_last_weapon" in ::getroottable()))
  ::_get_last_weapon <- ::get_last_weapon
::get_last_weapon <- function get_last_weapon(unitName)
{
  local res = ::_get_last_weapon(unitName)
  if (res != "")
    return res

  //validate last_weapon value
  local unit = ::getAircraftByName(unitName)
  if (!unit)
    return res
  foreach(weapon in unit.weapons)
    if (::is_weapon_visible(unit, weapon)
        && ::is_weapon_enabled(unit, weapon))
    {
      ::_set_last_weapon(unitName, weapon.name)
      return weapon.name
    }
  return res
}

::checkUnitWeapons <- function checkUnitWeapons(unit)
{
  local weapon = ::get_last_weapon(unit.name)
  local weaponText = ::getAmmoAmountData(unit, weapon, AMMO.WEAPON)
  if (weaponText.warning)
    return weaponText.amount? ::UNIT_WEAPONS_WARNING : ::UNIT_WEAPONS_ZERO

  for (local i = 0; i < ::BULLETS_SETS_QUANTITY; i++)
  {
    local modifName = ::get_last_bullets(unit.name, i);
    if (modifName && modifName != "" && ::shop_is_modification_enabled(unit.name, modifName))
    {
      local modificationText = ::getAmmoAmountData(unit, modifName, AMMO.MODIFICATION)
      if (modificationText.warning)
        return modificationText.amount? ::UNIT_WEAPONS_WARNING : ::UNIT_WEAPONS_ZERO
    }
  }

  return ::UNIT_WEAPONS_READY;
}

::getUnitNotReadyAmmoList <- function getUnitNotReadyAmmoList(unit, readyStatus = ::UNIT_WEAPONS_WARNING)
{
  local res = []
  local addAmmoData = function(ammoData) {
    if (readyStatus == ::UNIT_WEAPONS_READY
        || (readyStatus == ::UNIT_WEAPONS_ZERO && !ammoData.amount)
        || (readyStatus == ::UNIT_WEAPONS_WARNING && ammoData.warning))
      res.append(ammoData)
  }

  local weapon = ::get_last_weapon(unit.name)
  addAmmoData(::getAmmoAmountData(unit, weapon, AMMO.WEAPON))

  for (local i = 0; i < ::BULLETS_SETS_QUANTITY; i++)
  {
    local modifName = ::get_last_bullets(unit.name, i);
    if (modifName && modifName != "")
      addAmmoData(::getAmmoAmountData(unit, modifName, AMMO.MODIFICATION))
  }

  return res
}

::addWeaponsFromBlk <- function addWeaponsFromBlk(weapons, block, unit, weaponsFilterFunc = null)
{
  local unitType = ::get_es_unit_type(unit)

  foreach (weapon in (block % "Weapon"))
  {
    if (weapon?.dummy)
      continue

    if (!weapon?.blk)
      continue

    local weaponBlk = ::DataBlock( weapon.blk )
    if (!weaponBlk)
      continue

    if (weaponsFilterFunc?(weapon.blk, weaponBlk) == false)
      continue

    local currentTypeName = "turrets"
    local unitName = "bullet"

    if (weaponBlk?.rocketGun)
    {
      currentTypeName = ""
      switch (weapon?.trigger)
      {
        case "atgm":
        case "agm":     currentTypeName = "agm";      break
        case "aam":     currentTypeName = "aam";      break
        case "flares":  currentTypeName = "flares";   break
        default:        currentTypeName = "rockets"
      }
      if (weapon?.triggerGroup == "smoke")
        currentTypeName = "smoke"
      unitName = "rocket"
    }
    else if (weaponBlk?.bombGun)
    {
      currentTypeName = "bombs"
      unitName = "bomb"
    }
    else if (weaponBlk?.torpedoGun)
    {
      currentTypeName = "torpedoes"
      unitName = "torpedo"
    }
    else if (unitType == ::ES_UNIT_TYPE_TANK
             || ::isInArray(weapon.trigger, [ "machine gun", "cannon", "additional gun", "rockets",
                  "agm", "aam", "bombs", "torpedoes", "smoke", "flares" ]))
    { //not a turret
      currentTypeName = "guns"
      if (weaponBlk?.bullet && typeof(weaponBlk?.bullet) == "instance"
          && ::isCaliberCannon(1000 * ::getTblValue("caliber", weaponBlk?.bullet, 0)))
        currentTypeName = "cannons"
    }
    else if (weaponBlk?.fuelTankGun || weaponBlk?.boosterGun || weaponBlk?.airDropGun || weaponBlk?.undercarriageGun)
      continue

    local isTurret = currentTypeName == "turrets"

    local bullets = weapon?.bullets ?? 0
    if (bullets <= 0)
      bullets = ::max(weaponBlk?.bullets, 0)

    local item = {
      turret = null
      ammo = 0
      num = 0
      caliber = 0
      massKg = 0
      massLbs = 0
      explosiveType = null
      explosiveMass = 0
      dropSpeedRange = null
      dropHeightRange = null
    }

    local needBulletParams = !::isInArray(currentTypeName, [ "smoke", "flares" ])

    if (needBulletParams && unitName.len() && weaponBlk?[unitName])
    {
      local itemBlk = weaponBlk[unitName]
      item.caliber = itemBlk?.caliber ?? item.caliber
      item.massKg = itemBlk?.mass ?? item.massKg
      item.massLbs = itemBlk?.mass_lbs ?? item.massLbs
      item.explosiveType = itemBlk?.explosiveType ?? item.explosiveType
      item.explosiveMass = itemBlk?.explosiveMass ?? item.explosiveMass

      if (::isInArray(currentTypeName, [ "rockets", "agm", "aam" ]))
      {
        item.maxSpeed <- itemBlk?.maxSpeed ?? itemBlk?.endSpeed ?? 0
        if (currentTypeName == "aam")
        {
          item.loadFactorMax <- itemBlk?.loadFactorMax ?? 0
          item.seekerRangeRearAspect <- itemBlk?.irSeeker?.rangeBand0 ?? 0
          item.seekerRangeAllAspect  <- itemBlk?.irSeeker?.rangeBand1 ?? 0
        }
        else if (currentTypeName == "agm")
        {
          item.operatedDist <- itemBlk?.operatedDist ?? 0
        }
      }
      else  if (currentTypeName == "torpedoes")
      {
        item.dropSpeedRange = itemBlk.getPoint2("dropSpeedRange", Point2(0,0))
        if (item.dropSpeedRange.x == 0 && item.dropSpeedRange.y == 0)
          item.dropSpeedRange = null
        item.dropHeightRange = itemBlk.getPoint2("dropHeightRange", Point2(0,0))
        if (item.dropHeightRange.x == 0 && item.dropHeightRange.y == 0)
          item.dropHeightRange = null
        item.maxSpeedInWater <- itemBlk?.maxSpeedInWater ?? 0
        item.distToLive <- itemBlk?.distToLive ?? 0
        item.diveDepth <- itemBlk?.diveDepth ?? 0
        item.armDistance <- itemBlk?.armDistance ?? 0
      }
    }

    if(isTurret && weapon.turret)
    {
      local turretInfo = weapon.turret
      item.turret = ::u.isDataBlock(turretInfo) ? turretInfo.head : turretInfo
    }

    if (!(currentTypeName in weapons))
      weapons[ currentTypeName ] <- []

    local weaponName = ::get_weapon_name_by_blk_path(weapon.blk)
    local trIdx = -1
    foreach(idx, t in weapons[currentTypeName])
      if (weapon.trigger == t.trigger ||
          ((weaponName in t) && ::is_weapon_params_equal(item, t[weaponName])))
      {
        trIdx = idx
        break
      }

    // Merging duplicating weapons with different weaponName
    // (except guns, because there exists different guns with equal params)
    if (trIdx >= 0 && !(weaponName in weapons[currentTypeName][trIdx]) && unitName != "bullet")
      foreach (name, existingItem in weapons[currentTypeName][trIdx])
        if (::is_weapon_params_equal(item, existingItem))
        {
          weaponName = name
          break
        }

    if (trIdx < 0)
    {
      weapons[currentTypeName].append({ trigger = weapon.trigger, caliber = 0 })
      trIdx = weapons[currentTypeName].len() - 1
    }

    local currentType = weapons[currentTypeName][trIdx]

    if (!(weaponName in currentType))
    {
      currentType[weaponName] <- item
      if (item.caliber > currentType.caliber)
        currentType.caliber = item.caliber
    }
    currentType[weaponName].ammo += bullets
    currentType[weaponName].num += 1
  }

  return weapons
}

::get_weapon_name_by_blk_path <- function get_weapon_name_by_blk_path(weaponBlkLink)
{
  local weaponName = weaponBlkLink
  if ( weaponName.slice(-4) == ".blk" )
    weaponName = weaponName.slice(0, -4)

  for ( local i = weaponName.len() - 1; i >= 0; --i )
  {
    if (weaponName[ i ] == '/' || weaponName[ i ] == '\\')
    {
      weaponName = weaponName.slice(i)
      break
    }
  }
  return weaponName
}

::is_weapon_params_equal <- function is_weapon_params_equal(item1, item2)
{
  if (typeof(item1) != "table" || typeof(item2) != "table" || !item1.len() || !item2.len())
    return false
  local skipParams = [ "num", "ammo" ]
  foreach (idx, val in item1)
    if (!::isInArray(idx, skipParams) && !::u.isEqual(val, item2[idx]))
      return false
  return true
}

enum EWeaponType {          // weapon type for getWeaponInfoText
  guns      = 0x01
  cannons   = 0x02
  turrets   = 0x04
  bombs     = 0X08
  rockets   = 0x10
  torpedoes = 0x20
  front     = 0x03 // guns and cannons
  firearm   = 0x07 // guns, cannons and turrets
  pendant   = 0x38 // bombs, rockets, torpedoes
  all       = 0x3F // all weapons, default

  common    = 0x40 // if commonWeapons exists and not empty in plane's blk only description commonWeapons, else firearm
  additional= 0x80 // additional weapons, it's all weapons, exclude common
}

::getWeaponNameText <- function getWeaponNameText(air, isPrimary = null, weaponPreset=-1, newLine=", ")
{
  return getWeaponInfoText(air,
    { isPrimary = isPrimary, weaponPreset = weaponPreset, newLine = newLine, detail = INFO_DETAIL.SHORT })
}

local WEAPON_TEXT_PARAMS = { //const
  isPrimary = null //bool or null. When null return descripton for all weaponry.
  weaponPreset = -1 //int weaponIndex or string weapon name
  newLine="\n" //weapons delimeter
  detail = INFO_DETAIL.FULL
  needTextWhenNoWeapons = true
  ediff = null //int. when not set, uses get_current_ediff() function
  isLocalState = true //should apply my local parameters to unit (modifications, crew skills, etc)
  weaponsFilterFunc = null //function. When set, only filtered weapons are collected from weaponPreset.
}
::getWeaponInfoText <- function getWeaponInfoText(air, p = WEAPON_TEXT_PARAMS)
{
  if (typeof(air) == "string")
    air = getAircraftByName(air)
  if (!air)
    return ""

  local airBlk = ::get_full_unit_blk(air.name)
  if( !airBlk )
    return ""

  p = WEAPON_TEXT_PARAMS.__merge(p)

  local text = ""
  local unitType = ::get_es_unit_type(air)
  local primaryMod = ""
  local weaponPresetIdx = -1
  if ((typeof(p.weaponPreset)=="string") || p.weaponPreset<0)
  {
    if (!p.isPrimary)
    {
      local curWeap = (typeof(p.weaponPreset)=="string")? p.weaponPreset : ::get_last_weapon(air.name)
      weaponPresetIdx = -1
      foreach(idx, w in air.weapons)
        if (w.name == curWeap || (weaponPresetIdx < 0 && !::isWeaponAux(w)))
          weaponPresetIdx = idx
      if (weaponPresetIdx < 0)
        return ""
    }
    if (p.isPrimary && typeof(p.weaponPreset)=="string")
      primaryMod = p.weaponPreset
    else
      primaryMod = ::get_last_primary_weapon(air)
  } else
    weaponPresetIdx = p.weaponPreset

  local weapons = {}

  if (p.isPrimary || p.isPrimary==null)
  {
    local primaryBlk = ::getCommonWeaponsBlk(airBlk, primaryMod)
    if (primaryBlk)
      weapons = addWeaponsFromBlk({}, primaryBlk, air, p.weaponsFilterFunc)
    else if (p.needTextWhenNoWeapons)
      text += ::loc("weapon/noPrimaryWeapon")
  }

  if (airBlk?.weapon_presets != null && !p.isPrimary)
  {
    local wpBlk = null
    foreach (wp in (airBlk.weapon_presets % "preset"))
    {
      if (wp.name == air.weapons?[weaponPresetIdx]?.name)
      {
        wpBlk = ::DataBlock(wp.blk)
        break
      }
    }

    if (!wpBlk)
      return ""
    weapons = addWeaponsFromBlk(weapons, wpBlk, air, p.weaponsFilterFunc)
  }

  local weaponTypeList = [ "cannons", "guns", "aam", "agm", "rockets", "turrets", "torpedoes",
    "bombs", "smoke", "flares" ]
  local consumableWeapons = [ "aam", "agm", "rockets", "torpedoes", "bombs", "smoke", "flares" ]
  local stackableWeapons = ["turrets"]
  foreach (index, weaponType in weaponTypeList)
  {
    if (!(weaponType in weapons))
      continue

    local triggers = weapons[weaponType]
    triggers.sort(@(a, b) b.caliber <=> a.caliber)

    if (::isInArray(weaponType, stackableWeapons))
    {  //merge stackable in one
      for(local i=0; i<triggers.len(); i++)
      {
        triggers[i][weaponType] <- 1
        local sameIdx = -1
        for(local j=0; j<i; j++)
          if (triggers[i].len() == triggers[j].len())
          {
            local same = true
            foreach(wName, w in triggers[j])
              if (!(wName in triggers[i]) ||
                  ((typeof(w) == "table") && triggers[i][wName].num!=w.num))
              {
                same = false
                break
              }
            if (same)
            {
              sameIdx = j
              break
            }
          }
        if (sameIdx>=0)
        {
          triggers[sameIdx][weaponType]++
          foreach(wName, w in triggers[i])
            if (typeof(w) == "table")
              triggers[sameIdx][wName].ammo += w.ammo
          triggers.remove(i)
          i--
        }
      }
    }

    local isShortDesc = p.detail <= INFO_DETAIL.SHORT //for weapons SHORT == LIMITED_11
    local weapTypeCount = 0; //for shortDesc only
    foreach (trigger in triggers)
    {
      local tText = ""
      foreach (weaponName, weapon in trigger)
        if (typeof(weapon) == "table")
        {
          if (tText != "" && weapTypeCount==0)
            tText += p.newLine

          if (::isInArray(weaponType, consumableWeapons))
          {
            if (isShortDesc)
            {
              tText += ::loc("weapons" + weaponName + "/short")
              if (weapon.ammo > 1)
                tText += " " + ::format(::loc("weapons/counter/right/short"), weapon.ammo)
            }
            else
            {
              tText += ::loc("weapons" + weaponName) + ::format(::loc("weapons/counter"), weapon.ammo)
              if (weaponType == "torpedoes" && p.isPrimary != null &&
                  ::isInArray(unitType, [::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_HELICOPTER])) // torpedoes drop for air only
              {
                if (weapon.dropSpeedRange)
                {
                  local speedKmph = countMeasure(0, [weapon.dropSpeedRange.x, weapon.dropSpeedRange.y])
                  local speedMps  = countMeasure(3, [weapon.dropSpeedRange.x, weapon.dropSpeedRange.y])
                  tText += "\n"+::format( ::loc("weapons/drop_speed_range"),
                    "{0} {1}".subst(speedKmph, ::loc("ui/parentheses", { text = speedMps })) )
                }
                if (weapon.dropHeightRange)
                  tText += "\n"+::format(::loc("weapons/drop_height_range"),
                    countMeasure(1, [weapon.dropHeightRange.x, weapon.dropHeightRange.y]))
              }
              if (p.detail >= INFO_DETAIL.EXTENDED && unitType != ::ES_UNIT_TYPE_TANK)
                tText += _get_weapon_extended_info(weapon, weaponType, air, p.ediff, p.newLine + ::nbsp + ::nbsp + ::nbsp + ::nbsp)
            }
          }
          else
          {
            if (isShortDesc)
              weapTypeCount += ("turrets" in trigger)? 0 : weapon.num
            else
            {
              tText += ::loc("weapons" + weaponName)
              if (weapon.num > 1)
                tText += ::format(::loc("weapons/counter"), weapon.num)

              if (weapon.ammo > 0)
                tText += " (" + ::loc("shop/ammo") + ::loc("ui/colon") + weapon.ammo + ")"

              if (!air.unitType.canUseSeveralBulletsForGun)
              {
                local rTime = ::get_reload_time_by_caliber(weapon.caliber, p.ediff)
                if (rTime)
                {
                  if (p.isLocalState)
                  {
                    local difficulty = ::get_difficulty_by_ediff(p.ediff ?? ::get_current_ediff())
                    local key = ::isCaliberCannon(weapon.caliber) ? "cannonReloadSpeedK" : "gunReloadSpeedK"
                    local speedK = air.modificators?[difficulty.crewSkillName]?[key] ?? 1.0
                    if (speedK)
                      rTime = stdMath.round_by_value(rTime / speedK, 1.0).tointeger()
                  }
                  tText += " " + ::loc("bullet_properties/cooldown") + " " + time.secondsToString(rTime, true, true)
                }
              }
            }
          }
        }

      if (isShortDesc)
        weapTypeCount += ("turrets" in trigger)? trigger.turrets : 0
      else
      {
        if ("turrets" in trigger) // && !air.unitType.canUseSeveralBulletsForGun)
        {
          if(trigger.turrets > 1)
            tText = ::format(::loc("weapons/turret_number"), trigger.turrets) + tText
          else
            tText = ::g_string.utf8ToUpper(::loc("weapons_types/turrets"), 1) + ::loc("ui/colon") + tText
        }
      }

      if (tText!="")
        text += ((text!="")? p.newLine : "") + tText
    }
    if (weapTypeCount>0)
    {
      if (text!="") text += p.newLine
      if (isShortDesc)
        text += ::loc("weapons_types/" + weaponType) + ::nbsp + ::format(::loc("weapons/counter/right/short"), weapTypeCount)
      else
        text += ::loc("weapons_types/" + weaponType) + ::format(::loc("weapons/counter"), weapTypeCount)
    }
  }

  if (text=="" && p.needTextWhenNoWeapons)
    if (p.isPrimary)
      text = ::loc("weapon/noPrimaryWeapon")
    else
      text = (air.isAir() || air.isHelicopter()) ? ::loc("weapon/noSecondaryWeapon")
        : ::loc("weapon/noAdditionalWeapon")

  return text
}

//weapon - is a weaponData gathered by addWeaponsFromBlk
::_get_weapon_extended_info <- function _get_weapon_extended_info(weapon, weaponType, unit, ediff, newLine)
{
  local res = ""

  local massText = null
  if (weapon.massLbs > 0)
    massText = format(::loc("mass/lbs"), weapon.massLbs)
  else if (weapon.massKg > 0)
    massText = format(::loc("mass/kg"), weapon.massKg)
  if (massText)
    res += newLine + ::loc("shop/tank_mass") + " " + massText

  if (::isInArray(weaponType, [ "rockets", "agm", "aam" ]))
  {
    local maxSpeed = ::getTblValue("maxSpeed", weapon, 0)
    if (maxSpeed)
      res += newLine + ::loc("rocket/maxSpeed") + ::loc("ui/colon")
             + ::g_measure_type.SPEED_PER_SEC.getMeasureUnitsText(maxSpeed)

    if (weapon?.seekerRangeRearAspect)
      res += newLine + ::loc("missile/seekerRange/rearAspect") + ::loc("ui/colon")
             + ::g_measure_type.DISTANCE.getMeasureUnitsText(weapon.seekerRangeRearAspect)
    if (weapon?.seekerRangeAllAspect)
      res += newLine + ::loc("missile/seekerRange/allAspect") + ::loc("ui/colon")
             + ::g_measure_type.DISTANCE.getMeasureUnitsText(weapon.seekerRangeAllAspect)
    if (weapon?.loadFactorMax)
      res += newLine + ::loc("missile/loadFactorMax") + ::loc("ui/colon")
             + ::g_measure_type.GFORCE.getMeasureUnitsText(weapon.loadFactorMax)

    if (weapon?.operatedDist)
      res += newLine + ::loc("firingRange") + ::loc("ui/colon")
             + ::g_measure_type.DISTANCE.getMeasureUnitsText(weapon.operatedDist)
  }
  else if (weaponType == "torpedoes")
  {
    local torpedoMod = "torpedoes_movement_mode"
    if (::shop_is_modification_enabled(unit.name, torpedoMod))
    {
      local mod = ::getModificationByName(unit, torpedoMod)
      local diffId = ::get_difficulty_by_ediff(ediff ?? ::get_current_ediff()).crewSkillName
      local effects = mod?.effects?[diffId]
      if (effects)
      {
        weapon = clone weapon
        foreach (k, v in weapon)
        {
          local kEffect = k + "Torpedo"
          if ((kEffect in effects) && type(v) == type(effects[kEffect]))
            weapon[k] += effects[kEffect]
        }
      }
    }

    if (weapon?.maxSpeedInWater)
      res += newLine + ::loc("torpedo/maxSpeedInWater") + ::loc("ui/colon")
             + ::g_measure_type.SPEED.getMeasureUnitsText(weapon?.maxSpeedInWater)

    if (weapon?.distToLive)
      res += newLine + ::loc("torpedo/distanceToLive") + ::loc("ui/colon")
             + ::g_measure_type.DISTANCE.getMeasureUnitsText(weapon?.distToLive)

    if (weapon?.diveDepth)
      res += newLine + ::loc("bullet_properties/diveDepth") + ::loc("ui/colon")
             + ::g_measure_type.DEPTH.getMeasureUnitsText(weapon?.diveDepth)

    if (weapon?.armDistance)
      res += newLine + ::loc("torpedo/armingDistance") + ::loc("ui/colon")
             + ::g_measure_type.DEPTH.getMeasureUnitsText(weapon?.armDistance)
  }

  if (!weapon.explosiveType)
    return res

  res += newLine + ::loc("bullet_properties/explosiveType") + ::loc("ui/colon")
         + ::loc("explosiveType/" + weapon.explosiveType)
  if (weapon.explosiveMass)
  {
    local measureType = ::g_measure_type.getTypeByName("kg", true)
    res += newLine + ::loc("bullet_properties/explosiveMass") + ::loc("ui/colon")
             + measureType.getMeasureUnitsText(weapon.explosiveMass)
  }
  if (weapon.explosiveType && weapon.explosiveMass)
  {
    local tntEqText = ::g_dmg_model.getTntEquivalentText(weapon.explosiveType, weapon.explosiveMass)
    if (tntEqText.len())
      res += newLine + ::loc("bullet_properties/explosiveMassInTNTEquivalent") + ::loc("ui/colon") + tntEqText
  }

  if (/*weaponType == "rockets" || */ (weaponType == "bombs" && unit.unitType != ::g_unit_type.SHIP))
  {
    local destrTexts = ::g_dmg_model.getDestructionInfoTexts(weapon.explosiveType, weapon.explosiveMass, weapon.massKg)
    foreach(name in ["maxArmorPenetration", "destroyRadiusArmored", "destroyRadiusNotArmored"])
    {
      local valueText = destrTexts[name + "Text"]
      if (valueText.len())
        res += newLine + ::loc("bombProperties/" + name) + ::loc("ui/colon") + valueText
    }
  }

  return res
}

::getWeaponShortTypeFromWpName <- function getWeaponShortTypeFromWpName(wpName, air = null)
{
  if (!wpName || typeof(wpName) != "string")
    return ""

  if (typeof(air) == "string")
    air = ::getAircraftByName(air)

  if (!air)
    return ""

  for (local i = 0; i < air.weapons.len(); ++i)
  {
    if (wpName == air.weapons[i].name)
      return getWeaponShortType(air, i)
  }

  return ""
}

// return short desc of air.weapons[weaponPresetNo], like M\C\B\T
::getWeaponShortType <- function getWeaponShortType(air, weaponPresetNo=0)
{
  if (typeof(air) == "string")
    air = getAircraftByName(air)

  if (!air)
    return ""

  local text = ""
  if (air.weapons[weaponPresetNo].frontGun)
    text += ::loc("weapons_types/short/guns")

  if (air.weapons[weaponPresetNo].cannon)
  {
    if (text != "")
      text += ::loc("weapons_types/short/separator")
    text += ::loc("weapons_types/short/cannons")
  }
  if (air.weapons[weaponPresetNo].bomb)
  {
    if (text != "")
      text += ::loc("weapons_types/short/separator")
    text += ::loc("weapons_types/short/bombs")
  }
  if (air.weapons[weaponPresetNo].rocket)
  {
    if (text != "")
      text += ::loc("weapons_types/short/separator")
    text += ::loc("weapons_types/short/rockets")
  }
  if (air.weapons[weaponPresetNo].torpedo)
  {
    if (text != "")
      text += ::loc("weapons_types/short/separator")
    text += ::loc("weapons_types/short/torpedoes")
  }

  return text
}

::isCaliberCannon <- function isCaliberCannon(caliber_mm)
{
  return caliber_mm >= 15
}

::getWeaponXrayDescText <- function getWeaponXrayDescText(weaponBlk, unit, ediff)
{
  local weaponsBlk = ::DataBlock()
  weaponsBlk["Weapon"] = weaponBlk
  local weaponTypes = addWeaponsFromBlk({}, weaponsBlk, unit)
  foreach (weaponType, weaponTypeList in weaponTypes)
    foreach (weapons in weaponTypeList)
      foreach (weapon in weapons)
        if (::u.isTable(weapon))
          return _get_weapon_extended_info(weapon, weaponType, unit, ediff, "\n")
  return ""
}

::getWeaponDescTextByTriggerGroup <- function getWeaponDescTextByTriggerGroup(triggerGroup, unit, ediff)
{
  local unitBlk = ::get_full_unit_blk(unit.name)
  local primaryWeapon = ::get_last_primary_weapon(unit)
  local secondaryWeapon = ::get_last_weapon(unit.name)

  local primaryBlk = ::getCommonWeaponsBlk(unitBlk, primaryWeapon)
  local weaponTypes = {}
  if (primaryBlk)
    weaponTypes = addWeaponsFromBlk(weaponTypes, primaryBlk, unit)
  if (unitBlk?.weapon_presets)
    foreach (wp in (unitBlk.weapon_presets % "preset"))
      if (wp.name == secondaryWeapon)
      {
        local wpBlk = ::DataBlock(wp.blk)
        if (wpBlk)
          weaponTypes = addWeaponsFromBlk(weaponTypes, wpBlk, unit)
        break
      }

  if (weaponTypes?[triggerGroup])
    foreach (weapons in weaponTypes[triggerGroup])
      foreach (weaponName, weapon in weapons)
        if (::u.isTable(weapon))
          return ::loc("weapons" + weaponName) + ::format(::loc("weapons/counter"), weapon.ammo) +
            _get_weapon_extended_info(weapon, triggerGroup, unit, ediff,
              "\n" + ::nbsp + ::nbsp + ::nbsp + ::nbsp)
  return ""
}

::isAirHaveSecondaryWeapons <- function isAirHaveSecondaryWeapons(air)
{
  local foundWeapon = false
  for (local i = 0; i < air.weapons.len(); i++)
    if (!::isWeaponAux(air.weapons[i]))
      if (foundWeapon)
        return true
      else
        foundWeapon = true
  return "" != getWeaponInfoText(air, { isPrimary = false, weaponPreset = 0, needTextWhenNoWeapons = false })
}

::get_expendable_modifications_array <- function get_expendable_modifications_array(unit)
{
  if (!("modifications" in unit))
    return []

  return ::u.filter(unit.modifications, ::is_modclass_expendable)
}

::getPrimaryWeaponsList <- function getPrimaryWeaponsList(air)
{
  if(air.primaryWeaponMods)
    return air.primaryWeaponMods

  air.primaryWeaponMods = [""]

  local airBlk = ::get_full_unit_blk(air.name)
  if(!airBlk || !airBlk?.modifications)
    return air.primaryWeaponMods

  foreach(modName, modification in airBlk.modifications)
    if (modification?.effects?.commonWeapons)
      air.primaryWeaponMods.append(modName)

  return air.primaryWeaponMods
}

::get_last_primary_weapon <- function get_last_primary_weapon(air)
{
  local primaryList = ::getPrimaryWeaponsList(air)
  foreach(modName in primaryList)
    if (modName!="" && ::shop_is_modification_enabled(air.name, modName))
      return modName
  return ""
}

::getCommonWeaponsBlk <- function getCommonWeaponsBlk(airBlk, primaryMod)
{
  if (primaryMod == "" && airBlk?.commonWeapons)
    return airBlk.commonWeapons

  if (airBlk?.modifications)
    foreach(modName, modification in airBlk.modifications)
      if (modName == primaryMod)
      {
        if (modification?.effects.commonWeapons)
          return modification.effects.commonWeapons
        break
      }
  return null
}

::getAmmoAmount <- function getAmmoAmount(unit, ammoName, ammoType)
{
  if (!ammoName)
    return 0
  if (ammoType==AMMO.MODIFICATION)
    return ::shop_is_modification_purchased(unit.name, ammoName)
  return  ::shop_is_weapon_purchased(unit.name, ammoName)
}
::getAmmoMaxAmount <- function getAmmoMaxAmount(unit, ammoName, ammoType)
{
  if (ammoType==AMMO.MODIFICATION)
  {
    local res = ::wp_get_modification_max_count(unit.name, ammoName)
    //for unlimited ammo code return also 1, same as for other modifications
    if (res == 1 && ::getAmmoCost(unit, ammoName, ammoType).isZero())
      res = 0 //unlimited
    return res
  }
  return  ::wp_get_weapon_max_count(unit.name, ammoName)
}

::getAmmoMaxAmountInSession <- function getAmmoMaxAmountInSession(unit, ammoName, ammoType)
{
  if (ammoType==AMMO.MODIFICATION)
    return ::shop_get_modification_baseval(unit.name, ammoName)
  return  ::shop_get_weapon_baseval(unit.name, ammoName)
}

::getAmmoCost <- function getAmmoCost(unit, ammoName, ammoType)
{
  local res = ::Cost()
  if (ammoType==AMMO.MODIFICATION)
  {
    res.wp = ::max(::wp_get_modification_cost(unit.name, ammoName), 0)
    res.gold = ::max(::wp_get_modification_cost_gold(unit.name, ammoName), 0)
  } else
  {
    res.wp = ::wp_get_cost2(unit.name, ammoName)
    res.gold = ::wp_get_cost_gold2(unit.name, ammoName)
  }
  return  res
}

::isAmmoFree <- function isAmmoFree(unit, ammoName, ammoType)
{
  return ::getAmmoCost(unit, ammoName, ammoType) <= ::zero_money
}

::getAmmoWarningMinimum <- function getAmmoWarningMinimum(ammoType, unit, maxAmount)
{
  if (unit.unitType == ::g_unit_type.SHIP)
    return max(1, maxAmount / 10)
  return (ammoType==AMMO.MODIFICATION)? ::weaponsWarningMinimumPrimary : ::weaponsWarningMinimumSecondary
}

::getAmmoAmountData <- function getAmmoAmountData(unit, ammoName, ammoType)
{
  local res = {text = "", warning = false, amount = 0, buyAmount = 0,
               airName = unit.name, ammoName = ammoName, ammoType = ammoType }

  res.amount = ::getAmmoAmount(unit, ammoName, ammoType)
  local maxAmount = ::getAmmoMaxAmount(unit, ammoName, ammoType)
  local text = ::getAmountAndMaxAmountText(res.amount, maxAmount)
  if (text == "")
    return res

  local fullText = "(" + text + ")";
  local amountWarning = ::getAmmoWarningMinimum(ammoType, unit, maxAmount)
  if (res.amount < amountWarning)
  {
    res.text = "<color=@weaponWarning>" + fullText + "</color>"
    res.warning = true
    res.buyAmount = amountWarning - res.amount
    return res
  }
  res.text = fullText
  return res
}

::getBulletsSetData <- function getBulletsSetData(air, modifName, noModList = null)
    //noModList!=null -> generate sets for fake bullets. return setsAmount
    //id of thoose sets = modifName + setNum + "_default"
{
  if ((modifName in air.bulletsSets) && !noModList)
    return air.bulletsSets[modifName] //all sets saved for no need analyze blk everytime when it need.

  local res = null
  local airBlk = ::get_full_unit_blk(air.name)
  if (!airBlk?.modifications)
    return res

  local searchName = ""
  local mod = null
  if (!noModList)
  {
    searchName = ::getBulletsSearchName(air, modifName)
    if (searchName=="")
      return res
    mod = ::getModificationByName(air, modifName)
  }

  local wpList = []
  local primaryList = getPrimaryWeaponsList(air)
  foreach(primaryMod in primaryList)
  {
    local primaryBlk = ::getCommonWeaponsBlk(airBlk, primaryMod)
    if (primaryBlk)
      foreach (weapon in (primaryBlk % "Weapon"))
        if (weapon?.blk && !weapon?.dummy && !::isInArray(weapon.blk, wpList))
          wpList.append(weapon.blk)
  }

  if (airBlk?.weapon_presets && !noModList) //not for fake bullets
    foreach (preset in (airBlk.weapon_presets % "preset"))
      if (preset?.blk)
      {
        local pBlk = ::DataBlock(preset.blk)
        if (!pBlk)
          continue

        foreach (weapon in (pBlk % "Weapon"))
          if (weapon?.blk && !weapon?.dummy && !::isInArray(weapon.blk, wpList))
            wpList.append(weapon.blk)
      }

  local bulSetForIconParam = null
  local fakeBulletsSets = []
  foreach (wBlkName in wpList)
  {
    local wBlk = ::DataBlock(wBlkName)
    if (!wBlk || (!wBlk?[getModificationBulletsEffect(searchName)] && !noModList))
      continue
    if (noModList)
    {
      local skip = false
      foreach(modName in noModList)
        if (wBlk?[getModificationBulletsEffect(modName)])
        {
          skip = true
          break
        }
      if (skip)
        continue
    }

    local bulletsModBlk = wBlk?[getModificationBulletsEffect(modifName)]
    local bulletsBlk = bulletsModBlk ? bulletsModBlk : wBlk
    local bulletsList = bulletsBlk % "bullet"
    local weaponType = WEAPON_TYPE.GUN
    if (!bulletsList.len())
    {
      bulletsList = bulletsBlk % "rocket"
      if (bulletsList.len())
      {
        local rocket = bulletsList[0]
        if (rocket?.smokeShell == true)
          weaponType = WEAPON_TYPE.SMOKE_SCREEN
        else if (rocket?.smokeShell == false)
           weaponType = WEAPON_TYPE.FLARES
        else if (rocket?.guidance)
          weaponType = WEAPON_TYPE.AAM
        else if (rocket?.bulletType == "atgm_tank")
          weaponType = WEAPON_TYPE.AGM
        else
          weaponType = WEAPON_TYPE.ROCKET
      }
    }

    local isBulletBelt = weaponType == WEAPON_TYPE.GUN &&
      (wBlk?.isBulletBelt != false || ((wBlk?.bulletsCartridge ?? 0) > 1 && !wBlk?.useSingleIconForBullet))

    foreach (b in bulletsList)
    {
      local paramsBlk = ::u.isDataBlock(b?.rocket) ? b.rocket : b
      if (!res)
        if (paramsBlk?.caliber)
          res = { caliber = 1000.0 * paramsBlk.caliber,
                  bullets = [],
                  isBulletBelt = isBulletBelt
                  catridge = wBlk?.bulletsCartridge ?? 0
                  weaponType = weaponType
                  useDefaultBullet = !wBlk?.notUseDefaultBulletInGui,
                  weaponBlkName = wBlkName
                  maxToRespawn = mod?.maxToRespawn ?? 0
                }
        else
          continue

      local bulletType = b.bulletType || b.getBlockName()
      if (paramsBlk?.selfDestructionInAir)
        bulletType += "@s_d"
      res.bullets.append(bulletType)

      if ("bulletName" in b)
      {
        if (!("bulletNames" in res))
          res.bulletNames <- [];
        res.bulletNames.append(b.bulletName);
      }

      foreach(param in ["explosiveType", "explosiveMass"])
        if (param in paramsBlk)
          res[param] <- paramsBlk[param]

      foreach(param in ["smokeShellRad", "smokeActivateTime", "smokeTime"])
        if (param in paramsBlk)
          res[param] <- paramsBlk[param]

      if (paramsBlk?.proximityFuse)
      {
        res.proximityFuseArmDistance <- paramsBlk.proximityFuse?.armDistance ?? 0
        res.proximityFuseRadius      <- paramsBlk.proximityFuse?.radius ?? 0
      }
    }

    if (res)
    {
      if (noModList)
      {
        if (!bulSetForIconParam && !noModList.len()
            && !res.isBulletBelt) //really first default bullet set. can have default icon params
          bulSetForIconParam = res
        fakeBulletsSets.append(res)
        res = null
      }
      else
      {
        bulSetForIconParam = res
        break
      }
    }
  }

  if (bulSetForIconParam)
  {
    local bIconParam = 0
    if (searchName == modifName) //not default bullet
      bIconParam = ::getTblValue("bulletsIconParam", mod, 0)
    else
      bIconParam = ::getTblValue("bulletsIconParam", air, 0)
    if (bIconParam)
      bulSetForIconParam.bIconParam <- {
        armor = bIconParam % 10 - 1
        damage = (bIconParam / 10).tointeger() - 1
      }
  }

  //res = { caliber = 0.00762, bullets = ["he_i", "i_t", "he_frag@s_d", "aphe"]}
  if (!noModList)
    air.bulletsSets[modifName] <- res
  else
  {
    fakeBulletsSets.sort(function(a, b) {
      if (a.caliber != b.caliber)
        return a.caliber > b.caliber ? -1 : 1
      return 0
    })
    for(local i = 0; i < fakeBulletsSets.len(); i++)
      air.bulletsSets[modifName + i + "_default"] <- fakeBulletsSets[i]
  }

  return noModList? fakeBulletsSets.len() : res
}

::getBulletsSearchName <- function getBulletsSearchName(unit, modifName) //need for default bullets, which not exist as modifications
{
  if (!("modifications" in unit))
    return ""
  if (getModificationByName(unit, modifName))
    return modifName  //not default modification

  local groupName = ::getModificationBulletsGroup(modifName)
  if (groupName!="")
    foreach(i, modif in unit.modifications)
      if (::getModificationBulletsGroup(modif.name) == groupName)
        return modif.name
  return ""
}

::getActiveBulletsIntByWeaponsBlk <- function getActiveBulletsIntByWeaponsBlk(air, weaponsBlk, weaponToFakeBulletMask)
{
  local res = 0
  local wpList = []
  if (weaponsBlk)
    foreach (weapon in (weaponsBlk % "Weapon"))
      if (weapon?.blk && !weapon?.dummy && !::isInArray(weapon.blk, wpList))
        wpList.append(weapon.blk)

  if (wpList.len())
  {
    local modsList = ::getBulletsModListByGroups(air)
    foreach (wBlkName in wpList)
    {
      if (wBlkName in weaponToFakeBulletMask)
      {
        res = res | weaponToFakeBulletMask[wBlkName]
        continue
      }

      local wBlk = ::DataBlock(wBlkName)
      if (!wBlk)
        continue

      foreach(idx, modName in modsList)
        if (wBlk?[getModificationBulletsEffect(modName)])
        {
          res = stdMath.change_bit(res, idx, 1)
          break
        }
    }
  }
  return res
}

::getActiveBulletsGroupInt <- function getActiveBulletsGroupInt(air, checkPurchased = true)
{
  local primaryWeapon = ::get_last_primary_weapon(air)
  local secondaryWeapon = ::get_last_weapon(air.name)
  if (!(primaryWeapon in air.primaryBullets) || !(secondaryWeapon in air.secondaryBullets))
  {
    local weaponToFakeBulletMask = {}
    local lastFakeIdx = ::get_last_fake_bullets_index(air)
    local total = ::getBulletsGroupCount(air, true) - ::getBulletsGroupCount(air, false)
    local fakeBulletsOffset = lastFakeIdx - total
    for(local i = 0; i < total; i++)
    {
      local bulSet = ::getBulletsSetData(air, ::get_fake_bullet_name(i))
      if (bulSet)
        weaponToFakeBulletMask[bulSet.weaponBlkName] <- 1 << (fakeBulletsOffset + i)
    }

    if (!(primaryWeapon in air.primaryBullets))
    {
      local primary = 0
      local primaryList = ::getPrimaryWeaponsList(air)
      if (primaryList.len() > 0)
      {
        local airBlk = ::get_full_unit_blk(air.name)
        if (airBlk)
        {
          local primaryBlk = ::getCommonWeaponsBlk(airBlk, primaryWeapon)
          primary = ::getActiveBulletsIntByWeaponsBlk(air, primaryBlk, weaponToFakeBulletMask)
        }
      }
      air.primaryBullets[primaryWeapon] <- primary
    }

    if (!(secondaryWeapon in air.secondaryBullets))
    {
      local secondary = 0
      local airBlk = ::get_full_unit_blk(air.name)
      if (airBlk?.weapon_presets)
        foreach (wp in (airBlk.weapon_presets % "preset"))
          if (wp.name == secondaryWeapon)
          {
            local wpBlk = ::DataBlock(wp.blk)
            if (wpBlk)
              secondary = ::getActiveBulletsIntByWeaponsBlk(air, wpBlk, weaponToFakeBulletMask)
          }
      air.secondaryBullets[secondaryWeapon] <- secondary
    }
  }

  local res = air.primaryBullets[primaryWeapon] | air.secondaryBullets[secondaryWeapon]
  if (::can_bullets_be_duplicate(air))
  {
    res = res & ~((1 << ::BULLETS_SETS_QUANTITY) - 1) //use only fake bullets mask
    res = res | getActiveBulletsGroupIntForDuplicates(air, checkPurchased)
  }
  return res
}

::getActiveBulletsGroupIntForDuplicates <- function getActiveBulletsGroupIntForDuplicates(unit, checkPurchased = true)
{
  local res = 0
  local groupsCount = ::getBulletsGroupCount(unit, false)
  local lastLinkedIdx = -1
  local duplicates = 0
  local lastIdxTotal = 0
  local maxCatridges = 0
  for(local i = 0; i < ::BULLETS_SETS_QUANTITY; i++)
  {
    local linkedIdx = get_linked_gun_index(i, groupsCount)
    if (linkedIdx == lastLinkedIdx)
      duplicates++
    else
    {
      local bullets = get_bullets_list(unit.name, i, {
        isOnlyBought = checkPurchased, needCheckUnitPurchase = checkPurchased
      })
      lastIdxTotal = bullets.values.len()
      lastLinkedIdx = linkedIdx
      duplicates = 0

      local bInfo = ::getBulletsInfoForGun(unit, linkedIdx)
      maxCatridges = ::getTblValue("total", bInfo, 0)
    }

    if (lastIdxTotal > duplicates && duplicates < maxCatridges)
      res = res | (1 << i)
  }
  return res
}

::default_primary_bullets_info <- {
  guns = 1
  total = 0 //catridges total
  catridge = 1
  groupIndex = -1
  forcedMaxBulletsInRespawn = false
}
::getBulletsInfoForPrimaryGuns <- function getBulletsInfoForPrimaryGuns(air)
{
  if (air.primaryBulletsInfo)
    return air.primaryBulletsInfo

  local res = []
  air.primaryBulletsInfo = res
  if (!air.unitType.canUseSeveralBulletsForGun)
    return res

  local airBlk = ::get_full_unit_blk(air.name)
  if (!airBlk)
    return res

  local commonWeaponBlk = ::getCommonWeaponsBlk(airBlk, "")
  if (!commonWeaponBlk)
    return res

  local modsList = ::getBulletsModListByGroups(air)
  local wpList = {} // name = amount
  foreach (weapon in (commonWeaponBlk % "Weapon"))
    if (weapon?.blk && !weapon?.dummy)
      if (weapon.blk in wpList)
        wpList[weapon.blk].guns++
      else
      {
        wpList[weapon.blk] <- clone ::default_primary_bullets_info
        if (!("bullets" in weapon))
          continue

        wpList[weapon.blk].total = weapon?.bullets ?? 0
        local wBlk = ::DataBlock(weapon.blk)
        if (!wBlk)
          continue

        wpList[weapon.blk].catridge = wBlk?.bulletsCartridge || 1
        local totalBullets = wpList[weapon.blk].total
        wpList[weapon.blk].total = (wpList[weapon.blk].total / wpList[weapon.blk].catridge).tointeger()
        if (wpList[weapon.blk].total * wpList[weapon.blk].catridge < totalBullets)
          wpList[weapon.blk].total += 1
        foreach(idx, modName in modsList)
          if (wBlk?[getModificationBulletsEffect(modName)])
          {
            wpList[weapon.blk].groupIndex = idx
            break
          }
        wpList[weapon.blk].forcedMaxBulletsInRespawn = wBlk?.forcedMaxBulletsInRespawn ?? false
      }

  foreach(idx, modName in modsList)
  {
    local bInfo = null
    foreach(blkName, info in wpList)
      if (info.groupIndex == idx)
      {
        bInfo = info
        break
      }
    res.append(bInfo || (clone ::default_primary_bullets_info))
  }
  return res
}

::getBulletsInfoForGun <- function getBulletsInfoForGun(unit, gunIdx)
{
  local bulletsInfo = ::getBulletsInfoForPrimaryGuns(unit)
  return ::getTblValue(gunIdx, bulletsInfo)
}

::isBulletGroupActive <- function isBulletGroupActive(air, group)
{
  local groupsActive = ::getActiveBulletsGroupInt(air)
  return (groupsActive & (1 << group)) != 0
}

::is_bullets_group_active_by_mod <- function is_bullets_group_active_by_mod(air, mod)
{
  local groupIdx = ::getTblValue("isDefaultForGroup", mod, -1)
  if (groupIdx < 0)
    groupIdx = ::get_bullet_group_index(air.name, mod.name)
  return ::isBulletGroupActive(air, groupIdx)
}

::updateRelationModificationList <- function updateRelationModificationList(air, modifName)
{
  local mod = ::getModificationByName(air, modifName)
  if (mod && !("relationModification" in mod))
  {
    local blk = ::get_modifications_blk();
    mod.relationModification <- [];
    foreach(ind, m in air.modifications)
    {
      if ("reqModification" in m && ::isInArray(modifName, m.reqModification))
      {
        local modification = blk?.modifications?[m.name]
        if (modification?.effects)
          foreach (effectType, effect in modification.effects)
          {
            if (effectType == "additiveBulletMod")
            {
              mod.relationModification.append(m.name)
              break;
            }
          }
      }
    }
  }
}

::get_premExpMul_add_value <- function get_premExpMul_add_value(unit)
{
  return (::get_ranks_blk()?.goldPlaneExpMul ?? 1.0) - 1.0
}

::get_uniq_modification_text <- function get_uniq_modification_text(unit, modifName, isShortDesc)
{
  if (modifName == "premExpMul")
  {
    local value = ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(::get_premExpMul_add_value(unit), false)
    local ending = isShortDesc? "" : "/desc"
    return ::loc("modification/" + modifName + ending, "", { value = value })
  }
  return null
}

::getModificationName <- function getModificationName(air, modifName, limitedName = false)
{
  return ::getModificationInfo(air, modifName, true, limitedName).desc
}

// Generate text description for air.modifications[modificationNo]
::getModificationInfo <- function getModificationInfo(air, modifName, isShortDesc=false, limitedName = false,
                                 obj = null, itemDescrRewriteFunc = null)
{
  local res = {desc = "", delayed = false}
  if (typeof(air) == "string")
    air = getAircraftByName(air)
  if (!air)
    return res

  local uniqText = ::get_uniq_modification_text(air, modifName, isShortDesc)
  if (uniqText)
  {
    res.desc = uniqText
    return res
  }

  local mod = ::getModificationByName(air, modifName)

  local ammo_pack_len = 0
  if (modifName.indexof("_ammo_pack") != null && mod)
  {
    updateRelationModificationList(air, modifName);
    if ("relationModification" in mod && mod.relationModification.len() > 0)
    {
      modifName = mod.relationModification[0];
      ammo_pack_len = mod.relationModification.len()
      mod = ::getModificationByName(air, modifName)
    }
  }

  local groupName = ::getModificationBulletsGroup(modifName)
  if (groupName=="") //not bullets
  {
    if (!isShortDesc && itemDescrRewriteFunc)
      res.delayed = ::calculate_mod_or_weapon_effect(air.name, modifName, true, obj, itemDescrRewriteFunc, null) ?? true

    local locId = modifName
    local ending = isShortDesc? (limitedName? "/short" : "") : "/desc"

    res.desc = ::loc("modification/" + locId + ending, "")
    if (res.desc == "" && isShortDesc && limitedName)
      res.desc = ::loc("modification/" + locId, "")

    if (res.desc == "")
    {
      local caliber = 0.0
      foreach(n in ::modifications_locId_by_caliber)
        if (locId.len() > n.len() && locId.slice(locId.len()-n.len()) == n)
        {
          locId = n
          caliber = ("caliber" in mod)? mod.caliber : 0.0
          if (limitedName)
            caliber = caliber.tointeger()
          break
        }

      locId = "modification/" + locId
      if (::isCaliberCannon(caliber))
        res.desc = ::locEnding(locId + "/cannon", ending, "")
      if (res.desc=="")
        res.desc = ::locEnding(locId, ending)
      if (caliber > 0)
        res.desc = ::format(res.desc, caliber.tostring())
    }
    return res //without effects atm
  }

  //bullets sets
  local set = getBulletsSetData(air, modifName)

  if (isShortDesc && !mod && set?.weaponType == WEAPON_TYPE.GUN && !air.unitType.canUseSeveralBulletsForGun)
  {
    res.desc = ::loc("modification/default_bullets")
    return res
  }

  if (!set)
  {
    if (res.desc == "")
      res.desc = modifName + " not found bullets"
    return res
  }

  local shortDescr = "";
  if (isShortDesc || ammo_pack_len) //bullets name
  {
    local locId = modifName
    local caliber = limitedName? set.caliber.tointeger() : set.caliber
    foreach(n in ::bullets_locId_by_caliber)
      if (locId.len() > n.len() && locId.slice(locId.len()-n.len()) == n)
      {
        locId = n
        break
      }
    if (limitedName)
      shortDescr = ::loc(locId + "/name/short", "")
    if (shortDescr == "")
      shortDescr = ::loc(locId + "/name")
    if (set?.bulletNames?[0]
      && (set.weaponType != WEAPON_TYPE.GUN || !set.isBulletBelt ||
      (::isCaliberCannon(caliber) && air.unitType.canUseSeveralBulletsForGun)))
    {
      locId = set.bulletNames[0]
      shortDescr = ::loc(locId, ::loc("weapons/" + locId + "/short", locId))
    }
    if (!mod && air.unitType.canUseSeveralBulletsForGun && set.isBulletBelt)
      shortDescr = ::loc("modification/default_bullets")
    shortDescr = format(shortDescr, caliber.tostring())
  }
  if (isShortDesc)
  {
    res.desc = shortDescr
    return res
  }

  if (ammo_pack_len)
  {
    if ("bulletNames" in set && typeof(set.bulletNames) == "array" && set.bulletNames.len())
      shortDescr = format(::loc(set.isBulletBelt ? "modification/ammo_pack_belt/desc" : "modification/ammo_pack/desc"), shortDescr)
    if (ammo_pack_len > 1)
    {
      res.desc = shortDescr
      return res
    }
  }

  //bullets description
  local annotation = ""
  local usedLocs = []
  local infoFunc = function(name, addName=null) {
    local txt = ::loc(name + "/name/short")
    if (addName) txt += ::loc(addName + "/name/short")
    txt += " - " + ::loc(name + "/name")
    if (addName) txt += " " + ::loc(addName + "/name")
    return txt
  }
  local separator = ::loc("bullet_type_separator/name")
  local setText = ""
  foreach(b in set.bullets)
  {
    setText += ((setText=="")? "" : separator)
    local part = b.indexof("@")
    if (part==null)
      setText+=::loc(b + "/name/short")
    else
      setText+=::loc(b.slice(0, part) + "/name/short") + ::loc(b.slice(part+1) + "/name/short")
    if (!::isInArray(b, usedLocs))
    {
      if (annotation != "")
        annotation += "\n"
      if (part==null)
        annotation += infoFunc(b)
      else
        annotation += infoFunc(b.slice(0, part), b.slice(part+1))
      usedLocs.append(b)
    }
  }

  if (ammo_pack_len)
    res.desc = shortDescr + "\n"
  if (set.bullets.len() > 1)
    res.desc += format(::loc("caliber_" + set.caliber + "/desc"), setText) + "\n\n"
  res.desc += annotation
  return res
}

::getModificationBulletsGroup <- function getModificationBulletsGroup(modifName)
{
  local blk = ::get_modifications_blk();
  local modification = blk?.modifications?[modifName]
  if (modification)
  {
    if (!modification?.group)
      return "" //new_gun etc. - not a bullets list
    if (modification?.effects)
      foreach (effectType, effect in modification.effects)
      {
        if (effectType == "additiveBulletMod")
        {
          local underscore = modification.group.indexof("_");
          if (underscore)
            return modification.group.slice(0, underscore);
        }
        if (effectType == "bulletMod" || effectType == "additiveBulletMod")
          return modification.group;
      }
  }
  else if (modifName.len()>8 && modifName.slice(modifName.len()-8)=="_default")
    return modifName.slice(0, modifName.len()-8)

  return "";
}

::getDefaultBulletName <- function getDefaultBulletName(unit)
{
  if (!("modifications" in unit))
    return ""

  local ignoreGroups = [null, ""]
  for (local modifNo = 0; modifNo < unit.modifications.len(); modifNo++)
  {
    local modif = unit.modifications[modifNo]
    local modifName = modif.name;

    local groupName = ::getModificationBulletsGroup(modifName);
    if (::isInArray(groupName, ignoreGroups))
      continue

    local bData = ::getBulletsSetData(unit, modifName)
    if (!bData || bData?.useDefaultBullet)
      return groupName + "_default"

    ignoreGroups.append(groupName)
  }
  return ""
}

::getModificationBulletsEffect <- function getModificationBulletsEffect(modifName)
{
  local blk = ::get_modifications_blk();
  local modification = blk?.modifications?[modifName]
  if (modification?.effects)
  {
    foreach (effectType, effect in modification.effects)
    {
      if (effectType == "additiveBulletMod")
        return modification.effects.additiveBulletMod;
      if (effectType == "bulletMod")
        return modification.effects.bulletMod;
    }
  }
  return "";
}

::getBulletsGroupCount <- function getBulletsGroupCount(air, full = false)
{
  if (!air)
    return 0
  if (air.bulGroups < 0)
  {
    local modList = []
    local groups = []

    foreach(m in air.modifications)
    {
      local groupName = ::getModificationBulletsGroup(m.name)
      if (groupName!="")
      {
        if (!::isInArray(groupName, groups))
          groups.append(groupName)
        modList.append(m.name)
      }
    }
    air.bulModsGroups = groups.len()
    air.bulGroups     = groups.len()

    if (air.bulGroups < ::BULLETS_SETS_QUANTITY)
    {
      local add = ::getBulletsSetData(air, ::fakeBullets_prefix, modList) || 0
      air.bulGroups = ::min(air.bulGroups + add, ::BULLETS_SETS_QUANTITY)
    }
  }
  return full? air.bulGroups : air.bulModsGroups
}

::getBulletsModListByGroups <- function getBulletsModListByGroups(air)
{
  local modList = []
  local groups = []

  if ("modifications" in air)
    foreach(m in air.modifications)
    {
      local groupName = ::getModificationBulletsGroup(m.name)
      if (groupName!="" && !::isInArray(groupName, groups))
      {
        groups.append(groupName)
        modList.append(m.name)
      }
    }
  return modList
}
/*
::getActiveBulletsModificationName <- function getActiveBulletsModificationName(air, group_index)
{
  if (typeof(air) == "string")
    air = getAircraftByName(air)
  if (!air || !("modifications" in air))
    return null

  local groupsCount = 0
  if (air.unitType.canUseSeveralBulletsForGun)
    groupsCount = ::BULLETS_SETS_QUANTITY
  else
    groupsCount = ::getBulletsGroupCount(air);

  if (group_index >= 0 && group_index < groupsCount)
    return air.unitType.canUseSeveralBulletsForGun ? ::get_unit_option(air.name, ::USEROPT_BULLETS0 + group_index) : ::get_last_bullets(air.name, group_index)
  return null; //no group
}
*/

::check_bad_weapons <- function check_bad_weapons()
{
  foreach(unit in ::all_units)
  {
    if (!unit.isUsable())
      continue

    local curWeapon = ::get_last_weapon(unit.name)
    if (curWeapon=="")
      continue

    if (!::shop_is_weapon_available(unit.name, curWeapon, false, false) && !::shop_is_weapon_purchased(unit.name, curWeapon))
      ::set_last_weapon(unit.name, "")
  }
}

::get_reload_time_by_caliber <- function get_reload_time_by_caliber(caliber, ediff = null)
{
  local diff = ::get_difficulty_by_ediff(ediff ?? ::get_current_ediff())
  if (diff != ::g_difficulty.ARCADE)
    return null
  return ::reload_cooldown_time?[caliber]
}

::isModMaxExp <- function isModMaxExp(air, mod)
{
  return ::shop_get_module_exp(air.name, mod.name) >= ::getTblValue("reqExp", mod, 0)
}

::can_buy_weapons_item <- function can_buy_weapons_item(air, item)
{
  return ::g_weaponry_types.getUpgradeTypeByItem(item).canBuy(air, item)
}

::canBuyMod <- function canBuyMod(air, mod)
{
  local status = ::shop_get_module_research_status(air.name, mod.name)
  if (status & ::ES_ITEM_STATUS_CAN_BUY)
    return true

  if (status & (::ES_ITEM_STATUS_MOUNTED | ::ES_ITEM_STATUS_OWNED))
  {
    local amount = ::getAmmoAmount(air, mod.name, AMMO.MODIFICATION)
    local maxAmount = ::getAmmoMaxAmount(air, mod.name, AMMO.MODIFICATION)
    return amount < maxAmount
  }

  return false
}

::isModResearched <- function isModResearched(air, mod)
{
  local status = ::shop_get_module_research_status(air.name, mod.name)
  if (status & (::ES_ITEM_STATUS_CAN_BUY | ES_ITEM_STATUS_OWNED | ES_ITEM_STATUS_MOUNTED | ES_ITEM_STATUS_RESEARCHED))
    return true

  return false
}

::find_any_not_researched_mod <- function find_any_not_researched_mod(unit)
{
  if (!("modifications" in unit))
    return null

  foreach(mod in unit.modifications)
    if (::canResearchMod(unit, mod) && !::isModResearched(unit, mod))
      return mod

  return null
}

::isModClassPremium <- function isModClassPremium(moduleData)
{
  return ::getTblValue("modClass", moduleData, "") == "premium"
}

::is_modclass_expendable <- function is_modclass_expendable(moduleData)
{
  return ::getTblValue("modClass", moduleData, "") == "expendable"
}

::canResearchMod <- function canResearchMod(air, mod, checkCurrent = false)
{
  local status = ::shop_get_module_research_status(air.name, mod.name)
  local canResearch = checkCurrent ? status == ::ES_ITEM_STATUS_CAN_RESEARCH :
                        0 != (status & (::ES_ITEM_STATUS_CAN_RESEARCH | ::ES_ITEM_STATUS_IN_RESEARCH))

  return canResearch
}

::is_mod_available_or_free <- function is_mod_available_or_free(unitName, modName)
{
  return (::shop_is_modification_available(unitName, modName, true)
          || (!::wp_get_modification_cost(unitName, modName) && !wp_get_modification_cost_gold(unitName, modName)))
}

local getModBlock = function(modName, blockName, templateKey)
{
  local modsBlk = ::get_modifications_blk()
  local modBlock = modsBlk?.modifications?[modName]
  if (!modBlock || modBlock?[blockName])
    return modBlock?[blockName]
  local tName = modBlock?[templateKey]
  return tName ? modsBlk?.templates?[tName]?[blockName] : null
}

::is_mod_upgradeable <- @(modName) getModBlock(modName, "upgradeEffect", "modUpgradeType")
::has_active_overdrive <- @(unitName, modName) ::get_modifications_overdrive(unitName).len() > 0
  && getModBlock(modName, "overdriveEffect", "modOverdriveType")

::is_weapon_enabled <- function is_weapon_enabled(unit, weapon)
{
  return ::shop_is_weapon_available(unit.name, weapon.name, true, false) //no point to check purchased unit even in respawn screen
         //temporary hack: check ammo amount for forced units by mission,
         //because shop_is_weapon_available function work incorrect with them
         && (!::is_game_mode_with_spendable_weapons()
             || ::getAmmoAmount(unit, weapon.name, AMMO.WEAPON)
             || !::getAmmoMaxAmount(unit, weapon.name, AMMO.WEAPON)
            )
         && (!::is_in_flight() || ::g_mis_custom_state.getCurMissionRules().isUnitWeaponAllowed(unit, weapon))
}

::is_weapon_unlocked <- function is_weapon_unlocked(unit, weapon)
{
  foreach(rp in ["reqWeapon", "reqModification"])
      if (rp in weapon)
        foreach (req in weapon[rp])
          if (rp == "reqWeapon" && !::shop_is_weapon_purchased(unit.name, req))
            return false
          else
          if (rp == "reqModification" && !::shop_is_modification_purchased(unit.name, req))
            return false
  return true
}

::is_weapon_visible <- function is_weapon_visible(unit, weapon, onlyBought = true, weaponTags = null)
{
  if (::isWeaponAux(weapon))
    return false

  if (weaponTags != null)
  {
    local hasTag = false
    foreach(t in weaponTags)
      if (::getTblValue(t, weapon))
      {
        hasTag = true
        break
      }
    if (!hasTag)
      return false
  }

  if (onlyBought &&  !::shop_is_weapon_purchased(unit.name, weapon.name)
      && ::getAmmoCost(unit, weapon.name, AMMO.WEAPON) > ::zero_money)
    return false

  return true
}

::get_weapon_by_name <- function get_weapon_by_name(unit, weaponName)
{
  if (!("weapons" in unit))
    return null

  return ::u.search(unit.weapons, (@(weaponName) function(weapon) {
      return weapon.name == weaponName
    })(weaponName))
}

::getAllModsPrice <- function getAllModsPrice(unit, countGold = true)
{
  if (!unit)
    return ::zero_money

  local totalPrice = ::Cost()
  foreach(modification in ::getTblValue("modifications", unit, {}))
    if (::getAmmoMaxAmount(unit, modification.name, AMMO.MODIFICATION) == 1
      && ::wp_get_modification_cost_gold(unit.name, modification.name) == 0
      && !::shop_is_modification_purchased(unit.name, modification.name))
    {
      if (::isModResearched(unit, modification))
        totalPrice.wp += ::wp_get_modification_cost(unit.name, modification.name)
      if (countGold)
        totalPrice.gold += ::wp_get_modification_open_cost_gold(unit.name, modification.name)
    }

  return totalPrice
}

::get_all_modifications_cost <- function get_all_modifications_cost(unit, open = false)
{
  local modsCost = ::Cost()
  foreach(modification in ::getTblValue("modifications", unit, {}))
  {
    local statusTbl = ::weaponVisual.getItemStatusTbl(unit, modification)
    if (statusTbl.maxAmount == statusTbl.amount)
      continue

    local skipSummary = false
    local _modCost = ::Cost()

    if (open)
    {
      local openCost = ::weaponVisual.getItemUnlockCost(unit, modification)
      if (!openCost.isZero())
        _modCost = openCost
    }

    if (::canBuyMod(unit, modification))
    {
      local modificationCost = ::weaponVisual.getItemCost(unit, modification)
      if (!modificationCost.isZero())
      {
        skipSummary = statusTbl.maxAmount > 1

        if (modificationCost.gold > 0)
          skipSummary = true

        _modCost = modificationCost
      }
    }

    // premium modifications or ammo is separated,
    // so no need to show it's price with other modifications.
    if (skipSummary)
      continue

    modsCost += _modCost
  }

  return modsCost
}

::prepareUnitsForPurchaseMods <- {
  unitsTable = {} //unitName - unitBlock

  function clear() { unitsTable = {} }
  function getUnits() { return unitsTable }
  function haveUnits() { return unitsTable.len() > 0 }

  function addUnit(unit)
  {
    if (!unit)
      return

    unitsTable[unit.name] <- unit
  }

  function checkUnboughtMods(silent = false)
  {
    if (!haveUnits())
      return

    local cost = ::Cost()
    local unitsWithNBMods = []
    local stringOfUnits = []

    foreach(unitName, unit in unitsTable)
    {
      local modsCost = ::get_all_modifications_cost(unit)
      if (modsCost.isZero())
        continue

      cost += modsCost
      unitsWithNBMods.append(unit)
      stringOfUnits.append(::colorize("userlogColoredText", ::getUnitName(unit, true)))
    }

    if (unitsWithNBMods.len() == 0)
      return

    if (silent)
    {
      if (::check_balance_msgBox(cost, null, silent))
        ::prepareUnitsForPurchaseMods.purchaseModifications(unitsWithNBMods)
      return
    }

    ::scene_msg_box("buy_all_available_mods", null,
      ::loc("msgbox/buy_all_researched_modifications",
        { unitsList = ::g_string.implode(stringOfUnits, ","), cost = cost.getTextAccordingToBalance() }),
      [["yes", (@(cost, unitsWithNBMods) function() {
          if (!::check_balance_msgBox(cost, function(){::prepareUnitsForPurchaseMods.checkUnboughtMods()}))
            return

          ::prepareUnitsForPurchaseMods.purchaseModifications(unitsWithNBMods)
        })(cost, unitsWithNBMods)],
       ["no", function(){ ::prepareUnitsForPurchaseMods.clear() } ]],
        "yes", { cancel_fn = function() { ::prepareUnitsForPurchaseMods.clear() }})
  }

  function purchaseModifications(unitsArray)
  {
    if (unitsArray.len() == 0)
    {
      ::prepareUnitsForPurchaseMods.clear()
      ::showInfoMsgBox(::loc("msgbox/all_researched_modifications_bought"), "successfully_bought_mods")
      return
    }

    local curUnit = unitsArray.remove(0)
    local afterSuccessFunc = (@(unitsArray) function() {
      ::prepareUnitsForPurchaseMods.purchaseModifications(unitsArray)
    })(unitsArray)

    ::WeaponsPurchase(curUnit, {afterSuccessfullPurchaseCb = afterSuccessFunc, silent = true})
  }
}

::init_bullet_icons <- function init_bullet_icons(blk = null)
{
  if (::bullet_icons.len())
    return

  if (!blk)
    blk = ::configs.GUI.get()

  local ib = blk?.bullet_icons
  if (ib)
    foreach(key, value in ib)
      ::bullet_icons[key] <- value

  local bf = blk?.bullets_features_icons
  if (bf)
    foreach(item in ::bullets_features_img)
      item.values = bf % item.id
}

::is_fake_bullet <- function is_fake_bullet(modName)
{
  return ::g_string.startsWith(modName, ::fakeBullets_prefix)
}

::getModificationByName <- function getModificationByName(unit, modName, isFakeBulletsAllowed = false)
{
  if (!("modifications" in unit))
    return null

  foreach(i, modif in unit.modifications)
    if (modif.name == modName)
      return modif

  if (!isFakeBulletsAllowed)
    return null

  if (::is_fake_bullet(modName))
  {
    local groupIdxStr = ::g_string.slice(modName, ::fakeBullets_prefix.len(), ::fakeBullets_prefix.len() + 1)
    local groupIdx = ::to_integer_safe(groupIdxStr, -1)
    if (groupIdx < 0)
      return null
    return {
      name = modName
      isDefaultForGroup = groupIdx
    }
  }

  // Attempt to get modification from group index (e.g. default modification).
  local groupIndex = ::get_bullet_group_index(unit.name, modName)
  if (groupIndex >= 0)
    return { name = modName, isDefaultForGroup = groupIndex }

  return null
}

::append_one_bullets_item <- function append_one_bullets_item(descr, modifName, air, amountText, genTexts, enabled = true)
{
  local item =  { enabled = enabled }
  descr.items.append(item)
  descr.values.append(modifName)

  if (!genTexts)
    return

  item.text    <- ::g_string.implode([ amountText, ::getModificationName(air, modifName)     ], " ")
  item.tooltip <- ::g_string.implode([ amountText, ::getModificationInfo(air, modifName).desc ], " ")
}

::get_bullet_group_index <- function get_bullet_group_index(airName, bulletName)
{
  local group = -1;

    local groupName = ::getModificationBulletsGroup(bulletName);
    if (!groupName || groupName == "")
    {
      //dagor.debug("no group")
      return -1;
    }

    //dagor.debug(groupName)

    for (local groupIndex = 0; groupIndex < ::BULLETS_SETS_QUANTITY; groupIndex++)
    {
      local bulletsList = ::get_bullets_list(airName, groupIndex, {
        needCheckUnitPurchase = false, needOnlyAvailable = false
      })
    /*  foreach(c in bulletsList.values)
      {
        dagor.debug(c.tostring())
      }*/
      if (::find_in_array(bulletsList.values, bulletName) >= 0)
      {
        group = groupIndex;
        break;
      }
    }

  return group;
}

::get_linked_gun_index <- function get_linked_gun_index(group_index, total_groups, canBeDuplicate = true)
{
  if (!canBeDuplicate)
    return group_index
  return (group_index.tofloat() * total_groups / ::BULLETS_SETS_QUANTITY + 0.001).tointeger()
}

::can_bullets_be_duplicate <- function can_bullets_be_duplicate(unit)
{
  return unit.unitType.canUseSeveralBulletsForGun
}

::get_last_fake_bullets_index <- function get_last_fake_bullets_index(unit)
{
  if (!::can_bullets_be_duplicate(unit))
    return ::getBulletsGroupCount(unit, true)
  return ::BULLETS_SETS_QUANTITY - ::getBulletsGroupCount(unit, false) + ::getBulletsGroupCount(unit, true)
}

::get_fake_bullet_name <- function get_fake_bullet_name(bulletIdx)
{
  return ::fakeBullets_prefix + bulletIdx + "_default"
}

local BULLETS_LIST_PARAMS = {
  isOnlyBought = false
  needCheckUnitPurchase = true
  needOnlyAvailable = true
  needTexts = false
  isForcedAvailable = false
}
::get_bullets_list <- function get_bullets_list(airName, groupIdx, params = BULLETS_LIST_PARAMS)
{
  params = BULLETS_LIST_PARAMS.__merge(params)
  local descr = {
    values = []
    isTurretBelt = false
    weaponType = WEAPON_TYPE.GUN
    caliber = 0
    duplicate = false //tank gun bullets can be duplicate to change bullets during the battle

    //only when genText
    items = []
  }
  local air = getAircraftByName(airName)
  if (!air || !("modifications" in air))
    return descr

  local canBeDuplicate = ::can_bullets_be_duplicate(air)
  local groupCount = ::getBulletsGroupCount(air, true)
  if (groupCount <= groupIdx && !canBeDuplicate)
    return descr

  local modTotal = ::getBulletsGroupCount(air, false)
  local firstFakeIdx = canBeDuplicate? ::BULLETS_SETS_QUANTITY : modTotal
  if (firstFakeIdx <= groupIdx)
  {
    local fakeIdx = groupIdx - firstFakeIdx
    local modifName = ::get_fake_bullet_name(fakeIdx)
    local bData = getBulletsSetData(air, modifName)
    if (bData)
    {
      descr.caliber = bData.caliber
      descr.weaponType = bData.weaponType
    }

    ::append_one_bullets_item(descr, modifName, air, "", params.needTexts) //fake default bullet item
    return descr
  }

  local linked_index = ::get_linked_gun_index(groupIdx, modTotal, canBeDuplicate)
  descr.duplicate = canBeDuplicate && groupIdx > 0 && linked_index == ::get_linked_gun_index(groupIdx - 1, modTotal, canBeDuplicate)

  local groups = [];
  for (local modifNo = 0; modifNo < air.modifications.len(); modifNo++)
  {
    local modif = air.modifications[modifNo]
    local modifName = modif.name;

    local groupName = ::getModificationBulletsGroup(modifName);
    if (!groupName || groupName == "")
      continue;

    //get group index
    local currentGroup = ::find_in_array(groups, groupName)
    if (currentGroup == -1)
    {
      currentGroup = groups.len();
      groups.append(groupName);
    }
    if (currentGroup != linked_index)
      continue;

    if (descr.values.len()==0)
    {
      local bData = getBulletsSetData(air, modifName)
      if (!bData || bData.useDefaultBullet)
        ::append_one_bullets_item(descr, groupName + "_default", air, "", params.needTexts); //default bullets
      if ("isTurretBelt" in modif)
        descr.isTurretBelt = modif.isTurretBelt
      if (bData)
      {
        descr.caliber = bData.caliber
        descr.weaponType = bData.weaponType
      }
    }

    if (params.needOnlyAvailable && !params.isForcedAvailable
        && !::is_mod_available_or_free(airName, modifName))
      continue

    local enabled = !params.isOnlyBought || ::shop_is_modification_purchased(airName, modifName) != 0
    local amountText = params.needCheckUnitPurchase && ::is_game_mode_with_spendable_weapons() ?
      getAmmoAmountData(air, modifName, AMMO.MODIFICATION).text : "";

    ::append_one_bullets_item(descr, modifName, air, amountText, params.needTexts, enabled);
  }
  return descr
}

::get_bullets_list_header <- function get_bullets_list_header(unit, bulletsList)
{
  local locId = ""
  if (bulletsList.weaponType == WEAPON_TYPE.ROCKET)
    locId = "modification/_rockets"
  else if (::isInArray(bulletsList.weaponType, [ WEAPON_TYPE.AAM, WEAPON_TYPE.AGM ]))
    locId = "modification/_missiles"
  else if (bulletsList.weaponType == WEAPON_TYPE.FLARES)
    locId = "modification/_flares"
  else if (bulletsList.weaponType == WEAPON_TYPE.SMOKE_SCREEN)
    locId = "modification/_smoke_screen"
  else if (bulletsList.weaponType == WEAPON_TYPE.GUN)
  {
    if (unit.unitType.canUseSeveralBulletsForGun)
      locId = ::isCaliberCannon(bulletsList.caliber)? "modification/_tank_gun_pack" : "modification/_tank_minigun_pack"
    else
      locId = bulletsList.isTurretBelt ? "modification/_turret_belt_pack/short" : "modification/_belt_pack/short"
  }
  return ::format(::loc(locId), bulletsList.caliber.tostring())
}

//to get exact same bullets list as in standart options
::get_options_bullets_list <- function get_options_bullets_list(air, groupIndex, needTexts = false, isForcedAvailable = false)
{
  local checkPurchased = ::get_gui_options_mode() != ::OPTIONS_MODE_TRAINING
  local res = ::get_bullets_list(air.name, groupIndex, {
    isOnlyBought = checkPurchased
    needCheckUnitPurchase = checkPurchased
    needTexts = needTexts
    isForcedAvailable = isForcedAvailable
  }) //only_bought=true

  local curModif = air.unitType.canUseSeveralBulletsForGun ? ::get_unit_option(air.name, ::USEROPT_BULLETS0 + groupIndex)
                                 : ::get_last_bullets(air.name, groupIndex)
  local value = curModif? ::find_in_array(res.values, curModif) : -1

  if (value < 0 || !res.items[value].enabled)
  {
    value = 0
    local canBeDuplicate = ::can_bullets_be_duplicate(air)
    local skipIndex = canBeDuplicate ? groupIndex : 0
    for(local i = 0; i < res.items.len(); i++)
      if (res.items[i].enabled)
      {
        value = i
        if (--skipIndex < 0)
          break
      }
  }

  res.value <- value
  return res
}

::set_unit_last_bullets <- function set_unit_last_bullets(unit, groupIndex, value)
{
  if (unit.unitType.canUseSeveralBulletsForGun)
    ::set_unit_option(unit.name, ::USEROPT_BULLETS0 + groupIndex, value)

  local saveValue = value
  local modif = ::getModificationByName(unit, value)
  if (!modif) //default modification
    saveValue = ""

  //if (bulletsValue != null && ::get_gui_options_mode() == ::OPTIONS_MODE_TRAINING)
  dagor.debug("set_last_bullets " + value)
  local curBullets = ::get_last_bullets(unit.name, groupIndex)
  if (curBullets != saveValue) {
    ::set_last_bullets(unit.name, groupIndex, saveValue)
    ::broadcastEvent("UnitBulletsChanged", { unit = unit, groupIdx = groupIndex, bulletName = value })
  }
}

::isAirHaveAnyWeaponsTags <- function isAirHaveAnyWeaponsTags(air, tags, checkPurchase = true)
{
  if (!air)
    return false

  foreach(w in air.weapons)
    if (::shop_is_weapon_purchased(air.name, w.name) > 0 || !checkPurchase)
      foreach(tag in tags)
        if ((tag in w) && w[tag])
          return true
  return false
}

::get_weapons_list <- function get_weapons_list(aircraft, need_cost, wtags, only_bought=false, check_aircraft_purchased=true)
{
  local descr = {}
  descr.items <- []
  descr.values <- []
  descr.cost <- []
  descr.costGold <- []
  descr.hints <- []

  local unit = ::getAircraftByName(aircraft)
  if (!unit)
    return descr

  local optionSeparator = ", "
  local hintSeparator = "\n"

  foreach(weapNo, weapon in unit.weapons)
  {
    local weaponName = weapon.name
    if (!::is_weapon_visible(unit, weapon, only_bought, wtags))
      continue

    local cost = ::getAmmoCost(unit, weaponName, AMMO.WEAPON)
    descr.cost.append(cost.wp)
    descr.costGold.append(cost.gold)
    descr.values.append(weaponName)

    local costText = (need_cost && cost > ::zero_money)? "(" + cost.getUncoloredWpText() + ") " : ""
    local amountText = check_aircraft_purchased && ::is_game_mode_with_spendable_weapons() ?
      ::getAmmoAmountData(unit, weaponName, AMMO.WEAPON).text : "";

    local tooltip = costText + ::getWeaponInfoText(unit, { isPrimary = false, weaponPreset = weapNo, newLine = hintSeparator })
      + amountText

    descr.items.append({
      text = costText + ::getWeaponNameText(unit, false, weapNo, optionSeparator) + amountText
      tooltip = tooltip
    })
    descr.hints.append(tooltip)
  }

  return descr
}
