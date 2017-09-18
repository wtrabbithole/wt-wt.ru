enum WARBOND_SHOP_LEVEL_STATUS {
  LOCKED = "locked"
  RECEIVED = "received"
  CURRENT = "current"
}

::g_warbonds_view <- {
  [PERSISTENT_DATA_PARAMS] = ["needShowProgressBarInPromo"]
  progressBarId = "warbond_shop_progress"
  progressBarAddId = "warbond_shop_progress_additional_bar"
  levelItemIdPrefix = "level_"
  maxProgressBarValue = 10000

  needShowProgressBarInPromo = false
}

function g_warbonds_view::createProgressBox(wbClass, placeObj, handler, needForceHide = false)
{
  if (!::check_obj(placeObj))
    return

  local nest = placeObj.findObject("progress_box_place")
  if (!::check_obj(nest))
    return

  local show = !needForceHide
               && ::has_feature("Warbonds_2_0")
               && wbClass != null
               && wbClass.haveAnyOrdinaryRequirements()
               && wbClass.levelsArray.len()
  nest.show(show)
  if (!show)
    return

  local pbMarkUp = getProgressBoxMarkUp()
  pbMarkUp += getLevelItemsMarkUp(wbClass)

  nest.getScene().replaceContentFromText(nest, pbMarkUp, pbMarkUp.len(), handler)
  updateProgressBar(wbClass, nest)
}

function g_warbonds_view::getProgressBoxMarkUp()
{
  return ::handyman.renderCached("gui/commonParts/progressBarModern", {
    id = progressBarId
    addId = progressBarAddId
    additionalProgress = true
  })
}

function g_warbonds_view::getLevelItemsMarkUp(wbClass)
{
  local view = { level = [] }
  foreach (level, reqTasks in wbClass.levelsArray)
    view.level.append(getLevelItemData(wbClass, level))

  return ::handyman.renderCached("gui/items/warbondShopLevelItem", view)
}

function g_warbonds_view::getCurrentLevelItemMarkUp(wbClass, forcePosX = "0")
{
  local curLevel = wbClass.getCurrentShopLevel()
  if (curLevel < 0)
    return null

  return getLevelItemMarkUp(wbClass, curLevel, forcePosX)
}

function g_warbonds_view::getLevelItemMarkUp(wbClass, level, forcePosX = null)
{
  local levelData = getLevelItemData(wbClass, level, forcePosX)
  return ::handyman.renderCached("gui/items/warbondShopLevelItem", { level = [levelData]} )
}

function g_warbonds_view::getLevelItemData(wbClass, level, forcePosX = null)
{
  local status = getLevelStatus(wbClass, level)
  local reqTasks = wbClass.getShopLevelTasks(level)

  local posX = forcePosX
  if (!posX)
  {
    local maxLevel = wbClass.levelsArray.len() - 1
    posX = level / maxLevel.tofloat() + "pw - 50%w"
  }

  local lvlText = wbClass.getShopLevelText(level)
  return {
    id = levelItemIdPrefix + level
    levelIcon = wbClass.getLevelIcon()
    text = lvlText
    tooltip = ::loc("warbonds/shop/level/" + status + "/tooltip", {level = lvlText, tasksNum = reqTasks})
    status = status
    posX = posX
  }
}

function g_warbonds_view::getLevelStatus(wbClass, level)
{
  local curShopLevel = wbClass.getCurrentShopLevel()
  if (curShopLevel == level)
    return WARBOND_SHOP_LEVEL_STATUS.CURRENT

  if (level > curShopLevel)
    return WARBOND_SHOP_LEVEL_STATUS.LOCKED

  return WARBOND_SHOP_LEVEL_STATUS.RECEIVED
}

function g_warbonds_view::calculateProgressBarValue(wbClass, level, steps, curTasksDone)
{
  local levelTasks = wbClass.getShopLevelTasks(level)
  local nextLevelTasks = wbClass.getShopLevelTasks(level + 1)

  local progressPeerLevel = maxProgressBarValue.tofloat() / steps
  local iLerp = ::lerp(levelTasks, nextLevelTasks, 0, progressPeerLevel, curTasksDone)

  return steps == 1? iLerp : (progressPeerLevel * level + iLerp)
}

function g_warbonds_view::updateProgressBar(wbClass, placeObj, isForSingleStep = false)
{
  if (!wbClass)
    return

  local progressBoxObj = placeObj.findObject(progressBarId)
  if (!::check_obj(progressBoxObj))
    return

  local steps = isForSingleStep? 1 : wbClass.levelsArray.len() - 1
  local level = wbClass.getCurrentShopLevel()
  local tasks = wbClass.getCurrentShopLevelTasks()

  local totalTasks = tasks
  local reqTask = ::g_battle_tasks.getTaskWithAvailableAward(::g_battle_tasks.getActiveTasksArray())
  if (reqTask && ::g_battle_task_difficulty.getDifficultyTypeByTask(reqTask).canIncreaseShopLevel)
    totalTasks++
  local curProgress = calculateProgressBarValue(wbClass, level, steps, totalTasks)

  progressBoxObj.setValue(curProgress.tointeger())
  progressBoxObj.tooltip = getCurrentShopProgressBarText(wbClass)

  local addProgressBarObj = progressBoxObj.findObject(progressBarAddId)
  if (::checkObj(addProgressBarObj))
  {
    local addBarValue = calculateProgressBarValue(wbClass, level, steps, tasks)
    addProgressBarObj.setValue(addBarValue)
  }
}

function g_warbonds_view::getCurrentShopProgressBarText(wbClass)
{
  if (!showOrdinaryProgress(wbClass) || wbClass.levelsArray.len() == 0)
    return ""

  return getShopProgressBarText(
    wbClass.getCurrentShopLevelTasks(),
    wbClass.getNextShopLevelTasks()
  )
}

function g_warbonds_view::getShopProgressBarText(curTasks, nextLevelTasks)
{
  return ::loc("mainmenu/battleTasks/progressBarTooltip", {
    tasksNum = curTasks
    nextLevelTasksNum = nextLevelTasks
  })
}

function g_warbonds_view::createSpecialMedalsProgress(wbClass, placeObj, handler)
{
  if (!::check_obj(placeObj))
    return

  local nest = placeObj.findObject("medal_icon")
  if (!::check_obj(nest))
    return

  local show = ::has_feature("Warbonds_2_0")
               && wbClass
               && wbClass.haveAnySpecialRequirements()
  nest.show(show)
  if (!show)
    return

  nest.tooltip = getSpecialMedalsTooltip(wbClass)
  local data = getSpecialMedalsMarkUp(wbClass, getWarbondMedalsCount(wbClass), true)
  data += getSpecialMedalInProgressMarkUp(wbClass)
  nest.getScene().replaceContentFromText(nest, data, data.len(), handler)
}

function g_warbonds_view::getSpecialMedalsTooltip(wbClass)
{
  return ::loc("mainmenu/battleTasks/special/medals/tooltip",
  {
    medals = getWarbondMedalsCount(wbClass),
    tasksNum = wbClass.medalForSpecialTasks
  })
}

function g_warbonds_view::getSpecialMedalsMarkUp(wbClass, reqAwardMedals = 0, needShowZero = false)
{
  local medalsCount = getWarbondMedalsCount(wbClass)
  local view = { medal = [{
      posX = 0
      image = wbClass? wbClass.getMedalIcon() : null
      countText = needShowZero && reqAwardMedals==0? reqAwardMedals.tostring() : reqAwardMedals
      inactive = medalsCount < reqAwardMedals
  }]}

  return ::handyman.renderCached("gui/items/warbondSpecialMedal", view)
}

function g_warbonds_view::getSpecialMedalInProgressMarkUp(wbClass)
{
  if (!wbClass.needShowSpecialTasksProgress)
    return ""

  local leftTasks = wbClass.leftForAnotherMedalTasks()
  local view = { medal = [{
    sector = 360 - (360 * leftTasks.tofloat()/wbClass.medalForSpecialTasks)
    image = wbClass? wbClass.getMedalIcon() : null
  }]}
  return ::handyman.renderCached("gui/items/warbondSpecialMedal", view)
}

function g_warbonds_view::getWarbondMedalsCount(wbClass)
{
  return wbClass? wbClass.getCurrentMedalsCount() : 0
}

function g_warbonds_view::showOrdinaryProgress(wbClass)
{
  return ::has_feature("Warbonds_2_0") && wbClass && wbClass.haveAnyOrdinaryRequirements()
}

function g_warbonds_view::showSpecialProgress(wbClass)
{
  return ::has_feature("Warbonds_2_0") && wbClass && wbClass.haveAnySpecialRequirements()
}

function g_warbonds_view::resetShowProgressBarFlag()
{
  if (!needShowProgressBarInPromo)
    return

  needShowProgressBarInPromo = false
  ::broadcastEvent("WarbondViewShowProgressBarFlagUpdate")
}

::g_script_reloader.registerPersistentDataFromRoot("g_warbonds_view")
::subscribe_handler(::g_warbonds_view, ::g_listener_priority.DEFAULT_HANDLER)