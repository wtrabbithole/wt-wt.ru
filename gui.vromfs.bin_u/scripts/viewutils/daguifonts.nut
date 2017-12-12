local fonts = ::require("fonts")

local daguiFonts = {

  /**
   * Returns line height in pixels for given font.
   * @param {string} fontName - font CSS const name.
   * @return {int} - line height in pixels, or 0 in case of error.
   */
  getFontLineHeightPx = function(fontName)
  {
    local realFontName = ::get_main_gui_scene().getConstantValue(fontName)
    local bbox = fonts.getStringBBox(".", realFontName)
    return bbox ? ::max(0, bbox[3] - bbox[1]).tointeger() : 0
  }

  /**
   * Returns width in pixels for given text string rendered in given font.
   * @param {string} text - text string to be measured, without line breaks.
   * @param {string} fontName - font CSS const name.
   * @param {instance} [guiScene] - optional valid instance of ScriptedGuiScene.
   * @return {int} - text width in pixels, or 0 in case of error or empty string.
   */
  getStringWidthPx = function(text, fontName, guiScene = null)
  {
    if (text == "")
      return 0
    guiScene = guiScene || ::get_main_gui_scene()
    local realFontName = guiScene.getConstantValue(fontName)
    local bbox = fonts.getStringBBox(text, realFontName)
    return bbox ? ::max(0, bbox[2] - bbox[0]).tointeger() : 0
  }

}

return daguiFonts
