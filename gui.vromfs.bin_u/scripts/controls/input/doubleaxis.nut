class ::Input.DoubleAxis extends ::Input.InputBase
{
  //bit mask array of axis ids from ::JoystickParams().getAxis()
  axisIds = null

  deviceId = null

  function getMarkup()
  {
    local template = "gui/shortcutAxis"
    local view = {}
    if (deviceId == ::JOYSTICK_DEVICE_0_ID)
      view.buttonImage <- ::getTblValue(axisIds, ::gamepad_axes_images, "")
    else if (deviceId == ::STD_MOUSE_DEVICE_ID)
      view.buttonImage <- ::getTblValue(axisIds, ::mouse_axes_to_image, "")

    return ::handyman.renderCached(template, view)
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
