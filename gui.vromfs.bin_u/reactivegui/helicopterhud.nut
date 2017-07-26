local style = {}

style.helicopterHudText <- {
  color = Color(255, 255, 255, 0)
  font = Fonts.hud
  fontFxColor = Color(0, 0, 0, 255)
  fontFxFactor = 32
  fontFx = FFT_GLOW
}


local images = {
  dot = ::Picture("ui/dot.ddsx")
}

style.lineBackground <- {
  color = Color(0, 0, 0, 255)
  lineWidth = 4
  image = images.dot
}

style.lineForeground <- {
  color = Color(255, 255, 255, 0)
  lineWidth = 4
  image = images.dot
}

style.invisibleStyle <- {
  color = Color(0, 0, 0, 0)
  lineWidth = 1
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
};


local HelicopterRocketAim = function(elemStyle) {
  return @() {
    size = @() [ph(1.6), ph(4)]
    pos = @() [::interop.state.rocketAimX - w(50), ::interop.state.rocketAimY - w(50)]
    behavior = Behaviors.RealtimeUpdate
    subPixel = true

    children = !::interop.state.rocketAimVisible ? null : [
      {
        rendObj = ROBJ_LINE
        pos = @() [pw(0), ph(0)]
        size = @() [pw(100), ph(0)]
        style = elemStyle
        subPixel = true
      }
      {
        rendObj = ROBJ_LINE
        pos = @() [pw(0), ph(100)]
        size = @() [pw(100), ph(0)]
        style = elemStyle
        subPixel = true
      }
      {
        rendObj = ROBJ_LINE
        pos = @() [pw(100) * 0.5, ph(0)]
        size = @() [pw(0), ph(100)]
        style = elemStyle
        subPixel = true
      }
    ]
  }
}

local HelicopterFlightDirection = function(elemStyle)
{
  return @() {
    size = @() [ph(3), ph(3)]
    pos = @() [::interop.state.flightDirectionX - w(50), ::interop.state.flightDirectionY - w(50)]
    behavior = Behaviors.RealtimeUpdate
    subPixel = true

    children = !::interop.state.flightDirectionVisible ? null : [
      {
        rendObj = ROBJ_LINE
        pos = @() [pw(100) * 0.5, ph(0)]
        size = @() [pw(0), ph(100) * 0.25]
        style = elemStyle
        subPixel = true
      }
      {
        rendObj = ROBJ_LINE
        pos = @() [pw(0), ph(100) * 0.5]
        size = @() [pw(100) * 0.25, ph(0)]
        style = elemStyle
        subPixel = true
      }
      {
        rendObj = ROBJ_LINE
        pos = @() [pw(100), ph(100) * 0.5]
        size = @() [pw(100) * -0.25, ph(0)]
        style = elemStyle
        subPixel = true
      }
      {
        rendObj = ROBJ_CIRCLE
        pos = @() [pw(100) * 0.25, ph(100) * 0.25]
        size = @() [pw(100) * 0.5, ph(100) * 0.5]
        style = elemStyle
        subPixel = true
      }
    ]
  }
}

local HelicopterGunDirection = function(elemStyle) {
  return @() {
    size = @() [ph(2.5), ph(2.5)]
    pos = @() [::interop.state.gunDirectionX - w(50), ::interop.state.gunDirectionY - w(50)]
    behavior = Behaviors.RealtimeUpdate

    children = !::interop.state.gunDirectionVisible ? null : [
      {
        rendObj = ROBJ_LINE
        pos = @() [pw(50), ph(0)]
        size = @() [pw(0), ph(25)]
        style = elemStyle
      }
      {
        rendObj = ROBJ_LINE
        pos = @() [pw(50), ph(100)]
        size = @() [pw(0), ph(-25)]
        style = elemStyle
      }
      {
        rendObj = ROBJ_LINE
        pos = @() [pw(0), ph(50)]
        size = @() [pw(25), ph(0)]
        style = elemStyle
      }
      {
        rendObj = ROBJ_LINE
        pos = @() [pw(100), ph(50)]
        size = @() [pw(-25), ph(0)]
        style = elemStyle
      }
    ]
  
  }
}

local HelicopterFlightVector = function(elemStyle) {
  return @() {
    size = @() [ph(10), ph(10)]
    pos = @() [pw(50) - h(50), ph(60)]
    behavior = Behaviors.RealtimeUpdate
    isHidden = !::interop.state.indicatorsVisible

    children = [
      {
        rendObj = ROBJ_CIRCLE
        pos = @() [pw(100) * 0.5 - elemStyle.lineWidth * 0.25, ph(100) - elemStyle.lineWidth * 0.25]
        size = @() [elemStyle.lineWidth * 0.5, elemStyle.lineWidth * 0.5]
        style = elemStyle
        subPixel = true
      }
      {
        rendObj = ROBJ_LINE
        pos = @() [pw(100) * 0.5, ph(100)]
        size = @() [pw(100) * -::interop.state.leftSpeed * 0.01, pw(100) * -::interop.state.forwardSpeed * 0.01]
        style = elemStyle
        subPixel = true
      }
      {
        rendObj = ROBJ_CIRCLE
        pos = @() [
          pw(100) * 0.5 + pw(100) * -::interop.state.leftSpeed * 0.01 - elemStyle.lineWidth * 0.25,
          ph(100) + pw(100) * -::interop.state.forwardSpeed * 0.01 - elemStyle.lineWidth * 0.25]
        size = @() [elemStyle.lineWidth * 0.5, elemStyle.lineWidth * 0.5]
        style = elemStyle
        subPixel = true
      }
      {
        rendObj = ROBJ_CIRCLE
        pos = @() [
          pw(100) * 0.5 + pw(100) * -::interop.state.leftSpeed * 0.01 + pw(100) * -::interop.state.leftAccel * 0.02 - sh(1.1),
          ph(100) + pw(100) * -::interop.state.forwardSpeed * 0.01 + pw(100) * -::interop.state.forwardAccel * 0.02 - sh(1.1)]
        size = @() [sh(2.2), sh(2.2)]
        style = elemStyle
        subPixel = true
      }
    ]
  }
}

local HelicopterVertSpeed = function(elemStyle) {
  return @() {
    size = @() [ph(20), ph(20)]
    pos = @() [pw(70), ph(50) - h(50)]
    behavior = Behaviors.RealtimeUpdate
    isHidden = !::interop.state.indicatorsVisible

    children = [
      {
        rendObj = ROBJ_LINE
        pos = @() [pw(10), ph(0)]
        size = @() [pw(-10), ph(0)]
        style = elemStyle
      }
      {
        rendObj = ROBJ_LINE
        pos = @() [pw(10), ph(25)]
        size = @() [pw(-5), ph(0)]
        style = elemStyle
      }
      {
        rendObj = ROBJ_LINE
        pos = @() [pw(10), ph(25 - 12.5)]
        size = @() [pw(-5), ph(0)]
        style = elemStyle
      }
      {
        rendObj = ROBJ_LINE
        pos = @() [pw(10), ph(25 + 12.5)]
        size = @() [pw(-5), ph(0)]
        style = elemStyle
      }
      {
        rendObj = ROBJ_LINE
        pos = @() [pw(10), ph(50)]
        size = @() [pw(-10), ph(0)]
        style = elemStyle
      }
      {
        rendObj = ROBJ_LINE
        pos = @() [pw(10), ph(75)]
        size = @() [pw(-5), ph(0)]
        style = elemStyle
      }
      {
        rendObj = ROBJ_LINE
        pos = @() [pw(10), ph(90)]
        size = @() [pw(-5), ph(0)]
        style = elemStyle
      }
      {
        rendObj = ROBJ_LINE
        pos = @() [pw(10), ph(100)]
        size = @() [pw(-10), ph(0)]
        style = elemStyle
      }
      @(){
        rendObj = ROBJ_9RECT
        screenOffs = 4
        texOffs = 4
        isHidden = ::interop.state.distanceToGround > 50.0
        pos = @() [pw(10), ph(100 - ::clamp(::interop.state.distanceToGround * 2, 0, 100)) - 3]
        size = @() [pw(5), ph(::clamp(::interop.state.distanceToGround * 2, 0, 100)) + 6]
        style = elemStyle
        behavior = Behaviors.RealtimeUpdate
      }
      {
        pos = @() [pw(-44), ph(50 - 10)]
        size = @() [pw(30), ph(20)]

        children = [
          {
            hplace = HALIGN_RIGHT
            vplace = VALIGN_MIDDLE
            rendObj = ROBJ_TEXT
            isHidden = ::interop.state.distanceToGround > 350.0
            text = "" + ::math.floor(::interop.state.distanceToGround)
            style = style.helicopterHudText
            font = Fonts.hud // TODO: temporary fix, remove after getting font from style fixed
          }
        ]
      }

      {
        pos = @() [-w(150), ph(100) * 0.01 * clamp(50 - ::interop.state.verticalSpeed * 5.0, 0, 100) - h(50)]
        size = @() [pw(10), ph(10)]
        subPixel = true
        children = [
          {
            rendObj = ROBJ_LINE
            pos = @() [pw(50), ph(0)]
            size = @() [pw(80), ph(50)]
            style = elemStyle
            subPixel = true
          }
          {
            rendObj = ROBJ_LINE
            pos = @() [pw(50), ph(100)]
            size = @() [pw(80), ph(-50)]
            style = elemStyle
            subPixel = true
          }
          {
            rendObj = ROBJ_LINE
            pos = @() [pw(50), ph(0)]
            size = @() [pw(0), ph(100)]
            style = elemStyle
            subPixel = true
          }
        ]
      }

    ]
  }
}

/*local Indicators = function()
{
  return [
    @() {
      rendObj = ROBJ_TEXT
      hplace = HALIGN_LEFT
      text = ::interop.state.indicatorsVisible ? "ALT  " + ::interop.state.alt : ""
      style = style.helicopterHudText
      behavior = Behaviors.RealtimeUpdate
    }

    @() {
      rendObj = ROBJ_TEXT
      hplace = HALIGN_LEFT
      text = ::interop.state.indicatorsVisible ? "IAS  " + ::interop.state.ias : ""
      style = style.helicopterHudText
      behavior = Behaviors.RealtimeUpdate
    }
  ]
}*/

local SafeArea = function() {
  local safeAreaWidth = 95
  local safeAreaHeight = 92

  return {
    size = @() [sw(safeAreaWidth), sh(safeAreaHeight)]
    pos = @() [sw((100.0 - safeAreaWidth) / 2), sh((100.0 - safeAreaHeight) / 2)]
    flow = FLOW_VERTICAL

//    children = Indicators()
  }
}


local Root = function() {
  return {
    halign = HALIGN_LEFT
    valign = VALIGN_TOP
    size = [sw(100) , sh(100)]

    children = [
      SafeArea
      HelicopterRocketAim(style.lineBackground)
      HelicopterFlightDirection(style.lineBackground)      
      HelicopterGunDirection(style.lineBackground)
      //HelicopterFlightVector(style.lineBackground)   Item deleted due to confussion for begginers
      HelicopterVertSpeed(style.lineBackground)

      HelicopterRocketAim(style.lineForeground)
      HelicopterFlightDirection(style.lineForeground)
      HelicopterGunDirection(style.lineForeground)
      //HelicopterFlightVector(style.lineForeground)   Item deleted due to confussion for begginers
      HelicopterVertSpeed(style.lineForeground)

      { // TODO: remove after fix crash on empty hud
        rendObj = ROBJ_LINE
        pos = @() [pw(-10), ph(-10)]
        size = @() [pw(-10), ph(0)]
        style = style.lineForeground
      }
    ]
  }
}


return Root
