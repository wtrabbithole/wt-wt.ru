local defValue  = 1.0
local values    = [1.0, 0.95, 0.9, 0.85]
local items     = ["#options/no", "5%", "10%", "15%"]
local correctValues = ::is_version_equals_or_newer("1.71.2.18")

local getFixedValue = function() //return -1 when not fixed
{
  if (::is_platform_ps4)
    return ::ps4_get_safe_area()
  if (::is_platform_xboxone)
    return ::xbox_get_safe_area()
  return -1
}

local checkCompatibility = function() //Added on 1_71_2_X, can be removed after new version.
{
  local value = getValue()
  setValue(value < 0.5? 1 - value : value)
}

local getValue = function()
{
  local value = getFixedValue()
  if (value != -1)
    return value

  if (!::g_login.isAuthorized())
    return defValue

  local res = ::get_option_hud_screen_safe_area()
  return correctValues ? res : 1.0 - res
}

local setValue = function(value)
{
  if (!::g_login.isAuthorized())
    return

  value = ::isInArray(value, values) ? value : defValue
  if (!correctValues)
    value = 1 - value
  ::set_option_hud_screen_safe_area(value)
  ::set_gui_option_in_mode(::USEROPT_HUD_SCREEN_SAFE_AREA, value, ::OPTIONS_MODE_GAMEPLAY)
}

return {
  getValue = getValue
  setValue = setValue
  canChangeValue = @() getFixedValue() == -1
  getValueOptionIndex = @() values.find(getValue())
  checkCompatibility = checkCompatibility

  values = values
  items = items
  defValue = defValue
}