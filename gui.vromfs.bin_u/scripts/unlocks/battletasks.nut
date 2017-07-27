::g_battle_tasks <- null

class BattleTasks
{
  PLAYER_CONFIG_PATH = "seen/battletasks"

  currentTasksArray = null
  activeTasksArray = null
  proposedTasksArray = null

  seenTasks = null
  newIconWidgetByTaskId = null

  TASKS_OUT_OF_DATE_DAYS = 15
  lastGenerationId = null

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

  currentTasksArray.extend(getUpdatedActiveTasks())
  currentTasksArray.extend(getUpdatedProposedTasks())

  for (local i = currentTasksArray.len() - 1; i >= 0; i--)
  {
    local task = currentTasksArray[i]
    if (!isTaskActual(task))
    {
      currentTasksArray.remove(i)
      continue
    }

    local diff = ::g_battle_task_difficulty.getDifficultyTypeByTask(task)
    if (!::g_battle_task_difficulty.canPlayerInteractWithType(diff.name, currentTasksArray, showAllTasksValue)
        || !::g_battle_task_difficulty.checkAvailabilityByProgress(task, showAllTasksValue))
    {
      currentTasksArray.remove(i)
      continue
    }

    newIconWidgetByTaskId[getUniqueId(task)] <- null
  }

  currentTasksArray.sort(function(a,b) {
    if (a._sort_order == null || b._sort_order == null)
      return 0

    if (a._sort_order == b._sort_order)
      return 0

    return a._sort_order > b._sort_order? 1 : -1
  })

  ::broadcastEvent("BattleTasksFinishedUpdate")
}

function BattleTasks::onEventBattleTasksShowAll(params)
{
  showAllTasksValue = ::getTblValue("showAllTasksValue", params, false)
  updateTasksData()
}

function BattleTasks::onEventBattleTasksIncomeUpdate(params) { updateTasksData() }
function BattleTasks::onEventBattleEnded(params)             { updateTasksData() }

function BattleTasks::getUpdatedProposedTasks()
{
  local tasksDataBlock = ::get_proposed_personal_unlocks_blk()
  ::g_battle_task_difficulty.updateTimeParamsFromBlk(tasksDataBlock)
  lastGenerationId = tasksDataBlock.dailyPersonalUnlocks_lastGenerationId
  updateRerollCost(tasksDataBlock)

  proposedTasksArray = []
  newIconWidgetByTaskId = {}

  local proposedTasks = []
  for (local i = 0; i < tasksDataBlock.blockCount(); i++)
  {
    local block = ::DataBlock()
    block.setFrom(tasksDataBlock.getBlock(i))
    block.isActive = false
    proposedTasks.append(block)
    proposedTasksArray.append(block)
  }

  return proposedTasks
}

function BattleTasks::getUpdatedActiveTasks()
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

    local isNew = !isTaskDone(task) && canGetReward(task)
    markTaskSeen(getUniqueId(task), false, isNew)
  }

  return activeTasksArray
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
  if (!::g_battle_task_difficulty.canPlayerInteractWithType(diff.name, getProposedTasksArray())
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
  local minDay = ::get_utc_days() - TASKS_OUT_OF_DATE_DAYS
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
    seenTasks[generation_id] <- ::get_utc_days()
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
  return diff.name != "UNKNOWN"
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

      if (!::isInArray(diffTypeName, whiteList)
          && !::g_battle_task_difficulty.canPlayerInteractWithType(diffTypeName,
                                        proposedTasks, showAllTasksValue))
      {
        blackList.append(diffTypeName)
        continue
      }

      local diff = ::g_battle_task_difficulty.getDifficultyTypeByName(diffTypeName)
      whiteList.append(diffTypeName)
      header = diff.userlogHeaderName
    }
    if (!(header in res))
      res[header] <- []

    res[header].append(generateStringForUserlog(table, taskId))
  }

  local data = ""
  local lastUserLogHeader = ""
  foreach(userlogHeader, array in res)
  {
    if (array.len() == 0)
      continue

    data += data == ""? "" : "\n"
    if (lastUserLogHeader != userlogHeader)
    {
      data += ::loc("userlog/battletask/type/" + userlogHeader) + ::loc("ui/colon")
      lastUserLogHeader = userlogHeader
    }
    data += ::implode(array, "\n")
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

function BattleTasks::isTaskActual(task, override = false)
{
  if (override)
    return true

  local taskGenId = task._generation_id
  if (!taskGenId)
    return true

  if (::u.isString(taskGenId))
    taskGenId = taskGenId.tointeger()

  return taskGenId == lastGenerationId
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

function BattleTasks::getTaskDescription(config = null, isPromo = false)
{
  if (!config)
    return

  local task = getTaskById(config)

  local taskDescription = []
  local taskUnlocksListPrefix = ""
  local taskUnlocksList = []
  local taskConditionsList = []

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
        local isUnlocked = !isBitMode || (config.curVal & 1 << i)
        taskUnlocksList.append(getUnlockConditionBlock(namesLoc[i],
                                 config.names[i],
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

  local view = {
    taskDescription = ::implode(taskDescription, "\n")
    taskSpecialDescription = getRefreshTimeTextForTask(task)
    taskUnlocksListPrefix = taskUnlocksListPrefix
    taskUnlocks = taskUnlocksList
    taskUnlocksList = taskUnlocksList.len()
    taskConditionsList = taskConditionsList.len()? taskConditionsList : null
    isPromo = isPromo
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

  local holderObj = taskBlockObj.findObject("task_timer_text")
  if (::checkObj(holderObj) && task)
    ::secondsUpdater(holderObj, (@(task) function(obj, params) {
      local timeText = ::g_battle_tasks.getRefreshTimeTextForTask(task)
      local isTimeEnded = timeText == ""
      if (isTimeEnded)
        timeText = ::loc("mainmenu/battleTasks/timeWasted")
      obj.setValue(timeText)

      return isTimeEnded
    })(task))

  local holderObj = taskBlockObj.findObject("tasks_refresh_timer")
  if (::checkObj(holderObj))
    ::secondsUpdater(holderObj, function(obj, params) {
      local timeText = ::g_battle_task_difficulty.EASY.getTimeLeftText()
      obj.setValue(::loc("ui/parentheses/space", {text = timeText + ::loc("icon/timer")}))

      return timeText == ""
    })
}

function BattleTasks::getUnlockConditionBlock(text, id, type, isUnlocked, isFinal, hasCustomUnlockableList, typeOR = false, isBitMode = true)
{
  local unlockDesc = typeOR ? ::loc("hints/shortcut_separator") + "\n" : ""
  unlockDesc += text
  unlockDesc += typeOR? "" : ::loc(isFinal? "ui/dot" : "ui/comma")

  return {
    tooltipId = ::UnlockConditions.getTooltipIdByModeType(type, id, hasCustomUnlockableList)
    overlayTextColor = !isBitMode ? ""
                     : isUnlocked ? "active"
                     : "disabled"
    text = unlockDesc
  }
}

function BattleTasks::getRewardMarkUpConfig(task, config)
{
  local rewardMarkUp = {}
  local itemId = ::getTblValue("userLogId", task)
  if (itemId)
  {
    local item = ::ItemsManager.findItemById(itemId)
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

function BattleTasks::generateItemView(config, isPromo = false)
{
  local task = getTaskById(config) || ::getTblValue("originTask", config)
  local isBattleTask = isBattleTask(task)
  local canGetReward = canGetReward(task)

  local isUnlock = "unlockType" in config

  local title = isBattleTask? getLocalizedTaskNameById(task.id)
              : (isUnlock? ::get_unlock_name_text(config.unlockType, config.id) : ::getTblValue("text", config, ""))
  local rankVal = isUnlock ? ::UnlockConditions.getRankValue(config.conditions) : null

  local otherTasksText = isBattleTask || isUnlock ?
              (getTasksArray().len() ?
                    (::loc("mainmenu/battleTasks/OtherTasksCount") + ::loc("ui/parentheses/space", {text = getTasksArray().len()}))
                    : null)
              : null

  return {
    id = isBattleTask? task.id : config.id
    title = title
    taskStatus = getTaskStatus(task)
    taskImage = ::getTblValue("image", task) || ::getTblValue("image", config)
    taskPlayback = ::getTblValue("playback", task) || ::getTblValue("playback", config)
    taskDifficultyImage = ::getTblValue("image", ::g_battle_task_difficulty.getDifficultyTypeByTask(task))
    taskRankValue = rankVal? ::loc("ui/parentheses/space", {text = rankVal}) : null
    description = isBattleTask || isUnlock ? getTaskDescription(config, isPromo) : null
    reward = isPromo? null : getRewardMarkUpConfig(task, config)
    newIconWidget = isBattleTask? (isTaskActive(task)? null : NewIconWidget.createLayout()) : null
    canGetReward = isBattleTask && canGetReward
    canReroll = isBattleTask && !canGetReward
    otherTasksText = otherTasksText
    isLowWidthScreen = isPromo? ::is_low_width_screen() : null
    showAsUsualPromoButton = isPromo && !isBattleTask && !isUnlock
    isPromo = isPromo
  }
}

function BattleTasks::getTasksArrayByGameModeDiffCode(searchArray, gameModeId = null, gameModeDiff = null, override = false, ignoreReward = false)
{
  if (::u.isEmpty(searchArray))
    searchArray = currentTasksArray

  local array = []
  foreach(task in searchArray)
  {
    if (!isBattleTask(task))
    {
      if (::u.isEmpty(gameModeId))
        array.append(task)
      continue
    }

    if (!::g_battle_task_difficulty.canPlayerInteractWithType(::g_battle_task_difficulty.getDifficultyTypeByTask(task).name, searchArray, override))
      continue

    if (!ignoreReward && !override && canGetReward(task))
    {
      array = [task]
      break
    }

    if (!::u.isEmpty(gameModeDiff))
    {
      local choiceType = ::getTblValue("_choiceType", task, "")
      if (::isInArray(choiceType, gameModeDiff.choiceType))
      {
        array.append(task)
        continue
      }
    }

    local blk = ::build_conditions_config(task)
    foreach(condition in blk.conditions)
    {
      local values = ::getTblValue("values", condition)
      if (::u.isEmpty(values))
        continue

      if (!::u.isEmpty(gameModeId))
      {
        if (::isInArray(gameModeId, values))
        {
          array.append(task)
          break
        }
        continue
      }
    }
  }

  return array
}

function BattleTasks::getRewardForTask(battleTaskId)
{
  if (::u.isEmpty(battleTaskId))
    return

  local blk = ::DataBlock()
  blk.unlockName = battleTaskId

  local taskId = ::char_send_blk("cln_reward_specific_battle_task", blk)
  ::g_tasker.addTask(taskId, {showProgressBox = true}, function() {
    ::update_gamercards()
    ::broadcastEvent("BattleTasksIncomeUpdate")
  })
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

::g_battle_tasks = ::BattleTasks()
::g_battle_tasks.updateTasksData()
