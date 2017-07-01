::dagui_propid.add_name_id("has_ime")
::dagui_propid.add_name_id("target_platform")

::current_base_gui_handler <- null //active base handler in main gui scene
::always_reload_scenes <- false //debug only

::handlersManager <- {
  [PERSISTENT_DATA_PARAMS] = ["lastBaseHandlerStartFunc"]

  handlers = { //handlers weakrefs
    [handlerType.ROOT] = [],
    [handlerType.BASE] = [],
    [handlerType.MODAL] = [],
    [handlerType.CUSTOM] = []
  }
  activeBaseHandlers = [] //one  per guiScene
  activeRootHandlers = [] //not more than one per guiScene
  sceneObjIdx = -1
  lastGuiScene = null
  needFullReload = false
  needCheckPostLoadCss = false
  isFullReloadInProgress = false
  loaded_postLoadCss = ""
  isPxFontsInScene = false
  isInLoading = true
  restoreDataByTriggerHandler = {}
  lastBaseHandlerStartFunc = null //function to start backScene or to reload current base handler
                                  //automatically set on loadbaseHandler
                                  //but can be overrided by setLastBaseHandlerStartFunc

  lastLoadedHandlerName = ""

  setIngameShortcutsActive           = function(isActive) {}
  onClearScene                       = function() {}
  isNeedFullReloadAfterClearScene    = function() { return false }
  isNeedReloadSceneSpecific          = function() { return false }
  updatePostLoadCss                  = function() { return false } //return is css was updated
  onSwitchBaseHandler                = function() {}
  onActiveHandlersChanged            = function() {} //called when loaded or switched handlers,
                                                     //loaded or destroyed modal windows (inclode scene_msg_boxes
                                                     //dosn't called twice when single handler load subhandlers on init.
  animatedSwitchScene                = function(startFunc) { startFunc () } //no anim by default
  beforeLoadHandler                  = function(hType) {}

  _loadHandlerRecursionLevel         = 0
}

function handlersManager::init()
{
  ::g_script_reloader.registerPersistentDataFromRoot("handlersManager")
  ::subscribe_handler(::handlersManager, ::g_listener_priority.DEFAULT_HANDLER)
}

function handlersManager::loadHandler(handlerClass, params = {})
{
  _loadHandlerRecursionLevel++

  local hType = getHandlerType(handlerClass)
  beforeLoadHandler(hType)

  local startTime = ::dagor.getCurTime()
  local dbgName = onLoadHandlerDebug(handlerClass, params)

  local handler = null
  if (hType == handlerType.MODAL)
    handler = loadModalHandler(handlerClass, params)
  else if (hType==handlerType.CUSTOM)
    handler = loadCustomHandler(handlerClass, params)
  else
    handler = loadBaseHandler(handlerClass, params)

  ::dagor.debug(format("GuiManager: loading time = %d (%s)", (::dagor.getCurTime() - startTime),  dbgName))

  restoreHandlers(handlerClass)

  if (hType == handlerType.BASE && ::saved_scene_msg_box)
    ::saved_scene_msg_box()

  _loadHandlerRecursionLevel--
  if (!_loadHandlerRecursionLevel)
    onActiveHandlersChanged()
  return handler
}

function handlersManager::getHandlerClassName(handlerClass)
{
  foreach(name, hClass in ::gui_handlers)
    if (handlerClass == hClass)
      return name
  return null
}

function handlersManager::getHandlerClassDebugName(handlerClass)
{
  local className = getHandlerClassName(handlerClass)
  if (className)
    return "::gui_handlers." + className
  return " sceneBlk = " + ::getTblValue("sceneBlkName", handlerClass, null)
}

function handlersManager::onLoadHandlerDebug(handlerClass, params)
{
  local handlerName = getHandlerClassDebugName(handlerClass)
  dagor.debug("GuiManager: load handler " + handlerName)

  lastLoadedHandlerName = handlerName
  return handlerName
}

function handlersManager::initHandler(handler)
{
  local result
  try
  {
    handler.init()
    result = true
  }
  catch (errorMessage)
  {
    local handlerName = getHandlerClassDebugName(handler)
    local message = ::format("Error on init handler %s:\n%s", handlerName, errorMessage)
    ::script_net_assert_once(handlerName, message)
    local type = getHandlerType(handler.getclass())
    if (type == handlerType.MODAL)
    {
      if (::check_obj(handler.scene))
        ::get_cur_gui_scene().destroyElement(handler.scene)
    }
    else if (type == handlerType.CUSTOM)
    {
      if (::check_obj(handler.scene))
        ::get_cur_gui_scene().replaceContentFromText(handler.scene, "", 0, null)
      handler.scene = null
    }
    else if (handler.getclass() == ::gui_handlers.MainMenu)
      ::gui_start_logout()
    else
      ::gui_start_mainmenu()
    result = false
  }
  return result
}

function handlersManager::reinitHandler(handler, params)
{
  if ("reinitScreen" in handler)
    handler.reinitScreen(params)
}

function handlersManager::destroyHandler(handler) //destroy handler with it subhandlers.
                                                 //destroy handler scene, so accurate use with custom handlers
{
  if (!isHandlerValid(handler))
    return

  handler.onDestroy()
  foreach(sh in handler.subHandlers)
    destroyHandler(sh)
  handler.guiScene.destroyElement(handler.scene)
}

function handlersManager::loadBaseHandler(handlerClass, params = {})
{
  local reloadScene = updatePostLoadCss() || needReloadScene()
  local reload = !handlerClass.keepLoaded || reloadScene
  if (!reload)
  {
    local handler = findAndReinitHandler(handlerClass, params)
    if (handler)
    {
      setLastBaseHandlerStartFuncByHandler(handlerClass, params)
      ::broadcastEvent("NewSceneLoaded")
      return handler
    }
  }

  if (reloadScene)
    clearScene()

  local guiScene = ::get_gui_scene()
  local handler = createHandler(handlerClass, guiScene, params)
  local newLoadedRootHandler = loadHandlerScene(handler)
  switchBaseHandler(handler)

  local initResult = true
  if (newLoadedRootHandler)
    initResult = initHandler(newLoadedRootHandler)
  initResult = initResult && initHandler(handler)
  if (!initResult)
    return null

  handlers[handlerType.BASE].append(handler.weakref())
  lastGuiScene = handler.guiScene

  setLastBaseHandlerStartFuncByHandler(handlerClass, params)
  ::broadcastEvent("NewSceneLoaded")
  return handler
}

function handlersManager::loadHandlerScene(handler)
{
  if (!handler.sceneBlkName)
  {
    callstack()
    ::dagor.assertf(false, "Error: cant load base handler w/o sceneBlkName.")
    return null
  }

  local id = "root_scene_" + ++sceneObjIdx + " " + handler.sceneBlkName //mostly for debug
  if (!handler.rootHandlerClass || getHandlerType(handler) != handlerType.BASE)
  {
    local rootObj = handler.guiScene.getRoot()
    handler.scene = handler.guiScene.createElementByObject(rootObj, handler.sceneBlkName, "rootScene", handler)
    handler.scene.id = id
    return null
  }

  local newLoadedRootHandler = null
  local guiScene = ::get_cur_gui_scene()
  local rootHandler = findHandlerClassInScene(handler.rootHandlerClass)
  if (!isHandlerValid(rootHandler, true))
  {
    rootHandler = handler.rootHandlerClass(guiScene, {})
    loadHandlerScene(rootHandler)
    handlers[handlerType.ROOT].append(rootHandler.weakref())
    ::subscribe_handler(rootHandler)
    newLoadedRootHandler = rootHandler
  }

  local rootObj = rootHandler.getBaseHandlersContainer() || guiScene.getRoot()
  handler.scene = guiScene.createElementByObject(rootObj, handler.sceneBlkName, "rootScene", handler)
  handler.scene.id = id
  handler.rootHandlerWeak = rootHandler.weakref()
  return newLoadedRootHandler
}

function handlersManager::loadModalHandler(handlerClass, params = {})
{
  if (!handlerClass.sceneBlkName && !handler.sceneTplName)
  {
    callstack()
    ::dagor.assertf(handlerClass.sceneBlkName!=null, "Error: cant load modal handler w/o sceneBlkName or sceneTplName.")
    return null
  }
  local handler = findHandlerClassInScene(handlerClass)
  if (handler && !handlerClass.multipleInstances)
  {
    reinitHandler(handler, params)
    return handler
  }

  local guiScene = ::get_gui_scene()
  handler = createHandler(handlerClass, guiScene, params)
  handlers[handlerType.MODAL].append(handler.weakref())

  local scene = guiScene.loadModal("", handler.sceneBlkName || "gui/emptyScene.blk", "rootScene", handler)
  scene.id = "modal_wnd_" + ++sceneObjIdx + " " + handler.sceneBlkName //mostly for debug
  handler.scene = scene

  handler.initHandlerSceneTpl()
  local initResult = initHandler(handler)
  if (!initResult)
    return null

  return handler
}

function handlersManager::loadCustomHandler(handlerClass, params = {})
{
  local guiScene = ::get_gui_scene()
  local handler = createHandler(handlerClass, guiScene, params)
  if (!handler.sceneBlkName && !handler.sceneTplName)
  {
    callstack()
    ::dagor.assertf(false, "Error: cant load custom handler w/o sceneBlkName or sceneTplName.")
    return null
  }

  if (!handler.initCustomHandlerScene())
    loadHandlerScene(handler)
  local initResult = initHandler(handler)
  if (!initResult)
    return null

  handlers[handlerType.CUSTOM].append(handler.weakref())
  return handler
}

function handlersManager::createHandler(handlerClass, guiScene, params)
{
  local handler = handlerClass(guiScene, params)
  ::subscribe_handler(handler)
  return handler
}

function handlersManager::findAndReinitHandler(handlerClass, params)
{
  local curHandler = getActiveBaseHandler()
  if (curHandler && curHandler.getclass() == handlerClass)
  {
    reinitHandler(curHandler, params)
    return curHandler
  }

  local handler = findHandlerClassInScene(handlerClass)
  if (!handler)
    return null

  switchBaseHandler(handler)
  reinitHandler(handler, params)
  return handler
}

function handlersManager::switchBaseHandler(handler)
{
  local guiScene = ::get_cur_gui_scene()
  closeAllModals(guiScene)

  local curHandler = getActiveBaseHandler()
  showBaseHandler(curHandler, false)
  onBaseHandlerSwitch()
  if (handler)
  {
    switchRootHandlerChecked(handler.rootHandlerClass)
    showBaseHandler(handler, true)
  }

  removeHandlerFromListByGuiScene(activeBaseHandlers, guiScene)

  if (handler)
    activeBaseHandlers.append(handler)

  if (isMainGuiSceneActive())
    ::current_base_gui_handler = handler

  updateLoadingFlag()

  updateIngameShortcutsActive(curHandler, handler)

  onSwitchBaseHandler()

  ::broadcastEvent("SwitchedBaseHandler")
}

function handlersManager::switchRootHandlerChecked(rootHandlerClass)
{
  local curRootHandler = getActiveRootHandler()
  if ((!curRootHandler && !rootHandlerClass)
      || (curRootHandler && curRootHandler.getclass() == rootHandlerClass))
    return

  if (curRootHandler)
    showBaseHandler(curRootHandler, false)

  removeHandlerFromListByGuiScene(activeRootHandlers, ::get_cur_gui_scene())

  local newRootHandler = rootHandlerClass && findHandlerClassInScene(rootHandlerClass)
  if (newRootHandler)
  {
    activeRootHandlers.append(newRootHandler)
    showBaseHandler(newRootHandler, true)
  }
}

function removeHandlerFromListByGuiScene(list, guiScene)
{
  for(local i = list.len()-1; i >= 0; i--)
  {
    local h = list[i]
    if (!h || !h.guiScene || guiScene.isEqual(h.guiScene))
      list.remove(i)
  }
}

function handlersManager::updateIngameShortcutsActive(prevHandler, curHandler)
{
  if (!prevHandler && !curHandler)
    return

  if (!prevHandler || prevHandler.allowIngameShortcuts != curHandler.allowIngameShortcuts)
    setIngameShortcutsActive(curHandler.allowIngameShortcuts)
}

function handlersManager::onBaseHandlerSwitch()
{
  ::reset_msg_box_check_anim_time() //no need msg box anim right after scene switch
}

function handlersManager::showBaseHandler(handler, show)
{
  if (!isHandlerValid(handler, false))
    return clearInvalidHandlers()

  if (!show && !handler.keepLoaded)
  {
    destroyHandler(handler)
    clearInvalidHandlers()
    return
  }

  handler.scene.show(show)
  handler.scene.enable(show)
  if ("onSceneActivate" in handler)
    handler.onSceneActivate(show)
}

//if guiScene == null, will be used current scene
function handlersManager::clearScene(guiScene = null)
{
  if (!guiScene)
    guiScene = ::get_cur_gui_scene()
  sendEventToHandlers("onDestroy", guiScene)

  guiScene.loadScene("gui/rootScreen.blk", this)

  setGuiRootOptions(guiScene, false)
  guiScene.initCursor("gui/cursor.blk", "normal")
  if (!guiScene.isEqual(::get_cur_gui_scene()))
    return

  lastGuiScene = guiScene

  if (!isNeedFullReloadAfterClearScene())
    needFullReload = false

  updateLoadingFlag()
  onClearScene()
}

function handlersManager::updateLoadingFlag()
{
  local oldVal = isInLoading
  isInLoading = !isMainGuiSceneActive()
                || (!getActiveBaseHandler() && !getActiveRootHandler())//empty screen count as loading too

  if (oldVal != isInLoading)
    ::broadcastEvent("LoadingStateChange")
}

function handlersManager::emptyScreen()
{
  dagor.debug("GuiManager: load emptyScreen")
  setLastBaseHandlerStartFunc(function() { ::handlersManager.emptyScreen() })
  lastLoadedHandlerName = "emptyScreen"

  if (updatePostLoadCss() || getActiveBaseHandler() || getActiveRootHandler() || needReloadScene())
    clearScene()
  switchBaseHandler(null)

  if (!_loadHandlerRecursionLevel)
    onActiveHandlersChanged()
}

function handlersManager::isMainGuiSceneActive()
{
  return ::get_cur_gui_scene().isEqual(::get_main_gui_scene())
}

function handlersManager::setGuiRootOptions(guiScene, forceUpdate = true)
{
  local rootObj = guiScene.getRoot()

  rootObj["show_console_buttons"] = ::show_console_buttons ? "yes" : "no" //should to force box buttons in WoP?
  if (::should_swap_advance())
    rootObj["swap_ab"] = "yes"

  //Check for special hints, because IME is called with special action, and need to show text about it
  local hasIME = ::is_platform_ps4 || ::is_platform_android || ::is_steam_big_picture()
  rootObj["has_ime"] = hasIME? "yes" : "no"

  rootObj["target_platform"] = ::target_platform

  if (!forceUpdate)
    return

  rootObj["css-hier-invalidate"] = "all"  //need to update scene after set this parameters
  guiScene.performDelayed(this, (@(rootObj) function(dummy) {
    if (::check_obj(rootObj))
      rootObj["css-hier-invalidate"] = "no"
  })(rootObj))
}

function handlersManager::needReloadScene()
{
  return needFullReload || ::always_reload_scenes || !::check_obj(::get_cur_gui_scene()["root_loaded"])
         || isNeedReloadSceneSpecific()
}

function handlersManager::startSceneFullReload(startSceneFunc = null)
{
  startSceneFunc = startSceneFunc || lastBaseHandlerStartFunc
  if (!startSceneFunc)
    return

  needFullReload = true
  isFullReloadInProgress = true
  startSceneFunc()
  isFullReloadInProgress = false
}

function handlersManager::markfullReloadOnSwitchScene(needReloadOnActivateHandlerToo = true)
{
  needFullReload = true
  if (!needReloadOnActivateHandlerToo)
    return

  local handler = ::handlersManager.getActiveBaseHandler()
  if (handler)
    handler.doWhenActiveOnce("fullReloadScene")
}

function handlersManager::onEventScriptsReloaded(p)
{
  markfullReloadOnSwitchScene()
  if (lastBaseHandlerStartFunc)
    lastBaseHandlerStartFunc()
}

function handlersManager::checkPostLoadCssOnBackToBaseHandler()
{
  needCheckPostLoadCss = true
}

function handlersManager::checkPostLoadCss()
{
  if (!needCheckPostLoadCss)
    return false
  local handler = ::handlersManager.getActiveBaseHandler()
  if (!handler || !handler.isSceneActiveNoModals())
    return false

  needCheckPostLoadCss = false
  if (!updatePostLoadCss())
    return false

  handler.fullReloadScene()
  return true
}

function handlersManager::onEventModalWndDestroy(p)
{
  if (!checkPostLoadCss() && !_loadHandlerRecursionLevel)
    onActiveHandlersChanged()
}

function handlersManager::onEventMsgBoxCreated(p)
{
  if (!_loadHandlerRecursionLevel)
    onActiveHandlersChanged()
}

function handlersManager::isModal(handlerClass)
{
  return getHandlerType(handlerClass) == handlerType.MODAL
}

function handlersManager::getHandlerType(handlerClass)
{
  return handlerClass.wndType
}

function handlersManager::isHandlerValid(handler, checkGuiScene = false)
{
  return handler != null && handler.isValid() && (!checkGuiScene || handler.isInCurrentScene())
}

function handlersManager::clearInvalidHandlers()
{
  foreach(hType, group in handlers)
    for(local i = group.len()-1; i >= 0; i--)
      if (!isHandlerValid(group[i], false))
        group.remove(i)
}

function handlersManager::closeAllModals(guiScene = null)
{
  ::destroy_all_msg_boxes(guiScene)

  local group = handlers[handlerType.MODAL]
  for(local i = group.len()-1; i >= 0; i--)
  {
    local handler = group[i]
    if (guiScene && handler && !guiScene.isEqual(handler.guiScene))
      continue

    destroyHandler(handler)
    group.remove(i)
  }
}

function handlersManager::destroyModal(handler)
{
  if (!isHandlerValid(handler, true))
    return

  foreach(idx, h in handlers[handlerType.MODAL])
    if (isHandlerValid(h, true) && h.scene.isEqual(handler.scene))
    {
      handlers[handlerType.MODAL].remove(idx)
      break
    }
  destroyHandler(handler)
}

function handlersManager::findHandlerClassInScene(searchClass, checkGuiScene = true)
{
  local searchType = getHandlerType(searchClass)
  if (searchType in handlers)
    foreach(handler in handlers[searchType])
      if (!searchClass || (handler && handler.getclass() == searchClass))
      {
        if (isHandlerValid(handler, checkGuiScene))
          return handler
      }
  return null
}

function handlersManager::isAnyModalHandlerActive()
{
  foreach(handler in handlers[handlerType.MODAL])
    if (isHandlerValid(handler, true))
      return handler
  return null
}

function handlersManager::getActiveBaseHandler()
{
  local curGuiScene = ::get_cur_gui_scene()
  foreach(handler in activeBaseHandlers)
    if (handler.guiScene && handler.guiScene.isEqual(curGuiScene) && isHandlerValid(handler, false))
      return handler
  return null
}

function handlersManager::getActiveRootHandler()
{
  local curGuiScene = ::get_cur_gui_scene()
  foreach(handler in activeRootHandlers)
    if (handler.guiScene && handler.guiScene.isEqual(curGuiScene) && isHandlerValid(handler, false))
      return handler
  return null
}

function handlersManager::sendEventToHandlers(eventFuncName, guiScene = null, params = null)
{
  foreach(hType, hList in handlers)
    foreach(handler in hList)
      if (isHandlerValid(handler)
          && (!guiScene || handler.guiScene.isEqual(guiScene))
          && eventFuncName in handler && type(handler[eventFuncName]) == "function")
        if (params)
          handler[eventFuncName].call(handler, params)
        else
          handler[eventFuncName].call(handler)
}

/**
 * Finds handler with class 'restoreHandlerClass' and re-opens
 * it after 'triggerHandlerClass' was inited.
 *
 * @param restoreHandler Handler to be restored.
 * @param triggerHandlerClass Class of handler that triggers window restore.
 * Current base handler if used if this parameter not specified.
 * @return False if windows restoration failed. Occures if window
 * handler was not found or getHandlerRestoreData is not implemented.
 */
function handlersManager::requestHandlerRestore(restoreHandler, triggerHandlerClass = null)
{
  local restoreData = restoreHandler.getHandlerRestoreData()
  if (restoreData == null) // Not implemented.
    return false
  restoreData.handlerClass <- restoreHandler.getclass()
  if (triggerHandlerClass == null)
    triggerHandlerClass = getActiveBaseHandler()
  if (!triggerHandlerClass)
    return false

  local restoreDataArray = ::getTblValue(triggerHandlerClass, restoreDataByTriggerHandler, null) || []
  restoreDataArray.push(restoreData)
  restoreDataByTriggerHandler[triggerHandlerClass] <- restoreDataArray
  return true
}

/**
 * Restores handlers requested by specified trigger-handler.
 * Does nothing if no restore data found.
 */
function handlersManager::restoreHandlers(triggerHandlerClass)
{
  local restoreDataArray = ::getTblValue(triggerHandlerClass, restoreDataByTriggerHandler, null)
  if (restoreDataArray == null)
    return
  restoreDataByTriggerHandler[triggerHandlerClass] <- null
  for (local i = 0; i < restoreDataArray.len(); ++i) // First in - first out.
  {
    local restoreData = restoreDataArray[i]

    local openData = ::getTblValue("openData", restoreData, null)
    local handler = loadHandler(restoreData.handlerClass, openData || {})

    local stateData = ::getTblValue("stateData", restoreData, null)
    if (stateData != null)
      handler.restoreHandler(stateData)
  }
}

function handlersManager::getLastBaseHandlerStartFunc()
{
  return lastBaseHandlerStartFunc
}

function handlersManager::setLastBaseHandlerStartFunc(startFunc)
{
  lastBaseHandlerStartFunc = startFunc
}

function handlersManager::setLastBaseHandlerStartFuncByHandler(handlerClass, params)
{
  local handlerClassName = getHandlerClassName(handlerClass)
  lastBaseHandlerStartFunc = (@(handlerClassName, handlerClass, params) function() {
                               local hClass = ::getTblValue(handlerClassName, ::gui_handlers, handlerClass)
                               ::handlersManager.loadHandler(hClass, params)
                             })(handlerClassName, handlerClass, params)
}

//=======================  global functions  ==============================

function isHandlerInScene(handlerClass)
{
  return ::handlersManager.findHandlerClassInScene(handlerClass) != null
}
function gui_start_modal_wnd(handlerClass, params = {}) //only for basic handlers with sceneBlkName predefined
{
  return ::handlersManager.loadHandler(handlerClass, params)
}

function is_in_loading_screen()
{
  return ::handlersManager.isInLoading
}