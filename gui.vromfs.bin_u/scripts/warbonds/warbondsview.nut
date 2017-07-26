enum WARBOND_SHOP_LEVEL_STATUS {
  LOCKED = "locked"
  RECEIVED = "received"
  NEXT = "next"
}

::g_warbonds_view <- {
  progressBarId = "warbond_shop_progress"
  levelItemIdPrefix = "level_"

  MEDAL_FOR_SPEC_TASKS = ::getTblValue("specialTasksByMedal", ::configs.GUI.get().warbonds, 1)
}

function g_warbonds_view::createProgressBox(wbClass, placeObj, handler)
{
  if (!::check_obj(placeObj))
    return

  local nest = placeObj.findObject("progress_box_place")
  if (!::check_obj(nest))
    return

  local levelsData = ::configs.GUI.get().warbondsShopLevels
  local show = ::has_feature("Warbonds_2_0")
               && wbClass != null
               && wbClass.haveAnyOrdinaryRequirements()
               && levelsData != null
  nest.show(show)
  if (!show)
    return

  local pbMarkUp = getProgressBoxMarkUp()
  pbMarkUp += getLevelItemsMarkUp(levelsData, wbClass)

  nest.getScene().replaceContentFromText(nest, pbMarkUp, pbMarkUp.len(), handler)
  updateProgressBar(wbClass, nest)
}

function g_warbonds_view::getProgressBoxMarkUp()
{
  return ::handyman.renderCached("gui/commonParts/progressBarModern", { id = progressBarId })
}

function g_warbonds_view::getLevelItemsMarkUp(levelsData, wbClass, forcePosX = null)
{
  local lastRange = ::Point2(0,0)
  if (!forcePosX)
    lastRange = levelsData.getParamValue(levelsData.paramCount() - 1)

  local view = { level = [] }
  for (local i = 0; i < levelsData.paramCount(); i++)
    view.level.append(getLevelItemMarkUp(wbClass, i, lastRange, forcePosX))

  return ::handyman.renderCached("gui/items/warbondShopLevelItem", view)
}

function g_warbonds_view::getCurrentLevelItemMarkUp(wbClass)
{
  local curLevel = wbClass.getLevelData().Ordinary
  local curLevelData = getLevelItemMarkUp(wbClass, curLevel, null, "0")

  return ::handyman.renderCached("gui/items/warbondShopLevelItem", { level = [curLevelData]} )
}

function g_warbonds_view::getRangeForLevel(level)
{
  local levelsData = ::configs.GUI.get().warbondsShopLevels
  if (levelsData && levelsData.paramCount() > level)
    return levelsData.getParamValue(level)

  return ::Point2(0,0)
}

function g_warbonds_view::getLevelItemMarkUp(wbClass, level, lastRange = null, forcePosX = null)
{
  local range = getRangeForLevel(level)
  local status = getLevelStatus(wbClass, range)
  local posX = forcePosX? forcePosX : (range.y? ((range.y / lastRange.y) + "pw") : 0) + "- 50%w"

  local lvlText = level + 1
  return {
    id = levelItemIdPrefix + range.y
    text = ::get_roman_numeral(lvlText)
    tooltip = ::loc("warbonds/shop/level/" + status + "/tooltip", {level = lvlText, tasksNum = range.y})
    status = status
    posX = posX
  }
}

function g_warbonds_view::getLevelStatus(wbClass, levelRange)
{
  local curLevel = wbClass.getLevelData().Ordinary
  if (levelRange.y > 0 && ::clamp(curLevel, levelRange.x, levelRange.y) == curLevel)
    return WARBOND_SHOP_LEVEL_STATUS.NEXT

  if (levelRange.y > curLevel)
    return WARBOND_SHOP_LEVEL_STATUS.LOCKED

  return WARBOND_SHOP_LEVEL_STATUS.RECEIVED
}

function g_warbonds_view::updateProgressBar(wbClass, placeObj)
{
  local levelsData = ::configs.GUI.get().warbondsShopLevels
  if (!wbClass || !levelsData)
    return

  local progressBoxObj = placeObj.findObject(progressBarId)
  if (!::check_obj(progressBoxObj))
    return

  local lastRange = levelsData.getParamValue(levelsData.paramCount()-1)
  local curLevel = wbClass.getLevelData().Ordinary

  progressBoxObj.setValue(((curLevel.tofloat() / lastRange.y) * 10000.0).tointeger())
  progressBoxObj.tooltip = ::g_warbonds_view.getOrdinaryText(wbClass)
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

  nest.tooltip = ::loc("mainmenu/battleTasks/special/medals/tooltip",
    {
      medals = getMedalsCount(wbClass),
      tasksNum = MEDAL_FOR_SPEC_TASKS
    })
  local data = getSpecialMedalsMarkUp(wbClass)
  data += getSpecialMedalInProgressMarkUp(wbClass)
  nest.getScene().replaceContentFromText(nest, data, data.len(), handler)
}

function g_warbonds_view::getSpecialMedalsMarkUp(wbClass)
{
  local medals = getMedalsCount(wbClass)
  local view = { medal = [] }
  for (local i = 0; i < medals; i++)
    view.medal.append({
      posX = i? "-0.5*w" : 0
      image = wbClass? wbClass.getMedalIcon() : null
    })

  return ::handyman.renderCached("gui/items/warbondSpecialMedal", view)
}

function g_warbonds_view::getSpecialMedalInProgressMarkUp(wbClass)
{
  local leftTasks = leftForAnotherMedalTasks(wbClass)
  local view = { medal = [{
    sector = 360 - (360 * leftTasks.tofloat()/MEDAL_FOR_SPEC_TASKS)
    image = wbClass? wbClass.getMedalIcon() : null
  }]}
  return ::handyman.renderCached("gui/items/warbondSpecialMedal", view)
}

function g_warbonds_view::getMedalsCount(wbClass)
{
  if (!wbClass)
    return 0

  local curLevel = wbClass.getLevelData().Special
  return curLevel / MEDAL_FOR_SPEC_TASKS
}

function g_warbonds_view::leftForAnotherMedalTasks(wbClass)
{
  if (!wbClass)
    return MEDAL_FOR_SPEC_TASKS

  local curLevel = wbClass.getLevelData().Special
  local medals = getMedalsCount(wbClass)

  return curLevel - (medals * MEDAL_FOR_SPEC_TASKS)
}

function g_warbonds_view::showOrdinaryProgress(wbClass)
{
  return ::has_feature("Warbonds_2_0") && wbClass && wbClass.haveAnyOrdinaryRequirements()
}

function g_warbonds_view::getOrdinaryText(wbClass)
{
  if (!showOrdinaryProgress(wbClass))
    return ""

  return ::loc("mainmenu/battleTasks/doneTasks", {num = wbClass.getLevelData().Ordinary})
}

function g_warbonds_view::showSpecialProgress(wbClass)
{
  return ::has_feature("Warbonds_2_0") && wbClass && wbClass.haveAnySpecialRequirements()
}

function g_warbonds_view::getSpecialText(wbClass)
{
  if (!showSpecialProgress(wbClass))
    return ""

  return ::loc("mainmenu/battleTasks/special/medals", {medals = ::g_warbonds_view.getMedalsCount(wbClass)})
}