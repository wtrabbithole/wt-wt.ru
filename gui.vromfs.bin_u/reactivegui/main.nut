// Put to global namespace for compatibility
::math <- require("math")
::string <- require("string")

local widgets = require("reactiveGui/widgets.nut")
local ctrlsState = require("ctrlsState.nut") //need this for controls mask updated

return {
  children = [
    widgets
  ]
}
