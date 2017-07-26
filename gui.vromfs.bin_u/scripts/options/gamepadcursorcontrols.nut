const GAMEPAD_CURSOR_CONTROL_CONFIG_NAME = "use_gamepad_cursor_control"
const IS_GAMEPAD_CURSOR_ENABLED_DEFAULT = true

::g_gamepad_cursor_controls <- {
  currentOptionValue = IS_GAMEPAD_CURSOR_ENABLED_DEFAULT


  function init()
  {
    currentOptionValue = ::getSystemConfigOption(GAMEPAD_CURSOR_CONTROL_CONFIG_NAME, IS_GAMEPAD_CURSOR_ENABLED_DEFAULT)
    ::set_use_gamepad_cursor_control(currentOptionValue)
  }


  function setValue(newValue)
  {
    if (currentOptionValue == newValue)
      return
    ::set_use_gamepad_cursor_control(newValue)
    if (::g_login.isProfileReceived())
      ::set_gui_option_in_mode(
        ::USEROPT_GAMEPAD_CURSOR_CONTROLLER,
        newValue,
        ::OPTIONS_MODE_GAMEPLAY
      )
    currentOptionValue = newValue
    ::setSystemConfigOption(GAMEPAD_CURSOR_CONTROL_CONFIG_NAME, currentOptionValue)
    ::handlersManager.checkPostLoadCssOnBackToBaseHandler()
  }


  function getValue()
  {
    if (!::g_login.isProfileReceived())
      return ::getSystemConfigOption(GAMEPAD_CURSOR_CONTROL_CONFIG_NAME, IS_GAMEPAD_CURSOR_ENABLED_DEFAULT)
    if (canChangeValue())
      return ::get_gui_option_in_mode(
        ::USEROPT_GAMEPAD_CURSOR_CONTROLLER,
        ::OPTIONS_MODE_GAMEPLAY,
        false
      )
    return false
  }


  function canChangeValue()
  {
    return ::has_feature("GamepadCursorControl")
  }


  function onEventProfileUpdated(p)
  {
    setValue(getValue())
  }
}

::subscribe_handler(::g_gamepad_cursor_controls, ::g_listener_priority.CONFIG_VALIDATION)

::g_gamepad_cursor_controls.init()
