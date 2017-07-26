class ::Input.InputImage extends ::Input.InputBase
{
  image = ""
  constructor(imageName)
  {
    image = imageName
  }

  function getMarkup()
  {
    local view = { buttonImage = image }
    local template = "gui/gamepadButton"
    return ::handyman.renderCached(template, view)
  }
}
