local math = require("std/math.nut")
local screenState = require("style/screenState.nut")
local compass = require("compass.nut")
local rwr = require("rwr.nut")
local helicopterState = require("helicopterState.nut")
local aamAim = require("rocketAamAim.nut")
local aamAimState = require("rocketAamAimState.nut")

local style = {}

local backgroundColor = Color(0, 0, 0, 150)
local fontOutlineColor = Color(0, 0, 0, 235)

const NUM_ENGINES_MAX = 3
const NUM_TRANSMISSIONS_MAX = 6

local compassWidth = hdpx(420)
local compassHeight = hdpx(40)

enum GuidanceLockResult {
  RESULT_INVALID = -1
  RESULT_STANDBY = 0
  RESULT_WARMING_UP = 1
  RESULT_LOCKING = 2
  RESULT_TRACKING = 3
}

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


local getColor = function(isBackground){
  return isBackground ? backgroundColor : helicopterState.HudColor.value
}

local getFontScale = function()
{
  return max(sh(100) / 1080, 1)
}

local getMfdFontScale = function()
{
  return helicopterState.IsMfdEnabled.value ? 1.5 : getFontScale()
}

local getIlsFontScale = function()
{
  return helicopterState.IsMfdEnabled.value ? 2.0 : getFontScale()
}

local sightSh = function(h)
{
  return helicopterState.IsMfdEnabled.value ? (h * helicopterState.SightHudPosSize[3] / 100) : sh(h)
}
local sightSw = function(w)
{
  return helicopterState.IsMfdEnabled.value ? (w * helicopterState.SightHudPosSize[2] / 100) : sw(w)
}
local sightHdpx = function(px)
{
  return helicopterState.IsMfdEnabled.value ? (px * helicopterState.SightHudPosSize[3] / 1024) : hdpx(px)
}
local pilotSh = function(h)
{
  return helicopterState.IsMfdEnabled.value ? (h * helicopterState.PilotHudPosSize[3] / 100) : sh(h)
}
local pilotSw = function(w)
{
  return helicopterState.IsMfdEnabled.value ? (w * helicopterState.PilotHudPosSize[2] / 100) : sw(w)
}
local pilotHdpx = function(px)
{
  return helicopterState.IsMfdEnabled.value ? (px * helicopterState.PilotHudPosSize[3] / 1024) : hdpx(px)
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


local HelicopterVertSpeed = function(elemStyle, scaleWidth, height, posX, posY, isBackground) {

  local getRelativeHeight = @() ::clamp(helicopterState.DistanceToGround.value * 2.0, 0, 100)

  return {
    pos = [posX, posY]
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


local HelicopterHorizontalSpeedComponent = function(elemStyle, isBackground, posX = sw(50), posY = sh(50)) {
  local height = helicopterState.IsMfdEnabled.value ? pilotHdpx(100) : hdpx(40)

  return function() {
    return {
      pos = [posX - 2* height, posY - height*0.5]
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

local function isInsideAgmLaunchAngularRange() {
  return helicopterState.IsInsideLaunchZoneYawPitch.value
}

local function isInsideAgmLaunchDistanceRange() {
  return helicopterState.IsInsideLaunchZoneDist.value
}

const fullRangeMultInv = 0.7
const outOfZoneLaunchShowTimeOut = 2.0

local function turretAngles(line_style, height, aspect, isBackground) {
  local hl = 20
  local vl = 20

  local offset = 1.3
  local crossL = 2

  local getTurretCommands = function() {
    local px = helicopterState.TurretYaw.value * 100.0
    local py = 100 - helicopterState.TurretPitch.value * 100.0
    return [
      [VECTOR_LINE, px - crossL - offset, py, px - offset, py],
      [VECTOR_LINE, px + offset, py, px + crossL + offset, py],
      [VECTOR_LINE, px, py - crossL * aspect - offset * aspect, px, py - offset * aspect],
      [VECTOR_LINE, px, py + crossL * aspect + offset * aspect, px, py + offset * aspect]
    ]
  }

  local getAgmLaunchAngularRangeCommands = function() {
    if (helicopterState.IsAgmLaunchZoneVisible.value &&
        helicopterState.LastAgmOutOfAngleLaunchAttemptTimeOut.value < outOfZoneLaunchShowTimeOut &&
        (helicopterState.AgmLaunchZoneYawMin.value > 0.0 || helicopterState.AgmLaunchZoneYawMax.value < 1.0 ||
         helicopterState.AgmLaunchZonePitchMin.value > 0.0 || helicopterState.AgmLaunchZonePitchMax.value < 1.0) &&
        !isInsideAgmLaunchAngularRange())
    {
      local left  = max(0.0, helicopterState.AgmLaunchZoneYawMin.value) * 100.0
      local right = min(1.0, helicopterState.AgmLaunchZoneYawMax.value) * 100.0
      local lower = 100.0 - max(0.0, helicopterState.AgmLaunchZonePitchMin.value) * 100.0
      local upper = 100.0 - min(1.0, helicopterState.AgmLaunchZonePitchMax.value) * 100.0
      return [
        [VECTOR_LINE, left,  upper, right, upper],
        [VECTOR_LINE, right, upper, right, lower],
        [VECTOR_LINE, right, lower, left,  lower],
        [VECTOR_LINE, left,  lower, left,  upper]
      ]
    }
    else
      return []
  }

  local getAgmLaunchDistanceRangeCommands = function() {

    if (helicopterState.IsAgmLaunchZoneVisible.value)
    {
      local distanceRangeInv = fullRangeMultInv * 1.0 / (helicopterState.AgmLaunchZoneDistMax.value - 0.0 + 1.0)
      local distanceMinRel = (helicopterState.AgmLaunchZoneDistMin.value - 0.0) * distanceRangeInv
      local commands = [
        [VECTOR_LINE, 120, 0,   120, 100],
        [VECTOR_LINE, 120, 100, 125, 100],
        [VECTOR_LINE, 120, 0,   125, 0],
        [VECTOR_LINE, 120, 100 * (1.0 - fullRangeMultInv),  127, 100 * (1.0 - fullRangeMultInv)],
        [VECTOR_LINE, 120, 100 - (distanceMinRel * 100 - 1), 127, 100 - (distanceMinRel * 100 - 1)]
      ]
      if (helicopterState.IsRangefinderEnabled.value)
      {
        local distanceRel = min((helicopterState.RangefinderDist.value - 0.0) * distanceRangeInv, 1.0)
        commands.append([VECTOR_RECTANGLE, 120, 100 - (distanceRel * 100 - 1),  10, 2])
      }
      return commands
    }
    else
      return []
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
        lineWidth = hdpx(LINE_WIDTH + 1)
        size = [aspect * height, height]
        color = getColor(isBackground)
        watch = [helicopterState.TurretYaw, helicopterState.TurretPitch, helicopterState.FovYaw, helicopterState.FovPitch]
        commands = getTurretCommands()
      }),
      @() line_style.__merge({
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = hdpx(LINE_WIDTH + 0)
        size = [aspect * height, height]
        color = getColor(isBackground)
        watch = [
          helicopterState.LastAgmOutOfAngleLaunchAttemptTimeOut,
          helicopterState.IsAgmLaunchZoneVisible,
          helicopterState.IsInsideLaunchZoneYawPitch,
          helicopterState.TurretYaw, helicopterState.TurretPitch,
          helicopterState.AgmLaunchZoneYawMin, helicopterState.AgmLaunchZoneYawMax,
          helicopterState.AgmLaunchZonePitchMin, helicopterState.AgmLaunchZonePitchMax
        ]
        commands = getAgmLaunchAngularRangeCommands()
        behavior = Behaviors.RtPropUpdate
        update = function() {
          return {
            opacity = math.round(helicopterState.CurrentTime.value * 4) % 2 == 0 ? 100 : 0
          }
        }
      }),
      @() line_style.__merge({
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = hdpx(LINE_WIDTH + 1)
        size = [aspect * height, height]
        color = getColor(isBackground)
        watch = [
          helicopterState.IsAgmLaunchZoneVisible,
          helicopterState.IsRangefinderEnabled, helicopterState.RangefinderDist,
          helicopterState.AgmLaunchZoneDistMin, helicopterState.AgmLaunchZoneDistMax
        ]
        commands = getAgmLaunchDistanceRangeCommands()
        behavior = Behaviors.RtPropUpdate
        update = function() {
          return {
            opacity = !(helicopterState.IsRangefinderEnabled.value && !isInsideAgmLaunchDistanceRange()) ||
                      math.round(helicopterState.CurrentTime.value * 4) % 2 == 0 ? 100 : 0
          }
        }
      })
    ]
  })
}

local turretAnglesComponent = function(elemStyle, height, aspect, isBackground) {
  return {
    pos = [sightSw(50) - aspect * height * 0.5, sightSh(90) - height]
    size = SIZE_TO_CONTENT
    children = turretAngles(elemStyle, height, aspect, isBackground)
  }
}

local function launchDistanceMaxComponent(elemStyle, height, aspect, isBackground) {

  local getAgmLaunchDistanceMax = function() {
    return helicopterState.IsAgmLaunchZoneVisible.value ?
      ::string.format("%.1f", helicopterState.AgmLaunchZoneDistMax.value * 0.001) : ""
  }

  local launchDistanceMax = @() elemStyle.__merge({
    rendObj = ROBJ_DTEXT
    halign = HALIGN_CENTER
    valign = HALIGN_CENTER
    text = getAgmLaunchDistanceMax()
    watch = [
      helicopterState.IsAgmLaunchZoneVisible,
      helicopterState.AgmLaunchZoneDistMax
    ]
    color = getColor(isBackground)
  })

  local resCompoment = @() {
    rendObj = ROBJ_VECTOR_CANVAS
    pos = [sightSw(50) + 1.75 * aspect * height * 0.5, sightSh(90) - height * fullRangeMultInv]
    halign = HALIGN_CENTER
    valign = HALIGN_CENTER
    size = [0, 0]
    children = launchDistanceMax
  }

  return resCompoment
}

local generateBulletsTextFunction = function(countWatched, secondsWatched) {
  return function() {
    local str = ""
    if (secondsWatched.value >= 0)
    {
      str = ::string.format("%d:%02d", ::math.floor(secondsWatched.value / 60), secondsWatched.value % 60)
      if (countWatched.value > 0)
        str += " (" + countWatched.value + ")"
      return str
    }
    else if (countWatched.value >= 0)
      str = countWatched.value
    return str
  }
}

local generateAgmBulletsTextFunction = function(countWatched, secondsWatched, timeToHit, timeToWarning) {
  return function() {
    local str = ""
    if (secondsWatched.value >= 0)
    {
      str = ::string.format("%d:%02d", ::math.floor(secondsWatched.value / 60), secondsWatched.value % 60)
      if (countWatched.value > 0)
        str += " (" + countWatched.value + ")"
      return str
    }
    else if (countWatched.value >= 0)
      str = countWatched.value

    if (timeToHit.value > 0)
      str = str + ::string.format("[%d]", timeToHit.value)
    return str
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

local generateTransmissionStateTextFunction = function(oilWatched) {
  return function() {
    if(oilWatched.value > 0.01)
      return ::loc("HUD_FUEL_LEAK")
    else
    return ::loc("HUD_TANK_IS_EMPTY")

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

local getAGCaption = function() {
  local text = ""
  if (helicopterState.AgmGuidanceLockState.value == GuidanceLockResult.RESULT_INVALID)
    text = ::loc("HUD/AGM_SHORT")
  else if (helicopterState.AgmGuidanceLockState.value == GuidanceLockResult.RESULT_STANDBY)
    text = ::loc("HUD/TXT_LASER_MISSILE_STANDBY")
  else if (helicopterState.AgmGuidanceLockState.value == GuidanceLockResult.RESULT_WARMING_UP)
    text = ::loc("HUD/TXT_LASER_MISSILE_WARM_UP")
  else if (helicopterState.AgmGuidanceLockState.value == GuidanceLockResult.RESULT_LOCKING)
    text = ::loc("HUD/TXT_LASER_MISSILE_LOCK")
  else if (helicopterState.AgmGuidanceLockState.value == GuidanceLockResult.RESULT_TRACKING)
    text = ::loc("HUD/TXT_LASER_MISSILE_TRACK")
  return text
}

local getAACaption = function() {
  local text = ""
  if (aamAimState.GuidanceLockState.value == GuidanceLockResult.RESULT_STANDBY)
    text = ::loc("HUD/IR_MISSILE_STANDBY")
  else if (aamAimState.GuidanceLockState.value == GuidanceLockResult.RESULT_WARMING_UP)
    text = ::loc("HUD/TXT_IR_MISSILE_WARM_UP")
  else if (aamAimState.GuidanceLockState.value == GuidanceLockResult.RESULT_LOCKING)
    text = ::loc("HUD/IR_MISSILE_LOCK")
  else if (aamAimState.GuidanceLockState.value == GuidanceLockResult.RESULT_TRACKING)
    text = ::loc("HUD/IR_MISSILE_TRACK")
  return text
}

local getAGBlink = function()
{
  if (helicopterState.IsSightHudVisible.value && helicopterState.IsAgmLaunchZoneVisible.value &&
       (
         (helicopterState.LastAgmOutOfAngleLaunchAttemptTimeOut.value < outOfZoneLaunchShowTimeOut && !isInsideAgmLaunchAngularRange()) ||
         (helicopterState.IsRangefinderEnabled.value && !isInsideAgmLaunchDistanceRange())
       ) )
    return math.round(helicopterState.CurrentTime.value * 4) % 2 == 0 ? 100 : 0
  else
    return 100
}

local getAGBulletsBlink = function()
{
  if (helicopterState.Agm.timeToHit.value > 0 && helicopterState.Agm.timeToWarning.value <= 0)
    return math.round(helicopterState.CurrentTime.value * 4) % 2 == 0 ? 100 : 0
  else
    return 100
}

local getAGBullets = generateAgmBulletsTextFunction(helicopterState.Agm.count, helicopterState.Agm.seconds, helicopterState.Agm.timeToHit, helicopterState.Agm.timeToWarning)

local getAABullets = generateBulletsTextFunction(helicopterState.Aam.count, helicopterState.Aam.seconds)

local createHelicopterParam = function(param, width, line_style, isBackground, needCaption = true)
{
  local rowHeight = helicopterState.IsMfdEnabled.value ? 30 : hdpx(28)

  local selectColor = function(){
    return param?.alertWatched && param.alertWatched[0].value && !isBackground
      ? helicopterState.AlertColor.value
      : getColor(isBackground)
  }

  local captionComponent = @() line_style.__merge({
    rendObj = ROBJ_DTEXT
    size = [0.4*width, rowHeight]
    text = param.title()
    watch = (param?.alertWatched ? param.alertWatched : []).extend(param?.titleWatched ? param.titleWatched : [])
    color = selectColor()
  })

  return function() {
    return {
      size = SIZE_TO_CONTENT
      flow = FLOW_HORIZONTAL
      behavior = param?.blink ? Behaviors.RtPropUpdate : null
      update = function() {
        return {
          opacity = param.blink() ? 100 : 0
        }
      }
      children = [
        (needCaption ? captionComponent : null)
        @() line_style.__merge({
          color = selectColor()
          rendObj = ROBJ_DTEXT
          size = [0.6*width, rowHeight]
          text = param.value()
          watch = param.valuesWatched
          behavior = param?.valueBlink ? Behaviors.RtPropUpdate : null
          update = function() {
            return {
              opacity = param.valueBlink() ? 100 : 0
            }
          }
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
    alertWatched = [helicopterState.IsRpmCritical]
  },
  [HelicopterParams.THROTTLE] = {
    title = @() getThrottleCaption()
    value = @() getThrottleText()
    titleWatched = [helicopterState.TrtMode]
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
    alertWatched = [helicopterState.IsCanEmpty]
  },
   [HelicopterParams.MACHINE_GUN] = {
    title = @() ::loc("HUD/MACHINE_GUNS_SHORT")
    value = generateBulletsTextFunction(helicopterState.MachineGuns.count, helicopterState.MachineGuns.seconds)
    valuesWatched = [helicopterState.MachineGuns.count, helicopterState.MachineGuns.seconds, helicopterState.IsMachineGunEmpty]
    alertWatched = [helicopterState.IsMachineGunEmpty]
  },
  [HelicopterParams.CANNON_ADDITIONAL] = {
    title = @() ::loc("HUD/ADDITIONAL_GUNS_SHORT")
    value = generateBulletsTextFunction(helicopterState.CannonsAdditional.count, helicopterState.CannonsAdditional.seconds)
    valuesWatched = [
      helicopterState.CannonsAdditional.count,
      helicopterState.CannonsAdditional.seconds,
      helicopterState.IsCanAdditionalEmpty
    ]
    alertWatched = [helicopterState.IsCanAdditionalEmpty]
  },
  [HelicopterParams.ROCKET] = {
    title = @() ::loc("HUD/RKT")
    value = generateBulletsTextFunction(helicopterState.Rockets.count, helicopterState.Rockets.seconds)
    valuesWatched = [helicopterState.Rockets.count, helicopterState.Rockets.seconds, helicopterState.IsRktEmpty]
    alertWatched = [helicopterState.IsRktEmpty]
  },
  [HelicopterParams.AGM] = {
    title = @() getAGCaption()
    value = @() getAGBullets()
    blink = @() getAGBlink()
    titleWatched = [
      helicopterState.AgmGuidanceLockState,
      helicopterState.LastAgmOutOfAngleLaunchAttemptTimeOut,
      helicopterState.IsSightHudVisible, helicopterState.IsAgmLaunchZoneVisible, helicopterState.IsAgmLaunchZoneVisible,
      helicopterState.IsInsideLaunchZoneYawPitch, helicopterState.IsInsideLaunchZoneDist
    ]
    valueBlink = @() getAGBulletsBlink()
    valuesWatched = [
      helicopterState.LastAgmOutOfAngleLaunchAttemptTimeOut,
      helicopterState.IsSightHudVisible, helicopterState.IsAgmLaunchZoneVisible, helicopterState.IsAgmLaunchZoneVisible,
      helicopterState.Agm.count, helicopterState.Agm.seconds, helicopterState.Agm.timeToHit, helicopterState.Agm.timeToWarning,
      helicopterState.IsAgmEmpty, helicopterState.AgmGuidanceLockState
    ]
    alertWatched = [helicopterState.IsAgmEmpty]
  },
  [HelicopterParams.BOMBS] = {
    title = @() ::loc("HUD/BOMBS_SHORT")
    value = generateBulletsTextFunction(helicopterState.Bombs.count, helicopterState.Bombs.seconds)
    valuesWatched = [helicopterState.Bombs.count, helicopterState.Bombs.seconds, helicopterState.IsBmbEmpty]
    alertWatched = [helicopterState.IsBmbEmpty]
  },
  [HelicopterParams.RATE_OF_FIRE] = {
    title = @() ::loc("HUD/RATE_OF_FIRE_SHORT")
    value = @() helicopterState.IsHighRateOfFire.value ? ::loc("HUD/HIGHFREQ_SHORT") : ::loc("HUD/LOWFREQ_SHORT")
    valuesWatched = helicopterState.IsHighRateOfFire
  },
  [HelicopterParams.AAM] = {
    title = @() getAACaption()
    value = @() aamAimState.GuidanceLockState.value != GuidanceLockResult.RESULT_INVALID ? getAABullets() : ""
    titleWatched = [aamAimState.GuidanceLockState]
    valuesWatched = [helicopterState.Aam.count, helicopterState.Aam.seconds, helicopterState.IsAamEmpty,
      aamAimState.GuidanceLockState]
    alertWatched = [helicopterState.IsAamEmpty]
  },
  [HelicopterParams.FLARES] = {
    title = @() ::loc("HUD/FLARES_SHORT")
    value = generateBulletsTextFunction(helicopterState.Flares.count, helicopterState.Flares.seconds)
    valuesWatched = [helicopterState.Flares.count, helicopterState.Flares.seconds, helicopterState.IsFlrEmpty]
    alertWatched = [helicopterState.IsFlrEmpty]
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
    alertWatched = [helicopterState.IsOilAlert[i]]
  }

  textParamsMap[HelicopterParams.WATER_1 + i] <- {
    title = @() ::loc("HUD/WATER_TEMPERATURE_SHORT" + indexStr)
    value = generateTemperatureTextFunction(helicopterState.WaterTemperature[i], helicopterState.WaterState[i])
    valuesWatched = [
      helicopterState.WaterTemperature[i],
      helicopterState.WaterState[i],
      helicopterState.IsWaterAlert[i]
    ]
    alertWatched = [helicopterState.IsWaterAlert[i]]
  }

  textParamsMap[HelicopterParams.ENGINE_1 + i] <- {
    title = @() ::loc("HUD/ENGINE_TEMPERATURE_SHORT" + indexStr)
    value = generateTemperatureTextFunction(helicopterState.EngineTemperature[i], helicopterState.EngineState[i])
    valuesWatched = [
      helicopterState.EngineTemperature[i],
      helicopterState.EngineState[i],
      helicopterState.IsEngineAlert[i]
    ]
    alertWatched = [helicopterState.IsEngineAlert[i]]
  }
}


for (local i = 0; i < NUM_TRANSMISSIONS_MAX; ++i)
{
  local indexStr = (i+1).tostring();

  textParamsMap[HelicopterParams.TRANSMISSION_1 + i] <- {
    title = @() ::loc("HUD/TRANSMISSION_OIL_SHORT" + indexStr)
    value = generateTransmissionStateTextFunction(helicopterState.TransmissionOilState[i])
    valuesWatched = [
      helicopterState.TransmissionOilState[i],
      helicopterState.IsTransmissionOilAlert[i]
    ]
    alertWatched = [helicopterState.IsTransmissionOilAlert[i]]
  }
}

local paramsTableWidth = hdpx(450)
local paramsSightTableWidth = hdpx(220)


local generateParamsTable = function(mask, width, pos, gap, needCaption = true) {
  local getChildren = function(line_style, isBackground)
  {
    local children = []
    foreach(key, param in textParamsMap)
    {
      if ((1 << key) & mask.value)
        children.append(createHelicopterParam(param, width, line_style, isBackground, needCaption))
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

local mfdSightParamsTable = generateParamsTable(helicopterState.SightMask,
  250,
  [30, 175],
  hdpx(3))

local mfdPilotParamsTable = generateParamsTable(helicopterState.IlsMask,
  300,
  [50, 225],
  0,  false)

local sightParamsComponent = function(elemStyle, isBackground) {
  if (helicopterState.IsMfdEnabled.value)
    return mfdSightParamsTable(elemStyle, isBackground)
  else
    return helicopterSightParamsTable(elemStyle, isBackground)
}

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
  local width = sightHdpx(150)
  local height = sightHdpx(100)

  return @() {
    pos = [sightSw(50) - width * 0.5, sightSh(50) - height * 0.5]
    watch = helicopterState.IsSightLocked
    opacity = helicopterState.IsSightLocked.value ? 100 : 0
    size = SIZE_TO_CONTENT
    children = lockSight(elemStyle, width, height, isBackground)
  }
}

local laserDesignator = function(line_style, width, height, isBackground) {
  local hl = 5
  local vl = 7

  return @() line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, height]
    watch = helicopterState.IsAgmEmpty
    color = !isBackground && helicopterState.IsAgmEmpty.value ? helicopterState.AlertColor.value : getColor(isBackground)
    commands = [
      [VECTOR_LINE, 50 - hl, 50 - vl, 50 + hl, 50 - vl],
      [VECTOR_LINE, 50 - hl, 50 + vl, 50 + hl, 50 + vl],
      [VECTOR_LINE, 50 - hl, 50 - vl, 50 - hl, 50 + vl],
      [VECTOR_LINE, 50 + hl, 50 - vl, 50 + hl, 50 + vl],
    ]
  })
}

local laserDesignatorComponent = function(elemStyle, isBackground) {
  local width = sightHdpx(150)
  local height = sightHdpx(100)

  return @() {
    pos = [sightSw(50) - width * 0.5, sightSh(50) - height * 0.5]
    watch = helicopterState.IsLaserDesignatorEnabled
    opacity = helicopterState.IsLaserDesignatorEnabled.value ? 100 : 0
    size = SIZE_TO_CONTENT
    children = laserDesignator(elemStyle, width, height, isBackground)
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
  local height = sightHdpx(500)

  return {
    pos = [sightSw(50) - height * 0.5, sightSh(50) - height * 0.5]
    size = SIZE_TO_CONTENT
    children = sight(elemStyle, height, isBackground)
  }
}

local function rangeFinderComponent(elemStyle, isBackground) {
  local rangefinder = @() elemStyle.__merge({
    rendObj = ROBJ_DTEXT
    halign = HALIGN_CENTER
    text = math.round_by_value(helicopterState.RangefinderDist.value, 1)
    opacity = helicopterState.IsRangefinderEnabled.value ? 100 : 0
    watch = [helicopterState.RangefinderDist, helicopterState.IsRangefinderEnabled]
    color = getColor(isBackground)
  })

  local resCompoment = @() {
    pos = [sightSw(50), sightSh(59)]
    halign = HALIGN_CENTER
    size = [0, 0]
    children = rangefinder
  }

  return resCompoment
}

local function laserDesignatorStatusComponent(elemStyle, isBackground) {

  local function getText() {
    if (helicopterState.IsLaserDesignatorEnabled.value)
      return ::loc("HUD/TXT_LASER_DESIGNATOR")
    else
    {
      if (helicopterState.Agm.timeToHit.value > 0 && helicopterState.Agm.timeToWarning.value <= 0)
        return ::loc("HUD/TXT_ENABLE_LASER_NOW")
      else
        return ""
    }
  }

  local laserDesignatorStatus = @() elemStyle.__merge({
    rendObj = ROBJ_DTEXT
    halign = HALIGN_CENTER
    text = getText()
    watch = [ helicopterState.IsLaserDesignatorEnabled, helicopterState.Agm.timeToHit, helicopterState.Agm.timeToWarning ]
    color = getColor(isBackground)
    behavior = Behaviors.RtPropUpdate
    update = function() {
      return {
        opacity = !helicopterState.IsLaserDesignatorEnabled.value &&
                  helicopterState.Agm.timeToHit.value > 0 &&
                  helicopterState.Agm.timeToWarning.value <= 0 ?
                    ((math.round(helicopterState.CurrentTime.value * 4) % 2 == 0) ? 100 : 0) :
                  100
      }
    }
  })

  local resCompoment = @() {
    pos = [sightSw(50), sightSh(38)]
    halign = HALIGN_CENTER
    size = [0, 0]
    children = laserDesignatorStatus
  }

  return resCompoment
}

local function atgmTrackerStatusComponent(elemStyle, isBackground) {

  local atgmTrackerStatus = @() elemStyle.__merge({
    rendObj = ROBJ_DTEXT
    halign = HALIGN_CENTER
    text = ::loc("HUD/TXT_ATGM_OUT_OF_TRACKER_SECTOR")
    color = getColor(isBackground)
    behavior = Behaviors.RtPropUpdate
    update = function() {
      return {
        opacity = helicopterState.IsATGMOutOfTrackerSector.value &&
                  (math.round(helicopterState.CurrentTime.value * 4) % 2 == 0) ? 100 : 0
      }
    }
  })

  local resCompoment = @() {
    pos = [sightSw(50), sightSh(41)]
    halign = HALIGN_CENTER
    size = [0, 0]
    children = atgmTrackerStatus
  }

  return resCompoment
}

local function compassComponent(elemStyle, isBackground, w = compassWidth, h = compassHeight, x = sw(50) - 0.5 * compassWidth, y = sh(15)) {
  local color = getColor(isBackground)
  local getChildren = @() helicopterState.IsCompassVisible.value ? compass(elemStyle, w, h, color) : null
  return @()
  {
    size = SIZE_TO_CONTENT
    pos = [x, y]
    watch = helicopterState.IsCompassVisible
    children = getChildren()
  }
}


local function helicopterMainHud(elemStyle, isBackground) {
  return @(){
    watch = helicopterState.IsMainHudVisible
    children = helicopterState.IsMainHudVisible.value
    ? [
      HelicopterRocketAim(elemStyle, isBackground)
      aamAim(elemStyle, @() getColor(isBackground))
      HelicopterGunDirection(elemStyle, isBackground)
      HelicopterFixedGunsDirection(elemStyle, isBackground)
      HelicopterVertSpeed(elemStyle, sh(1.9), sh(15), sw(50) + hdpx(384), sh(42.5), isBackground)
      HelicopterHorizontalSpeedComponent(elemStyle, isBackground)
      helicopterParamsTable(elemStyle, isBackground)
      compassComponent(elemStyle, isBackground)
    ]
    : null
  }
}


local turretAnglesAspect = 2.0

local function helicopterSightHud(elemStyle, isBackground) {
  local mfdStyle = elemStyle.__merge({
    fontScale = getMfdFontScale()
  })
  local sightStyle = helicopterState.IsMfdEnabled.value ? mfdStyle : elemStyle
  local compassW = helicopterState.IsMfdEnabled.value ? sightSw(75) : compassWidth
  local compassH = helicopterState.IsMfdEnabled.value ? sightSh(10) : compassHeight
  return @(){
    watch = helicopterState.IsSightHudVisible
    pos = helicopterState.IsMfdEnabled ?
    [helicopterState.SightHudPosSize[0], helicopterState.SightHudPosSize[1]] :
    [0, 0]
    children = helicopterState.IsSightHudVisible.value
    ? (helicopterState.IsMfdEnabled.value ?
    [
      turretAnglesComponent(sightStyle, sightHdpx(150), turretAnglesAspect, isBackground)
      launchDistanceMaxComponent(sightStyle, sightHdpx(150), turretAnglesAspect, isBackground)
      sightComponent(sightStyle, isBackground)
      rangeFinderComponent(sightStyle, isBackground)
      lockSightComponent(sightStyle, isBackground)
    ] :
    [
      HelicopterVertSpeed(sightStyle, sightSh(3.6), sightSh(30), sightSw(50) + sightHdpx(384), sightSh(35), isBackground)
      turretAnglesComponent(sightStyle, sightHdpx(150), turretAnglesAspect, isBackground)
      launchDistanceMaxComponent(sightStyle, sightHdpx(150), turretAnglesAspect, isBackground)
      sightParamsComponent(sightStyle, isBackground)
      lockSightComponent(sightStyle, isBackground)
      laserDesignatorComponent(sightStyle, isBackground)
      sightComponent(sightStyle, isBackground)
      rangeFinderComponent(sightStyle, isBackground)
      laserDesignatorStatusComponent(sightStyle, isBackground)
      atgmTrackerStatusComponent(sightStyle, isBackground)
      compassComponent(sightStyle, isBackground, compassW, compassH, sightSw(50) - 0.5*compassW, sightSh(15))
    ])
    : null
  }
}


local function gunnerHud(elemStyle, isBackground) {
  return @(){
    watch = helicopterState.IsGunnerHudVisible
    children = helicopterState.IsGunnerHudVisible.value
    ? [
      HelicopterRocketAim(elemStyle, isBackground)
      aamAim(elemStyle, @() getColor(isBackground))
      HelicopterGunDirection(elemStyle, isBackground)
      HelicopterFixedGunsDirection(elemStyle, isBackground)
      HelicopterVertSpeed(elemStyle, sh(1.9), sh(15), sw(50) + hdpx(384), sh(42.5), isBackground)
      helicopterParamsTable(elemStyle, isBackground)
    ]
    : null
  }
}


local function pilotHud(elemStyle, isBackground) {
  local ilsStyle = elemStyle.__merge({
    fontScale = getIlsFontScale()
    lineWidth = LINE_WIDTH * 3
  })
  local compassW = helicopterState.IsMfdEnabled.value ? pilotSw(75) : compassWidth
  local compassH = helicopterState.IsMfdEnabled.value ? pilotSh(13) : compassHeight
  return @(){
    watch = helicopterState.IsPilotHudVisible
    pos = helicopterState.IsMfdEnabled ?
    [helicopterState.PilotHudPosSize[0], helicopterState.PilotHudPosSize[1]] :
    [0, 0]
    children = helicopterState.IsPilotHudVisible.value
    ? (helicopterState.IsMfdEnabled.value ?
      [
       HelicopterVertSpeed(ilsStyle, pilotSh(5), pilotSh(40), pilotSw(50) + pilotHdpx(384), pilotSh(35), isBackground)
       mfdPilotParamsTable(ilsStyle, isBackground)
       HelicopterHorizontalSpeedComponent(ilsStyle, isBackground, pilotSw(50), pilotSh(60))
       compassComponent(ilsStyle, isBackground, compassW, compassH, pilotSw(50) - 0.5 * compassW, pilotSh(5))
      ] :
      [
        HelicopterVertSpeed(elemStyle, pilotSh(1.9), pilotSh(15), pilotSw(50) + pilotHdpx(384), pilotSh(42.5), isBackground)
        helicopterParamsTable(elemStyle, isBackground)
      ]
      )
    : null
  }
}

local getRwr = function(colorStyle) {
  local getChildren = function() {
    return helicopterState.RwrForMfd.value ?
      rwr(colorStyle,
       helicopterState.RwrPosSize[0] + helicopterState.RwrPosSize[2] * 0.2,
       helicopterState.RwrPosSize[1] + helicopterState.RwrPosSize[2] * 0.05,
       helicopterState.RwrPosSize[2] * 0.9, true) : rwr(colorStyle)
  }
  return @(){
    watch = helicopterState.RwrForMfd
    children = getChildren()
  }
}

local function helicopterHUDs(colorStyle, isBackground) {
  local rwrStyle = colorStyle.__merge({
    color = getColor(isBackground)
  })

  return [
    helicopterMainHud(colorStyle, isBackground)
    helicopterSightHud(colorStyle, isBackground)
    gunnerHud(colorStyle, isBackground)
    pilotHud(colorStyle, isBackground)
    getRwr(rwrStyle)
  ]
}


local Root = function() {
  local children = helicopterHUDs(style.lineBackground, true)
  children.extend(helicopterHUDs(style.lineForeground, false))

  return {
    watch = [
      helicopterState.IndicatorsVisible
      helicopterState.HudColor
      helicopterState.IsMfdEnabled
    ]
    halign = HALIGN_LEFT
    valign = VALIGN_TOP
    size = [sw(100), sh(100)]
    children = (helicopterState.IndicatorsVisible.value ||
    helicopterState.IsMfdEnabled) ? children : null
  }
}


return Root
