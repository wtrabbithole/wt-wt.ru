class ::WwAirfieldCooldownFormation extends ::WwAirfieldFormation
{
  cooldownFinishedMillis = 0

  constructor(blk, airfield)
  {
    units = []
    update(blk, airfield)
  }

  function update(blk, airfield)
  {
    units = ::WwUnit.loadUnitsFromBlk(blk.getBlockByName("units"))
    morale = airfield.createArmyMorale
    if ("cooldownFinishedMillis" in blk)
      cooldownFinishedMillis = blk.cooldownFinishedMillis
  }

  function clear()
  {
    base.clear()
    cooldownFinishedMillis = 0
  }

  function getCooldownTime()
  {
    return ::max(0, (cooldownFinishedMillis - ::ww_get_operation_time_millisec()))
  }

  function getCooldownText()
  {
    local cooldownTime = getCooldownTime()
    if (cooldownTime == 0)
      return ::loc("worldwar/state/ready")

    return ::secondsToString(::milliseconds_to_seconds(cooldownTime), false)
  }
}
