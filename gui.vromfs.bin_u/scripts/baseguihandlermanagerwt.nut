local colorCorrector = ::require_native("colorCorrector")
local fonts = require("fonts")
local screenInfo = require("scripts/options/screenInfo.nut")
local safeAreaMenu = require("scripts/options/safeAreaMenu.nut")
local safeAreaHud = require("scripts/options/safeAreaHud.nut")
local gamepadIcons = require("scripts/controls/gamepadIcons.nut")
local focusFrame = require("scripts/viewUtils/focusFrameWT.nut")
local { setSceneActive } = require("reactiveGuiCommand")
local rootScreenBlkPathWatch = require("scripts/baseGuiHandler/rootScreenBlkPathWatch.nut")
local { startLogout } = require("scripts/login/logout.nut")
local { isPlatformSony,
        isPlatformXboxOne,
        targetPlatform } = require("scripts/clientState/platform.nut")

::dagui_propid.add_name_id("has_ime")
::dagui_propid.add_name_id("target_platform")

handlersManager[PERSISTENT_DATA_PARAMS].append("curControlsAllowMask", "isCurSceneBgBlurred")

::handlersManager.lastInFlight <- false  //to reload scenes on change inFlight
::handlersManager.currentFont <- ::g_font.LARGE
::handlersManager.lastScreenHeightForFont <- 0
::handlersManager.shouldResetFontsCache <- false

::handlersManager.curControlsAllowMask <- CtrlsInGui.CTRL_ALLOW_FULL
::handlersManager.controlsAllowMaskDefaults <- {
  [handlerType.ROOT] = CtrlsInGui.CTRL_ALLOW_FULL,
  [handlerType.BASE] = CtrlsInGui.CTRL_ALLOW_ANSEL,
  [handlerType.MODAL] = CtrlsInGui.CTRL_ALLOW_NONE,
  [handlerType.CUSTOM] = CtrlsInGui.CTRL_ALLOW_FULL
}

::handlersManager.isCurSceneBgBlurred <- false
::handlersManager.sceneBgBlurDefaults <- {
  [handlerType.ROOT]   = false,
  [handlerType.BASE]   = false,
  [handlerType.MODAL]  = false,
  [handlerType.CUSTOM] = false,
}

handlersManager.beforeClearScene <- function beforeClearScene(guiScene)
{
  local sh = screenInfo.getScreenHeightForFonts(::screen_width(), ::screen_height())
  if (lastScreenHeightForFont && lastScreenHeightForFont != sh)
    shouldResetFontsCache = true
  lastScreenHeightForFont = sh

  if (shouldResetFontsCache)
  {
    fonts.discardLoadedData()
    shouldResetFontsCache = false
  }
}

handlersManager.onClearScene <- function onClearScene(guiScene)
{
  if (isMainGuiSceneActive()) //is_in_flight function not available before first loading screen
    lastInFlight = ::is_in_flight()

  focusFrame.enable(::get_is_console_mode_enabled())

  if (guiScene.setCursorSizeMul) //compatibility with old exe
    guiScene.setCursorSizeMul(guiScene.calcString("@cursorSizeMul", null))
  if (guiScene.setPatternSizeMul) //compatibility with old exe
    guiScene.setPatternSizeMul(guiScene.calcString("@dp", null))
  ::enable_dirpad_control_mouse(true)
}

handlersManager.isNeedFullReloadAfterClearScene <- function isNeedFullReloadAfterClearScene()
{
  return !isMainGuiSceneActive()
}

handlersManager.isNeedReloadSceneSpecific <- function isNeedReloadSceneSpecific()
{
  return isMainGuiSceneActive() && lastInFlight != ::is_in_flight()
}

handlersManager.beforeLoadHandler <- function beforeLoadHandler(hType)
{
  //clear main gui scene when load to battle or from battle
  if ((hType == handlerType.BASE || hType == handlerType.ROOT)
      && ::g_login.isLoggedIn()
      && lastGuiScene
      && lastGuiScene.isEqual(::get_main_gui_scene())
      && !isMainGuiSceneActive())
    clearScene(lastGuiScene)
}

handlersManager.onBaseHandlerLoadFailed <- function onBaseHandlerLoadFailed(handler)
{
  if (!::g_login.isLoggedIn()
      || handler.getclass() == ::gui_handlers.MainMenu
      || handler.getclass() == ::gui_handlers.FlightMenu
     )
    startLogout()
  else if (::is_in_flight())
    ::gui_start_flight_menu()
  else
    ::gui_start_mainmenu()
}

handlersManager.onSwitchBaseHandler <- function onSwitchBaseHandler()
{
  if (!::g_login.isLoggedIn())
    return
  local curHandler = getActiveBaseHandler()
  if (curHandler)
    ::set_last_gc_scene_if_exist(curHandler.scene)
}

handlersManager.animatedSwitchScene <- function animatedSwitchScene(startFunc)
{
  ::switch_gui_scene(startFunc)
}

handlersManager.updatePostLoadCss <- function updatePostLoadCss()
{
  local haveChanges = false

  local font = ::g_font.getCurrent()
  if (currentFont != font)
  {
    shouldResetFontsCache = true
    haveChanges = true
    ::call_darg("updateExtWatched", {
      fontGenId = font.fontGenId
      fontSizePx = font.getFontSizePx(::screen_width(), ::screen_height())
    })
  }
  currentFont = font

  local cssStringPre = font.genCssString() + "\n" + generatePreLoadCssString() + "\n" + gamepadIcons.getCssString()
  if (::get_dagui_pre_include_css_str() != cssStringPre)
  {
    local safearea = safeAreaHud.getSafearea()
    ::set_dagui_pre_include_css_str(cssStringPre)
    ::set_hud_width_limit(safearea[0])
    ::call_darg("updateExtWatched", {
      safeAreaHud = safearea
      safeAreaMenu = safeAreaMenu.getSafearea()
    })
    haveChanges = true
  }

  ::set_dagui_pre_include_css("")

  local cssStringPost = generatePostLoadCssString()
  if (::get_dagui_post_include_css_str() != cssStringPost)
  {
    ::set_dagui_post_include_css_str(cssStringPost)
    local forcedColors = ::g_login.isLoggedIn() ? ::get_team_colors() : {}
    ::call_darg("recalculateTeamColors", forcedColors)
    haveChanges = true
  }

  if (::switch_show_console_buttons(::get_is_console_mode_enabled()))
    haveChanges = true

  return haveChanges
}

handlersManager.generatePreLoadCssString <- function generatePreLoadCssString()
{
  local countriesCount = 7
  if (::g_login.isLoggedIn())
  {
    countriesCount = 0
    foreach(c in ::shopCountriesList)
      if (::is_country_visible(c))
        countriesCount++
  }

  local hudSafearea = safeAreaHud.getSafearea()
  local menuSafearea = safeAreaMenu.getSafearea()

  local config = [
    { name = "target_pc",         value = (isPlatformSony || isPlatformXboxOne) ? "no" : "yes" }
    { name = "swMain",            value = screenInfo.getMainScreenSizePx()[0].tostring() }
    { name = "_safearea_menu_w",  value = ::format("%.2f", menuSafearea[0]) }
    { name = "_safearea_menu_h",  value = ::format("%.2f", menuSafearea[1]) }
    { name = "_safearea_hud_w",   value = ::format("%.2f", hudSafearea[0]) }
    { name = "_safearea_hud_h",   value = ::format("%.2f", hudSafearea[1]) }
    { name = "slotbarCountries",  value = countriesCount.tostring() }
  ]

  return generateCssString(config)
}


handlersManager.generateColorConstantsConfig <- function generateColorConstantsConfig()
{
  if (!::g_login.isAuthorized())
    return []

  local cssConfig = []
  local standardColors = !::g_login.isLoggedIn() || !::isPlayerDedicatedSpectator()
  local forcedColors = ::get_team_colors()
  local allyTeam, allyTeamColor, enemyTeamColor
  if (forcedColors)
  {
    allyTeam = ::get_mp_local_team()
    allyTeamColor = allyTeam == 2 ? forcedColors?.colorTeamB : forcedColors?.colorTeamA
    enemyTeamColor = allyTeam == 2 ? forcedColors?.colorTeamA : forcedColors?.colorTeamB
    cssConfig.append(
      {
        name = "mainPlayerColor"
        value = "#" + allyTeamColor
      },
      {
        name = "chatSenderMeColor"
        value = "#" + allyTeamColor
      },
      {
        name = "hudColorHero"
        value = "#" + allyTeamColor
      }
    )
  }

  local theme = {
    squad = standardColors ? colorCorrector.TARGET_HUE_SQUAD : colorCorrector.TARGET_HUE_SPECTATOR_ALLY
    ally  = standardColors ? colorCorrector.TARGET_HUE_ALLY  : colorCorrector.TARGET_HUE_SPECTATOR_ALLY
    enemy = standardColors ? colorCorrector.TARGET_HUE_ENEMY : colorCorrector.TARGET_HUE_SPECTATOR_ENEMY
  }

  local config = [
    { style = "squad", baseColor = "3E9E2F", names = [ "mySquadColor", "hudColorSquad", "chatSenderMySquadColor", "chatTextSquadVoiceColor" ] }
    { style = "squad", baseColor = "65FF4D", names = [ "chatTextSquadColor" ] }
    { style = "squad", baseColor = "A5FF97", names = [ "mySquadLightColor" ] }
    { style = "ally",  baseColor = "527AFF", names = [ "teamBlueColor", "hudColorBlue", "chatSenderFriendColor", "chatTextTeamVoiceColor" ] }
    { style = "ally",  baseColor = "99B1FF", names = [ "teamBlueLightColor", "hudColorDeathEnemy" ] }
    { style = "ally",  baseColor = "5C637A", names = [ "teamBlueInactiveColor", "hudColorDarkBlue" ] }
    { style = "ally",  baseColor = "0F1834", names = [ "teamBlueDarkColor" ] }
    { style = "ally",  baseColor = "82C2FF", names = [ "chatTextTeamColor" ] }
    { style = "enemy", baseColor = "FF5A52", names = [ "teamRedColor", "hudColorRed", "chatSenderEnemyColor", "chatTextEnemyVoiceColor" ] }
    { style = "enemy", baseColor = "FFA29D", names = [ "teamRedLightColor", "hudColorDeathAlly" ] }
    { style = "enemy", baseColor = "7C5F5D", names = [ "teamRedInactiveColor", "hudColorDarkRed" ] }
    { style = "enemy", baseColor = "34110F", names = [ "teamRedDarkColor" ] }
  ]

  foreach (cfg in config)
  {
    local color = forcedColors ? (cfg.style == "enemy" ? enemyTeamColor : allyTeamColor)
      : colorCorrector.correctHueTarget(cfg.baseColor, theme[cfg.style])

    foreach (name in cfg.names)
      cssConfig.append({
        name = name,
        value = "#" + color
      })
  }

  return cssConfig
}


handlersManager.generatePostLoadCssString <- function generatePostLoadCssString()
{
  local controlCursorWithStick = ::g_gamepad_cursor_controls.getValue()
  local config = [
    {
      name = "shortcutUpGamepad"
      value = controlCursorWithStick ? "@shortcutUpDp" : "@shortcutUpDpAndStick"
    }
    {
      name = "shortcutDownGamepad"
      value = controlCursorWithStick ? "@shortcutDownDp" : "@shortcutDownDpAndStick"
    }
    {
      name = "shortcutLeftGamepad"
      value = controlCursorWithStick ? "@shortcutLeftDp" : "@shortcutLeftDpAndStick"
    }
    {
      name = "shortcutRightGamepad"
      value = controlCursorWithStick ? "@shortcutRightDp" : "@shortcutRightDpAndStick"
    }
  ]

  config.extend(generateColorConstantsConfig())

  return generateCssString(config)
}


handlersManager.generateCssString <- function generateCssString(config)
{
  local res = ""
  foreach (cfg in config)
    res += ::format("@const %s:%s;", cfg.name, cfg.value)
  return res
}

handlersManager.updateCssParams <- function(guiScene) {
  local rootObj = guiScene.getRoot()

  //Check for special hints, because IME is called with special action, and need to show text about it
  local hasIME = isPlatformSony || isPlatformXboxOne || ::is_platform_android || ::is_steam_big_picture()
  rootObj["has_ime"] = hasIME? "yes" : "no"
  rootObj["target_platform"] = targetPlatform
}

handlersManager.getHandlerControlsAllowMask <- function getHandlerControlsAllowMask(handler)
{
  local res = null
  if ("getControlsAllowMask" in handler)
    res = handler.getControlsAllowMask()
  if (res != null)
    return res
  return ::getTblValue(handler.wndType, controlsAllowMaskDefaults, CtrlsInGui.CTRL_ALLOW_FULL)
}

handlersManager.calcCurrentControlsAllowMask <- function calcCurrentControlsAllowMask()
{
  if (::check_obj(::current_wait_screen))
    return CtrlsInGui.CTRL_ALLOW_NONE
  if (::is_active_msg_box_in_scene(::get_cur_gui_scene()))
    return CtrlsInGui.CTRL_ALLOW_NONE

  local res = CtrlsInGui.CTRL_ALLOW_FULL
  foreach(group in handlers)
    foreach(h in group)
      if (isHandlerValid(h, true) && h.isSceneActive())
      {
        local mask = getHandlerControlsAllowMask(h)
        res = res & mask | (CtrlsInGui.CTRL_WINDOWS_ALL & (res | mask))
      }

  foreach(name in ["menu_chat_handler", "contacts_handler", "game_chat_handler"])
    if (name in ::getroottable() && ::getroottable()[name])
    {
      local mask = ::getroottable()[name].getControlsAllowMask()
      res = res & mask | (CtrlsInGui.CTRL_WINDOWS_ALL & (res | mask))
    }

  return res
}

handlersManager.updateControlsAllowMask <- function updateControlsAllowMask()
{
  if (!_loadHandlerRecursionLevel)
    _updateControlsAllowMask()
}

handlersManager._updateControlsAllowMask <- function _updateControlsAllowMask()
{
  local newMask = calcCurrentControlsAllowMask()
  if (newMask == curControlsAllowMask)
    return

  curControlsAllowMask = newMask
  ::set_allowed_controls_mask(curControlsAllowMask)
  //dlog(::format("GP: controls changed to 0x%X", curControlsAllowMask))
}

handlersManager._updateWidgets <- function _updateWidgets()
{
  local widgetsList = []
  local hasActiveDargScene = false
  foreach(group in handlers)
    foreach(h in group)
      if (isHandlerValid(h, true) && h.isSceneActive() && h?.getWidgetsList)
      {
        local wList = h.getWidgetsList()
        widgetsList.extend(wList)
        if (wList.len() > 0 && h.isSceneActiveNoModals())
          hasActiveDargScene = true
      }

  setSceneActive(hasActiveDargScene)
  ::call_darg("updateWidgets", widgetsList)
}

handlersManager.calcCurrentSceneBgBlur <- function calcCurrentSceneBgBlur()
{
  foreach(wndType, group in handlers)
  {
    local defValue = ::getTblValue(wndType, sceneBgBlurDefaults, false)
    foreach(h in group)
      if (isHandlerValid(h, true) && h.isSceneActive())
        if (::getTblValue("shouldBlurSceneBg", h, defValue))
          return true
  }
  return false
}

handlersManager.updateSceneBgBlur <- function updateSceneBgBlur(forced = false)
{
  if (!_loadHandlerRecursionLevel)
    _updateSceneBgBlur(forced)
}


handlersManager._updateSceneBgBlur <- function _updateSceneBgBlur(forced = false)
{
  local isBlur = calcCurrentSceneBgBlur()
  if (!forced && isBlur == isCurSceneBgBlurred)
    return

  isCurSceneBgBlurred = isBlur
  ::hangar_blur(isCurSceneBgBlurred)
}

handlersManager.onActiveHandlersChanged <- function onActiveHandlersChanged()
{
  _updateControlsAllowMask()
  _updateWidgets()
  _updateSceneBgBlur()
  ::broadcastEvent("ActiveHandlersChanged")
}

handlersManager.onEventWaitBoxCreated <- function onEventWaitBoxCreated(p)
{
  _updateControlsAllowMask()
  _updateWidgets()
  _updateSceneBgBlur()
}

handlersManager.beforeInitHandler <- function beforeInitHandler(handler)
{
  if (handler.rootHandlerClass || getHandlerType(handler) == handlerType.CUSTOM)
    return

  if (focusFrame.isEnabled)
    handler.guiScene.createElementByObject(handler.scene, "gui/focusFrameAnim.blk", "tdiv", null)

  if (!::g_login.isLoggedIn() || handler instanceof ::gui_handlers.BaseGuiHandlerWT)
    return

  initVoiceChatWidget(handler)
}

handlersManager.initVoiceChatWidget <- function initVoiceChatWidget(handler)
{
  if (handler.rootHandlerClass || getHandlerType(handler) == handlerType.CUSTOM)
    return

  if (::g_login.isLoggedIn() && (handler?.needVoiceChat ?? true))
    handler.guiScene.createElementByObject(handler.scene, "gui/chat/voiceChatWidget.blk", "widgets", null)
}

handlersManager.validateHandlersAfterLoading <- function validateHandlersAfterLoading()
{
  clearInvalidHandlers()
  updateLoadingFlag()
  ::broadcastEvent("FinishLoading")
}

handlersManager.getRootScreenBlkPath <- function getRootScreenBlkPath() {
  return rootScreenBlkPathWatch.value
}

::get_cur_base_gui_handler <- function get_cur_base_gui_handler() //!!FIX ME: better to not use it at all. really no need to create instance of base handler without scene.
{
  local handler = ::handlersManager.getActiveBaseHandler()
  if (handler)
    return handler
  return ::gui_handlers.BaseGuiHandlerWT(::get_cur_gui_scene())
}

::gui_start_empty_screen <- function gui_start_empty_screen()
{
  ::handlersManager.emptyScreen()
  local guiScene = ::get_cur_gui_scene()
  if (guiScene)
    guiScene.clearDelayed() //delayed actions doesn't work in empty screen.
}

::is_low_width_screen <- function is_low_width_screen() //change this function simultaneously with isWide constant in css
{
  return ::handlersManager.currentFont.isLowWidthScreen()
}

::isInMenu <- function isInMenu()
{
  return !::is_in_loading_screen() && !::is_in_flight()
}

::gui_finish_loading <- function gui_finish_loading()
{
  ::handlersManager.validateHandlersAfterLoading()
}

::move_mouse_on_obj <- function move_mouse_on_obj(obj) { //it used in a lot of places, so leave it global
  if (obj?.isValid())
    obj.setMouseCursorOnObject()
}

::move_mouse_on_child <- function move_mouse_on_child(obj, idx = 0) { //it used in a lot of places, so leave it global
  if (::is_mouse_last_time_used() || !obj?.isValid() || obj.childrenCount() <= idx || idx < 0)
    return
  local child = obj.getChild(idx)
  if (!child.isValid())
    return
  child.scrollToView()
  child.setMouseCursorOnObject()
}

::move_mouse_on_child_by_value <- function move_mouse_on_child_by_value(obj) { //it used in a lot of places, so leave it global
  if (obj?.isValid())
    move_mouse_on_child(obj, obj.getValue())
}

::select_editbox <- function select_editbox(obj) {
  if (!obj?.isValid())
    return
  if (::is_mouse_last_time_used())
    obj.select()
  else
    obj.setMouseCursorOnObject()
}

local needDebug = ::getFromSettingsBlk("debug/debugGamepadCursor", false)
::get_cur_gui_scene()?.setGamepadCursorDebug(needDebug)

handlersManager.init()
