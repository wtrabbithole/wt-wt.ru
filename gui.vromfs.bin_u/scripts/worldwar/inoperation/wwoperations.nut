::g_operations <- {
  operationStatusById = {}

  UPDATE_REFRESH_DELAY = 1000

  lastUpdateTime = 0
  updateRequested = false
}

/******************* Public ********************/

function g_operations::fullUpdate()
{
  if (!updateRequested)
    return

  local curTime = ::dagor.getCurTime()
  if (curTime - lastUpdateTime < UPDATE_REFRESH_DELAY)
    return

  getCurrentOperation().update()

  lastUpdateTime = curTime
  updateRequested = false
}

function g_operations::getArmiesByStatus(status)
{
  return getCurrentOperation().armies.getArmiesByStatus(status)
}

function g_operations::getArmiesCache()
{
  return getCurrentOperation().armies.armiesByStatusCache
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
  updateRequested = true
}

function g_operations::onEventWWLoadOperation(params)
{
  updateRequested = true
  fullUpdate()
}

function g_operations::onEventWWArmyPathTrackerStatus(params)
{
  local armyName = ::getTblValue("army", params)
  getCurrentOperation().armies.updateArmyStatus(armyName)
}

::subscribe_handler(::g_operations, ::g_listener_priority.DEFAULT_HANDLER)