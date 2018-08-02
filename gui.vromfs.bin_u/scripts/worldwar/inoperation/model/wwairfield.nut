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

  function getUnitsNumber()
  {
    local count = 0
    foreach (formation in formations)
      count += formation.getUnitsNumber()

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
}
