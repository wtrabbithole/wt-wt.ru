class ::mission_rules.UnitsDeck extends ::mission_rules.Base
{
  needLeftRespawnOnSlots = true

  function getLeftRespawns()
  {
    return ::RESPAWNS_UNLIMITED
  }

  function getUnitLeftRespawns(unit, teamDataBlk = null)
  {
    if (!unit)
      return 0
    local myState = getMyStateBlk()
    local limitedUnits = ::getTblValue("limitedUnits", myState)
    return ::getTblValue(unit.name, limitedUnits, 0)
  }

  function getSpecialCantRespawnMessage(unit)
  {
    local leftRespawns = getUnitLeftRespawns(unit)
    if (leftRespawns)
      return null
    return ::loc("multiplayer/noTeamUnitLeft", { unitName = ::colorize("userlogColoredText", ::getUnitName(unit)) })
  }

  function hasCustomUnitRespawns()
  {
    local myTeamDataBlk = getMyTeamDataBlk()
    return myTeamDataBlk != null
  }

  function calcFullUnitLimitsData()
  {
    local res = base.calcFullUnitLimitsData()
    res.defaultUnitRespawnsLeft = 0

    local myTeamDataBlk = getMyTeamDataBlk()

    local distributedBlk = ::getTblValue("distributedUnits", myTeamDataBlk)
    local limitedBlk = ::getTblValue("limitedUnits", myTeamDataBlk)
    if (::u.isDataBlock(limitedBlk))
      for(local i = 0; i < limitedBlk.paramCount(); i++)
      {
        local unitName = limitedBlk.getParamName(i)
        local limit = ::g_unit_limit_classes.LimitByUnitName(unitName,
                                                             limitedBlk.getParamValue(i),
                                                             ::getTblValue(unitName, distributedBlk, 0)
                                                            )
        res.unitLimits.append(limit)
      }

    return res
  }
}
