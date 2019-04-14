local defValue  = 1.0
local values    = [ 1.0, 0.95, 0.9 ]
local items     = ["#options/no", "5%", "10%"]

local getFixedValue = function() //return -1 when not fixed
{
  if (::is_platform_ps4)
    return ::ps4_get_safe_area()
  if (::is_platform_xboxone)
    return ::xbox_get_safe_area()
  if (::is_low_width_screen())
    return 1.0
  return -1
}

local compatibleGetValue = function()
{
  local value = !::g_login.isAuthorized() ?
    ::to_float_safe(::getSystemConfigOption("video/safearea", defValue), defValue) :
    ::get_gui_option_in_mode(::USEROPT_MENU_SCREEN_SAFE_AREA, ::OPTIONS_MODE_GAMEPLAY, defValue)

  if (value < 0.5)
    return 1 - value
  return value
}

local getValue = function()
{
  local value = getFixedValue()
  if (value != -1)
    return value

  value = compatibleGetValue()
  return ::isInArray(value, values) ? value : defValue
}

local setValue = function(value)
{
  if (!::g_login.isAuthorized())
    return

  value = ::isInArray(value, values) ? value : defValue
  ::setSystemConfigOption("video/safearea", value == defValue ? null : value)
  ::set_gui_option_in_mode(::USEROPT_MENU_SCREEN_SAFE_AREA, value, ::OPTIONS_MODE_GAMEPLAY)
}

local getValueOptionIndex = @() values.find(getValue())

local canChangeValue = @() getFixedValue() == -1

local export = {
  getValue = getValue
  setValue = setValue
  canChangeValue = canChangeValue
  getValueOptionIndex = getValueOptionIndex

  values = values
  items = items
  defValue = defValue
}

return export