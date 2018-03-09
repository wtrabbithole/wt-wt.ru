function get_ship_subtype_by_exp_class(exp_class) {

  local econCommonBlk = get_economy_config_block("common")
  return econCommonBlk?["ship_exp_groups"]?[exp_class] || ::DS_UT_SHIP
}

function ship_get_damage_award(target, unitDamage, totalDamage, evType, awardName = "warpoints") {

  local econBlk = get_economy_config_block(awardName)
  local exp_class = (getWpcostUnitClass(target) == "exp_zero") ? target : getWpcostUnitClass(target)
  local targetSubtype = get_ship_subtype_by_exp_class(exp_class)
  local damageMul = unitDamage
  local baseAward = econBlk.getReal("baseDamageAward_"+targetSubtype, 0.0)

  if (unitDamage < 0 || unitDamage > 1.0
  || totalDamage < 0 || (totalDamage > 0 && unitDamage > totalDamage)) {
    dagor.debug("ship_get_damage_award. ERROR! wrong damage stats for "+awardName+" totalDamage: "+totalDamage+" unitDamage "+unitDamage)
    return 0
  }

  dagor.debug("ship_get_damage_award. "+awardName+" "+evType+". totalDamage: "+totalDamage+" unitDamage: "+unitDamage+" target: "+target)

  if (evType != "shipHit") {
    local econCommonBlk = get_economy_config_block("common")
    local damageThreshold = econCommonBlk.getReal("shipDamageThreshold", 0.7)
    local remainingHpPart = 0.0
    local playerPart = 0.0
    local unitDamageAdd = ship_calc_unit_damage_add(evType, unitDamage, totalDamage, damageThreshold, awardName)
    local unitDamageCalculated = ship_calc_unit_damage(evType, unitDamage, totalDamage, damageThreshold)
    local totalDamageCalculated = totalDamage < damageThreshold? damageThreshold : totalDamage

    playerPart = unitDamageCalculated / totalDamageCalculated
    remainingHpPart = max((1 - totalDamageCalculated), 0)
    damageMul = playerPart * remainingHpPart + unitDamageAdd
    dagor.debug("ship_get_damage_award. "+awardName+" Step 1. damageMul: "+damageMul+" player's part in award "+playerPart+
            " amount of hp to be rewarded: "+remainingHpPart+" unitDamage calculated: "+unitDamageCalculated+" totalDamage calculated "+totalDamageCalculated+" damageAdd "+unitDamageAdd)
  }
  if (damageMul > 1 || damageMul < 0) {
    dagor.debug("ship_get_damage_award. DAMAGE CALC ERROR! damageMul wrong: "+damageMul)
    return 0
  }
  local award = (baseAward * damageMul + 0.5).tointeger()

  dagor.debug("ship_get_damage_award. "+awardName+" Award "+award+" target "+targetSubtype+" baseAward "+baseAward+" damageMul "+damageMul)
  return award
}

function ship_calc_unit_damage(evType, unitDamageIncome, totalDamageIncome, damageThreshold) {

  local unitDamageCalculated = unitDamageIncome
  if (evType == "kill" && totalDamageIncome < damageThreshold) {
    unitDamageCalculated += (damageThreshold - totalDamageIncome)
    unitDamageCalculated = min(unitDamageCalculated, 1)
  }
  return unitDamageCalculated
}

function ship_calc_unit_damage_add(evType, unitDamageIncome, totalDamageIncome, damageThreshold, awardName) {

  local unitDamageAddCalculated = 0
  if (evType == "kill" && totalDamageIncome < damageThreshold) {
    unitDamageAddCalculated = damageThreshold - totalDamageIncome
  }
  unitDamageAddCalculated += awardName == "ranks"? unitDamageIncome : 0
  return unitDamageAddCalculated
}

dagor.debug("shipsAwards script loaded")