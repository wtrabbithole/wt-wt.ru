// Put to global namespace for compatibility
::math <- require("math")
::string <- require("string")
::loc <- require("dagor.localize").loc

// configure scene when hosted in game
if ("gui_scene" in ::getroottable()) {
  ::gui_scene.config.gamepadCursorControl = false
}

local widgets = require("reactiveGui/widgets.nut")
local ctrlsState = require("ctrlsState.nut") //need this for controls mask updated

/*scale px by font size*/
local fontsState = require("style/fontsState.nut")
::fpx <- fontsState.getSizePx //equal @sf/1@pf in gui
::dp <- fontsState.getSizeByDp //equal @dp in gui
::scrn_tgt <- fontsState.getSizeByScrnTgt //equal @scrn_tgt/100 in gui

return {
  children = [
    widgets
  ]
}
