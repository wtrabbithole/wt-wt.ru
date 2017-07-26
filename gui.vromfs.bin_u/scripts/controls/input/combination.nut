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
    local template = "gui/combination"
    local view = {
      elements = []
    }

    foreach (element in elements)
      view.elements.append({ element = element.getMarkup() })

    view.elements.top().last <- true

    return ::handyman.renderCached(template, view)
  }

  function getText()
  {
    local text = []
    foreach (element in elements)
      text.append(element.getText())

    return ::implode(text, " + ")
  }

  function getDeviceId()
  {
    if (elements.len())
      return elements[0].getDeviceId()

    return ::NULL_INPUT_DEVICE_ID
  }
}
