::g_operations <- {
  operationStatusById = {}

  UPDATE_REFRESH_DELAY = 1000

  lastUpdateTime = 0
  isUpdateRequired = false
}

/******************* Public ********************/

function g_operations::forcedFullUpdate()
{
  isUpdateRequired = true
  fullUpdate()
}

function g_operations::fullUpdate()
{
  if (!isUpdateRequired)
    return

  local curTime = ::dagor.getCurTime()
  if (curTime - lastUpdateTime < UPDATE_REFRESH_DELAY)
    return

  getCurrentOperation().update()

  lastUpdateTime = curTime
  isUpdateRequired = false
}

function g_operations::getArmiesByStatus(status)
{
  return getCurrentOperation().armies.getArmiesByStatus(status)
}

function g_operations::getArmiesCache()
{
  return getCurrentOperation().armies.armiesByStatusCache
}

function g_operations::getAirArmiesNumberByGroupIdx(groupIdx)
{
  local armyCount = 0
  foreach (wwArmyByStatus in getArmiesCache())
    foreach (wwArmyByGroup in wwArmyByStatus)
      foreach (wwArmy in wwArmyByGroup)
        if (wwArmy.getArmyGroupIdx() == groupIdx &&
            !(wwArmy.getArmyFlags() & EAF_NO_AIR_LIMIT_ACCOUNTING) &&
            ::g_ww_unit_type.isAir(wwArmy.getUnitType()))
          armyCount++

  return armyCount
}

function g_operations::getAllOperationUnitsBySide(side)
{
  local operationUnits = {}
  local blk = ::DataBlock()
  ::ww_get_sides_info(blk)

  local sidesBlk = blk["sides"]
  if (sidesBlk == null)
    return operationUnits

  local sideBlk = sidesBlk[side.tostring()]
  if (sideBlk == null)
    return operationUnits

  foreach (unitName in sideBlk.unitsEverSeen % "item")
    if (::getAircraftByName(unitName))
      operationUnits[unitName] <- 0

  return operationUnits
}

/***************** Private ********************/

function g_operations::getCurrentOperation()
{
  local operationId = ::ww_get_operation_id()
  if (!(operationId in operationStatusById))
    operationStatusById[operationId] <- ::WwOperationModel()

  return operationStatusById[operationId]
}

/************* onEvent Handlers ***************/

function g_operations::onEventWWFirstLoadOperation(params)
{
  isUpdateRequired = true
}

function g_operations::onEventWWLoadOperation(params)
{
  forcedFullUpdate()
}

function g_operations::onEventWWArmyPathTrackerStatus(params)
{
  local armyName = ::getTblValue("army", params)
  getCurrentOperation().armies.updateArmyStatus(armyName)
}

::subscribe_handler(::g_operations, ::g_listener_priority.DEFAULT_HANDLER)