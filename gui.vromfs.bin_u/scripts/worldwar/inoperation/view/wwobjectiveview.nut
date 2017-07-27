class ::WwObjectiveView
{
  id = ""
  type = null
  staticBlk = null
  dynamicBlk = null
  side = null
  status = ""
  statusImg = ""
  zonesList = null

  isLastObjective = false

  constructor(_staticBlk, _dynamicBlk, _side, _isLastObjective = false)
  {
    staticBlk = _staticBlk
    dynamicBlk = _dynamicBlk
    side = ::ww_side_val_to_name(_side)
    type = ::g_ww_objective_type.getTypeByTypeName(staticBlk.type)
    id = staticBlk.getBlockName()
    isLastObjective = _isLastObjective

    local statusType = type.getObjectiveStatus(dynamicBlk.winner, side)
    status = statusType.name
    statusImg = statusType.wwMissionObjImg
    zonesList = type.getUpdatableZonesParams(staticBlk, dynamicBlk, side)
  }

  function getNameId()
  {
    return type.getNameId(staticBlk, side)
  }

  function getName()
  {
    return type.getName(staticBlk, dynamicBlk, side)
  }

  function getDesc()
  {
    return type.getDesc(staticBlk, dynamicBlk, side)
  }

  function getParamsArray()
  {
    return type.getParamsArray(staticBlk, side)
  }

  function getUpdatableData()
  {
    return type.getUpdatableParamsArray(staticBlk, dynamicBlk, side)
  }

  function getUpdatableZonesData()
  {
    return zonesList
  }

  function hasObjectiveZones()
  {
    return zonesList.len()
  }
}
