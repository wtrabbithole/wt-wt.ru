local textInputBase = require("daRg/components/textInput.nut")
local colors = require("reactiveGui/style/colors.nut")


local hudFrame = function(inputObj, group, sf) {
  return {
    rendObj = ROBJ_BOX
    size = [flex(), SIZE_TO_CONTENT]
    fillColor = colors.menu.textInputBgColor
    borderColor = colors.menu.textInputBorderColor
    borderWidth = [hdpx(1)]

    group = group
    padding = [hdpx(5) , hdpx(6)]

    children = inputObj
  }
}


local makeTextInput = function(text_state, options, handlers, frameCtor) {
  options.colors <- textInputColors
  return
}


local export = class {
  hud = @(text_state, options={}, handlers={}) textInputBase(text_state, options, handlers, hudFrame)
  _call = @(self, text_state, options={}, handlers={}) textInputBase(text_state, options, handlers)
}()


return export