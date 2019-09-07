local radarComponent = require("radarComponent.nut")


local Root = function() {
  return {
    halign = HALIGN_LEFT
    valign = VALIGN_TOP
    size = [sw(100), sh(100)]
    children = [
      radarComponent
    ]
  }
}


return Root
