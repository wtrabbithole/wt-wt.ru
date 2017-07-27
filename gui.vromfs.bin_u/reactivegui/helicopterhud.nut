local style = {}

style.helicopterHudText <- class {
  color = Color(255, 255, 255, 150)
  font = Fonts.hud
  fontFxColor = Color(0, 0, 0, 80)
  fontFxFactor = 16
  fontFx = FFT_GLOW
}


local images = {
  dot = ::Picture("ui/dot.ddsx")
}


const LINE_WIDTH = 4

style.lineBackground <- class {
  color = Color(0, 0, 0, 80)
  lineWidth = LINE_WIDTH
  image = images.dot
}

style.lineForeground <- class {
  color = Color(255, 255, 255, 150)
  lineWidth = LINE_WIDTH
  image = images.dot
}


::interop.state <- {
  indicatorsVisible = 1
  ias = 0
  alt = 0
  distanceToGround = 100
  verticalSpeed = 0
  forwardSpeed = 0
  leftSpeed = 0
  forwardAccel = 0
  leftAccel = 0

  rocketAimX = 0
  rocketAimY = 0
  rocketAimVisible = 1

  flightDirectionX = 0
  flightDirectionY = 0
  flightDirectionVisible = 1

  gunDirectionX = 0
  gunDirectionY = 0
  gunDirectionVisible = 0
}


local RocketAimLines = function(line_style) {
  local w = sh(0.8)
  local h = sh(2)
  return [
    class extends line_style { rendObj = ROBJ_LINE; pos = [0, -h]; size = [2*w, 0] }
    class extends line_style { rendObj = ROBJ_LINE; pos = [0, h];  size = [2*w, 0] }
    class extends line_style { rendObj = ROBJ_LINE; pos = [0, 0];  size = [0, 2*h] }
  ]
}

local HelicopterRocketAim = function(line_style) {
  local lines = RocketAimLines(line_style)

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
    children = lines
  }
}

local FlightDirLines = function(line_style) {
  local r = sh(0.75)

  return [
    class extends line_style { rendObj = ROBJ_LINE;   pos = [0, -1.5*r];  size = [0, r] }
    class extends line_style { rendObj = ROBJ_LINE;   pos = [-1.5*r, 0];  size = [r, 0] }
    class extends line_style { rendObj = ROBJ_LINE;   pos = [1.5*r, 0];   size = [r, 0] }
    class extends line_style { rendObj = ROBJ_CIRCLE; pos = [0, 0];       size = [2*r, 2*r] }
  ]
}


local HelicopterFlightDirection = function(line_style) {
  local lines = FlightDirLines(line_style)
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
    children = lines
  }
}

local GunDirLines = function(line_style) {
  local r = sh(0.625)
  
  return [
    class extends line_style { rendObj = ROBJ_LINE; pos = [0, -1.5*r]; size = [0, r] }
    class extends line_style { rendObj = ROBJ_LINE; pos = [0, 1.5*r];  size = [0, -r] }
    class extends line_style { rendObj = ROBJ_LINE; pos = [-1.5*r, 0]; size = [r, 0] }
    class extends line_style { rendObj = ROBJ_LINE; pos = [1.5*r, 0];  size = [-r, 0] }
  ]
}


local HelicopterGunDirection = function(line_style) {
  local lines = GunDirLines(line_style)
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
    children = lines
  }
}


/*
local HelicopterFlightVector = function(elemStyle)
{
  return @() {
    size = [sh(10), sh(10)]
    hplace = HALIGN_CENTER
    vplace = VALIGN_BOTTOM
    pos = [0, sh(40)]
    behavior = Behaviors.RtPropUpdate
    update = @(){
      isHidden = !::interop.state.indicatorsVisible
    }

    children = [
      class extends elemStyle {
        rendObj = ROBJ_CIRCLE
        pos = @() [pw(100) * 0.5 - elemStyle.lineWidth * 0.25, ph(100) - elemStyle.lineWidth * 0.25]
        size = [elemStyle.lineWidth * 0.5, elemStyle.lineWidth * 0.5]
      }
      class extends elemStyle {
        rendObj = ROBJ_LINE
        pos = @() [pw(100) * 0.5, ph(100)]
        behavior = Behaviors.RtPropUpdate
        update = @(){
          size = @() [pw(100) * -::interop.state.leftSpeed * 0.01, pw(100) * -::interop.state.forwardSpeed * 0.01]
        }
      }
      class extends elemStyle {
        rendObj = ROBJ_CIRCLE
        behavior = Behaviors.RtPropUpdate
        update = @() {
          pos = @() [
            pw(100) * 0.5 + pw(100) * -::interop.state.leftSpeed * 0.01 - elemStyle.lineWidth * 0.25,
            ph(100) + pw(100) * -::interop.state.forwardSpeed * 0.01 - elemStyle.lineWidth * 0.25]
        }
        size = @() [elemStyle.lineWidth * 0.5, elemStyle.lineWidth * 0.5]
      }
      class extends elemStyle {
        rendObj = ROBJ_CIRCLE
        behavior = Behaviors.RtPropUpdate
        update = @() {
          pos = @() [
            pw(100) * 0.5 + pw(100) * -::interop.state.leftSpeed * 0.01 + pw(100) * -::interop.state.leftAccel * 0.02 - sh(1.1),
            ph(100) + pw(100) * -::interop.state.forwardSpeed * 0.01 + pw(100) * -::interop.state.forwardAccel * 0.02 - sh(1.1)]
        }
        size = [sh(2.2), sh(2.2)]
      }
    ]
  }
}
*/

local verticalSpeedInd = function(line_style, height) {
  return {
    size =[height,height]
    pos = [0,-height*0.5]
    children = [
      class extends line_style { rendObj = ROBJ_LINE pos = [0, 0]   size = [height, 0.5*height]  subPixel = true}
      class extends line_style { rendObj = ROBJ_LINE pos = [0, height] size = [height, -0.5*height] subPixel = true}
      class extends line_style { rendObj = ROBJ_LINE pos = [0, 0]   size = [0, height]  subPixel = true}
   ]
 }
}

local verticalSpeedScale = function(line_style, width, height) {
  return {
    size = [width,height]
    halign = HALIGN_RIGHT
    children = [ 
      class extends line_style { rendObj = ROBJ_LINE pos = [0, 0]           size = [width,0]  }
      class extends line_style { rendObj = ROBJ_LINE pos = [0, height*0.125] size = [width*0.5, 0] }
      class extends line_style { rendObj = ROBJ_LINE pos = [0, height*0.25]  size = [width*0.5, 0] }
      class extends line_style { rendObj = ROBJ_LINE pos = [0, height*0.375]size = [width*0.5, 0]  }
      class extends line_style { rendObj = ROBJ_LINE pos = [0, height*0.50] size = [width*0.5,0]  }
      class extends line_style { rendObj = ROBJ_LINE pos = [0, height*0.75] size = [width*0.5, 0]  }
      class extends line_style { rendObj = ROBJ_LINE pos = [0, height*0.9]  size = [width*0.5, 0]  }
      class extends line_style { rendObj = ROBJ_LINE pos = [0, height]      size = [width,0]  }
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
          rendObj = ROBJ_9RECT
          screenOffs = 4
          texOffs = 4
          behavior = Behaviors.RtPropUpdate
          pos = [LINE_WIDTH,LINE_WIDTH*0.5]
          update = @() {
            isHidden = ::interop.state.distanceToGround > 50.0
            size = @() [LINE_WIDTH, (height+LINE_WIDTH) * ::clamp(::interop.state.distanceToGround * 2, 0, 100)/100]
          }
        }
      }
      {
        halign = HALIGN_RIGHT
        valign = VALIGN_MIDDLE
        size = [-scaleWidth-sh(0.5),height]
        children = class extends style.helicopterHudText {
          valign = VALIGN_MIDDLE
          rendObj = ROBJ_TEXT
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


local Root = function() {
  return {
    halign = HALIGN_LEFT
    valign = VALIGN_TOP
    size = [sw(100) , sh(100)]

    children = [

      HelicopterRocketAim(style.lineBackground)
      HelicopterFlightDirection(style.lineBackground)
      HelicopterGunDirection(style.lineBackground)
//      HelicopterFlightVector(style.lineBackground)   //Item deleted due to confussion for begginers
      HelicopterVertSpeed(style.lineBackground)
      
      HelicopterRocketAim(style.lineForeground)
      HelicopterFlightDirection(style.lineForeground)
      HelicopterGunDirection(style.lineForeground)
//      HelicopterFlightVector(style.lineForeground)   //Item deleted due to confussion for begginers
      HelicopterVertSpeed(style.lineForeground)

    ]
  }
}


return Root
