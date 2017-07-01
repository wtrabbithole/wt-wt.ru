/*
  FramedMessageBox is a message box, with visible frame.
  Config {
    pos - required position to show or will be used current mouse position
    align - ["left", "right", "top", "bottom"] - near the setted position
    title - upper tiny text
    message - main small text
    onOpenSound - sound ID to play on box open
    buttons - array of table params, for gui/commonParts/button.tpl
    {
      cb - callback for button, otherwise action will be 'goBack' only.
      * if not exist any button - use closeButtonDefault.
    }
  }
*/

class ::gui_handlers.FramedMessageBox extends ::BaseGuiHandler
{
  wndType      = handlerType.MODAL
  sceneTplName = "gui/framedMessageBox"

  buttons = null
  title = ""
  message = ""
  pos = null
  align = "top"
  onOpenSound = null

  closeButtonDefault = [{
    id = "btn_ok"
    text = "#mainmenu/btnOk"
    shortcut = "A"
    button = true
  }]

  function open(config = {})
  {
    ::handlersManager.loadHandler(::gui_handlers.FramedMessageBox, config)
  }

  function getSceneTplView()
  {
    if (::u.isEmpty(buttons))
      buttons = closeButtonDefault

    foreach(idx, button in buttons)
    {
      buttons[idx].funcName <- "onButtonClick"
      buttons[idx].id <- ::getTblValue("id", button, "button_" + idx)
    }

    return this
  }

  function initScreen()
  {
    local obj = scene.findObject("framed_message_box")
    if (!::checkObj(obj))
      return

    ::g_dagui_utils.setObjPosition(obj, pos || getDefaultPos(), ["1@bw", "1@bottomBarHeight"])
    obj.animation = "show"

    local buttonsObj = scene.findObject("framed_message_box_buttons_place")
    if (::check_obj(buttonsObj))
      buttonsObj.select()

    if (!::u.isEmpty(onOpenSound))
      ::play_gui_sound(onOpenSound)
  }

  function getDefaultPos()
  {
    local buttonsObj = scene.findObject("framed_message_box_buttons_place")
    if (!::check_obj(buttonsObj))
      return ::array(2, 0)

    local pos = ::getPositionToDraw(null, align)
    return ::split(pos, ",")
  }

  function onButtonClick(obj)
  {
    foreach(button in buttons)
      if (button.id == obj.id)
      {
        performAction(::getTblValue("cb", button))
        break
      }

    goBack()
  }

  function performAction(func = null)
  {
    if (!func)
      return

    func()
  }
}
