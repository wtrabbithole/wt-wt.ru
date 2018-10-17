local gamepadIcons = require("scripts/controls/gamepadIcons.nut")

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
    local data = getMarkupData()
    return ::handyman.renderCached(data.template, data.view)
  }

  function getMarkupData()
  {
    local data = {
      template = ""
      view = {}
    }

    if (deviceId == ::JOYSTICK_DEVICE_0_ID && gamepadIcons.hasTextureByButtonIdx(buttonId))
    {
      data.template = "gui/gamepadButton"
      data.view.buttonImage <- gamepadIcons.getTextureByButtonIdx(buttonId)
    }
    else if (deviceId == ::STD_MOUSE_DEVICE_ID && gamepadIcons.hasMouseTexture(buttonId))
    {
      data.template = "gui/gamepadButton"
      data.view.buttonImage <- gamepadIcons.getMouseTexture(buttonId)
    }
    else
    {
      data.template = "gui/keyboardButton"
      data.view.text <- getText()
    }

    return data
  }

  function getText()
  {
    local curPreset = ::g_controls_manager.getCurPreset()
    return ::getLocalizedControlShortName(curPreset.getButtonName(deviceId, buttonId))
  }

  function getDeviceId()
  {
    return deviceId
  }
}
