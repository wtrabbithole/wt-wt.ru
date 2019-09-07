local enums = ::require("sqStdlibs/helpers/enums.nut")
local time = require("scripts/time.nut")

::g_battle_task_difficulty <- {
  types = []
  template = {}
  cache = {
    byName = {}
    byExecOrder = {}
  }
}

g_battle_task_difficulty._getTimeLeftText <- function _getTimeLeftText()
{
  local timeLeft = getTimeLeft()
  if (timeLeft < 0)
    return ""

  return time.hoursToString(time.secondsToHours(timeLeft), false, true, true)
}

::g_battle_task_difficulty.template <- {
  getLocName = @() ::loc("battleTasks/" + timeParamId + "/name")
  getTimeLeftText = ::g_battle_task_difficulty._getTimeLeftText
  getDifficultyGroup = @() timeParamId

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
  showSeasonIcon = false
  canIncreaseShopLevel = true
  hasTimer = true
}

enums.addTypesByGlobalName("g_battle_task_difficulty", {
  EASY = {
    image = "#ui/gameuiskin#battle_tasks_easy"
    timeParamId = "daily"
    executeOrder = 0
    timeLimit = function() { return time.daysToSeconds(1) }
    getTimeLeft = function() { return lastGenTimeSuccess + generationPeriodSec - ::get_charserver_time_sec() }
  }

  MEDIUM = {
    image = "#ui/gameuiskin#battle_tasks_middle"
    timeParamId = "daily"
    executeOrder = 1
    timeLimit = function() { return time.daysToSeconds(1) }
    getTimeLeft = function() { return lastGenTimeSuccess + generationPeriodSec - ::get_charserver_time_sec() }
  }

  HARD = {
    image = "#ui/gameuiskin#hard_task_medal3"
    showSeasonIcon = true
    canIncreaseShopLevel = false
    timeParamId = "specialTasks"
    timeLimit = function() { return time.daysToSeconds(1) }
    getTimeLeft = function() { return lastGenTimeSuccess + generationPeriodSec - ::get_charserver_time_sec() }
    hasTimer = false
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

g_battle_task_difficulty.getDifficultyTypeByName <- function getDifficultyTypeByName(typeName)
{
  return enums.getCachedType("name", typeName, ::g_battle_task_difficulty.cache.byName,
    ::g_battle_task_difficulty, ::g_battle_task_difficulty.UNKNOWN)
}

g_battle_task_difficulty.getDifficultyFromTask <- function getDifficultyFromTask(task)
{
  return ::getTblValue("_puType", task, "").toupper()
}

g_battle_task_difficulty.getDifficultyTypeByTask <- function getDifficultyTypeByTask(task)
{
  return getDifficultyTypeByName(getDifficultyFromTask(task))
}

g_battle_task_difficulty.getRequiredDifficultyTypeDone <- function getRequiredDifficultyTypeDone(diff)
{
  local res = null
  if (diff.executeOrder >= 0)
    res = ::u.search(types, @(t) t.executeOrder == (diff.executeOrder-1))

  return res || ::g_battle_task_difficulty.UNKNOWN
}

g_battle_task_difficulty.getRefreshTimeForAllTypes <- function getRefreshTimeForAllTypes(tasksArray, overrideStatus = false)
{
  local processedTimeParamIds = []
  if (!overrideStatus)
    foreach(task in tasksArray)
    {
      local t = getDifficultyTypeByTask(task)
      ::u.appendOnce(t.timeParamId, processedTimeParamIds)
    }

  local resultArray = []
  foreach(t in types)
  {
    if (::isInArray(t.timeParamId, processedTimeParamIds))
      continue

    processedTimeParamIds.append(t.timeParamId)

    local timeText = t.getTimeLeftText()
    if (timeText != "")
      resultArray.append(t.getLocName() + ::loc("ui/parentheses/space", {text = timeText}))
  }

  return resultArray
}

g_battle_task_difficulty.canPlayerInteractWithDifficulty <- function canPlayerInteractWithDifficulty(diff, tasksArray, overrideStatus = false)
{
  if (overrideStatus)
    return true

  local reqDiffDone = getRequiredDifficultyTypeDone(diff)
  if (reqDiffDone == ::g_battle_task_difficulty.UNKNOWN)
    return true

  foreach(task in tasksArray)
  {
    local taskDifficulty = getDifficultyTypeByTask(task)
    if (taskDifficulty != reqDiffDone)
      continue

    if (!::g_battle_tasks.isBattleTask(task) || !::g_battle_tasks.isTaskActual(task))
      continue

    if (::g_battle_tasks.isTaskDone(task))
      continue

    if (diff.executeOrder <= taskDifficulty.executeOrder)
      continue

    return false
  }

  return true
}

g_battle_task_difficulty.updateTimeParamsFromBlk <- function updateTimeParamsFromBlk(blk)
{
  foreach(t in types)
  {
    local genSuccessTimeId = t.timeParamId + "PersonalUnlocks_lastGenerationTimeOnSuccess"
    t.lastGenTimeSuccess = blk?[genSuccessTimeId] ?? -1

    local genFailureTimeId = t.timeParamId + "PersonalUnlocks_lastGenerationTimeOnFailure"
    t.lastGenTimeFailure = blk?[genFailureTimeId] ?? -1

    local genPerSecTimeId = t.timeParamId + "PersonalUnlocks_CUSTOM_generationPeriodSec"
    t.generationPeriodSec = blk?[genPerSecTimeId] ?? -1

    local genPeriodId = t.timeParamId + "PersonalUnlocks_WEEKLY_weeklyPeriod"
    t.period = blk?[genPeriodId] ?? 1

    local genShiftId = t.timeParamId + "PersonalUnlocks_WEEKLY_weekStartDayShift"
    t.daysShift = blk?[genShiftId] ?? 0
  }
}

g_battle_task_difficulty.checkAvailabilityByProgress <- function checkAvailabilityByProgress(task, overrideStatus = false)
{
  if (overrideStatus)
    return true

  if (!::g_battle_tasks.isTaskDone(task) ||
    !getDifficultyTypeByTask(task).showAtPositiveProgress)
    return true

  local progress = ::get_unlock_progress(task.id, -1)
  return ::getTblValue("curVal", progress, 0) > 0
}

g_battle_task_difficulty.withdrawTasksArrayByDifficulty <- function withdrawTasksArrayByDifficulty(diff, tasks)
{
  return ::u.filter(tasks, @(task) diff == ::g_battle_task_difficulty.getDifficultyTypeByTask(task) )
}

g_battle_task_difficulty.getDefaultDifficultyGroup <- function getDefaultDifficultyGroup()
{
  return EASY.getDifficultyGroup()
}
