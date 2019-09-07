local compassState = require("compassState.nut")
local alienNumbers = require("alienNumbers.nut")


local generateCompassNumber = function(num, line_style, width, height, color){
  return {
    size = [width, height]
    flow = FLOW_VERTICAL
    children = [
      line_style.__merge({
        rendObj = ROBJ_STEXT
        pos = [-0.5 * width, 0]
        size = [width * 2.0, 0.5 * height]
        halign = HALIGN_CENTER
        text = num
        color = color
      })
      line_style.__merge({
        rendObj = ROBJ_VECTOR_CANVAS
        size = [width, 0.5 * height]
        color = color
        commands = [
          [VECTOR_LINE, 50, 0, 50, 100]
        ]
      })
    ]
  }
}


local generateCompassDash = function(line_style, width, height, color){
  return line_style.__merge({
    size = [width, height]
    rendObj = ROBJ_VECTOR_CANVAS
    color = color
    commands = [
      [VECTOR_LINE, 50, 70, 50, 100]
    ]
  })
}


local compassLine = function(line_style, total_width, width, height, color){
  local params = alienNumbers.getCompassParams()
  local children = []

  for (local i = 0; i <= 2.0 * params.grad / params.step; ++i)
  {
    local num = (i * params.step).tointeger() % params.grad
    local txt = alienNumbers.getNumStr(num)
    if (num % params.pole == 0)
    {
      local mark = ::loc("HUD/alien/comma", "-")
      txt = mark + txt + mark
    }

    children.append(generateCompassNumber(txt, line_style, width, height, color))
    children.append(generateCompassDash(line_style, width, height, color))
  }

  local getOffset = @() 0.5 * (total_width - width) + compassState.CompassValue.value * width * 2.0 / params.step - 2.0 * params.grad * width / params.step

  return {
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [getOffset(), 0]
      }
    }
    size = [SIZE_TO_CONTENT, height]
    flow = FLOW_HORIZONTAL
    children = children
  }
}


local compassArrow = function(line_style, height, color) {
  return line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [height, height]
    color = color
    commands = [
      [VECTOR_LINE, 0, 100, 50, 0],
      [VECTOR_LINE, 50, 0, 100, 100]
    ]
  })
}


local compass = function(line_style, width, height, color) {
  local oneElementWidth = height
  return {
    size = [width, height]
    clipChildren = true
    children = [
      compassLine(line_style, width, oneElementWidth, height, color)
    ]
  }
}


local compassComponent = function(elemStyle, width, height, color) {
  return {
    size = SIZE_TO_CONTENT
    flow = FLOW_VERTICAL
    halign = HALIGN_CENTER
    gap = hdpx(5)
    children = [
      compass(elemStyle, width, height, color)
      compassArrow(elemStyle, 0.3 * height, color)
    ]
  }
}


return compassComponent
