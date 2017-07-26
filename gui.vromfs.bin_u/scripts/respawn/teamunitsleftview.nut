class ::gui_handlers.teamUnitsLeftView extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneTplName = "gui/promo/promoBlocks"

  blockId = "leftUnits"

  parentHandlerWeak = null
  missionRules = null
  isSceneLoaded = false
  isCollapsed = true

  collapsedInfoRefreshDelay = 4.0
  collapsedInfoUnitLimit = null
  collapsedInfoTimer = -1

  function initScreen()
  {
    if (parentHandlerWeak)
      parentHandlerWeak = parentHandlerWeak.weakref() //we are miss weakref on assigning from params table

    scene.setUserData(this) //to not unload handler even when scene not loaded
    missionRules = ::g_mis_custom_state.getCurMissionRules()

    refreshScene()
  }

  function loadSceneOnce()
  {
    if (isSceneLoaded)
      return

    local view = {
      promoButtons = []
    }

    local buttonData = {
      id = blockId
      type = "autoWidth"
      inputTransparent = true
      needTextShade = true
      showTextShade = true
      show = true
      collapsed = isCollapsed ? "yes" : "no"
      timerFunc = "onUpdate"
      needNavigateToCollapseButtton = true
      needCollapsedTextAnimSwitch = true

      fillBlocks = [{}]
    }

    view.promoButtons.append(buttonData)

    local data = ::handyman.renderCached(sceneTplName, view)
    guiScene.replaceContentFromText(scene, data, data.len(), this)
    isSceneLoaded = true

    scene.findObject(blockId).setUserData(this)
  }

  function refreshScene()
  {
    if (!missionRules.hasCustomUnitRespawns())
      return

    loadSceneOnce()
    updateInfo()
  }

  function getRespTextByUnitLimit(unitLimit)
  {
    return unitLimit ? unitLimit.getText() : ""
  }

  function getFullUnitsText()
  {
    local data = missionRules.getFullUnitLimitsData()
    local textsList = ::u.map(data.unitLimits, getRespTextByUnitLimit)
    textsList.insert(0, ::loc("multiplayer/teamUnitsLeftHeader"))
    return ::implode(textsList, "\n")
  }

  function updateInfo(isJustSwitched = false)
  {
    if (!isSceneLoaded)
      return

    if (isCollapsed)
      updateCollapsedInfoText(isJustSwitched)
    else
      scene.findObject(blockId + "_text").setValue(getFullUnitsText())
  }

  function updateCollapsedInfoByUnitLimit(unitLimit, needAnim = true)
  {
    collapsedInfoUnitLimit = unitLimit
    local text = getRespTextByUnitLimit(unitLimit)
    if (needAnim)
    {
      ::g_promo_view_utils.animSwitchCollapsedText(scene, blockId, text)
      return
    }

    local obj = ::g_promo_view_utils.getVisibleCollapsedTextObj(scene, blockId)
    if (::checkObj(obj))
      obj.setValue(text)
  }

  function setNewCollapsedInfo(needAnim = true)
  {
    local data = missionRules.getFullUnitLimitsData()
    local prevIdx = -1
    if (collapsedInfoUnitLimit)
      prevIdx = ::u.searchIndex(data.unitLimits, collapsedInfoUnitLimit.isSame.bindenv(collapsedInfoUnitLimit))

    updateCollapsedInfoByUnitLimit(::u.chooseRandomNoRepeat(data.unitLimits, prevIdx), needAnim)
    collapsedInfoTimer = collapsedInfoRefreshDelay
  }

  function updateCollapsedInfoText(isJustSwitched = false)
  {
    if (isJustSwitched || !collapsedInfoUnitLimit)
      return setNewCollapsedInfo(!isJustSwitched)

    local data = missionRules.getFullUnitLimitsData()
    local newUnitLimit = ::u.search(data.unitLimits, collapsedInfoUnitLimit.isSame.bindenv(collapsedInfoUnitLimit))
    if (newUnitLimit)
      updateCollapsedInfoByUnitLimit(newUnitLimit, false)
    else
      setNewCollapsedInfo()
  }

  function onToggleItem(obj)
  {
    isCollapsed = !isCollapsed
    scene.findObject(blockId).collapsed = isCollapsed ? "yes" : "no"
    updateInfo(true)
  }

  function onUpdate(obj, dt)
  {
    if (!isCollapsed)
      return

    collapsedInfoTimer -= dt
    if (collapsedInfoTimer < 0)
      setNewCollapsedInfo()
  }

  function onEventMissionCustomStateChanged(p)
  {
    doWhenActiveOnce("refreshScene")
  }

  function getMainFocusObj()
  {
    return isSceneLoaded ? scene.findObject(blockId + "_toggle") : null
  }

  function wrapNextSelect(obj = null, dir = 0)
  {
    if (::handlersManager.isHandlerValid(parentHandlerWeak))
      parentHandlerWeak.wrapNextSelect(obj, dir)
  }

  function onWrapLeft(obj)
  {
    if (::handlersManager.isHandlerValid(parentHandlerWeak)
        && ::u.isFunction(parentHandlerWeak.onWrapLeft))
      parentHandlerWeak.onWrapLeft(obj)
  }

  function onWrapRight(obj)
  {
    if (::handlersManager.isHandlerValid(parentHandlerWeak)
        && ::u.isFunction(parentHandlerWeak.onWrapRight))
      parentHandlerWeak.onWrapRight(obj)
  }
}