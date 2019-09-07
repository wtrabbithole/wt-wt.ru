local time = require("scripts/time.nut")
local controllerState = require_native("controllerState")

::classic_control_preset <- "classic"
::shooter_control_preset <- "shooter"
::thrustmaster_hotas_one_preset_type <- "thrustmaster_hotas_one"

::recomended_control_presets <- [
  ::classic_control_preset
  ::shooter_control_preset
]

if (::is_platform_xboxone)
  ::recomended_control_presets.append(::thrustmaster_hotas_one_preset_type)

::g_controls_utils <- {
  [PERSISTENT_DATA_PARAMS] = ["eventHandler"]
  eventHandler = null
}

::g_script_reloader.registerPersistentDataFromRoot("g_controls_utils")

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

local is_keyboard_or_mouse_connected_before = false

local on_controller_event = function()
{
  local is_keyboard_or_mouse_connected = controllerState.is_keyboard_connected()
    || controllerState.is_mouse_connected()
  if (is_keyboard_or_mouse_connected_before == is_keyboard_or_mouse_connected)
    return
  is_keyboard_or_mouse_connected_before = is_keyboard_or_mouse_connected;
  if (!is_keyboard_or_mouse_connected || !::isInMenu())
    return
  local action = function() { ::gui_modal_controlsWizard() }
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
    ::loc("popup/keyboard_or_mouse_connected"),
    ::loc("popup/keyboard_or_mouse_connected/message"),
    action,
    buttons,
    null,
    null,
    time.secondsToMilliseconds(time.minutesToSeconds(10))
  )
}

if (::g_controls_utils.eventHandler && controllerState?.remove_event_handler)
  controllerState.remove_event_handler(::g_controls_utils.eventHandler)

::g_controls_utils.eventHandler = on_controller_event
if (controllerState?.add_event_handler)
  controllerState.add_event_handler(::g_controls_utils.eventHandler)

function get_controls_preset_by_selected_type(cType = "")
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
  if (cType in presets) {
    preset = presets[cType]
  } else {
    ::script_net_assert_once("wrong controls type", "Passed wrong controls type")
  }

  preset = ::g_controls_presets.parsePresetName(preset)
  preset = ::g_controls_presets.getHighestVersionPreset(preset)
  return preset
}