local style = {}

style.helicopterHudText <- class {
  color = Color(255, 255, 255, 150)
  font = Fonts.hud
  fontFxColor = Color(0, 0, 0, 80)
  fontFxFactor = 16
  fontFx = FFT_GLOW
}


const LINE_WIDTH = 1.6

style.lineBackground <- class {
  color = Color(0, 0, 0, 80)
  fillColor = Color(0, 0, 0, 0)
  lineWidth = LINE_WIDTH + 2.0
}

style.lineForeground <- class {
  color = Color(255, 255, 255, 255)
  fillColor = Color(0, 0, 0, 0)
  lineWidth = LINE_WIDTH
}


::interop.state <- {
  indicatorsVisible = 1
  ias = 0
  alt = 0
  distanceToGround = 0.0
  verticalSpeed = 0
  forwardSpeed = 0
  leftSpeed = 0
  forwardAccel = 0
  leftAccel = 0

  rocketAimX = 100
  rocketAimY = 200
  rocketAimVisible = 1

  flightDirectionX = 150
  flightDirectionY = 200
  flightDirectionVisible = 1

  gunDirectionX = 200
  gunDirectionY = 200
  gunDirectionVisible = 1
}


local HelicopterRocketAim = function(line_style) {

  local lines = class extends line_style {
      rendObj = ROBJ_VECTOR_CANVAS
      size = [sh(0.8), sh(2)]
      commands = [
        [VECTOR_LINE, -100, -100, 100, -100],
        [VECTOR_LINE, -100, 100, 100, 100],
        [VECTOR_LINE, 0, -100, 0, 100],
      ]
    }

  return {
    halign = HALIGN_CENTER
    valign = VALIGN_MIDDLE
    size = [0,0]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      isHidden = !::interop.state.rocketAimVisible
      transform = {
        translate = [::interop.state.rocketAimX, ::interop.state.rocketAimY]
      }
    }
    children = [lines]
  }
}


local HelicopterFlightDirection = function(line_style) {
  local lines = class extends line_style {
      rendObj = ROBJ_VECTOR_CANVAS
      size = [sh(0.75), sh(0.75)]
      commands = [
        [VECTOR_LINE, -100, 0, -200, 0],
        [VECTOR_LINE, 100, 0, 200, 0],
        [VECTOR_LINE, 0, -100, 0, -200],
        [VECTOR_ELLIPSE, 0, 0, 100, 100],
      ]
    }

  return @(){
    size = [0, 0]
    behavior = Behaviors.RtPropUpdate
    halign = HALIGN_CENTER
    valign = VALIGN_MIDDLE
    update = @() {
      isHidden = !::interop.state.flightDirectionVisible
      transform = {
        translate = [::interop.state.flightDirectionX, ::interop.state.flightDirectionY]
      }
    }
    children = [lines]
  }
}


local HelicopterGunDirection = function(line_style) {

  local lines = class extends line_style {
      rendObj = ROBJ_VECTOR_CANVAS
      size = [sh(0.625), sh(0.625)]
      commands = [
        [VECTOR_LINE, 0, 50, 0, 150],
        [VECTOR_LINE, 0, -50, 0, -150],
        [VECTOR_LINE, 50, 0, 150, 0],
        [VECTOR_LINE, -50, 0, -150, 0],
      ]
    }

  return @() {
    size = [0, 0]
    halign = HALIGN_CENTER
    valign = VALIGN_MIDDLE
    behavior = Behaviors.RtPropUpdate
    update = @() {
      isHidden = !::interop.state.gunDirectionVisible
      transform = {
        translate = [::interop.state.gunDirectionX, ::interop.state.gunDirectionY]
      }
    }
    children = [lines]
  }
}


local verticalSpeedInd = function(line_style, height) {
  return class extends line_style {
    rendObj = ROBJ_VECTOR_CANVAS
    size = [height, height]
    pos = [0, -height*0.5]
    commands = [
      [VECTOR_LINE, 0, 0, 100, 50, 0, 100, 0, 0],
    ]
  }
}

local verticalSpeedScale = function(line_style, width, height) {
  return class extends line_style {
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, height]
    halign = HALIGN_RIGHT
    commands = [
      [VECTOR_LINE, 0, 0, 100, 0],
      [VECTOR_LINE, 0, 12.5, 50, 12.5],
      [VECTOR_LINE, 0, 25, 50, 25],
      [VECTOR_LINE, 0, 37.5, 50, 37.5],
      [VECTOR_LINE, 0, 50, 100, 50],
      [VECTOR_LINE, 0, 75, 50, 75],
      [VECTOR_LINE, 0, 90, 50, 90],
      [VECTOR_LINE, 0, 100, 100, 100],
    ]
  }
}

local HelicopterVertSpeed = function(elemStyle) {
  local scaleWidth = sh(1)
  local height = sh(20)

  return @() {
    pos = [sw(70), sh(50) - height*0.5]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      isHidden = !::interop.state.indicatorsVisible
    }
    children = [
      @() {
        children = verticalSpeedScale(elemStyle, scaleWidth, height)
      }
      {
        valign = VALIGN_BOTTOM
        halign = HALIGN_RIGHT
        size = [scaleWidth, height]
        children = class extends elemStyle {
          rendObj = ROBJ_VECTOR_CANVAS
          behavior = Behaviors.RtPropUpdate
          pos = [LINE_WIDTH, 0]
          size = [LINE_WIDTH, height]
          tmpHeight = 0
          fillColor = Color(255, 255, 255, 255)
          commands = [[VECTOR_RECTANGLE, 0, 0, 100, 100]]
          update = @() {
            isHidden = ::interop.state.distanceToGround > 50.0
            tmpHeight = ::clamp(::interop.state.distanceToGround * 2.0, 0, 100)
            commands = [[VECTOR_RECTANGLE, 0, 100 - tmpHeight, 100, tmpHeight]]
          }
        }
      }
      {
        halign = HALIGN_RIGHT
        valign = VALIGN_MIDDLE
        size = [-scaleWidth-sh(0.5),height]
        children = class extends style.helicopterHudText {
          rendObj = ROBJ_DTEXT
          behavior = Behaviors.RtPropUpdate
          update = @() {
            isHidden = ::interop.state.distanceToGround > 350.0
            text = ::math.floor(::interop.state.distanceToGround).tostring()
          }
        }
      }
      {
        behavior = Behaviors.RtPropUpdate
        pos = [-scaleWidth, 0]
        update = @() {
          transform = {
            translate = [0, height * 0.01 * clamp(50 - ::interop.state.verticalSpeed * 5.0, 0, 100)]
          }
        }
        children = verticalSpeedInd(elemStyle, sh(1.))
      }

    ]
  }
}


local helicopterHUDs = function (color) {
  return [
    HelicopterRocketAim(color)
    HelicopterFlightDirection(color)
    HelicopterGunDirection(color)
//    HelicopterFlightVector(color)   //Item deleted due to confussion for begginers
    HelicopterVertSpeed(color)
  ]

}


local Root = function() {
  local children = helicopterHUDs(style.lineBackground)
  children.extend(helicopterHUDs(style.lineForeground))
  
  return {
    halign = HALIGN_LEFT
    valign = VALIGN_TOP
    size = [sw(100) , sh(100)]
    children = children 
  }
}


return Root
