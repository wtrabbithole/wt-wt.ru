local textInputBase = require("daRg/components/textInput.nut")
local colors = require("../style/colors.nut")
local background = require("../style/hudBackground.nut")


local bg = Picture("!ui/gameuiskin#debriefing_bg_grad")
local hudFrame = function(inputObj, group, sf) {
  return {
    size = [flex(), SIZE_TO_CONTENT]
    fillColor = colors.hud.componentFill
    borderColor = colors.hud.componentBorder
    group = group
    padding = [sh(7.0/1080*100) , sh(15.0/1080*100)]

    children = inputObj
  }.patchComponent(background)
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
