local gamepadIcons = require("scripts/controls/gamepadIcons.nut")

class ::Input.Button extends ::Input.InputBase
{
  deviceId = -1
  buttonId = -1

  preset = null

  constructor(dev, btn, _preset = null)
  {
    deviceId = dev
    buttonId = btn
    preset = _preset || ::g_controls_manager.getCurPreset()
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
    return ::getLocalizedControlName(preset, deviceId, buttonId)
  }

  function getDeviceId()
  {
    return deviceId
  }

  function getImage()
  {
    if (deviceId == ::JOYSTICK_DEVICE_0_ID && gamepadIcons.hasTextureByButtonIdx(buttonId))
      return gamepadIcons.getTextureByButtonIdx(buttonId)
    else if (deviceId == ::STD_MOUSE_DEVICE_ID && gamepadIcons.hasMouseTexture(buttonId))
      return gamepadIcons.getMouseTexture(buttonId)

    return null
  }

  function hasImage ()
  {
    return gamepadIcons.hasMouseTexture(buttonId) || gamepadIcons.hasTextureByButtonIdx(buttonId)
  }

  function getConfig()
  {
    return {
      inputName = "button"
      buttonImage = getImage()
      text = getText()
    }
  }
}
