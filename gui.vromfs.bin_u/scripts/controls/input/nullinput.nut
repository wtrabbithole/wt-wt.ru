class ::Input.NullInput extends ::Input.InputBase
{
  showPlaceholder = false

  function getMarkup()
  {
    return showPlaceholder ? "textAreaNoTab { text:t='shortcutId' }" : null
  }

  function getText()
  {
    return showPlaceholder ? "<<" + shortcutId + ">>" : ""
  }
}
