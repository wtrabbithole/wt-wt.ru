enum WARBOND_SHOP_LEVEL_STATUS {
  LOCKED = "locked"
  RECEIVED = "received"
  CURRENT = "current"
}

::g_warbonds_view <- {
  progressBarId = "warbond_shop_progress"
  levelItemIdPrefix = "level_"
  maxProgressBarValue = 10000
}

function g_warbonds_view::createProgressBox(wbClass, placeObj, handler)
{
  if (!::check_obj(placeObj))
    return

  local nest = placeObj.findObject("progress_box_place")
  if (!::check_obj(nest))
    return

  local show = ::has_feature("Warbonds_2_0")
               && wbClass != null
               && wbClass.haveAnyOrdinaryRequirements()
               && wbClass.levelsArray.len() > 0
  nest.show(show)
  if (!show)
    return

  local pbMarkUp = getProgressBoxMarkUp()
  pbMarkUp += getLevelItemsMarkUp(wbClass)

  nest.getScene().replaceContentFromText(nest, pbMarkUp, pbMarkUp.len(), handler)
  updateProgressBar(wbClass, nest)
}

function g_warbonds_view::getProgressBoxMarkUp(params = {})
{
  params.id <- progressBarId
  return ::handyman.renderCached("gui/commonParts/progressBarModern", params)
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
  local reqTasks = wbClass.levelsArray[level]

  local posX = forcePosX
  if (!posX)
  {
    local maxLevel = wbClass.levelsArray.len() - 1
    posX = level / maxLevel.tofloat() + "pw - 50%w"
  }

  local lvlText = wbClass.getShopLevelText(level)
  return {
    id = levelItemIdPrefix + level
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

function g_warbonds_view::calculateProgressBarValue(wbClass, level, steps)
{
  local levelTasks = wbClass.getShopLevelTasks(level)
  local nextLevelTasks = wbClass.getShopLevelTasks(level + 1)

  local progressPeerLevel = maxProgressBarValue.tofloat() / steps

  local iLerp = ::lerp(levelTasks, nextLevelTasks, 0, progressPeerLevel, wbClass.getCurrentShopLevelTasks())
  return progressPeerLevel * level + iLerp
}

function g_warbonds_view::updateProgressBar(wbClass, placeObj)
{
  if (!wbClass)
    return

  local progressBoxObj = placeObj.findObject(progressBarId)
  if (!::check_obj(progressBoxObj))
    return

  local steps = wbClass.levelsArray.len() - 1
  local level = wbClass.getCurrentShopLevel()

  local curProgress = calculateProgressBarValue(wbClass, level, steps)

  progressBoxObj.setValue(curProgress.tointeger())
  progressBoxObj.tooltip = getCurrentShopProgressBarText(wbClass)
}

function g_warbonds_view::getCurrentShopProgressBarText(wbClass)
{
  if (!showOrdinaryProgress(wbClass))
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

  local nest = placeObj.findObject("medals_block")
  if (!::check_obj(nest))
    return

  local show = ::has_feature("Warbonds_2_0")
               && wbClass
               && wbClass.haveAnySpecialRequirements()
  nest.show(show)
  if (!show)
    return

  nest.tooltip = getSpecialMedalsTooltip(wbClass)
  local data = getSpecialMedalsMarkUp(wbClass)
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

function g_warbonds_view::getSpecialMedalsMarkUp(wbClass, isSingle = false, reqAwardMedals = 0)
{
  local medalsCount = getWarbondMedalsCount(wbClass)
  local icons = isSingle? 1 : medalsCount
  local view = { medal = [] }
  for (local i = 0; i < icons; i++)
    view.medal.append({
      posX = i? "-0.5*w" : 0
      image = wbClass? wbClass.getMedalIcon() : null
      countText = reqAwardMedals
      inactive = medalsCount < reqAwardMedals
    })

  return ::handyman.renderCached("gui/items/warbondSpecialMedal", view)
}

function g_warbonds_view::getSpecialMedalInProgressMarkUp(wbClass)
{
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

function g_warbonds_view::getSpecialText(wbClass)
{
  if (!showSpecialProgress(wbClass))
    return ""

  return ::loc("mainmenu/battleTasks/special/medals", {medals = getWarbondMedalsCount(wbClass)})
}