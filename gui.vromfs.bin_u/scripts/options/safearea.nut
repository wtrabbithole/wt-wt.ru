::g_option_menu_safearea <- {
  defValue  = 0.0
  values    = [ 0.0, 0.05, 0.1 ]
  items     = ["#options/no", "5%", "10%"]

  getFixedValue = function() //return -1 when not fixed
  {
    if (::is_platform_ps4)
      return 1.0 - ::ps4_get_safe_area()
    if (::is_low_width_screen())
      return 0.0
    return -1
  }

  canChangeValue = function()
  {
    return getFixedValue() == -1
  }

  getValue = function()
  {
    local value = getFixedValue()
    if (value != -1)
      return value

    local value = !::g_login.isAuthorized() ?
      ::to_float_safe(::getSystemConfigOption("video/safearea", defValue), defValue) :
      ::get_gui_option_in_mode(::USEROPT_MENU_SCREEN_SAFE_AREA, ::OPTIONS_MODE_GAMEPLAY, defValue)
    return ::isInArray(value, values) ? value : defValue
  }

  setValue = function(value)
  {
    if (!::g_login.isAuthorized())
      return
    value = ::isInArray(value, values) ? value : defValue
    ::setSystemConfigOption("video/safearea", value == defValue ? null : value)
    ::set_gui_option_in_mode(::USEROPT_MENU_SCREEN_SAFE_AREA, value, ::OPTIONS_MODE_GAMEPLAY)
  }

  getConfig = function()
  {
    return {
      values    = clone values
      items     = clone items
      defValue  = defValue
      value     = getValue()
    }
  }

  isEnabled = function()
  {
    return getValue() != defValue
  }
}
