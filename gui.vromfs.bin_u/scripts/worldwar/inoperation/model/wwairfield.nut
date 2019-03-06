class ::WwAirfield
{
  index  = -1
  size   = 0
  side   = ::SIDE_NONE
  pos    = null
  armies = null
  formations = null
  cooldownFormations = null
  clanFormation = null
  allyFormation = null
  createArmyMorale = 0

  constructor(airfieldIndex)
  {
    index  = airfieldIndex
    pos    = ::Point2()
    armies = []
    formations = []
    cooldownFormations = []
    clanFormation = null
    allyFormation = null

    if (airfieldIndex < 0)
      return

    update()
  }

  function isValid()
  {
    return index >= 0
  }

  function getIndex()
  {
    return index
  }

  function update()
  {
    createArmyMorale = ::g_world_war.getWWConfigurableValue("airfieldCreateArmyMorale", 0)

    local blk = ::DataBlock()
    ::ww_get_airfield_info(index, blk)

    if ("specs" in blk)
    {
      side = blk.specs.side? ::ww_side_name_to_val(blk.specs.side) : side
      size = blk.specs.size || size
      pos = blk.specs.pos || pos
    }

    if ("groups" in blk)
      for (local i = 0; i < blk.groups.blockCount(); i++)
      {
        local itemBlk = blk.groups.getBlock(i)
        local formation = ::WwAirfieldFormation(itemBlk, this)
        formations.push(formation)

        if (formation.isBelongsToMyClan())
        {
          clanFormation = formation
          clanFormation.setFormationID(WW_ARMY_RELATION_ID.CLAN)
          clanFormation.setName("formation_" + WW_ARMY_RELATION_ID.CLAN)
        }
        else
        {
          if (!allyFormation)
          {
            allyFormation = ::WwCustomFormation(itemBlk, this)
            allyFormation.setFormationID(WW_ARMY_RELATION_ID.ALLY)
            allyFormation.setName("formation_" + WW_ARMY_RELATION_ID.ALLY)
            allyFormation.setUnitType(::WwAirfieldFormation.unitType)
            allyFormation.setMapObjectName(::WwAirfieldFormation.mapObjectName)
          }
          allyFormation.addUnits(itemBlk)
        }

        local cooldownsBlk = itemBlk.getBlockByName("cooldownUnits")
        for (local j = 0; j < cooldownsBlk.blockCount(); j++)
        {
          local cdFormation = ::WwAirfieldCooldownFormation(cooldownsBlk.getBlock(j), this)
          cdFormation.owner = ::WwArmyOwner(itemBlk.getBlockByName("owner"))
          cdFormation.setFormationID(j)
          cdFormation.setName("cooldown_" + j)
          cooldownFormations.push(cdFormation)
        }
      }

    if ("armies" in blk)
      armies = blk.armies % "item"
  }

  function tostring()
  {
    local returnText = "AIRFIELD: index = " + index + ", side = " + side + ", size = " + size + ", pos = " + ::toString(pos)
    if (formations.len())
      returnText += ", groups len = " + formations.len()
    if (armies.len())
      returnText += ", armies len = " + armies.len()
    return returnText
  }

  function isArmyBelongsTo(army)
  {
    return ::isInArray(army.name, armies)
  }

  function getSide()
  {
    return side
  }

  function getSize()
  {
    return size
  }

  function getPos()
  {
    return pos
  }

  function getUnitsNumber(needToAddCooldown = true)
  {
    local count = 0
    foreach (formation in formations)
      count += formation.getUnitsNumber()

    if (needToAddCooldown)
      foreach (formation in cooldownFormations)
        count += formation.getUnitsNumber()

    return count
  }

  function getUnitsInFlyNumber()
  {
    local unitsNumber = 0
    foreach (armyName in armies)
    {
      local army = ::g_world_war.getArmyByName(armyName)
      if (army.isValid())
      {
        army.updateUnits()
        unitsNumber += army.getUnitsNumber()
      }
    }

    return unitsNumber
  }

  function isMySide(checkSide)
  {
    return getSide() == checkSide
  }

  function getCooldownsWithManageAccess()
  {
    return ::u.filter(cooldownFormations, function(formation) { return formation.hasManageAccess() })
  }

  function getCooldownArmiesByGroupIdx(groupIdx)
  {
    return ::u.filter(cooldownFormations,
      @(formation) formation.getArmyGroupIdx() == groupIdx)
  }

  function getCooldownArmiesNumberByGroupIdx(groupIdx)
  {
    return getCooldownArmiesByGroupIdx(groupIdx).len()
  }

  function hasEnoughUnitsToFly()
  {
    foreach (formation in formations)
      if (hasFormationEnoughUnitsToFly(formation))
        return true

    return false
  }

  function hasFormationEnoughUnitsToFly(formation)
  {
    if (!formation || !formation.isValid() || !formation.hasManageAccess())
      return false

    local airClassesAmount = {
      [WW_UNIT_CLASS.FIGHTER] = 0,
      [WW_UNIT_CLASS.BOMBER] = 0
    }
    local customClassAmount = 0
    local customClassWeaponMask = ::g_world_war.getWWConfigurableValue("fighterToAssaultWeaponMask", 0)
    local wpcostBlk = ::get_wpcost_blk()
    foreach (unit in formation.units)
    {
      local flyOutUnitClass = unit.getUnitClassData().flyOutUnitClass
      if (!(flyOutUnitClass in airClassesAmount))
        continue

      airClassesAmount[flyOutUnitClass] += unit.count

      if (flyOutUnitClass != WW_UNIT_CLASS.FIGHTER)
        continue

      foreach (weapon in wpcostBlk?[unit.getId()]?.weapons ?? {})
        if (weapon.weaponmask & customClassWeaponMask)
        {
          customClassAmount += unit.count
          break
        }
    }

    local operation = ::g_operations.getCurrentOperation()
    local flyoutRange = operation.getUnitsFlyoutRange()
    foreach (mask in [WW_UNIT_CLASS.FIGHTER, WW_UNIT_CLASS.COMBINED])
    {
      local additionalAirs = 0
      local hasEnough = false
      foreach (unitClass in [WW_UNIT_CLASS.FIGHTER, WW_UNIT_CLASS.BOMBER])
      {
        local amount = airClassesAmount?[unitClass] ?? 0
        local unitRange = operation.getQuantityToFlyOut(unitClass, mask, flyoutRange)

        hasEnough = amount + additionalAirs >= unitRange.x
        if (!hasEnough)
          break

        if (unitClass == WW_UNIT_CLASS.FIGHTER && amount > unitRange.x)
          additionalAirs = ::min(amount - unitRange.x, customClassAmount)
      }

      if (hasEnough)
        return true
    }

    return false
  }

  getAvailableFormations = @() isValid()
    ? ::u.filter(formations, @(formation) formation.hasManageAccess()) : []

  getFormationByGroupIdx = @(groupIdx)
    ::u.search(formations, @(group) group.owner.armyGroupIdx == groupIdx)
}
