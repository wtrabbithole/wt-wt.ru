local time = require("scripts/time.nut")


::unlocks_punctuation_without_space <- ","
::map_mission_type_to_localization <- null

const FAVORITE_UNLOCKS_LIST_SAVE_ID = "favorite_unlocks"

::show_next_award_modetypes <- { //modeTypeName = localizationId
  char_versus_battles_end_count_and_rank_test = "battle_participate_award"
  char_login_count                            = "day_login_award"
}

::air_stats_list <- [
  { id="victories", icon = "lb_each_player_victories", text = "multiplayer/each_player_victories" }
  { id="sessions", icon = "lb_each_player_session", text = "multiplayer/each_player_session"
    countFunc = function(statBlk)
    {
      local sessions = statBlk.victories? statBlk.victories : 0
      sessions += statBlk.defeats? statBlk.defeats : 0
      return sessions
    }
  }
  { id="victories_battles", type = ::g_lb_data_type.PERCENT
    countFunc = function(statBlk)
    {
      local victories = statBlk.victories? statBlk.victories : 0
      local sessions = victories + (statBlk.defeats? statBlk.defeats : 0)
      if (sessions>0)
        return victories.tofloat() / sessions
      return 0
    }
  }
  "flyouts",
  "deaths",
  "air_kills",
  "ground_kills",
  {
    id   = "naval_kills",
    icon = "lb_naval_kills",
    text = "multiplayer/naval_kills",
    reqFeature = ["Ships"]
  }
  { id="wp_total", icon = "lb_wp_total_gained", text = "multiplayer/wp_total_gained", ownProfileOnly = true }
  { id="online_exp_total", icon = "lb_online_exp_gained_for_common", text = "multiplayer/online_exp_gained_for_common" }
]
foreach(idx, a in ::air_stats_list)
{
  if (typeof(a) == "string")
    ::air_stats_list[idx] = { id=a }
  if (!("type" in ::air_stats_list[idx]))
    ::air_stats_list[idx].type <- ::g_lb_data_type.NUM
}

::unlock_time_range_conditions <- ["timeRange", "char_time_range"]

function get_airs_stats_from_blk(blk)
{
  local res = {}
  foreach(diffName, diffBlk in blk)
  {
    if (!diffBlk || typeof(diffBlk)!="instance")
      continue

    local diffData = {}
    foreach(typeName, typeBlk in diffBlk)
    {
      if (!typeBlk || typeof(typeBlk)!="instance")
        continue

      local typeData = []
      foreach(airName, airBlk in typeBlk)
      {
        if (!airBlk || typeof(airBlk)!="instance")
          continue

        local airData = { name = airName }
        foreach(stat in ::air_stats_list)
        {
          if ("reqFeature" in stat && !::has_feature_array(stat.reqFeature))
            continue

          if ("countFunc" in stat)
            airData[stat.id] <- stat.countFunc(airBlk)
          else
            airData[stat.id] <- airBlk[stat.id]? airBlk[stat.id] : 0
        }
        typeData.append(airData)
      }
      if (typeData.len() > 0)
        diffData[typeName] <- typeData
    }
    if (diffData.len() > 0)
      res[diffName] <- diffData
  }
  return res
}

function is_unlocked_scripted(unlockType, id)
{
  local isUnlocked = ::is_unlocked(unlockType, id)
  if (isUnlocked)
  {
    if (unlockType < 0)
      unlockType = ::get_unlock_type_by_id(id)

    if (::is_platform_ps4 && unlockType == ::UNLOCKABLE_TROPHY_PSN)
      isUnlocked = ::ps4_is_trophy_unlocked(id)
    else if (::is_platform_xboxone && unlockType == ::UNLOCKABLE_TROPHY_XBOXONE)
      isUnlocked = ::xbox_is_achievement_unlocked(id)
  }
  return isUnlocked
}

function build_unlock_desc(item, params = {})
{
  local showStages = "stages" in item && item.stages.len() > 1
  if (!showStages && item.maxVal < 0)
    return item

  local isComplete = ::UnlockConditions.isBitModeType(item.type)
                       ? ::number_of_set_bits(item.curVal) >= ::number_of_set_bits(item.maxVal)
                       : item.curVal >= item.maxVal
  if (showStages && !isComplete)
    item.stagesText <- ::loc("challenge/stage", {
                         stage = ::colorize("unlockActiveColor", item.curStage + 1)
                         totalStages = ::colorize("unlockActiveColor", item.stages.len())
                       })

  local showProgress = ::getTblValue("showProgress", params, true)
  local progressText = ::UnlockConditions.getMainConditionText(item.conditions, showProgress? "%d" : null, "%d", params)
                       //to generate progress text for stages
  item.showProgress <- showProgress && (progressText != "")
  item.progressText <- progressText
  item.shortText <- ::g_string.implode([item.text, item.progressText], "\n")

  local showAsContent = ::getTblValue("showAsContent", params, false)
  if (showAsContent && ::getTblValue("isRevenueShare", item))
    item.text += (item.text.len() ? "\n" : "") + ::colorize("advertTextColor", ::loc("content/revenue_share"))

  item.text += (item.text.len() ? "\n\n" : "") + ::getUnlockDescription(item, params)
  return item
}

function getUnlockDescription(data, params = {})
{
  local descData = [::getTblValue("stagesText", data, "")]

  if (::getTblValue("locDescId", data, "") != "")
    descData.append(::loc(data.locDescId))

  if ("desc" in data)
    descData.append(data.desc)

  local curVal = ::getTblValue("curVal", params)
  if (curVal == null)
    curVal = ::getTblValue("showProgress", data, true) ? data.curVal : null

  local maxVal = ::getTblValue("maxVal", params)
  if (maxVal == null)
    maxVal = data.maxVal

  descData.append(::UnlockConditions.getConditionsText(data.conditions, curVal, maxVal, params))

  if (::getTblValue("showCost", params, false))
  {
    local cost = ::get_unlock_cost(data.id)
    if (cost > ::zero_money)
      descData.append(::loc("ugm/price") + ::loc("ui/colon") + ::colorize("unlockActiveColor", cost.getTextAccordingToBalance()))
  }

  return ::g_string.implode(descData, "\n")
}

function set_image_by_unlock_type(config, unlockBlk)
{
  local unlockType = ::get_unlock_type(::getTblValue("type", unlockBlk, ""))
  if (unlockType == ::UNLOCKABLE_MEDAL)
  {
    if (::getTblValue("subType", unlockBlk) == "clan_season_reward")
    {
      local unlock = ::ClanSeasonPlaceTitle.createFromUnlockBlk(unlockBlk)
      config.iconStyle <- unlock.iconStyle()
      config.iconParams <- unlock.iconParams()
    }
    else
      config.image <- ::get_image_for_unlockable_medal(unlockBlk.id)

    return
  }
  else if (unlockType == ::UNLOCKABLE_CHALLENGE && unlockBlk.showAsBattleTask)
    config.image <- unlockBlk.image

  local decoratorType = ::g_decorator_type.getTypeByUnlockedItemType(unlockType)
  if (decoratorType != ::g_decorator_type.UNKNOWN && !::is_in_loading_screen())
  {
    local decorator = ::g_decorator.getDecorator(unlockBlk.id, decoratorType)
    config.image <- decoratorType.getImage(decorator)
    config.imgRatio <- decoratorType.getRatio(decorator)
  }
}


function parse_personal_unlock_for_clan_season_id(id)
{
  local parts = ::g_string.split(id, "_")
  return {
    place = ::getTblValue(0, parts, "")
    difficultyName = ::getTblValue(1, parts, "")
    era = ::getTblValue(2, parts, "")
    seasonId = ::getTblValue(3, parts, "")
  }
}


function get_image_for_unlockable_medal(id)
{
  local image = ::format("!@#ui/medalskin#%s", id)
  return image
}


function set_description_by_unlock_type(config, unlockBlk)
{
  local unlockType = ::get_unlock_type(::getTblValue("type", unlockBlk, ""))
  if (unlockType == ::UNLOCKABLE_MEDAL)
  {

    if (::getTblValue("subType", unlockBlk) == "clan_season_reward")
    {
      local unlock = ::ClanSeasonPlaceTitle.createFromUnlockBlk(unlockBlk)
      config.desc <- unlock.desc()
    }
  }
  else if (unlockType == ::UNLOCKABLE_DECAL)
  {
    config.desc <- ::loc("decals/" + unlockBlk.id + "/desc", "")
  }
  else
  {
    config.desc <- ::loc(unlockBlk.id + "/desc", "")
  }
}


function get_empty_conditions_config()
{
  return {
    id = ""
    unlockType = -1
    text = ""
    locId = ""
    locDescId = ""
    curVal = 0
    maxVal = 0
    stages = []
    curStage = -1
    link = ""
    forceExternalBrowser = false
    iconStyle = ""
    iconParams = null
    image = ""
    imgRatio = 1.0
    playback = null
    type = ""
    conditions = []
    hasCustomUnlockableList = false
    names = [] //bit progress names. better to rename it.

    showProgress = true
    getProgressBarData = function()
    {
      local res = ::UnlockConditions.getProgressBarData(type, curVal, maxVal)
      res.show = res.show && showProgress
      return res
    }
  }
}

function build_conditions_config(blk, showStage = -1)
{
  local id = blk.getStr("id", "")
  local config = ::get_empty_conditions_config()
  config.id = id
  config.imgRatio = blk.getReal("aspect_ratio", 1.0)

  local type = blk.getStr("type", "")
  config.unlockType = ::get_unlock_type(type)
  config.locId = blk.getStr("locId", "")
  config.locDescId = blk.getStr("locDescId", "")
  config.link = ::g_promo.getLinkText(blk)
  config.forceExternalBrowser = ::getTblValue("forceExternalBrowser", blk, false)
  config.playback = ::getTblValue("playback", blk)

  config.iconStyle <- blk.iconStyle || config.iconStyle

  local unlocked = ::is_unlocked_scripted(config.unlockType, id)
  local icon = ::get_icon_from_unlock_blk(blk, unlocked)
  if (icon)
    config.image = icon
  else
    ::set_image_by_unlock_type(config, blk)
  ::set_description_by_unlock_type(config, blk)

  if (blk.isRevenueShare)
    config.isRevenueShare <- true

  if (blk._puType)
    config._puType <- blk._puType

  if (blk._acceptTime)
    config._acceptTime <- blk._acceptTime

  if (blk._controller)
    config._controller <- blk._controller

  foreach (modeIdx, mode in blk % "mode")
  {
    local modeType = mode.type || ""
    config.type = modeType

    if (config.unlockType == ::UNLOCKABLE_TROPHY_PSN)
    {
      //do not show secondary conditions anywhere for psn trophies
      config.conditions = []
      local mainCond = ::UnlockConditions.loadMainProgressCondition(mode)
      if (mainCond)
        config.conditions.append(mainCond)
    } else
      config.conditions = ::UnlockConditions.loadConditionsFromBlk(mode)

    local mainCond = ::UnlockConditions.getMainProgressCondition(config.conditions)

    config.hasCustomUnlockableList = ::getTblValue("hasCustomUnlockableList", mainCond, false)

    if (mainCond && mainCond.values && (mainCond.values.len() > 1 || config.hasCustomUnlockableList))
      config.names = mainCond.values //for easy support old values list

    config.maxVal = ::getTblValue("num", mainCond)
    config.curVal = 0

    if (modeType=="rank")
      config.curVal = ::get_player_rank_by_country(config.country)
    else if (::does_unlock_exist(id))
    {
      local progress = ::get_unlock_progress(id, modeIdx)
      if (modeType == "char_player_exp")
      {
        config.maxVal = ::get_rank_by_exp(progress.maxVal)
        config.curVal = ::get_rank_by_exp(progress.curVal)
      }
      else
      {
        if (!::g_battle_tasks.isBattleTask(id))
          config.maxVal = progress.maxVal
        else if (blk.__numToControl)
        {
          config.maxVal = blk.__numToControl
          if (mainCond)
            mainCond.num = blk.__numToControl
        }

        config.curVal = progress.curVal
      }
    }

    if (::UnlockConditions.isBitModeType(modeType) && mainCond)
      config.curVal = ((1 << mainCond.values.len()) - 1) & config.curVal
    else if (config.curVal > config.maxVal)
      config.curVal = config.maxVal
  }

  local haveBasicRewards = !blk.aircraftPresentExtMoneyback
  foreach(stage in blk % "stage")
  {
    local sData = { val = config.type == "char_player_exp"
                          ? ::get_rank_by_exp(stage.getInt("param", 1))
                          : stage.getInt("param", 1)
                  }
    if (haveBasicRewards)
      sData.reward <- ::get_reward_cost_from_blk(stage)
    config.stages.append(sData)
  }

  if (showStage >= 0 && blk.isMultiStage) // isMultiStage means stages are auto-generated (used only for streaks).
  {
    config.curStage = showStage
    config.maxVal = config.stages[0].val + showStage
  }
  else if (showStage >= 0 && showStage < config.stages.len())
  {
    config.curStage = showStage
    config.maxVal = config.stages[showStage].val
  }
  else
  {
    foreach(idx, stage in config.stages)
      if ((stage.val <= config.maxVal && stage.val > config.curVal)
          || (config.curStage < 0 && stage.val == config.maxVal && stage.val == config.curVal))
      {
        config.curStage = idx
        config.maxVal = stage.val
      }
  }

  if (haveBasicRewards)
  {
    local reward = ::get_reward_cost_from_blk(blk)
    if (reward > ::zero_money)
      config.reward <- reward
  }

  if (config.unlockType == ::UNLOCKABLE_WARBOND)
  {
    local wbAmount = blk.amount_warbonds
    if (wbAmount)
    {
      config.rewardWarbonds <- {
        wbName = blk.userLogId || id
        wbAmount = wbAmount
      }
    }
  }

  return config
}

function get_unlock_rewards_text(config)
{
  local textsList = []
  if ("reward" in config)
    textsList.append(config.reward.tostring())
  if ("rewardWarbonds" in config)
    textsList.append(
      ::g_warbonds.getWarbondPriceText(config.rewardWarbonds.wbName, null, config.rewardWarbonds.wbAmount)
    )
  return ::g_string.implode(textsList, ", ")
}

function get_icon_from_unlock_blk(unlockBlk, unlocked = true)
{
  if (!unlockBlk.icon)
    return null

  if (unlocked)
    return unlockBlk.icon

  if (unlockBlk.iconLocked)
    return unlockBlk.iconLocked

  local iconName = unlockBlk.icon
  local dotPlace = iconName.find(".")
  if (dotPlace != null)
    return iconName.slice(0, dotPlace) + "_locked" + iconName.slice(dotPlace)
  return iconName + "_locked"
}

function get_reward_cost_from_blk(blk)
{
  local res = ::Cost()
  res.wp = typeof(blk.amount_warpoints) == "instance" ? blk.amount_warpoints.x.tointeger() : blk.getInt("amount_warpoints", 0)
  res.gold = typeof(blk.amount_gold) == "instance" ? blk.amount_gold.x.tointeger() : blk.getInt("amount_gold", 0)
  res.frp = typeof(blk.amount_exp) == "instance" ? blk.amount_exp.x.tointeger() : blk.getInt("amount_exp", 0)
  return res
}

function is_unlock_visible(unlockBlk, needCheckVisibilityByPlatform = true)
{
  if (!unlockBlk)
    return false
  if (unlockBlk.hidden)
    return false

  if(needCheckVisibilityByPlatform && ! is_unlock_visible_on_cur_platform(unlockBlk))
    return false

  local unlockId = unlockBlk.id
  local name = unlockId || ""
  if (!::g_unlocks.isVisibleByTime(unlockId, true, !unlockBlk.hideUntilUnlocked)
    && !::is_unlocked_scripted(-1, name))
    return false
  if (unlockBlk.showByEntitlement && !::has_entitlement(unlockBlk.showByEntitlement))
    return false
  if ((unlockBlk % "hideForLang").find(::g_language.getLanguageName()) >= 0)
    return false
  foreach (feature in unlockBlk % "reqFeature")
    if (!::has_feature(feature))
      return false
  if (!::g_features.hasFeatureBasic("Tanks") && ::is_unlock_tanks_related(unlockId, unlockBlk))
    return false
  if (!::g_unlocks.checkDependingUnlocks(unlockBlk))
    return false
  if (::g_unlocks.isHiddenByUnlockedUnlocks(unlockBlk))
    return false
  return true
}

function is_unlock_visible_on_cur_platform(unlockBlk)
{
  if (unlockBlk.psn && !::is_platform_ps4)
    return false
  if (unlockBlk.ps_plus && !::ps4_has_psplus())
    return false
  if (unlockBlk.hide_for_platform == ::target_platform)
    return false

  local unlockType = ::get_unlock_type(unlockBlk.type || "")
  if (unlockType == ::UNLOCKABLE_TROPHY_PSN && !::is_platform_ps4)
    return false
  if (unlockType == ::UNLOCKABLE_TROPHY_XBOXONE && !::is_platform_xboxone)
    return false
  if (unlockType == ::UNLOCKABLE_TROPHY_STEAM && !::is_platform_pc)
    return false
  return true
}

function is_decal_visible(decalBlk)
{
  if (!::is_decal_allowed(decalBlk.getBlockName(), ""))
    return false
  if (decalBlk.psn && !::is_platform_ps4)
    return false
  if (decalBlk.ps_plus && !::ps4_has_psplus())
    return false
  if (decalBlk.hideUntilUnlocked && !::player_have_decal(decalBlk.getBlockName()))
    return false
  if (decalBlk.showByEntitlement && !::has_entitlement(decalBlk.showByEntitlement))
    return false
  if ((decalBlk % "hideForLang").find(::g_language.getLanguageName()) >= 0)
    return false
  foreach (feature in decalBlk % "reqFeature")
    if (!::has_feature(feature))
      return false
  return true
}

::tanks_related_unlocks <- {}

function is_unlock_tanks_related(unlockId = null, unlockBlk = null)
{
  unlockId = unlockId || unlockBlk && unlockBlk.id
  if (!unlockId)
    return false
  if (unlockId in ::tanks_related_unlocks)
    return ::tanks_related_unlocks[unlockId]
  local res = ::tanks_related_unlocks_parser(unlockBlk || ::g_unlocks.getUnlockById(unlockId))
  ::tanks_related_unlocks[unlockId] <- res
  return res
}

function tanks_related_unlocks_parser(unlockBlk)
{
  if (!unlockBlk)
    return false

  foreach (mode in unlockBlk % "mode")
  {
    if (mode.unitClass)
      return mode.unitClass == "tank" || ::getTblValue(mode.unitClass, ::mapWpUnitClassToWpUnitType, "") == "Tank"

    if (mode.type == "char_unit_exist")
      return ::isTank(::getAircraftByName(mode.unit))
    else if (mode.type == "char_unlocks")
    {
      foreach (unlockId in mode % "unlock")
        if (::is_unlock_tanks_related(unlockId))
          return true
    }

    foreach (condition in mode % "condition")
    {
      if (condition.type == "playerType")
      {
        foreach (unitType in condition % "unitType")
          if (::isInArray(unitType, ::stats_tanks))
            return true
        foreach (unitClass in condition % "unitClass")
          if (::getTblValue(unitClass, ::unlock_condition_unitclasses, ::ES_UNIT_TYPE_INVALID) == ::ES_UNIT_TYPE_TANK)
            return true
      }
      else if (condition.type == "playerUnit")
      {
        foreach (unitId in condition % "class")
          if (::isTank(::getAircraftByName(unitId)))
            return true
      }
    }
  }
  return false
}

function get_unlock_cost(id)
{
  return ::Cost(::wp_get_unlock_cost(id), ::wp_get_unlock_cost_gold(id))
}

function showUnlocksGroupWnd(unlocksLists)
{
  ::gui_start_modal_wnd(
    ::gui_handlers.showUnlocksGroupModal,
    { unlocksLists = unlocksLists }
  )
}

class ::gui_handlers.showUnlocksGroupModal extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/emptyFrame.blk"
  unlocksLists = null
  currentTab = 0

  function initScreen()
  {
    if (!checkUnlocksLists(unlocksLists))
      return goBack()

    //set initial window parameters
    local fObj = scene.findObject("wnd_frame")
    fObj["max-height"] = "1@maxWindowHeight"
    fObj["max-width"] = "1@maxWindowWidth"
    fObj["class"] = "wnd"
    local blocksCount = (getMaximumListlength(unlocksLists) > 3) ? 2 : 1
    fObj.width = blocksCount + "@unlockBlockWidth + " + blocksCount + "*3@framePadding"

    local listObj = scene.findObject("wnd_content")
    listObj.width = "pw"
    listObj["overflow-y"] = "auto"
    listObj.flow = "h-flow"
    listObj.scrollbarShortcuts = "yes"

    fillHeader()
    fillPage()
  }

  function reinitScreen(params = {})
  {
    setParams(params)
    initScreen()
  }


  /**
   * Create tabs for several unlock list or
   * jast fill header for one list
   */
  function fillHeader()
  {
    if (unlocksLists.len() > 1)
    {
      local view = {
        tabs = []
      }
      foreach(i, list in unlocksLists)
        view.tabs.push({
          tabName = ::getTblValue("titleText", list, "")
          navImagesText = ::get_navigation_images_text(i, unlocksLists.len())
        })

      local markup = ::handyman.renderCached("gui/frameHeaderTabs", view)
      local tabsObj = scene.findObject("tabs_list")
      tabsObj.show(true)
      tabsObj.enable(true)
      guiScene.replaceContentFromText(tabsObj, markup, markup.len(), this)
      tabsObj.setValue(0)
    }
    else
    {
      local titleText = ::getTblValue("titleText", unlocksLists[0], "")
      local titleObj = scene.findObject("wnd_title")
      titleObj.show(true)
      titleObj.setValue(titleText)
    }
  }


  /**
   * Goes throug lists and return true
   * if lists are valid, othrvise return false.
   */
  function checkUnlocksLists(lists)
  {
    if (!unlocksLists || !unlocksLists.len())
      return false

    foreach (unlockListData in lists)
    {
      if (!("unlocksList" in unlockListData))
        continue

      if (unlockListData.unlocksList.len())
        return true
    }
    return false
  }


  function getMaximumListlength(lists)
  {
    local result = 0
    foreach (list in lists)
    {
      local len = ::getTblValue("unlocksList", list, []).len()
      result = (result < len) ? len : result
    }
    return result
  }

  function addUnlock(idx, unlock, listObj)
  {
    local objId = "unlock_" + idx
    local obj = guiScene.createElementByObject(listObj, "gui/unlocks/unlockBlock.blk", "frameBlock_dark", this)
    obj.id = objId
    obj.width = "1@unlockBlockWidth"

    ::fill_unlock_block(obj, unlock)
  }

  function onAwardTooltipOpen(obj)
  {
    local id = getTooltipObjId(obj)
    if (!id)
      return

    local unlock = getUnlock(id.tointeger())
    ::build_unlock_tooltip_by_config(obj, unlock , this)
  }

  function onHeaderTabSelect(obj)
  {
    currentTab = obj.getValue()
    fillPage()
  }

  function fillPage()
  {
    local unlocksList = unlocksLists[currentTab].unlocksList
    local listObj = scene.findObject("wnd_content")
    local fObj = scene.findObject("wnd_frame")

    guiScene.setUpdatesEnabled(false, false)
    guiScene.replaceContentFromText(listObj, "", 0, this)
    for(local i = 0; i < unlocksList.len(); i++)
      addUnlock(i, unlocksList[i], listObj)
    guiScene.setUpdatesEnabled(true, true)
    listObj.select()
  }

  function getUnlock(id)
  {
    return ::getTblValue(idx, unlocksLists[currentTab])
  }
}

function fill_unlock_block(obj, config)
{
  local icoObj = obj.findObject("award_image")
  set_unlock_icon_by_config(icoObj, config)

  local tObj = obj.findObject("award_title_text")
  tObj.setValue("title" in config? config.title : "")

  local uObj = obj.findObject("unlock_name")
  uObj.setValue(::getTblValue("name", config, ""))

  local amount = ::getTblValue("amount", config, 1)

  if ("similarAwardNamesList" in config)
  {
    local maxStreak = ::getTblValue("maxStreak", config.similarAwardNamesList, 1)
    local repeatText = ::loc("streaks/rewarded_count", { count = ::colorize("activeTextColor", amount) })
    if (!::g_unlocks.hasSpecialMultiStageLocId(config.id, maxStreak))
      repeatText = ::format(::loc("streaks/max_streak_amount"), maxStreak.tostring()) + "\n" + repeatText
    obj.findObject("mult_awards_text").setValue(repeatText)
  }

  local dObj = obj.findObject("desc_text")
  dObj.setValue("desc" in config? config.desc : "")

  if (("progressBar" in config) && config.progressBar.show)
  {
    local pObj = obj.findObject("progress")
    pObj.setValue(config.progressBar.value)
    pObj.show(true)
  }

  if (config?.showAsTrophyContent)
  {
    local isUnlocked = ::is_unlocked_scripted(-1, config?.id)
    local text = ::loc(isUnlocked ? "mainmenu/itemReceived" : "mainmenu/itemCanBeReceived")
    if (isUnlocked)
      text += "\n" + ::colorize("badTextColor", ::loc("mainmenu/receiveOnlyOnce"))
    obj.findObject("state").show(true)
    obj.findObject("state_text").setValue(text)
    obj.findObject("state_icon")["background-image"] = isUnlocked ? "#ui/gameuiskin#favorite" : "#ui/gameuiskin#locked"
  }

  local rObj = obj.findObject("award_text")
  rObj.setValue(("rewardText" in config && config.rewardText != "")? (::loc("challenge/reward") + " " + config.rewardText) : "")

  local awMultObj = obj.findObject("award_multiplier")
  if (::checkObj(awMultObj))
  {
    local show = amount > 1
    awMultObj.show(show)
    if (show)
      awMultObj.findObject("amount_text").setValue("x" + amount)
  }
}

function set_unlock_icon_by_config(obj, config)
{
  local iconStyle = ("iconStyle" in config)? config.iconStyle : ""
  local iconParams = ::getTblValue("iconParams", config, null)
  local ratio = (("descrImage" in config) && ("descrImageRatio" in config))? config.descrImageRatio : 1.0
  local image = ("descrImage" in config)? config.descrImage : ""
  ::LayersIcon.replaceIcon(obj, iconStyle, image, ratio, null, iconParams)
}

function build_unlock_tooltip_by_config(obj, config, handler)
{
  local guiScene = obj.getScene()
  guiScene.replaceContent(obj, "gui/unlocks/unlockBlock.blk", handler)

  obj["min-width"] = "0.8@unlockBlockWidth"

  ::fill_unlock_block(obj, config)
}

function get_unlock_description(unlockName, forUnlockedStage = -1, showProgress = false)
{
  local unlock = ::g_unlocks.getUnlockById(unlockName)
  if (!unlock)
    return ""

  local config = build_conditions_config(unlock, forUnlockedStage)
  config = ::build_unlock_desc(config, {showProgress = showProgress})
  return config.text
}

function get_unlock_reward(unlockName)
{
  local unlock = ::g_unlocks.getUnlockById(unlockName)
  if (!unlock)
    return ""

  local wpReward = typeof(unlock.amount_warpoints) == "instance"
                   ? unlock.amount_warpoints.x.tointeger()
                   : unlock.getInt("amount_warpoints", 0)
  local goldReward = typeof(unlock.amount_gold) == "instance"
                     ? unlock.amount_gold.x.tointeger()
                     : unlock.getInt("amount_gold", 0)
  local xpReward = typeof(unlock.amount_exp) == "instance"
                   ? unlock.amount_exp.x.tointeger()
                   : unlock.getInt("amount_exp", 0)
  local reward = ::Cost(wpReward, goldReward, xpReward)

  return ::buildRewardText("", reward, true, true)
}

function show_sm_unlock_description(unlockName, afterFunc)
{
  local msg = ::loc("charServer/needUnlock") + "\n\n" + ::get_unlock_description(unlockName, 1)
  ::scene_msg_box("in_demo_only", null, msg,
         [["ok", afterFunc ]], "ok")
}

::default_unlock_data <- {
  id = ""
  type = -1
  title = ""
  name = ""
  image = "#ui/gameuiskin#unlocked"
  image2 = ""
  rewardText = ""
  wp = 0
  gold = 0
  rp = 0
  frp = 0
  exp = 0
  amount = 1 //for multiple awards such as streaks x3, x4...
  aircraft = []
  stage = -1
  desc = ""
  link = ""
  forceExternalBrowser = false
}

function create_default_unlock_data()
{
  return clone ::default_unlock_data
}

function getDifficultyLocalizationText(difficulty)
{
  if (difficulty == "hardcore")
    return ::loc("difficulty2")
  else if (difficulty == "realistic")
    return ::loc("difficulty1")
  else
    return ::loc("difficulty0")
}

function get_mode_localization_text(modeInt)
{
  if (::map_mission_type_to_localization == null)
  {
    local blk = ::get_game_settings_blk()
    if (!blk.mapIntDiffToName)
      return null

    ::map_mission_type_to_localization = ::buildTableFromBlk(blk.mapIntDiffToName)
  }

  return ::getTblValue(modeInt.tostring(), ::map_mission_type_to_localization, "")
}

function get_unlock_name_text(unlockType, id)
  //unlockType = -1 will find unlock by id, so better to use correct unlocktype when already known
{
  if (::g_battle_tasks.isBattleTask(id))
    return ::g_battle_tasks.getLocalizedTaskNameById(id)

  if (unlockType < 0)
    unlockType = ::get_unlock_type_by_id(id)
  switch (unlockType)
  {
    case ::UNLOCKABLE_AIRCRAFT:
      return ::getUnitName(id)

    case ::UNLOCKABLE_SKIN:
      local unitName = ::g_unlocks.getPlaneBySkinId(id)
      local res = ::loc(id)
      if (unitName != "")
        res += ::loc("ui/parentheses/space", { text = ::getUnitName(unitName) })
      return res

    case ::UNLOCKABLE_DECAL:
      return ::loc("decals/" + id)

    case ::UNLOCKABLE_WEAPON:
      return ""

    case ::UNLOCKABLE_DIFFICULTY:
      return ::getDifficultyLocalizationText(id)

    case ::UNLOCKABLE_ENCYCLOPEDIA:
      local index = id.find("/")
      if (index != null)
        return ::loc("encyclopedia/" + id.slice(index + 1))
      return ::loc("encyclopedia/" + id)

    case ::UNLOCKABLE_SINGLEMISSION:
      local index = id.find("/")
      if (index != null)
        return ::loc("missions/" + id.slice(index + 1))
      return res.name = ::loc("missions/" + id)

    case ::UNLOCKABLE_TITLE:
      return ::loc("title/"+id)

    case ::UNLOCKABLE_PILOT:
      return ""
             //(::loc("pilots/"+id+"/firstName"))
             // + " " + (::loc("pilots/"+id+"/lastName"))

    case ::UNLOCKABLE_STREAK:
      local res = ::loc("streaks/" + id)
      if (res.find("%d") != null)
          res = ::loc("streaks/" + id + "/multiple")
      return res

    case ::UNLOCKABLE_AWARD:
      return ::loc("award/"+id)

    case ::UNLOCKABLE_ENTITLEMENT:
      local ent = ::get_entitlement_config(id)
      return ::get_entitlement_name(ent)

    case ::UNLOCKABLE_COUNTRY:
      return ::loc(id)

    case ::UNLOCKABLE_AUTOCOUNTRY:
      return ::loc("award/autocountry")

    case ::UNLOCKABLE_SLOT:
      return ::loc("options/crew")

    case ::UNLOCKABLE_DYNCAMPAIGN:
      local parts = ::split(id, "_")
      local countryId = (parts.len() > 1) ? "country_" + parts[parts.len() - 1] : null
      if (::isInArray(countryId, ::shopCountriesList))
        parts.pop()
      else
        countryId = null
      local locId = "dynamic/" + ::g_string.implode(parts, "_")
      return ::loc(locId) + (countryId ? ::loc("ui/parentheses/space", { text = ::loc(countryId) }) : "")

    case ::UNLOCKABLE_TROPHY:
      local item = ::ItemsManager.findItemById(id, itemType.TROPHY)
      return item ? item.getName(false) : ::loc("item/" + id)

    case ::UNLOCKABLE_YEAR:
      return id.len() > 4 ? id.slice(id.len()-4, id.len()) : ""

    case ::UNLOCKABLE_MEDAL:
      local unlockBlk = ::g_unlocks.getUnlockById(id)
      if (::getTblValue("subType", unlockBlk) == "clan_season_reward")
      {
        local unlock = ::ClanSeasonPlaceTitle.createFromUnlockBlk(unlockBlk)
        return unlock.name()
      }
      break
  }

  return ::loc(id + "/name")
}

function get_unlock_type_text(unlockType, id = null)
{
  if (unlockType == ::UNLOCKABLE_AUTOCOUNTRY)
    return ::loc("unlocks/country")

  if (id && ::g_battle_tasks.isBattleTask(id))
    return ::loc("unlocks/battletask")

  return ::loc("unlocks/" + ::get_name_by_unlock_type(unlockType))
}

function does_unlock_exist(unlockId)
{
  return ::get_unlock_type_by_id(unlockId) != ::UNLOCKABLE_UNKNOWN
}

function build_log_unlock_data(config)
{
  local showProgress = config?.showProgress ?? false
  local needTitle = config?.needTitle ?? true

  local res = ::create_default_unlock_data()
  local realId = ("unlockId" in config)? config.unlockId : ("id" in config)? config.id : ""
  local unlockBlk = ::g_unlocks.getUnlockById(realId)

  local type = ("unlockType" in config)? config.unlockType : ("type" in config)? config.type : -1
  if (type < 0)
    type = (unlockBlk && unlockBlk.type)? ::get_unlock_type(unlockBlk.type) : -1
  local stage = ("stage" in config)? config.stage : -1
  local isMultiStage = (unlockBlk && unlockBlk.isMultiStage) ? true : false // means stages are auto-generated (used only for streaks).
  local id = ("displayId" in config)? config.displayId : realId

  res.desc = ""
  local cond = {}
  if (unlockBlk)
  {
    cond = ::build_conditions_config(unlockBlk, stage)
    local isProgressing = showProgress && (stage == -1 || stage == cond.curStage) && cond.curVal < cond.maxVal
    local progressData = isProgressing ? cond.getProgressBarData() : null
    local haveProgress = ::getTblValue("show", progressData, false)
    if (haveProgress)
      res.progressBar <- progressData
    local description = ::build_unlock_desc(cond, {showProgress = haveProgress})
    res.desc = description.text
    res.link = unlockBlk.link || ""
    res.forceExternalBrowser = unlockBlk.forceExternalBrowser || false
  }
  if (res.desc == "" && id!=realId)
    res.desc = ::loc(id + "/desc", "")

  res.id = id
  res.type = type
  res.rewardText = ""
  res.amount = ::getTblValue("amount", config, res.amount)

  if (::g_battle_tasks.isBattleTask(realId))
  {
    if (needTitle)
      res.title = ::loc("unlocks/battletask")
    res.name = ::g_battle_tasks.getLocalizedTaskNameById(realId)
  } else
  {
    res.name = ::get_unlock_name_text(type, id)
    if (needTitle)
      res.title = ::get_unlock_type_text(type, id)
  }

  if (config?.showAsTrophyContent)
    res.showAsTrophyContent <- true

  switch (type)
  {
    case ::UNLOCKABLE_SKIN:
    case ::UNLOCKABLE_ATTACHABLE:
    case ::UNLOCKABLE_DECAL:
      local decoratorType = ::g_decorator_type.getTypeByUnlockedItemType(type)
      res.image = decoratorType.userlogPurchaseIcon
      res.name = decoratorType.getLocName(id)

      local decorator = ::g_decorator.getDecorator(id, decoratorType)
      if (decorator && !::is_in_loading_screen())
      {
        res.descrImage <- decoratorType.getImage(decorator)
        res.descrImageSize <- decoratorType.getImageSize(decorator)
        res.descrImageRatio <- decoratorType.getRatio(decorator)
      }
      break

    case ::UNLOCKABLE_MEDAL:
      if (id != "")
      {
        local imagePath = "!@#ui/medalskin#" + id
        res.image = "!@#ui/medalskin#" + id
        res.descrImage <- ::getTblValue("image", cond, imagePath + "_big")
        res.descrImageSize <- "128, 128"
      }
      break

    case ::UNLOCKABLE_CHALLENGE:
      local challengeDescription = ::loc(id+"/desc", "")
      if (challengeDescription && challengeDescription != "")
        res.desc = challengeDescription
      res.image = "#ui/gameuiskin#unlock_challenge"
      break

    case ::UNLOCKABLE_SINGLEMISSION:
      res.image = "#ui/gameuiskin#unlock_mission"
      break

    case ::UNLOCKABLE_TITLE:
    case ::UNLOCKABLE_ACHIEVEMENT:
      local challengeDescription = ::loc(id+"/desc", "")
      if (challengeDescription && challengeDescription != "")
        res.desc = challengeDescription
      res.image = "#ui/gameuiskin#unlock_achievement"
      break

    case ::UNLOCKABLE_TROPHY_STEAM:
      res.image = "#ui/gameuiskin#unlock_achievement"
      break

    case ::UNLOCKABLE_PILOT:
      if (id!="")
      {
        res.descrImage <- "#ui/images/avatars/" + id
        res.descrImageSize <- "100, 100"
        res.needFrame <- true
      }
      break

    case ::UNLOCKABLE_STREAK:
      local name = ::loc("streaks/" + id)
      local desc = ::loc("streaks/" + id + "/desc", "")
      local iconStyle = "streak_" + id

      if (isMultiStage && stage >= 0 && unlockBlk.stage && unlockBlk.stage.param != null)
      {
        res.stage = stage
        local maxStreak = unlockBlk.stage.param.tointeger() + stage
        if ("similarAwards" in config && config.similarAwards.len() > 0)
        {
          ::checkAwardsAmountPeerSession(res, config, maxStreak, name)
          maxStreak = res.similarAwardNamesList.maxStreak
          name = ::loc("streaks/" + id + "/multiple", name)
          desc = ::loc("streaks/" + id + "/multiple/desc", desc)
        }
        else (::g_unlocks.isUnlockMultiStageLocId(id))
        {
          local stageId = ::g_unlocks.getMultiStageId(id, maxStreak)
          name = ::loc("streaks/" + stageId)
          iconStyle = "streak_" + stageId
        }

        name = ::format(name, maxStreak)
        desc = ::format(desc, maxStreak)
      }
      else
      {
        if (name.find("%d") != null)
          name = ::loc("streaks/" + id + "/multiple")
        if (desc.find("%d") != null)
        {
          local descValue = unlockBlk.stage ? ::getTblValue("param", unlockBlk.stage, 0) : ::getTblValue("num", unlockBlk.mode, 0)
          if (descValue > 0)
            desc = ::format(desc, descValue)
          else
            desc = ::loc("streaks/" + id + "/multiple/desc", desc)
        }
      }

      res.name = name
      res.desc = desc
      res.image = "#ui/gameuiskin#unlock_streak"
      res.iconStyle <- iconStyle
      break

    case ::UNLOCKABLE_AWARD:
      res.desc = ::loc("award/"+id+"/desc", "")
      if (id == "money_back")
      {
        local unitName = ::getTblValue("unit", config)
        if (unitName)
          res.desc += ((res.desc == "")? "":"\n") + ::loc("award/money_back/unit", { unitName = ::getUnitName(unitName)})
      }
      break

    case ::UNLOCKABLE_AUTOCOUNTRY:
      res.rewardText = ::loc("award/autocountry")
      break

    case ::UNLOCKABLE_SLOT:
      local slotNum = ::getTblValue("slot", config, 0)
      res.name = (slotNum > 0)
        ? ::loc("options/crewName") + slotNum.tostring()
        : ::loc("options/crew")
      res.desc = ::loc("slot/"+id+"/desc", "")
      res.image = "#ui/gameuiskin#log_crew"
      break;

    case ::UNLOCKABLE_DYNCAMPAIGN:
    case ::UNLOCKABLE_YEAR:
      if(unlockBlk && unlockBlk.mode && unlockBlk.mode.country)
        res.image = ::get_country_icon(unlockBlk.mode.country)
      break

    case ::UNLOCKABLE_SKILLPOINTS:
      local slotId = ::getTblValue("slot", config, -1)
      local crew = ::get_crew_by_id(slotId)
      local crewName = crew? ::g_crew.getCrewName(crew) : ::loc("options/crew")
      local country = crew? crew.country : ("country" in config)? config.country : ""
      local skillPoints = ::getTblValue("sp" ,config, 0)
      local skillPointsStr = ::getCrewSpText(skillPoints)

      if (::checkCountry(country, "userlog EULT_*_CREW"))
        res.image2 = ::get_country_icon(country)

      res.desc = crewName + ::loc("unlocks/skillpoints/desc") + skillPointsStr
      res.image = "#ui/gameuiskin#log_crew"
      break

    case ::UNLOCKABLE_TROPHY:
      local item = ::ItemsManager.findItemById(id)
      if (item)
      {
        res.title = ::get_unlock_type_text(type, realId)
        res.name = ::get_unlock_name_text(type, realId)
        res.image = item.getSmallIconName()
        res.desc = item.getDescription()
        res.rewardText = item.getName()
      }
      break

    case ::UNLOCKABLE_WARBOND:
      local wbAmount = ::getTblValue("warbonds", config, 0)
      local wbStageName = ::getTblValue("warbondStageName", config)
      local wb = ::g_warbonds.findWarbond(id, wbStageName)
      if (wb && wbAmount)
        res.rewardText = wb.getPriceText(wbAmount, false, false)
      break
  }

  if (unlockBlk && unlockBlk.locId)
    res.name = ::get_locId_name(unlockBlk)
  if (unlockBlk && unlockBlk.customDescription && unlockBlk.customDescription != "")
    res.desc = ::loc(unlockBlk.customDescription, "")

  local rewards = {wp = "amount_warpoints", exp = "amount_exp", gold = "amount_gold"}
  local rewardsWasLoadedFromLog = false;
  foreach( nameInConfig, nameInBlk in rewards) //try load rewards data from log first because
    if (nameInConfig in config)                //award message can haven't appropriate unlock
    {
      res[nameInConfig] = config[nameInConfig]
      rewardsWasLoadedFromLog = true;
    }
  if ("exp" in config)
  {
    res.frp = config.exp
    rewardsWasLoadedFromLog = true;
  }

  if ("userLogId" in config)
  {
    local itemId = config.userLogId
    local item = ::ItemsManager.findItemById(itemId)
    if (item)
    {
      res.rewardText += item.getName()
      res.rewardText += "\n" + item.getNameMarkup()
    }
  }

  //check rewards and stages
  if (unlockBlk)
  {
    local rBlock = ::DataBlock()
    rewardsWasLoadedFromLog = rewardsWasLoadedFromLog || unlockBlk.aircraftPresentExtMoneyback == true

    // stage >= 0 means there are stages.
    // isMultiStage=false means stages are hard-coded (usually used for challenges and achievements).
    // isMultiStage=true means stages are auto-generated (usually used only for streaks).
    // there are streaks with stages and isMultiStage=false and they should have own name, icon, etc
    if (stage >= 0 && !isMultiStage && type != ::UNLOCKABLE_STREAK)
    {
      local curStage = -1
      for (local j = 0; j < unlockBlk.blockCount(); j++)
      {
        local sBlock = unlockBlk.getBlock(j)
        if (sBlock.getBlockName() != "stage")
          continue

        curStage++
        if (curStage==stage)
        {
          rBlock = sBlock
          res.name += " " + ::get_roman_numeral(stage + 1)
          res.stage <- stage
          res.unlocked <- true
          res.iconStyle <- "default_unlocked"
        } else
        if (curStage > stage)
        {
          if (stage >= 0)
          {
            res.unlocked = false
            res.iconStyle <- "default_locked_stage_" + (stage + 1)
          }
          break
        }
      }
      if (curStage!=stage)
        stage = -1
    }
    if (stage<0)  //no stages
      rBlock = unlockBlk

    if (rBlock.iconStyle)
      res.iconStyle <- rBlock.iconStyle

    if (::getTblValue("descrImage", res, "") == "")
    {
      local icon = ::get_icon_from_unlock_blk(unlockBlk, true)
      if (icon)
        res.descrImage <- icon
      else if (::getTblValue("iconStyle", res, "") == "")
        res.iconStyle <- "default_unlocked"
    }

    if (!rewardsWasLoadedFromLog)
    {
      foreach( nameInConfig, nameInBlk in rewards)
      {
        res[nameInConfig] = rBlock[nameInBlk]? rBlock[nameInBlk] : 0
        if (typeof(res[nameInConfig]) == "instance")
          res[nameInConfig] = res[nameInConfig].x
      }
      if (rBlock["amount_exp"])
        res.frp = (typeof(rBlock["amount_exp"]) == "instance") ? rBlock["amount_exp"].x : rBlock["amount_exp"]
    }

    local popupImage = ::g_language.getLocTextFromConfig(rBlock, "popupImage", "")
    if (popupImage != "")
      res.popupImage <- popupImage
  }

  local cost = ::Cost(::getTblValue("wp", res, 0),
                      ::getTblValue("gold", res, 0),
                      ::getTblValue("frp", res, 0),
                      ::getTblValue("rp", res, 0))

  res.rewardText = ::colorize("activeTextColor", res.rewardText + cost.tostring())
  res.showShareBtn <- true

  if ("miscMsg" in config) //for misc params from userlog
    res.miscParam <- config.miscMsg
  return res
}

function get_fake_unlock_data(config)
{
  local res = {}
  foreach(key, value in ::default_unlock_data)
    res[key] <- (key in config)? config[key] : value
  foreach(key, value in config)
    if (!(key in res))
      res[key] <- value
  return res
}

function get_locId_name(config, key = "locId")
{
  local name = ""
  local parsedString = ::split(config[key], "; ")
  if (parsedString.len() <= 1)
    name = ::loc(config[key])
  else
    foreach(idx, namePart in parsedString)
      if (namePart.len() == 1 && ::unlocks_punctuation_without_space.find(namePart) != null)
        name += namePart
      else
        name += ((name == ""? "" : " ") + ::loc(namePart))
  return name
}

function get_next_award_text(unlockId)
{
  local res = ""
  if (!::has_feature("ShowNextUnlockInfo"))
    return res

  local unlockBlk = ::g_unlocks.getUnlockById(unlockId)
  if (!unlockBlk)
    return res

  local modeType = null
  local num = 0
  foreach (mode in unlockBlk % "mode")
  {
    local mType = mode.getStr("type", "")
    if (mType in ::show_next_award_modetypes)
    {
      modeType = mType
      num = mode.getInt("num", 0)
      break
    }
    if (mType == "char_unlocks") //for unlocks unlocked by other unlock
    {
      foreach (uId in mode % "unlock")
      {
        res = ::get_next_award_text(uId)
        if (res != "")
          return res
      }
      break
    }
  }
  if (!modeType)
    return res

  local nextUnlock = null
  local nextStage = -1
  local nextNum = -1
  foreach(cb in ::g_unlocks.getAllUnlocksWithBlkOrder())
    if (!cb.hidden || (cb.type && ::get_unlock_type(cb.type) == ::UNLOCKABLE_AUTOCOUNTRY))
      foreach (modeIdx, mode in cb % "mode")
        if (mode.getStr("type", "") == modeType)
        {
          local n = mode.getInt("num", 0)
          if (n > num && (!nextUnlock || n < nextNum))
          {
            nextUnlock = cb
            nextNum = n
            nextStage = modeIdx
            break
          }
        }
  if (!nextUnlock)
    return res

  local diff = nextNum - num
  local locId = ::show_next_award_modetypes[modeType]
  locId += "/" + ((diff == 1)? "one_more" : "several")

  local unlockData = ::build_log_unlock_data({ id = nextUnlock.id, stage = nextStage })
  res = ::loc("next_award", { awardName = unlockData.name })
  if (unlockData.rewardText != "")
    res += ::loc("ui/colon") + "\n" + ::loc(locId, { amount = diff
                                                     reward = unlockData.rewardText
                                                   })
  return res
}

function checkAwardsAmountPeerSession(res, config, streak, name)
{
  local maxStreak = streak

  res.similarAwardNamesList <- {}
  foreach(simAward in config.similarAwards)
  {
    local simUnlock = ::g_unlocks.getUnlockById(simAward.unlockId)
    local simStreak = simUnlock.stage.param.tointeger() + simAward.stage
    maxStreak = ::max(simStreak, maxStreak)
    local simAwName = ::format(name, simStreak)
    if (simAwName in res.similarAwardNamesList)
      res.similarAwardNamesList[simAwName]++
    else
      res.similarAwardNamesList[simAwName] <- 1
  }

  local mainAwName = ::format(name, streak)
  if (mainAwName in res.similarAwardNamesList)
    res.similarAwardNamesList[mainAwName]++
  else
    res.similarAwardNamesList[mainAwName] <- 1
  res.similarAwardNamesList.maxStreak <- maxStreak
}

function combineSimilarAwards(awardsList)
{
  local amount = 1
  local res = []

  foreach(award in awardsList)
  {
    local found = false
    if ("unlockType" in award && award.unlockType == ::UNLOCKABLE_STREAK)
    {
      local unlockId = award.unlockId
      local isMultiStageLoc = ::g_unlocks.isUnlockMultiStageLocId(unlockId)
      local stage = ::getTblValue("stage", award, 0)
      local hasSpecialMultiStageLoc = ::g_unlocks.hasSpecialMultiStageLocIdByStage(unlockId, stage)
      foreach(approvedAward in res)
      {
        if (unlockId != approvedAward.unlockId)
          continue
        if (isMultiStageLoc)
        {
          local approvedStage = ::getTblValue("stage", approvedAward, 0)
          if (stage != approvedStage
            && (hasSpecialMultiStageLoc || ::g_unlocks.hasSpecialMultiStageLocIdByStage(unlockId, approvedStage)))
           continue
        }
        approvedAward.amount++
        approvedAward.similarAwards.append(award)
        foreach(name in ["wp", "exp", "gold"])
          if (name in approvedAward && name in award)
            approvedAward[name] += award[name]
        found = true
        break
      }
    }

    if (found)
      continue

    res.append(award)
    local array = res.top()
    array.amount <- 1
    array.similarAwards <- []
  }

  return res
}

function is_any_award_received_by_mode_type(modeType)
{
  foreach(cb in ::g_unlocks.getAllUnlocks())
    foreach (mode in cb % "mode")
    {
      if (mode.type == modeType && cb.id && ::is_unlocked_scripted(-1, cb.id))
        return true
      break
    }
  return false
}

function req_unlock_by_client(id, disableLog)
{
  local unlock = ::g_unlocks.getUnlockById(id)
  local featureName =  ::getTblValue("check_client_feature", unlock, null)
  if (featureName == null || ::has_feature(featureName))
      return ::req_unlock(id, disableLog)

  return -1
}

::g_unlocks <- {
  [PERSISTENT_DATA_PARAMS] = ["cache", "cacheArray"] //to do not parse again on script reload

  unitNameReg = ::regexp2(@"[.*/].+")
  skinNameReg = ::regexp2(@"^[^/]*/")
  cache = {}
  cacheArray = []
  cacheByType = {} //<unlockTypeName> = { byName = { <unlockId> = <unlockBlk> }, inOrder = [<unlockBlk>] }
  isCacheValid = false
  isFavUnlockCacheValid = false
  favoriteUnlocks = null
  favoriteInvisibleUnlocks = null

  multiStageLocId =
  {
    multi_kill_air =    {[2] = "double_kill_air",    [3] = "triple_kill_air",    def = "multi_kill_air"}
    multi_kill_ship =   {[2] = "double_kill_ship",   [3] = "triple_kill_ship",   def = "multi_kill_ship"}
    multi_kill_ground = {[2] = "double_kill_ground", [3] = "triple_kill_ground", def = "multi_kill_ground"}
  }
}

function g_unlocks::validateCache()
{
  if (isCacheValid)
    return

  isCacheValid = true
  cache.clear()
  cacheArray.clear()
  cacheByType.clear()
  _convertblkToCache(::get_unlocks_blk())
  _convertblkToCache(::get_personal_unlocks_blk())
}

function g_unlocks::_convertblkToCache(blk)
{
  foreach(unlock in (blk % "unlockable"))
  {
    cache[unlock.id] <- unlock
    cacheArray.append(unlock)

    local typeName = unlock.type
    if (!(typeName in cacheByType))
      cacheByType[typeName] <- { byName = {}, inOrder = [] }
    cacheByType[typeName].byName[unlock.id] <- unlock
    cacheByType[typeName].inOrder.append(unlock)
  }
}

function g_unlocks::getAllUnlocks()
{
  validateCache()
  return cache
}

function g_unlocks::getAllUnlocksWithBlkOrder()
{
  validateCache()
  return cacheArray
}

function g_unlocks::getUnlockById(unlockId)
{
  if (::g_login.isLoggedIn())
    return ::getTblValue(unlockId, getAllUnlocks())

  //For before login actions.
  local blk = ::get_unlocks_blk()
  foreach(cb in (blk % "unlockable"))
    if (cb.id == unlockId)
      return cb
  return null
}

function g_unlocks::getUnlocksByType(typeName)
{
  validateCache()
  local data = ::getTblValue(typeName, cacheByType)
  return data ? data.byName : {}
}

function g_unlocks::getUnlocksByTypeInBlkOrder(typeName)
{
  validateCache()
  local data = ::getTblValue(typeName, cacheByType)
  return data ? data.inOrder : []
}

function g_unlocks::getPlaneBySkinId(id)
{
  return unitNameReg.replace("", id)
}

function g_unlocks::getSkinNameBySkinId(id)
{
  return skinNameReg.replace("", id)
}

function g_unlocks::getSkinId(unitName, skinName)
{
  return unitName + "/" + skinName
}

function g_unlocks::isDefaultSkin(id)
{
  return getSkinNameBySkinId(id) == "default"
}

function g_unlocks::checkDependingUnlocks(unlockBlk)
{
  if (!unlockBlk || !unlockBlk.hideUntilPrevUnlocked)
    return true

  local prevUnlocksArray = ::split(unlockBlk.hideUntilPrevUnlocked, "; ")
  foreach (prevUnlockId in prevUnlocksArray)
    if (!::is_unlocked_scripted(-1, prevUnlockId))
      return false
  return true
}

function g_unlocks::onEventSignOut(p)
{
  invalidateUnlocksCache()
}

function g_unlocks::onEventLoginComplete(p)
{
  invalidateUnlocksCache()
}

function g_unlocks::onEventProfileUpdated(p)
{
  invalidateUnlocksCache()
}

function g_unlocks::invalidateUnlocksCache()
{
  isCacheValid = false
  isFavUnlockCacheValid = null
  ::broadcastEvent("UnlocksCacheInvalidate")
}

function g_unlocks::isUnlockMultiStageLocId(unlockId)
{
  return unlockId in multiStageLocId
}

function g_unlocks::getUnlockRepeatInARow(unlockId, stage)
{
  return stage + ::getTblValueByPath("stage.param", ::g_unlocks.getUnlockById(unlockId), 0)
}

//has not default multistage id. Used to combine similar unlocks.
function g_unlocks::hasSpecialMultiStageLocId(unlockId, repeatInARow)
{
  return isUnlockMultiStageLocId(unlockId) && repeatInARow in multiStageLocId[unlockId]
}

function g_unlocks::hasSpecialMultiStageLocIdByStage(unlockId, stage)
{
  return hasSpecialMultiStageLocId(unlockId, getUnlockRepeatInARow(unlockId, stage))
}

function g_unlocks::getMultiStageId(unlockId, repeatInARow)
{
  if (!isUnlockMultiStageLocId(unlockId))
    return unlockId
  local config = multiStageLocId[unlockId]
  return ::getTblValue(repeatInARow, config) || ::getTblValue("def", config, unlockId)
}

function g_unlocks::checkUnlockString(string)
{
  local unlocks = ::split(string, ";")
  foreach (unlockId in unlocks)
  {
    unlockId = strip(unlockId)
    if (!unlockId.len())
      continue

    local confirmingResult = true
    if (unlockId.len() > 1 && unlockId.slice(0,1) == "!")
    {
      confirmingResult = false
      unlockId = unlockId.slice(1)
    }

    if (::is_unlocked_scripted(-1, unlockId) != confirmingResult)
      return false
  }

  return true
}

function g_unlocks::buyUnlock(unlockData, onSuccessCb = null, onAfterCheckCb = null)
{
  local unlock = unlockData
  if (::u.isString(unlockData))
    unlock = ::g_unlocks.getUnlockById(unlockData)

  if (!::check_balance_msgBox(::get_unlock_cost(unlock.id), onAfterCheckCb))
    return

  local taskId = ::shop_buy_unlock(unlock.id)
  ::g_tasker.addTask(taskId, {
      showProgressBox = true,
      showErrorMessageBox = false
      progressBoxText = ::loc("charServer/purchase")
    },
    onSuccessCb,
    @(result) ::g_popups.add(::getErrorText(result), "")
  )
}

// Favorite Unlocks

function g_unlocks::getFavoriteUnlocks()
{
  if( ! isFavUnlockCacheValid || favoriteUnlocks == null)
    loadFavorites()
  return favoriteUnlocks
}

function g_unlocks::loadFavorites()
{
  if(favoriteUnlocks)
  {
    favoriteUnlocks.reset()
    favoriteInvisibleUnlocks.reset()
  }
  else
  {
    favoriteUnlocks = ::DataBlock()
    favoriteInvisibleUnlocks = ::DataBlock()
  }

  local loaded = ::load_local_account_settings(FAVORITE_UNLOCKS_LIST_SAVE_ID)
  if(loaded)
  {
    foreach(unlockId, unlockValue in loaded)
    {
      local unlock = ::g_unlocks.getUnlockById(unlockId)
      if (::is_unlock_visible(unlock, false))
      {
        if ( ! ::is_unlock_visible_on_cur_platform(unlock))
          favoriteInvisibleUnlocks[unlockId] = true  // unlock not avaliable on current platform
        else
        {
          favoriteUnlocks.addBlock(unlockId)  // valid unlock
          favoriteUnlocks[unlockId] = unlock
        }
      }
    }
  }
  isFavUnlockCacheValid = true
}

function g_unlocks::addUnlockToFavorites(unlockId)
{
  if(unlockId in getFavoriteUnlocks())
    return
  getFavoriteUnlocks().addBlock(unlockId)
  getFavoriteUnlocks()[unlockId] = ::g_unlocks.getUnlockById(unlockId)
  saveFavorites()
  ::broadcastEvent("FavoriteUnlocksChanged")
}

function g_unlocks::removeUnlockFromFavorites(unlockId)
{
  if(unlockId in getFavoriteUnlocks())
  {
    getFavoriteUnlocks().removeBlock(unlockId)
    saveFavorites()
    ::broadcastEvent("FavoriteUnlocksChanged")
  }
}

function g_unlocks::saveFavorites()
{
  local saveBlk = ::DataBlock()
  saveBlk.setFrom(favoriteInvisibleUnlocks)
  foreach(unlockId, unlockValue in getFavoriteUnlocks())
    if( ! (unlockId in saveBlk))
      saveBlk[unlockId] = true
  ::save_local_account_settings(FAVORITE_UNLOCKS_LIST_SAVE_ID, saveBlk)
}

function g_unlocks::isVisibleByTime(id, hasIncludTimeBefore = true, resWhenNoTimeLimit = true, shouldDebugTime = false)
{
  local unlock = getUnlockById(id)
  if (!unlock)
    return false

  local isVisibleUnlock = resWhenNoTimeLimit
  if (::is_numeric(unlock.visibleDays)
    || ::is_numeric(unlock.visibleDaysBefore)
    || ::is_numeric(unlock.visibleDaysAfter))
  {
    foreach (cond in unlock.mode % "condition")
    {
      if (!::isInArray(cond.type, unlock_time_range_conditions))
      {
        continue
      }

      local startTime = ::mktime(time.getTimeFromStringUtc(cond.beginDate)) -
        time.daysToSeconds(hasIncludTimeBefore
        ? unlock?.visibleDaysBefore ?? unlock?.visibleDays ?? 0
        : 0).tointeger()
      local endTime = ::mktime(time.getTimeFromStringUtc(cond.endDate)) +
        time.daysToSeconds(unlock?.visibleDaysAfter ?? unlock?.visibleDays ?? 0).tointeger()
      local currentTime = get_charserver_time_sec()

      isVisibleUnlock = (currentTime > startTime && currentTime < endTime)

      if (shouldDebugTime)
      {
        dagor.debug("unlock " + id + " is visible by time ? " + isVisibleUnlock)
        dagor.debug("curTime = " + currentTime + ", visibleDiapason = " + startTime + ", " + endTime
          + ", beginDate = " + cond.beginDate + ", endDate = " + cond.endDate
          + ", visibleDaysBefore = " + unlock?.visibleDaysBefore
          + ", visibleDays = " + unlock?.visibleDays
          + ", visibleDaysAfter = " + unlock?.visibleDaysAfter
        )
      }

      break
    }
  }
  return isVisibleUnlock
}

function g_unlocks::isHiddenByUnlockedUnlocks(unlockBlk)
{
  if (::is_unlocked_scripted(-1, unlockBlk?.id))
    return false

  foreach (value in (unlockBlk % "hideWhenUnlocked"))
  {
    local unlockedCount = 0
    local unlocksId = ::split(value, "; ")
    foreach (id in unlocksId)
      if (::is_unlocked_scripted(-1, id))
        unlockedCount ++

    if (unlockedCount == unlocksId.len())
      return true
  }

  return false
}
::g_script_reloader.registerPersistentDataFromRoot("g_unlocks")
::subscribe_handler(::g_unlocks, ::g_listener_priority.CONFIG_VALIDATION)
