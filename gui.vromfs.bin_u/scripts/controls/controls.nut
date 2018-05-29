local gamepadIcons = require("scripts/controls/gamepadIcons.nut")
local stdMath = require("math")
local globalEnv = require_native("globalEnv")

::MAX_SHORTCUTS <- 3
::preset_changed <- false
::ps4ControlsModeActivatedParamName <- "ps4ControlsAdvancedModeActivated"
::hotas4_device_id <- "044F:B67B"

/*  filter = ::USEROPT_HELPERS_MODE
  globalEnv.EM_MOUSE_AIM,
  globalEnv.EM_INSTRUCTOR,
  globalEnv.EM_REALISTIC,
  globalEnv.EM_FULL_REAL
*/

function isExperimentalCameraTrack()
{
  return get_settings_blk().debug && get_settings_blk().debug.experimentalCameraTrack;
}

function get_favorite_voice_message_option(index)
{
  assert(index >= 1 && index <= NUM_FAST_VOICE_MESSAGES);
  return { id = "favorite_voice_message_" + index, type = CONTROL_TYPE.SPINNER
      options = get_favorite_voice_messages_variants()
      value = (@(index) function(joyParams) { return ::get_option_favorite_voice_message(index - 1) + 1 })(index)
      setValue = (@(index) function(joyParams, objValue) { ::set_option_favorite_voice_message(index - 1, objValue - 1); })(index)
    }
}

::shortcuts_not_change_by_preset <- [
  "ID_INTERNET_RADIO", "ID_INTERNET_RADIO_PREV", "ID_INTERNET_RADIO_NEXT",
  "ID_PTT"
]


::shortcutsList <- [
  { id = "helpers_mode", type = CONTROL_TYPE.LISTBOX
    optionType = ::USEROPT_HELPERS_MODE
    onChangeValue = "onOptionsFilter"
    isFilterObj = true
  }

  { id = "ID_PLANE_CONTROL_HEADER"
    type = CONTROL_TYPE.HEADER
    unitType = ::g_unit_type.AIRCRAFT
    isHelpersVisible = true }
  { id = "ID_PLANE_MODE_HEADER", type = CONTROL_TYPE.SECTION }
    { id="mouse_usage", type = CONTROL_TYPE.SPINNER
      optionType = ::USEROPT_MOUSE_USAGE
      onChangeValue = "onAircraftHelpersChanged"
    }
    { id="mouse_usage_no_aim", type = CONTROL_TYPE.SPINNER
      showFunc = @() ::has_feature("SimulatorDifficulty") && (getMouseUsageMask() & AIR_MOUSE_USAGE.AIM)
      optionType = ::USEROPT_MOUSE_USAGE_NO_AIM
      onChangeValue = "onAircraftHelpersChanged"
    }
    { id="instructor_enabled", type = CONTROL_TYPE.SWITCH_BOX
      optionType = ::USEROPT_INSTRUCTOR_ENABLED
      onChangeValue = "onAircraftHelpersChanged"
    }
    { id="autotrim", type = CONTROL_TYPE.SWITCH_BOX
      filterHide = [globalEnv.EM_MOUSE_AIM, globalEnv.EM_INSTRUCTOR]
      optionType = ::USEROPT_AUTOTRIM
      onChangeValue = "onAircraftHelpersChanged"
    }
    { id="ID_TOGGLE_INSTRUCTOR"
      checkAssign = false
    }

  { id = "ID_PLANE_FIRE_HEADER", type = CONTROL_TYPE.SECTION }
    { id = "ID_FIRE_MGUNS", autobind = ["ID_FIRE_CANNONS", "ID_FIRE_GM"]
      autobind_sc = @() ::is_xinput_device() ? [{btn = [17], dev = [3]} /* R2 */] : null
    }
    { id = "ID_FIRE_CANNONS", autobind = ["ID_FIRE_MGUNS", "ID_FIRE_GM"]
      autobind_sc = @() ::is_xinput_device() ? [{btn = [17], dev = [3]} /* R2 */] : null
    }
    { id = "ID_FIRE_ADDITIONAL_GUNS", autobind = ["ID_FIRE_CANNONS", "ID_FIRE_MGUNS", "ID_FIRE_GM"]
      autobind_sc = @() ::is_xinput_device() ? [{btn = [17], dev = [3]} /* R2 */] : null
    }
    { id = "fire", type = CONTROL_TYPE.AXIS, checkAssign = false }
    { id = "ID_BAY_DOOR", checkAssign = false }
    "ID_BOMBS"
    { id = "ID_BOMBS_SERIES", checkAssign = false }
    "ID_ROCKETS",
    { id = "ID_FUEL_TANKS",
      showFunc = @() ::has_feature("Payload"),
      checkAssign = false
    }
    { id = "ID_AIR_DROP",
      showFunc = @() ::has_feature("Payload"),
      checkAssign = false
    }
    { id = "ID_WEAPON_LOCK",
      showFunc = @() ::has_feature("Missiles"),
      checkAssign = false
    }
    { id = "ID_SENSOR_SWITCH"
      showFunc = @() ::has_feature("Sensors")
      checkAssign = false
    }
    { id = "ID_SENSOR_MODE_SWITCH"
      showFunc = @() ::has_feature("Sensors")
      checkAssign = false
    }
    { id = "ID_SENSOR_SCAN_PATTERN_SWITCH"
      showFunc = @() ::has_feature("Sensors")
      checkAssign = false
    }
    { id = "ID_SENSOR_RANGE_SWITCH"
      showFunc = @() ::has_feature("Sensors")
      checkAssign = false
    }
    { id = "ID_SENSOR_TARGET_LOCK"
      showFunc = @() ::has_feature("Sensors")
      checkAssign = false
    }
    { id = "sensor_designation_x"
      type = CONTROL_TYPE.AXIS
      showFunc = @() ::has_feature("Sensors")
      checkAssign = false
    }
    { id = "sensor_designation_y"
      type = CONTROL_TYPE.AXIS
      showFunc = @() ::has_feature("Sensors")
      checkAssign = false
    }
    { id = "sensor_designation_z"
      type = CONTROL_TYPE.AXIS
      showFunc = @() ::has_feature("Sensors")
      checkAssign = false
    }
    { id="ID_SCHRAEGE_MUSIK", checkAssign = false }
    { id="ID_RELOAD_GUNS", checkAssign = false, autobind = ["ID_REPAIR_TANK"] }

  { id = "ID_PLANE_AXES_HEADER", type = CONTROL_TYPE.SECTION }
    { id = "mouse_z", type = CONTROL_TYPE.MOUSE_AXIS
      axis_num = MouseAxis.MOUSE_SCROLL
      values = ["none", "throttle", "zoom", /*"elevator",*/ "camy", /* "weapon"*/]
      onChangeValue = "onMouseWheel"
      showFunc = @() !::is_platform_xboxone
    }
/*    { id = "mouse_x", type = CONTROL_TYPE.MOUSE_AXIS
      filterHide = [globalEnv.EM_MOUSE_AIM]
//      showFunc = @() checkOptionValue("mouse_joystick", 1)
      axis_num = MouseAxis.MOUSE_X
      values = ["none", "ailerons", "rudder", "camx"]
    }
    { id = "mouse_y", type = CONTROL_TYPE.MOUSE_AXIS
      filterHide = [globalEnv.EM_MOUSE_AIM]
      axis_num = MouseAxis.MOUSE_Y
      values = ["none", "elevator", "camy"]
    }*/
    { id="throttle", type = CONTROL_TYPE.AXIS, def_relative = true }
    { id="holdThrottleForWEP", type = CONTROL_TYPE.SWITCH_BOX,
      value = @(joyParams) joyParams.holdThrottleForWEP
      setValue = function(joyParams, objValue) {
        local old  = joyParams.holdThrottleForWEP
        joyParams.holdThrottleForWEP = objValue
        if (objValue != old)
          ::set_controls_preset("");
      }
    }
    { id="ailerons", type = CONTROL_TYPE.AXIS, reqInMouseAim = false
      hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    }
    { id="elevator", type = CONTROL_TYPE.AXIS, reqInMouseAim = false
      hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    }
    { id="rudder", type = CONTROL_TYPE.AXIS, reqInMouseAim = false
//      hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    }
    { id="roll_sens", type = CONTROL_TYPE.SLIDER
      filterHide = [globalEnv.EM_MOUSE_AIM]
      optionType = ::USEROPT_AILERONS_MULTIPLIER
    }
    { id="pitch_sens", type = CONTROL_TYPE.SLIDER
      filterHide = [globalEnv.EM_MOUSE_AIM]
      optionType = ::USEROPT_ELEVATOR_MULTIPLIER
    }
    { id="yaw_sens", type = CONTROL_TYPE.SLIDER
      filterHide = [globalEnv.EM_MOUSE_AIM]
      optionType = ::USEROPT_RUDDER_MULTIPLIER
    }
    { id="invert_y", type = CONTROL_TYPE.SWITCH_BOX
      optionType = ::USEROPT_INVERTY
      onChangeValue = "doControlsGroupChangeDelayed"
    }
    { id="invert_x", type = CONTROL_TYPE.SPINNER
      filterHide = [globalEnv.EM_INSTRUCTOR, globalEnv.EM_REALISTIC, globalEnv.EM_FULL_REAL]
      optionType = ::USEROPT_INVERTX
      showFunc = @() checkOptionValue("invert_y", true)
    }
    { id="multiplier_force_gain", type = CONTROL_TYPE.SLIDER
      filterHide = [globalEnv.EM_MOUSE_AIM]
      optionType = ::USEROPT_FORCE_GAIN
    }
  { id = "ID_PLANE_MECHANIZATION_HEADER", type = CONTROL_TYPE.SECTION }
    { id="ID_IGNITE_BOOSTERS", reqInMouseAim = false, checkAssign = false }
    { id="ID_FLAPS", reqInMouseAim = false }
    { id="ID_FLAPS_DOWN", reqInMouseAim = false }
    { id="ID_FLAPS_UP", reqInMouseAim = false }
    { id="ID_AIR_BRAKE", reqInMouseAim = false }
    "ID_GEAR"
    { id="brake_left",   type = CONTROL_TYPE.AXIS, checkAssign = false, filterShow = [globalEnv.EM_REALISTIC, globalEnv.EM_FULL_REAL] }
    { id="brake_right",  type = CONTROL_TYPE.AXIS, checkAssign = false, filterShow = [globalEnv.EM_REALISTIC, globalEnv.EM_FULL_REAL] }

  { id = "ID_PLANE_GUNNERS_HEADER", type = CONTROL_TYPE.SECTION }
    { id="ID_TOGGLE_GUNNERS", checkAssign = false }
    { id="turret_x", type = CONTROL_TYPE.AXIS, filterHide = [globalEnv.EM_MOUSE_AIM] }
    { id="turret_y", type = CONTROL_TYPE.AXIS, filterHide = [globalEnv.EM_MOUSE_AIM] }
    { id="gunner_view_sens", type = CONTROL_TYPE.SLIDER
      optionType = ::USEROPT_GUNNER_VIEW_SENSE
      filterHide = [globalEnv.EM_MOUSE_AIM]
    }
    { id = "gunner_joy_speed", type = CONTROL_TYPE.SLIDER
      value = @(joyParams) 100.0*(::get_option_multiplier(::OPTION_CAMERA_SPEED) - min_camera_speed) / (max_camera_speed - min_camera_speed)
      setValue = @(joyParams, objValue) ::set_option_multiplier(::OPTION_CAMERA_SPEED, min_camera_speed + (objValue / 100.0) * (max_camera_speed - min_camera_speed))
      filterHide = [globalEnv.EM_MOUSE_AIM]
    }
    { id="invert_y_gunner", type = CONTROL_TYPE.SWITCH_BOX
      optionType = ::USEROPT_GUNNER_INVERTY
    }

  { id = "ID_PLANE_VIEW_HEADER", type = CONTROL_TYPE.SECTION }
    { id="ID_TOGGLE_VIEW",          autobind = ["ID_TOGGLE_VIEW_GM"] }
    { id="ID_CAMERA_FPS",           checkAssign = false }
    { id="ID_CAMERA_TPS",           checkAssign = false }
    { id="ID_CAMERA_VIRTUAL_FPS",   checkAssign = false }
    { id="ID_CAMERA_DEFAULT",       checkAssign = false }
    { id="ID_CAMERA_GUNNER",        checkAssign = false }
    { id="ID_CAMERA_BOMBVIEW",      checkAssign = false }
    { id="ID_CAMERA_FOLLOW_OBJECT", checkAssign = false }
    { id="ID_TARGET_CAMERA",        checkAssign = false }
    { id="ID_AIM_CAMERA",           checkAssign = false, condition = @() ::is_ps4_or_xbox }
    { id="target_camera"
      type = CONTROL_TYPE.AXIS
      checkAssign = false
      condition = @() ::is_ps4_or_xbox
      hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    }
    { id="ID_CAMERA_VIEW_DOWN", checkAssign = false }
    { id="ID_CAMERA_VIEW_BACK", checkAssign = false }
    { id = "invert_y_camera"
      type = CONTROL_TYPE.SWITCH_BOX
      optionType = ::USEROPT_INVERTCAMERAY
    }
    { id="zoom", type = CONTROL_TYPE.AXIS, checkAssign = false }
    { id="camx",         type = CONTROL_TYPE.AXIS, reqInMouseAim = false }
    { id="camy",         type = CONTROL_TYPE.AXIS, reqInMouseAim = false }
    { id="head_pos_x", type = CONTROL_TYPE.AXIS, checkAssign = false, dontCheckDupes = true }
    { id="head_pos_y", type = CONTROL_TYPE.AXIS, checkAssign = false, dontCheckDupes = true }
    { id="head_pos_z", type = CONTROL_TYPE.AXIS, checkAssign = false, dontCheckDupes = true }
    { id="fps_camera_physics", type = CONTROL_TYPE.SLIDER
      optionType = ::USEROPT_FPS_CAMERA_PHYSICS
    }

  { id = "ID_PLANE_OTHER_HEADER", type = CONTROL_TYPE.SECTION }
    { id="ID_AEROBATICS_SMOKE",  checkAssign = false }
    { id="ID_TOGGLE_COCKPIT_DOOR", checkAssign = false }
    { id="ID_TOGGLE_COCKPIT_LIGHTS", checkAssign = false }
    { id="ID_TOGGLE_COLLIMATOR",    filterShow = [globalEnv.EM_FULL_REAL] }

  { id = "ID_INSTRUCTOR_HEADER", type = CONTROL_TYPE.SECTION
    filterShow = [globalEnv.EM_MOUSE_AIM, globalEnv.EM_INSTRUCTOR]
  }
    { id="instructor_ground_avoidance", type = CONTROL_TYPE.SWITCH_BOX
      filterShow = [globalEnv.EM_MOUSE_AIM, globalEnv.EM_INSTRUCTOR]
      optionType = ::USEROPT_INSTRUCTOR_GROUND_AVOIDANCE
    }
    { id="instructor_gear_control", type = CONTROL_TYPE.SWITCH_BOX
      filterShow = [globalEnv.EM_MOUSE_AIM, globalEnv.EM_INSTRUCTOR]
      optionType = ::USEROPT_INSTRUCTOR_GEAR_CONTROL
    }
    { id="instructor_flaps_control", type = CONTROL_TYPE.SWITCH_BOX
      filterShow = [globalEnv.EM_MOUSE_AIM, globalEnv.EM_INSTRUCTOR]
      optionType = ::USEROPT_INSTRUCTOR_FLAPS_CONTROL
    }
    { id="instructor_engine_control", type = CONTROL_TYPE.SWITCH_BOX
      filterShow = [globalEnv.EM_MOUSE_AIM, globalEnv.EM_INSTRUCTOR]
      optionType = ::USEROPT_INSTRUCTOR_ENGINE_CONTROL
    }
    { id="instructor_simple_joy", type = CONTROL_TYPE.SWITCH_BOX
      filterShow = [globalEnv.EM_INSTRUCTOR]
      optionType = ::USEROPT_INSTRUCTOR_SIMPLE_JOY
    }

  { id = "ID_PLANE_MOUSE_AIM_HEADER", type = CONTROL_TYPE.SECTION }
    { id="mouse_aim_x", type = CONTROL_TYPE.AXIS
      filterHide = [globalEnv.EM_INSTRUCTOR, globalEnv.EM_REALISTIC, globalEnv.EM_FULL_REAL]
      hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    }
    { id="mouse_aim_y", type = CONTROL_TYPE.AXIS
      filterHide = [globalEnv.EM_INSTRUCTOR, globalEnv.EM_REALISTIC, globalEnv.EM_FULL_REAL]
      hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    }
    { id="mouse_smooth", type = CONTROL_TYPE.SWITCH_BOX
      optionType = ::USEROPT_MOUSE_SMOOTH
      showFunc = @() !::is_platform_xboxone
    }
    { id = "aim_time_nonlinearity_air", type = CONTROL_TYPE.SLIDER
      value = @(joyParams) 100.0 * ::get_option_multiplier(::OPTION_AIM_TIME_NONLINEARITY_AIR)
      setValue = @(joyParams, objValue)
        ::set_option_multiplier(::OPTION_AIM_TIME_NONLINEARITY_AIR, objValue / 100.0)
    }
    { id = "aim_acceleration_delay_air", type = CONTROL_TYPE.SLIDER
      value = @(joyParams) 100.0 * ::get_option_multiplier(::OPTION_AIM_ACCELERATION_DELAY_AIR)
      setValue = @(joyParams, objValue)
        ::set_option_multiplier(::OPTION_AIM_ACCELERATION_DELAY_AIR, objValue / 100.0)
    }
    { id="joy_camera_sensitivity", type = CONTROL_TYPE.SLIDER
      optionType = ::USEROPT_MOUSE_AIM_SENSE
    }

  { id = "ID_PLANE_JOYSTICK_HEADER"
    type = CONTROL_TYPE.SECTION
    filterHide = [globalEnv.EM_MOUSE_AIM]
    showFunc = @() getMouseUsageMask() & (AIR_MOUSE_USAGE.JOYSTICK | AIR_MOUSE_USAGE.RELATIVE)
  }
    { id = "mouse_joystick_mode", type = CONTROL_TYPE.SPINNER,
      filterHide = [globalEnv.EM_MOUSE_AIM],
      options = ["#options/mouse_joy_mode_simple", "#options/mouse_joy_mode_standard"],
      showFunc = @() getMouseUsageMask() & AIR_MOUSE_USAGE.JOYSTICK
      value = @(joyParams) ::get_option_int(::OPTION_MOUSE_JOYSTICK_MODE)
      setValue = @(joyParams, objValue) ::set_option_int(::OPTION_MOUSE_JOYSTICK_MODE, objValue)
    }
    { id = "mouse_joystick_sensitivity", type = CONTROL_TYPE.SLIDER
      filterHide = [globalEnv.EM_MOUSE_AIM]
      showFunc = @() getMouseUsageMask() & AIR_MOUSE_USAGE.JOYSTICK
      value = @(joyParams)
        100.0*(::get_option_multiplier(::OPTION_MOUSE_JOYSTICK_SENSITIVITY) - ::minMouseJoystickSensitivity) /
          (::maxMouseJoystickSensitivity - ::minMouseJoystickSensitivity)
      setValue = @(joyParams, objValue)
        ::set_option_multiplier(::OPTION_MOUSE_JOYSTICK_SENSITIVITY, ::minMouseJoystickSensitivity + (objValue / 100.0) *
          (::maxMouseJoystickSensitivity - ::minMouseJoystickSensitivity))
    }
    { id = "mouse_joystick_deadzone", type = CONTROL_TYPE.SLIDER
      filterHide = [globalEnv.EM_MOUSE_AIM]
      showFunc = @() getMouseUsageMask() & AIR_MOUSE_USAGE.JOYSTICK
      value = @(joyParams) 100.0*::get_option_multiplier(::OPTION_MOUSE_JOYSTICK_DEADZONE) / ::maxMouseJoystickDeadZone
      setValue = @(joyParams, objValue) ::set_option_multiplier(::OPTION_MOUSE_JOYSTICK_DEADZONE,
        (objValue / 100.0) * ::maxMouseJoystickDeadZone)
    }
    { id = "mouse_joystick_screensize", type = CONTROL_TYPE.SLIDER
      filterHide = [globalEnv.EM_MOUSE_AIM]
      showFunc = @() getMouseUsageMask() & AIR_MOUSE_USAGE.JOYSTICK
      value = @(joyParams)
        100.0*(::get_option_multiplier(::OPTION_MOUSE_JOYSTICK_SCREENSIZE) - ::minMouseJoystickScreenSize) /
          (::maxMouseJoystickScreenSize - ::minMouseJoystickScreenSize)
      setValue = @(joyParams, objValue)
        ::set_option_multiplier(::OPTION_MOUSE_JOYSTICK_SCREENSIZE, ::minMouseJoystickScreenSize + (objValue / 100.0) *
          (::maxMouseJoystickScreenSize - ::minMouseJoystickScreenSize))
    }
    { id = "mouse_joystick_screen_place", type = CONTROL_TYPE.SLIDER
      filterHide = [globalEnv.EM_MOUSE_AIM]
      showFunc = @() getMouseUsageMask() & AIR_MOUSE_USAGE.JOYSTICK
      value = @(joyParams) 100.0*::get_option_multiplier(::OPTION_MOUSE_JOYSTICK_SCREENPLACE)
      setValue = @(joyParams, objValue) ::set_option_multiplier(::OPTION_MOUSE_JOYSTICK_SCREENPLACE, objValue / 100.0)
    }
    { id = "mouse_joystick_rudder", type = CONTROL_TYPE.SLIDER
      filterHide = [globalEnv.EM_MOUSE_AIM]
      showFunc = @() getMouseUsageMask() & (AIR_MOUSE_USAGE.JOYSTICK | AIR_MOUSE_USAGE.RELATIVE)
      value = @(joyParams) 100.0*::get_option_multiplier(::OPTION_MOUSE_AILERON_RUDDER_FACTOR) / ::maxMouseJoystickRudder
      setValue = @(joyParams, objValue) ::set_option_multiplier(::OPTION_MOUSE_AILERON_RUDDER_FACTOR,
        (objValue / 100.0) * ::maxMouseJoystickRudder)
    }
    { id = "mouse_joystick_square", type = CONTROL_TYPE.SWITCH_BOX
      filterHide = [globalEnv.EM_MOUSE_AIM]
      showFunc = @() getMouseUsageMask() & AIR_MOUSE_USAGE.JOYSTICK
      value = @(joyParams) ::get_option_mouse_joystick_square()
      setValue = @(joyParams, objValue) ::set_option_mouse_joystick_square(objValue)
    }
    { id="ID_CENTER_MOUSE_JOYSTICK"
      filterHide = [globalEnv.EM_MOUSE_AIM]
      showFunc = @() ::is_mouse_available() && getMouseUsageMask() & AIR_MOUSE_USAGE.JOYSTICK
      checkAssign = false
    }

  { id = "ID_TRIM_CONTROL_HEADER", type = CONTROL_TYPE.SECTION
    filterShow = [globalEnv.EM_FULL_REAL]
  }
//    { id="ID_WHEEL_BRAKE", filterShow = [globalEnv.EM_FULL_REAL] }
    { id="ID_TRIM", filterShow = [globalEnv.EM_FULL_REAL], checkAssign = false }
    { id="ID_TRIM_RESET", filterShow = [globalEnv.EM_FULL_REAL], checkAssign = false }
    { id="ID_TRIM_SAVE", filterShow = [globalEnv.EM_FULL_REAL], checkAssign = false }
    { id="trim_elevator", type = CONTROL_TYPE.AXIS
      filterShow = [globalEnv.EM_FULL_REAL], checkAssign = false }
    { id="trim_ailerons", type = CONTROL_TYPE.AXIS
      filterShow = [globalEnv.EM_FULL_REAL], checkAssign = false }
    { id="trim_rudder", type = CONTROL_TYPE.AXIS
      filterShow = [globalEnv.EM_FULL_REAL], checkAssign = false }

  { id = "ID_MANUAL_ENGINE_CONTROL_HEADER", type = CONTROL_TYPE.SECTION
    filterShow = [globalEnv.EM_FULL_REAL]
  }
    { id="ID_COMPLEX_ENGINE", filterShow = [globalEnv.EM_FULL_REAL], checkAssign = false }
    { id="ID_TOGGLE_ENGINE", filterShow = [globalEnv.EM_FULL_REAL], checkAssign = false }
    { id="mixture", type = CONTROL_TYPE.AXIS
      filterShow = [globalEnv.EM_FULL_REAL], checkAssign = false }
    { id="prop_pitch", type = CONTROL_TYPE.AXIS
      filterShow = [globalEnv.EM_FULL_REAL], checkAssign = false }
    { id="ID_PROP_PITCH_AUTO", filterShow = [globalEnv.EM_FULL_REAL], checkAssign = false }
    { id="radiator", type = CONTROL_TYPE.AXIS
      filterShow = [globalEnv.EM_FULL_REAL], checkAssign = false }
    { id="oil_radiator", type = CONTROL_TYPE.AXIS, filterShow = [globalEnv.EM_FULL_REAL], checkAssign = false }
    { id="ID_RADIATOR_AUTO", filterShow = [globalEnv.EM_FULL_REAL], checkAssign = false }
    { id="turbo_charger", type = CONTROL_TYPE.AXIS
      filterShow = [globalEnv.EM_FULL_REAL], checkAssign = false }
    { id="ID_TOGGLE_AUTO_TURBO_CHARGER", filterShow = [globalEnv.EM_FULL_REAL], checkAssign = false }
    { id="ID_SUPERCHARGER", filterShow = [globalEnv.EM_FULL_REAL], checkAssign = false }
    { id="ID_MAGNETO_INCREASE", filterShow = [globalEnv.EM_FULL_REAL], checkAssign = false }
    { id="ID_MAGNETO_DECREASE", filterShow = [globalEnv.EM_FULL_REAL], checkAssign = false }
    { id="ID_TOGGLE_PROP_FEATHERING", filterShow = [globalEnv.EM_FULL_REAL], checkAssign = false }
    { id="ID_TOGGLE_1_ENGINE_CONTROL", filterShow = [globalEnv.EM_FULL_REAL], checkAssign = false }
    { id="ID_TOGGLE_2_ENGINE_CONTROL", filterShow = [globalEnv.EM_FULL_REAL], checkAssign = false }
    { id="ID_TOGGLE_3_ENGINE_CONTROL", filterShow = [globalEnv.EM_FULL_REAL], checkAssign = false }
    { id="ID_TOGGLE_4_ENGINE_CONTROL", filterShow = [globalEnv.EM_FULL_REAL], checkAssign = false }
    { id="ID_TOGGLE_5_ENGINE_CONTROL", filterShow = [globalEnv.EM_FULL_REAL], checkAssign = false }
    { id="ID_TOGGLE_6_ENGINE_CONTROL", filterShow = [globalEnv.EM_FULL_REAL], checkAssign = false }
    { id="ID_ENABLE_ALL_ENGINE_CONTROL", filterShow = [globalEnv.EM_FULL_REAL], checkAssign = false }


  { id = "ID_HELICOPTER_CONTROL_HEADER"
    type = CONTROL_TYPE.HEADER
    unitType = ::g_unit_type.AIRCRAFT
    unitTag = "helicopter"
    showFunc = function() {
      local currentUnit = ::get_player_cur_unit()
      return ::has_feature("Helicopters") ||
        currentUnit && ::is_helicopter(currentUnit)
    }
  }
  { id = "ID_HELICOPTER_AXES_HEADER"
    type = CONTROL_TYPE.SECTION
  }
    { id = "helicopter_keep_height",
      type = CONTROL_TYPE.SWITCH_BOX
      optionType = ::USEROPT_HELICOPTER_KEEP_HEIGHT
    }
    { id = "helicopter_aim_move",
      type = CONTROL_TYPE.SWITCH_BOX
      optionType = ::USEROPT_HELICOPTER_AIM_MOVE
      onChangeValue = "doControlsGroupChangeDelayed"
    }
    { id = "ID_FORWARD_HELICOPTER"
      checkGroup = ctrlGroups.HELICOPTER
      checkAssign = false
      autobind_sc = @() ::is_xinput_device() ?
        [SHORTCUT.GAMEPAD_UP] : [SHORTCUT.KEY_W, SHORTCUT.KEY_UP]
    }
    { id = "ID_BACKWARD_HELICOPTER"
      checkGroup = ctrlGroups.HELICOPTER
      checkAssign = false
      autobind_sc = @() ::is_xinput_device() ?
        [SHORTCUT.GAMEPAD_DOWN] : [SHORTCUT.KEY_S, SHORTCUT.KEY_DOWN]
    }
    { id = "helicopter_throttle"
      type = CONTROL_TYPE.AXIS
      checkGroup = ctrlGroups.HELICOPTER
      autobind_raw = @() ::is_xinput_device()
        ? {axis = {axisId = AXIS.RIGHTSTICK_Y}}
        : {keys = {
          helicopter_throttle_rangeMin = [SHORTCUT.KEY_LCTRL]
          helicopter_throttle_rangeMax = [SHORTCUT.KEY_LSHIFT]
        }}
    }
    { id = "helicopter_roll"
      type = CONTROL_TYPE.AXIS
      checkGroup = ctrlGroups.HELICOPTER
      autobind_raw = @() ::is_xinput_device()
        ? {axis = {axisId = AXIS.LEFTSTICK_X}}
        : {keys = {
          helicopter_roll_rangeMin =
            [SHORTCUT.KEY_A, SHORTCUT.KEY_LEFT]
          helicopter_roll_rangeMax =
            [SHORTCUT.KEY_D, SHORTCUT.KEY_RIGHT]
        }}
      def_relative = false
      reqInMouseAim = false
    }
    { id = "helicopter_pitch"
      type = CONTROL_TYPE.AXIS
      checkGroup = ctrlGroups.HELICOPTER
      autobind_raw = @() ::is_xinput_device()
        ? {axis = {axisId = AXIS.LEFTSTICK_Y, inverse = true}}
        : {keys = {
          helicopter_pitch_rangeMin = [SHORTCUT.KEY_PAGE_UP]
          helicopter_pitch_rangeMax = [SHORTCUT.KEY_PAGE_DOWN]
        }}
      def_relative = false
      checkAssign = false
    }
    { id = "helicopter_yaw"
      type = CONTROL_TYPE.AXIS
      checkGroup = ctrlGroups.HELICOPTER
      autobind_raw = @() ::is_xinput_device()
        ? {axis = {axisId = AXIS.RIGHTSTICK_X}}
        : {keys = {
          helicopter_yaw_rangeMin = [SHORTCUT.KEY_Q]
          helicopter_yaw_rangeMax = [SHORTCUT.KEY_E]
        }}
      def_relative = false
      checkAssign = false
    }

  { id = "ID_HELICOPTER_FIRE_HEADER"
    type = CONTROL_TYPE.SECTION
  }
    { id = "helicopter_aim_fire",
      type = CONTROL_TYPE.SWITCH_BOX
      optionType = ::USEROPT_HELICOPTER_AIM_FIRE
      showFunc = @() checkOptionValue("helicopter_aim_move", false)
    }
    { id = "ID_FIRE_HELICOPTER"
      checkGroup = ctrlGroups.HELICOPTER
      autobind_sc = @() ::is_xinput_device() ? [SHORTCUT.GAMEPAD_R2] : [SHORTCUT.MOUSE_LEFT_BUTTON]
    }
    { id = "ID_ROCKETS_HELICOPTER"
      checkGroup = ctrlGroups.HELICOPTER
      autobind_sc = @() ::is_xinput_device() ? [SHORTCUT.GAMEPAD_L1]
        : [SHORTCUT.KEY_R, SHORTCUT.KEY_4, SHORTCUT.MOUSE_BUTTON_5]
    }
    { id = "ID_MISSLE_HELICOPTER"
      checkGroup = ctrlGroups.HELICOPTER
      autobind_sc = @() ::is_xinput_device() ? [SHORTCUT.GAMEPAD_R1]
        : [SHORTCUT.KEY_SPACE, SHORTCUT.KEY_3, SHORTCUT.MOUSE_BUTTON_4]
    }

  { id = "ID_HELICOPTER_VIEW_HEADER"
    type = CONTROL_TYPE.SECTION
  }
    { id = "ID_TOGGLE_VIEW_HELICOPTER"
      checkGroup = ctrlGroups.HELICOPTER
      autobind_sc = @() ::is_xinput_device() ? [SHORTCUT.GAMEPAD_Y] : [SHORTCUT.KEY_V]
      checkAssign = false
    }
    { id = "ID_TARGETING_HOLD_HELICOPTER"
      checkGroup = ctrlGroups.HELICOPTER
      autobind_sc = @() ::is_xinput_device() ? [SHORTCUT.GAMEPAD_L2] : [SHORTCUT.MOUSE_RIGHT_BUTTON]
      checkAssign = false
    }
    { id = "helicopter_camx"
      type = CONTROL_TYPE.AXIS
      checkGroup = ctrlGroups.HELICOPTER
      checkAssign = false
      autobind_raw = @() ::is_xinput_device()
        ? {axis = {axisId = AXIS.RIGHTSTICK_X}, keys = {
          helicopter_camx = [SHORTCUT.GAMEPAD_LEFT, SHORTCUT.GAMEPAD_RIGHT]
        }}
        : null
    }
    { id = "helicopter_camy"
      type = CONTROL_TYPE.AXIS
      checkGroup = ctrlGroups.HELICOPTER
      checkAssign = false
      autobind_raw = @() ::is_xinput_device()
        ? {axis = {axisId = AXIS.RIGHTSTICK_Y}, keys = {
          helicopter_camy = [SHORTCUT.GAMEPAD_LEFT, SHORTCUT.GAMEPAD_RIGHT]
        }}
        : null
    }
    { id = "invert_y_helicopter"
      type = CONTROL_TYPE.SWITCH_BOX
      optionType = ::USEROPT_INVERTY_HELICOPTER
    }
    { id = "helicopter_mouse_aim_x"
      type = CONTROL_TYPE.AXIS
      checkGroup = ctrlGroups.HELICOPTER
      checkAssign = false
    }
    { id = "helicopter_mouse_aim_y"
      type = CONTROL_TYPE.AXIS
      checkGroup = ctrlGroups.HELICOPTER
      checkAssign = false
    }


  { id = "ID_TANK_CONTROL_HEADER"
    type = CONTROL_TYPE.HEADER
    unitType = ::g_unit_type.TANK
    showFunc = @() ::has_feature("Tanks")
  }
  { id = "ID_TANK_MOVE_HEADER", type = CONTROL_TYPE.SECTION }
    { id="gm_automatic_transmission",
      type = CONTROL_TYPE.SWITCH_BOX
      optionType = ::USEROPT_AUTOMATIC_TRANSMISSION_TANK
      onChangeValue = "doControlsGroupChangeDelayed"
    }
    { id="ID_TOGGLE_TRANSMISSION_MODE_GM", checkGroup = ctrlGroups.TANK, checkAssign = false }
    { id="gm_throttle", type = CONTROL_TYPE.AXIS, checkGroup = ctrlGroups.TANK }
    { id="gm_steering", type = CONTROL_TYPE.AXIS, checkGroup = ctrlGroups.TANK }
    { id="gm_brake_left"
      type = CONTROL_TYPE.AXIS
      checkGroup = ctrlGroups.TANK
      checkAssign = false
    }
    { id="gm_brake_right"
      type = CONTROL_TYPE.AXIS
      checkGroup = ctrlGroups.TANK
      checkAssign = false
    }
    { id="ID_TRANS_GEAR_UP",
      checkGroup = ctrlGroups.TANK,
      checkAssign = false
    }
    { id="ID_TRANS_GEAR_DOWN",
      checkGroup = ctrlGroups.TANK,
      checkAssign = false
    }
    { id="ID_TRANS_GEAR_NEUTRAL",
      checkGroup = ctrlGroups.TANK,
      checkAssign = false,
      showFunc = @() checkOptionValue("gm_automatic_transmission", false)
    }
    { id="ID_ENABLE_GM_DIRECTION_DRIVING" , checkGroup = ctrlGroups.TANK, checkAssign = false }

  { id = "ID_TANK_FIRE_HEADER", type = CONTROL_TYPE.SECTION }
    { id="ID_FIRE_GM", checkGroup = ctrlGroups.TANK, autobind = ["ID_FIRE_MGUNS", "ID_FIRE_CANNONS"] }
    { id="ID_FIRE_GM_SECONDARY_GUN", checkGroup = ctrlGroups.TANK, checkAssign = false
      autobind = ["ID_FIRE_GM", "ID_FIRE_CANNONS", "ID_FIRE_MGUNS"]
    }
    { id="ID_FIRE_GM_MACHINE_GUN", checkGroup = ctrlGroups.TANK, checkAssign = false
      autobind = ["ID_FIRE_GM_SECONDARY_GUN", "ID_FIRE_GM", "ID_FIRE_CANNONS", "ID_FIRE_MGUNS"]
    }
    { id="ID_FIRE_GM_SPECIAL_GUN", checkGroup = ctrlGroups.TANK, autobind = ["ID_ROCKETS"] }
    { id="ID_SELECT_GM_GUN_RESET",      checkGroup = ctrlGroups.TANK, checkAssign = false }
    { id="ID_SELECT_GM_GUN_PRIMARY",    checkGroup = ctrlGroups.TANK, checkAssign = false }
    { id="ID_SELECT_GM_GUN_SECONDARY",  checkGroup = ctrlGroups.TANK, checkAssign = false }
    { id="ID_SELECT_GM_GUN_MACHINEGUN", checkGroup = ctrlGroups.TANK, checkAssign = false }
    { id="ID_SMOKE_SCREEN"
      checkGroup = ctrlGroups.TANK
      autobind_sc = @() ::is_xinput_device() ? null : [SHORTCUT.KEY_G]
      checkAssign = false
    }
    {
      id = "ID_SMOKE_SCREEN_GENERATOR"
      checkGroup = ctrlGroups.TANK
      autobind_sc = @() ::is_xinput_device() ? null : [SHORTCUT.KEY_H]
      checkAssign = false
    }

  { id = "ID_TANK_VIEW_HEADER", type = CONTROL_TYPE.SECTION }
    { id="ID_ZOOM_HOLD_GM", checkGroup = ctrlGroups.TANK, checkAssign = false }
    { id="ID_TOGGLE_VIEW_GM", checkGroup = ctrlGroups.TANK, autobind = ["ID_TOGGLE_VIEW"] }
    { id="ID_CAMERA_DRIVER",        checkGroup = ctrlGroups.TANK, checkAssign = false }
    { id="ID_CAMERA_BINOCULARS",    checkGroup = ctrlGroups.TANK, checkAssign = false }
    { id="ID_ENABLE_GUN_STABILIZER_GM", checkGroup = ctrlGroups.TANK, checkAssign = false }
    { id="ID_TARGETING_HOLD_GM", checkGroup = ctrlGroups.TANK, checkAssign = false }
    { id="gm_zoom", type = CONTROL_TYPE.AXIS, autobind=["zoom"], checkGroup = ctrlGroups.TANK, checkAssign = false }
    { id="gm_camx",         type = CONTROL_TYPE.AXIS, autobind=["camx"], checkGroup = ctrlGroups.TANK, reqInMouseAim = false }
    { id="gm_camy",         type = CONTROL_TYPE.AXIS, autobind=["camy"], checkGroup = ctrlGroups.TANK, reqInMouseAim = false }
    { id="invert_y_tank", type = CONTROL_TYPE.SWITCH_BOX
      optionType = ::USEROPT_INVERTY_TANK
      onChangeValue = "doControlsGroupChangeDelayed"
    }
    { id="gm_mouse_aim_x", type = CONTROL_TYPE.AXIS, checkGroup = ctrlGroups.TANK
      reqInMouseAim = false
      hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    }
    { id="gm_mouse_aim_y", type = CONTROL_TYPE.AXIS, checkGroup = ctrlGroups.TANK
      reqInMouseAim = false
      hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    }
    { id = "aim_time_nonlinearity_tank", type = CONTROL_TYPE.SLIDER
      value = @(joyParams) 100.0 * ::get_option_multiplier(::OPTION_AIM_TIME_NONLINEARITY_TANK)
      setValue = @(joyParams, objValue)
        ::set_option_multiplier(::OPTION_AIM_TIME_NONLINEARITY_TANK, objValue / 100.0)
    }
    { id = "aim_acceleration_delay_tank", type = CONTROL_TYPE.SLIDER
      value = @(joyParams) 100.0 * ::get_option_multiplier(::OPTION_AIM_ACCELERATION_DELAY_TANK)
      setValue = @(joyParams, objValue)
        ::set_option_multiplier(::OPTION_AIM_ACCELERATION_DELAY_TANK, objValue / 100.0)
    }
    { id = "mouse_z_ground", type = CONTROL_TYPE.MOUSE_AXIS
      axis_num = MouseAxis.MOUSE_SCROLL_TANK
      values = ["none", "gm_zoom", "gm_sight_distance"]
      onChangeValue = "onMouseWheel"
      showFunc = @() !::is_platform_xboxone && ::has_feature("Tanks")
    }

  { id = "ID_TANK_SUSPENSION_HEADER", type = CONTROL_TYPE.SECTION }
    { id="ID_SUSPENSION_PITCH_UP", checkGroup = ctrlGroups.TANK, checkAssign = false }
    { id="ID_SUSPENSION_PITCH_DOWN", checkGroup = ctrlGroups.TANK, checkAssign = false }
    { id="ID_SUSPENSION_ROLL_UP", checkGroup = ctrlGroups.TANK, checkAssign = false }
    { id="ID_SUSPENSION_ROLL_DOWN", checkGroup = ctrlGroups.TANK, checkAssign = false }
    { id="ID_SUSPENSION_CLEARANCE_UP", checkGroup = ctrlGroups.TANK, checkAssign = false }
    { id="ID_SUSPENSION_CLEARANCE_DOWN", checkGroup = ctrlGroups.TANK, checkAssign = false }
    { id="ID_SUSPENSION_RESET", checkGroup = ctrlGroups.TANK, checkAssign = false }

  { id = "ID_TANK_OTHER_HEADER", type = CONTROL_TYPE.SECTION }
    //{ id="ID_SHOW_TARGET_ARMOR" }
    //{ id="ID_REPAIR_TRACKS" ,           checkGroup = ctrlGroups.TANK, checkAssign = false}
    { id="ID_REPAIR_TANK",              checkGroup = ctrlGroups.TANK, autobind = ["ID_RELOAD_GUNS"] }
    { id="ID_ACTION_BAR_ITEM_1", checkGroup = ctrlGroups.TANK, checkAssign = false }
    { id="ID_ACTION_BAR_ITEM_2", checkGroup = ctrlGroups.TANK, checkAssign = false }
    { id="ID_ACTION_BAR_ITEM_3", checkGroup = ctrlGroups.TANK, checkAssign = false }
    { id="ID_ACTION_BAR_ITEM_4", checkGroup = ctrlGroups.TANK, checkAssign = false }
    { id="ID_ACTION_BAR_ITEM_5", checkGroup = ctrlGroups.TANK, checkAssign = false,
      autobind = ["ID_KILLSTREAK_WHEEL_MENU"]
      showFunc = @() ::is_platform_pc && !::is_xinput_device()
    }
    { id="ID_ACTION_BAR_ITEM_6", checkGroup = ctrlGroups.TANK, checkAssign = false }
    { id="ID_ACTION_BAR_ITEM_7", checkGroup = ctrlGroups.TANK, checkAssign = false }
    { id="ID_ACTION_BAR_ITEM_8", checkGroup = ctrlGroups.TANK, checkAssign = false }
    { id="ID_ACTION_BAR_ITEM_9", checkGroup = ctrlGroups.TANK, checkAssign = false }
    { id="ID_ACTION_BAR_ITEM_10", checkGroup = ctrlGroups.TANK, checkAssign = false }
    { id="ID_ACTION_BAR_ITEM_12", checkGroup = ctrlGroups.TANK, checkAssign = false }
    { id="ID_KILLSTREAK_WHEEL_MENU", checkGroup = ctrlGroups.TANK, checkAssign = false,
      autobind = ["ID_ACTION_BAR_ITEM_5"]
      showFunc = @() !(::is_platform_pc && !::is_xinput_device())
    }
    { id="ID_SCOUT"
      checkGroup = ctrlGroups.TANK,
      autobind_sc = @() ::is_xinput_device() ? null : [SHORTCUT.KEY_V]
      checkAssign = false
      showFunc = @() ::has_feature("ActiveScouting")
    }

    { id="ID_RANGEFINDER", checkGroup = ctrlGroups.TANK, checkAssign = false }
    { id="ID_TOGGLE_GM_CROSSHAIR_LIGHTING", checkGroup = ctrlGroups.TANK, checkAssign = false }
    { id="ID_SHORT_STOP",               checkGroup = ctrlGroups.TANK, checkAssign = false }
    { id="gm_sight_distance"
      type = CONTROL_TYPE.AXIS
      def_relative = true
      isAbsOnlyWhenRealAxis = true
      checkGroup = ctrlGroups.TANK
      checkAssign = false
    }


  { id = "ID_SHIP_CONTROL_HEADER"
    type = CONTROL_TYPE.HEADER
    unitType = ::g_unit_type.SHIP
    showFunc = @() ::has_feature("Ships")
  }
  { id = "ID_SHIP_MOVE_HEADER", type = CONTROL_TYPE.SECTION }
    { id = "ship_seperated_engine_control",
      type = CONTROL_TYPE.SWITCH_BOX
      optionType = ::USEROPT_SEPERATED_ENGINE_CONTROL_SHIP
      onChangeValue = "doControlsGroupChangeDelayed"
    }
    { id = "ship_main_engine",
      type = CONTROL_TYPE.AXIS,
      autobind = ["gm_throttle"],
      def_relative = true,
      checkGroup = ctrlGroups.SHIP,
      showFunc = @() checkOptionValue("ship_seperated_engine_control", false)
    }
    { id = "ship_port_engine",
      type = CONTROL_TYPE.AXIS,
      def_relative = true,
      checkGroup = ctrlGroups.SHIP,
      showFunc = @() checkOptionValue("ship_seperated_engine_control", true)
      checkAssign = false
    }
    { id="ship_star_engine",
      type = CONTROL_TYPE.AXIS
      def_relative = true
      checkGroup = ctrlGroups.SHIP
      showFunc = @() checkOptionValue("ship_seperated_engine_control", true)
      checkAssign = false
    }
    { id="ship_steering", type = CONTROL_TYPE.AXIS, autobind=["gm_steering"], checkGroup = ctrlGroups.SHIP }
    {
      id = "ID_SHIP_FULL_STOP",
      checkGroup = ctrlGroups.SHIP,
      checkAssign = false
    }
  { id = "ID_SHIP_FIRE_HEADER", type = CONTROL_TYPE.SECTION }
    {
      id = "ID_SHIP_WEAPON_ALL",
      autobind = ["ID_FIRE_GM", "ID_FIRE_CANNONS", "ID_FIRE_MGUNS"]
      checkGroup = ctrlGroups.SHIP
    }

    {
      id = "ID_SHIP_WEAPON_PRIMARY",
      checkGroup = ctrlGroups.SHIP,
      checkAssign = false
    }

    {
      id = "ID_SHIP_WEAPON_SECONDARY",
      checkGroup = ctrlGroups.SHIP,
      checkAssign = false
    }

    {
      id = "ID_SHIP_WEAPON_MACHINEGUN",
      checkGroup = ctrlGroups.SHIP,
      checkAssign = false
    }

    {
      id = "ID_SHIP_WEAPON_TORPEDOES",
      autobind = ["ID_BOMBS"]
      checkGroup = ctrlGroups.SHIP
      checkAssign = false
    }

    {
      id = "ID_SHIP_WEAPON_DEPTH_CHARGE",
      checkGroup = ctrlGroups.SHIP
      autobind = ["ID_SHIP_WEAPON_MINE"]
      autobind_sc = @() ::is_xinput_device() ? null : [SHORTCUT.KEY_LCTRL]
      checkAssign = false
    }

    {
      id = "ID_SHIP_WEAPON_ROCKETS",
      autobind = ["ID_ROCKETS"]
      checkGroup = ctrlGroups.SHIP
      checkAssign = false
    }

    {
      id = "ID_SHIP_WEAPON_MINE",
      checkGroup = ctrlGroups.SHIP
      autobind = ["ID_SHIP_WEAPON_DEPTH_CHARGE"]
      autobind_sc = @() ::is_xinput_device() ? null : [SHORTCUT.KEY_LCTRL]
      checkAssign = false
    }
    {
      id = "ID_SHIP_TORPEDO_SIGHT"
      checkGroup = ctrlGroups.SHIP
      autobind_sc = @() ::is_xinput_device() ? null : [SHORTCUT.KEY_Q]
      checkAssign = false
    }
    {
      id="ID_SHIP_TOGGLE_GUNNERS"
      checkGroup = ctrlGroups.SHIP
      autobind_sc = @() ::is_xinput_device() ? null : [SHORTCUT.KEY_E]
      checkAssign = false
    }
    {
      id = "ID_SHIP_SELECT_TARGET_AI_PRIM",
      checkGroup = ctrlGroups.SHIP,
      checkAssign = false
    }
    {
      id = "ID_SHIP_SELECT_TARGET_AI_SEC",
      checkGroup = ctrlGroups.SHIP,
      checkAssign = false
    }
    {
      id = "ID_SHIP_SELECT_TARGET_AI_MGUN",
      checkGroup = ctrlGroups.SHIP,
      checkAssign = false
    }

  { id = "ID_SHIP_VIEW_HEADER", type = CONTROL_TYPE.SECTION }
    { id="ID_TOGGLE_VIEW_SHIP", checkGroup = ctrlGroups.SHIP, autobind = ["ID_TOGGLE_VIEW_GM"] }
    { id="ID_LOCK_TARGETING_AT_POINT_SHIP", checkGroup = ctrlGroups.SHIP, checkAssign = false }
    { id="ship_zoom", type = CONTROL_TYPE.AXIS, autobind=["gm_zoom"], checkGroup = ctrlGroups.SHIP, checkAssign = false }
    { id="ship_camx", type = CONTROL_TYPE.AXIS, autobind=["gm_camx"], checkGroup = ctrlGroups.SHIP, reqInMouseAim = false }
    { id="ship_camy", type = CONTROL_TYPE.AXIS, autobind=["gm_camy"], checkGroup = ctrlGroups.SHIP, reqInMouseAim = false }
    { id="invert_y_ship"
      type = CONTROL_TYPE.SWITCH_BOX
      optionType = ::USEROPT_INVERTY_SHIP
    }
    { id="ship_mouse_aim_x", type = CONTROL_TYPE.AXIS, autobind=["gm_mouse_aim_x"], checkGroup = ctrlGroups.SHIP
      reqInMouseAim = false
      hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    }
    { id="ship_mouse_aim_y", type = CONTROL_TYPE.AXIS, autobind=["gm_mouse_aim_y"], checkGroup = ctrlGroups.SHIP
      reqInMouseAim = false
      hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    }
    { id = "aim_time_nonlinearity_ship", type = CONTROL_TYPE.SLIDER
      value = @(joyParams) 100.0 * ::get_option_multiplier(::OPTION_AIM_TIME_NONLINEARITY_SHIP)
      setValue = @(joyParams, objValue)
        ::set_option_multiplier(::OPTION_AIM_TIME_NONLINEARITY_SHIP, objValue / 100.0)
    }
    { id = "aim_acceleration_delay_ship", type = CONTROL_TYPE.SLIDER
      value = @(joyParams) 100.0 * ::get_option_multiplier(::OPTION_AIM_ACCELERATION_DELAY_SHIP)
      setValue = @(joyParams, objValue)
        ::set_option_multiplier(::OPTION_AIM_ACCELERATION_DELAY_SHIP, objValue / 100.0)
    }
    { id = "mouse_z_ship", type = CONTROL_TYPE.MOUSE_AXIS
      axis_num = MouseAxis.MOUSE_SCROLL_SHIP
      values = ["none", "ship_sight_distance", "ship_main_engine", "ship_zoom"]
      onChangeValue = "onMouseWheel"
      showFunc = @() !::is_platform_xboxone && ::has_feature("Ships")
    }

  { id = "ID_SHIP_OTHER_HEADER", type = CONTROL_TYPE.SECTION }
    {
      id = "ID_SHIP_ACTION_BAR_ITEM_1",
      autobind = ["ID_ACTION_BAR_ITEM_1"]
      checkGroup = ctrlGroups.SHIP,
      checkAssign = false
    }

    {
      id = "ID_SHIP_ACTION_BAR_ITEM_2",
      autobind = ["ID_ACTION_BAR_ITEM_2"]
      checkGroup = ctrlGroups.SHIP,
      checkAssign = false
    }

    {
      id = "ID_SHIP_ACTION_BAR_ITEM_3",
      autobind = ["ID_ACTION_BAR_ITEM_3"]
      checkGroup = ctrlGroups.SHIP,
      checkAssign = false
    }

    {
      id = "ID_SHIP_ACTION_BAR_ITEM_4",
      autobind = ["ID_ACTION_BAR_ITEM_4"]
      checkGroup = ctrlGroups.SHIP,
      checkAssign = false
    }

    {
      id = "ID_SHIP_ACTION_BAR_ITEM_5",
      autobind = ["ID_ACTION_BAR_ITEM_5"]
      checkGroup = ctrlGroups.SHIP,
      checkAssign = false
    }

    { id="ID_SHIP_KILLSTREAK_WHEEL_MENU"
      checkGroup = ctrlGroups.SHIP
      checkAssign = false
      autobind = ["ID_KILLSTREAK_WHEEL_MENU"]
      showFunc = @() !(::is_platform_pc && !::is_xinput_device())
    }

    {
      id = "ID_SHIP_ACTION_BAR_ITEM_6",
      autobind = ["ID_ACTION_BAR_ITEM_6"]
      checkGroup = ctrlGroups.SHIP,
      checkAssign = false
    }

    { id="ID_SHIP_ACTION_BAR_ITEM_11",
      autobind = ["ID_REPAIR_TANK"]
      checkGroup = ctrlGroups.SHIP
      autobind_sc = @() ::is_xinput_device() ? null : [SHORTCUT.KEY_7]
      checkAssign = false
    }

    { id="ID_REPAIR_BREACHES"
      checkGroup = ctrlGroups.SHIP
      autobind_sc = @() ::is_xinput_device() ? null : [SHORTCUT.KEY_8]
      checkAssign = false
    }

    { id="ID_SHIP_ACTION_BAR_ITEM_10",
      autobind = ["ID_ACTION_BAR_ITEM_10"]
      checkGroup = ctrlGroups.SHIP
      checkAssign = false
    }

    { id="ID_SHIP_LOCK_SHOOT_DISTANCE",
      checkGroup = ctrlGroups.SHIP,
      checkAssign = false
    }

    { id="ship_sight_distance"
      type = CONTROL_TYPE.AXIS
      def_relative = true
      isAbsOnlyWhenRealAxis = true
      checkGroup = ctrlGroups.SHIP
      checkAssign = false
    }
    { id="ship_shoot_direction"
      type = CONTROL_TYPE.AXIS
      def_relative = true
      isAbsOnlyWhenRealAxis = true
      checkGroup = ctrlGroups.SHIP
      checkAssign = false
    }

    {
      id = "ID_SHIP_SMOKE_SCREEN_GENERATOR",
      checkGroup = ctrlGroups.SHIP,
      checkAssign = false
      autobind_sc = @() ::is_xinput_device() ? null : [SHORTCUT.KEY_G]
    }

  { id = "ID_SUBMARINE_CONTROL_HEADER"
    type = CONTROL_TYPE.HEADER
    unitType = ::g_unit_type.SHIP
    unitTag = "submarine"
    showFunc = @() ::has_feature("SpecialShips") || ::is_submarine(::get_player_cur_unit())
  }
  { id = "ID_SUBMARINE_MOVE_HEADER"
    type = CONTROL_TYPE.SECTION
  }
    { id = "submarine_main_engine"
      type = CONTROL_TYPE.AXIS
      def_relative = true
      checkGroup = ctrlGroups.SUBMARINE
    }
    { id = "submarine_steering"
      type = CONTROL_TYPE.AXIS
      checkGroup = ctrlGroups.SUBMARINE
    }
    { id = "submarine_depth"
      type = CONTROL_TYPE.AXIS
      checkGroup = ctrlGroups.SUBMARINE
    }
    { id = "ID_SUBMARINE_FULL_STOP"
      checkGroup = ctrlGroups.SUBMARINE
      checkAssign = false
    }

  { id = "ID_SUBMARINE_FIRE_HEADER"
    type = CONTROL_TYPE.SECTION
  }
    { id = "ID_TOGGLE_VIEW_SUBMARINE"
      checkGroup = ctrlGroups.SUBMARINE
      checkAssign = false
    }
    { id = "ID_SUBMARINE_WEAPON_TORPEDOES"
      checkGroup = ctrlGroups.SUBMARINE
    }
    { id = "ID_SUBMARINE_SWITCH_ACTIVE_SONAR"
      checkGroup = ctrlGroups.SUBMARINE
      checkAssign = false
    }
    { id = "ID_SUBMARINE_WEAPON_TOGGLE_ACTIVE_SENSOR"
      checkGroup = ctrlGroups.SUBMARINE
      checkAssign = false
    }
    { id = "ID_SUBMARINE_WEAPON_TOGGLE_SELF_HOMMING"
      checkGroup = ctrlGroups.SUBMARINE
      checkAssign = false
    }

  { id = "ID_SUBMARINE_VIEW_HEADER"
    type = CONTROL_TYPE.SECTION
  }
    { id="submarine_zoom"
      type = CONTROL_TYPE.AXIS
      checkGroup = ctrlGroups.SUBMARINE
      checkAssign = false
    }
    { id="submarine_camx"
      type = CONTROL_TYPE.AXIS
      checkGroup = ctrlGroups.SUBMARINE
      reqInMouseAim = false
    }
    { id="submarine_camy"
      type = CONTROL_TYPE.AXIS
      checkGroup = ctrlGroups.SUBMARINE
      reqInMouseAim = false
    }
    { id="invert_y_submarine"
      type = CONTROL_TYPE.SWITCH_BOX
      optionType = ::USEROPT_INVERTY_SUBMARINE
    }
    { id="submarine_mouse_aim_x"
      type = CONTROL_TYPE.AXIS
      checkGroup = ctrlGroups.SUBMARINE
      reqInMouseAim = false
      hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    }
    { id="submarine_mouse_aim_y"
      type = CONTROL_TYPE.AXIS
      checkGroup = ctrlGroups.SUBMARINE
      reqInMouseAim = false
      hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    }
    { id = "aim_time_nonlinearity_submarine"
      type = CONTROL_TYPE.SLIDER
      value = @(joyParams) 100.0 * ::get_option_multiplier(::OPTION_AIM_TIME_NONLINEARITY_SUBMARINE)
      setValue = @(joyParams, objValue)
        ::set_option_multiplier(::OPTION_AIM_TIME_NONLINEARITY_SUBMARINE, objValue / 100.0)
    }
    { id = "aim_acceleration_delay_submarine"
      type = CONTROL_TYPE.SLIDER
      value = @(joyParams) 100.0 * ::get_option_multiplier(::OPTION_AIM_ACCELERATION_DELAY_SUBMARINE)
      setValue = @(joyParams, objValue)
        ::set_option_multiplier(::OPTION_AIM_ACCELERATION_DELAY_SUBMARINE, objValue / 100.0)
    }
    { id = "mouse_z_submarine"
      type = CONTROL_TYPE.MOUSE_AXIS
      axis_num = MouseAxis.MOUSE_SCROLL_SUBMARINE
      values = ["none", "submarine_main_engine", "submarine_zoom"]
      onChangeValue = "onMouseWheel"
      showFunc = @() ::is_mouse_available()
    }

  { id = "ID_SUBMARINE_OTHER_HEADER"
    type = CONTROL_TYPE.SECTION
  }
    { id = "ID_SUBMARINE_ACOUSTIC_COUNTERMEASURES"
      checkGroup = ctrlGroups.SUBMARINE
      checkAssign = false
    }
    { id="ID_SUBMARINE_KILLSTREAK_WHEEL_MENU"
      checkGroup = ctrlGroups.SUBMARINE
      autobind = ["ID_SHIP_KILLSTREAK_WHEEL_MENU"]
      showFunc = @() !(::is_platform_pc && !::is_xinput_device())
      checkAssign = false
    }
    { id = "ID_SUBMARINE_ACTION_BAR_ITEM_11",
      checkGroup = ctrlGroups.SUBMARINE
      checkAssign = false
    }
    { id = "ID_SUBMARINE_REPAIR_BREACHES"
      checkGroup = ctrlGroups.SUBMARINE
      checkAssign = false
    }


  { id = "ID_COMMON_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
  { id = "ID_COMMON_BASIC_HEADER", type = CONTROL_TYPE.SECTION }
    { id="ID_TACTICAL_MAP",      checkGroup = ctrlGroups.COMMON }
    { id="ID_MPSTATSCREEN",      checkGroup = ctrlGroups.COMMON }
    { id="ID_BAILOUT",           checkGroup = ctrlGroups.COMMON, checkAssign = false }
    { id="ID_SHOW_HERO_MODULES", checkGroup = ctrlGroups.COMMON, checkAssign = false }
    { id="ID_LOCK_TARGET",       checkGroup = ctrlGroups.COMMON }
    { id="ID_PREV_TARGET",       checkGroup = ctrlGroups.COMMON, checkAssign = false }
    { id="ID_NEXT_TARGET",       checkGroup = ctrlGroups.COMMON, checkAssign = false }
    { id="ID_TOGGLE_CHAT_TEAM",  checkGroup = ctrlGroups.COMMON, checkAssign = ::is_platform_pc }
    { id="ID_TOGGLE_CHAT",       checkGroup = ctrlGroups.COMMON, checkAssign = ::is_platform_pc }
    { id="ID_TOGGLE_CHAT_MODE",  checkGroup = ctrlGroups.COMMON, checkAssign = ::is_platform_pc }

    { id="ID_PTT", checkGroup = ctrlGroups.COMMON, checkAssign = false,
      condition = @() ::gchat_is_voice_enabled()
      showFunc = @() ::has_feature("Voice")
    }

  { id = "ID_COMMON_ARTILLERY_HEADER", type = CONTROL_TYPE.SECTION }
    { id="ID_SHOOT_ARTILLERY", checkGroup = ctrlGroups.ARTILLERY, checkAssign = false
      autobind = ["ID_FIRE_GM", "ID_FIRE_GM_SECONDARY_GUN", "ID_FIRE_CANNONS", "ID_FIRE_MGUNS"]
    }
    { id="ID_CHANGE_ARTILLERY_TARGETING_MODE", checkGroup = ctrlGroups.ARTILLERY, checkAssign = false
      autobind_sc = @() get_is_console_mode_force_enabled() ?
        [SHORTCUT.GAMEPAD_Y] : [SHORTCUT.MOUSE_MIDDLE_BUTTON]
    }
    { id="ID_ARTILLERY_CANCEL", checkGroup = ctrlGroups.ARTILLERY, checkAssign = false}

  { id = "ID_COMMON_INTERFACE_HEADER", type = CONTROL_TYPE.SECTION }
    { id="ID_FLIGHTMENU_SETUP",  checkGroup = ctrlGroups.COMMON, checkAssign = false }
    { id="ID_CONTINUE_SETUP",    checkGroup = ctrlGroups.NO_GROUP, checkAssign = false }
    { id="ID_GAME_PAUSE",        checkGroup = ctrlGroups.COMMON, checkAssign = false }
    { id="ID_HIDE_HUD",          checkGroup = ctrlGroups.COMMON, checkAssign = false }
    { id="ID_SHOW_MOUSE_CURSOR", checkGroup = ctrlGroups.COMMON, checkAssign = false
      showFunc = @() !::is_platform_xboxone
      condition = @() ::is_platform_pc || ::is_ps4_or_xbox
    }
    { id="ID_SCREENSHOT",        checkGroup = ctrlGroups.COMMON, checkAssign = false
      condition = @() ::is_platform_pc // See AcesApp::makeScreenshot()
    }
    { id="ID_SCREENSHOT_WO_HUD", checkGroup = ctrlGroups.COMMON, checkAssign = false
      condition = @() ::is_platform_pc // See AcesApp::makeScreenshot()
    }
    { id="decal_move_x", type = CONTROL_TYPE.AXIS, checkGroup = ctrlGroups.HANGAR, checkAssign = false }
    { id="decal_move_y", type = CONTROL_TYPE.AXIS, checkGroup = ctrlGroups.HANGAR, checkAssign = false }


  { id = "ID_VIEW_CONTROL_HEADER", type = CONTROL_TYPE.SECTION }
/*
    { id = "mouse_look_type", type = CONTROL_TYPE.SPINNER  //!!Fix me: Change to button
      options = ["#options/no", "#options/yes"]
      value = @(joyParams) joyParams.isMouseLookHold ? 1 : 0
      setValue = function(joyParams, objValue) {
        local prev = joyParams.isMouseLookHold
        joyParams.isMouseLookHold = objValue==1
        if (joyParams.isMouseLookHold != prev)
          ::set_controls_preset("")
      }
    }
*/
    { id="ID_ZOOM_TOGGLE",          checkGroup = ctrlGroups.COMMON }
    { id="ID_CAMERA_NEUTRAL",       checkGroup = ctrlGroups.COMMON, checkAssign = false
      showFunc = @() !::is_platform_xboxone
  }
    { id="mouse_sensitivity", type = CONTROL_TYPE.SLIDER
      optionType = ::USEROPT_MOUSE_SENSE
    }
    { id = "camera_mouse_speed", type = CONTROL_TYPE.SLIDER
      value = @(joyParams) 100.0*(::get_option_multiplier(::OPTION_CAMERA_MOUSE_SPEED) - min_camera_speed) / (max_camera_speed - min_camera_speed)
      setValue = @(joyParams, objValue) ::set_option_multiplier(::OPTION_CAMERA_MOUSE_SPEED, min_camera_speed + (objValue / 100.0) * (max_camera_speed - min_camera_speed))
      showFunc = @() !::is_platform_xboxone
    }
    { id = "camera_smooth", type = CONTROL_TYPE.SLIDER
      value = @(joyParams) 100.0*::get_option_multiplier(::OPTION_CAMERA_SMOOTH) / max_camera_smooth
      setValue = @(joyParams, objValue) ::set_option_multiplier(::OPTION_CAMERA_SMOOTH, (objValue / 100.0) * max_camera_smooth)
    }
    { id = "hatview_mouse", type = CONTROL_TYPE.SWITCH_BOX
      value = @(joyParams) joyParams.isHatViewMouse
      setValue = function(joyParams, objValue) {
        local prev = joyParams.isHatViewMouse
        joyParams.isHatViewMouse = objValue
        if (prev != objValue)
          ::set_controls_preset("")
      }
    }
    { id = "invert_y_spectator"
      type = CONTROL_TYPE.SWITCH_BOX
      optionType = ::USEROPT_INVERTY_SPECTATOR
    }
    { id="hangar_camera_x", type = CONTROL_TYPE.AXIS, checkGroup = ctrlGroups.HANGAR, checkAssign = false }
    { id="hangar_camera_y", type = CONTROL_TYPE.AXIS, checkGroup = ctrlGroups.HANGAR, checkAssign = false }

  { id = "ID_COMMON_VOICE_HEADER", type = CONTROL_TYPE.SECTION }
    { id="ID_SHOW_VOICE_MESSAGE_LIST",       checkGroup = ctrlGroups.COMMON }
    { id="ID_SHOW_VOICE_MESSAGE_LIST_SQUAD", checkGroup = ctrlGroups.COMMON, checkAssign = ::is_platform_pc }
    { id="ID_VOICE_MESSAGE_1", checkGroup = ctrlGroups.VOICE, checkAssign = false }
    { id="ID_VOICE_MESSAGE_2", checkGroup = ctrlGroups.VOICE, checkAssign = false }
    { id="ID_VOICE_MESSAGE_3", checkGroup = ctrlGroups.VOICE, checkAssign = false }
    { id="ID_VOICE_MESSAGE_4", checkGroup = ctrlGroups.VOICE, checkAssign = false }
    { id="ID_VOICE_MESSAGE_5", checkGroup = ctrlGroups.VOICE, checkAssign = false }
    { id="ID_VOICE_MESSAGE_6", checkGroup = ctrlGroups.VOICE, checkAssign = false }
    { id="ID_VOICE_MESSAGE_7", checkGroup = ctrlGroups.VOICE, checkAssign = false }
    { id="ID_VOICE_MESSAGE_8", checkGroup = ctrlGroups.VOICE, checkAssign = false }
    { id="use_joystick_mouse_for_voice_message", type = CONTROL_TYPE.SWITCH_BOX,
      value = @(joyParams) joyParams.useJoystickMouseForVoiceMessage
      setValue = function(joyParams, objValue) {
        local old  = joyParams.useJoystickMouseForVoiceMessage
        joyParams.useJoystickMouseForVoiceMessage = objValue
        if (joyParams.useJoystickMouseForVoiceMessage != old)
          ::set_controls_preset("");
      }
    }
    { id="use_mouse_for_voice_message", type = CONTROL_TYPE.SWITCH_BOX,
      value = @(joyParams) joyParams.useMouseForVoiceMessage
      showFunc = @() !::is_platform_xboxone
      setValue = function(joyParams, objValue) {
        local old  = joyParams.useMouseForVoiceMessage
        joyParams.useMouseForVoiceMessage = objValue
        if (joyParams.useMouseForVoiceMessage != old)
          ::set_controls_preset("");
      }
    }
    { id="ID_FAST_VOICE_MESSAGE_1", checkGroup = ctrlGroups.VOICE, checkAssign = false }
    ::get_favorite_voice_message_option(1)
    { id="ID_FAST_VOICE_MESSAGE_2", checkGroup = ctrlGroups.VOICE, checkAssign = false }
    ::get_favorite_voice_message_option(2)
    { id="ID_FAST_VOICE_MESSAGE_3", checkGroup = ctrlGroups.VOICE, checkAssign = false }
    ::get_favorite_voice_message_option(3)
    { id="ID_FAST_VOICE_MESSAGE_4", checkGroup = ctrlGroups.VOICE, checkAssign = false }
    ::get_favorite_voice_message_option(4)
    { id="ID_FAST_VOICE_MESSAGE_5", checkGroup = ctrlGroups.VOICE, checkAssign = false }
    ::get_favorite_voice_message_option(5)
    { id="ID_FAST_VOICE_MESSAGE_6", checkGroup = ctrlGroups.VOICE, checkAssign = false }
    ::get_favorite_voice_message_option(6)
    { id="ID_FAST_VOICE_MESSAGE_7", checkGroup = ctrlGroups.VOICE, checkAssign = false }
    ::get_favorite_voice_message_option(7)
    { id="ID_FAST_VOICE_MESSAGE_8", checkGroup = ctrlGroups.VOICE, checkAssign = false }
    ::get_favorite_voice_message_option(8)
    { id="ID_FAST_VOICE_MESSAGE_9", checkGroup = ctrlGroups.VOICE, checkAssign = false }
    ::get_favorite_voice_message_option(9)
    { id="ID_FAST_VOICE_MESSAGE_10", checkGroup = ctrlGroups.VOICE, checkAssign = false }
    ::get_favorite_voice_message_option(10)
    { id="ID_FAST_VOICE_MESSAGE_11", checkGroup = ctrlGroups.VOICE, checkAssign = false }
    ::get_favorite_voice_message_option(11)
    { id="ID_FAST_VOICE_MESSAGE_12", checkGroup = ctrlGroups.VOICE, checkAssign = false }
    ::get_favorite_voice_message_option(12)

  { id = "ID_COMMON_TRACKER_HEADER", type = CONTROL_TYPE.SECTION
    showFunc = @() !::is_platform_xboxone || ::ps4_headtrack_is_attached() || ::is_tracker_joystick()
  }
    { id="headtrack_enable", type = CONTROL_TYPE.SWITCH_BOX
      showFunc = @() ::ps4_headtrack_is_attached()
      optionType = ::USEROPT_HEADTRACK_ENABLE
      onChangeValue = "doControlsGroupChangeDelayed"
    }
    { id = "ID_TRACKER_RESET_POSITION"
      showFunc = @() !::is_platform_xboxone || checkOptionValue("headtrack_enable", true)
      checkGroup = ctrlGroups.COMMON
      checkAssign = false
      autobind = ["ID_CAMERA_NEUTRAL"]
    }
    { id="tracker_camx", type = CONTROL_TYPE.AXIS, checkGroup = ctrlGroups.COMMON, checkAssign = false,
      showFunc = @() ::is_tracker_joystick()
    }
    { id="tracker_camy", type = CONTROL_TYPE.AXIS, checkGroup = ctrlGroups.COMMON, checkAssign = false,
      showFunc = @() ::is_tracker_joystick()
    }
    { id="zoom_sens", type = CONTROL_TYPE.SLIDER
      showFunc = @() !::is_platform_xboxone
      optionType = ::USEROPT_ZOOM_SENSE
    }
    { id = "trackIrZoom", type = CONTROL_TYPE.SWITCH_BOX
      showFunc = @() !::is_platform_xboxone || checkOptionValue("headtrack_enable", true)
      value = @(joyParams) joyParams.trackIrZoom
      setValue = function(joyParams, objValue) {
        local prev = joyParams.trackIrZoom
        joyParams.trackIrZoom = objValue
        if (prev != objValue)
          ::set_controls_preset("")
      }
    }
    { id = "trackIrForLateralMovement", type = CONTROL_TYPE.SWITCH_BOX
      showFunc = @() !::is_platform_xboxone
      value = @(joyParams) joyParams.trackIrForLateralMovement
      setValue = function(joyParams, objValue) {
        local prev = joyParams.trackIrForLateralMovement
        joyParams.trackIrForLateralMovement = objValue
        if (prev != objValue)
          ::set_controls_preset("")
      }
    }
    { id = "trackIrAsHeadInTPS", type = CONTROL_TYPE.SWITCH_BOX
      showFunc = @() !::is_platform_xboxone || checkOptionValue("headtrack_enable", true)
      value = @(joyParams) joyParams.trackIrAsHeadInTPS
      setValue = function(joyParams, objValue) {
        local prev = joyParams.trackIrAsHeadInTPS
        joyParams.trackIrAsHeadInTPS = objValue
        if (joyParams.trackIrAsHeadInTPS != prev)
          ::set_controls_preset("")
      }
    }
    { id="headtrack_scale_x", type = CONTROL_TYPE.SLIDER
      showFunc = @() checkOptionValue("headtrack_enable", true)
      optionType = ::USEROPT_HEADTRACK_SCALE_X
    }
    { id="headtrack_scale_y", type = CONTROL_TYPE.SLIDER
      showFunc = @() checkOptionValue("headtrack_enable", true)
      optionType = ::USEROPT_HEADTRACK_SCALE_Y
    }


  { id = "ID_REPLAY_CONTROL_HEADER", type = CONTROL_TYPE.HEADER,
    showFunc = @() ::has_feature("Replays") || ::has_feature("Spectator")
  }
    { id="ID_TOGGLE_FOLLOWING_CAMERA", checkGroup = ctrlGroups.REPLAY, checkAssign = false }
    { id="ID_PREV_PLANE", checkGroup = ctrlGroups.REPLAY, checkAssign = false }
    { id="ID_NEXT_PLANE", checkGroup = ctrlGroups.REPLAY, checkAssign = false }
    { id="ID_REPLAY_CAMERA_GUN", checkGroup = ctrlGroups.REPLAY, checkAssign = false }
    { id="ID_REPLAY_CAMERA_WING", checkGroup = ctrlGroups.REPLAY, checkAssign = false },
    { id="ID_REPLAY_CAMERA_FLYBY", checkGroup = ctrlGroups.REPLAY, checkAssign = false },
    { id="ID_REPLAY_CAMERA_OPERATOR", checkGroup = ctrlGroups.REPLAY, checkAssign = false },
    { id="ID_REPLAY_CAMERA_FREE", checkGroup = ctrlGroups.REPLAY, checkAssign = false },
    { id="ID_REPLAY_CAMERA_RANDOMIZE", checkGroup = ctrlGroups.REPLAY, checkAssign = false }
    { id="ID_REPLAY_CAMERA_FREE_PARENTED", checkGroup = ctrlGroups.REPLAY, checkAssign = false },
    { id="free_camera_inertia", type = CONTROL_TYPE.SLIDER
      optionType = ::USEROPT_FREE_CAMERA_INERTIA,
    }
    { id="replay_camera_wiggle", type = CONTROL_TYPE.SLIDER
      optionType = ::USEROPT_REPLAY_CAMERA_WIGGLE,
    }
    { id="ID_REPLAY_CAMERA_HOVER", checkGroup = ctrlGroups.REPLAY, checkAssign = false },
    { id="ID_REPLAY_CAMERA_ZOOM_IN", checkGroup = ctrlGroups.REPLAY, checkAssign = false },
    { id="ID_REPLAY_CAMERA_ZOOM_OUT", checkGroup = ctrlGroups.REPLAY, checkAssign = false },
    { id="ID_REPLAY_SLOWER", checkGroup = ctrlGroups.REPLAY, checkAssign = false },
    { id="ID_REPLAY_FASTER", checkGroup = ctrlGroups.REPLAY, checkAssign = false }
    { id="ID_REPLAY_PAUSE", checkGroup = ctrlGroups.REPLAY, checkAssign = false
      autobind = ["ID_SKIP_CUTSCENE", "ID_GAME_PAUSE"] }
    { id="ID_REPLAY_AVI_WRITER",
      checkGroup = ctrlGroups.REPLAY,
      checkAssign = false,
      showFunc = @() ::has_feature("Replays")
    }
    { id="ID_REPLAY_SHOW_MARKERS", checkGroup = ctrlGroups.REPLAY, checkAssign = false }
    { id="ID_TOGGLE_CONTOURS", checkGroup = ctrlGroups.REPLAY, checkAssign = false }
    { id="cam_fwd", type = CONTROL_TYPE.AXIS, checkGroup = ctrlGroups.REPLAY, checkAssign = false }
    { id="cam_strafe", type = CONTROL_TYPE.AXIS, checkGroup = ctrlGroups.REPLAY, checkAssign = false }
    { id="cam_vert", type = CONTROL_TYPE.AXIS, checkGroup = ctrlGroups.REPLAY, checkAssign = false }
    { id="cam_roll", type = CONTROL_TYPE.AXIS, checkGroup = ctrlGroups.REPLAY, checkAssign = false, dontCheckDupes = true }
    { id="ID_REPLAY_RESET_CAMERA_ROLL", checkGroup = ctrlGroups.REPLAY, checkAssign = false, dontCheckDupes = true }
    { id="ID_REPLAY_TOGGLE_PLAYER_VISIBILITY", checkGroup = ctrlGroups.REPLAY, checkAssign = false, dontCheckDupes = true }
    { id="ID_REPLAY_TOGGLE_DOF", checkGroup = ctrlGroups.REPLAY, checkAssign = false, dontCheckDupes = true }
    { id="ID_SPECTATOR_CAMERA_ROTATION", checkGroup = ctrlGroups.REPLAY, checkAssign = false
      autobind_sc = [SHORTCUT.MOUSE_RIGHT_BUTTON]
    }

    { id="ID_REPLAY_TRACK_ADD_KEYFRAME",
      checkGroup = ctrlGroups.REPLAY, checkAssign = false, dontCheckDupes = true, showFunc = isExperimentalCameraTrack }
    { id="ID_REPLAY_TRACK_REMOVE_KEYFRAME",
      checkGroup = ctrlGroups.REPLAY, checkAssign = false, dontCheckDupes = true, showFunc = isExperimentalCameraTrack }
    { id="ID_REPLAY_TRACK_PLAY_STOP",
      checkGroup = ctrlGroups.REPLAY, checkAssign = false, dontCheckDupes = true, showFunc = isExperimentalCameraTrack }
    { id="ID_REPLAY_TRACK_CLEAR_ALL",
      checkGroup = ctrlGroups.REPLAY, checkAssign = false, dontCheckDupes = true, showFunc = isExperimentalCameraTrack }
    { id="ID_REPLAY_TOGGLE_LERP",
      checkGroup = ctrlGroups.REPLAY, checkAssign = false, dontCheckDupes = true, showFunc = isExperimentalCameraTrack }
]

::shortcutsAxisList <- [
  { id="rangeMax", type = CONTROL_TYPE.AXIS_SHORTCUT, symbol = "controls/rangeMax_symbol" }
  { id="rangeMin", type = CONTROL_TYPE.AXIS_SHORTCUT, symbol = "controls/rangeMin_symbol" }
  { id="rangeSet", type = CONTROL_TYPE.AXIS_SHORTCUT, symbol = "controls/rangeSet_symbol" }
  { id="",         type = CONTROL_TYPE.AXIS_SHORTCUT, symbol = "controls/enable_symbol" }
  { id = "keepDisabledValue", type = CONTROL_TYPE.SWITCH_BOX
    value = @(axis) axis.keepDisabledValue
    setValue = @(axis, objValue) axis.keepDisabledValue = objValue
  }
  { id = "deadzone", type = CONTROL_TYPE.SLIDER
    min=0, max=100, step=5, showValueMul = 0.005
    value = @(axis) (axis.innerDeadzone/max_deadzone) * 100
    setValue = @(axis, objValue) axis.innerDeadzone = objValue / 100.0 * max_deadzone
  }
  { id = "nonlinearity", type = CONTROL_TYPE.SLIDER
    min=10, max=max_nonlinearity * 10, step=1, showValueMul = 0.1
    value = @(axis) axis.nonlinearity * 10.0 + 10.0
    setValue = @(axis, objValue) axis.nonlinearity = (objValue / 10.0) - 1.0
  }
  { id = "invertAxis", type = CONTROL_TYPE.SWITCH_BOX
    value = @(axis) axis.inverse
    setValue = @(axis, objValue) axis.inverse = objValue
  }
  { id = "relativeAxis", type = CONTROL_TYPE.SWITCH_BOX
    value = @(axis) axis.relative
    setValue = @(axis, objValue) axis.relative = objValue
    onChangeValue = "onChangeAxisRelative"
  }
  { id = "kRelSpd", type = CONTROL_TYPE.SLIDER
    min=1, max=10, step=1, showValuePercMul = 10
    value = @(axis) sqrt(axis.relSens)*10.0
    setValue = @(axis, objValue) axis.relSens = stdMath.pow(objValue / 10.0, 2)
  }
  { id = "kRelStep", type = CONTROL_TYPE.SLIDER
    min=0, max=50, step=1
    value = @(axis) axis.relStep * 100.0
    setValue = @(axis, objValue) axis.relStep = objValue / 100.0
  }
  { id = "kMul", type = CONTROL_TYPE.SLIDER
    min=20, max=200, step=5, showValueMul = 0.01
    value = @(axis) axis.kMul*100.0
    setValue = @(axis, objValue) axis.kMul = objValue / 100.0
  }
  { id = "kAdd", type = CONTROL_TYPE.SLIDER
    min=-50, max=50, step=1
    value = @(axis) axis.kAdd*50.0
    setValue = @(axis, objValue) axis.kAdd = objValue / 50.0
  }
]

function initShortcutsList(arr)
{
  local shortcutsMap = {}
  for(local i=0; i < arr.len(); i++)
  {
    if (typeof(arr[i]) == "string")
      arr[i] = { id=arr[i] }
    local id = arr[i].id
    if (!("type" in arr[i]))
      arr[i].type <- CONTROL_TYPE.SHORTCUT
    if (arr[i].type == CONTROL_TYPE.AXIS)
    {
      arr[i].axisIndex <- ::get_axis_index(id)
      arr[i].axisName <- id
      arr[i].modifiersId <- {}
    }
    if (!("checkGroup" in arr[i]))
      arr[i].checkGroup <- ctrlGroups.DEFAULT
    if (!("checkAssign" in arr[i]))
      arr[i].checkAssign <- true
    if (!("reqInMouseAim" in arr[i]))
      arr[i].reqInMouseAim <- arr[i].checkAssign
    arr[i].isHidden <- false
    arr[i].shortcutId <- -1

    if (id in shortcutsMap)
      dagor.assertf(false, "Found duplicate shortcut " + id)
    else
      shortcutsMap[id] <- arr[i]
  }
  return shortcutsMap
}

::shortcuts_map <- ::initShortcutsList(::shortcutsList)
::initShortcutsList(::shortcutsAxisList)

function get_shortcut_by_id(shortcutId)
{
  return ::getTblValue(shortcutId, ::shortcuts_map)
}

::controlsHelp_shortcuts <- [
  { id ="ID_BASIC_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
  "ID_FIRE_MGUNS",
  "ID_FIRE_CANNONS",
  "ID_FIRE_ADDITIONAL_GUNS",
  "ID_BAY_DOOR",
  "ID_BOMBS",
  "ID_ROCKETS",
  "ID_SENSOR_SWITCH",
  "ID_SENSOR_MODE_SWITCH",
  "ID_SENSOR_SCAN_PATTERN_SWITCH",
  "ID_SENSOR_RANGE_SWITCH",
  "ID_SENSOR_TARGET_LOCK",
  "ID_SCHRAEGE_MUSIK",
  "ID_GEAR",
  { id="ailerons", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  { id="elevator", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  { id="rudder", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  { id="throttle", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  { id="mouse_aim_x", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  { id="mouse_aim_y", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  "ID_LOCK_TARGET",
  "ID_NEXT_TARGET",
  "ID_PREV_TARGET",
  "ID_RELOAD_GUNS",
  "ID_SHOW_HERO_MODULES",

  { id ="ID_VIEW_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
  "ID_ZOOM_TOGGLE"
  "ID_TARGET_CAMERA", "ID_CAMERA_NEUTRAL",
  "ID_CAMERA_TPS", "ID_CAMERA_FPS", "ID_CAMERA_VIRTUAL_FPS", "ID_CAMERA_GUNNER",
  "ID_CAMERA_BOMBVIEW", "ID_CAMERA_DEFAULT",
  "ID_CAMERA_FOLLOW_OBJECT"
  "ID_TOGGLE_VIEW"

  { id ="ID_MISC_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
  "ID_HELP"
  "ID_GAME_PAUSE",
//  "ID_BAILOUT",
  "ID_TACTICAL_MAP", "ID_MPSTATSCREEN",
  "ID_TOGGLE_CHAT_TEAM",
  "ID_TOGGLE_CHAT"
  "ID_SHOW_VOICE_MESSAGE_LIST"
  "ID_SHOW_VOICE_MESSAGE_LIST_SQUAD"
  "ID_HIDE_HUD"
]

::controlsHelp_shortcuts_ground <- [
  { id ="ID_BASIC_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
  "ID_FIRE_GM",
  { id="gm_throttle", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  { id="gm_steering", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  { id="gm_mouse_aim_x", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  { id="gm_mouse_aim_y", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  "ID_TRANS_GEAR_UP",
  "ID_TRANS_GEAR_DOWN",
  "ID_SUSPENSION_PITCH_UP",
  "ID_SUSPENSION_PITCH_DOWN",
  "ID_SUSPENSION_ROLL_UP",
  "ID_SUSPENSION_ROLL_DOWN",
  "ID_SUSPENSION_CLEARANCE_UP",
  "ID_SUSPENSION_CLEARANCE_DOWN",
  "ID_SUSPENSION_RESET",
  "ID_ACTION_BAR_ITEM_1",
  "ID_ACTION_BAR_ITEM_2",
  "ID_ACTION_BAR_ITEM_3",
  "ID_ACTION_BAR_ITEM_4",
  "ID_ACTION_BAR_ITEM_5",
  "ID_ACTION_BAR_ITEM_6",
  "ID_SHOOT_ARTILLERY",
  "ID_LOCK_TARGET",
  "ID_REPAIR_TANK",
  "ID_SHOW_HERO_MODULES",
  "ID_SMOKE_SCREEN_GENERATOR",

  { id ="ID_VIEW_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
  "ID_ZOOM_TOGGLE"
  "ID_TARGET_CAMERA"
  "ID_CAMERA_NEUTRAL"
  "ID_TOGGLE_VIEW_GM"

  { id ="ID_MISC_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
  "ID_HELP"
  "ID_GAME_PAUSE",
  "ID_TACTICAL_MAP", "ID_MPSTATSCREEN",
  "ID_TOGGLE_CHAT_TEAM",
  "ID_TOGGLE_CHAT"
  "ID_SHOW_VOICE_MESSAGE_LIST"
  "ID_SHOW_VOICE_MESSAGE_LIST_SQUAD"
  "ID_HIDE_HUD"
]

::controlsHelp_shortcuts_naval <- [
  { id = "ID_SHIP_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
  "ID_SHIP_WEAPON_ALL"
  "ID_SHIP_WEAPON_PRIMARY"
  "ID_SHIP_WEAPON_SECONDARY"
  "ID_SHIP_WEAPON_MACHINEGUN"
  "ID_SHIP_WEAPON_TORPEDOES"
  "ID_SHIP_WEAPON_DEPTH_CHARGE"
  "ID_SHIP_WEAPON_ROCKETS"
  "ID_SHIP_WEAPON_MINE"
  "ID_SHIP_SMOKE_SCREEN_GENERATOR"
  { id="ship_main_engine", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  { id="ship_steering", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  { id="submarine_depth", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  "ID_SHIP_ACTION_BAR_ITEM_1",
  "ID_SHIP_ACTION_BAR_ITEM_2",
  "ID_SHIP_ACTION_BAR_ITEM_3",
  "ID_SHIP_ACTION_BAR_ITEM_4",
  "ID_SHIP_ACTION_BAR_ITEM_5",
  "ID_SHIP_ACTION_BAR_ITEM_6",
  "ID_SHIP_ACTION_BAR_ITEM_11",
  "ID_REPAIR_BREACHES",
  "ID_SHIP_ACTION_BAR_ITEM_10",
  "ID_LOCK_TARGET",
  "ID_SHOW_HERO_MODULES",

  { id ="ID_VIEW_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
  "ID_ZOOM_TOGGLE"
  "ID_TARGET_CAMERA"
  "ID_CAMERA_NEUTRAL"
  "ID_TOGGLE_VIEW_SHIP"

  { id ="ID_MISC_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
  "ID_HELP"
  "ID_GAME_PAUSE",
  "ID_TACTICAL_MAP", "ID_MPSTATSCREEN",
  "ID_TOGGLE_CHAT_TEAM",
  "ID_TOGGLE_CHAT"
  "ID_SHOW_VOICE_MESSAGE_LIST"
  "ID_SHOW_VOICE_MESSAGE_LIST_SQUAD"
  "ID_HIDE_HUD"
]

::controlsHelp_shortcuts_helicopter <- [
  { id ="ID_BASIC_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
  "ID_FIRE_HELICOPTER",
  "ID_ROCKETS_HELICOPTER",
  "ID_MISSLE_HELICOPTER",
  "ID_FORWARD_HELICOPTER",
  "ID_BACKWARD_HELICOPTER",
  { id="helicopter_roll", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  { id="helicopter_yaw", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  { id="helicopter_throttle", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  { id="helicopter_pitch", axisShortcuts = ["rangeMin", "rangeMax", ""] }

  { id ="ID_VIEW_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
  "ID_LOCK_TARGET",
  "ID_TARGETING_HOLD_HELICOPTER",
  "ID_TOGGLE_VIEW"

  { id ="ID_MISC_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
  "ID_HELP"
  "ID_TACTICAL_MAP", "ID_MPSTATSCREEN",
  "ID_TOGGLE_CHAT_TEAM",
  "ID_SHOW_VOICE_MESSAGE_LIST"
  "ID_SHOW_VOICE_MESSAGE_LIST_SQUAD"
  "ID_HIDE_HUD"
]

::controlsHelp_shortcuts_submarine <- [
  { id ="ID_SUBMARINE_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
  { id="submarine_main_engine", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  { id="submarine_steering", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  { id="submarine_depth", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  "ID_SUBMARINE_FULL_STOP",
  "ID_SUBMARINE_ACOUSTIC_COUNTERMEASURES",
  "ID_SUBMARINE_ACTION_BAR_ITEM_11",
  "ID_SUBMARINE_REPAIR_BREACHES",

  { id ="ID_SUBMARINE_FIRE_HEADER", type = CONTROL_TYPE.HEADER }
  "ID_SUBMARINE_SWITCH_ACTIVE_SONAR",
  "ID_SUBMARINE_WEAPON_TORPEDOES",
  "ID_TOGGLE_VIEW_SUBMARINE",
  "ID_SUBMARINE_WEAPON_TOGGLE_ACTIVE_SENSOR",
  "ID_SUBMARINE_WEAPON_TOGGLE_SELF_HOMMING",

  { id ="ID_MISC_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
  "ID_HELP"
  "ID_TACTICAL_MAP", "ID_MPSTATSCREEN",
  "ID_TOGGLE_CHAT_TEAM",
  "ID_SHOW_VOICE_MESSAGE_LIST"
  "ID_SHOW_VOICE_MESSAGE_LIST_SQUAD"
  "ID_HIDE_HUD"
]

if (::is_platform_pc) //See AcesApp::makeScreenshot()
{
  local extra = ["ID_SCREENSHOT", "ID_SCREENSHOT_WO_HUD",]
  ::controlsHelp_shortcuts.extend(extra)
  ::controlsHelp_shortcuts_ground.extend(extra)
  ::controlsHelp_shortcuts_naval.extend(extra)
  ::controlsHelp_shortcuts_helicopter.extend(extra)
  ::controlsHelp_shortcuts_submarine.extend(extra)
}

enum AXIS_MODIFIERS {
  NONE = 0x0,
  MIN = 0x8000,
  MAX = 0x4000,
}

//gamepad axes bitmask
enum GAMEPAD_AXIS {
  NOT_AXIS = 0

  LEFT_STICK_HORIZONTAL = 0x1
  LEFT_STICK_VERTICAL = 0x2
  RIGHT_STICK_HORIZONTAL = 0x4
  RIGHT_STICK_VERTICAL = 0x8

  LEFT_TRIGGER = 0x10
  RIGHT_TRIGGER = 0x20

  LEFT_STICK = 0x3
  RIGHT_STICK = 0xC
}

//xinput axes to image
::gamepad_axes_images <- {
  [GAMEPAD_AXIS.NOT_AXIS] = "",
  [GAMEPAD_AXIS.LEFT_STICK_HORIZONTAL] = "@control_l_stick_to_left_n_right",
  [GAMEPAD_AXIS.LEFT_STICK_VERTICAL] = "@control_l_stick_to_up_n_down",
  [GAMEPAD_AXIS.LEFT_STICK] = "@control_l_stick_4",
  [GAMEPAD_AXIS.RIGHT_STICK_HORIZONTAL] = "@control_r_stick_to_left_n_right",
  [GAMEPAD_AXIS.RIGHT_STICK_VERTICAL] = "@control_r_stick_to_up_n_down",
  [GAMEPAD_AXIS.RIGHT_STICK] = "@control_r_stick_4",
  [GAMEPAD_AXIS.LEFT_TRIGGER] = "@control_l_trigger",
  [GAMEPAD_AXIS.RIGHT_TRIGGER] = "@control_r_trigger",

  [GAMEPAD_AXIS.LEFT_STICK_VERTICAL | AXIS_MODIFIERS.MIN] = "@control_l_stick_down",
  [GAMEPAD_AXIS.LEFT_STICK_VERTICAL | AXIS_MODIFIERS.MAX] = "@control_l_stick_up",
  [GAMEPAD_AXIS.LEFT_STICK_HORIZONTAL | AXIS_MODIFIERS.MIN] = "@control_l_stick_left",
  [GAMEPAD_AXIS.LEFT_STICK_HORIZONTAL | AXIS_MODIFIERS.MAX] = "@control_l_stick_right",
  [GAMEPAD_AXIS.RIGHT_STICK_VERTICAL | AXIS_MODIFIERS.MIN] = "@control_r_stick_down",
  [GAMEPAD_AXIS.RIGHT_STICK_VERTICAL | AXIS_MODIFIERS.MAX] = "@control_r_stick_up",
  [GAMEPAD_AXIS.RIGHT_STICK_HORIZONTAL | AXIS_MODIFIERS.MIN] = "@control_r_stick_left",
  [GAMEPAD_AXIS.RIGHT_STICK_HORIZONTAL | AXIS_MODIFIERS.MAX] = "@control_r_stick_right",
}

//mouse axes bitmask
enum MOUSE_AXIS {
  NOT_AXIS = 0x0

  HORIZONTAL_AXIS = 0x1
  VERTICAL_AXIS = 0x2
  WHEEL_AXIS = 0x4

  MOUSE_MOVE = 0x3

  TOTAL = 3
}

::mouse_axes_to_image <- {
  [MOUSE_AXIS.NOT_AXIS] = "",
  [MOUSE_AXIS.HORIZONTAL_AXIS] = "#ui/gameuiskin#mouse_move_l_r",
  [MOUSE_AXIS.VERTICAL_AXIS] = "#ui/gameuiskin#mouse_move_up_down",
  [MOUSE_AXIS.MOUSE_MOVE] = "#ui/gameuiskin#mouse_move_4_sides",
  [MOUSE_AXIS.WHEEL_AXIS] = "#ui/gameuiskin#mouse_center_up_down",

  [MOUSE_AXIS.WHEEL_AXIS | AXIS_MODIFIERS.MIN] = "#ui/gameuiskin#mouse_center_down",
  [MOUSE_AXIS.WHEEL_AXIS | AXIS_MODIFIERS.MAX] = "#ui/gameuiskin#mouse_center_up",
  [MOUSE_AXIS.HORIZONTAL_AXIS | AXIS_MODIFIERS.MIN] = "#ui/gameuiskin#mouse_move_l",
  [MOUSE_AXIS.HORIZONTAL_AXIS | AXIS_MODIFIERS.MAX] = "#ui/gameuiskin#mouse_move_r",
  [MOUSE_AXIS.VERTICAL_AXIS | AXIS_MODIFIERS.MIN] = "#ui/gameuiskin#mouse_move_down",
  [MOUSE_AXIS.VERTICAL_AXIS | AXIS_MODIFIERS.MAX] = "#ui/gameuiskin#mouse_move_up",
}

::autorestore_axis_table <- {
  ["AXIS_DECAL_MOVE_X"] = {
    type = ::AXIS_DECAL_MOVE_X
    id = 0 //gamepad - left stick - horizontal axis
  },
  ["AXIS_DECAL_MOVE_Y"] = {
    type = ::AXIS_DECAL_MOVE_Y
    id = 1 //gamepad - left stick - verical axis
  },
  ["AXIS_HANGAR_CAMERA_X"] = {
    type = ::AXIS_HANGAR_CAMERA_X
    id = 2 //gamepad - right stick - horizontal axis
  },
  ["AXIS_HANGAR_CAMERA_Y"] = {
    type = ::AXIS_HANGAR_CAMERA_Y
    id = 3 //gamepad - right stick - vertical axis
  }
}

function can_change_helpers_mode()
{
  if (!::is_in_flight())
    return true

  local missionBlk = ::DataBlock()
  ::get_current_mission_info(missionBlk)

  foreach(part, block in ::tutorials_to_check)
    if(block.tutorial == missionBlk.name)
      return false
  return true
}

function reset_default_control_settings()
{
  ::set_option_multiplier(::OPTION_AILERONS_MULTIPLIER,         0.79); //::USEROPT_AILERONS_MULTIPLIER
  ::set_option_multiplier(::OPTION_ELEVATOR_MULTIPLIER,         0.64); //::USEROPT_ELEVATOR_MULTIPLIER
  ::set_option_multiplier(::OPTION_RUDDER_MULTIPLIER,           0.43); //::USEROPT_RUDDER_MULTIPLIER
  ::set_option_multiplier(::OPTION_ZOOM_SENSE,                  0); //::USEROPT_ZOOM_SENSE
  ::set_option_multiplier(::OPTION_MOUSE_SENSE,                 0.5); //::USEROPT_MOUSE_SENSE
  ::set_option_multiplier(::OPTION_MOUSE_AIM_SENSE,             0.5); //::USEROPT_MOUSE_AIM_SENSE
  ::set_option_multiplier(::OPTION_GUNNER_VIEW_SENSE,           1); //::USEROPT_GUNNER_VIEW_SENSE
  ::set_option_multiplier(::OPTION_MOUSE_JOYSTICK_DEADZONE,     0.1); //mouseJoystickDeadZone
  ::set_option_multiplier(::OPTION_MOUSE_JOYSTICK_SCREENSIZE,   0.6); //mouseJoystickScreenSize
  ::set_option_multiplier(::OPTION_MOUSE_JOYSTICK_SENSITIVITY,  2); //mouseJoystickSensitivity
  ::set_option_multiplier(::OPTION_MOUSE_JOYSTICK_SCREENPLACE,  0); //mouseJoystickScreenPlace
  ::set_option_multiplier(::OPTION_MOUSE_AILERON_RUDDER_FACTOR, 0.5); //mouseAileronRudderFactor
  ::set_option_multiplier(::OPTION_CAMERA_SMOOTH,               0); //
  ::set_option_multiplier(::OPTION_CAMERA_SPEED,                1.13); //
  ::set_option_multiplier(::OPTION_CAMERA_MOUSE_SPEED,          4); //
  ::set_option_multiplier(::OPTION_AIM_TIME_NONLINEARITY_AIR,   0.0); //
  ::set_option_multiplier(::OPTION_AIM_TIME_NONLINEARITY_TANK,  0.0); //
  ::set_option_multiplier(::OPTION_AIM_TIME_NONLINEARITY_SHIP,  0.0); //
  ::set_option_multiplier(::OPTION_AIM_TIME_NONLINEARITY_SUBMARINE,  0.0); //
  ::set_option_multiplier(::OPTION_AIM_ACCELERATION_DELAY_AIR,  0.5); //
  ::set_option_multiplier(::OPTION_AIM_ACCELERATION_DELAY_TANK, 0.5); //
  ::set_option_multiplier(::OPTION_AIM_ACCELERATION_DELAY_SHIP, 0.5); //
  ::set_option_multiplier(::OPTION_AIM_ACCELERATION_DELAY_SUBMARINE, 0.5); //

  ::set_option_mouse_joystick_square(0); //mouseJoystickSquare
  ::set_option_gain(1); //::USEROPT_FORCE_GAIN
}

function restore_shortcuts(scList, scNames)
{
  local changeList = []
  local changeNames = []
  local curScList = ::get_shortcuts(scNames)
  foreach(idx, sc in curScList)
  {
    local prevSc = scList[idx]
    if (!::isShortcutMapped(prevSc))
      continue

    if (::is_shortcut_equal(sc, prevSc))
      continue

    changeList.append(prevSc)
    changeNames.append(scNames[idx])
  }
  if (!changeList.len())
    return

  ::set_controls_preset("")
  ::set_shortcuts(changeList, changeNames)
}

function switch_helpers_mode_and_option(preset = "")
{
  local joyCurSettings = ::joystick_get_cur_settings()
  if (joyCurSettings.useMouseAim)
    ::set_helpers_mode_and_option(globalEnv.EM_MOUSE_AIM)
  else if (::is_platform_ps4 && preset == ::g_controls_presets.getControlsPresetFilename("thrustmaster_hotas4"))
  {
    if (::getCurrentHelpersMode() == globalEnv.EM_MOUSE_AIM)
      ::set_helpers_mode_and_option(globalEnv.EM_INSTRUCTOR)
  }
  else if (::is_ps4_or_xbox || ::is_platform_shield_tv())
    ::set_helpers_mode_and_option(globalEnv.EM_REALISTIC)
  else if (::getCurrentHelpersMode() == globalEnv.EM_MOUSE_AIM)
    ::set_helpers_mode_and_option(globalEnv.EM_INSTRUCTOR)
}

function apply_joy_preset_xchange(preset, updateHelpersMode = true)
{
  if (!preset)
    preset = ::get_controls_preset()

  if (!preset || preset == "")
    return

  local scToRestore = ::get_shortcuts(::shortcuts_not_change_by_preset)

  ::restore_default_controls(preset)
  ::set_controls_preset(preset)

  local joyCurSettings = ::joystick_get_cur_settings()
  local curJoyParams = ::JoystickParams()
  curJoyParams.setFrom(joyCurSettings)
  ::joystick_set_cur_values(curJoyParams)

  ::restore_shortcuts(scToRestore, ::shortcuts_not_change_by_preset)

  if (::is_platform_pc)
    ::switch_show_console_buttons(preset.find("xinput") != null)

  if (updateHelpersMode)
    ::switch_helpers_mode_and_option(preset)

  ::save_profile_offline_limited()
}

function isShortcutMapped(shortcut)
{
  foreach (button in shortcut)
    if (button && button.dev.len() >= 0)
      foreach(d in button.dev)
        if (d > 0 && d <= JOYSTICK_DEVICE_ID)
            return true
  return false
}

local axisMappedOnMouse = {
  mouse_aim_x            = @(isMouseAimMode) isMouseAimMode ? MOUSE_AXIS.HORIZONTAL_AXIS : MOUSE_AXIS.NOT_AXIS
  mouse_aim_y            = @(isMouseAimMode) isMouseAimMode ? MOUSE_AXIS.VERTICAL_AXIS : MOUSE_AXIS.NOT_AXIS
  gm_mouse_aim_x         = @(isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  gm_mouse_aim_y         = @(isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  ship_mouse_aim_x       = @(isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  ship_mouse_aim_y       = @(isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  helicopter_mouse_aim_x = @(isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  helicopter_mouse_aim_y = @(isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  submarine_mouse_aim_x  = @(isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  submarine_mouse_aim_y  = @(isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  camx                   = @(isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  camy                   = @(isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  gm_camx                = @(isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  gm_camy                = @(isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  ship_camx              = @(isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  ship_camy              = @(isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  helicopter_camx        = @(isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  helicopter_camy        = @(isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
  submarine_camx         = @(isMouseAimMode) MOUSE_AXIS.HORIZONTAL_AXIS
  submarine_camy         = @(isMouseAimMode) MOUSE_AXIS.VERTICAL_AXIS
}
function is_axis_mapped_on_mouse(shortcutId, helpersMode = null, joyParams = null)
{
  return get_mouse_axis(shortcutId, helpersMode, joyParams) != MOUSE_AXIS.NOT_AXIS
}

function get_mouse_axis(shortcutId, helpersMode = null, joyParams = null)
{
  local axis = axisMappedOnMouse?[shortcutId]
  if (axis)
    return axis((helpersMode ?? ::getCurrentHelpersMode()) == globalEnv.EM_MOUSE_AIM)

  if (!joyParams)
  {
    joyParams = ::JoystickParams()
    joyParams.setFrom(::joystick_get_cur_settings())
  }
  for (local i = 0; i < MouseAxis.NUM_MOUSE_AXIS_TOTAL; ++i)
  {
    if (shortcutId == joyParams.getMouseAxis(i))
      return 1 << ::min(i, MOUSE_AXIS.TOTAL - 1)
  }

  return MOUSE_AXIS.NOT_AXIS
}

function gui_start_controls()
{
  if (::is_ps4_or_xbox || ::is_platform_shield_tv())
  {
    local cdb = ::get_local_custom_settings_blk()
    if (!(ps4ControlsModeActivatedParamName in cdb) || cdb[ps4ControlsModeActivatedParamName])
    {
      ::gui_start_controls_console()
      return
    }
  }

  ::gui_start_advanced_controls()
}

function gui_start_advanced_controls()
{
  ::gui_start_modal_wnd(::gui_handlers.Hotkeys)
}

class ::gui_handlers.Hotkeys extends ::gui_handlers.GenericOptions
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/controls.blk"
  sceneNavBlkName = null

  filterValues = null
  filterObjId = null
  filter = null
  lastFilter = null

  navigationHandlerWeak = null
  shouldUpdateNavigationSection = true

  shortcuts = null
  shortcutNames = null
  shortcutItems = null
  modifierSymbols = null

  dontCheckControlsDupes = null
  notAssignedAxis = null

  deviceMapping = null

  inputBox = null

  curJoyParams = null
  backAfterSave = true

  setupAxisMode = -1
  bindAxisNum = -1
  joysticks = null

  controlsGroupsIdList = []
  curGroupId = ""

  forceLoadWizard = false
  changeControlsMode = false
  applyApproved = false

  isAircraftHelpersChangePerformed = false

  function getMainFocusObj()
  {
    return getObj("helpers_mode")
  }

  function getMainFocusObj2()
  {
    return getObj("controls_tbl")
  }

  function initScreen()
  {
    mainOptionsMode = ::get_gui_options_mode()
    ::set_gui_options_mode(::OPTIONS_MODE_GAMEPLAY)

    setupAxisMode = -1
    scene.findObject("hotkeys_update").setUserData(this)

    shortcuts = []
    shortcutNames = []
    shortcutItems = []
    dontCheckControlsDupes = []
    notAssignedAxis = []
    deviceMapping = []

    initNavigation()
    initMainParams()

    if (!fetch_devices_inited_once())
      ::gui_start_controls_type_choice()

    initFocusArray()
  }

  function onSwitchModeButton()
  {
    changeControlsWindowType(true)
    goBack()
  }

  function initMainParams()
  {
    initShortcutsNames()
    curJoyParams = ::JoystickParams()
    curJoyParams.setFrom(::joystick_get_cur_settings())
    updateButtons()

    ::g_controls_manager.restoreHardcodedKeys(::MAX_SHORTCUTS)
    shortcuts = ::get_shortcuts(shortcutNames)
    deviceMapping = ::u.copy(::g_controls_manager.getCurPreset().deviceMapping)

    fillControlsType()
  }

  function initNavigation()
  {
    local handler = ::handlersManager.loadHandler(
      ::gui_handlers.navigationPanel,
      { scene = scene.findObject("control_navigation")
        onSelectCb = ::Callback(doNavigateToSection, this)
        panelWidth        = "0.35@sf, ph"
        // Align to helpers_mode and table first row
        headerHeight      = "0.05@sf + @sf/@pf"
        headerOffsetX     = "0.015@sf"
        headerOffsetY     = "0.015@sf"
        collapseShortcut  = "LB"
        navShortcutGroup  = ::get_option(::USEROPT_GAMEPAD_CURSOR_CONTROLLER).value ? null : "RS"
      })
    registerSubHandler(navigationHandlerWeak)
    navigationHandlerWeak = handler.weakref()
  }

  function fillFilterObj()
  {
    if (filterObjId)
    {
      local filterObj = scene.findObject(filterObjId)
      if (::checkObj(filterObj) && filterValues && filterObj.childrenCount()==filterValues.len() && !::preset_changed)
        return //no need to refill filters
    }

    local modsBlock = null
    foreach(block in ::shortcutsList)
      if ("isFilterObj" in block && block.isFilterObj)
      {
        modsBlock = block
        break
      }

    if (modsBlock == null)
      return

    local options = ::get_option(modsBlock.optionType)

    filterObjId = modsBlock.id
    filterValues = options.values

    local view = { items = [] }
    foreach (idx, item in options.items)
      view.items.append({
        id = "option_" + options.values[idx]
        text = item.text
        selected = options.value == idx
        tooltip = item.tooltip
      })

    local listBoxObj = scene.findObject(modsBlock.id)
    local data = ::handyman.renderCached("gui/commonParts/shopFilter", view)
    guiScene.replaceContentFromText(listBoxObj, data, data.len(), this)
    onOptionsFilter()
  }

  function fillControlsType()
  {
    fillFilterObj()
  }

  function isScriptOpenFileDialogAllowed()
  {
    return ::has_feature("ScriptImportExportControls")
      && "export_current_layout_by_path" in ::getroottable()
      && "import_current_layout_by_path" in ::getroottable()
  }

  function updateButtons()
  {
    local isTutorial = ::get_game_mode() == ::GM_TRAINING
    local isImportExportAllowed = !isTutorial
      && (isScriptOpenFileDialogAllowed() || ::is_platform_windows)

    showSceneBtn("btn_controlsHelp", ::is_platform_pc)
    showSceneBtn("btn_exportToFile", isImportExportAllowed)
    showSceneBtn("btn_importFromFile", isImportExportAllowed)
    showSceneBtn("btn_switchMode", ::is_ps4_or_xbox || ::is_platform_shield_tv())
    showSceneBtn("btn_ps4BackupManager", ::gui_handlers.Ps4ControlsBackupManager.isAvailable())
    showSceneBtn("btn_controlsWizard", !isTutorial && !::is_platform_xboxone)
    showSceneBtn("btn_controlsDefault", !isTutorial && ::is_platform_xboxone)
    showSceneBtn("btn_clearAll", !isTutorial)
  }

  function fillControlGroupsList()
  {
    local groupsList = scene.findObject("controls_groups_list")
    if (!::checkObj(groupsList))
      return

    local curValue = 0
    controlsGroupsIdList = []
    local currentUnit = ::get_player_cur_unit()
    local unitType = ::g_unit_type.INVALID
    local unitTags = []
    if (curGroupId == "" && currentUnit)
    {
      unitType = currentUnit.unitType
      unitTags = ::getTblValue("tags", currentUnit, [])
    }

    for(local i=0; i < ::shortcutsList.len(); i++)
      if (::shortcutsList[i].type == CONTROL_TYPE.HEADER)
      {
        if ("filterShow" in ::shortcutsList[i])
          if (!isInArray(filter, ::shortcutsList[i].filterShow))
            continue
        if ("showFunc" in ::shortcutsList[i])
          if (!::shortcutsList[i].showFunc.bindenv(this)())
            continue

        controlsGroupsIdList.append(::shortcutsList[i].id)
        if (unitType != ::g_unit_type.INVALID
          && unitType == ::getTblValue("unitType", ::shortcutsList[i])
          && (!("unitTag" in ::shortcutsList[i])
            || ::isInArray(::shortcutsList[i].unitTag, unitTags)))
          curGroupId = ::shortcutsList[i].id
        if (::shortcutsList[i].id == curGroupId)
          curValue = controlsGroupsIdList.len()-1
      }

    local view = { tabs = [] }
    foreach(idx, group in controlsGroupsIdList)
      view.tabs.append({
        id = group
        tabName = "#hotkeys/" + group
        navImagesText = ::get_navigation_images_text(idx, controlsGroupsIdList.len())
      })

    local data = ::handyman.renderCached("gui/frameHeaderTabs", view)
    guiScene.replaceContentFromText(groupsList, data, data.len(), this)

    local listValue = groupsList.getValue()
    if (groupsList.getValue() != curValue)
      groupsList.setValue(curValue)
    if (listValue <= 0 && curValue == 0) //when list value == -1 it doesnt send on_select event when we switch value to 0
      onControlsGroupChange()
  }

  function onControlsGroupChange()
  {
    doControlsGroupChange()
  }

  function doControlsGroupChange(forceUpdate = false)
  {
    if (!::checkObj(scene))
      return

    local groupId = scene.findObject("controls_groups_list").getValue()
    if (groupId < 0)
      groupId = 0

    if (!(groupId in controlsGroupsIdList))
      return

    local newGroupId = controlsGroupsIdList[groupId]
    local isGroupChanged = curGroupId != newGroupId
    if (!isGroupChanged && filter==lastFilter && !::preset_changed && !forceUpdate)
      return

    lastFilter = filter
    if (!::preset_changed)
      doApplyJoystick()
    curGroupId = newGroupId
    fillControlGroupTab(curGroupId)

    if (isGroupChanged)
    {
      local controlTblObj = scene.findObject("controls_tbl")
      if (::checkObj(controlTblObj))
        controlTblObj.setValue(::getNearestSelectableChildIndex(controlTblObj, -1, 1))
      updateButtonsChangeValue()
    }
  }

  function fillControlGroupTab(groupId)
  {
    local data = "";
    local joyParams = ::joystick_get_cur_settings();
    local gRow = 0  //for even and odd color by groups
    local isSectionShowed = true
    local isHelpersVisible = false

    local navigationItems = []

    for(local n=0; n < ::shortcutsList.len(); n++)
    {
      if (::shortcutsList[n].id != groupId)
        continue

      isHelpersVisible = ::getTblValue("isHelpersVisible", ::shortcutsList[n])
      for(local i=n+1; i < ::shortcutsList.len(); i++)
      {
        local entry = ::shortcutsList[i]
        if (entry.type == CONTROL_TYPE.HEADER)
          break
        if (entry.type == CONTROL_TYPE.SECTION)
        {
          isSectionShowed =
            (!("filterHide" in entry) || !::isInArray(filter, entry.filterHide)) &&
            (!("filterShow" in entry) || ::isInArray(filter, entry.filterShow)) &&
            (!("showFunc" in entry) || entry.showFunc.call(this))
          if (isSectionShowed)
            navigationItems.append({
              id = entry.id
              text = "#hotkeys/" + entry.id
            })
        }
        if (!isSectionShowed)
          continue

        local hotkeyData = ::buildHotkeyItem(i, shortcuts, entry, joyParams, gRow%2 == 0)
        if (hotkeyData != "")
        {
          data += hotkeyData
          gRow++
        }
      }

      break
    }

    local controlTblObj = scene.findObject("controls_tbl");
    if (::checkObj(controlTblObj))
      guiScene.replaceContentFromText(controlTblObj, data, data.len(), this);
    showSceneBtn("helpers_mode", isHelpersVisible)
    if (navigationHandlerWeak)
    {
      navigationHandlerWeak.setNavItems(navigationItems)
      updateButtonsChangeValue()
    }
    updateSceneOptions()
    optionsFilterApply()
    restoreFocus()
  }

  function doNavigateToSection(navItem)
  {
    local sectionId = navItem.id
    shouldUpdateNavigationSection = false
    local rowIdx = getRowIdxBYId(sectionId)
    local rowId = "table_row_" + rowIdx
    local rowObj = scene.findObject(rowId)

    rowObj.scrollToView(true)
    selectRowByRowIdx(rowIdx)
    shouldUpdateNavigationSection = true
  }

  function checkCurrentNavagationSection()
  {
    local item = getCurItem()
    if (!navigationHandlerWeak || !shouldUpdateNavigationSection || !item)
      return

    local navItems = navigationHandlerWeak.getNavItems()
    if (navItems.len() > 1)
    {
      local navId = null
      for (local i = 0; i < ::shortcutsList.len(); i++)
      {
        local entry = ::shortcutsList[i]
        if (entry.type == CONTROL_TYPE.SECTION)
          navId = entry.id
        if (entry.id != item.id)
          continue

        local curItem = ::u.search(navItems,
          (@(navId) function(item) {return item.id == navId})(navId))
        if (curItem != null)
          navigationHandlerWeak.setCurrentItem(curItem)

        break
      }
    }
  }

  function onUpdate(obj, dt)
  {
    if (!::preset_changed)
      return

    initMainParams()
    ::preset_changed = false
    if (forceLoadWizard)
    {
      forceLoadWizard = false
      onControlsWizard()
    }
  }

  function initShortcutsNames()
  {
    local axisScNames = []
    modifierSymbols = {}

    for(local i=0; i < ::shortcutsAxisList.len(); i++)
      if (::shortcutsAxisList[i].type == CONTROL_TYPE.AXIS_SHORTCUT
          && !isInArray(::shortcutsAxisList[i].id, axisScNames))
      {
        axisScNames.append(::shortcutsAxisList[i].id)
        if ("symbol" in ::shortcutsAxisList[i])
          modifierSymbols[::shortcutsAxisList[i].id] <- ::loc(::shortcutsAxisList[i].symbol) + ::loc("ui/colon")
      }

    shortcutNames = []
    shortcutItems = []

    local addShortcutNames = function(arr)
    {
      for(local i=0; i < arr.len(); i++)
        if (arr[i].type == CONTROL_TYPE.SHORTCUT)
        {
          arr[i].shortcutId = shortcutNames.len()
          shortcutNames.append(arr[i].id)
          shortcutItems.append(arr[i])
        }
    }
    addShortcutNames(::shortcutsList)
    addShortcutNames(::shortcutsAxisList)

    for(local i=0; i < ::shortcutsList.len(); i++)
    {
      local item = ::shortcutsList[i]

      if (item.type != CONTROL_TYPE.AXIS)
        continue

      item.modifiersId = {}
      foreach(name in axisScNames)
      {
        item.modifiersId[name] <- shortcutNames.len()
        shortcutNames.append(item.axisName + ((name=="")?"" : "_" + name))
        shortcutItems.append(item)
      }
    }
  }

  function getSymbol(name)
  {
    if (name in modifierSymbols)
      return "<color=@axisSymbolColor>" + modifierSymbols[name] + "</color>"
    return ""
  }

  function updateAxisText(device, item)
  {
    local itemTextObj = scene.findObject("txt_" + item.id)
    if (!::checkObj(itemTextObj))
      return

    if (device == null)
    {
      itemTextObj.setValue(::loc("joystick/no_available_joystick"))
      return
    }

    local axis = item.axisIndex >= 0
      ? curJoyParams.getAxis(item.axisIndex)
      : ControlsPreset.getDefaultAxis()
    local axisText = ""
    local data = ""
    local curPreset = ::g_controls_manager.getCurPreset()
    if (axis.axisId >= 0)
      axisText = ::remapAxisName(curPreset.getAxisName(axis.axisId))

    if ("modifiersId" in item)
    {
      if ("" in item.modifiersId)
      {
        local activationShortcut = ::get_shortcut_text(shortcuts, item.modifiersId[""], false)
        if (activationShortcut != "")
          data += activationShortcut + " + "
      }
      if (axisText!="")
        data += ::addHotkeyTxt(getSymbol("") + axisText, "")

      //--- options controls list  ---
      foreach(modifier, id in item.modifiersId)
        if (modifier != "")
        {
          local scText = ::get_shortcut_text(shortcuts, id, false)
          if (scText!="")
          {
            data += (data=="" ? "" : ";  ") +
              getSymbol(modifier) +
              scText;
          }
        }
    } else
      data = ::addHotkeyTxt(axisText)

    local notAssignedId = ::find_in_array(notAssignedAxis, item)
    if (data == "")
    {
      data = ::loc("joystick/axis_not_assigned")
      if (notAssignedId<0)
        notAssignedAxis.append(item)
    } else
      if (notAssignedId>=0)
        notAssignedAxis.remove(notAssignedId)

    itemTextObj.setValue(data)
  }

  function updateSceneOptions()
  {
    local device = ::joystick_get_default()

    for(local i=0; i < ::shortcutsList.len(); i++)
    {
      if (::shortcutsList[i].type == CONTROL_TYPE.AXIS && ::shortcutsList[i].axisIndex>=0)
        updateAxisText(device, ::shortcutsList[i])
      else
      if (::shortcutsList[i].type== CONTROL_TYPE.SLIDER)
        updateSliderValue(::shortcutsList[i])
    }
  }

  function getRowIdx(rowObj)
  {
    local id = rowObj.id
    if (!id || id.len() <= 10 || id.slice(0, 10) != "table_row_")
      return -1
    return id.slice(10).tointeger()
  }

  function getRowIdxBYId(id)
  {
    return ::u.searchIndex(::shortcutsList, (@(id) function(s) { return s.id == id })(id))
  }

  function getCurItem()
  {
    local objTbl = scene.findObject("controls_tbl")
    if (!::check_obj(objTbl))
      return null

    local idx = objTbl.getValue()
    if (idx < 0 || objTbl.childrenCount() <= idx)
      return null

    local rowObj = objTbl.getChild(idx)
    local sel = getRowIdx(rowObj)

    if (setupAxisMode >= 0)
      if (sel < 0 || sel >= ::shortcutsAxisList.len())
        return null
      else
        return ::shortcutsAxisList[sel]
    if (sel < 0 || sel >= ::shortcutsList.len())
      return null
    return ::shortcutsList[sel]
  }

  function checkOptionValue(optName, checkValue)
  {
    local obj = scene.findObject(optName)
    if (!obj)
      return false

    local value = obj.getValue()
    return value == checkValue
  }

  function getMouseUsageMask()
  {
    local usage = ::g_aircraft_helpers.getOptionValue(
      ::USEROPT_MOUSE_USAGE)
    local usageNoAim = ::g_aircraft_helpers.getOptionValue(
      ::USEROPT_MOUSE_USAGE_NO_AIM)
    return (usage ? usage : 0) | (usageNoAim ? usageNoAim : 0)
  }

  function applyAirHelpersChange(obj = null)
  {
    if (isAircraftHelpersChangePerformed)
      return
    isAircraftHelpersChangePerformed = true

    if (::checkObj(obj))
    {
      local valueIdx = obj.getValue()
      local item = null
      for(local i = 0; i < ::shortcutsList.len(); i++)
        if (obj.id == ::shortcutsList[i].id)
        {
          item = ::shortcutsList[i]
          break
        }
      if (item != null && "optionType" in item)
        ::set_option(item.optionType, valueIdx)
    }

    local options = ::u.values(::g_aircraft_helpers.controlHelpersOptions)
    foreach (optionId in options)
    {
      if (optionId == ::USEROPT_HELPERS_MODE)
        continue
      local option = ::get_option(optionId)
      local object = scene.findObject(option.id)
      if (::checkObj(object) && object.getValue() != option.value)
        object.setValue(option.value)
    }

    curJoyParams.mouseJoystick = ::getTblValue("mouseJoystick",
      ::g_controls_manager.getCurPreset().params, false)

    isAircraftHelpersChangePerformed = false
  }

  function onAircraftHelpersChanged(obj = null)
  {
    if (isAircraftHelpersChangePerformed)
      return

    applyAirHelpersChange(obj)
    doControlsGroupChangeDelayed(obj)
  }

  function onOptionsFilter(obj = null)
  {
    applyAirHelpersChange(obj)

    if (!filterObjId)
      return

    local filterObj = scene.findObject(filterObjId)
    if (!::checkObj(filterObj))
      return

    local filterId = filterObj.getValue()
    if (!(filterId in filterValues))
      return

    if (!::can_change_helpers_mode() && filter!=null)
    {
      foreach(idx, value in filterValues)
        if (value == filter)
        {
          if (idx != filterId)
            msgBox("cant_change_controls", ::loc("msgbox/tutorial_controls_type_locked"),
                   [["ok", (@(filterObj, idx) function() {
                       if (::checkObj(filterObj))
                         filterObj.setValue(idx)
                     })(filterObj, idx)
                   ]], "ok")
          break
        }
      return
    }
    ::set_control_helpers_mode(filterId);
    filter = filterValues[filterId];
    fillControlGroupsList();
    //doControlsGroupChange();
  }

  function selectRowByControlObj(obj)
  {
    selectRowByRowIdx(getRowIdxBYId(obj.id))
  }

  function selectRowByRowIdx(idx)
  {
    local controlTblObj = scene.findObject("controls_tbl")
    if (!::checkObj(controlTblObj) || idx < 0)
      return

    local id = "table_row_" + idx
    for(local i = 0; i < controlTblObj.childrenCount(); i++)
      if (controlTblObj.getChild(i).id == id)
      {
        if (controlTblObj.getValue() != i)
          controlTblObj.setValue(::getNearestSelectableChildIndex(controlTblObj, i, 1))
        break
      }
  }

  function getFilterObj()
  {
    if (!::check_obj(scene) || !filterObjId)
      return null
    return scene.findObject(filterObjId)
  }

  delayedControlsGroupStrated = false
  function doControlsGroupChangeDelayed(obj = null)
  {
    if (obj)
      selectRowByControlObj(obj) //to correct scroll after refill page

    delayedControlsGroupStrated = true
    guiScene.performDelayed(this, function()
    {
      delayedControlsGroupStrated = false
      local filterOption = ::get_option(::USEROPT_HELPERS_MODE)
      local filterObj = getFilterObj()
      if (::checkObj(filterObj) && filterObj.getValue() != filterOption.value)
        filterObj.setValue(filterOption.value)
      doControlsGroupChange(true)
    })
  }

  function updateHidden()
  {
    for(local i = 0; i < ::shortcutsList.len(); i++)
    {
      local item = ::shortcutsList[i]
      local show = true
      local canBeHidden = true

      if ("filterHide" in item)
      {
        show = !isInArray(filter, item.filterHide)
      } else
      if ("filterShow" in item)
      {
        show = isInArray(filter, item.filterShow)
      } else
        canBeHidden = false

      if ("showFunc" in item)
      {
        show = show && item.showFunc.bindenv(this)()
        canBeHidden = true
      }
      if (!canBeHidden)
        continue

      item.isHidden = !show
    }
  }

  function optionsFilterApply()
  {
    updateHidden()
    local mainTbl = scene.findObject("controls_tbl")
    if (!::checkObj(mainTbl))
      return

    local curRow = mainTbl.cur_row.tointeger()
    local totalRows = mainTbl.childrenCount()

    for(local i=0; i<totalRows; i++)
    {
      local obj = mainTbl.getChild(i)
      local itemIdx = getRowIdx(obj)
      if (itemIdx < 0)
        continue

      local item = ::shortcutsList[itemIdx]
      local show = !item.isHidden

      if (obj)
      {
        obj.hiddenTr = show ? "no" : "yes"
        obj.inactive = (show && item.type != CONTROL_TYPE.HEADER
          && item.type != CONTROL_TYPE.SECTION) ? null : "yes"
      }

      if (curRow == i && !show)
      {
        ::gui_bhv.OptionsNavigator.onShortcutUp.call(::gui_bhv.OptionsNavigator, mainTbl, true)
        curRow=mainTbl.cur_row.tointeger()
      }
    }

    if ((curRow < mainTbl.childrenCount()) && (curRow >= 0))
    {
      local rowObj = mainTbl.getChild(curRow)
      guiScene.performDelayed(this, (@(rowObj) function(dummy) {
        if (::checkObj(rowObj))
          rowObj.scrollToView()
      })(rowObj))
    }

    showSceneBtn("btn_preset", filter!=globalEnv.EM_MOUSE_AIM)
    showSceneBtn("btn_defaultpreset", filter==globalEnv.EM_MOUSE_AIM)

    dontCheckControlsDupes = ::refillControlsDupes()
  }

  function loadPresetWithMsg(msg, presetSelected, askKeyboardDefault=false)
  {
    msgBox(
      "controls_restore_question", msg,
      [
        ["yes", function() {
          if (askKeyboardDefault)
          {
            msgBox("ask_kbd_type", ::loc("controls/askKeyboardWasdType"),
            [
              ["classic", function() {
                applyChoosedPreset(::get_controls_preset_by_selected_type("classic").fileName)
              }],
              ["shooter", function() {
                applyChoosedPreset(::get_controls_preset_by_selected_type("shooter").fileName)
              }]
            ], "classic")
            return
          }

          local preset = "empty_ver1"
          local opdata = ::get_option(::USEROPT_CONTROLS_PRESET)
          if (presetSelected in opdata.values)
            preset = opdata.values[presetSelected]
          else
          {
            if (::is_platform_ps4)
              preset = "empty.ps4"
            else if (::is_platform_xboxone)
              preset = "empty.xboxone"
            else
              forceLoadWizard = true
          }
          preset = ::g_controls_presets.parsePresetName(preset)
          preset = ::g_controls_presets.getHighestVersionPreset(preset)
          applyChoosedPreset(preset.fileName)
        }],
        ["cancel", @() null],
      ], "cancel"
    )
  }

  function applyChoosedPreset(preset)
  {
    ::reset_default_control_settings()
    ::apply_joy_preset_xchange(preset);
    ::preset_changed=true
  }

  function onClearAll()
  {
    backAfterSave = false
    doApply()
    loadPresetWithMsg(::loc("hotkeys/msg/clearAll"), -1)
  }

  function onDefaultPreset()
  {
    backAfterSave = false
    doApply()
    loadPresetWithMsg(::loc("controls/askRestoreDefaults"), 0, true)
  }

  function onButtonReset()
  {
    local item = getCurItem()
    if (!item) return
    if (item.type == CONTROL_TYPE.AXIS)
      return onAxisReset()
    if (!(item.shortcutId in shortcuts))
      return

    guiScene.performDelayed(this, (@(item) function(dummy) {
      if (scene && scene.isValid())
      {
        local obj = scene.findObject("controls_input_root")
        if (obj) guiScene.destroyElement(obj)
      }

      if (!item) return

      shortcuts[item.shortcutId] = []
      ::set_controls_preset("")
      updateShortcutText(item.shortcutId)
    })(item))
  }

  function onTblSelect()
  {
    updateButtonsChangeValue()
  }

  function updateButtonsChangeValue()
  {
    local item = getCurItem()
    if (!item)
      return

    local showScReset = item.type == CONTROL_TYPE.SHORTCUT || item.type == CONTROL_TYPE.AXIS_SHORTCUT
    local showAxisReset = item.type == CONTROL_TYPE.AXIS

    local btnA = scene.findObject("btn_assign")
    if (::checkObj(btnA))
    {
      local btnText = ""
      if (showAxisReset)
        btnText = ::loc("mainmenu/btnEditAxis")
      else if (showScReset)
        btnText = ::loc("mainmenu/btnAssign")

      btnA.show(btnText != "")
      btnA.setValue(btnText)
    }

    showSceneBtn("btn_reset_shortcut", showScReset)
    showSceneBtn("btn_reset_axis", showAxisReset)

    checkCurrentNavagationSection()
  }

  function onTblDblClick()
  {
    local item = getCurItem()
    if (!item) return

    if (item.type == CONTROL_TYPE.AXIS)
      openAxisBox(item)
    else if (item.type == CONTROL_TYPE.SHORTCUT || item.type == CONTROL_TYPE.AXIS_SHORTCUT)
      openShortcutInputBox()
  }

  function openShortcutInputBox()
  {
    ::assignButtonWindow(this, onAssignButton)
  }

  function onAssignButton(dev, btn)
  {
    if (dev.len() > 0 && dev.len() == btn.len())
    {
      local item = getCurItem()
      if (item)
        bindShortcut(dev, btn, item.shortcutId)
    }
  }

  function doBind(devs, btns, shortcutId)
  {
    local event = shortcuts[shortcutId]
    event.append({dev = devs, btn = btns})
    if (event.len() > ::MAX_SHORTCUTS)
      event.remove(0)

    ::set_controls_preset(""); //custom mode
    updateShortcutText(shortcutId)
  }

  function updateShortcutText(shortcutId)
  {
    if (!(shortcutId in shortcuts))
      return

    local item = shortcutItems[shortcutId]
    local obj = scene.findObject("txt_sc_"+shortcutNames[shortcutId])

    if (obj)
      obj.setValue(::get_shortcut_text(shortcuts, shortcutId))

    if (item.type == CONTROL_TYPE.AXIS)
    {
      local device = ::joystick_get_default()
      if (device != null)
        updateAxisText(device, item)
    }
  }

  function bindShortcut(devs, btns, shortcutId)
  {
    if (!(shortcutId in shortcuts))
      return false

    local curBinding = findButtons(devs, btns, shortcutId)
    if (!curBinding || curBinding.len() == 0)
    {
      doBind(devs, btns, shortcutId)
      return false
    }

    for(local i = 0; i < curBinding.len(); i++)
      if (curBinding[i][0]==shortcutId)
        return false

    local msg = ::loc("hotkeys/msg/unbind_question", {
        action=::loc("hotkeys/"+shortcutNames[curBinding[0][0]])
    })
    msgBox("controls_unbind_question", msg, [
      ["add", (@(curBinding, devs, btns, shortcutId) function() {
        doBind(devs, btns, shortcutId)
      })(curBinding, devs, btns, shortcutId)],
      ["replace", (@(curBinding, devs, btns, shortcutId) function() {
        for(local i = curBinding.len() - 1; i >= 0; i--)
        {
          local binding = curBinding[i]
          if (!(binding[1] in shortcuts[binding[0]]))
            continue

          shortcuts[binding[0]].remove(binding[1])
          updateShortcutText(binding[0])
        }
        doBind(devs, btns, shortcutId)
      })(curBinding, devs, btns, shortcutId)],
      ["cancel", function() { }],
    ], "cancel")
    return true
  }

  function findButtons(devs, btns, shortcutId)
  {
    local visibilityMap = getShortcutsVisibilityMap()

    if (::find_in_array(dontCheckControlsDupes, shortcutNames[shortcutId]) >= 0)
      return null

    local res = []

    foreach (index, event in shortcuts)
      if ((shortcutItems[index].checkGroup & shortcutItems[shortcutId].checkGroup) &&
        ::getTblValue(shortcutNames[index], visibilityMap) &&
        ::get_shortcut_autobind(shortcutItems[index]).find(shortcutNames[shortcutId]) < 0 &&
        ::get_shortcut_autobind(shortcutItems[shortcutId]).find(shortcutNames[index]) < 0)
        foreach (button_index, button in event)
        {
          if (!button || button.dev.len() != devs.len())
            continue
          local numEqual = 0
          for (local i = 0; i < button.dev.len(); i++)
            for (local j = 0; j < devs.len(); j++)
              if ((button.dev[i] == devs[j]) && (button.btn[i] == btns[j]))
                numEqual++

          if (numEqual == btns.len() && ::find_in_array(dontCheckControlsDupes, shortcutNames[index]) < 0)
            res.append([index, button_index])
        }
    return res
  }

  function openAxisBox(axisItem)
  {
    if (!curJoyParams || !axisItem || axisItem.axisIndex < 0 )
      return

    local params = {
      owner = this,
      axisItem = axisItem,
      curJoyParams = curJoyParams,
      shortcuts = shortcuts,
      shortcutItems = shortcutItems
    }

    ::gui_start_modal_wnd(::gui_handlers.AxisControls, params)
  }

  function onAxisReset()
  {
    local axisMode = -1
    local item = getCurItem()
    if (item && item.type == CONTROL_TYPE.AXIS)
      axisMode = item.axisIndex

    if (axisMode<0)
      return

    ::set_controls_preset("");
    local axis = curJoyParams.getAxis(axisMode)
    axis.inverse = false
    axis.innerDeadzone = 0
    axis.nonlinearity = 0
    axis.kAdd = 0
    axis.kMul = 1.0
    axis.relSens = 1.0
    axis.relStep = 0
    axis.relative = ::getTblValue("def_relative", item, false)

    if (item)
      foreach(name, idx in item.modifiersId)
        shortcuts[idx] = []

    curJoyParams.bindAxis(axisMode, -1)
    local device = ::joystick_get_default()
    curJoyParams.applyParams(device)
    updateSceneOptions()
  }

  function setAxisBind(axisIdx, bindAxisNum)
  {
    ::set_controls_preset("");
    curJoyParams.bindAxis(axisIdx, bindAxisNum)
    local device = ::joystick_get_default()
    curJoyParams.applyParams(device)
    updateSceneOptions()
  }

  function onChangeAxisRelative(obj)
  {
    if (!obj)
      return

    local isRelative = obj.getValue() == 1
    local txtObj = scene.findObject("txt_rangeMax")
    if (txtObj) txtObj.setValue(::loc(isRelative? "hotkeys/rangeInc" : "hotkeys/rangeMax"))
    txtObj = scene.findObject("txt_rangeMin")
    if (txtObj) txtObj.setValue(::loc(isRelative? "hotkeys/rangeDec" : "hotkeys/rangeMin"))
  }

  function getUnmappedByGroups()
  {
    local isHeaderVisible = true
    local res = []
    local resForHeader = null
    foreach(item in ::shortcutsList)
    {
      if (item.type == CONTROL_TYPE.HEADER)
      {
        isHeaderVisible = !("showFunc" in item) || item.showFunc.call(this)
        if (isHeaderVisible)
        {
          if (resForHeader && resForHeader.list.len() > 0)
            res.append(resForHeader)
          resForHeader = {id = "hotkeys/" + item.id, list = []}
        }
      }
      if (!isHeaderVisible || !item.checkAssign || item.isHidden || !resForHeader)
        continue
      if (filter == globalEnv.EM_MOUSE_AIM && !item.reqInMouseAim)
        continue

      if (item.type == CONTROL_TYPE.SHORTCUT)
      {
        if ((item.shortcutId in shortcuts)
            && !::isShortcutMapped(shortcuts[item.shortcutId]))
          resForHeader.list.append("hotkeys/" + shortcutNames[item.shortcutId])
      }
      else if (item.type == CONTROL_TYPE.AXIS)
      {
        if (::is_axis_mapped_on_mouse(item.id, filter, curJoyParams))
          continue

        local axisId = item.axisIndex >= 0
          ? curJoyParams.getAxis(item.axisIndex).axisId : -1
        if (axisId < 0 && ("modifiersId" in item))
            foreach(name in ["rangeMin", "rangeMax"])
              if (name in item.modifiersId)
              {
                local id = item.modifiersId[name]
                if ((id in shortcuts) && !::isShortcutMapped(shortcuts[id]))
                {
                  local name = "controls/" + item.axisName
                  if (::find_in_array(resForHeader.list, name) < 0)
                    resForHeader.list.append(name)
                }
              }
      }
    }
    if (resForHeader && resForHeader.list.len() > 0)
      res.append(resForHeader)
    return res
  }

  function updateSliderValue(item)
  {
    local valueObj = scene.findObject(item.id+"_value")
    if (!valueObj) return
    local vlObj = scene.findObject(item.id)
    if (!vlObj) return

    local value = vlObj.getValue()
    local valueText = ""
    if ("showValueMul" in item)
      valueText = (item.showValueMul * value).tostring()
    else
      valueText = value * (("showValuePercMul" in item)? item.showValuePercMul : 1) + "%"
    valueObj.setValue(valueText)
  }

  function onSliderChange(obj)
  {
    if (!obj) return
    local id=obj.id
    local tbl = (setupAxisMode>=0)? ::shortcutsAxisList : ::shortcutsList
    foreach(item in tbl)
      if (item.id==id)
        updateSliderValue(item)
  }

  function doApplyJoystick()
  {
    if (curJoyParams == null)
      return

    local axis = null
    if (setupAxisMode>=0)
      axis = curJoyParams.getAxis(setupAxisMode)

    local itemsTotal = axis ? ::shortcutsAxisList.len() : ::shortcutsList.len()
    for(local i=0; i < itemsTotal; i++)
    {
      local item = axis ? ::shortcutsAxisList[i] : ::shortcutsList[i]
      if ((("condition" in item) && !item.condition())
          ||(item.type == CONTROL_TYPE.SHORTCUT))
        continue

      local obj = scene.findObject(item.id)
      if (!::checkObj(obj)) continue

      if ("optionType" in item)
      {
        local value = obj.getValue()
        ::set_option(item.optionType, value)
        continue
      }

      if (item.type== CONTROL_TYPE.MOUSE_AXIS && ("axis_num" in item))
      {
        local value = obj.getValue()
        if (value in item.values)
          if (item.values[value] == "none")
            curJoyParams.setMouseAxis(item.axis_num, "")
          else
            curJoyParams.setMouseAxis(item.axis_num, item.values[value])
      }

      if (!("setValue" in item))
        continue

      local value = obj.getValue()
      if ((item.type == CONTROL_TYPE.SPINNER || item.type== CONTROL_TYPE.DROPRIGHT || item.type== CONTROL_TYPE.LISTBOX)
          && (item.options.len() > 0))
        if (value in item.options)
          item.setValue(axis? axis : curJoyParams, value)

      if (item.type == CONTROL_TYPE.SLIDER)
        item.setValue(axis? axis : curJoyParams, value)
      else if (item.type == CONTROL_TYPE.SWITCH_BOX)
        item.setValue(axis? axis : curJoyParams, value)
    }

    ::joystick_set_cur_settings(curJoyParams)
  }

  function onEventControlsMappingChanged(realMapping)
  {
    shortcuts = fix_shortcuts_and_axes_mapping(deviceMapping, realMapping,
      shortcuts, shortcutNames, CONTROL_TYPE.AXIS, ::shortcutsList)
    deviceMapping = ::u.copy(realMapping)
    fillControlGroupTab(curGroupId)
  }

  function doApply()
  {
    if (!::checkObj(scene))
      return

    applyApproved = true
    ::set_shortcuts(shortcuts, shortcutNames)
    doApplyJoystick()
    save(false)
    backAfterSave = true
  }

  function buildMsgFromGroupsList(list)
  {
    local text = ""
    local colonLocalized = ::loc("ui/colon")
    foreach(groupIdx, group in list)
    {
      if (groupIdx > 0)
        text += "\n"
      text += ::loc(group.id) + colonLocalized + "\n"
      foreach(idx, locId in group.list)
      {
        if (idx != 0)
          text += ", "
        text += ::loc(locId)
      }
    }
    return text
  }

  function changeControlsWindowType(value)
  {
    if (changeControlsMode==value)
      return

    changeControlsMode = value
    ::switchControlsMode(value)
  }

  function goBack()
  {
    onApply()
  }

  function onApply()
  {
    doApply()
  }

  function closeWnd()
  {
    restoreMainOptions()
    ::autobind_shortcuts()
    base.goBack()
  }

  function afterSave()
  {
    if (!backAfterSave)
      return

    local reqList = getUnmappedByGroups()
    if (!reqList.len())
      return closeWnd()

    local msg = ::loc("controls/warningUnmapped") + ::loc("ui/colon") + "\n" +
      buildMsgFromGroupsList(reqList)
    msgBox("not_all_mapped", msg,
    [
      ["resetToDefaults", function()
      {
        changeControlsWindowType(false)
        guiScene.performDelayed(this, onDefaultPreset)
      }],
      ["backToControls", function() {
        changeControlsWindowType(false)
      }],
      ["stillContinue", function()
      {
        guiScene.performDelayed(this, closeWnd)
      }]
    ], "backToControls")
  }

  function onMouseWheel(obj)
  {
    local item = getCurItem()
    if (!item || !("values" in item) || !obj)
      return

    ::set_controls_preset("")
    local value = obj.getValue()
    local axisName = ::getTblValue(value, item.values)
    local zoomPostfix = "zoom"
    if (axisName && axisName.len() >= zoomPostfix.len() && axisName.slice(-4) == zoomPostfix)
    {
      local zoomAxisIndex = ::get_axis_index(axisName)
      if (zoomAxisIndex<0) return

      local axis = curJoyParams.getAxis(zoomAxisIndex)
      if (axis.axisId<0) return

      if (filter==globalEnv.EM_MOUSE_AIM)
      {
        setAxisBind(zoomAxisIndex, -1)
        return
      }

      local device = ::joystick_get_default()
      local curPreset = ::g_controls_manager.getCurPreset()
      local msg = format(::loc("msg/zoomAssignmentsConflict"),
        ::remapAxisName(curPreset.getAxisName(axis.axisId)))
      guiScene.performDelayed(this, @()
        msgBox("zoom_axis_assigned", msg,
        [
          ["replace", (@(zoomAxisIndex) function() {
            setAxisBind(zoomAxisIndex, -1)
          })(zoomAxisIndex)],
          ["cancel", function() {
            if (::check_obj(obj))
              obj.setValue(0)
          }]
        ], "replace"))
    }
    else if (axisName && (axisName == "camx" || axisName == "camy")
      && item.axis_num == MouseAxis.MOUSE_SCROLL)
    {
      local isMouseView = AIR_MOUSE_USAGE.VIEW ==
        ::g_aircraft_helpers.getOptionValue(::USEROPT_MOUSE_USAGE)
      local isMouseViewWhenNoAim = AIR_MOUSE_USAGE.VIEW ==
        ::g_aircraft_helpers.getOptionValue(::USEROPT_MOUSE_USAGE_NO_AIM)

      if (isMouseView || isMouseViewWhenNoAim)
      {
        local msg = isMouseView
          ? ::loc("msg/replaceMouseViewToScroll")
          : ::loc("msg/replaceMouseViewToScrollNoAim")
        guiScene.performDelayed(this, @()
          msgBox("mouse_used_for_view", msg,
          [
            ["replace", function() {
              ::g_aircraft_helpers.setOptionValue(
                ::USEROPT_MOUSE_USAGE, AIR_MOUSE_USAGE.AIM)
              ::g_aircraft_helpers.setOptionValue(
                ::USEROPT_MOUSE_USAGE_NO_AIM, AIR_MOUSE_USAGE.JOYSTICK)
              onAircraftHelpersChanged(null)
            }],
            ["cancel", function() {
              if (::check_obj(obj))
                obj.setValue(0)
            }]
          ], "cancel"))
      }
    }
  }

  function onControlsHelp()
  {
    backAfterSave = false
    doApply()
    ::gui_modal_help(false, HELP_CONTENT_SET.CONTROLS)
  }

  function onControlsWizard()
  {
    backAfterSave = false
    doApply()
    ::gui_modal_controlsWizard()
  }

  function updateCurPresetForExport()
  {
    ::set_shortcuts(shortcuts, shortcutNames)
    doApplyJoystick()

    ::g_controls_manager.clearGuiOptions()
    local curPreset = ::g_controls_manager.getCurPreset()
    local mainOptionsMode = ::get_gui_options_mode()
    ::set_gui_options_mode(::OPTIONS_MODE_GAMEPLAY)
    foreach (item in ::shortcutsList)
      if ("optionType" in item && item.optionType in ::user_option_name_by_idx)
      {
        local optionName = ::user_option_name_by_idx[item.optionType]
        local value = ::get_option(item.optionType).value
        if (value != null)
          curPreset.params[optionName] <- value
      }
    ::set_gui_options_mode(mainOptionsMode)
  }

  function onPs4ManageBackup()
  {
    updateCurPresetForExport()
    ::gui_handlers.Ps4ControlsBackupManager.open()
  }

  function onExportToFile()
  {
    updateCurPresetForExport()

    if (isScriptOpenFileDialogAllowed())
    {
      ::gui_start_modal_wnd(::gui_handlers.FileDialog, {
        isSaveFile = true
        dirPath = ::get_save_load_path()
        pathTag = "controls"
        onSelectCallback = function(path) {
          local isSaved = ::export_current_layout_by_path(path)
          if (!isSaved)
            ::showInfoMsgBox(::loc("msgbox/errorSavingPreset"))
          return isSaved
        }
        extension = "blk"
        currentFilter = "blk"
      })
    }
    else if (!::export_current_layout())
      msgBox("errorSavingPreset", ::loc("msgbox/errorSavingPreset"),
             [["ok", function() {} ]], "ok", { cancel_fn = function() {}})
  }

  function onImportFromFile()
  {
    if (isScriptOpenFileDialogAllowed())
    {
      ::gui_start_modal_wnd(::gui_handlers.FileDialog, {
        isSaveFile = false
        dirPath = ::get_save_load_path()
        pathTag = "controls"
        onSelectCallback = function(path) {
          local isOpened = ::import_current_layout_by_path(path)
          if (isOpened)
            ::preset_changed = true
          else
            ::showInfoMsgBox(::loc("msgbox/errorLoadingPreset"))
          return isOpened && ::is_last_load_controls_succeeded
        }
        extension = "blk"
        currentFilter = "blk"
      })
    }
    else
    {
      if (::import_current_layout())
        ::preset_changed = true
      else
        msgBox("errorLoadingPreset", ::loc("msgbox/errorLoadingPreset"),
               [["ok", function() {} ]], "ok", { cancel_fn = function() {}})
    }
  }

  function afterModalDestroy()
  {
    if (changeControlsMode && applyApproved)
      ::gui_start_controls_console()
  }

  function onOptionsListboxDblClick(obj) {}

  function getShortcutsVisibilityMap()
  {
    local filter = ::getCurrentHelpersMode()
    local isHeaderShowed = true
    local isSectionShowed = true

    local visibilityMap = {}

    foreach (entry in ::shortcutsList)
    {
      local isShowed =
        (!("filterHide" in entry) || !::isInArray(filter, entry.filterHide)) &&
        (!("filterShow" in entry) || ::isInArray(filter, entry.filterShow)) &&
        (!("showFunc" in entry) || entry.showFunc.call(this))
      if (entry.type == CONTROL_TYPE.HEADER)
      {
        isHeaderShowed = isShowed
        isSectionShowed = true
      }
      else if (entry.type == CONTROL_TYPE.SECTION)
        isSectionShowed = isShowed
      visibilityMap[entry.id] <- isShowed && isHeaderShowed && isSectionShowed
    }

    return visibilityMap
  }
}

function refillControlsDupes()
{
  local arr = []
  for(local i = 0; i < ::shortcutsList.len(); i++)
  {
    local item = ::shortcutsList[i]
    if ((item.type == CONTROL_TYPE.SHORTCUT)
        && (item.isHidden || (("dontCheckDupes" in item) && item.dontCheckDupes)))
      arr.append(item.id)
  }
  return arr
}

function buildHotkeyItem(rowIdx, shortcuts, item, params, even, rowParams = "")
{
  if (("condition" in item) && !item.condition())
    return ""

  local trAdd = ::format("id:t='table_row_%d'; even:t='%s'; %s", rowIdx, even? "yes" : "no", rowParams)
  local res = ""
  local elemTxt = ""
  local elemIdTxt = "#controls/" + item.id

  if (item.type == CONTROL_TYPE.SECTION)
  {
    local data = ""
    res = format("tr { %s inactive:t='yes';" +
                   "td { width:t='@controlsLeftRow'; overflow:t='visible';" +
                     "optionBlockHeader { text:t='%s'; }}\n" +
                   "td { width:t='pw-1@controlsLeftRow'; }\n" +
                 "}\n", trAdd, ::getTblValue("title", item, "#hotkeys/" + item.id))
  }
  else if (item.type == CONTROL_TYPE.SHORTCUT || item.type == CONTROL_TYPE.AXIS_SHORTCUT)
  {
    local trName = "#hotkeys/" + ((item.id=="")? "enable" : item.id)
    res = format("tr { %s " +
                   "td { width:t='@controlsLeftRow'; overflow:t='hidden'; optiontext{id:t='%s'; text:t='%s'; }}\n" +
                   "td { width:t='pw-1@controlsLeftRow'; cellType:t='right'; padding-left:t='@optPad';" +
                   " textareaNoTab {id:t='%s'; pos:t='0, 0.5ph-0.5h'; position:t='relative'; text:t='%s'; }}\n" +
                 "}\n",
                 trAdd,
                 "txt_" + item.id,
                 trName,
                 "txt_sc_" + item.id,
                 ::get_shortcut_text(shortcuts, item.shortcutId, true, true))
  }
  else if (item.type == CONTROL_TYPE.AXIS && item.axisIndex >= 0)
  {
    local data = ""
    res = format("tr { id:t='%s'; %s " +
                   "td { width:t='@controlsLeftRow'; overflow:t='hidden'; optiontext{text:t='%s'; }}\n" +
                   "td { width:t='pw-1@controlsLeftRow'; cellType:t='right'; padding-left:t='@optPad';" +
                   " textareaNoTab {id:t='%s'; pos:t='0, 0.5ph-0.5h'; position:t='relative'; text:t='%s'; }}\n" +
                 "}\n",
                 "axis_" + item.axisIndex, trAdd, "#controls/"+item.id, "txt_"+item.id, data)
  }
  else if (item.type == CONTROL_TYPE.SPINNER || item.type== CONTROL_TYPE.DROPRIGHT)
  {
    local createOptFunc = ::create_option_list
    if (item.type== CONTROL_TYPE.DROPRIGHT)
      createOptFunc = ::create_option_dropright

    local callBack = ("onChangeValue" in item)? item.onChangeValue : null

    if ("optionType" in item)
    {
      local config = ::get_option(item.optionType)
      elemIdTxt = "#options/" + config.id
      elemTxt = createOptFunc(item.id, config.items, config.value, callBack, true)
    }
    else if ("options" in item && (item.options.len() > 0))
    {
      local value = ("value" in item)? item.value(params) : 0
      elemTxt = createOptFunc(item.id, item.options, value, callBack, true)
    }
    else
      dagor.debug("Error: No optionType nor options field");
  }
  else if (item.type== CONTROL_TYPE.SLIDER)
  {
    if ("optionType" in item)
    {
      local config = ::get_option(item.optionType)
      elemIdTxt = "#options/" + config.id
      elemTxt = ::create_option_slider(item.id, config.value, "onSliderChange", true, "slider", config)
    }
    else
    {
      local value = ("value" in item)? item.value(params) : 50
      elemTxt = ::create_option_slider(item.id, value.tointeger(), "onSliderChange", true, "slider", item)
    }

    elemTxt += format("activeText{ id:t='%s'; margin-left:t='0.01@sf' } ", item.id+"_value")
  }
  else if (item.type== CONTROL_TYPE.SWITCH_BOX)
  {
    local config = null
    if ("optionType" in item)
    {
      config = ::get_option(item.optionType)
      elemIdTxt = "#options/" + config.id
      config.id = item.id
    }
    else
    {
      local value = ("value" in item)? item.value(params) : false
      config = {
        id = item.id
        value = value
      }
    }
    config.cb <- ::getTblValue("onChangeValue", item)
    elemTxt = ::create_option_switchbox(config)
  }
  else if (item.type== CONTROL_TYPE.MOUSE_AXIS && (item.values.len() > 0) && ("axis_num" in item))
  {
    local value = params.getMouseAxis(item.axis_num)
    local callBack = ("onChangeValue" in item)? item.onChangeValue : null
    local options = []
    for (local i = 0; i < item.values.len(); i++)
      options.append("#controls/" + item.values[i])
    local sel = ::find_in_array(item.values, value)
    if (!(sel in item.values))
      sel = 0
    elemTxt = ::create_option_list(item.id, options, sel, callBack, true)
  }
  else
  {
    res = "tr { display:t='hide'; td {} td { tdiv{} } }"
    dagor.debug("Error: wrong shortcut - " + item.id)
  }

  if (elemTxt!="")
    res += ::format("tr { css-hier-invalidate:t='all'; width:t='pw'; %s " +
                   "td { width:t='@controlsLeftRow'; overflow:t='hidden'; optiontext { text:t ='%s'; }} " +
                   "td { width:t='pw-1@controlsLeftRow'; cellType:t='right'; padding-left:t='@optPad'; %s } " +
                 "}\n",
                 trAdd, elemIdTxt, elemTxt)
  return res
}

function get_shortcut_text(shortcuts, shortcutId, cantBeEmpty = true, strip_tags = false)
{
  if (!(shortcutId in shortcuts))
    return ""

  local data = ""
  for (local i = 0; i < shortcuts[shortcutId].len(); i++)
  {
    local text = ""
    local sc = shortcuts[shortcutId][i]
    local curPreset = ::g_controls_manager.getCurPreset()
    for (local j = 0; j < sc.dev.len(); j++)
      text += ((j != 0)? " + ":"") + ::getLocalizedControlName(
        curPreset.getButtonName(sc.dev[j], sc.btn[j]))

    if (text=="")
      continue

    data = ::addHotkeyTxt(strip_tags? ::g_string.stripTags(text) : text, data)
  }

  if (cantBeEmpty && data=="")
    data = "---"

  return data
}

function addHotkeyTxt(hotkeyTxt, baseTxt="")
{
  return ((baseTxt!="")? baseTxt+", " : "") + "<color=@hotkeyColor>" + hotkeyTxt + "</color>"
}

//works like get_shortcut_text, but returns only first binded shortcut for action
//needed wor hud
function get_first_shortcut_text(shortcutData)
{
  local text = ""
  if (shortcutData.len() > 0)
  {
    local sc = shortcutData[0]

    local curPreset = ::g_controls_manager.getCurPreset()
    for (local j = 0; j < sc.btn.len(); j++)
      text += ((j != 0)? " + " : "") + ::getLocalizedControlName(
        curPreset.getButtonName(sc.dev[j], sc.btn[j]))
  }

  return text
}

function get_shortcut_gamepad_textures(shortcutData)
{
  local res = []
  foreach(sc in shortcutData)
  {
    if (sc.dev.len() <= 0 || sc.dev[0] != JOYSTICK_DEVICE_ID)
      continue

    for (local i = 0; i < sc.dev.len(); i++)
      res.append(gamepadIcons.getTextureByButtonIdx(sc.btn[i]))
    return res
  }
  return res
}

//*************************Functions***************************//

function applySelectedPreset(presetName)
{
  if(::isInArray(presetName, ["keyboard", "keyboard_shooter"]))
    ::set_option(::USEROPT_HELPERS_MODE, globalEnv.EM_MOUSE_AIM)
  return ("config/hotkeys/hotkey." + presetName + ".blk")
}

function getSeparatedControlLocId(text)
{
  local txt = text
  local index_txt = ""

  if (txt.find("Button ") == 0) //"Button 1" in "Button" and "1"
    index_txt = " " + txt.slice("Button ".len())
  else if (txt.find("Button") == 0) //"Button1" in "Button" and "1"
    index_txt = " " + txt.slice("Button".len())

  if (index_txt != "")
    txt = ::loc("key/Button") + index_txt

  return txt
}

function getLocaliazedPS4controlName(text)
{
  local locText = ::loc("xinp/" + text, "")
  if (locText == "")
    locText = ::getSeparatedControlLocId(text)
  return locText
}

function getLocalizedControlName(text) //used in client code for hud. see getRemapButtonName
{
  local locText = ::loc("key/" + text, "")
  if (locText == "")
    locText = ::getLocaliazedPS4controlName(text)
  return locText
}

function remapAxisName(text)
{
  if (text == null)
    return "?"

  if (text.find("Axis ") == 0) //"Axis 1" in "Axis" and "1"
  {
    return ::loc("composite/axis")+text.slice("Axis ".len());
  }
  else if (text.find("Axis") == 0) //"Axis1" in "Axis" and "1"
  {
    return ::loc("composite/axis")+text.slice("Axis".len());
  }

  local locText = ::loc("joystick/" + text, "")
  if (locText == "")
    locText = ::getLocalizedControlName(text)
  return locText
}

function assignButtonWindow(owner, onButtonEnteredFunc)
{
  ::gui_start_modal_wnd(::gui_handlers.assignModalButtonWindow, { owner = owner, onButtonEnteredFunc = onButtonEnteredFunc})
}

class ::gui_handlers.assignModalButtonWindow extends ::gui_handlers.BaseGuiHandlerWT
{
  function initScreen()
  {
    ::set_bind_mode(true);
    guiScene.sleepKeyRepeat(true);
    isListenButton = true;
    scene.select();
  }

  function onButtonEntered(obj)
  {
    if (!isListenButton)
      return;

    dev = [];
    btn = [];
    for (local i = 0; i < 3; i++)
    {
      if (obj["device" + i]!="" && obj["button" + i]!="")
      {
        local devId = obj["device" + i].tointeger();
        local btnId = obj["button" + i].tointeger();
        dagor.debug("onButtonEntered "+i+" "+devId+" "+btnId);
        dev.append(devId);
        btn.append(btnId);
      }
    }
    goBack();
  }

  function onCancelButtonInput(obj)
  {
    goBack();
  }

  function onButtonAdded(obj)
  {
    local curBtnText = ""
    local numButtons = 0
    local curPreset = ::g_controls_manager.getCurPreset()
    for (local i = 0; i < 3; i++)
    {
      local devId = obj["device" + i]
      local btnId = obj["button" + i]
      if (devId != "" && btnId != "")
      {
        devId = devId.tointeger()
        btnId = btnId.tointeger()

        if (numButtons != 0)
          curBtnText += " + "

        local btnName = curPreset.getButtonName(devId, btnId)
        curBtnText += ::getLocalizedControlName(btnName)
        numButtons++
      }
    }
    curBtnText = ::hackTextAssignmentForR2buttonOnPS4(curBtnText)
    scene.findObject("txt_current_button").setValue(curBtnText + ((numButtons < 3)? " + ?" : ""));
  }

  function afterModalDestroy()
  {
    if (dev.len() > 0 && dev.len() == btn.len())
      if (::handlersManager.isHandlerValid(owner) && onButtonEnteredFunc)
        onButtonEnteredFunc.call(owner, dev, btn);
  }

  function onEventAfterJoinEventRoom(event)
  {
    goBack()
  }

  function goBack()
  {
    guiScene.sleepKeyRepeat(false);
    ::set_bind_mode(false);
    isListenButton = false;
    base.goBack();
  }

  owner = null;
  onButtonEnteredFunc = null;
  isListenButton = false;
  dev = [];
  btn = [];

  wndType = handlerType.MODAL
  sceneBlkName = "gui/controlsInput.blk";
}

function hackTextAssignmentForR2buttonOnPS4(mainText)
{
  if (::is_platform_ps4)
  {
    local hack = ::getLocaliazedPS4controlName("R2") + " + " + ::getLocaliazedPS4controlName("MouseLB")
    if (mainText.len() >= hack.len())
    {
      local replaceButtonText = ::getLocaliazedPS4controlName("R2")
      if (mainText.slice(0, hack.len()) == hack)
        mainText = replaceButtonText + mainText.slice(hack.len())
      else if (mainText.slice(mainText.len() - hack.len()) == hack)
        mainText = mainText.slice(0, mainText.len() - hack.len()) + replaceButtonText
    }
  }
  return mainText
}

function switchControlsMode(value)
{
  local cdb = ::get_local_custom_settings_blk()
  if (value == cdb[ps4ControlsModeActivatedParamName])
    return

  cdb[ps4ControlsModeActivatedParamName] = value
  ::save_profile_offline_limited()
}

function getUnmappedControlsForCurrentMission()
{
  local unit = ::get_player_cur_unit()
  local helpersMode = ::getCurrentHelpersMode()
  local required = ::getRequiredControlsForUnit(unit, helpersMode)

  local unmapped = ::getUnmappedControls(required, helpersMode)
  if (::is_in_flight() && ::get_mp_mode() == ::GM_TRAINING)
  {
    local tutorialUnmapped = ::getUnmappedControlsForTutorial(::current_campaign_mission, helpersMode)
    foreach (id in tutorialUnmapped)
      ::u.appendOnce(id, unmapped)
  }
  return unmapped
}

function getCurrentHelpersMode()
{
  local difficulty = ::is_in_flight() ? ::get_mission_difficulty_int() : ::get_current_shop_difficulty().diffCode
  if (difficulty == 2)
    return (::is_platform_pc ? globalEnv.EM_FULL_REAL : globalEnv.EM_REALISTIC)
  local option = ::get_option_in_mode(::USEROPT_HELPERS_MODE, ::OPTIONS_MODE_GAMEPLAY)
  return option.values[option.value]
}

function getUnmappedControlsForTutorial(missionId, helpersMode)
{
  local res = []

  local mis_file = null
  local chapters = ::get_meta_missions_info_by_chapters(::GM_TRAINING)
  foreach(chapter in chapters)
    foreach(m in chapter)
      if (m.name == missionId)
      {
        mis_file = m.mis_file
        break
      }
  local missionBlk = mis_file && ::DataBlock(mis_file)
  if (!missionBlk || !missionBlk.triggers)
    return res

  local tutorialControlAliases = {
    ["ANY"]                = null,
    ["ID_CONTINUE"]        = null,
    ["ID_SKIP_CUTSCENE"]   = null,
    ["ID_FIRE"]            = "ID_FIRE_MGUNS",
    ["ID_TRANS_GEAR_UP"]   = "gm_throttle",
    ["ID_TRANS_GEAR_DOWN"] = "gm_throttle",
    ["ID_ELEVATOR_UP"]     = "elevator",
    ["ID_ELEVATOR_DOWN"]   = "elevator",
    ["ID_AILERONS_LEFT"]   = "ailerons",
    ["ID_AILERONS_RIGHT"]  = "ailerons",
    ["ID_RUDDER_LEFT"]     = "rudder",
    ["ID_RUDDER_RIGHT"]    = "rudder",
  }

  local conditionsList = []
  foreach (trigger in missionBlk.triggers)
  {
    if (typeof(trigger) != "instance")
      continue

    local condition = (trigger.props && trigger.props.conditionsType != "ANY") ? "ALL" : "ANY"

    local shortcuts = []
    if (trigger.conditions)
    {
      foreach (playerShortcutPressed in trigger.conditions % "playerShortcutPressed")
        if (playerShortcutPressed.control)
        {
          local id = playerShortcutPressed.control
          local alias = (id in tutorialControlAliases) ? tutorialControlAliases[id] : id
          if (alias && !::isInArray(alias, shortcuts))
            shortcuts.append(alias)
        }

      foreach (playerWhenOptions in trigger.conditions % "playerWhenOptions")
        if (playerWhenOptions.currentView)
          conditionsList.append({ condition = "ONE", shortcuts = [ "ID_TOGGLE_VIEW" ] })

      foreach (unitWhenInArea in trigger.conditions % "unitWhenInArea")
        if (unitWhenInArea.target == "gears_area")
          conditionsList.append({ condition = "ONE", shortcuts = [ "ID_GEAR" ] })

      foreach (unitWhenStatus in trigger.conditions % "unitWhenStatus")
        if (unitWhenStatus.object_type == "isTargetedByPlayer")
          conditionsList.append({ condition = "ONE", shortcuts = [ "ID_LOCK_TARGET" ] })

      foreach (playerWhenCameraState in trigger.conditions % "playerWhenCameraState")
        if (playerWhenCameraState.state == "fov")
          conditionsList.append({ condition = "ONE", shortcuts = [ "ID_ZOOM_TOGGLE" ] })
    }

    if (shortcuts.len())
      conditionsList.append({ condition = condition, shortcuts = shortcuts })
  }

  foreach (cond in conditionsList)
    if (cond.shortcuts.len() == 1)
      cond.condition = "ALL"

  for (local i = conditionsList.len() - 1; i >= 0; i--)
  {
    local duplicate = false
    for (local j = i - 1; j >= 0; j--)
      if (::u.isEqual(conditionsList[i], conditionsList[j]))
      {
        duplicate = true
        break
      }
    if (duplicate)
      conditionsList.remove(i)
  }

  local controlsList = []
  foreach (cond in conditionsList)
    foreach (id in cond.shortcuts)
      if (!::isInArray(id, controlsList))
        controlsList.append(id)
  local unmapped = ::getUnmappedControls(controlsList, helpersMode, false, false)

  foreach (cond in conditionsList)
  {
    if (cond.condition == "ALL")
      foreach (id in cond.shortcuts)
        if (::isInArray(id, unmapped) && !::isInArray(id, res))
          res.append(id)
  }

  foreach (cond in conditionsList)
  {
    if (cond.condition == "ANY" || cond.condition == "ONE")
    {
      local allUnmapped = true
      foreach (id in cond.shortcuts)
        if (!::isInArray(id, unmapped) || ::isInArray(id, res))
        {
          allUnmapped = false
          break
        }
      if (allUnmapped)
        foreach (id in cond.shortcuts)
          if (!::isInArray(id, res))
          {
            res.append(id)
            if (cond.condition == "ONE")
              break
          }
    }
  }

  res = ::getUnmappedControls(res, helpersMode, true, false)
  return res
}

function getRequiredControlsForUnit(unit, helpersMode)
{
  local controls = []
  if (!unit || ::use_touchscreen)
    return controls

  local unitId = unit.name
  local unitType = unit.unitType

  local actionBarShortcutFormat = null

  local unitBlk = null
  local blkCommonWeapons = null
  local blkWeaponPreset = null
  local blkSensors = null

  local preset = ::g_controls_manager.getCurPreset()

  if (unitType == ::g_unit_type.AIRCRAFT
    && ::isInArray("helicopter", ::getTblValue("tags", unit)))
  {
    controls.append("helicopter_throttle")
    controls.append("helicopter_roll")
    controls.append("ID_FIRE_HELICOPTER")
    controls.append("ID_ROCKETS_HELICOPTER")
    controls.append("ID_MISSLE_HELICOPTER")

    local isHelicopterAimMove =
      ::get_gui_option_in_mode(::USEROPT_HELICOPTER_AIM_MOVE, ::OPTIONS_MODE_GAMEPLAY)
    local isHelicopterAimFire =
      ::get_gui_option_in_mode(::USEROPT_HELICOPTER_AIM_FIRE, ::OPTIONS_MODE_GAMEPLAY)

    if (!isHelicopterAimMove)
    {
      if (preset.getAxis("helicopter_pitch").axisId == -1)
      {
        controls.append("ID_FORWARD_HELICOPTER")
        controls.append("ID_BACKWARD_HELICOPTER")
      }
      controls.append("helicopter_yaw")
    }

    if ((isHelicopterAimMove || isHelicopterAimFire) && ::is_xinput_device())
    {
      controls.append("helicopter_mouse_aim_x")
      controls.append("helicopter_mouse_aim_y")
    }

    return controls;
  }

  if (unitType == ::g_unit_type.AIRCRAFT || unitType == ::g_unit_type.SHIP)
  {
    unitBlk = ::get_full_unit_blk(unitId)
    blkCommonWeapons = unitBlk.commonWeapons || ::DataBlock()
    local curWeaponPresetId = ::is_in_flight() ? ::get_cur_unit_weapon_preset() : ::get_last_weapon(unitId)
    blkWeaponPreset = ::DataBlock()
    if (unitBlk.weapon_presets)
      foreach (idx, preset in (unitBlk.weapon_presets % "preset"))
        if (preset.name == curWeaponPresetId || curWeaponPresetId == "" && idx == 0)
        {
          blkWeaponPreset = ::DataBlock(preset.blk)
          break
        }
    blkSensors = unitBlk.sensors
  }

  if (unitType == ::g_unit_type.AIRCRAFT)
  {
    local fmBlk = ::get_fm_file(unitId, unitBlk)
    local unitControls = fmBlk.AvailableControls || ::DataBlock()

    local isMouseAimMode = helpersMode == globalEnv.EM_MOUSE_AIM
    local gotInstructor = helpersMode == globalEnv.EM_MOUSE_AIM || helpersMode == globalEnv.EM_INSTRUCTOR
    local option = ::get_option_in_mode(::USEROPT_INSTRUCTOR_GEAR_CONTROL, ::OPTIONS_MODE_GAMEPLAY)
    local instructorGearControl = gotInstructor && option.value

    controls = [ "ID_TOGGLE_ENGINE", "throttle" ]

    if (isMouseAimMode)
      controls.extend([ "mouse_aim_x", "mouse_aim_y" ])
    else
    {
      if (unitControls.hasAileronControl)
        controls.append("ailerons")
      if (unitControls.hasElevatorControl)
        controls.append("elevator")
      if (unitControls.hasRudderControl)
        controls.append("rudder")
    }

    if (unitControls.hasGearControl && !instructorGearControl)
      controls.append("ID_GEAR")
    if (unitControls.hasAirbrake)
      controls.append("ID_AIR_BRAKE")
    if (unitControls.hasFlapsControl)
    {
      local shortcuts = ::get_shortcuts([ "ID_FLAPS", "ID_FLAPS_UP", "ID_FLAPS_DOWN" ])
      local flaps   = ::isShortcutMapped(shortcuts[0])
      local flapsUp = ::isShortcutMapped(shortcuts[1])
      local flapsDn = ::isShortcutMapped(shortcuts[2])

      if (!flaps && !flapsUp && !flapsDn)
        controls.append("ID_FLAPS")
      else if (!flaps && !flapsUp && flapsDn)
        controls.append("ID_FLAPS_UP")
      else if (!flaps && flapsUp && !flapsDn)
        controls.append("ID_FLAPS_DOWN")
    }

    local gotMachineGuns = false
    local gotCannons = false
    local gotAdditionalGuns = false
    local gotBombs = false
    local gotTorpedoes = false
    local gotRockets = false
    local gotWeaponLock = false
    local gotSmoke = false
    local gotGunnerTurrets = false
    local gotSchraegeMusik = false

    foreach (weaponSet in [ blkCommonWeapons, blkWeaponPreset ])
    {
      foreach (weapon in (weaponSet % "Weapon"))
      {
        if (weapon.trigger == "machine gun")
          gotMachineGuns = true
        if (weapon.trigger == "cannon")
          gotCannons = true
        if (weapon.trigger == "additional gun")
          gotAdditionalGuns = true
        if (weapon.trigger == "bombs")
          gotBombs = true
        if (weapon.trigger == "torpedoes")
          gotTorpedoes = true
        if (weapon.trigger == "rockets")
          gotRockets = true
        local weaponBlk = ::DataBlock(weapon.blk)
        if ("rocket" in weaponBlk)
          if ("guidance" in weaponBlk.rocket)
            gotWeaponLock = true
        if (weapon.trigger == "smoke")
          gotSmoke = true
        if (type(weapon.trigger) == "string" && weapon.trigger.len() > 6 && weapon.trigger.slice(0, 6) == "gunner")
          gotGunnerTurrets = true
        if (::is_platform_pc && weapon.schraegeMusikAngle != null)
          gotSchraegeMusik = true
      }
    }
    local gotSensors = false
    if (blkSensors != null)
      foreach (sensor in (blkSensors % "sensor"))
        gotSensors = true;
    if (preset.getAxis("fire").axisId == -1)
    {
      if (gotMachineGuns || !gotCannons && (gotGunnerTurrets || gotSchraegeMusik)) // Gunners require either Mguns or Cannons shortcut.
        controls.append("ID_FIRE_MGUNS")
      if (gotCannons)
        controls.append("ID_FIRE_CANNONS")
      if (gotAdditionalGuns)
        controls.append("ID_FIRE_ADDITIONAL_GUNS")
    }
    if (gotBombs || gotTorpedoes)
      controls.append("ID_BOMBS")
    if (gotRockets)
      controls.append("ID_ROCKETS")
    if (gotWeaponLock)
      controls.append("ID_WEAPON_LOCK")
    if (gotSensors)
    {
      controls.append("ID_SENSOR_SWITCH")
      controls.append("ID_SENSOR_MODE_SWITCH")
      controls.append("ID_SENSOR_SCAN_PATTERN_SWITCH")
      controls.append("ID_SENSOR_RANGE_SWITCH")
      controls.append("ID_SENSOR_TARGET_LOCK")
    }
    if (gotSchraegeMusik)
      controls.append("ID_SCHRAEGE_MUSIK")
  }
  else if (unitType == ::g_unit_type.TANK)
  {
    controls = [ "gm_throttle", "gm_steering", "gm_mouse_aim_x", "gm_mouse_aim_y", "ID_TOGGLE_VIEW_GM", "ID_FIRE_GM", "ID_REPAIR_TANK" ]

    if (::is_platform_pc && !::is_xinput_device())
    {
      if (::shop_is_modification_enabled(unitId, "manual_extinguisher"))
        controls.append("ID_ACTION_BAR_ITEM_6")
      if (::shop_is_modification_enabled(unitId, "art_support"))
      {
        controls.append("ID_ACTION_BAR_ITEM_5")
        controls.append("ID_SHOOT_ARTILLERY")
      }
    }

    local gameParams = ::dgs_get_game_params()
    local missionDifficulty = ::get_mission_difficulty()
    local difficultyName = ::g_difficulty.getDifficultyByName(missionDifficulty).settingsName
    local difficultySettings = gameParams?.difficulty_settings?.baseDifficulty?[difficultyName]

    local unit = ::get_player_cur_unit()
    local tags = unit?.tags || []
    local scoutPresetId = difficultySettings?.scoutPreset || ""
    if (::has_feature("ActiveScouting") && tags.find("scout") != null
      && gameParams?.scoutPresets?[scoutPresetId]?.enabled)
      controls.append("ID_SCOUT")

    actionBarShortcutFormat = "ID_ACTION_BAR_ITEM_%d"
  }
  else if (unitType == ::g_unit_type.SHIP)
  {
    controls = ["ship_steering", "ID_TOGGLE_VIEW_SHIP"]

    local isSeperatedEngineControl =
      ::get_gui_option_in_mode(::USEROPT_SEPERATED_ENGINE_CONTROL_SHIP, ::OPTIONS_MODE_GAMEPLAY)
    if (isSeperatedEngineControl)
      controls.extend(["ship_port_engine", "ship_star_engine"])
    else
      controls.append("ship_main_engine")

    local weaponGroups = [
      {
        triggerGroup = "primary"
        shortcuts = ["ID_SHIP_WEAPON_ALL", "ID_SHIP_WEAPON_PRIMARY"]
      }
      {
        triggerGroup = "secondary"
        shortcuts = ["ID_SHIP_WEAPON_ALL", "ID_SHIP_WEAPON_SECONDARY"]
      }
      {
        triggerGroup = "machinegun"
        shortcuts = ["ID_SHIP_WEAPON_ALL", "ID_SHIP_WEAPON_MACHINEGUN"]
      }
      {
        triggerGroup = "torpedoes"
        shortcuts = ["ID_SHIP_WEAPON_TORPEDOES"]
      }
      {
        triggerGroup = "depth_charge"
        shortcuts = ["ID_SHIP_WEAPON_DEPTH_CHARGE"]
      }
      {
        triggerGroup = "rockets"
        shortcuts = ["ID_SHIP_WEAPON_ROCKETS"]
      }
    ]

    foreach (weaponSet in [ blkCommonWeapons, blkWeaponPreset ])
      foreach (weapon in (weaponSet % "Weapon"))
        foreach (group in weaponGroups)
        {
          if ("isRequired" in group ||
            group.triggerGroup != ::getTblValue("triggerGroup", weapon))
            continue

          group.isRequired <- true
          break
        }

    foreach (group in weaponGroups)
      if ("isRequired" in group)
      {
        local isMapped = false
        foreach (shortcut in group.shortcuts)
          if (preset.getHotkey(shortcut).len() > 0)
          {
            isMapped = true
            break
          }
        if (!isMapped)
          foreach (shortcut in group.shortcuts)
            if (controls.find(shortcut) < 0)
              controls.append(shortcut)
      }

    actionBarShortcutFormat = "ID_SHIP_ACTION_BAR_ITEM_%d"
  }

  if (actionBarShortcutFormat)
  {
    if (::is_platform_pc && !::is_xinput_device())
    {
      local bulletsChoice = 0
      for (local groupIndex = 0; groupIndex < ::BULLETS_SETS_QUANTITY; groupIndex++)
      {
        if (::isBulletGroupActive(unit, groupIndex))
        {
          local bullets = ::get_unit_option(unitId, ::USEROPT_BULLET_COUNT0 + groupIndex)
          if (bullets != null && bullets > 0)
            bulletsChoice++
        }
      }
      if (bulletsChoice > 1)
        for (local i = 0; i < bulletsChoice; i++)
          controls.append(::format(actionBarShortcutFormat, i + 1))
    }
  }

  return controls
}

function getUnmappedControls(controls, helpersMode, getLocNames = true, shouldCheckRequirements = true)
{
  local unmapped = []

  local joyParams = ::JoystickParams()
  joyParams.setFrom(::joystick_get_cur_settings())

  foreach (item in ::shortcutsList)
  {
    if (::isInArray(item.id, controls))
    {
      if (("filterHide" in item) && ::isInArray(helpersMode, item.filterHide)
        || ("filterShow" in item) && !::isInArray(helpersMode, item.filterShow)
        || (shouldCheckRequirements && helpersMode == globalEnv.EM_MOUSE_AIM && !item.reqInMouseAim))
        continue

      if (item.type == CONTROL_TYPE.SHORTCUT)
      {
        local shortcuts = ::get_shortcuts([ item.id ])
        if (shortcuts.len() && !::isShortcutMapped(shortcuts[0]))
          unmapped.append((getLocNames ? "hotkeys/" : "") + item.id)
      }
      else if (item.type == CONTROL_TYPE.AXIS)
      {
        if (::is_axis_mapped_on_mouse(item.id, helpersMode, joyParams))
          continue

        local axisIndex = ::get_axis_index(item.id)
        local axisId = axisIndex >= 0
          ? joyParams.getAxis(axisIndex).axisId : -1
        if (axisId == -1)
        {
          local modifiers = ["rangeMin", "rangeMax"]
          local shortcutsCount = 0
          foreach (modifier in modifiers)
          {
            if (!("hideAxisOptions" in item) || !::isInArray(modifier, item.hideAxisOptions))
            {
              local shortcuts = ::get_shortcuts([ item.id + "_" + modifier ])
              if (shortcuts.len() && ::isShortcutMapped(shortcuts[0]))
                shortcutsCount++
            }
          }
          if (shortcutsCount < modifiers.len())
            unmapped.append((getLocNames ? "controls/" : "") + item.axisName)
        }
      }
    }
  }

  return unmapped
}

function autorestore_preset()
{
  if (::get_controls_preset() != "")
    return

  local pList = ::g_controls_presets.getControlsPresetsList()
  local curPreset = ""

  local scNames = ::get_full_shortcuts_list()
  local curSc = ::get_shortcuts(scNames)

  foreach(preset in pList)
  {
    local blk = ::DataBlock()
    blk.load(::g_controls_presets.getControlsPresetFilename(preset))
    if (!blk)
      continue

    if (!blk.hotkeys || !blk.joysticks)
      continue

    if (!::compare_axis_with_blk(blk.joysticks))
      continue

    if (!::compare_shortcuts_with_blk(scNames, curSc, blk.hotkeys))
      continue

    curPreset = preset
    break
  }

  if (curPreset == "")
    return

  ::g_controls_manager.getCurPreset().setDefaultBasePresetName(curPreset)
  dagor.debug("PRESETS: Autorestore defaultBasePreset to " + curPreset)
}

function get_full_shortcuts_list()
{
  local res = []
  local axisScNames = []
  res.extend(::shortcuts_not_change_by_preset)

  for(local i=0; i < ::shortcutsAxisList.len(); i++)
    if (::shortcutsAxisList[i].type == CONTROL_TYPE.AXIS_SHORTCUT
        && !isInArray(::shortcutsAxisList[i].id, axisScNames))
      axisScNames.append(::shortcutsAxisList[i].id)

  foreach(item in ::shortcutsList)
    if (item.type == CONTROL_TYPE.SHORTCUT)
      ::u.appendOnce(item.id, res)
    else if (item.type == CONTROL_TYPE.AXIS)
      foreach(name in axisScNames)
        ::u.appendOnce(item.axisName + ((name=="")?"" : "_" + name), res)
  return res
}

function compare_shortcuts_with_blk(names, scList, scBlk, dbg = false)
{
  if (names.len() != scList.len())
    return false

  local res = true
  //some shortcuts exist in blk twice, and merged in code. So need to get a full list before analize it.
  local scbList = ::get_shortcuts_from_blk(names, scBlk)
  foreach(idx, scb in scbList)
  {
    local sc = scList[idx]

    if (!scb)
    {
      if (!::isShortcutMapped(sc))
        continue

      res = false
      if (dbg)
      {
        dagor.debug("PRESETS: found unmapped shortcut: " + names[idx])
        debugTableData(sc)
        continue
      }
      break
    }

    if (!::is_shortcut_equal(sc, scb))
    {
      res = false
      if (dbg)
      {
        dagor.debug("PRESETS: not equal shortcuts: " + names[idx])
        debugTableData(sc)
        debugTableData(scb)
        continue
      }
      break
    }
  }
  return res
}

function is_shortcut_equal(sc1, sc2)
{
  if (sc1.len() != sc2.len())
    return false

  foreach(i, sb in sc2)
    if (!::is_bind_in_shortcut(sb, sc1))
      return false
  return true
}

function is_shortcut_display_equal(sc1, sc2)
{
  foreach(i, sb in sc1)
    if (::is_bind_in_shortcut(sb, sc2))
      return true
  return false
}

function is_bind_in_shortcut(bind, shortcut)
{
  foreach(sc in shortcut)
    if (sc.btn.len() == bind.btn.len())
    {
      local same = true
      foreach(ib, btn in bind.btn)
      {
        local i = ::find_in_array(sc.btn, btn)
        if (i < 0 || sc.dev[i] != bind.dev[ib])
        {
          same = false
          break
        }
      }
      if (same)
        return true
    }
  return false
}

function get_shortcuts_from_blk(names, scBlk)
{
  local res = array(names.len(), null)
  foreach(event in scBlk % "event")
  {
    local idx = ::find_in_array(names, event.name)
    if (idx >= 0)
      res[idx] = ::get_shortcut_data_from_blk(event, res[idx])
  }
  return res
}

function get_shortcut_data_from_blk(blk, mergedRes = null)
{
  if (!mergedRes)
    mergedRes = []
  foreach(scBlk in blk % "shortcut")
  {
    local sc = { btn = [], dev = [] }
    foreach(btn in scBlk % "button")
      if (btn.deviceId != null && btn.buttonId != null)
      {
        sc.btn.append(btn.buttonId)
        sc.dev.append(btn.deviceId)
      }
    if (!::is_bind_in_shortcut(sc, mergedRes))
      mergedRes.append(sc)
  }
  return mergedRes
}

function compare_axis_with_blk(blk)
{
  local joyBlk = blk.joystickSettings
  if (!joyBlk)
    return true

  local joyParams = ::JoystickParams()
  joyParams.setFrom(::joystick_get_cur_settings())

  local paramsList = ["isHatViewMouse"
                    "trackIrZoom"
                    "trackIrForLateralMovement"
                    "trackIrAsHeadInTPS"
                    "isMouseLookHold"
                    "holdThrottleForWEP"
                    "useJoystickMouseForVoiceMessage"
                    "useMouseForVoiceMessage"
                    "mouseJoystick"]
  foreach(p in paramsList)
    if (joyBlk[p] != null && joyBlk[p] != joyParams[p])
      return false

  foreach(item in ::shortcutsList)
  {
    if (item.type != CONTROL_TYPE.AXIS)
      continue

    local axisBlk = joyBlk[item.id]
    local axis = joyParams.getAxis(item.axisIndex)
    if (!axisBlk || !axis)
      continue

    if (!::compare_blk_axis(axisBlk, axis))
      return false
  }

  if (joyBlk.mouse)
    foreach(i, value in joyBlk.mouse % "axis")
    {
      local name = ::get_axis_name(value) || ""
      if (name != joyParams.getMouseAxis(i)) //cant get mouse index from joyParams w/o code change
        return false
    }
  return true
}

function compare_blk_axis(blk, axis)
{
  local axisBase = ["axisId",
                    "inverse", "relative",
                    "keepDisabledValue",
                    /*"useSliders"*/ //nonLinearity sliers not use yet
                   ]
  foreach(p in axisBase)
    if (blk[p] != null && blk[p] != axis[p])
      return false

  local axisFloats = ["innerDeadzone", /*"outerDeadzone",*/
                      /*"rangeMin", "rangeMax", */
                      "nonlinearity",
                      "kAdd", "kMul",
                      "relSens", "relStep",
                     ]
  foreach(p in axisFloats)
    if (blk[p] != null && fabs(blk[p] - axis[p]) > 0.001)
      return false

  /*  //nonLinearitySliders not used yet.
  if (blk.useSliders)
    foreach(idx, value in axis.nonLinearitySliders)
      if (blk["nonLinearitySlider" + idx] != value)
        return false
  */
  return true
}

function toggle_shortcut(shortcutName)
{
  ::activate_shortcut(shortcutName, true, true)
}

function set_shortcut_on(shortcutName)
{
  ::activate_shortcut(shortcutName, true, false)
}

function set_shortcut_off(shortcutName)
{
  ::activate_shortcut(shortcutName, false, false)
}

function is_device_connected(devId = null)
{
  if (!devId)
    return false

  local blk = ::DataBlock()
  ::fill_joysticks_desc(blk)

  for (local i = 0; i < blk.blockCount(); i++)
  {
    local device = blk.getBlock(i)
    if (device.disconnected)
      continue

    if (device.devId && device.devId == devId)
      return true
  }

  return false
}

function check_joystick_thustmaster_hotas(changePreset = true)
{
  if (!::is_platform_ps4 || !::g_login.isLoggedIn())
    return false

  if (!::is_device_connected(::hotas4_device_id))
    return false

  return changePreset? ::ask_hotas4_preset_change() : true
}

function ask_hotas4_preset_change()
{
  if (::loadLocalByAccount("wnd/detectThrustmasterHotas", false))
    return

  local preset = ::g_controls_presets.getCurrentPreset()
  if (preset.name.find("dualshock4") == null && preset.name.find("default") == null)
  {
    ::saveLocalByAccount("wnd/detectThrustmasterHotas", true)
    return
  }

  ::scene_msg_box("change_preset_hotas4", null,
    ::loc("msgbox/controller_hotas4_found"),
    [
      ["ok", function() {
          ::apply_joy_preset_xchange(::g_controls_presets.getControlsPresetFilename("thrustmaster_hotas4"))
          ::saveLocalByAccount("wnd/detectThrustmasterHotas", true)
        }
      ],
      ["cancel", function() {
        ::saveLocalByAccount("wnd/detectThrustmasterHotas", true)
      }]
    ], "ok")
}
