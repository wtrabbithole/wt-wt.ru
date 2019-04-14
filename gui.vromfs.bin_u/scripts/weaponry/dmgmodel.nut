local stdMath = require("std/math.nut")

const RICOCHET_DATA_ANGLE = 30
const DEFAULT_ARMOR_FOR_PENETRATION_RADIUS = 50

::g_dmg_model <- {
  RICOCHET_PROBABILITIES = [0.0, 0.5, 1.0]

  ricochetDataByBulletType = null
}

/*************************************************************************************************/
/*************************************PUBLIC FUNCTIONS *******************************************/
/*************************************************************************************************/

function g_dmg_model::getDmgModelBlk()
{
  local blk = ::DataBlock()
  blk.load("config/damageModel.blk")
  return blk
}

function g_dmg_model::getRicochetData(bulletType)
{
  initRicochetDataOnce()
  return ::getTblValue(bulletType, ricochetDataByBulletType)
}

function g_dmg_model::getTntEquivalentText(explosiveType, explosiveMass)
{
  if(explosiveType == "tnt")
    return ""
  local blk = getDmgModelBlk()
  local explMassInTNT = ::getTblValueByPath("explosiveTypes." + explosiveType + ".strengthEquivalent", blk, 0)
  if (!explosiveMass || explMassInTNT <= 0)
    return ""
  return ::g_dmg_model.getMeasuredExplosionText(explosiveMass.tofloat() * explMassInTNT)
}

function g_dmg_model::getMeasuredExplosionText(weightValue)
{
  local typeName = "kg"
  if (weightValue < 1.0)
  {
    typeName = "gr"
    weightValue *= 1000
  }
  return ::g_measure_type.getTypeByName(typeName, true).getMeasureUnitsText(weightValue)
}

function g_dmg_model::getDestructionInfoTexts(explosiveType, explosiveMass, ammoMass)
{
  local res = {
    maxArmorPenetrationText = ""
    destroyRadiusArmoredText = ""
    destroyRadiusNotArmoredText = ""
  }

  local dmgModelBlk = getDmgModelBlk()
  local explTypeBlk = ::getTblValueByPath("explosiveTypes." + explosiveType, dmgModelBlk)
  if (!::u.isDataBlock(explTypeBlk))
    return res

  //armored vehicles data
  local explMassInTNT = explosiveMass * (explTypeBlk.strengthEquivalent || 0)
  local splashParamsBlk = dmgModelBlk.explosiveTypeToSplashParams
  if (explMassInTNT && ::u.isDataBlock(splashParamsBlk))
  {
    local maxPenetration = getLinearValueFromP2blk(splashParamsBlk.explosiveMassToPenetration, explMassInTNT)
    local innerRadius = getLinearValueFromP2blk(splashParamsBlk.explosiveMassToInnerRadius, explMassInTNT)
    local outerRadius = getLinearValueFromP2blk(splashParamsBlk.explosiveMassToOuterRadius, explMassInTNT)
    local armorToShowRadus = dmgModelBlk.penetrationToCalcDestructionRadius || DEFAULT_ARMOR_FOR_PENETRATION_RADIUS

    if (maxPenetration)
      res.maxArmorPenetrationText = ::g_measure_type.getTypeByName("mm", true).getMeasureUnitsText(maxPenetration)
    if (maxPenetration >= armorToShowRadus)
    {
      local radius = innerRadius + (outerRadius - innerRadius) * (maxPenetration - armorToShowRadus) / maxPenetration
      res.destroyRadiusArmoredText = ::g_measure_type.getTypeByName("dist_short", true).getMeasureUnitsText(radius)
    }
  }

  //not armored vehicles data
  local fillingRatio = ammoMass ? explosiveMass / ammoMass : 1.0
  local brisanceMass = explosiveMass * (explTypeBlk.brisanceEquivalent || 0)
  local destroyRadiusNotArmored = calcDestroyRadiusNotArmored(dmgModelBlk.explosiveTypeToShattersParams,
                                                              fillingRatio,
                                                              brisanceMass)
  if (destroyRadiusNotArmored > 0)
    res.destroyRadiusNotArmoredText = ::g_measure_type.getTypeByName("dist_short", true).getMeasureUnitsText(destroyRadiusNotArmored)

  return res
}

/*************************************************************************************************/
/************************************PRIVATE FUNCTIONS *******************************************/
/*************************************************************************************************/

function g_dmg_model::resetData()
{
  ricochetDataByBulletType = null
}

function g_dmg_model::getLinearValueFromP2blk(blk, x)
{
  local min = null
  local max = null
  if (::u.isDataBlock(blk))
    for (local i = 0; i < blk.paramCount(); i++)
    {
      local p2 = blk.getParamValue(i)
      if (typeof p2 != "instance" || !(p2 instanceof ::Point2))
        continue

      if (p2.x == x)
        return p2.y

      if (p2.x < x && (!min || p2.x > min.x))
        min = p2
      if (p2.x > x && (!max || p2.x < max.x))
        max = p2
    }
  if (!min)
    return max?.y ?? 0.0
  if (!max)
    return min.y
  return min.y + (max.y - min.y) * (x - min.x) / (max.x - min.x)
}

/** Returns -1 if no such angle found. */
function g_dmg_model::getAngleByProbabilityFromP2blk(blk, x)
{
  for (local i = 0; i < blk.paramCount() - 1; ++i)
  {
    local p1 = blk.getParamValue(i)
    local p2 = blk.getParamValue(i + 1)
    if (typeof p1 != "instance" || !(p1 instanceof ::Point2) ||
        typeof p2 != "instance" || !(p2 instanceof ::Point2))
      continue
    local angle1 = p1.x
    local probability1 = p1.y
    local angle2 = p2.x
    local probability2 = p2.y
    if ((probability1 <= x && x <= probability2) || (probability2 <= x && x <= probability1))
    {
      if (probability1 == probability2)
      {
        // This means that we are on the left side of
        // probability-by-angle curve.
        if (x == 1)
          return ::max(angle1, angle2)
        else
          return ::min(angle1, angle2)
      }
      return stdMath.lerp(probability1, probability2, angle1, angle2, x)
    }
  }
  return -1
}

/** Returns -1 if nothing found. */
function g_dmg_model::getMaxProbabilityFromP2blk(blk)
{
  local result = -1
  for (local i = 0; i < blk.paramCount(); ++i)
  {
    local p = blk.getParamValue(i)
    if (typeof p == "instance" && p instanceof ::Point2)
      result = ::max(result, p.y)
  }
  return result
}

function g_dmg_model::initRicochetDataOnce()
{
  if (ricochetDataByBulletType)
    return

  ricochetDataByBulletType = {}
  local blk = getDmgModelBlk()
  if (!blk)
    return

  local typesList = blk.bulletTypes
  local ricBlk = blk.ricochetPresets
  if (!typesList || !ricBlk)
  {
    ::dagor.assertf(false, "ERROR: Can't load ricochet params from damageModel.blk")
    return
  }

  local defaultData = getRicochetDataByPreset({
                        ricochetPreset = "default"
                      },
                      ricBlk)
  ricochetDataByBulletType[""] <- defaultData

  for (local i = 0; i < typesList.blockCount(); i++)
  {
    local presetBlk = typesList.getBlock(i)
    local bulletType = presetBlk.getBlockName()
    ricochetDataByBulletType[bulletType] <- getRicochetDataByPreset(presetBlk, ricBlk, defaultData)
  }
}

function g_dmg_model::getRicochetDataByPreset(preset, ricBlk, defaultData = null)
{
  local res = {
    angleProbabilityMap = []
  }
  local rPreset = preset.ricochetPreset
  local ricochetPresetBlk = getRichochetPresetBlkByName(rPreset, ricBlk)
  if (ricochetPresetBlk != null)
  {
    local addMaxProbability = false
    for (local i = 0; i < RICOCHET_PROBABILITIES.len(); ++i)
    {
      local probability = RICOCHET_PROBABILITIES[i]
      local angle = getAngleByProbabilityFromP2blk(ricochetPresetBlk, probability)
      if (angle != -1)
      {
        res.angleProbabilityMap.push({
          probability = probability
          angle = 90.0 - angle
        })
      }
      else
        addMaxProbability = true
    }

    // If, say, we didn't find angle with 100% ricochet chance,
    // then showing angle for max possible probability.
    if (addMaxProbability)
    {
      local maxProbability = getMaxProbabilityFromP2blk(ricochetPresetBlk)
      local angleAtMaxProbability = getAngleByProbabilityFromP2blk(ricochetPresetBlk, maxProbability)
      if (maxProbability != -1 && angleAtMaxProbability != -1)
      {
        res.angleProbabilityMap.push({
          probability = maxProbability
          angle = 90.0 - angleAtMaxProbability
        })
      }
    }
  }
  return res
}

function g_dmg_model::getRichochetPresetBlkByName(presetName, ricBlk)
{
  if (presetName == null || ricBlk[presetName] == null)
    return null
  local presetData = ricBlk[presetName]
  // First cycle through all preset blocks searching
  // for block with "caliberToArmor:r = 1".
  for (local i = 0; i < presetData.blockCount(); ++i)
  {
    local presetBlock = presetData.getBlock(i)
    if (presetBlock.caliberToArmor == 1)
      return presetBlock
  }
  // If no such block found then try to find block
  // without "caliberToArmor" property.
  for (local i = 0; i < presetData.blockCount(); ++i)
  {
    local presetBlock = presetData.getBlock(i)
    if (!("caliberToArmor" in presetBlock))
      return presetBlock
  }
  // If still nothing found then return presetData
  // as it is a preset block itself.
  return presetData
}

function g_dmg_model::calcDestroyRadiusNotArmored(shattersParamsBlk, fillingRatio, brisanceMass)
{
  if (!::u.isDataBlock(shattersParamsBlk) || !brisanceMass)
    return 0

  for (local i = 0; i < shattersParamsBlk.blockCount(); i++)
  {
    local blk = shattersParamsBlk.getBlock(i)
    if (fillingRatio > (blk.fillingRatio || 0))
      continue

    return getLinearValueFromP2blk(blk.explosiveMassToRadius, brisanceMass)
  }
  return 0
}

function g_dmg_model::onEventSignOut(p)
{
  resetData()
}

::subscribe_handler(::g_dmg_model, ::g_listener_priority.CONFIG_VALIDATION)