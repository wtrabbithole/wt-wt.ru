class ::Input.Button extends ::Input.InputBase
{
  deviceId = -1
  buttonId = -1

  constructor(dev, btn)
  {
    deviceId = dev
    buttonId = btn
  }

  function getMarkup()
  {
    local view = {}
    local template = ""
    if (deviceId == ::JOYSTICK_DEVICE_ID && buttonId in ::joystickBtnTextures)
    {
      template = "gui/gamepadButton"
      view.buttonImage <- "#ui/controlskin#" + ::joystickBtnTextures[buttonId]
    }
    else if (deviceId == ::STD_MOUSE_DEVICE_ID && buttonId in mouse_button_texturas)
    {
      template = "gui/gamepadButton"
      view.buttonImage <- "#ui/gameuiskin#" + ::mouse_button_texturas[buttonId]
    }
    else
    {
      template = "gui/keyboardButton"
      view.text <- getText()
    }

    return ::handyman.renderCached(template, view)
  }

  function getText()
  {
    local curPreset = ::g_controls_manager.getCurPreset()
    return ::getLocalizedControlName(curPreset.getButtonName(deviceId, buttonId))
  }

  function getDeviceId()
  {
    return deviceId
  }
}
