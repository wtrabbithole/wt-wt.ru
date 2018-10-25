class ::Input.Axis extends ::Input.InputBase
{
  //from ::JoystickParams().getAxis()
  axisId = null
  //AXIS_MODIFIERS
  axisModifyer = null

  deviceId = null

  //its impossible to determine mouse axis without shortcut id
  //so we cache it on construction to not to keep shortcut id all the time
  mouseAxis = null

  // @deviceAxisDescription is a result of g_shortcut_type::_getDeviceAxisDescription
  constructor (deviceAxisDescription, axisMod = AXIS_MODIFIERS.NONE)
  {
    deviceId = deviceAxisDescription.deviceId
    axisId = deviceAxisDescription.axisId
    mouseAxis = deviceAxisDescription.mouseAxis
    axisModifyer = axisMod
  }

  function getMarkup()
  {
    local data = getMarkupData()
    return ::handyman.renderCached(data.template, data.view)
  }

  function getMarkupData()
  {
    local data = {
      template = ""
      view = {}
    }

    if (deviceId == ::JOYSTICK_DEVICE_0_ID)
    {
      local axis = GAMEPAD_AXIS.NOT_AXIS
      if (axisId >= 0)
        axis = 1 << axisId
      data.view.buttonImage <- ::getTblValue(axis | axisModifyer, ::gamepad_axes_images, "")

      data.template = "gui/shortcutAxis"
    }
    else if (deviceId == ::STD_MOUSE_DEVICE_ID)
    {
      data.template = "gui/shortcutAxis"
      data.view.buttonImage <- ::getTblValue(mouseAxis | axisModifyer, ::mouse_axes_to_image, "")
    }
    else
    {
      data.view.text <- getText()
      data.template = "gui/keyboardButton"
    }

    return data
  }

  function getText()
  {
    local device = ::joystick_get_default()
    if (!device)
      return ""
    local curPreset = ::g_controls_manager.getCurPreset()
    return ::remapAxisName(curPreset, axisId)
  }

  function getDeviceId()
  {
    return deviceId
  }
}
