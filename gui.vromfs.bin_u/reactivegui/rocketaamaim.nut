local aamAimState = require("rocketAamAimState.nut")


local aamAimGimbal = function(line_style, color_func) {
  local circle = @() line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [sh(14.0), sh(14.0)]
    color = color_func()
    commands = [
      [VECTOR_ELLIPSE, 0, 0, aamAimState.GimbalSize.value, aamAimState.GimbalSize.value]
    ]
  })

  return @(){
    halign = HALIGN_CENTER
    valign = VALIGN_MIDDLE
    size = SIZE_TO_CONTENT
    watch = [aamAimState.GimbalX, aamAimState.GimbalY, aamAimState.GimbalVisible]
    transform = {
      translate = [aamAimState.GimbalX.value, aamAimState.GimbalY.value]
    }
    children = aamAimState.GimbalVisible.value ? [circle] : null
  }
}

local aamAimTracker = function(line_style, color_func) {
  local circle = @() line_style.__merge({
      rendObj = ROBJ_VECTOR_CANVAS
      size = [sh(14.0), sh(14.0)]
      color = color_func()
      commands = [
        [VECTOR_ELLIPSE, 0, 0, aamAimState.TrackerSize.value, aamAimState.TrackerSize.value]
      ]
    })

  return @(){
    halign = HALIGN_CENTER
    valign = VALIGN_MIDDLE
    size = SIZE_TO_CONTENT
    watch = [aamAimState.TrackerX, aamAimState.TrackerY, aamAimState.TrackerVisible]
    transform = {
      translate = [aamAimState.TrackerX.value, aamAimState.TrackerY.value]
    }
    children = aamAimState.TrackerVisible.value ? [circle] : null
  }
}


return function(line_style, color_func) {
  return {
    children = [
      aamAimGimbal(line_style, color_func)
      aamAimTracker(line_style, color_func)
    ]
  }
}
