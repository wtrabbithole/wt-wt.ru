class ::mission_rules.UnitsDeck extends ::mission_rules.Base
{
  needLeftRespawnOnSlots = true

  function getLeftRespawns()
  {
    return ::RESPAWNS_UNLIMITED
  }

  function getRespawnInfoTextForUnitInfo(unit)
  {
    return ::loc("multiplayer/leftTeamUnit",
                 { num = getUnitLeftRespawns(unit) })
  }

  function getUnitLeftRespawns(unit, teamDataBlk = null)
  {
    if (!unit)
      return 0
    local myState = getMyStateBlk()
    local limitedUnits = ::getTblValue("limitedUnits", myState)
    return ::getTblValue(unit.name, limitedUnits, 0)
  }

  function getUnitLeftRespawnsByTeamDataBlk(unit, teamDataBlk)
  {
    if (!unit)
      return 0

    return teamDataBlk?.limitedUnits?[unit.name] ?? ::RESPAWNS_UNLIMITED
  }

  function getSpecialCantRespawnMessage(unit)
  {
    local leftRespawns = getUnitLeftRespawns(unit)
    if (leftRespawns)
      return null
    return ::loc("respawn/noUnitLeft", { unitName = ::colorize("userlogColoredText", ::getUnitName(unit)) })
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
    local myTeamUnitsParamsBlk = getMyTeamDataBlk("unitsParamsList")
    local weaponsLimitsBlk = getWeaponsLimitsBlk()

    if (::u.isDataBlock(limitedBlk))
      for(local i = 0; i < limitedBlk.paramCount(); i++)
      {
        local unitName = limitedBlk.getParamName(i)
        local teamUnitPreset = ::getTblValue(unitName, myTeamUnitsParamsBlk, null)
        local userUnitPreset = ::getTblValue(unitName, weaponsLimitsBlk, null)
        local weapon = ::getTblValue("weapon", teamUnitPreset, null)

        local presetData = {
          weaponPresetId = ::getTblValue("name", weapon, "")
          teamUnitPresetAmount = ::getTblValue("count", weapon, "")
          userUnitPresetAmount = ::getTblValue("respawnsLeft", userUnitPreset, 0)
        }

        local limit = ::g_unit_limit_classes.LimitByUnitName(
          unitName,
          limitedBlk.getParamValue(i),
          ::getTblValue(unitName, distributedBlk, 0),
          presetData
        )

        res.unitLimits.append(limit)
      }
    return res
  }

  function isUnitAvailableForWWSpawnScore(unit)
  {
    return unit && isWorldWar && isUnitForcedVisible(unit.name)
      && getUnitLeftRespawns(unit) == 0
      && getUnitLeftRespawnsByTeamDataBlk(unit, getMyTeamDataBlk()) != 0
  }
}
