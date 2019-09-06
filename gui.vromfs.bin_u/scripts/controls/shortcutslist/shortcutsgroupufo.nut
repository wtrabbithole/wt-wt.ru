local globalEnv = require_native("globalEnv")

return [
  {
    id = "ID_CONTROL_HEADER_UFO"
    showFunc = @() ::has_feature("UfoControl")
    type = CONTROL_TYPE.HEADER
    unitType = ::g_unit_type.AIRCRAFT
    unitTag = "ufo"
    isHelpersVisible = true
  }
//-------------------------------------------------------
  {
    id = "ID_MODE_HEADER_UFO"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "mouse_usage_ufo"
    type = CONTROL_TYPE.SPINNER
    optionType = ::USEROPT_MOUSE_USAGE
    onChangeValue = "onAircraftHelpersChanged"
  }
  {
    id = "mouse_usage_no_aim_ufo"
    type = CONTROL_TYPE.SPINNER
    showFunc = @() ::has_feature("SimulatorDifficulty") && (getMouseUsageMask() & AIR_MOUSE_USAGE.AIM)
    optionType = ::USEROPT_MOUSE_USAGE_NO_AIM
    onChangeValue = "onAircraftHelpersChanged"
  }
  {
    id = "instructor_enabled_ufo"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = ::USEROPT_INSTRUCTOR_ENABLED
    onChangeValue = "onAircraftHelpersChanged"
  }
  {
    id = "ID_TOGGLE_INSTRUCTOR_UFO"
    checkGroup = ctrlGroups.UFO
    checkAssign = false
  }
//-------------------------------------------------------
  {
    id = "ID_AXES_HEADER_UFO"
    type = CONTROL_TYPE.SECTION
    unitType = ::g_unit_type.AIRCRAFT
    unitTag = "ufo"
  }
  {
    id = "roll_ufo"
    type = CONTROL_TYPE.AXIS
    reqInMouseAim = false
    checkGroup = ctrlGroups.UFO
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
  }
  {
    id = "pitch_ufo"
    type = CONTROL_TYPE.AXIS
    reqInMouseAim = false
    checkGroup = ctrlGroups.UFO
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
  }
  {
    id = "yaw_ufo"
    type = CONTROL_TYPE.AXIS
    reqInMouseAim = false
    checkGroup = ctrlGroups.UFO
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
  }
  {
    id = "thrust_vector_forward_ufo"
    type = CONTROL_TYPE.AXIS
    reqInMouseAim = false
    checkGroup = ctrlGroups.UFO
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    checkAssign = false
  }
  {
    id = "thrust_vector_lateral_ufo"
    type = CONTROL_TYPE.AXIS
    reqInMouseAim = false
    checkGroup = ctrlGroups.UFO
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    checkAssign = false
  }
  {
    id = "thrust_vector_vertical_ufo"
    type = CONTROL_TYPE.AXIS
    reqInMouseAim = false
    checkGroup = ctrlGroups.UFO
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    checkAssign = false
  }
  {
    id = "roll_sens_ufo"
    type = CONTROL_TYPE.SLIDER
    filterHide = [globalEnv.EM_MOUSE_AIM]
    optionType = ::USEROPT_AILERONS_MULTIPLIER
  }
  {
    id = "pitch_sens_ufo"
    type = CONTROL_TYPE.SLIDER
    filterHide = [globalEnv.EM_MOUSE_AIM]
    optionType = ::USEROPT_ELEVATOR_MULTIPLIER
  }
  {
    id = "yaw_sens_ufo"
    type = CONTROL_TYPE.SLIDER
    filterHide = [globalEnv.EM_MOUSE_AIM]
    optionType = ::USEROPT_RUDDER_MULTIPLIER
  }
  {
    id = "invert_y_ufo"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = ::USEROPT_INVERTY_UFO
    onChangeValue = "doControlsGroupChangeDelayed"
  }
  {
    id = "invert_x_ufo"
    type = CONTROL_TYPE.SPINNER
    filterHide = [globalEnv.EM_INSTRUCTOR, globalEnv.EM_REALISTIC, globalEnv.EM_FULL_REAL]
    optionType = ::USEROPT_INVERTX
    showFunc = @() checkOptionValue("invert_y", true)
  }
//-------------------------------------------------------
  {
    id = "ID_FIRE_HEADER_UFO"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_FIRE_LASERGUNS_UFO"
    checkGroup = ctrlGroups.UFO
    conflictGroup = ConflictGroups.UFO_FIRE
  }
  {
    id = "ID_FIRE_RAILGUNS_UFO"
    checkGroup = ctrlGroups.UFO
    conflictGroup = ConflictGroups.UFO_FIRE
  }
  {
    id = "fire_ufo"
    checkGroup = ctrlGroups.UFO
    alternativeIds = [
      "ID_FIRE_LASERGUNS_UFO"
      "ID_FIRE_RAILGUNS_UFO"
    ]
    type = CONTROL_TYPE.AXIS
  }
  {
    id = "ID_TORPEDOES_UFO"
    checkGroup = ctrlGroups.UFO
  }
  {
    id = "ID_TORPEDO_LOCK_UFO"
    checkGroup = ctrlGroups.UFO
  }
//-------------------------------------------------------
  {
    id = "ID_VIEW_HEADER_UFO"
    type = CONTROL_TYPE.SECTION
    unitType = ::g_unit_type.AIRCRAFT
    unitTag = "ufo"
  }
  {
    id = "ID_TOGGLE_VIEW_UFO"
    checkGroup = ctrlGroups.UFO
  }
  {
    id = "invert_y_camera_ufo"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = ::USEROPT_INVERTCAMERAY
  }
  {
    id = "zoom_ufo"
    type = CONTROL_TYPE.AXIS
    checkAssign = false
    checkGroup = ctrlGroups.UFO
  }
  {
    id = "camx_ufo"
    type = CONTROL_TYPE.AXIS
    reqInMouseAim = false,
    axisDirection = AxisDirection.X
    checkGroup = ctrlGroups.UFO
  }
  {
    id = "camy_ufo"
    type = CONTROL_TYPE.AXIS
    reqInMouseAim = false,
    axisDirection = AxisDirection.Y
    checkGroup = ctrlGroups.UFO
  }
  {
    id = "mouse_aim_x_ufo"
    type = CONTROL_TYPE.AXIS
    filterHide = [globalEnv.EM_INSTRUCTOR, globalEnv.EM_REALISTIC, globalEnv.EM_FULL_REAL]
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    axisDirection = AxisDirection.X
    checkGroup = ctrlGroups.UFO
  }
  {
    id = "mouse_aim_y_ufo"
    type = CONTROL_TYPE.AXIS
    filterHide = [globalEnv.EM_INSTRUCTOR, globalEnv.EM_REALISTIC, globalEnv.EM_FULL_REAL]
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    axisDirection = AxisDirection.Y
    checkGroup = ctrlGroups.UFO
  }
//-------------------------------------------------------
  {
    id = "ID_INSTRUCTOR_HEADER_UFO"
    type = CONTROL_TYPE.SECTION
    unitType = ::g_unit_type.AIRCRAFT
    unitTag = "ufo"
    filterShow = [globalEnv.EM_MOUSE_AIM, globalEnv.EM_INSTRUCTOR]
  }
  {
    id = "instructor_ground_avoidance_ufo"
    type = CONTROL_TYPE.SWITCH_BOX
    filterShow = [ globalEnv.EM_MOUSE_AIM, globalEnv.EM_INSTRUCTOR ]
    optionType = ::USEROPT_INSTRUCTOR_GROUND_AVOIDANCE
  }
//-------------------------------------------------------
  {
    id = "ID_OTHER_HEADER_UFO"
    type = CONTROL_TYPE.SECTION
    unitType = ::g_unit_type.AIRCRAFT
    unitTag = "ufo"
  }
  {
    id = "ID_GEAR_UFO"
    checkGroup = ctrlGroups.UFO
  }
]