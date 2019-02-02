local u = require("std/u.nut")

/**
 * Input combination.
 * Container for several elements, which represets single input.
 * It may be a key combination (Ctrl + A) or
 * combinations of several axes (left gamebad trigger + right gamepad trigger.
 */
class ::Input.Combination extends ::Input.InputBase
{
  elements = null


  constructor(_elements = [])
  {
    elements = _elements
  }

  function getMarkup()
  {
    local data = getMarkupData()
    return ::handyman.renderCached(data.template, data.view)
  }

  function getMarkupData()
  {
    local data = {
      template = "gui/combination"
      view = { elements = u.map(elements, @(element) { element = element.getMarkup()}) }
    }

    data.view.elements.top().last <- true
    return data
  }

  function getText()
  {
    local text = []
    foreach (element in elements)
      text.append(element.getText())

    return ::g_string.implode(text, " + ")
  }

  function getDeviceId()
  {
    if (elements.len())
      return elements[0].getDeviceId()

    return ::NULL_INPUT_DEVICE_ID
  }

  function hasImage()
  {
    if (elements.len())
      foreach (item in elements)
        if (item.hasImage())
          return true

    return false
  }
}
