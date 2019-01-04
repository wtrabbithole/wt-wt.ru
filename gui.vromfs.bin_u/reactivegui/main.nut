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

return {
  children = [
    widgets
  ]
}
