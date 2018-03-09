class ::Input.DoubleAxis extends ::Input.InputBase
{
  //bit mask array of axis ids from ::JoystickParams().getAxis()
  axisIds = null

  deviceId = null

  function getMarkup()
  {
    local data = getMarkupData()
    return ::handyman.renderCached(data.template, data.view)
  }

  function getMarkupData()
  {
    local data = {
      template = "gui/shortcutAxis"
      view = {}
    }

    if (deviceId == ::JOYSTICK_DEVICE_0_ID)
      data.view.buttonImage <- ::getTblValue(axisIds, ::gamepad_axes_images, "")
    else if (deviceId == ::STD_MOUSE_DEVICE_ID)
      data.view.buttonImage <- ::getTblValue(axisIds, ::mouse_axes_to_image, "")

    return data
  }

  function getText()
  {
    return ""
  }

  function getDeviceId()
  {
    return deviceId
  }
}
