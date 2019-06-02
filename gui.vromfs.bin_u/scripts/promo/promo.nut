local time = require("scripts/time.nut")
local bhvUnseen = ::require("scripts/seen/bhvUnseen.nut")

::g_promo <- {
  PROMO_BUTTON_TYPE = {
    ARROW = "arrowButton"
    IMAGE = "imageButton"
    IMAGE_ROULETTE = "imageRoulette"
    BATTLE_TASK = "battleTask"
    RECENT_ITEMS = "recentItems"
  }

  BUTTON_OUT_OF_DATE_DAYS = 15
  MAX_IMAGE_WIDTH_COEF = 2
  PERFORM_ACTON_NAME = "performAction"

  DEFAULT_TIME_SWITCH_SEC = 10
  DEFAULT_MANUAL_SWITCH_TIME_MULTIPLAYER = 2
  DEFAULT_REQ_STOP_PLAY_TIME_SONG_SEC = 60

  PLAYLIST_SONG_TIMER_TASK = -1

  performActionTable = {
    events = function(handler, params, obj) { return openEventsWnd(handler, params) }
    tutorial = function(handler, params, obj) { return onOpenTutorial(handler, params) }
    battle_tasks = function(handler, params, obj) { return onOpenBattleTasksWnd(handler, params, obj) }
    url = function(handler, params, obj) { return openLink(handler, params) }
    items = function(handler, params, obj) { return openItemsWnd(handler, params) }
    squad_contacts = function(handler, params, obj) { return ::open_search_squad_player() }
    world_war = function(handler, params, obj) { ::g_world_war.openMainWnd() }
    content_pack = function(handler, params, obj)
    {
      ::check_package_and_ask_download(::getTblValue(0, params, ""))
    }
    achievements = function(handler, params, obj)
    {
      local chapterName = params?[0] ?? ""
      local groupName = params?[1] ?? ""
      ::gui_start_profile({
        initialSheet = "UnlockAchievement"
        uncollapsedChapterName = groupName != ""? chapterName : null
        curAchievementGroupName = chapterName + (groupName != ""? ("/" + groupName) : "") })
    }
    show_unit = function(handler, params, obj)
    {
      local unitName = params?[0] ?? ""
      local unit = ::getAircraftByName(unitName)
      if (!unit)
        return

      local country = unit.shopCountry
      local showUnitInShop = @() ::gui_handlers.ShopViewWnd.open({
        curAirName = unitName
        forceUnitType = unit?.unitType })

      local acceptCallback = ::Callback( function() {
        ::switch_profile_country(country)
        showUnitInShop() }, this)
      if (country != ::get_profile_country_sq())
        ::queues.checkAndStart(
          acceptCallback,
          null,
          "isCanModifyCrew")
      else
        showUnitInShop()
    }
  }

  collapsedParams = {
    world_war_button = { collapsedIcon = ::loc("icon/worldWar") }
    events_mainmenu_button = { collapsedIcon = ::loc("icon/events") }
    tutorial_mainmenu_button = { collapsedIcon = ::loc("icon/tutorial") }
    current_battle_tasks_mainmenu_button = {
      collapsedIcon = ::loc("icon/battleTasks")
      collapsedText = "title"
    }
    web_poll = { collapsedIcon = ::loc("icon/web_poll") }
  }
  defaultCollapsedIcon = ::loc("icon/news")
  defaultCollapsedText = ""

  visibilityByAction = {
    content_pack = function(params)
    {
      return ::has_feature("Packages") && !::have_package(::getTblValue(0, params, ""))
    }
  }

  customSeenId = {
    events_mainmenu_button = @() bhvUnseen.makeConfigStr(SEEN.EVENTS, SEEN.S_EVENTS_WINDOW)
  }
  getCustomSeenId = @(blockId) customSeenId?[blockId] && customSeenId[blockId]()

  actionParamsByBlockId = {}
  showAllPromoBlocks = false

  paramsSeparator = "; "
  blocksSeparator = "|"

  cache = null
  visibilityStatuses = {}

  multiblockData = {}

  // block name in 'customSettings > accounts > <account> > seen' = function (must return days)
  oldRecordsCheckTable = {
    promo = @(tm) tm
  }
}

function g_promo::checkOldRecordsOnInit()
{
  local blk = ::loadLocalByAccount("seen")
  if (!blk)
    return

  foreach (blockName, convertTimeFunc in oldRecordsCheckTable)
  {
    local newBlk = ::DataBlock()
    local checkBlock = blk.getBlockByName(blockName)
    if (!checkBlock)
      continue

    for (local i = 0; i < checkBlock.paramCount(); i++)
    {
      local id = checkBlock.getParamName(i)
      local lastTimeSeen = checkBlock.getParamValue(i)
      local days = convertTimeFunc(lastTimeSeen)

      local minDay = time.getUtcDays() - BUTTON_OUT_OF_DATE_DAYS
      if (days > minDay)
        continue

      newBlk[id] <- lastTimeSeen
    }
    ::saveLocalByAccount("seen/" + blockName, newBlk)
  }
}

function g_promo::recievePromoBlk()
{
  local customPromoBlk = ::get_gui_regional_blk().promo_block
  if (!::u.isDataBlock(customPromoBlk)) //compatibility with not exist or old gui_regional
  {
    local blk = ::get_game_settings_blk()
    customPromoBlk = blk && blk.promo_block
    if (!::u.isDataBlock(customPromoBlk))
      customPromoBlk = ::DataBlock()
  }
  local showAllPromo = ::g_promo.getShowAllPromoBlocks()

  local promoBlk = ::u.copy(customPromoBlk)
  local guiBlk = ::configs.GUI.get()
  local staticPromoBlk = guiBlk.static_promo_block

  if (!::u.isEmpty(staticPromoBlk))
  {
    //---Check on non-unique block names-----
    for (local i = 0; i < staticPromoBlk.blockCount(); i++)
    {
      local block = staticPromoBlk.getBlock(i)
      local blockName = block.getBlockName()
      local haveDouble = blockName in promoBlk
      if (!haveDouble || showAllPromo)
        promoBlk[blockName] <- ::u.copy(block)
    }
  }

  if (!::g_promo.needUpdate(promoBlk) && !showAllPromo)
    return null
  return promoBlk
}

function g_promo::requestUpdate()
{
  local promoBlk = ::g_promo.recievePromoBlk()
  if (::u.isEmpty(promoBlk))
    return false

  ::g_promo.checkOldRecordsOnInit()
  cache = ::DataBlock()
  cache.setFrom(promoBlk)
  actionParamsByBlockId.clear()
  return true
}

function g_promo::clearCache()
{
  cache = null
}

function g_promo::getConfig()
{
  return ::g_promo.cache
}

function g_promo::needUpdate(newData)
{
  local reqForceUpdate = false
  for (local i = 0; i < newData.blockCount(); i++)
  {
    local block = newData.getBlock(i)
    local id = block.getBlockName()

    local show = checkBlockVisibility(block)
    if (::getTblValue(id, visibilityStatuses) != show)
    {
      visibilityStatuses[id] <- show
      reqForceUpdate = true
    }
  }

  return reqForceUpdate
}

function g_promo::createActionParamsData(actionName, paramsArray = null)
{
  return {
    action = actionName
    paramsArray = paramsArray || []
  }
}

function g_promo::gatherActionParamsData(block)
{
  local actionStr = ::getTblValue("action", block)
  if (::u.isEmpty(actionStr))
    return null

  local params = ::g_string.split(actionStr, paramsSeparator)
  local action = params.remove(0)
  return createActionParamsData(action, params)
}

function g_promo::setActionParamsData(blockId, actionOrActionData, paramsArray = null)
{
  if (::u.isString(actionOrActionData))
    actionOrActionData = createActionParamsData(actionOrActionData, paramsArray)

  actionParamsByBlockId[blockId] <- actionOrActionData
}

function g_promo::getActionParamsData(blockId)
{
  return ::getTblValue(blockId, actionParamsByBlockId)
}

function g_promo::generateBlockView(block)
{
  local id = block.getBlockName()
  local view = ::buildTableFromBlk(block)
  view.id <- id
  view.type <- ::g_promo.getType(block)
  view.collapsed <- ::g_promo.isCollapsed(id)? "yes" : "no"
  view.aspect_ratio <- countMaxSize(block)
  view.fillBlocks <- []

  local unseenIcon = getCustomSeenId(id)
  if (unseenIcon)
    view.unseenIcon <- unseenIcon
  view.notifyNew <- !unseenIcon && (view?.notifyNew ?? true)

  local isDebugModeEnabled = getShowAllPromoBlocks()
  local blocksCount = block.blockCount()
  local isMultiblock = block.multiple || false
  view.isMultiblock <- isMultiblock

  view.radiobuttons <- []
  if (isMultiblock)
  {
    local value = (id in multiblockData)?
                    ::to_integer_safe(multiblockData[id].value, 0)
                    : 0
    local switchVal = block.switch_time_sec?
                        ::to_integer_safe(block.switch_time_sec, DEFAULT_TIME_SWITCH_SEC)
                        : DEFAULT_TIME_SWITCH_SEC
    local mSwitchVal = block.manual_switch_time_multiplayer?
                        ::to_integer_safe(block.manual_switch_time_multiplayer, DEFAULT_MANUAL_SWITCH_TIME_MULTIPLAYER)
                        : DEFAULT_MANUAL_SWITCH_TIME_MULTIPLAYER
    local lifeTimeVal = (id in multiblockData)? multiblockData[id].life_time : switchVal
    multiblockData[id] <- { value = value,
                            switch_time_sec = switchVal,
                            manual_switch_time_multiplayer = mSwitchVal,
                            life_time = lifeTimeVal}
  }

  local requiredBlocks = isMultiblock? blocksCount : 1

  for (local i = 0; i < requiredBlocks; i++)
  {
    local blockId = view.id + (isMultiblock? ("_" + i) : "")
    local actionParamsKey = getActionParamsKey(blockId)

    local checkBlock = isMultiblock? block.getBlock(i) : block
    local fillBlock = ::buildTableFromBlk(checkBlock)
    fillBlock.blockId <- actionParamsKey

    local actionData = gatherActionParamsData(fillBlock) || gatherActionParamsData(block)
    if (actionData)
    {
      local action = actionData.action
      if (action == "url" && actionData.paramsArray.len())
        fillBlock.link <- ::g_url.validateLink(actionData.paramsArray[0])

      fillBlock.action <- PERFORM_ACTON_NAME
      view.collapsedAction <- PERFORM_ACTON_NAME
      setActionParamsData(actionParamsKey, actionData)
    }

    local link = getLinkText(fillBlock)
    if (::u.isEmpty(link) && isMultiblock)
      link = getLinkText(block)
    if (!::u.isEmpty(link))
    {
      fillBlock.link <- link
      setActionParamsData(actionParamsKey, "url", [link, ::getTblValue("forceExternalBrowser", checkBlock, false)])
      fillBlock.action <- PERFORM_ACTON_NAME
      view.collapsedAction <- PERFORM_ACTON_NAME
    }

    local image = getImage(fillBlock)
    if (image != "")
      fillBlock.image <- image

    local text = getViewText(fillBlock, isMultiblock ? "" : null)
    if (::u.isEmpty(text) && isMultiblock)
      text = getViewText(block)
    fillBlock.text <- text

    local showTextShade = !::is_chat_message_empty(text) || isDebugModeEnabled
    fillBlock.showTextShade <- showTextShade

    local isBlockSelected = isValueCurrentInMultiBlock(id, i)
    local show = checkBlockVisibility(checkBlock) && isBlockSelected
    if (view.type == PROMO_BUTTON_TYPE.ARROW && !showTextShade)
      show = false
    fillBlock.blockShow <- show

    fillBlock.aspect_ratio <- view.aspect_ratio
    view.fillBlocks.append(fillBlock)

    view.radiobuttons.append({selected = isBlockSelected})
  }

  if ("action" in view)
    delete view.action
  view.show <- checkBlockVisibility(block) && block.pollId == null
  view.collapsedIcon <- getCollapsedIcon(view, id)
  view.collapsedText <- getCollapsedText(view, id)

  return view
}

function g_promo::getCollapsedIcon(view, promoButtonId)
{
  local result = ""
  local icon = ::getTblValueByPath(promoButtonId + ".collapsedIcon", collapsedParams)
  if (icon)
    result = ::getTblValue(icon, view, icon) //can be set as param
  else
    result = ::g_language.getLocTextFromConfig(view, "collapsedIcon", defaultCollapsedIcon)

  return ::loc(result)
}

function g_promo::getCollapsedText(view, promoButtonId)
{
  local result = ""
  local text = ::getTblValueByPath(promoButtonId + ".collapsedText", collapsedParams)
  if (text)
    result = ::getTblValue(text, view, defaultCollapsedText) //can be set as param
  else
    result = ::g_language.getLocTextFromConfig(view, "collapsedText", defaultCollapsedText)

  return ::loc(result)
}

function g_promo::countMaxSize(block)
{
  local ratio = block.aspect_ratio || 1
  local height = 1.0
  local width = ratio

  if (ratio > MAX_IMAGE_WIDTH_COEF)
  {
    width = MAX_IMAGE_WIDTH_COEF
    height = MAX_IMAGE_WIDTH_COEF / ratio
  }

  return ::format("height:t='%0.2f@arrowButtonWithImageHeight'; width:t='%0.2fh'", height, width)
}

/**
 * First searches text for current language (e.g. "text_en", "text_ru").
 * If no such text found, tries to return text in "text" property.
 * If nothing find returns block id.
 */
function g_promo::getViewText(view, defValue = null)
{
  return ::g_language.getLocTextFromConfig(view, "text", defValue)
}

function g_promo::getLinkText(view)
{
  return ::g_language.getLocTextFromConfig(view, "link", "")
}

function g_promo::getLinkBtnText(view)
{
  return ::g_language.getLocTextFromConfig(view, "linkText", "")
}

function g_promo::getImage(view)
{
  return ::g_language.getLocTextFromConfig(view, "image", "")
}

function g_promo::checkBlockTime(block)
{
  local utcTime = ::get_charserver_time_sec()

  local startTime = getUTCTimeFromBlock(block, "startTime")
  if (startTime > 0 && startTime >= utcTime)
    return false

  local endTime = getUTCTimeFromBlock(block, "endTime")
  if (endTime > 0 && utcTime >= endTime)
    return false

  if (!::g_partner_unlocks.isPartnerUnlockAvailable(block.partnerUnlock, block.partnerUnlockDurationMin))
    return false

  // Block has no time restrictions.
  return true
}

function g_promo::checkBlockReqFeature(block)
{
  if (!("reqFeature" in block))
    return true

  return ::has_feature_array(::split(block.reqFeature, "; "))
}

function g_promo::checkBlockUnlock(block)
{
  if (!("reqUnlock" in block))
    return true

  return ::g_unlocks.checkUnlockString(block.reqUnlock)
}

function g_promo::isVisibleByAction(block)
{
  local actionData = gatherActionParamsData(block)
  if (!actionData)
    return true
  local isVisibleFunc = ::getTblValue(actionData.action, visibilityByAction)
  return !isVisibleFunc || isVisibleFunc(actionData.paramsArray)
}

function g_promo::getCurrentValueInMultiBlock(id)
{
  if (!(id in multiblockData))
    return 0

  return multiblockData[id].value
}

function g_promo::isValueCurrentInMultiBlock(id, value)
{
  return ::g_promo.getCurrentValueInMultiBlock(id) == value
}

function g_promo::checkBlockVisibility(block)
{
  return (::g_language.isAvailableForCurLang(block)
           && checkBlockReqFeature(block)
           && checkBlockUnlock(block)
           && checkBlockTime(block)
           && isVisibleByAction(block))
         || getShowAllPromoBlocks()
}

function g_promo::getUTCTimeFromBlock(block, timeProperty)
{
  local timeText = ::getTblValue(timeProperty, block, null)
  if (!::u.isString(timeText) || timeText.len() == 0)
    return -1
  return time.getTimestampFromStringUtc(timeText)
}

function g_promo::getDefaultBoolParamFromBlock(block, param, defaultValue = false)
{
  local value = ::getTblValue(param, block, defaultValue)
  if (::u.isString(value))
    value = value == "yes"

  return !!value
}

function g_promo::initWidgets(obj, widgetsTable, widgetsWithCounter = [])
{
  foreach(id, table in widgetsTable)
    widgetsTable[id] = ::g_promo.initNewWidget(id, obj, widgetsWithCounter)
}

function g_promo::getActionParamsKey(id)
{
  return "perform_action_" + id
}

function g_promo::cutActionParamsKey(id)
{
  return ::g_string.cutPrefix(id, "perform_action_", id)
}

function g_promo::getType(block)
{
  local res = PROMO_BUTTON_TYPE.ARROW
  if (block.blockCount() > 1)
    res = PROMO_BUTTON_TYPE.IMAGE_ROULETTE
  else if (::getTblValue("image", block, "") != "")
    res = PROMO_BUTTON_TYPE.IMAGE
  else if (block.getBlockName().find("current_battle_tasks") != null)
    res = PROMO_BUTTON_TYPE.BATTLE_TASK

  return res
}

function g_promo::setButtonText(buttonObj, id, text = "")
{
  if (!::checkObj(buttonObj))
    return

  local obj = buttonObj.findObject(id + "_text")
  if (::checkObj(obj))
    obj.setValue(text)
}

function g_promo::getVisibilityById(id)
{
  return ::getTblValue(id, visibilityStatuses, false)
}

//----------- <NEW ICON WIDGET> ----------------------------
function g_promo::initNewWidget(id, obj, widgetsWithCounter = [])
{
  if (isWidgetSeenById(id))
    return null

  local newIconWidget = null
  local widgetContainer = obj.findObject(id + "_new_icon_widget_container")
  if (::checkObj(widgetContainer))
    newIconWidget = NewIconWidget(obj.getScene(), widgetContainer)
  return newIconWidget
}

function g_promo::isWidgetSeenById(id)
{
  local blk = ::loadLocalByAccount("seen/promo")
  return id in blk
}

function g_promo::setSimpleWidgetData(widgetsTable, id, widgetsWithCounter = [])
{
  if (::isInArray(id, widgetsWithCounter))
    return

  local blk = ::loadLocalByAccount("seen/promo")
  local table = ::buildTableFromBlk(blk)

  if (!(id in table))
    table[id] <- time.getUtcDays()

  if (::getTblValue(id, widgetsTable) != null)
    widgetsTable[id].setWidgetVisible(false)

  updateSimpleWidgetsData(table)
}

function g_promo::updateSimpleWidgetsData(table)
{
  local minDay = time.getUtcDays() - BUTTON_OUT_OF_DATE_DAYS
  local idOnRemoveArray = []
  local blk = ::DataBlock()
  foreach(id, day in table)
  {
    if (day < minDay)
    {
      idOnRemoveArray.append(id)
      continue
    }

    blk[id] = day
  }

  ::saveLocalByAccount("seen/promo", blk)
  updateCollapseStatuses(idOnRemoveArray)
}
//-------------- </NEW ICON WIDGET> ----------------------

//-------------- <ACTION> --------------------------------
function g_promo::performAction(handler, obj)
{
  if (!::checkObj(obj))
    return false

  local key = obj.id
  local actionData = getActionParamsData(key)
  if (!actionData)
  {
    ::dagor.assertf(false, "Promo: Not found action params by key " + key)
    return false
  }

  local action = actionData.action
  local actionFunc = ::getTblValue(action, performActionTable)
  if (!actionFunc)
  {
    ::dagor.assert(false, "Promo: Not found action in actions table. Action " + action)
    ::dagor.debug("Promo: Rest params of paramsArray")
    debugTableData(actionData)
    return false
  }

  actionFunc(handler, actionData.paramsArray, obj)
  return true
}

function g_promo::openLink(owner, params = [], source = "promo_open_link")
{
  local link = ""
  local forceBrowser = false
  if (::u.isString(params))
    link = params
  else if (::u.isArray(params) && params.len() > 0)
  {
    link = params[0]
    forceBrowser = params.len() > 1? params[1] : false
  }

  local processedLink = ::g_url.validateLink(link)
  if (processedLink == null)
    return
  ::open_url(processedLink, forceBrowser, false, source)
}

function g_promo::onOpenTutorial(owner, params = [])
{
  local tutorialId = ""
  if (::u.isString(params))
    tutorialId = params
  else if (::u.isArray(params) && params.len() > 0)
    tutorialId = params[0]

  owner.checkedNewFlight((@(tutorialId) function() {
    if (!::gui_start_checkTutorial(tutorialId, false))
      ::gui_start_tutorial()
  })(tutorialId))
}

function g_promo::openEventsWnd(owner, params = [])
{
  local eventId = params.len() > 0? params[0] : null
  owner.checkedForward((@(eventId) function() {
    goForwardIfOnline((@(eventId) function() {
      ::gui_start_modal_events({event = eventId})
    })(eventId), false, true)
  })(eventId), null)
}

function g_promo::openItemsWnd(owner, params = [])
{
  local tab = getconsttable()?.itemsTab?[(params?[1] ?? "SHOP").toupper()] ?? itemsTab.INVENTORY

  local curSheet = null
  local sheetSearchId = params?[0] ?? null
  if (sheetSearchId)
    curSheet = {searchId = sheetSearchId}

  if (tab >= itemsTab.TOTAL)
    tab = itemsTab.INVENTORY

  ::gui_start_items_list(tab, {curSheet = curSheet})
}

function g_promo::onOpenBattleTasksWnd(owner, params = {}, obj = null)
{
  local taskId = obj.task_id
  if (taskId == null && params.len() > 0)
    taskId = params[0]

  ::g_warbonds_view.resetShowProgressBarFlag()
  ::gui_start_battle_tasks_wnd(taskId)
}

//---------------- </ACTIONS> -----------------------------

//-------------- <SHOW ALL CHECK BOX> ---------------------

/** Returns 'true' if user can use "Show All Promo Blocks" check box. */
function g_promo::canSwitchShowAllPromoBlocksFlag()
{
  return ::has_feature("ShowAllPromoBlocks")
}

/** Returns 'true' is user can use check box and it is checked. */
function g_promo::getShowAllPromoBlocks()
{
  return canSwitchShowAllPromoBlocksFlag() && showAllPromoBlocks
}

function g_promo::setShowAllPromoBlocks(value)
{
  if (showAllPromoBlocks != value)
  {
    showAllPromoBlocks = value
    ::broadcastEvent("ShowAllPromoBlocksValueChanged")
  }
}

//-------------- </SHOW ALL CHECK BOX> --------------------

//--------------------- <TOGGLE> ----------------------------

function g_promo::toggleItem(toggleButtonObj)
{
  local promoButtonObj = toggleButtonObj.getParent()
  local toggled = isCollapsed(promoButtonObj.id)
  local newVal = changeToggleStatus(promoButtonObj.id, toggled)
  promoButtonObj.collapsed = newVal? "yes" : "no"
}

function g_promo::isCollapsed(id)
{
  local blk = ::loadLocalByAccount("seen/promo_collapsed")
  return blk? blk[id] : false
}

function g_promo::changeToggleStatus(id, value)
{
  local newValue = !value
  local blk = ::loadLocalByAccount("seen/promo_collapsed") || ::DataBlock()
  blk[id] = newValue

  ::saveLocalByAccount("seen/promo_collapsed", blk)
  return newValue
}

function g_promo::updateCollapseStatuses(arr)
{
  local blk = ::loadLocalByAccount("seen/promo_collapsed")
  if (!blk)
    return

  local clearedBlk = ::DataBlock()
  foreach(id, status in blk)
  {
    if (::isInArray(id, arr))
      continue

    clearedBlk[id] = status
  }

  ::saveLocalByAccount("seen/promo_collapsed", clearedBlk)
}

//-------------------- </TOGGLE> ----------------------------

//----------------- <RADIOBUTTONS> --------------------------

function g_promo::switchBlock(obj, promoHolderObj)
{
  if (!::checkObj(promoHolderObj))
    return

  if (!(obj.blockId in multiblockData))
    return

  local promoButtonObj = promoHolderObj.findObject(obj.blockId)
  local value = obj.getValue()
  local prevValue = multiblockData[promoButtonObj.id].value
  if (prevValue >= 0)
  {
    local prevObj = promoButtonObj.findObject(::g_promo.getActionParamsKey(promoButtonObj.id + "_" + prevValue))
    prevObj.animation = "hide"
  }

  local searchId = ::g_promo.getActionParamsKey(promoButtonObj.id + "_" + value)
  local curObj = promoButtonObj.findObject(searchId)
  curObj.animation = "show"
  multiblockData[promoButtonObj.id].value = value
}

function g_promo::manualSwitchBlock(obj, promoHolderObj)
{
  if (!::checkObj(promoHolderObj))
    return

  local pId = obj.blockId

  multiblockData[pId].life_time = multiblockData[pId].manual_switch_time_multiplayer * multiblockData[pId].switch_time_sec

  ::g_promo.switchBlock(obj, promoHolderObj)
}

function g_promo::selectNextBlock(obj, dt)
{
  if (!(obj.id in multiblockData))
    return

  multiblockData[obj.id].life_time -= dt
  if (multiblockData[obj.id].life_time > 0)
    return

  multiblockData[obj.id].life_time = multiblockData[obj.id].switch_time_sec

  local listObj = obj.findObject("multiblock_radiobuttons_list")
  if (!::checkObj(listObj))
    return

  local curVal = listObj.getValue()
  local nextVal = curVal + 1
  if (nextVal >= listObj.childrenCount())
    nextVal = 0
  listObj.setValue(nextVal)
}

//----------------- </RADIOBUTTONS> -------------------------

//------------------ <PLAYBACK> -----------------------------
function g_promo::enablePlayMenuMusic(playlistArray, tm)
{
  if (PLAYLIST_SONG_TIMER_TASK >= 0)
    return

  ::set_cached_music(::CACHED_MUSIC_MENU, ::u.chooseRandom(playlistArray), "")
  PLAYLIST_SONG_TIMER_TASK = ::periodic_task_register(this, ::g_promo.requestTurnOffPlayMenuMusic, tm)
}

function g_promo::requestTurnOffPlayMenuMusic(dt)
{
  if (PLAYLIST_SONG_TIMER_TASK < 0)
    return

  ::set_cached_music(::CACHED_MUSIC_MENU, "", "")
  ::periodic_task_unregister(PLAYLIST_SONG_TIMER_TASK)
  PLAYLIST_SONG_TIMER_TASK = -1
}
//------------------- </PLAYBACK> ----------------------------
