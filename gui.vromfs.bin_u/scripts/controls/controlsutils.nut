local time = require("scripts/time.nut")


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
  local preset = ""
  switch (type)
  {
    case "classic":
      preset = ::is_platform_ps4
      ? "default"
      : ::is_platform_xboxone
        ? "xboxone_simulator"
        : "keyboard"
      break
    case "shooter":
      preset = ::is_platform_ps4
      ? "dualshock4"
      : ::is_platform_xboxone
        ? "xboxone_ma"
        : "keyboard_shooter"
      break
    default:
      ::script_net_assert_once("wrong controls type", "Passed wrong controls type")
  }

  preset = ::g_controls_presets.parsePresetName(preset)
  preset = ::g_controls_presets.getHighestVersionPreset(preset)
  return preset
}