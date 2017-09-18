/*
  widget API:
  static createLayout()  - return widget layout

  setContainer(containerObj) - link current widget to current @containerObj (daguiObj)
  validateContent() - validate current widget container (repaceContent layout on invalid)

  setValue(value)
             @value > 0  - setText value and show widget with text
             @value == 0 - hide widget
             @value < 0  - show only icon
             also validateContent when @value != 0

  setWidgetVisible(value)  - set widget visibility  to @value
  setText(text)            - set widget text to @text
                             @text == ""   - hide widgetText
*/

class NewIconWidget
{
  widgetContainerTag = "newIconWidget"
  defaultIcon = "#ui/gameuiskin#new_icon"

  _guiScene = null
  _containerObj = null
  _textObj = null
  _iconObj = null

  icon = null

  function constructor(guiScene, containerObj = null)
  {
    _guiScene = guiScene
    setContainer(containerObj)
  }

  static function createLayout(params = {})
  {
    local view = {
      needContainer = ::getTblValue("needContainer", params, true)
      icon = ::getTblValue("icon", params, ::NewIconWidget.defaultIcon)
    }
    return ::handyman.renderCached("gui/newIconWidget", view)
  }

  function setContainer(containerObj)
  {
    _containerObj = containerObj
    if (::checkObj(_containerObj))
    {
      _containerObj.setUserData(this.weakref())
      validateContent()
    }
  }

  function _updateSubObjects()
  {
    _textObj = _getTextObj()
    _iconObj = _getIconObj()
  }

  function isValidContainerData()
  {
    return ::checkObj(_textObj) && ::checkObj(_iconObj)
  }

  function validateContent()
  {
    if (!::checkObj(_containerObj))
      return
    if (isValidContainerData())
      return

    local needContainer = _containerObj.tag != widgetContainerTag
    local data = createLayout({
                                needContainer = needContainer
                                icon = icon || defaultIcon
                              })
    _guiScene.replaceContentFromText(_containerObj, data, data.len(), this)

    if (needContainer)
      setContainer(_containerObj.findObject("widget_container"))
    else
      _updateSubObjects()
  }

  function setText(newText)
  {
    if (!::checkObj(_textObj))
      return

    _containerObj.widgetClass = (newText == "") ? "" : "text"
    _textObj.setValue(newText)
  }

  function setValue(value)
  {
    if (!isValidContainerData())
      if (value != 0)
        validateContent()
      else
        return

    setWidgetVisible(value != 0)
    setText((value > 0) ? value.tostring() : "")
  }

  function setWidgetVisible(value)
  {
    if (!::checkObj(_containerObj))
      return
    _containerObj.show(value)
    _containerObj.enable(value)
  }

  function setIcon(newIcon)
  {
    icon = newIcon
    if (::checkObj(_iconObj))
      _iconObj["background-image"] = icon
  }

  function _getTextObj()
  {
    if (!::checkObj(_containerObj))
      return
    local obj = _containerObj.findObject("new_icon_widget_text")
    if (!::checkObj(obj))
      return null
    return obj
  }

  function _getIconObj()
  {
    if (!::checkObj(_containerObj))
      return
    local obj = _containerObj.findObject("new_icon_widget_icon")
    return ::checkObj(obj) ? obj : null
  }

  static function getWidgetByObj(obj)
  {
    if (!::checkObj(obj))
      return null
    local widget = obj.getUserData()
    if (widget == null)
      return null
    if (widget instanceof NewIconWidget)
      return widget
    return null
  }
}
