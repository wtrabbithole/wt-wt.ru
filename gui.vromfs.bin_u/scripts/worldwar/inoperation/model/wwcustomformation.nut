class ::WwCustomFormation extends ::WwFormation
{
  constructor(blk, airfield)
  {
    units = []
    update(blk, airfield)
  }

  function update(blk, airfield)
  {
    owner = ::WwArmyOwner(blk.getBlockByName("owner"))
    morale = airfield.createArmyMorale
  }

  function clear()
  {
    base.clear()
  }

  function isValid()
  {
    return false
  }

  function getArmyGroup()
  {
    return null
  }

  function addUnits(blk)
  {
    local additionalUnits = ::WwUnit.loadUnitsFromBlk(blk.getBlockByName("units"))
    units.extend(additionalUnits)
    units = ::u.reduce(units, function (unit, memo) {
      foreach (unitInMemo in memo)
        if (unitInMemo.name == unit.name)
        {
          unitInMemo.count += unit.count
          return memo
        }
      memo.append(unit)
      return memo
    }, [])
  }
}
