// Put to global namespace for compatibility
::math <- require("math")
::string <- require("string")

local widgets = require("reactiveGui/widgets.nut")

return {
  children = [
    widgets
  ]
}
