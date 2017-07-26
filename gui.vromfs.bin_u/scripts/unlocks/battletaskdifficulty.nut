::g_battle_task_difficulty <- {
  types = []
  template = {}
  cache = {
    byName = {}
    byExecOrder = {}
  }
}

function g_battle_task_difficulty::_getLocName()
{
  return ::loc("battletask/" + timeParamId + "/name")
}

function g_battle_task_difficulty::_getTimeLeftText()
{
  local time = getTimeLeft()
  if (time < 0)
    return ""

  return ::hoursToString(time / TIME_HOUR_IN_SECONDS_F, false, true, true)
}

::g_battle_task_difficulty.template <- {
  getLocName = ::g_battle_task_difficulty._getLocName
  getTimeLeftText = ::g_battle_task_difficulty._getTimeLeftText

  name = ""
  timeParamId = ""
  userlogHeaderName = ""
  image = null
  period = 1
  daysShift = 0
  executeOrder = -1
  lastGenTimeSuccess = -1
  lastGenTimeFailure = -1
  generationPeriodSec = -1
  showAtPositiveProgress = false
  timeLimit = function() { return -1 }
  getTimeLeft = function() { return -1 }
}

::g_enum_utils.addTypesByGlobalName("g_battle_task_difficulty", {
  EASY = {
    image = "#ui/gameuiskin#battle_tasks_easy"
    timeParamId = "daily"
    executeOrder = 0
    timeLimit = function() { return TIME_DAY_IN_SECONDS }
    getTimeLeft = function() { return lastGenTimeSuccess + generationPeriodSec - ::get_charserver_time_sec() }
  }

  MEDIUM = {
    image = "#ui/gameuiskin#battle_tasks_middle"
    timeParamId = "daily"
    executeOrder = 1
    timeLimit = function() { return TIME_DAY_IN_SECONDS }
    getTimeLeft = function() { return lastGenTimeSuccess + generationPeriodSec - ::get_charserver_time_sec() }
  }

  HARD = {
    image = "#ui/gameuiskin#battle_tasks_hard"
    timeParamId = "daily"
    executeOrder = 2
    timeLimit = function() { return TIME_DAY_IN_SECONDS }
    getTimeLeft = function() { return lastGenTimeSuccess + generationPeriodSec - ::get_charserver_time_sec() }
  }

  UNKNOWN = {}

/******** Old types **********/
  WEEKLY = {}
  DAILY = {}
  MONTHLY = {}
/*****************************/
}, null, "name")

g_battle_task_difficulty.types.sort(function(a,b){
  if (a.executeOrder != b.executeOrder)
    return a.executeOrder > b.executeOrder ? 1 : -1
  return 0
})

function g_battle_task_difficulty::getDifficultyTypeByName(typeName)
{
  return ::g_enum_utils.getCachedType("name", typeName, ::g_battle_task_difficulty.cache.byName,
    ::g_battle_task_difficulty, ::g_battle_task_difficulty.UNKNOWN)
}

function g_battle_task_difficulty::getDifficultyTypeByExecuteOrder(typeName)
{
  return ::g_enum_utils.getCachedType("executeOrder", typeName, ::g_battle_task_difficulty.cache.byExecOrder,
    ::g_battle_task_difficulty, ::g_battle_task_difficulty.UNKNOWN)
}

function g_battle_task_difficulty::getDifficultyFromTask(task)
{
  return ::getTblValue("_puType", task, "").toupper()
}

function g_battle_task_difficulty::getDifficultyTypeByTask(task)
{
  return getDifficultyTypeByName(getDifficultyFromTask(task))
}

function g_battle_task_difficulty::getRequiredDifficultyTypeDone(typeName)
{
  foreach(type in types)
    if (type.executeOrder > 0 && typeName == type.name)
      return getDifficultyTypeByExecuteOrder(type.executeOrder - 1)

  return null
}

function g_battle_task_difficulty::getRefreshTimeForAllTypes(tasksArray, overrideStatus = false)
{
  local processedTimeParamIds = []
  if (!overrideStatus)
    foreach(task in tasksArray)
    {
      local type = getDifficultyTypeByTask(task)
      ::append_once(type.timeParamId, processedTimeParamIds)
    }

  local resultArray = []
  foreach(type in types)
  {
    if (::isInArray(type.timeParamId, processedTimeParamIds))
      continue

    processedTimeParamIds.append(type.timeParamId)

    local timeText = type.getTimeLeftText()
    if (timeText != "")
      resultArray.append(type.getLocName() + ::loc("ui/parentheses/space", {text = timeText}))
  }

  return resultArray
}

function g_battle_task_difficulty::canPlayerInteractWithType(checkDiffName, tasksArray, overrideStatus = false)
{
  if (overrideStatus)
    return true

  local reqTypeDone = getRequiredDifficultyTypeDone(checkDiffName)
  if (::u.isEmpty(reqTypeDone))
    return true

  foreach(task in tasksArray)
  {
    if (!::g_battle_tasks.isBattleTask(task) || !::g_battle_tasks.isTaskActual(task))
      continue

    if (::g_battle_tasks.isTaskDone(task))
      continue

    if (getDifficultyTypeByName(checkDiffName).executeOrder <= getDifficultyTypeByTask(task).executeOrder)
      continue

    return false
  }

  return true
}

function g_battle_task_difficulty::updateTimeParamsFromBlk(blk)
{
  foreach(type in types)
  {
    local genTimeId = type.timeParamId + "PersonalUnlocks_lastGenerationTimeOnSuccess"
    type.lastGenTimeSuccess = blk[genTimeId] || -1

    local genTimeId = type.timeParamId + "PersonalUnlocks_lastGenerationTimeOnFailure"
    type.lastGenTimeFailure = blk[genTimeId] || -1

    local genPerSecTimeId = type.timeParamId + "PersonalUnlocks_CUSTOM_generationPeriodSec"
    type.generationPeriodSec = blk[genPerSecTimeId] || -1

    local genPeriodId = type.timeParamId + "PersonalUnlocks_WEEKLY_weeklyPeriod"
    type.period = blk[genPeriodId] || 1

    local genShiftId = type.timeParamId + "PersonalUnlocks_WEEKLY_weekStartDayShift"
    type.daysShift = blk[genShiftId] || 0
  }
}

function g_battle_task_difficulty::checkAvailabilityByProgress(task, overrideStatus = false)
{
  if (overrideStatus)
    return true

  if (!::g_battle_tasks.isTaskDone(task) ||
    !getDifficultyTypeByTask(task).showAtPositiveProgress)
    return true

  local progress = ::get_unlock_progress(task.id, -1)
  return ::getTblValue("curVal", progress, 0) > 0
}

function g_battle_task_difficulty::withdrawTasksArrayByDifficulty(diff, array)
{
  return ::u.filter(array, (@(diff) function(task) {
      return diff == ::g_battle_task_difficulty.getDifficultyTypeByTask(task).name
    })(diff))
}
