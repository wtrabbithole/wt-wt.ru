local math = require("std/math.nut")
local interopGet = require("daRg/helpers/interopGen.nut")

local style = {}

local greenColor = Color(71, 232, 39, 200)
local backgroundColor = Color(0, 0, 0, 150)
local fontOutlineColor = Color(0, 0, 0, 235)

const LINE_WIDTH = 1.6
const NUM_ENGINES_MAX = 3


local temperatureUnit = null
local velocityUnit = null


local getTemperatureUnit = function(){
  if (temperatureUnit)
    return temperatureUnit

  temperatureUnit = ::cross_call.measureTypes.TEMPERATURE.getMeasureUnitsName()
  return temperatureUnit
}


local getVelocityUnit = function(){
  if (velocityUnit)
    return velocityUnit

  velocityUnit = ::cross_call.measureTypes.SPEED.getMeasureUnitsName()
  return velocityUnit
}


local helicopterState = {
  IndicatorsVisible = Watched(false)
  DistanceToGround = Watched(0.0)
  VerticalSpeed = Watched(0.0)

  RocketAimX = Watched(0.0)
  RocketAimY = Watched(0.0)
  RocketAimVisible = Watched(false)

  AamAimGimbalX = Watched(0.0)
  AamAimGimbalY = Watched(0.0)
  AamAimGimbalSize = Watched(0.0)
  AamAimGimbalVisible = Watched(false)

  AamAimTrackerX = Watched(0.0)
  AamAimTrackerY = Watched(0.0)
  AamAimTrackerSize = Watched(0.0)
  AamAimTrackerVisible = Watched(false)

  GunDirectionX = Watched(0.0)
  GunDirectionY = Watched(0.0)
  GunDirectionVisible = Watched(false)

  HorAngle = Watched(0.0)

  TurretYaw = Watched(0.0)
  TurretPitch = Watched(0.0)

  IsSightLocked = Watched(false)

  MainMask = Watched(0)
  SightMask = Watched(0)

  HudColor = Watched(Color(71, 232, 39, 240))
  AlertColor = Watched(Color(255, 0, 0, 240))

  TrtMode = Watched(0)

  Rpm = Watched(0)
  Trt = Watched(0)
  Spd = Watched(0)

  Cannons = {
    count = Watched(0)
    seconds = Watched(-1)
  }

  CannonsAdditional = {
    count = Watched(0)
    seconds = Watched(-1)
  }

  Rockets = {
    count = Watched(0)
    seconds = Watched(-1)
  }

  Agm = {
    count = Watched(0)
    seconds = Watched(-1)
  }

  Aam = {
    count = Watched(0)
    seconds = Watched(-1)
  }

  Bombs = {
    count = Watched(0)
    seconds = Watched(-1)
  }

  Flares = {
    count = Watched(0)
    seconds = Watched(-1)
  }

  IsCanEmpty = Watched(false)
  IsCanAdditionalEmpty = Watched(false)
  IsRktEmpty = Watched(false)
  IsAgmEmpty = Watched(false)
  IsAamEmpty = Watched(false)
  IsBmbEmpty = Watched(false)
  IsFlrEmpty = Watched(false)

  IsHighRateOfFire = Watched(false)

  IsRpmCritical = Watched(false)

  FixedGunDirectionX = Watched(-100)
  FixedGunDirectionY = Watched(-100)
  FixedGunDirectionVisible = Watched(false)

  IsRangefinderEnabled = Watched(false)
  RangefinderDist = Watched(0)

  OilTemperature = []
  WaterTemperature = []
  EngineTemperature = []

  OilState = []
  WaterState = []
  EngineState = []

  IsOilAlert = []
  IsWaterAlert = []
  IsEngineAlert = []

  IsMainHudVisible = Watched(false)
  IsSightHudVisible = Watched(false)
  IsPilotHudVisible = Watched(false)
  IsGunnerHudVisible = Watched(false)

  GunOverheatState = Watched(0)
}

::interop.updateCannons <- function(count, sec = -1) {
  helicopterState.Cannons.count.update(count)
  helicopterState.Cannons.seconds.update(sec)
}

::interop.updateAdditionalCannons <- function(count, sec = -1) {
  helicopterState.CannonsAdditional.count.update(count)
}

::interop.updateRockets <- function(count, sec = -1) {
  helicopterState.Rockets.count.update(count)
  helicopterState.Rockets.seconds.update(sec)
}

::interop.updateAgm <- function(count, sec = -1) {
  helicopterState.Agm.count.update(count)
  helicopterState.Agm.seconds.update(sec)
}

::interop.updateAam <- function(count, sec = -1) {
  helicopterState.Aam.count.update(count)
  helicopterState.Aam.seconds.update(sec)
}

::interop.updateBombs <- function(count, sec = -1) {
  helicopterState.Bombs.count.update(count)
  helicopterState.Bombs.seconds.update(sec)
}

::interop.updateFlares <- function(count, sec = -1) {
  helicopterState.Flares.count.update(count)
  helicopterState.Flares.seconds.update(sec)
}

for (local i = 0; i < NUM_ENGINES_MAX; ++i)
{
  helicopterState.OilTemperature.append(Watched(0))
  helicopterState.WaterTemperature.append(Watched(0))
  helicopterState.EngineTemperature.append(Watched(0))

  helicopterState.OilState.append(Watched(0))
  helicopterState.WaterState.append(Watched(0))
  helicopterState.EngineState.append(Watched(0))

  helicopterState.IsOilAlert.append(Watched(false))
  helicopterState.IsWaterAlert.append(Watched(false))
  helicopterState.IsEngineAlert.append(Watched(false))
}

interopGet({
  stateTable = helicopterState
  prefix = "helicopter"
  postfix = "Update"
})

::interop.updateOilTemperature <- function (temperature, state, index) {
  helicopterState.OilTemperature[index].update(temperature)
  helicopterState.OilState[index].update(state)
}

::interop.updateWaterTemperature <- function (temperature, state, index) {
  helicopterState.WaterTemperature[index].update(temperature)
  helicopterState.WaterState[index].update(state)
}

::interop.updateEngineTemperature <- function (temperature, state, index) {
  helicopterState.EngineTemperature[index].update(temperature)
  helicopterState.EngineState[index].update(state)
}

::interop.updateOilAlert <- function (value, index) {
  helicopterState.IsOilAlert[index].update(value)
}

::interop.updateWaterAlert <- function (value, index) {
  helicopterState.IsWaterAlert[index].update(value)
}

::interop.updateEngineAlert <- function (value, index) {
  helicopterState.IsEngineAlert[index].update(value)
}


local getColor = function(isBackground){
  return isBackground ? backgroundColor : helicopterState.HudColor.value
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
  watch = [helicopterState.HudColor]
  fillColor = Color(0, 0, 0, 0)
  lineWidth = hdpx(1) * LINE_WIDTH
  font = Fonts.hud
  fontFxColor = fontOutlineColor
  fontFxFactor = 40
  fontFx = FFT_GLOW
  fontScale = getFontScale()
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
        if (!helicopterState.IsCanEmpty.value)
          mainCommands.append(commandsDash[i])
      }
      else
      {
        overheatCommands.append(commands[i])
        if (!helicopterState.IsCanEmpty.value)
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
    watch = [helicopterState.IsCanEmpty, helicopterState.GunOverheatState,
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

  local lines = @() line_style.__merge({
      rendObj = ROBJ_VECTOR_CANVAS
      size = [sh(0.625), sh(0.625)]
      color = getColor(isBackground)
      commands = [
        [VECTOR_LINE, 0, 50, 0, 150],
        [VECTOR_LINE, 0, -50, 0, -150],
        [VECTOR_LINE, 50, 0, 150, 0],
        [VECTOR_LINE, -50, 0, -150, 0],
      ]
    })

  return @() {
    size = SIZE_TO_CONTENT
    halign = HALIGN_CENTER
    valign = VALIGN_MIDDLE
    watch = [helicopterState.FixedGunDirectionVisible,
             helicopterState.FixedGunDirectionX,
             helicopterState.FixedGunDirectionY]
    opacity = helicopterState.FixedGunDirectionVisible.value ? 100 : 0
    transform = {
      translate = [helicopterState.FixedGunDirectionX.value, helicopterState.FixedGunDirectionY.value]
    }
    children = [lines]
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
          text = ::math.floor(helicopterState.DistanceToGround.value).tostring()
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
              text = math.round_by_value(helicopterState.VerticalSpeed.value, 1).tostring()
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
      local str = ::string.format("%d:%02d", ::math.floor(secondsWatched.value / 60), secondsWatched.value % 60)
      if (countWatched.value > 0)
        str += " (" + countWatched.value + ")"
      return str
    }
    else if (countWatched.value > 0)
      return countWatched.value
    else
      return ""
  }
}


local generateTemperatureTextFunction = function(temperatureWatched, stateWatched) {
  return function() {
    if (stateWatched.value == TemperatureState.OVERHEAT)
      return temperatureWatched.value + getTemperatureUnit()
    else if (stateWatched.value == TemperatureState.EMPTY_TANK)
      return ::loc("HUD_TANK_IS_EMPTY")
    else if (stateWatched.value == TemperatureState.FUEL_LEAK)
      return ::loc("HUD_FUEL_LEAK")
    else if (stateWatched.value == TemperatureState.BLANK)
      return ""

    return ""
  }
}


local getThrottleText = function() {

  if ( helicopterState.TrtMode.value == HelicopterThrottleMode.DEFAULT_MODE
    || helicopterState.TrtMode.value == HelicopterThrottleMode.CLIMB)
    return helicopterState.Trt.value + "%"
  else if (helicopterState.TrtMode.value == HelicopterThrottleMode.BRAKE)
    return ::loc("HUD/BRAKE_SHORT")
  else if (helicopterState.TrtMode.value == HelicopterThrottleMode.WEP)
    return ::loc("HUD/WEP_SHORT")

  return ""
}


local getThrottleCaption = function() {
  return (helicopterState.TrtMode.value == HelicopterThrottleMode.CLIMB)
    ? ::loc("HUD/CLIMB_SHORT")
    : ::loc("HUD/PROP_PITCH_SHORT")
}


local createHelicopterParam = function(param, width, line_style, isBackground)
{
  local rowHeight = hdpx(28)

  local selectColor = function(){
    return param?.alertWatched && param.alertWatched.value && !isBackground
      ? helicopterState.AlertColor.value
      : getColor(isBackground)
  }

  local captionComponent = @() line_style.__merge({
    rendObj = ROBJ_DTEXT
    size = [0.4*width, rowHeight]
    text = param.title()
    watch = [param?.alertWatched, param?.titleWatched]
    color = selectColor()
  })

  return function() {
    return {
      size = SIZE_TO_CONTENT
      flow = FLOW_HORIZONTAL
      children = [
        captionComponent
        @() line_style.__merge({
          color = selectColor()
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
  [HelicopterParams.RPM] = {
    title = @() ::loc("HUD/PROP_RPM_SHORT")
    value = @() helicopterState.Rpm.value + "%"
    valuesWatched = [helicopterState.Rpm, helicopterState.IsRpmCritical]
    alertWatched = helicopterState.IsRpmCritical
  },
  [HelicopterParams.THROTTLE] = {
    title = @() getThrottleCaption()
    value = @() getThrottleText()
    titleWatched = helicopterState.TrtMode
    valuesWatched = [helicopterState.Trt, helicopterState.TrtMode]
  },
  [HelicopterParams.SPEED] = {
    title = @() ::loc("HUD/REAL_SPEED_SHORT")
    value = @() helicopterState.Spd.value + " " + getVelocityUnit()
    valuesWatched = helicopterState.Spd
  },
  [HelicopterParams.CANNON] = {
    title = @() ::loc("HUD/CANNONS_SHORT")
    value = generateBulletsTextFunction(helicopterState.Cannons.count, helicopterState.Cannons.seconds)
    valuesWatched = [helicopterState.Cannons.count, helicopterState.Cannons.seconds, helicopterState.IsCanEmpty]
    alertWatched = helicopterState.IsCanEmpty
  },
  [HelicopterParams.CANNON_ADDITIONAL] = {
    title = @() ::loc("HUD/ADDITIONAL_GUNS_SHORT")
    value = generateBulletsTextFunction(helicopterState.CannonsAdditional.count, helicopterState.CannonsAdditional.seconds)
    valuesWatched = [
      helicopterState.CannonsAdditional.count,
      helicopterState.CannonsAdditional.seconds,
      helicopterState.IsCanAdditionalEmpty
    ]
    alertWatched = helicopterState.IsCanAdditionalEmpty
  },
  [HelicopterParams.ROCKET] = {
    title = @() ::loc("HUD/RKT")
    value = generateBulletsTextFunction(helicopterState.Rockets.count, helicopterState.Rockets.seconds)
    valuesWatched = [helicopterState.Rockets.count, helicopterState.Rockets.seconds, helicopterState.IsRktEmpty]
    alertWatched = helicopterState.IsRktEmpty
  },
  [HelicopterParams.AGM] = {
    title = @() ::loc("HUD/AGM_SHORT")
    value = generateBulletsTextFunction(helicopterState.Agm.count, helicopterState.Agm.seconds)
    valuesWatched = [helicopterState.Agm.count, helicopterState.Agm.seconds, helicopterState.IsAgmEmpty]
    alertWatched = helicopterState.IsAgmEmpty
  },
  [HelicopterParams.AAM] = {
    title = @() ::loc("HUD/AAM_SHORT")
    value = generateBulletsTextFunction(helicopterState.Aam.count, helicopterState.Aam.seconds)
    valuesWatched = [helicopterState.Aam.count, helicopterState.Aam.seconds, helicopterState.IsAamEmpty]
    alertWatched = helicopterState.IsAamEmpty
  },
  [HelicopterParams.BOMBS] = {
    title = @() ::loc("HUD/BOMBS_SHORT")
    value = generateBulletsTextFunction(helicopterState.Bombs.count, helicopterState.Bombs.seconds)
    valuesWatched = [helicopterState.Bombs.count, helicopterState.Bombs.seconds, helicopterState.IsBmbEmpty]
    alertWatched = helicopterState.IsBmbEmpty
  },
  [HelicopterParams.RATE_OF_FIRE] = {
    title = @() ::loc("HUD/RATE_OF_FIRE_SHORT")
    value = @() helicopterState.IsHighRateOfFire.value ? ::loc("HUD/HIGHFREQ_SHORT") : ::loc("HUD/LOWFREQ_SHORT")
    valuesWatched = helicopterState.IsHighRateOfFire
  },
  [HelicopterParams.FLARES] = {
    title = @() ::loc("HUD/FLARES_SHORT")
    value = generateBulletsTextFunction(helicopterState.Flares.count, helicopterState.Flares.seconds)
    valuesWatched = [helicopterState.Flares.count, helicopterState.Flares.seconds, helicopterState.IsFlrEmpty]
    alertWatched = helicopterState.IsFlrEmpty
  },
}

for (local i = 0; i < NUM_ENGINES_MAX; ++i)
{
  local indexStr = (i+1).tostring()

  textParamsMap[HelicopterParams.OIL_1 + i] <- {
    title = @() ::loc("HUD/OIL_TEMPERATURE_SHORT" + indexStr)
    value = generateTemperatureTextFunction(helicopterState.OilTemperature[i], helicopterState.OilState[i])
    valuesWatched = [
      helicopterState.OilTemperature[i],
      helicopterState.OilState[i],
      helicopterState.IsOilAlert[i]
    ]
    alertWatched = helicopterState.IsOilAlert[i]
  }

  textParamsMap[HelicopterParams.WATER_1 + i] <- {
    title = @() ::loc("HUD/WATER_TEMPERATURE_SHORT" + indexStr)
    value = generateTemperatureTextFunction(helicopterState.WaterTemperature[i], helicopterState.WaterState[i])
    valuesWatched = [
      helicopterState.WaterTemperature[i],
      helicopterState.WaterState[i],
      helicopterState.IsWaterAlert[i]
    ]
    alertWatched = helicopterState.IsWaterAlert[i]
  }

  textParamsMap[HelicopterParams.ENGINE_1 + i] <- {
    title = @() ::loc("HUD/ENGINE_TEMPERATURE_SHORT" + indexStr)
    value = generateTemperatureTextFunction(helicopterState.EngineTemperature[i], helicopterState.EngineState[i])
    valuesWatched = [
      helicopterState.EngineTemperature[i],
      helicopterState.EngineState[i],
      helicopterState.IsEngineAlert[i]
    ]
    alertWatched = helicopterState.IsEngineAlert[i]
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
  [hdpx(300), sh(50) - hdpx(100)],
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

local helicopterMainHud = function (style, isBackground) {
  return @(){
    watch = helicopterState.IsMainHudVisible
    children = helicopterState.IsMainHudVisible.value
    ? [
      HelicopterRocketAim(style, isBackground)
      HelicopterAamAimGimbal(style, isBackground)
      HelicopterAamAimTracker(style, isBackground)
      HelicopterGunDirection(style, isBackground)
      HelicopterFixedGunsDirection(style, isBackground)
      HelicopterVertSpeed(style, sh(1.9), sh(15), sw(70), isBackground)
      HelicopterHorizontalSpeedComponent(style, isBackground)
      helicopterParamsTable(style, isBackground)
    ]
    : null
  }
}


local helicopterSightHud = function (style, isBackground) {
  return @(){
    watch = helicopterState.IsSightHudVisible
    children = helicopterState.IsSightHudVisible.value
    ? [
      HelicopterVertSpeed(style, sh(3.6), sh(30), sw(50) + hdpx(370), isBackground)
      turretAnglesComponent(style, isBackground)
      helicopterSightParamsTable(style, isBackground)
      lockSightComponent(style, isBackground)
      sightComponent(style, isBackground)
      rangeFinderComponent(style, isBackground)
    ]
    : null
  }
}


local gunnerHud = function (style, isBackground) {
  return @(){
    watch = helicopterState.IsGunnerHudVisible
    children = helicopterState.IsGunnerHudVisible.value
    ? [
      HelicopterRocketAim(style, isBackground)
      HelicopterAamAimGimbal(style, isBackground)
      HelicopterAamAimTracker(style, isBackground)
      HelicopterGunDirection(style, isBackground)
      HelicopterFixedGunsDirection(style, isBackground)
      HelicopterVertSpeed(style, sh(1.9), sh(15), sw(70), isBackground)
      helicopterParamsTable(style, isBackground)
    ]
    : null
  }
}


local pilotHud = function (style, isBackground) {
  return @(){
    watch = helicopterState.IsPilotHudVisible
    children = helicopterState.IsPilotHudVisible.value
    ? [
      HelicopterVertSpeed(style, sh(1.9), sh(15), sw(70), isBackground)
      helicopterParamsTable(style, isBackground)
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
      helicopterState.HudColor
    ]
    halign = HALIGN_LEFT
    valign = VALIGN_TOP
    size = [sw(100), sh(100)]
    children = helicopterState.IndicatorsVisible.value ? children : null
  }
}


return Root
