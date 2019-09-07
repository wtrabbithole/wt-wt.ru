/* Collection of all 'standard' ui widgets
  you can use it:
    this.__update(require("daRg/components/std.nut"))
    textArea("text")
  or
    local ui = require("daRg/components/std.nut")
    ui.textArea("my text")
*/

/*TODO:
  ? combine all *.style.nut to one table and/or move to ../style (it's easier probably to change all colors in one file?)
  ? rework styling for something easier to use
  ? consider add default fonts to darg itself (fontawesome and some std utf font. However - we definitely need better font render\layout system first, cause in other case size of font is something not defined)

  add widgets for:
    image
    ninerect
    select
    !property grid
    ? 'container'/ 'panel' (more sense if we would have render-to-texture panels, but whatever)

  documentation and samples


*/

local textArea = require("textArea.nut")
local text = require("text.nut").text
local stext = require("text.nut").stext
local dtext = require("text.nut").dtext
local contextMenu = require("contextMenu.nut")
local textInput = require("textInput.nut")
local scrollbar = require("scrollbar.nut")
local combobox = require("combobox.nut")
local msgbox = require("msgbox.nut")
local textButton = require("textButton.nut")
local tabs = require("tabs.nut")
local image = require("image.nut")
local panel = require("panel.nut")
local function mkpanel(def){
  return function(elem_, ...) {
    return panel.acall([null, def.__merge(elem_)].extend(vargv))
 }
}
local hpanel = mkpanel({flow=FLOW_HORIZONTAL size=flex() minWidth=SIZE_TO_CONTENT minHeight=SIZE_TO_CONTENT})
local vpanel = mkpanel({flow=FLOW_VERTICAL size=flex() minWidth=SIZE_TO_CONTENT minHeight=SIZE_TO_CONTENT})


return {
  textArea = textArea
  contextMenu = contextMenu
  textInput = textInput
  scrollbar = scrollbar
  combobox = combobox
  msgbox = msgbox
  textButton = textButton
  tabs = tabs
  text = text
  dtext = dtext
  stext = stext
  image = image
  panel = panel
  mkpanel = mkpanel
  hpanel = hpanel
  vpanel = vpanel

  red = Color(255,0,0)
  blue = Color(0,0,255)
  green = Color(0,255,0)
  magenta = Color(255,0,255)
  yellow = Color(255,255,0)
  cyan = Color(0,255,255)
  gray = Color(128,128,128)
  lightgray = Color(192,192,192)
  darkgray = Color(64,64,64)
  black = Color(0,0,0)
  white = Color(255,255,255)
}