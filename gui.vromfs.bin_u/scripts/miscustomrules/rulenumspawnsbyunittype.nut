class ::mission_rules.NumSpawnsByUnitType extends ::mission_rules.Base
{
  function getUnitLeftRespawns(unit, teamDataBlk = null)
  {
    return getUnitTypeLeftRespans(get_es_unit_type(unit), getMyStateBlk())
  }

  function getSpecialCantRespawnMessage(unit)
  {
    local leftRespawns = getUnitLeftRespawns(unit)
    if (leftRespawns)
      return null
    return ::loc("multiplayer/noArmyRespawnsLeft",
                 {
                   armyIcon = ::colorize("userlogColoredText", unit.unitType.fontIcon)
                   armyName = unit.unitType.getArmyLocName()
                 })
  }

  function getCurCrewsRespawnMask()
  {
    local res = 0
    if (!getLeftRespawns())
      return res

    local crewsList = ::get_crews_list_by_country(::get_local_player_country())
    local myStateBlk = getMyStateBlk()
    if (!myStateBlk)
      return (1 << crewsList.len()) - 1

    foreach(idx, crew in crewsList)
      if (getUnitTypeLeftRespans(::get_es_unit_type(::g_crew.getCrewUnit(crew)), myStateBlk) != 0)
        res = res | (1 << idx)
    return res
  }

  function getRespawnInfoTextForUnit(unit)
  {
    return ::loc("respawn/leftRespawns",
                 { num = getRespawnInfoText(getMyStateBlk(), getCustomRulesBlk().ruleSet) })
  }

  //stateData is a table or blk
  //baseRules - used to detect which unitTypes require to show
  function getRespawnInfoText(stateData, baseRules = null)
  {
    local typeTexts = []
    foreach(unitType in ::g_unit_type.types)
      if (unitType.isAvailable())
      {
        local resp = getUnitTypeLeftRespans(unitType.esUnitType, stateData)
        if (resp || (baseRules && getUnitTypeLeftRespans(unitType.esUnitType, baseRules)))
          typeTexts.append(unitType.fontIcon + resp)
      }
    return ::colorize("@activeTextColor", ::g_string.implode(typeTexts, ", "))
  }

  function getUnitTypeLeftRespans(esUnitType, stateData) //stateData is a table or blk
  {
    local respawns = ::getTblValue(::get_ds_ut_name_unit_type(esUnitType) + "_numSpawn", stateData, 0)
    return ::max(0, respawns) //dont have unlimited respawns
  }

  function getEventDescByRulesTbl(rulesTbl)
  {
    return ::loc("multiplayer/flyouts") + ::loc("ui/colon") + getRespawnInfoText(::getTblValue("ruleSet", rulesTbl, {}))
  }
}
