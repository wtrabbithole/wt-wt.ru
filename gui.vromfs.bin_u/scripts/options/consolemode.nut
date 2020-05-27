::get_is_console_mode_force_enabled <- function get_is_console_mode_force_enabled()
{
  return ::is_ps4_or_xbox
         || ::is_platform_android
         || ::is_platform_shield_tv()
         || ::is_steam_big_picture()
}

::get_is_console_mode_enabled <- function get_is_console_mode_enabled()
{
  if (::get_is_console_mode_force_enabled())
    return true

  if (::g_login.isProfileReceived())
    return ::get_gui_option_in_mode(::USEROPT_ENABLE_CONSOLE_MODE, ::OPTIONS_MODE_GAMEPLAY, false)

  return ::getSystemConfigOption("use_gamepad_interface", false)
}

::switch_show_console_buttons <- function switch_show_console_buttons(showCB)
{
  if (::get_is_console_mode_force_enabled() && !showCB)
    return false
  if (showCB == ::show_console_buttons)
    return false

  ::show_console_buttons = showCB
  ::call_darg("updateExtWatched", { showConsoleButtons = showCB })
  if (!::g_login.isProfileReceived())
    return true

  ::set_gui_option_in_mode(::USEROPT_ENABLE_CONSOLE_MODE, showCB, ::OPTIONS_MODE_GAMEPLAY)
  ::setSystemConfigOption("use_gamepad_interface", showCB)
  ::handlersManager.markfullReloadOnSwitchScene()
  return true
}

::cross_call_api.isConsoleModeEnabled <- @() ::get_is_console_mode_enabled()
