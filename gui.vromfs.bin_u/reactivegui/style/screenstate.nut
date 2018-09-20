local string = require("std/string.nut")
local frp = require("daRg/frp.nut")

local debugRowHeight = 14 /* Height of on-screen debug text (fps, build, etc) */

local resolution = persist("resolution",
  @() Watched(::cross_call.sysopt.getGuiValue("resolution", "1024 x 768")))

local mode = persist("mode",
  @() Watched(::cross_call.sysopt.getGuiValue("mode", "fullscreen")))

local safeAreaHud = persist("safeAreaHud",
  @() Watched(::cross_call.getSafeAreaHudValue() ?? 1.0))

local recalculateHudSize = function(safeAreaValue) {
  local borders = [ ::max((sh((1.0 - safeAreaValue) *100) / 2).tointeger(), debugRowHeight),
    ::max((sw((1.0 - safeAreaValue) *100) / 2).tointeger(), debugRowHeight)]
  local size = [sw(100) - 2 * borders[1], sh(100) - 2 * borders[0]]
  return {
    size = size
    borders = borders
  }
}

local safeAreaSizeHud = frp.map(safeAreaHud, @(val) recalculateHudSize(val))

frp.subscribe([resolution, mode], function(new_val){
  ::gui_scene.setInterval(0.5,
    function() {
      ::gui_scene.clearTimer(callee())
      safeAreaSizeHud.update(recalculateHudSize(safeAreaHud.value))
      safeAreaSizeHud.trigger()
  })
})

::interop.updateHudSafeArea <- function (config = {}) {
  local newSafeAreaHud = config?.safeAreaHud
  if(newSafeAreaHud)
    safeAreaHud.update(newSafeAreaHud)
}

::interop.updateScreenOptions <- function (config = {}) {
  local newResolution = config?.resolution
  if(newResolution)
    resolution.update(newResolution)

  local newMode = config?.mode
  if(newMode)
    mode.update(newMode)
}


return {
  safeAreaSizeHud = safeAreaSizeHud
}
