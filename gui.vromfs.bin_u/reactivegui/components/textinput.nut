local textInputBase = require("daRg/components/textInput.nut")
local colors = require("../style/colors.nut")


local hudFrame = function(inputObj, group, sf) {
  return {
    rendObj = ROBJ_9RECT
    size = [flex(), SIZE_TO_CONTENT]
    fillColor = colors.hud.componentFill
    borderColor = colors.hud.componentBorder
    group = group
    padding = [hdpx(5) , hdpx(15)]
    color = colors.hud.hudLogBgColor

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