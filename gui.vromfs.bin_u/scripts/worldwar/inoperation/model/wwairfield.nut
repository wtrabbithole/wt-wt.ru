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
  createArmyUnitCountMin = 0
  createArmyUnitCountMax = 0
  maxUniqueUnitsOnFlyout = 0
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

  function update()
  {
    createArmyUnitCountMin = ::g_world_war.getWWConfigurableValue("airfieldCreateArmyUnitCountMin", 0)
    createArmyUnitCountMax = ::g_world_war.getWWConfigurableValue("airfieldCreateArmyUnitCountMax", 0)
    maxUniqueUnitsOnFlyout = ::g_world_war.getWWConfigurableValue("maxUniqueUnitsOnFlyout", 0)
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
          local cooldown = ::WwAirfieldCooldownFormation(cooldownsBlk.getBlock(j), this)
          cooldown.owner = ::WwArmyOwner(itemBlk.getBlockByName("owner"))
          cooldown.setFormationID(j)
          cooldown.setName("cooldown_" + j)
          cooldownFormations.push(cooldown)
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

  function isMySide(checkSide)
  {
    return getSide() == checkSide
  }

  function getCooldownsWithManageAccess()
  {
    return ::u.filter(cooldownFormations, function(cooldown) { return cooldown.hasManageAccess() })
  }
}
