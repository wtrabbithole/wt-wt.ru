local activeManagerGroupsCount = 0
local armyManagersNames = {}
local currentOperationID = 0

local function updateManagerStat(group, uid, mName, total)
{
  local activity = total > 0
    ? ::round(100 * (group.actionCounts?[uid] ?? 0) / total).tointeger()
    : 0
  group.armyManagers.append({uid = uid, name = mName, activity = activity})
  if(--group.unupdatedCount <=0)
  {
    group.armyManagers.sort(@(a,b) b.activity <=> a.activity)
    if(--activeManagerGroupsCount <= 0)
      ::ww_event("ArmyManagersInfoUpdated")
  }
}

local function getActiveManagerGroupsCount(armyGroups)
{
  local count = 0
  foreach(group in armyGroups)
    if(group.unupdatedCount > 0)
      count++
  return count
}

local function updateArmyManagers(group)
{
  local total = group.actionCounts.reduce(@(res, value) res + value, 0)
  foreach(uid in group.activeManagerUids)
  {
    uid = uid.tostring()
    if(armyManagersNames?[uid] == null)
      ::add_bg_task_cb(::req_player_public_statinfo(uid),
        function(){
          local data = ::DataBlock()
          ::get_player_public_stats(data)
          local userid = data?.userid
          local mName = data?.nick
          if(userid)
          {
            armyManagersNames[userid] <- {name = mName}
            updateManagerStat(group, userid, mName, total)
          }
        }.bindenv(this))
    else
      updateManagerStat(group, uid, armyManagersNames[uid].name, total)
  }
}

function updateManagers()
{
  local operationID = ::ww_get_operation_id()
  local armyGroups = ::g_world_war.armyGroups
  activeManagerGroupsCount = getActiveManagerGroupsCount(armyGroups)
  if(operationID != currentOperationID)
    armyManagersNames = {}

  currentOperationID = operationID
  if(activeManagerGroupsCount == 0)
    return
  foreach(group in armyGroups)
    updateArmyManagers(group)
}

return {
  updateManagers = updateManagers
}
