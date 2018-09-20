local time = require("scripts/time.nut")

::classic_control_preset <- "classic"
::shooter_control_preset <- "shooter"
::thrustmaster_hotas_one_preset_type <- "thrustmaster_hotas_one"

::recomended_control_presets <- [
  ::classic_control_preset
  ::shooter_control_preset
]

if (::is_platform_xboxone)
  ::recomended_control_presets.append(::thrustmaster_hotas_one_preset_type)

function on_connected_controller()
{
  //calls from c++ code, no event on PS4 or XBoxOne
  if (!::isInMenu())
    return
  local action = function() { ::gui_start_controls_type_choice() }
  local buttons = [{
      id = "change_preset",
      text = ::loc("msgbox/btn_yes"),
      func = action
    },
    { id = "cancel",
      text = ::loc("msgbox/btn_no"),
      func = null
    }]

  ::g_popups.add(
    ::loc("popup/newcontroller"),
    ::loc("popup/newcontroller/message"),
    action,
    buttons,
    null,
    null,
    time.secondsToMilliseconds(time.minutesToSeconds(10))
  )
}

function get_controls_preset_by_selected_type(type = "")
{
  local presets = ::is_platform_ps4 ? {
    [::classic_control_preset] = "default",
    [::shooter_control_preset] = "dualshock4"
  } : ::is_platform_xboxone ? {
    [::classic_control_preset] = "xboxone_simulator",
    [::shooter_control_preset] = "xboxone_ma",
    [::thrustmaster_hotas_one_preset_type] = "xboxone_thrustmaster_hotas_one"
  } : {
    [::classic_control_preset] = "keyboard",
    [::shooter_control_preset] = "keyboard_shooter"
  }

  local preset = ""
  if (type in presets) {
    preset = presets[type]
  } else {
    ::script_net_assert_once("wrong controls type", "Passed wrong controls type")
  }

  preset = ::g_controls_presets.parsePresetName(preset)
  preset = ::g_controls_presets.getHighestVersionPreset(preset)
  return preset
}