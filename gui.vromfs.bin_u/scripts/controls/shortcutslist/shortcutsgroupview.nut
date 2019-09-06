return [
//-------------------------------------------------------
  {
    id = "ID_VIEW_CONTROL_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_ZOOM_TOGGLE"
    checkGroup = ctrlGroups.NO_GROUP
  }
  {
    id = "ID_CAMERA_NEUTRAL"
    checkGroup = ctrlGroups.NO_GROUP
    checkAssign = false
    showFunc = @() ::has_feature("EnableMouse")
  }
  {
    id = "mouse_sensitivity"
    type = CONTROL_TYPE.SLIDER
    optionType = ::USEROPT_MOUSE_SENSE
  }
  {
    id = "camera_mouse_speed"
    type = CONTROL_TYPE.SLIDER
    value = @(joyParams) 100.0*(::get_option_multiplier(::OPTION_CAMERA_MOUSE_SPEED) - min_camera_speed) / (max_camera_speed - min_camera_speed)
    setValue = @(joyParams, objValue) ::set_option_multiplier(::OPTION_CAMERA_MOUSE_SPEED, min_camera_speed + (objValue / 100.0) * (max_camera_speed - min_camera_speed))
    showFunc = @() ::has_feature("EnableMouse")
  }
  {
    id = "camera_smooth"
    type = CONTROL_TYPE.SLIDER
    value = @(joyParams) 100.0*::get_option_multiplier(::OPTION_CAMERA_SMOOTH) / max_camera_smooth
    setValue = @(joyParams, objValue) ::set_option_multiplier(::OPTION_CAMERA_SMOOTH, (objValue / 100.0) * max_camera_smooth)
  }
  {
    id = "zoom_sens"
    type = CONTROL_TYPE.SLIDER
    optionType = ::USEROPT_ZOOM_SENSE
  }
  {
    id = "hatview_mouse"
    type = CONTROL_TYPE.SWITCH_BOX
    value = @(joyParams) joyParams.isHatViewMouse
    setValue = function(joyParams, objValue) {
      local prev = joyParams.isHatViewMouse
      joyParams.isHatViewMouse = objValue
      if (prev != objValue)
        ::set_controls_preset("")
    }
  }
  {
    id = "invert_y_spectator"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = ::USEROPT_INVERTY_SPECTATOR
  }
  {
    id = "hangar_camera_x"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.HANGAR
    checkAssign = false
  }
  {
    id = "hangar_camera_y"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.HANGAR
    checkAssign = false
  }
]
