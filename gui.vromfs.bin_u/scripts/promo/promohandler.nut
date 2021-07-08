local { set_blk_value_by_path } = require("sqStdLibs/helpers/datablockUtils.nut")
local { clearOldVotedPolls, setPollBaseUrl, isPollVoted, generatePollUrl } = require("scripts/web/webpoll.nut")
local { getPromoHandlerUpdateConfigs } = require("scripts/promo/promoButtonsConfig.nut")

::create_promo_blocks <- function create_promo_blocks(handler)
{
  if (!::handlersManager.isHandlerValid(handler))
    return null

  local owner = handler.weakref()
  local guiScene = handler.guiScene
  local scene = handler.scene.findObject("promo_mainmenu_place")

  return ::Promo(owner, guiScene, scene)
}

::Promo <- class
{
  owner = null
  guiScene = null
  scene = null

  sourceDataBlock = null

  widgetsTable = {}

  pollIdToObjectId = {}
  needUpdateByTimerArr = null

  updateFunctions = null

  constructor(_handler, _guiScene, _scene)
  {
    owner = _handler
    guiScene = _guiScene
    scene = _scene

    updateFunctions = {}
    foreach (key, config in getPromoHandlerUpdateConfigs()) {
      local { updateFunctionInHandler, updateByEvents } = config
      if (updateFunctionInHandler == null)
        continue

      updateFunctions[key] <- @() updateFunctionInHandler()
      foreach (event in (updateByEvents ?? []))
        ::add_event_listener(event, @(p) updateFunctionInHandler(), this)
    }

    initScreen(true)

    local pollsTable = {}
    for (local j = 0; sourceDataBlock != null && j < sourceDataBlock.blockCount(); j++)
    {
      local block = sourceDataBlock.getBlock(j)
      if (block?.pollId != null)
        pollsTable[block.pollId] <- true
    }
    clearOldVotedPolls(pollsTable)

    ::subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)
  }

  function initScreen(forceReplaceContent = false)
  {
    updatePromoBlocks(forceReplaceContent)
  }

  function updatePromoBlocks(forceReplaceContent = false)
  {
    if (!::g_promo.requestUpdate() && !forceReplaceContent)
      return

    sourceDataBlock = ::g_promo.getConfig()
    updateAllBlocks()
  }

  function updateAllBlocks()
  {
    needUpdateByTimerArr = []
    local data = generateData()
    local topPositionPromoPlace = scene.findObject("promo_mainmenu_place_top")
    if (::checkObj(topPositionPromoPlace))
      guiScene.replaceContentFromText(topPositionPromoPlace, data.upper, data.upper.len(), this)

    local bottomPositionPromoPlace = scene.findObject("promo_mainmenu_place_bottom")
    if (::checkObj(bottomPositionPromoPlace))
      guiScene.replaceContentFromText(bottomPositionPromoPlace, data.bottom, data.bottom.len(), this)

    ::g_promo.initWidgets(scene, widgetsTable)
    updateData()
    setTimers()
  }

  function onSceneActivate(show)
  {
    if (show)
      updatePromoBlocks()
  }

  function toggleSceneVisibility(isShow)
  {
    scene.show(isShow)
    onSceneActivate(isShow)
  }

  function generateData()
  {
    widgetsTable = {}
    local upperPromoView = {
      showAllCheckBoxEnabled = ::g_promo.canSwitchShowAllPromoBlocksFlag()
      showAllCheckBoxValue = ::g_promo.getShowAllPromoBlocks()
      promoButtons = []
    }

    local bottomPromoView = {
      showAllCheckBoxEnabled = false
      promoButtons = []
    }

    for (local i = 0; sourceDataBlock != null && i < sourceDataBlock.blockCount(); i++)
    {
      local block = sourceDataBlock.getBlock(i)

      local blockView = ::g_promo.generateBlockView(block)
      local blockId = blockView.id
      if (block?.pollId != null)
      {
        if (::g_promo.getVisibilityById(blockId)) //add pollId to request only for visible promo
          setPollBaseUrl(block.pollId, block?.link)
        pollIdToObjectId[block.pollId] <- blockId
      }

      if (block?.bottom != null)
        bottomPromoView.promoButtons.append(blockView)
      else
        upperPromoView.promoButtons.append(blockView)

      if (blockView?.notifyNew && !::g_promo.isWidgetSeenById(blockId))
        widgetsTable[blockId] <- {}

      local playlistArray = getPlaylistArray(block)
      if (playlistArray.len() > 0)
      {
        local requestStopPlayTimeSec = block?.requestStopPlayTimeSec || ::g_promo.DEFAULT_REQ_STOP_PLAY_TIME_SONG_SEC
        ::g_promo.enablePlayMenuMusic(playlistArray, requestStopPlayTimeSec)
      }

      if (blockView.needUpdateByTimer)
        needUpdateByTimerArr.append(blockId)
    }
    return {
      upper = ::handyman.renderCached("gui/promo/promoBlocks", upperPromoView)
      bottom = ::handyman.renderCached("gui/promo/promoBlocks", bottomPromoView)
    }
  }

  function setTplView(tplPath, object, view = {})
  {
    if (!::checkObj(object))
      return

    local data = ::handyman.renderCached(tplPath, view)
    guiScene.replaceContentFromText(object, data, data.len(), this)
  }

  function updateData()
  {
    if (sourceDataBlock == null)
      return

    for (local i = 0; i < sourceDataBlock.blockCount(); i++)
    {
      local block = sourceDataBlock.getBlock(i)
      local id = block.getBlockName()
      if (id in updateFunctions)
        updateFunctions[id].call(this)

      if (block?.pollId != null)
        updateWebPollButton({pollId = block.pollId})

      if (!(block?.multiple ?? false))
        continue

      local btnObj = scene.findObject(id)
      if (::check_obj(btnObj))
        btnObj.setUserData(this)
    }
  }

  function getPlaylistArray(block)
  {
    local defaultName = "playlist"
    local langKey = defaultName + "_" + ::g_language.getShortName()
    local list = block?[langKey] ?? block?[defaultName]
    if (!list)
      return []
    return list % "name"
  }

  function performAction(obj)
  {
    performActionWithStatistics(obj, false)
  }

  function performActionWithStatistics(obj, isFromCollapsed)
  {
    ::add_big_query_record("promo_click",
      ::save_to_json({id = ::g_promo.cutActionParamsKey(obj.id), collapsed = isFromCollapsed}))
    local objScene = obj.getScene()
    objScene.performDelayed(
      this,
      (@(owner, obj, widgetsTable) function() {
        if (!::checkObj(obj))
          return

        if (!::g_promo.performAction(owner, obj))
          if (::checkObj(obj))
            ::g_promo.setSimpleWidgetData(widgetsTable, obj.id)
      })(owner, obj, widgetsTable)
    )
  }

  function performActionCollapsed(obj)
  {
    local buttonObj = obj.getParent()
    performActionWithStatistics(buttonObj.findObject(::g_promo.getActionParamsKey(buttonObj.id)), true)
  }

  function onShowAllCheckBoxChange(obj)
  {
    ::g_promo.setShowAllPromoBlocks(obj.getValue())
  }

  function isShowAllCheckBoxEnabled()
  {
    if (!isValid())
      return false

    local chBoxObj = scene.findObject("checkbox_show_all_promo_blocks")
    if (!::checkObj(chBoxObj))
      return false

    return chBoxObj.getValue()
  }

  function getBoolParamByIdFromSourceBlock(param, id, defaultValue = false)
  {
    if (!sourceDataBlock?[id][param])
      return null

    local show = ::getTblValue(param, sourceDataBlock[id], defaultValue)
    if (::u.isString(show))
      show = show == "yes"? true : false

    return show
  }

  function isValid()
  {
    return ::check_obj(scene)
  }

  function onPromoBlocksUpdate(obj, dt)
  {
    updatePromoBlocks()
  }

  //----------------- <NAVIGATION> --------------------------

  function getWrapNestObj()
  {
    if (!isValid())
      return null

    for (local i = 0; i < scene.childrenCount(); i++)
    {
      local child = scene.getChild(i)
      if (child.isVisible() && child.isEnabled())
        return scene
    }

    return null
  }

  //------------------ </NAVIGATION> --------------------------

  //--------------------- <TOGGLE> ----------------------------

  function onToggleItem(obj) { ::g_promo.toggleItem(obj) }

  //-------------------- </TOGGLE> ----------------------------

  //------------------ <WEB POLL> -------------------------

  function updateWebPollButton(param)
  {
    local pollId = param?.pollId
    local objectId = ::getTblValue(pollId, pollIdToObjectId)
    if (objectId == null)
      return

    local showByLocalConditions = !isPollVoted(pollId) && ::g_promo.getVisibilityById(objectId)
    if(!showByLocalConditions)
    {
      ::showBtn(objectId, false, scene)
      return
    }

    local link = generatePollUrl(pollId)
    if (link.len() == 0)
      return
    set_blk_value_by_path(sourceDataBlock, objectId + "/link", link)
    ::g_promo.generateBlockView(sourceDataBlock[objectId])
    ::showBtn(objectId, true, scene)
  }

  //----------------- </WEB POLL> -------------------------

  //----------------- <RADIOBUTTONS> --------------------------

  function switchBlock(obj) { ::g_promo.switchBlock(obj, scene) }
  function manualSwitchBlock(obj) { ::g_promo.manualSwitchBlock(obj, scene) }
  function selectNextBlock(obj, dt) { ::g_promo.selectNextBlock(obj, dt) }

  //----------------- </RADIOBUTTONS> -------------------------

  function onEventShowAllPromoBlocksValueChanged(p) { updatePromoBlocks() }
  function onEventPartnerUnlocksUpdated(p) { updatePromoBlocks(true) }
  function onEventShopWndVisible(p) { toggleSceneVisibility(!::getTblValue("isShopShow", p, false)) }
  function onEventXboxMultiplayerPrivilegeUpdated(p) { updatePromoBlocks(true) }
  function onEventWebPollAuthResult(p) { updateWebPollButton(p) }
  function onEventWebPollTokenInvalidated(p) {
    if (p?.pollId == null)
      updateData()
    else
      updateWebPollButton(p)
  }

  function setTimers()
  {
    local timerObj = owner.scene.findObject("promo_blocks_timer_slow")
    if (::check_obj(timerObj))
      timerObj.setUserData(this)

    local isNeedFrequentUpdate = needUpdateByTimerArr.len() > 0
    timerObj = owner.scene.findObject("promo_blocks_timer_fast")
    if (::check_obj(timerObj))
      timerObj.setUserData(isNeedFrequentUpdate ? this : null)
  }

  function onPromoBlocksTimer(obj, dt)
  {
    foreach (promoId in needUpdateByTimerArr)
    {
      updateFunctions?[promoId]?.call?(this)
    }
  }
}
