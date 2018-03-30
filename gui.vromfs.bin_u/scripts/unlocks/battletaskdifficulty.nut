local enums = ::require("std/enums.nut")
local time = require("scripts/time.nut")

::g_battle_task_difficulty <- {
  types = []
  template = {}
  cache = {
    byName = {}
    byExecOrder = {}
  }
}

function g_battle_task_difficulty::_getTimeLeftText()
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

function g_battle_task_difficulty::getDifficultyTypeByName(typeName)
{
  return enums.getCachedType("name", typeName, ::g_battle_task_difficulty.cache.byName,
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

function g_battle_task_difficulty::getRequiredDifficultyTypeDone(diff)
{
  local res = null
  if (diff.executeOrder >= 0)
    res = ::u.search(types, @(type) type.executeOrder == (diff.executeOrder-1))

  return res || ::g_battle_task_difficulty.UNKNOWN
}

function g_battle_task_difficulty::getRefreshTimeForAllTypes(tasksArray, overrideStatus = false)
{
  local processedTimeParamIds = []
  if (!overrideStatus)
    foreach(task in tasksArray)
    {
      local type = getDifficultyTypeByTask(task)
      ::u.appendOnce(type.timeParamId, processedTimeParamIds)
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

function g_battle_task_difficulty::canPlayerInteractWithDifficulty(diff, tasksArray, overrideStatus = false)
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
  return ::u.filter(array, @(task) diff == ::g_battle_task_difficulty.getDifficultyTypeByTask(task) )
}

function g_battle_task_difficulty::getDefaultDifficultyGroup()
{
  return EASY.getDifficultyGroup()
}
