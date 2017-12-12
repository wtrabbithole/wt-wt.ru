local globalState = require("globalState.nut")
local helicopterHud = require("reactiveGui/helicopterHud.nut")
local hudState = require("hudState.nut")
local shipHud = require("reactiveGui/shipHud.nut")

return function () {
  local hud = null
  if (globalState.isInFlight.value) {
    if (hudState.unitType.value == "helicopter") {
      hud = helicopterHud
    } else if (hudState.unitType.value == "ship") {
      hud = shipHud
    }
  }

  return {
    watch = [
      hudState.unitType
      globalState.isInFlight
    ]
    children = hud
  }
}
