local math = require("std/math.nut")
local screenState = require("style/screenState.nut")
local compass = require("compassEx.nut")
local helicopterState = require("helicopterState.nut")
local alienNumbers = require("alienNumbers.nut")

local style = {}

local mainColor = Color(255, 255, 255, 250)
local backgroundColor = Color(20, 20, 20, 150)
local fontOutlineColor = Color(0, 0, 0, 255)

const LINE_WIDTH = 1.6

local compassWidth = hdpx(420)
local compassHeight = hdpx(40)

enum GuidanceLockResult {
  RESULT_INVALID = -1
  RESULT_STANDBY = 0
  RESULT_WARMING_UP = 1
  RESULT_LOCKING = 2
  RESULT_TRACKING = 3
}


local throttleStr  = ::loc("HUD/alien/throttle", "")
local velocityStr  = ::loc("HUD/alien/velocity", "")
local velocityUnit = ::loc("HUD/alien/kmph", "")
local gunStr       = ::loc("HUD/alien/gun", "")
local rocketsStr   = ::loc("HUD/alien/rockets", "")


local getColor = function(isBackground){
  return isBackground ? backgroundColor : mainColor
}

local getFontScale = function()
{
  return max(sh(100) / 1080, 1)
}

style.lineBackground <- class {
  fillColor = Color(0, 0, 0, 0)
  lineWidth = hdpx(1) * (LINE_WIDTH + 1.5)
  font = Fonts.hud
  fontFxColor = fontOutlineColor
  fontFxFactor = 40
  fontFx = FFT_GLOW
  fontScale = getFontScale()
}


style.lineForeground <- class {
  fillColor = Color(0, 0, 0, 0)
  lineWidth = hdpx(1) * LINE_WIDTH
  font = Fonts.hud
  fontFxColor = fontOutlineColor
  fontFxFactor = 40
  fontFx = FFT_GLOW
  fontScale = getFontScale()
}

local isHitAimVisible = Watched(false)

::interop.updateHitAim <- function(isVisible) {
  isHitAimVisible.update(isVisible)
}


local HelicopterRocketAim = function(line_style, isBackground) {

  local lines = @() line_style.__merge({
      rendObj = ROBJ_VECTOR_CANVAS
      size = [sh(0.8), sh(1.8)]
      color = getColor(isBackground)
      commands = [
        [VECTOR_LINE, -100, -100, 100, -100],
        [VECTOR_LINE, -100, 100, 100, 100],
        [VECTOR_LINE, -20, -100, -20, 100],
        [VECTOR_LINE, 20, -100, 20, 100],
      ]
    })

  return @(){
    halign = HALIGN_CENTER
    valign = VALIGN_MIDDLE
    size = SIZE_TO_CONTENT
    watch = [helicopterState.RocketAimX, helicopterState.RocketAimY, helicopterState.RocketAimVisible]
    opacity = helicopterState.RocketAimVisible.value ? 100 : 0
    transform = {
      translate = [helicopterState.RocketAimX.value, helicopterState.RocketAimY.value]
    }
    children = [lines]
  }
}

local HelicopterAamAimGimbal = function(line_style, isBackground) {
  local circle = @() line_style.__merge({
      rendObj = ROBJ_VECTOR_CANVAS
      size = [sh(14.0), sh(14.0)]
      color = getColor(isBackground)
      commands = [
        [VECTOR_ELLIPSE, 0, 0, helicopterState.AamAimGimbalSize.value, helicopterState.AamAimGimbalSize.value]
      ]
    })

  return @(){
    halign = HALIGN_CENTER
    valign = VALIGN_MIDDLE
    size = SIZE_TO_CONTENT
    watch = [helicopterState.AamAimGimbalX, helicopterState.AamAimGimbalY, helicopterState.AamAimGimbalVisible]
    opacity = helicopterState.AamAimGimbalVisible.value ? 100 : 0
    transform = {
      translate = [helicopterState.AamAimGimbalX.value, helicopterState.AamAimGimbalY.value]
    }
    children = [circle]
  }
}

local HelicopterAamAimTracker = function(line_style, isBackground) {
  local circle = @() line_style.__merge({
      rendObj = ROBJ_VECTOR_CANVAS
      size = [sh(14.0), sh(14.0)]
      color = getColor(isBackground)
      commands = [
        [VECTOR_ELLIPSE, 0, 0, helicopterState.AamAimTrackerSize.value, helicopterState.AamAimTrackerSize.value]
      ]
    })

  return @(){
    halign = HALIGN_CENTER
    valign = VALIGN_MIDDLE
    size = SIZE_TO_CONTENT
    watch = [helicopterState.AamAimTrackerX, helicopterState.AamAimTrackerY, helicopterState.AamAimTrackerVisible]
    opacity = helicopterState.AamAimTrackerVisible.value ? 100 : 0
    transform = {
      translate = [helicopterState.AamAimTrackerX.value, helicopterState.AamAimTrackerY.value]
    }
    children = [circle]
  }
}


local createHitMarker = function(elemStyle, isBackground) {
  local width = hdpx(34)
  local color = getColor(isBackground)

  return @() elemStyle.__merge( {
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, width]
    color = color
    pos = [-0.5 * width, -0.5 * width]
    commands = [
      [VECTOR_LINE, 0, 0, 20, 20],
      [VECTOR_LINE, 80, 80, 100, 100],
      [VECTOR_LINE, 0, 100, 20, 80],
      [VECTOR_LINE, 80, 20, 100, 0]
    ]
  })
}


local createHitMarkerComponent = function(elemStyle, isBackground, pos) {
  return @() {
    watch = isHitAimVisible
    pos = pos
    children = isHitAimVisible.value ? createHitMarker(elemStyle, isBackground) : null
    size = SIZE_TO_CONTENT
  }
}


local HelicopterGunDirection = function(line_style, isBackground) {
  local sqL = 80
  local l = 20
  local offset = (100 - sqL) * 0.5

  local getCommands = function() {
    local commands = [
      [VECTOR_LINE, -50 + offset, -50 + offset, 50 - offset, -50 + offset],
      [VECTOR_LINE, 50 - offset, 50 - offset, 50 - offset, -50 + offset],
      [VECTOR_LINE, -50 + offset, 50 - offset, 50 - offset, 50 - offset],
      [VECTOR_LINE, -50 + offset, -50 + offset, -50 + offset, 50 - offset]
    ]

    local commandsDash = [
      [VECTOR_LINE, 0, -50, 0, -50 + l],
      [VECTOR_LINE, 50 - l, 0, 50, 0],
      [VECTOR_LINE, 0, 50 - l, 0, 50],
      [VECTOR_LINE, -50, 0, -50 + l, 0]
    ]

    local mainCommands = []
    local overheatCommands = []

    for (local i = 0; i < commands.len(); ++i)
    {
      if (i >= helicopterState.GunOverheatState.value)
      {
        mainCommands.append(commands[i])
        if (!helicopterState.IsCanEmpty.value || !helicopterState.IsMachineGunEmpty.value)
          mainCommands.append(commandsDash[i])
      }
      else
      {
        overheatCommands.append(commands[i])
        if (!helicopterState.IsCanEmpty.value || !helicopterState.IsMachineGunEmpty.value)
          overheatCommands.append(commandsDash[i])
      }
    }

    return {
      mainCommands = mainCommands
      overheatCommands = overheatCommands
    }
  }

  local lines = @() line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [sh(2), sh(2)]
    color = getColor(isBackground)
    commands = getCommands().mainCommands
  })

  local linesOverheat = @() line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [sh(2), sh(2)]
    color = isBackground ? backgroundColor : helicopterState.AlertColor.value
    commands = getCommands().overheatCommands
  })

  return @() {
    size = SIZE_TO_CONTENT
    halign = HALIGN_CENTER
    valign = VALIGN_MIDDLE
    watch = [helicopterState.IsCanEmpty, helicopterState.IsMachineGunEmpty, helicopterState.GunOverheatState,
      helicopterState.GunDirectionX, helicopterState.GunDirectionY, helicopterState.GunDirectionVisible]
    opacity = helicopterState.GunDirectionVisible.value ? 100 : 0
    transform = {
      translate = [helicopterState.GunDirectionX.value, helicopterState.GunDirectionY.value]
    }
    children = [
      lines,
      linesOverheat
    ]
  }
}


local HelicopterFixedGunsDirection = function(line_style, isBackground) {
  local w = sh(0.625)

  local lines = @() line_style.__merge({
      rendObj = ROBJ_VECTOR_CANVAS
      size = [w, w]
      color = getColor(isBackground)
      commands = [
        [VECTOR_LINE, 0, 50, 0, 150],
        [VECTOR_LINE, 0, -50, 0, -150],
        [VECTOR_LINE, 50, 0, 150, 0],
        [VECTOR_LINE, -50, 0, -150, 0],
      ]
    })

  return @() {
    size = [w, w]
    halign = HALIGN_CENTER
    valign = VALIGN_MIDDLE
    watch = [helicopterState.FixedGunDirectionVisible,
             helicopterState.FixedGunDirectionX,
             helicopterState.FixedGunDirectionY]
    opacity = helicopterState.FixedGunDirectionVisible.value ? 100 : 0
    transform = {
      translate = [helicopterState.FixedGunDirectionX.value, helicopterState.FixedGunDirectionY.value]
    }
    children = [
      lines,
      createHitMarkerComponent(line_style, isBackground, [hdpx(14), hdpx(14)])
    ]
  }
}


local verticalSpeedInd = function(line_style, height, isBackground) {
  return @() line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [height, height]
    pos = [0, -height*0.25]
    color = getColor(isBackground)
    commands = [
      [VECTOR_LINE, 0, 25, 100, 50, 100, 0, 0, 25],
    ]
  })
}

local verticalSpeedScale = function(line_style, width, height, isBackground) {
  local part1_16 = 0.0625 * 100
  local lineStart = 70

  return @() line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, height]
    halign = HALIGN_RIGHT
    color = getColor(isBackground)
    commands = [
      [VECTOR_LINE, 0,         0,           100, 0],
      [VECTOR_LINE, lineStart, part1_16,    100, part1_16],
      [VECTOR_LINE, lineStart, 2*part1_16,  100, 2*part1_16],
      [VECTOR_LINE, lineStart, 3*part1_16,  100, 3*part1_16],
      [VECTOR_LINE, 0,         25,          100, 25],
      [VECTOR_LINE, lineStart, 5*part1_16,  100, 5*part1_16],
      [VECTOR_LINE, lineStart, 6*part1_16,  100, 6*part1_16],
      [VECTOR_LINE, lineStart, 7*part1_16,  100, 7*part1_16],
      [VECTOR_LINE, 0,         50,          100, 50],
      [VECTOR_LINE, lineStart, 9*part1_16,  100, 9*part1_16],
      [VECTOR_LINE, lineStart, 10*part1_16, 100, 10*part1_16],
      [VECTOR_LINE, lineStart, 11*part1_16, 100, 11*part1_16],
      [VECTOR_LINE, 0,         75,          100, 75],
      [VECTOR_LINE, lineStart, 13*part1_16, 100, 13*part1_16],
      [VECTOR_LINE, lineStart, 14*part1_16, 100, 14*part1_16],
      [VECTOR_LINE, lineStart, 15*part1_16, 100, 15*part1_16],
      [VECTOR_LINE, 0,         100,         100, 100],
    ]
  })
}


local HelicopterVertSpeed = function(elemStyle, scaleWidth, height, posX, isBackground) {

  local getRelativeHeight = @() ::clamp(helicopterState.DistanceToGround.value * 2.0, 0, 100)

  return {
    pos = [posX, sh(50) - height*0.5]
    children = [
      {
        children = verticalSpeedScale(elemStyle, scaleWidth, height, isBackground)
      }
      {
        valign = VALIGN_BOTTOM
        halign = HALIGN_RIGHT
        size = [scaleWidth, height]
        children = @() elemStyle.__merge({
          rendObj = ROBJ_VECTOR_CANVAS
          pos = [LINE_WIDTH, 0]
          size = [LINE_WIDTH, height]
          tmpHeight = 0
          fillColor = getColor(isBackground)
          color = getColor(isBackground)
          watch = helicopterState.DistanceToGround
          opacity = helicopterState.DistanceToGround.value > 50.0 ? 0 : 100
          commands = [[VECTOR_RECTANGLE, 0, 100 - getRelativeHeight(), 100, getRelativeHeight()]]
        })
      }
      {
        halign = HALIGN_RIGHT
        valign = VALIGN_MIDDLE
        size = [-0.5*scaleWidth, height]
        children = @() elemStyle.__merge({
          rendObj = ROBJ_DTEXT
          halign = HALIGN_RIGHT
          size = [scaleWidth*4,SIZE_TO_CONTENT]
          color = getColor(isBackground)
          watch = helicopterState.DistanceToGround
          text = alienNumbers.getNumStr(::math.floor(helicopterState.DistanceToGround.value))
        })
      }
      @(){
        watch = helicopterState.VerticalSpeed
        pos = [scaleWidth + sh(0.5), 0]
        transform = {
          translate = [0, height * 0.01 * clamp(50 - helicopterState.VerticalSpeed.value * 5.0, 0, 100)]
        }
        children = [
          verticalSpeedInd(elemStyle, hdpx(25), isBackground),
          {
            pos = [scaleWidth + hdpx(10), hdpx(-10)]
            children = @() elemStyle.__merge({
              rendObj = ROBJ_DTEXT
              size = [scaleWidth*4,SIZE_TO_CONTENT]
              color = getColor(isBackground)
              watch = helicopterState.VerticalSpeed
              text = alienNumbers.getNumStr(::math.round(helicopterState.VerticalSpeed.value))
            })
          }
        ]
      }

    ]
  }
}


local airHorizonZeroLevel = function(line_style, height, isBackground) {
  return @() line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [4*height, height]
    color = getColor(isBackground)
    commands = [
      [VECTOR_LINE, 0, 50, 15, 50],
      [VECTOR_LINE, 85, 50, 100, 50],
    ]
  })
}


local airHorizon = function(line_style, height, isBackground) {
  return @() line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [4*height, height]
    color = getColor(isBackground)
    commands = [
      [VECTOR_LINE, 20, 50,  32, 50,  41, 100,  50, 50,  59, 100,  68, 50,  80, 50],
    ]
    watch = helicopterState.HorAngle
    transform = {
      pivot = [0.5, 0.5]
      rotate = helicopterState.HorAngle.value
    }
  })
}


local horizontalSpeedVector = function(line_style, height, isBackground) {
  return @() line_style.__merge({
    rendObj = ROBJ_HELICOPTER_HORIZONTAL_SPEED
    size = [height, height]
    color = getColor(isBackground)
    minLengthArrowVisibleSq = 200
    velocityScale = 5
  })
}


local HelicopterHorizontalSpeedComponent = function(elemStyle, isBackground) {
  local height = hdpx(40)

  return function() {
    return {
      pos = [sw(50) - 2* height, sh(50) - height*0.5]
      size = [4*height, height]
      children = [
        airHorizonZeroLevel(elemStyle, height, isBackground)
        airHorizon(elemStyle, height, isBackground)
        {
          pos = [height, -0.5*height]
          children = [
            horizontalSpeedVector(elemStyle, 2 * height, isBackground)
          ]
        }
      ]
    }
  }
}


local turretAngles = function(line_style, height, aspect, isBackground) {
  local hl = 20
  local vl = 20

  local crossL = 2
  local offset = 1.3

  local getCommands = function() {
    local px = helicopterState.TurretYaw.value * 100.0
    local py = 100 - helicopterState.TurretPitch.value * 100.0
    return [
      [VECTOR_LINE, px - crossL - offset, py, px - offset, py],
      [VECTOR_LINE, px + offset, py, px + crossL + offset, py],
      [VECTOR_LINE, px, py - crossL * aspect - offset * aspect, px, py - offset * aspect],
      [VECTOR_LINE, px, py + crossL * aspect + offset * aspect, px, py + offset * aspect]
    ]
  }

  return @() line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [aspect * height, height]
    color = getColor(isBackground)
    commands = [
      [VECTOR_LINE, 0, 100 - vl, 0, 100, hl, 100],
      [VECTOR_LINE, 100 - hl, 100, 100, 100, 100, 100 - vl],
      [VECTOR_LINE, 100, vl, 100, 0, 100 - hl, 0],
      [VECTOR_LINE, hl, 0, 0, 0, 0, vl]
    ]
    children = [
      @() line_style.__merge({
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = hdpx(LINE_WIDTH + 2)
        size = [aspect * height, height]
        color = getColor(isBackground)
        watch = [helicopterState.TurretYaw, helicopterState.TurretPitch]
        commands = getCommands()
      })
    ]
  })
}


local turretAnglesComponent = function(elemStyle, isBackground) {
  local height = hdpx(150)
  local aspect = 2.0

  return {
    pos = [sw(50) - aspect * height * 0.5, sh(90) - height]
    size = SIZE_TO_CONTENT
    children = turretAngles(elemStyle, height, aspect, isBackground)
  }
}


local generateBulletsTextFunction = function(countWatched, secondsWatched) {
  return function() {
    if (secondsWatched.value >= 0)
    {
      local mnt = alienNumbers.getNumStr(::math.floor(secondsWatched.value / 60))
      local sec = alienNumbers.getNumStr(::string.format("%02d", secondsWatched.value % 60))
      local str = mnt + ::loc("HUD/alien/comma") + sec
      if (countWatched.value > 0)
        str += " (" + alienNumbers.getNumStr(countWatched.value) + ")"
      return str
    }
    else if (countWatched.value >= 0)
      return alienNumbers.getNumStr(countWatched.value)
    else
      return ""
  }
}


local getThrottleText = function() {
  local value = alienNumbers.convPercentage(helicopterState.Trt.value)
  return alienNumbers.getNumStr(value) + ::loc("HUD/alien/percent", "%")
}


local createHelicopterParam = function(param, width, line_style, isBackground)
{
  local rowHeight = hdpx(28)

  local captionComponent = line_style.__merge({
    rendObj = ROBJ_STEXT
    size = [0.4*width, rowHeight]
    text = param.title
    color = getColor(isBackground)
  })

  return function() {
    return {
      size = SIZE_TO_CONTENT
      flow = FLOW_HORIZONTAL
      children = [
        captionComponent
        @() line_style.__merge({
          color = getColor(isBackground)
          rendObj = ROBJ_DTEXT
          size = [0.6*width, rowHeight]
          text = param.value()
          watch = param.valuesWatched
        })
      ]
    }
  }
}


local textParamsMap = {
  [HelicopterParams.THROTTLE] = {
    title = throttleStr
    value = @() getThrottleText()
    titleWatched = helicopterState.TrtMode
    valuesWatched = [helicopterState.Trt, helicopterState.TrtMode]
  },
  [HelicopterParams.SPEED] = {
    title = velocityStr
    value = @() alienNumbers.getNumStr(helicopterState.Spd.value) + " " + velocityUnit
    valuesWatched = helicopterState.Spd
  },
  [HelicopterParams.CANNON] = {
    title = gunStr
    value = generateBulletsTextFunction(helicopterState.Cannons.count, helicopterState.Cannons.seconds)
    valuesWatched = [helicopterState.Cannons.count, helicopterState.Cannons.seconds, helicopterState.IsCanEmpty]
    alertWatched = helicopterState.IsCanEmpty
  },
  [HelicopterParams.ROCKET] = {
    title = rocketsStr
    value = generateBulletsTextFunction(helicopterState.Rockets.count, helicopterState.Rockets.seconds)
    valuesWatched = [helicopterState.Rockets.count, helicopterState.Rockets.seconds, helicopterState.IsRktEmpty]
    alertWatched = helicopterState.IsRktEmpty
  }
}


local paramsTableWidth = hdpx(450)
local paramsSightTableWidth = hdpx(220)


local generateParamsTable = function(mask, width, pos, gap) {
  local getChildren = function(line_style, isBackground)
  {
    local children = []
    foreach(key, param in textParamsMap)
    {
      if ((1 << key) & mask.value)
        children.append(createHelicopterParam(param, width, line_style, isBackground))
    }
    return children
  }

  return function(line_style, isBackground){
    return {
      children = @() line_style.__merge({
        watch = mask
        color = getColor(isBackground)
        pos = pos
        size = [width, SIZE_TO_CONTENT]
        flow = FLOW_VERTICAL
        gap = gap
        children = getChildren(line_style, isBackground)
      })
    }
  }
}


local helicopterParamsTable = generateParamsTable(helicopterState.MainMask,
  paramsTableWidth,
  [max(screenState.safeAreaSizeHud.value.borders[1], sw(50) - hdpx(660)), sh(50) - hdpx(100)],
  hdpx(5))

local helicopterSightParamsTable = generateParamsTable(helicopterState.SightMask,
  paramsSightTableWidth,
  [sw(50) - hdpx(250) - hdpx(180), hdpx(480)],
  hdpx(3))


local lockSight = function(line_style, width, height, isBackground) {
  local hl = 20
  local vl = 20

  return @() line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, height]
    watch = helicopterState.IsAgmEmpty
    color = !isBackground && helicopterState.IsAgmEmpty.value ? helicopterState.AlertColor.value : getColor(isBackground)
    commands = [
      [VECTOR_LINE, 0, 0, hl, vl],
      [VECTOR_LINE, 0, 100, vl, 100 - vl],
      [VECTOR_LINE, 100, 100, 100 - hl, 100 - vl],
      [VECTOR_LINE, 100, 0, 100 - hl, vl]
    ]
  })
}


local lockSightComponent = function(elemStyle, isBackground) {
  local width = hdpx(150)
  local height = hdpx(100)

  return @() {
    pos = [sw(50) - width * 0.5, sh(50) - height * 0.5]
    watch = helicopterState.IsSightLocked
    opacity = helicopterState.IsSightLocked.value ? 100 : 0
    size = SIZE_TO_CONTENT
    children = lockSight(elemStyle, width, height, isBackground)
  }
}


local sight = function(line_style, height, isBackground) {
  local longL = 22
  local shortL = 10
  local dash = 0.8
  local centerOffset = 3

  return @() line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [height, height]
    color = getColor(isBackground)
    commands = [
      [VECTOR_LINE, 0, 50, longL, 50],
      [VECTOR_LINE, 100 - longL, 50, 100, 50],
      [VECTOR_LINE, 50, 100, 50, 100 - longL],
      [VECTOR_LINE, 50, 0, 50, longL],

      [VECTOR_LINE, 50 - shortL - centerOffset, 50, 50 - centerOffset, 50],
      [VECTOR_LINE, 50 + centerOffset, 50, 50 + centerOffset + shortL, 50],
      [VECTOR_LINE, 50, 50 + centerOffset, 50, 50 + centerOffset + shortL],
      [VECTOR_LINE, 50, 50 - shortL - centerOffset, 50, 50 - centerOffset],

      [VECTOR_LINE, 50 - centerOffset, 50 - dash , 50 - centerOffset, 50 + dash],
      [VECTOR_LINE, 50 + centerOffset, 50 - dash , 50 + centerOffset, 50 + dash],
      [VECTOR_LINE, 50 - dash , 50 - centerOffset, 50 + dash, 50 - centerOffset],
      [VECTOR_LINE, 50 - dash , 50 + centerOffset, 50 + dash, 50 + centerOffset],
    ]
  })
}


local sightComponent = function(elemStyle, isBackground) {
  local height = hdpx(500)

  return {
    pos = [sw(50) - height * 0.5, sh(50) - height * 0.5]
    size = SIZE_TO_CONTENT
    children = sight(elemStyle, height, isBackground)
  }
}

local rangeFinderComponent = function(elemStyle, isBackground) {
  local rangefinder = @() elemStyle.__merge({
    rendObj = ROBJ_DTEXT
    halign = HALIGN_CENTER
    text = math.round_by_value(helicopterState.RangefinderDist.value, 1)
    opacity = helicopterState.IsRangefinderEnabled.value ? 100 : 0
    watch = [helicopterState.RangefinderDist, helicopterState.IsRangefinderEnabled]
    color = getColor(isBackground)
  })

  local resCompoment = @() {
    pos = [sw(50), sh(59)]
    halign = HALIGN_CENTER
    size = [0, 0]
    children = rangefinder
  }

  return resCompoment
}


local compassComponent = function(elemStyle, isBackground) {
  local color = getColor(isBackground)

  return {
    size = SIZE_TO_CONTENT
    pos = [sw(50) - 0.5 * compassWidth, sh(15)]
    children = compass(elemStyle, compassWidth, compassHeight, color)
  }
}


local helicopterMainHud = function(elemStyle, isBackground) {
  return @(){
    watch = helicopterState.IsMainHudVisible
    children = helicopterState.IsMainHudVisible.value
    ? [
      HelicopterRocketAim(elemStyle, isBackground)
      HelicopterAamAimGimbal(elemStyle, isBackground)
      HelicopterAamAimTracker(elemStyle, isBackground)
      HelicopterGunDirection(elemStyle, isBackground)
      HelicopterFixedGunsDirection(elemStyle, isBackground)
      HelicopterVertSpeed(elemStyle, sh(1.9), sh(15), sw(50) + hdpx(384), isBackground)
      HelicopterHorizontalSpeedComponent(elemStyle, isBackground)
      helicopterParamsTable(elemStyle, isBackground)
      compassComponent(elemStyle, isBackground)
    ]
    : null
  }
}


local helicopterSightHud = function(elemStyle, isBackground) {
  return @(){
    watch = helicopterState.IsSightHudVisible
    children = helicopterState.IsSightHudVisible.value
    ? [
      HelicopterVertSpeed(elemStyle, sh(3.6), sh(30), sw(50) + hdpx(384), isBackground)
      turretAnglesComponent(elemStyle, isBackground)
      helicopterSightParamsTable(elemStyle, isBackground)
      lockSightComponent(elemStyle, isBackground)
      sightComponent(elemStyle, isBackground)
      rangeFinderComponent(elemStyle, isBackground)
      compassComponent(elemStyle, isBackground)
    ]
    : null
  }
}


local gunnerHud = function(elemStyle, isBackground) {
  return @(){
    watch = helicopterState.IsGunnerHudVisible
    children = helicopterState.IsGunnerHudVisible.value
    ? [
      HelicopterRocketAim(elemStyle, isBackground)
      HelicopterAamAimGimbal(elemStyle, isBackground)
      HelicopterAamAimTracker(elemStyle, isBackground)
      HelicopterGunDirection(elemStyle, isBackground)
      HelicopterFixedGunsDirection(elemStyle, isBackground)
      HelicopterVertSpeed(elemStyle, sh(1.9), sh(15), sw(50) + hdpx(384), isBackground)
      helicopterParamsTable(elemStyle, isBackground)
    ]
    : null
  }
}


local function pilotHud(elemStyle, isBackground) {
  return @(){
    watch = helicopterState.IsPilotHudVisible
    children = helicopterState.IsPilotHudVisible.value
    ? [
      HelicopterVertSpeed(elemStyle, sh(1.9), sh(15), sw(50) + hdpx(384), isBackground)
      helicopterParamsTable(elemStyle, isBackground)
    ]
    : null
  }
}


local helicopterHUDs = function (colorStyle, isBackground) {
  return [
    helicopterMainHud(colorStyle, isBackground)
    helicopterSightHud(colorStyle, isBackground)
    gunnerHud(colorStyle, isBackground)
    pilotHud(colorStyle, isBackground)
  ]
}


local Root = function() {
  local children = helicopterHUDs(style.lineBackground, true)
  children.extend(helicopterHUDs(style.lineForeground, false))

  return {
    watch = [
      helicopterState.IndicatorsVisible
    ]
    halign = HALIGN_LEFT
    valign = VALIGN_TOP
    size = [sw(100), sh(100)]
    children = helicopterState.IndicatorsVisible.value ? children : null
  }
}


return Root
