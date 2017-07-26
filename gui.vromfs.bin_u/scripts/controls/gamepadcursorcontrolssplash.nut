function gui_start_gamepad_cursor_controls_splash(onEnable)
{
  ::gui_start_modal_wnd(::gui_handlers.GampadCursorControlsSplash, {onEnable = onEnable})
}


class ::gui_handlers.GampadCursorControlsSplash extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/controls/gamepadCursorControlsSplash.blk"
  onEnable = null


  controller360View =
  {
    gampadImage = "#ui/images/controller/controller_xbox360"
    rightTrigger = {
     contactPointX = "pw-510"
     contactPointY = "297"
    }
    leftStick = {
      contactPointX = "470"
      contactPointY = "452"
    }
    rightStick = {
      contactPointX = "pw-570"
      contactPointY = "550"
    }
  }


  controllerDualshock4View =
  {
    gampadImage = "#ui/images/controller/controller_dualshock4"
    rightTrigger = {
     contactPointX = "pw-432"
     contactPointY = "297"
    }
    leftStick = {
      contactPointX = "520"
      contactPointY = "552"
    }
    rightStick = {
      contactPointX = "pw-542"
      contactPointY = "560"
    }
  }


  static function isDisplayed()
  {
    return ::loadLocalByAccount("gamepad_cursor_controls_splash_displayed", false)
  }


  static function markDisplayed()
  {
    ::saveLocalByAccount("gamepad_cursor_controls_splash_displayed", true)
  }


  function initScreen()
  {
    local contentObj = scene.findObject("content")
    if (!::check_obj(contentObj))
      goBack()

    local view = ::is_platform_ps4 ? controllerDualshock4View : controller360View
    local markUp = ::handyman.renderCached("gui/controls/gamepadCursorcontrolsController", view)
    guiScene.replaceContentFromText(contentObj, markUp, markUp.len(), this)
  }


  function enableGamepadCursorcontrols()
  {
    if (::g_gamepad_cursor_controls.canChangeValue())
    {
      ::g_gamepad_cursor_controls.setValue(true)
      if (onEnable)
        onEnable()
    }
    goBack()
  }


  function goBack()
  {
    markDisplayed()
    base.goBack()
  }


  function getNavbarTplView()
  {
    return {
      middle = [
        {
          text = "#gamepad_cursor_control_splash/accept"
          shortcut = "A"
          funcName = "enableGamepadCursorcontrols"
          isToBattle = true
          button = true
        }
      ]
      left = [
        {
          text = "#gamepad_cursor_control_splash/decline"
          shortcut = "B"
          funcName = "goBack"
          button = true
        }
      ]
    }
  }
}
