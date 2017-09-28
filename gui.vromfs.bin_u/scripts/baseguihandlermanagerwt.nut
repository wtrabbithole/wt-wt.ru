local colorCorrector = require_native("colorCorrector")
local fonts = require_native("fonts")
handlersManager[PERSISTENT_DATA_PARAMS].extend([ "curControlsAllowMask", "isCurSceneBgBlurred" ])

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
  [handlerType.MODAL]  = true,
  [handlerType.CUSTOM] = false,
}

function handlersManager::setIngameShortcutsActive(value)
{
  ::set_ingame_shortcuts_active(value)
}

function handlersManager::beforeClearScene(guiScene)
{
  local sh = ::min(0.75 * ::screen_width(), ::screen_height())
  if (lastScreenHeightForFont && lastScreenHeightForFont != sh)
    shouldResetFontsCache = true
  lastScreenHeightForFont = sh

  if (shouldResetFontsCache)
  {
    fonts.discardLoadedData()
    shouldResetFontsCache = false
  }
}

function handlersManager::onClearScene(guiScene)
{
  if (isMainGuiSceneActive()) //is_in_flight function not available before first loading screen
    lastInFlight = ::is_in_flight()

  if (guiScene.setCursorSizeMul) //compatibility with old exe
    guiScene.setCursorSizeMul(guiScene.calcString("@cursorSizeMul", null))
  if (guiScene.setPatternSizeMul) //compatibility with old exe
    guiScene.setPatternSizeMul(guiScene.calcString("@dp", null))

  ::broadcastEvent("GuiSceneCleared")
}

function handlersManager::isNeedFullReloadAfterClearScene()
{
  return !isMainGuiSceneActive()
}

function handlersManager::isNeedReloadSceneSpecific()
{
  return isMainGuiSceneActive() && lastInFlight != ::is_in_flight()
}

function handlersManager::beforeLoadHandler(hType)
{
  //clear main gui scene when load to battle or from battle
  if ((hType == handlerType.BASE || hType == handlerType.ROOT)
      && ::g_login.isLoggedIn()
      && lastGuiScene
      && lastGuiScene.isEqual(::get_main_gui_scene())
      && !isMainGuiSceneActive())
    clearScene(lastGuiScene)
}

function handlersManager::onBaseHandlerLoadFailed(handler)
{
  if (!::g_login.isLoggedIn()
      || handler.getclass() == ::gui_handlers.MainMenu
      || handler.getclass() == ::gui_handlers.FlightMenu
     )
    ::gui_start_logout()
  else if (::is_in_flight())
    ::gui_start_flight_menu()
  else
    ::gui_start_mainmenu()
}

function handlersManager::onSwitchBaseHandler()
{
  if (!::g_login.isLoggedIn())
    return
  local curHandler = getActiveBaseHandler()
  if (curHandler)
    ::set_last_gc_scene_if_exist(curHandler.scene)
}

function handlersManager::animatedSwitchScene(startFunc)
{
  ::switch_gui_scene(startFunc)
}

function handlersManager::updatePostLoadCss()
{
  local haveChanges = false

  local font = ::g_font.getCurrent()
  if (currentFont != font)
  {
    shouldResetFontsCache = true
    haveChanges = true
  }
  currentFont = font

  local cssStringPre = font.genCssString() + "\n" + generatePreLoadCssString()
  if (::get_dagui_pre_include_css_str() != cssStringPre)
  {
    ::set_dagui_pre_include_css_str(cssStringPre)
    haveChanges = true
  }

  ::set_dagui_pre_include_css("")

  local cssStringPost = generatePostLoadCssString()
  if (::get_dagui_post_include_css_str() != cssStringPost)
  {
    ::set_dagui_post_include_css_str(cssStringPost)
    haveChanges = true
  }

  if (::switch_show_console_buttons(::get_is_console_mode_enabled()))
    haveChanges = true

  return haveChanges
}

function handlersManager::generatePreLoadCssString()
{
  local safeareaMenu = ::g_option_menu_safearea.getValue()
  local safeareaHud  =
    ::is_platform_ps4 ? (1.0 - ::ps4_get_safe_area()) :
    !::g_login.isAuthorized() ? 0.0 :
    ::get_option_hud_screen_safe_area()
  local countriesCount = 7
  if (::g_login.isLoggedIn())
  {
    countriesCount = 0
    foreach(c in ::shopCountriesList)
      if (::is_country_visible(c))
        countriesCount++
  }

  local config = [
    { name = "target_pc",         value = ::is_platform_ps4 ? "no" : "yes" }
    { name = "_safearea_menu",    value = ::format("%.2f", safeareaMenu) }
    { name = "_safearea_hud",     value = ::format("%.2f", safeareaHud) }
    { name = "slotbarCountries",  value = countriesCount.tostring() }
  ]

  return generateCssString(config)
}


function handlersManager::generateColorConstantsConfig()
{
  if (!::g_login.isAuthorized())
    return []

  local cssConfig = []
  local standardColors = !::g_login.isLoggedIn() || !::isPlayerDedicatedSpectator()
  local theme = {
    squad = standardColors ? colorCorrector.TARGET_HUE_SQUAD : colorCorrector.TARGET_HUE_SPECTATOR_ALLY
    ally  = standardColors ? colorCorrector.TARGET_HUE_ALLY  : colorCorrector.TARGET_HUE_SPECTATOR_ALLY
    enemy = standardColors ? colorCorrector.TARGET_HUE_ENEMY : colorCorrector.TARGET_HUE_SPECTATOR_ENEMY
  }

  local config = [
    { style = "squad", baseColor = "3E9E2F", names = [ "mySquadColor", "hudColorSquad", "chatSenderMySquadColor", "chatTextSquadVoiceColor" ] }
    { style = "squad", baseColor = "C6FFBD", names = [ "chatTextSquadColor" ] }
    { style = "ally",  baseColor = "527AFF", names = [ "teamBlueColor", "hudColorBlue", "chatSenderFriendColor", "chatTextTeamVoiceColor" ] }
    { style = "ally",  baseColor = "99B1FF", names = [ "teamBlueLightColor", "hudColorDeathEnemy" ] }
    { style = "ally",  baseColor = "5C637A", names = [ "teamBlueInactiveColor", "hudColorDarkBlue" ] }
    { style = "ally",  baseColor = "0F1834", names = [ "teamBlueDarkColor" ] }
    { style = "ally",  baseColor = "BDCCFF", names = [ "chatTextTeamColor" ] }
    { style = "enemy", baseColor = "FF5A52", names = [ "teamRedColor", "hudColorRed", "chatSenderEnemyColor", "chatTextEnemyVoiceColor" ] }
    { style = "enemy", baseColor = "FFA29D", names = [ "teamRedLightColor", "hudColorDeathAlly" ] }
    { style = "enemy", baseColor = "7C5F5D", names = [ "teamRedInactiveColor", "hudColorDarkRed" ] }
    { style = "enemy", baseColor = "34110F", names = [ "teamRedDarkColor" ] }
  ]

  foreach (cfg in config)
  {
    local color = colorCorrector.correctHueTarget(cfg.baseColor, theme[cfg.style])

    foreach (name in cfg.names)
      cssConfig.append({
        name = name,
        value = "#" + color
      })
  }

  return cssConfig
}


function handlersManager::generatePostLoadCssString()
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


function handlersManager::generateCssString(config)
{
  local css = []
  foreach (cfg in config)
    css.append(::format("@const %s:%s", cfg.name, cfg.value))

  return ::g_string.implode(css, ";")
}

function handlersManager::getHandlerControlsAllowMask(handler)
{
  local res = null
  if ("getControlsAllowMask" in handler)
    res = handler.getControlsAllowMask()
  if (res != null)
    return res
  return ::getTblValue(handler.wndType, controlsAllowMaskDefaults, CtrlsInGui.CTRL_ALLOW_FULL)
}

function handlersManager::calcCurrentControlsAllowMask()
{
  if (::check_obj(::current_wait_screen))
    return CtrlsInGui.CTRL_ALLOW_NONE
  if (::is_active_msg_box_in_scene(::get_cur_gui_scene()))
    return CtrlsInGui.CTRL_ALLOW_NONE

  local res = CtrlsInGui.CTRL_ALLOW_FULL
  foreach(group in handlers)
    foreach(h in group)
      if (isHandlerValid(h, true) && h.isSceneActive())
        res = res & getHandlerControlsAllowMask(h)

  foreach(name in ["menu_chat_handler", "contacts_handler", "game_chat_handler"])
    if (name in ::getroottable() && ::getroottable()[name])
      res = res & ::getroottable()[name].getControlsAllowMask()

  return res
}

function handlersManager::updateControlsAllowMask()
{
  if (!_loadHandlerRecursionLevel)
    _updateControlsAllowMask()
}

function handlersManager::_updateControlsAllowMask()
{
  local newMask = calcCurrentControlsAllowMask()
  if (newMask == curControlsAllowMask)
    return

  curControlsAllowMask = newMask
  ::set_allowed_controls_mask(curControlsAllowMask)
  //dlog(::format("GP: controls changed to 0x%X", curControlsAllowMask))
}

function handlersManager::calcCurrentSceneBgBlur()
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

function handlersManager::updateSceneBgBlur(forced = false)
{
  if (!_loadHandlerRecursionLevel)
    _updateSceneBgBlur(forced)
}

function handlersManager::_updateSceneBgBlur(forced = false)
{
  local isBlur = calcCurrentSceneBgBlur()
  if (!forced && isBlur == isCurSceneBgBlurred)
    return

  isCurSceneBgBlurred = isBlur
  ::hangar_blur(isCurSceneBgBlurred)
}

function handlersManager::onActiveHandlersChanged()
{
  _updateControlsAllowMask()
  _updateSceneBgBlur()
  ::broadcastEvent("ActiveHandlersChanged")
}

function handlersManager::onEventWaitBoxCreated(p)
{
  _updateControlsAllowMask()
  _updateSceneBgBlur()
}

function get_cur_base_gui_handler() //!!FIX ME: better to not use it at all. really no need to create instance of base handler without scene.
{
  local handler = ::handlersManager.getActiveBaseHandler()
  if (handler)
    return handler
  return ::gui_handlers.BaseGuiHandlerWT(::get_cur_gui_scene())
}

function gui_start_empty_screen()
{
  ::handlersManager.emptyScreen()
  local guiScene = ::get_cur_gui_scene()
  if (guiScene)
    guiScene.clearDelayed() //delayed actions doesn't work in empty screen.
}

function is_low_width_screen() //change this function simultaneously with isWide constant in css
{
  return ::handlersManager.currentFont.isLowWidthScreen(::screen_width(), ::screen_height())
}

function isInMenu()
{
  return !::is_in_loading_screen() && !::is_in_flight()
}

handlersManager.init()
