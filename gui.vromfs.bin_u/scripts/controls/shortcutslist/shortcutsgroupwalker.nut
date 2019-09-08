return [
  {
    id = "ID_WALKER_CONTROL_HEADER"
    unitType = ::g_unit_type.TANK
    unitTag = "walker"
    showFunc = @() ::has_feature("WalkerControl") || ::get_player_cur_unit()?.isWalker()
    type = CONTROL_TYPE.HEADER
  }
//-------------------------------------------------------
  {
    id = "ID_WALKER_MOVE_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "walker_throttle"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.WALKER
    axisDirection = AxisDirection.Y
    checkAssign = false
  }
  {
    id = "walker_steering"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.WALKER
    axisDirection = AxisDirection.X
    checkAssign = false
  }
  {
    id = "ID_WALKER_TORSO_UP"
    checkGroup = ctrlGroups.WALKER
    checkAssign = false
  }
  {
    id = "ID_WALKER_TORSO_DOWN"
    checkGroup = ctrlGroups.WALKER
    checkAssign = false
  }
  {
    id = "ID_WALKER_BOOST"
    checkGroup = ctrlGroups.WALKER
    checkAssign = false
  }
//-------------------------------------------------------
  {
    id = "ID_WALKER_FIRE_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_FIRE_WALKER"
    checkGroup = ctrlGroups.WALKER
    checkAssign = false
  }
  {
    id = "ID_FIRE_WALKER_SECONDARY_GUN"
    checkGroup = ctrlGroups.WALKER
    checkAssign = false
  }
  {
    id = "ID_FIRE_WALKER_MACHINE_GUN"
    checkGroup = ctrlGroups.WALKER
    checkAssign = false
  }
  {
    id = "ID_FIRE_WALKER_SPECIAL_GUN"
    checkGroup = ctrlGroups.WALKER
    checkAssign = false
  }
  {
    id = "ID_WALKER_SMOKE_SCREEN"
    checkGroup = ctrlGroups.WALKER
    checkAssign = false
  }
//-------------------------------------------------------
  {
    id = "ID_WALKER_VIEW_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_TOGGLE_VIEW_WALKER"
    checkGroup = ctrlGroups.WALKER
    checkAssign = false
  }
  {
    id = "walker_zoom"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.WALKER
    checkAssign = false
  }
  {
    id = "walker_camx"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.WALKER
    reqInMouseAim = false
    axisDirection = AxisDirection.X
    checkAssign = false
  }
  {
    id = "walker_camy"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.WALKER
    reqInMouseAim = false
    axisDirection = AxisDirection.Y
    checkAssign = false
  }
  {
    id = "invert_y_walker"
    type = CONTROL_TYPE.SWITCH_BOX
    optionType = ::USEROPT_INVERTY_WALKER
    onChangeValue = "doControlsGroupChangeDelayed"
  }
  {
    id = "walker_mouse_aim_x"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.WALKER
    reqInMouseAim = false
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    axisDirection = AxisDirection.X
  }
  {
    id = "walker_mouse_aim_y"
    type = CONTROL_TYPE.AXIS
    checkGroup = ctrlGroups.WALKER
    reqInMouseAim = false
    hideAxisOptions = ["rangeSet", "relativeAxis", "kRelSpd", "kRelStep"]
    axisDirection = AxisDirection.Y
  }
  {
    id = "aim_time_nonlinearity_walker"
    type = CONTROL_TYPE.SLIDER
    value = @(joyParams) 100.0 * ::get_option_multiplier(::OPTION_AIM_TIME_NONLINEARITY_WALKER)
    setValue = @(joyParams, objValue)
      ::set_option_multiplier(::OPTION_AIM_TIME_NONLINEARITY_WALKER, objValue / 100.0)
  }
  {
    id = "aim_acceleration_delay_walker"
    type = CONTROL_TYPE.SLIDER
    value = @(joyParams) 100.0 * ::get_option_multiplier(::OPTION_AIM_ACCELERATION_DELAY_WALKER)
    setValue = @(joyParams, objValue)
      ::set_option_multiplier(::OPTION_AIM_ACCELERATION_DELAY_WALKER, objValue / 100.0)
  }
//-------------------------------------------------------
  {
    id = "ID_WALKER_OTHER_HEADER"
    type = CONTROL_TYPE.SECTION
  }
  {
    id = "ID_REPAIR_WALKER"
    checkGroup = ctrlGroups.WALKER
    checkAssign = false
  }
  {
    id = "ID_WALKER_ACTION_BAR_ITEM_1"
    checkGroup = ctrlGroups.WALKER
    checkAssign = false
  }
  {
    id = "ID_WALKER_ACTION_BAR_ITEM_2"
    checkGroup = ctrlGroups.WALKER
    checkAssign = false
  }
  {
    id = "ID_WALKER_ACTION_BAR_ITEM_3"
    checkGroup = ctrlGroups.WALKER
    checkAssign = false
  }
  {
    id = "ID_WALKER_ACTION_BAR_ITEM_4"
    checkGroup = ctrlGroups.WALKER
    checkAssign = false
  }
  {
    id = "ID_WALKER_ACTION_BAR_ITEM_5"
    checkGroup = ctrlGroups.WALKER
    checkAssign = false
    showFunc = @() ::is_platform_pc && !::is_xinput_device()
  }
  {
    id = "ID_WALKER_ACTION_BAR_ITEM_6"
    checkGroup = ctrlGroups.WALKER
    checkAssign = false
  }
  {
    id = "ID_WALKER_ACTION_BAR_ITEM_7"
    checkGroup = ctrlGroups.WALKER
    checkAssign = false
  }
  {
    id = "ID_WALKER_ACTION_BAR_ITEM_8"
    checkGroup = ctrlGroups.WALKER
    checkAssign = false
  }
  {
    id = "ID_WALKER_ACTION_BAR_ITEM_9"
    checkGroup = ctrlGroups.WALKER
    checkAssign = false
  }
  {
    id = "ID_WALKER_ACTION_BAR_ITEM_12"
    checkGroup = ctrlGroups.WALKER
    checkAssign = false
  }
  {
    id = "ID_WALKER_KILLSTREAK_WHEEL_MENU"
    checkGroup = ctrlGroups.WALKER
    checkAssign = false
    showFunc = @() !(::is_platform_pc && !::is_xinput_device())
  }
]