local SecondsUpdater = require("sqDagui/timer/secondsUpdater.nut")
local time = require("scripts/time.nut")
local stdMath = require("std/math.nut")


::g_battle_tasks <- null

class BattleTasks
{
  PLAYER_CONFIG_PATH = "seen/battletasks"
  specialTasksId = "specialTasksPersonalUnlocks"
  dailyTasksId = "dailyPersonalUnlocks"

  currentTasksArray = null
  activeTasksArray = null
  proposedTasksArray = null

  seenTasks = null
  newIconWidgetByTaskId = null

  TASKS_OUT_OF_DATE_DAYS = 15
  lastGenerationId = null
  specTasksLastGenerationId = null

  rerollCost = null

  seenTasksInited = false
  showAllTasksValue = false

  currentPlayback = null
}

function BattleTasks::constructor()
{
  currentTasksArray = []
  activeTasksArray = []
  proposedTasksArray = []

  seenTasks = {}
  newIconWidgetByTaskId = {}

  lastGenerationId = 0
  specTasksLastGenerationId = 0

  ::subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)
}

function BattleTasks::reset()
{
  currentTasksArray.clear()
  activeTasksArray.clear()
  proposedTasksArray.clear()

  seenTasks = {}
  newIconWidgetByTaskId = {}
  seenTasksInited = false

  lastGenerationId = 0
  specTasksLastGenerationId = 0
}

function BattleTasks::isAvailableForUser()
{
  return ::has_feature("BattleTasks")
         && !::u.isEmpty(getTasksArray())
}

function BattleTasks::updateTasksData()
{
  currentTasksArray.clear()
  if (!::g_login.isLoggedIn())
    return

  updatedProposedTasks()
  updatedActiveTasks()

  currentTasksArray.sort(function(a,b) {
    if (a._sort_order == null || b._sort_order == null)
      return 0

    if (a._sort_order == b._sort_order)
      return 0

    return a._sort_order > b._sort_order? 1 : -1
  })

  if (::isInMenu())
    checkNewSpecialTasks()
  ::broadcastEvent("BattleTasksFinishedUpdate")
}

function BattleTasks::onEventBattleTasksShowAll(params)
{
  showAllTasksValue = ::getTblValue("showAllTasksValue", params, false)
  updateTasksData()
}

function BattleTasks::onEventBattleTasksIncomeUpdate(params) { updateTasksData() }
function BattleTasks::onEventBattleEnded(params)             { updateTasksData() }

function BattleTasks::updatedProposedTasks()
{
  local tasksDataBlock = ::get_proposed_personal_unlocks_blk()
  ::g_battle_task_difficulty.updateTimeParamsFromBlk(tasksDataBlock)
  lastGenerationId = tasksDataBlock[dailyTasksId + "_lastGenerationId"]
  specTasksLastGenerationId = tasksDataBlock[specialTasksId + "_lastGenerationId"]

  updateRerollCost(tasksDataBlock)

  proposedTasksArray = []
  newIconWidgetByTaskId = {}

  for (local i = 0; i < tasksDataBlock.blockCount(); i++)
  {
    local task = ::DataBlock()
    task.setFrom(tasksDataBlock.getBlock(i))
    task.isActive = false
    proposedTasksArray.append(task)
    if (!isTaskActual(task) || !canInteract(task)
      || !::g_battle_task_difficulty.checkAvailabilityByProgress(task, showAllTasksValue))
      continue

    currentTasksArray.append(task)
    newIconWidgetByTaskId[getUniqueId(task)] <- null
  }
}

function BattleTasks::updatedActiveTasks()
{
  local currentActiveTasks = ::get_personal_unlocks_blk()
  activeTasksArray.clear()
  for (local i = 0; i < currentActiveTasks.blockCount(); i++)
  {
    local task = ::DataBlock()
    task.setFrom(currentActiveTasks.getBlock(i))

    if (!isBattleTask(task))
      continue

    task.isActive = true
    activeTasksArray.append(task)

    if (!isTaskActual(task) || !canInteract(task)
      || !::g_battle_task_difficulty.checkAvailabilityByProgress(task, showAllTasksValue))
      continue

    currentTasksArray.append(task)
    local isNew = !isTaskDone(task) && canGetReward(task)
    markTaskSeen(getUniqueId(task), false, isNew)
    newIconWidgetByTaskId[getUniqueId(task)] <- null
  }
}

function BattleTasks::updateRerollCost(tasksDataBlock)
{
  rerollCost = ::Cost(::getTblValue("_rerollCost", tasksDataBlock, 0),
                      ::getTblValue("_rerollGoldCost", tasksDataBlock, 0))
}

function BattleTasks::isTaskActive(task)
{
  return ::getTblValue("isActive", task, true)
}

function BattleTasks::isTaskDone(config)
{
  if (::u.isEmpty(config))
    return false

  if (isBattleTask(config))
  {
    if (!getTaskById(config.id))
      return true //Task with old difficulty type, not using anymore
    return ::is_unlocked_scripted(-1, config.id)
  }
  return ::is_unlocked_scripted(-1, config.id)
}

function BattleTasks::canGetReward(task)
{
  return isBattleTask(task)
         && isTaskActual(task)
         && !isTaskDone(task)
         && ::getTblValue("_readyToReward", task, false)
}

function BattleTasks::canGetAnyReward()
{
  foreach (task in getActiveTasksArray())
    if (canGetReward(task))
      return true
  return false
}

function BattleTasks::canActivateTask(task = null)
{
  if (!isBattleTask(task))
    return false

  local diff = ::g_battle_task_difficulty.getDifficultyTypeByTask(task)
  if (!::g_battle_task_difficulty.canPlayerInteractWithDifficulty(diff, getProposedTasksArray())
      || !::g_battle_task_difficulty.checkAvailabilityByProgress(task))
      return false

  foreach (idx, activeTask in getActiveTasksArray())
    if (!isAutoAcceptedTask(activeTask))
      return false

  return true
}

function BattleTasks::getTasksArray() { return currentTasksArray }
function BattleTasks::getProposedTasksArray() { return proposedTasksArray }
function BattleTasks::getActiveTasksArray() { return activeTasksArray }
function BattleTasks::getWidgetsTable() { return newIconWidgetByTaskId }

function BattleTasks::debugClearSeenData()
{
  seenTasks = {}
  saveSeenTasksData()
  //!!fix me: need to recount seen data from active tasks
}

function BattleTasks::loadSeenTasksData(forceLoad = false)
{
  if (seenTasksInited && !forceLoad)
    return true

  seenTasks.clear()
  local blk = ::loadLocalByAccount(PLAYER_CONFIG_PATH)
  if (typeof(blk) == "instance" && (blk instanceof ::DataBlock))
    for (local i = 0; i < blk.paramCount(); i++)
    {
      local id = blk.getParamName(i)
      seenTasks[id] <- ::max(blk.getParamValue(i), ::getTblValue(id, seenTasks, 0))
    }

  seenTasksInited = true
  return true
}

function BattleTasks::saveSeenTasksData()
{
  local minDay = time.getUtcDays() - TASKS_OUT_OF_DATE_DAYS
  local blk = ::DataBlock()
  foreach(generation_id, day in seenTasks)
  {
    if (day < minDay && !isBattleTaskNew(generation_id))
      continue

    blk[generation_id] = day
  }

  ::saveLocalByAccount(PLAYER_CONFIG_PATH, blk)
}

function BattleTasks::isBattleTaskNew(generation_id)
{
  loadSeenTasksData()
  return !(generation_id in seenTasks)
}

function BattleTasks::markTaskSeen(generation_id, sendEvent = true, isNew = false)
{
  local wasNew = isBattleTaskNew(generation_id)
  if (wasNew == isNew)
    return false

  if (!isNew)
    seenTasks[generation_id] <- time.getUtcDays()
  else if (generation_id in seenTasks)
    delete seenTasks[generation_id]

  if (sendEvent)
    ::broadcastEvent("NewBattleTasksChanged")
  return true
}

function BattleTasks::markAllTasksSeen()
{
  local changeNew = false
  foreach(task in currentTasksArray)
  {
    local generation_id = getUniqueId(task)
    local result = markTaskSeen(generation_id, false)
    changeNew = changeNew || result
  }

  if (changeNew)
    ::broadcastEvent("NewBattleTasksChanged")
}

function BattleTasks::getUnseenTasksCount()
{
  loadSeenTasksData()

  local num = 0
  foreach(idx, task in currentTasksArray)
  {
    if (!isBattleTaskNew(getUniqueId(task)))
      continue

    num++
  }
  return num
}

function BattleTasks::getLocalizedTaskNameById(param)
{
  local task = null
  local id = null
  if (::u.isDataBlock(param))
  {
    task = param
    id = ::getTblValue("id", param)
  }
  else if (::u.isString(param))
  {
    task = getTaskById(param)
    id = param
  }
  else
    return ""

  return ::loc(::getTblValue("locId", task, "battletask/" + id))
}

function BattleTasks::getTaskById(id)
{
  if (::u.isTable(id) || ::u.isDataBlock(id))
    id = ::getTblValue("id", id)

  if (!id)
    return null

  foreach(task in activeTasksArray)
    if (task.id == id)
      return task

  foreach(task in proposedTasksArray)
    if (task.id == id)
      return task

  return null
}

function BattleTasks::generateUnlockConfigByTask(task)
{
  local config = ::build_conditions_config(task)
  ::build_unlock_desc(config)
  config.originTask <- task
  return config
}

function BattleTasks::getUniqueId(task)
{
  return task.id
}

function BattleTasks::isController(config)
{
  return ::getTblValue("_controller", config, false)
}

function BattleTasks::isAutoAcceptedTask(task)
{
  return ::getTblValue("_autoAccept", task, false)
}

function BattleTasks::isBattleTask(task)
{
  if (::u.isString(task))
    task = getTaskById(task)

  local diff = ::g_battle_task_difficulty.getDifficultyTypeByTask(task)
  return diff != ::g_battle_task_difficulty.UNKNOWN
}

function BattleTasks::isUserlogForBattleTasksGroup(body)
{
  local unlockId = ::getTblValue("unlockId", body)
  if (unlockId == null)
    return true

  return getTaskById(unlockId) != null
}

//currently it is using in userlog
function BattleTasks::generateUpdateDescription(log)
{
  local res = {}
  local blackList = []
  local whiteList = []

  local proposedTasks = getProposedTasksArray()

  foreach(taskId, table in log)
  {
    local header = ""
    local diffTypeName = ::getTblValue("type", table)
    if (diffTypeName)
    {
      if (::isInArray(diffTypeName, blackList))
        continue

      local diff = ::g_battle_task_difficulty.getDifficultyTypeByName(diffTypeName)
      if (!::isInArray(diffTypeName, whiteList)
          && !::g_battle_task_difficulty.canPlayerInteractWithDifficulty(diff,
                                        proposedTasks, showAllTasksValue))
      {
        blackList.append(diffTypeName)
        continue
      }

      whiteList.append(diffTypeName)
      header = diff.userlogHeaderName
    }
    if (!(header in res))
      res[header] <- []

    res[header].append(generateStringForUserlog(table, taskId))
  }

  local data = ""
  local lastUserLogHeader = ""
  foreach(userlogHeader, arr in res)
  {
    if (arr.len() == 0)
      continue

    data += data == ""? "" : "\n"
    if (lastUserLogHeader != userlogHeader)
    {
      data += ::loc("userlog/battletask/type/" + userlogHeader) + ::loc("ui/colon")
      lastUserLogHeader = userlogHeader
    }
    data += ::g_string.implode(arr, "\n")
  }

  return data
}

function BattleTasks::generateStringForUserlog(table, taskId)
{
  local text = getBattleTaskLocIdFromUserlog(table, taskId)
  local cost = ::Cost(::getTblValue("cost", table, 0), ::getTblValue("costGold", table, 0))
  if (!::u.isEmpty(cost))
    text += ::loc("ui/parentheses/space", {text = cost.tostring()})

  return text
}

function BattleTasks::getBattleTaskLocIdFromUserlog(log, taskId)
{
  return "locId" in log? ::loc(log.locId) : getLocalizedTaskNameById(taskId)
}

function BattleTasks::getImage(imageName = null)
{
  if (imageName)
    return "ui/images/battle_tasks/" + imageName + ".jpg?P1"
  return null
}

function BattleTasks::getTaskStatus(task)
{
  if (canGetReward(task))
    return "complete"
  if (isTaskDone(task))
    return "done"
  return null
}

function BattleTasks::getGenerationIdInt(task)
{
  local taskGenId = task._generation_id
  if (!taskGenId)
    return 0

  return ::u.isString(taskGenId)? taskGenId.tointeger() : taskGenId
}

function BattleTasks::isTaskActual(task)
{
  if (!task._generation_id)
    return true

  local taskGenId = getGenerationIdInt(task)
  return taskGenId == lastGenerationId
    || taskGenId == specTasksLastGenerationId
}

function BattleTasks::isTaskUnderControl(checkTask, taskController, typesToCheck = null)
{
  if (taskController.id == checkTask.id || taskController._generation_id != checkTask._generation_id)
    return false
  if (!typesToCheck)
    return true

  return ::isInArray(::g_battle_task_difficulty.getDifficultyTypeByTask(checkTask).name, typesToCheck)
}

function BattleTasks::canCancelTask(task)
{
  return !isTaskDone(task) && !::getTblValue("_preventCancel", task, false)
}

function BattleTasks::getTasksListByControllerTask(taskController, conditions)
{
  local tasksArray = []
  if (!isController(taskController))
    return tasksArray

  local unlocksCond = ::u.search(conditions, function(cond) { return cond.type == "char_personal_unlock" } )
  local personalUnlocksTypes = unlocksCond && unlocksCond.values

  foreach (task in currentTasksArray)
    if (isTaskUnderControl(task, taskController, personalUnlocksTypes))
      tasksArray.append(task)

  return tasksArray
}

function BattleTasks::getTaskWithAvailableAward(tasksArray)
{
  return ::u.search(tasksArray, function(task) {
      return canGetReward(task)
    }.bindenv(this))
}

function BattleTasks::getTaskDescription(config = null, paramsCfg = {})
{
  if (!config)
    return

  local task = getTaskById(config)

  local taskDescription = []
  local taskUnlocksListPrefix = ""
  local taskUnlocksList = []
  local taskConditionsList = []
  local isPromo = paramsCfg?.isPromo ?? false

  if (showAllTasksValue)
    taskDescription.append("*Debug info: id - " + config.id)

  if (isPromo)
  {
    if (::getTblValue("locDescId", config, "") != "")
      taskDescription.append(::loc(config.locDescId))
    taskDescription.append(::UnlockConditions.getMainConditionText(config.conditions, config.curVal, config.maxVal))
  }
  else
  {
    if (::getTblValue("text", config, "") != "")
      taskDescription.append(config.text)

    if (!canGetReward(task))
    {
      taskUnlocksListPrefix = ::UnlockConditions.getMainConditionListPrefix(config.conditions)

      local isBitMode = ::UnlockConditions.isBitModeType(config.type)
      local namesLoc = ::UnlockConditions.getLocForBitValues(config.type, config.names, config.hasCustomUnlockableList)
      local typeOR = ::getTblValue("compareOR", config, false)
      for (local i = 0; i < namesLoc.len(); i++)
      {
        local unlockId = config.names[i]
        if (!::is_unlock_visible(::g_unlocks.getUnlockById(unlockId)))
          continue

        local isUnlocked = !isBitMode || (config.curVal & 1 << i)
        taskUnlocksList.append(getUnlockConditionBlock(namesLoc[i],
                                 unlockId,
                                 config.type,
                                 isUnlocked,
                                 i == namesLoc.len() - 1,
                                 config.hasCustomUnlockableList,
                                 i > 0 && typeOR,
                                 isBitMode))
      }
    }

    local controlledTasks = getTasksListByControllerTask(task, config.conditions)
    foreach (contrTask in controlledTasks)
    {
      taskConditionsList.append({
        unlocked = isTaskDone(contrTask)
        text = ::colorize(isActive(contrTask)? "userlogColoredText" : "", getLocalizedTaskNameById(contrTask))
      })
    }
  }

  local progressData = config?.getProgressBarData? config.getProgressBarData() : null
  local progressBarValue = config?.curVal >= 0? (config.curVal.tofloat() / (config?.maxVal ?? 1) * 1000) : 0

  local view = {
    id = config.id
    taskDescription = ::g_string.implode(taskDescription, "\n")
    taskSpecialDescription = getRefreshTimeTextForTask(task)
    taskUnlocksListPrefix = taskUnlocksListPrefix
    taskUnlocks = taskUnlocksList
    taskUnlocksList = taskUnlocksList.len()
    taskConditionsList = taskConditionsList.len()? taskConditionsList : null
    needShowProgressBar = isPromo && progressData?.show
    progressBarValue = progressBarValue.tointeger()
    isPromo = isPromo
    isOnlyInfo = paramsCfg?.isOnlyInfo ?? false
  }

  return ::handyman.renderCached("gui/unlocks/battleTasksDescription", view)
}

function BattleTasks::getRefreshTimeTextForTask(task)
{
  local text = ""
  local timeLeft = ::g_battle_task_difficulty.getDifficultyTypeByTask(task).getTimeLeftText()
  if (timeLeft != "")
    text = ::loc("unlocks/_acceptTime") + ::loc("ui/colon") + ::colorize("unlockActiveColor", timeLeft)

  return text
}

function BattleTasks::setUpdateTimer(task, taskBlockObj)
{
  if (!::checkObj(taskBlockObj))
    return

  local diff = ::g_battle_task_difficulty.getDifficultyTypeByTask(task)
  if (!diff.hasTimer) return

  local holderObj = taskBlockObj.findObject("task_timer_text")
  if (::checkObj(holderObj) && task)
    SecondsUpdater(holderObj, (@(task) function(obj, params) {
      local timeText = ::g_battle_tasks.getRefreshTimeTextForTask(task)
      local isTimeEnded = timeText == ""
      if (isTimeEnded)
        timeText = ::loc("mainmenu/battleTasks/timeWasted")
      obj.setValue(timeText)

      return isTimeEnded
    })(task))

  holderObj = taskBlockObj.findObject("tasks_refresh_timer")
  if (::checkObj(holderObj))
    SecondsUpdater(holderObj, function(obj, params) {
      local timeText = ::g_battle_task_difficulty.EASY.getTimeLeftText()
      obj.setValue(::loc("ui/parentheses/space", {text = timeText + ::loc("icon/timer")}))

      return timeText == ""
    })
}

function BattleTasks::getUnlockConditionBlock(text, id, mType, isUnlocked, isFinal, hasCustomUnlockableList, typeOR = false, isBitMode = true)
{
  local unlockDesc = typeOR ? ::loc("hints/shortcut_separator") + "\n" : ""
  unlockDesc += text
  unlockDesc += typeOR? "" : ::loc(isFinal? "ui/dot" : "ui/comma")

  return {
    tooltipId = ::UnlockConditions.getTooltipIdByModeType(mType, id, hasCustomUnlockableList)
    overlayTextColor = (isBitMode && isUnlocked) ? "userlog" : "active"
    text = unlockDesc
  }
}

function BattleTasks::getPlaybackPath(playbackName, shouldUseDefaultLang = false)
{
  if (::u.isEmpty(playbackName))
    return ""

  local guiBlk = ::configs.GUI.get()
  local unlockPlaybackPath = guiBlk.unlockPlaybackPath
  if (!unlockPlaybackPath)
    return ""

  local path = unlockPlaybackPath.mainPath
  local abbrev = shouldUseDefaultLang? "en" : ::g_language.getShortName()
  return path + abbrev + "/" + playbackName + unlockPlaybackPath.fileExtension
}

function BattleTasks::getRewardMarkUpConfig(task, config)
{
  local rewardMarkUp = {}
  local itemId = ::getTblValue("userLogId", task)
  if (itemId)
  {
    local item = ::ItemsManager.findItemById(::to_integer_safe(itemId, itemId, false))
    if (item)
      rewardMarkUp.itemMarkUp <- item.getNameMarkup(::getTblValue("amount_trophies", task))
  }

  local reward = ::get_unlock_rewards_text(config)
  if (reward == "" && !rewardMarkUp.len())
    return rewardMarkUp

  local rewardLoc = isTaskDone(task)? ::loc("rewardReceived") : ::loc("reward")
  rewardMarkUp.rewardText <- rewardLoc + ::loc("ui/colon") + reward
  return rewardMarkUp
}

function BattleTasks::generateItemView(config, paramsCfg = {})
{
  local isPromo = paramsCfg?.isPromo ?? false
  local isShortDescription = paramsCfg?.isShortDescription ?? false

  local task = getTaskById(config) || ::getTblValue("originTask", config)
  local isBattleTask = isBattleTask(task)
  local canGetReward = canGetReward(task)

  local isUnlock = "unlockType" in config

  local title = isBattleTask? getLocalizedTaskNameById(task.id)
              : (isUnlock? ::get_unlock_name_text(config.unlockType, config.id) : ::getTblValue("text", config, ""))
  local brVal = isUnlock ? ::UnlockConditions.getBRValue(config.conditions) : null
  local rankVal = isUnlock ? ::UnlockConditions.getRankValue(config.conditions) : null

  local id = isBattleTask? task.id : config.id
  local progressData = config?.getProgressBarData? config.getProgressBarData() : null
  local progressBarValue = config?.curVal >= 0? (config.curVal.tofloat() / (config?.maxVal ?? 1) * 1000) : 0
  local taskStatus = getTaskStatus(task)

  return {
    id = id
    title = title
    taskStatus = taskStatus
    taskImage = (paramsCfg?.showUnlockImage ?? true) && (::getTblValue("image", task) || ::getTblValue("image", config))
    taskPlayback = ::getTblValue("playback", task) || ::getTblValue("playback", config)
    isPlaybackDownloading = !::g_sound.canPlay(id)
    taskDifficultyImage = getDifficultyImage(task)
    taskRankValue = brVal || rankVal ? ::loc("ui/parentheses/space", { text = brVal || rankVal }) : null
    description = isBattleTask || isUnlock ? getTaskDescription(config, paramsCfg) : null
    reward = isPromo? null : getRewardMarkUpConfig(task, config)
    newIconWidget = isBattleTask? (isTaskActive(task)? null : NewIconWidget.createLayout()) : null
    canGetReward = isBattleTask && canGetReward
    canReroll = isBattleTask && !canGetReward
    otherTasksNum = task && isPromo? getTotalActiveTasksNum() : null
    isLowWidthScreen = isPromo? ::is_low_width_screen() : null
    showAsUsualPromoButton = isPromo && task == null
    isPromo = isPromo
    isOnlyInfo = paramsCfg?.isOnlyInfo ?? false
    needShowProgressValue = taskStatus == null && config?.curVal >= 0 && config?.maxVal >= 0
    progressValue = config?.curVal
    progressMaxValue = config?.maxVal
    needShowProgressBar = progressData?.show
    progressBarValue = progressBarValue.tointeger()
    getTooltipId = (isPromo || isShortDescription) && isBattleTask? @() ::g_tooltip_type.BATTLE_TASK.getTooltipId(id) : null
    isShortDescription = isShortDescription
    shouldRefreshTimer = config?.shouldRefreshTimer ?? false
  }
}

function BattleTasks::getTotalActiveTasksNum()
{
  local num = 0
  foreach (task in getActiveTasksArray())
    if (isTaskActual(task) && !isTaskDone(task))
      num++
  return num
}

function BattleTasks::getDifficultyImage(task)
{
  local difficulty = ::g_battle_task_difficulty.getDifficultyTypeByTask(task)
  if (difficulty.showSeasonIcon)
  {
    local curWarbond = ::g_warbonds.getCurrentWarbond()
    if (curWarbond)
      return curWarbond.getMedalIcon()
  }

  return difficulty.image
}

function BattleTasks::getTasksArrayByIncreasingDifficulty()
{
  local typesArray = [
    ::g_battle_task_difficulty.EASY,
    ::g_battle_task_difficulty.MEDIUM,
    ::g_battle_task_difficulty.HARD
  ]

  local result = []
  foreach(t in typesArray)
  {
    local arr = ::g_battle_task_difficulty.withdrawTasksArrayByDifficulty(t, currentTasksArray)
    if (arr.len() == 0)
      continue

    if (::g_battle_task_difficulty.canPlayerInteractWithDifficulty(t, arr))
      result.extend(arr)
  }

  return result
}

function BattleTasks::filterTasksByGameModeId(tasksArray, gameModeId)
{
  if (::u.isEmpty(gameModeId))
    return tasksArray

  local res = []
  foreach(task in tasksArray)
  {
    if (!isBattleTask(task))
      continue

    local blk = ::build_conditions_config(task)
    foreach(condition in blk.conditions)
    {
      local values = ::getTblValue("values", condition)
      if (::u.isEmpty(values))
          continue

      if (::isInArray(gameModeId, values))
      {
        res.append(task)
        break
      }
    }
  }
  return res
}

function BattleTasks::getTasksArrayByDifficulty(searchArray, difficulty = null)
{
  if (::u.isEmpty(searchArray))
    searchArray = currentTasksArray

  if (::u.isEmpty(difficulty))
    return searchArray

  return searchArray.filter(@(idx, task) ::g_battle_tasks.isTaskSameDifficulty(task, difficulty))
}

function BattleTasks::isTaskSameDifficulty(task, difficulty)
{
  if (!isBattleTask(task))
    return true

  return ::isInArray(task?._choiceType ?? "", difficulty.choiceType)
}

function BattleTasks::isTaskSuitableForUnitTypeMask(task, unitTypeMask)
{
  if (!isBattleTask(task))
    return false

  local blk = ::build_conditions_config(task)
  foreach(condition in blk.conditions)
  {
    local values = ::getTblValue("values", condition)
    if (::u.isEmpty(values))
      continue

    foreach (value in values)
    {
      local gameMode = ::game_mode_manager.getGameModeById(value)
      if (!gameMode)
        continue

      foreach (unitType in gameMode.unitTypes)
        if (stdMath.is_bit_set(unitTypeMask, unitType))
          return true

      break
    }
  }

  return false
}

function BattleTasks::getRewardForTask(battleTaskId)
{
  if (::u.isEmpty(battleTaskId))
    return

  local battleTask = getTaskById(battleTaskId)
  if (!::g_warbonds.checkOverLimit(battleTask))
    return

  sendReceiveRewardRequest(battleTask)
}

function BattleTasks::sendReceiveRewardRequest(battleTask)
{
  local blk = ::DataBlock()
  blk.unlockName = battleTask.id

  local taskId = ::char_send_blk("cln_reward_specific_battle_task", blk)
  ::g_tasker.addTask(taskId, {showProgressBox = true}, function() {
    ::g_warbonds_view.needShowProgressBarInPromo = true
    ::update_gamercards()
    ::broadcastEvent("BattleTasksIncomeUpdate")
    ::broadcastEvent("BattleTasksRewardReceived")
  })
}

function BattleTasks::rerollTask(task)
{
  if (::u.isEmpty(task))
    return

  local blk = ::DataBlock()
  blk.unlockName = task.id

  local taskId = ::char_send_blk("cln_reroll_battle_task", blk)
  ::g_tasker.addTask(taskId, {showProgressBox = true},
    function() {
      ::statsd_counter("battle_tasks.reroll_v2." + task._base_id)
      ::broadcastEvent("BattleTasksIncomeUpdate")
    }
  )
}

function BattleTasks::rerollSpecialTask(task)
{
  if (::u.isEmpty(task))
    return

  local blk = ::DataBlock()
  blk.unlockName = task.id
  blk.metaTypeName = specialTasksId

  local taskId = ::char_send_blk("cln_reroll_all_battle_tasks_for_meta", blk)
  ::g_tasker.addTask(taskId, {showProgressBox = true},
    function() {
      ::statsd_counter("battle_tasks.special_reroll" + task._base_id)
      ::broadcastEvent("BattleTasksIncomeUpdate")
    })
}

function BattleTasks::canActivateHardTasks()
{
  return ::isInMenu()
    && ::u.search(proposedTasksArray, ::Callback(isSpecialBattleTask, this )) != null
    && ::u.search(activeTasksArray, ::Callback(isSpecialBattleTask, this )) == null
}

function BattleTasks::isSpecialBattleTask(task)
{
  return getGenerationIdInt(task) == specTasksLastGenerationId
}

function BattleTasks::onEventSignOut(p)
{
  reset()
}

function BattleTasks::onEventLoginComplete(p)
{
  reset()
  updateTasksData()
}

function BattleTasks::checkNewSpecialTasks()
{
  if (!canActivateHardTasks())
    return

  local arr = ::u.filter(proposedTasksArray, ::Callback(isSpecialBattleTask, this) )
  ::gui_start_battle_tasks_select_new_task_wnd(arr)
}

function BattleTasks::getDifficultyTypeGroup()
{
  local result = []
  foreach(t in ::g_battle_task_difficulty.types)
  {
    local difficultyGroup = t.getDifficultyGroup()
    if (difficultyGroup =="")
      continue

    result.append(t)
  }
  return result
}

function BattleTasks::canInteract(task)
{
  local diff = ::g_battle_task_difficulty.getDifficultyTypeByTask(task)
  return ::g_battle_task_difficulty.canPlayerInteractWithDifficulty(diff, currentTasksArray, showAllTasksValue)
}

::g_battle_tasks = ::BattleTasks()
::g_battle_tasks.updateTasksData()
