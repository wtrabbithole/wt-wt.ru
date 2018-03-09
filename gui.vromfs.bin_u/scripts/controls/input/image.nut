class ::Input.InputImage extends ::Input.InputBase
{
  image = ""
  constructor(imageName)
  {
    image = imageName
  }

  function getMarkup()
  {
    local data = getMarkupData()
    return ::handyman.renderCached(data.template, data.view)
  }

  function getMarkupData()
  {
    return {
      template = "gui/gamepadButton"
      view = { buttonImage = image }
    }
  }
}