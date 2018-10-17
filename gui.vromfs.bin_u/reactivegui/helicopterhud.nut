local math = require("std/math.nut")
local interopGet = require("daRg/helpers/interopGen.nut")

local style = {}

local greenColor = Color(71, 232, 39, 200)
local backgroundColor = Color(0, 0, 0, 90)

const LINE_WIDTH = 1.6
const NUM_ENGINES_MAX = 7


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
  horAngle = 0
  horizontalSpeedX = 0
  horizontalSpeedZ = 0

  turretYaw = 0.5
  turretPitch = 0.5

  isSightLocked = false
}


local helicopterState = {
  MainList = Watched([])
  SightList = Watched([])
  HudColor = Watched(Color(71, 232, 39, 240))
  AlertColor = Watched(Color(255, 0, 0, 240))

  TrtCaption = Watched("")

  Rpm = Watched("0")
  Trt = Watched("0")
  Spd = Watched("0")

  Can = Watched("--")
  CanAdditional = Watched("--")
  Rkt = Watched("--")
  Msl = Watched("--")
  Bmb = Watched("--")

  RateOfFire = Watched("LOW")

  IsRpmCritical = Watched(false)

  FixedGunDirectionX = Watched(-100)
  FixedGunDirectionY = Watched(-100)
  FixedGunDirectionVisible = Watched(false)

  IsRangefinderEnabled = Watched(false)
  RangefinderDist = Watched(0)

  OilTemperature = []
  WaterTemperature = []
  EngineTemperature = []

  IsOilAlert = []
  IsWaterAlert = []
  IsEngineAlert = []

  IsMainHudVisible = Watched(false)
  IsSightHudVisible = Watched(false)
  IsPilotHudVisible = Watched(false)
  IsGunnerHudVisible = Watched(false)

  FlyByWireMode = Watched("0")
}

for (local i = 0; i < NUM_ENGINES_MAX; ++i)
{
  helicopterState.OilTemperature.append(Watched(""))
  helicopterState.WaterTemperature.append(Watched(""))
  helicopterState.EngineTemperature.append(Watched(""))

  helicopterState.IsOilAlert.append(Watched(false))
  helicopterState.IsWaterAlert.append(Watched(false))
  helicopterState.IsEngineAlert.append(Watched(false))
}

interopGet({
  stateTable = helicopterState
  prefix = "helicopter"
  postfix = "Update"
})

::interop.updateOilTemperature <- function (value, index) {
  helicopterState.OilTemperature[index].update(value)
}

::interop.updateWaterTemperature <- function (value, index) {
  helicopterState.WaterTemperature[index].update(value)
}

::interop.updateEngineTemperature <- function (value, index) {
  helicopterState.EngineTemperature[index].update(value)
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


style.lineBackground <- class {
  fillColor = Color(0, 0, 0, 0)
  lineWidth = hdpx(LINE_WIDTH + 2.0)
  font = Fonts.small_text_hud
  fontFxColor = backgroundColor
  fontFxFactor = 16
  fontFx = FFT_GLOW
}


style.lineForeground <- class {
  watch = [helicopterState.HudColor]
  fillColor = Color(0, 0, 0, 0)
  lineWidth = hdpx(LINE_WIDTH)
  font = Fonts.small_text_hud
  fontFxColor = backgroundColor
  fontFxFactor = 16
  fontFx = FFT_GLOW
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

  return {
    halign = HALIGN_CENTER
    valign = VALIGN_MIDDLE
    size = SIZE_TO_CONTENT
    behavior = Behaviors.RtPropUpdate
    update = @() {
      opacity = ::interop.state.rocketAimVisible ? 100 : 0
      transform = {
        translate = [::interop.state.rocketAimX, ::interop.state.rocketAimY]
      }
    }
    children = [lines]
  }
}


local HelicopterFlightDirection = function(line_style, isBackground) {
  local lines = @() line_style.__merge({
      rendObj = ROBJ_VECTOR_CANVAS
      size = [sh(0.75), sh(0.75)]
      color = getColor(isBackground)
      commands = [
        [VECTOR_LINE, -100, 0, -200, 0],
        [VECTOR_LINE, 100, 0, 200, 0],
        [VECTOR_LINE, 0, -100, 0, -200],
        [VECTOR_ELLIPSE, 0, 0, 100, 100],
      ]
    })

  return @(){
    size = SIZE_TO_CONTENT
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


local HelicopterGunDirection = function(line_style, isBackground) {
  local sqL = 80
  local l = 20
  local offset = (100 - sqL) * 0.5

  local lines = @() line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [sh(2), sh(2)]
    color = getColor(isBackground)
    commands = [
      [VECTOR_LINE, -50 + offset, -50 + offset,
        -50 + offset,  50 - offset,
         50 - offset,  50 - offset,
         50 - offset, -50 + offset,
        -50 + offset, -50 + offset],
      [VECTOR_LINE, -50, 0, -50 + l, 0],
      [VECTOR_LINE, 50 - l, 0, 50, 00],
      [VECTOR_LINE, 0, -50, 0, -50 + l],
      [VECTOR_LINE, 0, 50 - l, 0, 50]
    ]
  })

  return @() {
    size = SIZE_TO_CONTENT
    halign = HALIGN_CENTER
    valign = VALIGN_MIDDLE
    behavior = Behaviors.RtPropUpdate
    update = @() {
      opacity = ::interop.state.gunDirectionVisible ? 100 : 0
      transform = {
        translate = [::interop.state.gunDirectionX, ::interop.state.gunDirectionY]
      }
    }
    children = [lines]
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
  return @() {
    pos = [posX, sh(50) - height*0.5]
    children = [
      @() {
        children = verticalSpeedScale(elemStyle, scaleWidth, height, isBackground)
      }
      @(){
        valign = VALIGN_BOTTOM
        halign = HALIGN_RIGHT
        size = [scaleWidth, height]
        children = @() elemStyle.__merge({
          rendObj = ROBJ_VECTOR_CANVAS
          behavior = Behaviors.RtPropUpdate
          pos = [LINE_WIDTH, 0]
          size = [LINE_WIDTH, height]
          tmpHeight = 0
          fillColor = Color(255, 255, 255, 255)
          color = getColor(isBackground)
          commands = [[VECTOR_RECTANGLE, 0, 0, 100, 100]]
          update = @() {
            opacity = ::interop.state.distanceToGround > 50.0 ? 0 : 100
            tmpHeight = ::clamp(::interop.state.distanceToGround * 2.0, 0, 100)
            commands = [[VECTOR_RECTANGLE, 0, 100 - tmpHeight, 100, tmpHeight]]
          }
        })
      }
      {
        halign = HALIGN_RIGHT
        valign = VALIGN_MIDDLE
        size = [-0.5*scaleWidth, height]
        children = @() elemStyle.__merge({
          rendObj = ROBJ_DTEXT
          halign = HALIGN_RIGHT
          behavior = Behaviors.RtPropUpdate
          size = [scaleWidth*4,SIZE_TO_CONTENT]
          color = getColor(isBackground)
          update = @() {
            text = ::math.floor(::interop.state.distanceToGround).tostring()
          }
        })
      }
      {
        behavior = Behaviors.RtPropUpdate
        pos = [scaleWidth + sh(0.5), 0]
        update = @() {
          transform = {
            translate = [0, height * 0.01 * clamp(50 - ::interop.state.verticalSpeed * 5.0, 0, 100)]
          }
        }
        children = [
          verticalSpeedInd(elemStyle, hdpx(25), isBackground),
          {
            pos = [scaleWidth + hdpx(10), hdpx(-13)]
            children = @() elemStyle.__merge({
              rendObj = ROBJ_DTEXT
              size = [scaleWidth*4,SIZE_TO_CONTENT]
              color = getColor(isBackground)
              behavior = Behaviors.RtPropUpdate
              update = @(){
                text = math.round_by_value(::interop.state.verticalSpeed, 1).tostring()
              }
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
    behavior = Behaviors.RtPropUpdate
    update = @()
    {
      transform = {
        pivot = [0.5, 0.5]
        rotate = ::interop.state.horAngle
      }
    }
  })
}


local horizontalSpeedVector = function(line_style, height, isBackground) {
  return @() line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [height, height]
    behavior = Behaviors.RtPropUpdate
    color = getColor(isBackground)
    update = function()
    {
      local factor = 5.0
      local limit = 100.0
      local pointX = ::interop.state.horizontalSpeedZ * factor
      local pointY = ::interop.state.horizontalSpeedX * factor
      if (pointX > limit)
        pointX = limit
      else if (pointX < -limit)
        pointX = -limit
      if (pointY > limit)
        pointY = limit
      else if (pointY < -limit)
        pointY = -limit

      local pointXrel = 50.0 + pointX
      local pointYrel = 50.0 - pointY

      local vecLength = math.sqrt(pointX*pointX + pointY*pointY)

      local pointArrowA = {
        x = pointXrel
        y = pointYrel
      }

      local pointArrowB = {
        x = pointXrel
        y = pointYrel
      }

      if (vecLength > 0)
      {
        local minusVecNorm = {
          x = -pointX / vecLength
          y = pointY / vecLength
        }

        local perpendicularVecNorm = {
          x = 0
          y = 0
        }

        if (pointX != 0)
        {
          perpendicularVecNorm.y = 1.0 / math.sqrt(1 + (pointY * pointY / (pointX * pointX)))
          perpendicularVecNorm.x = pointY * perpendicularVecNorm.y / pointX
        }
        else
        {
          perpendicularVecNorm.x = 1.0
          perpendicularVecNorm.y = 0.0
        }

        local arrowWidth = 5.0
        local arrowLength = 10.0

        pointArrowA = 
        {
          x = pointXrel + perpendicularVecNorm.x * arrowWidth + minusVecNorm.x * arrowLength
          y = pointYrel + perpendicularVecNorm.y * arrowWidth + minusVecNorm.y * arrowLength
        }

        pointArrowB = 
        {
          x = pointXrel - perpendicularVecNorm.x * arrowWidth + minusVecNorm.x * arrowLength
          y = pointYrel - perpendicularVecNorm.y * arrowWidth + minusVecNorm.y * arrowLength
        }
      }

      local commands = [
        [VECTOR_LINE, 50.0, 50.0, pointXrel, pointYrel]
      ]

      local minLengthArrowVisibleSq = 30.0
      if (pointX * pointX + pointY * pointY > minLengthArrowVisibleSq)
      {
        commands.extend([
          [VECTOR_LINE, pointXrel, pointYrel, pointArrowA.x, pointArrowA.y],
          [VECTOR_LINE, pointXrel, pointYrel, pointArrowB.x, pointArrowB.y]
        ])
      }

      return {
        commands = commands
      }
    }
  })
}


local HelicopterHorizontalSpeedComponent = function(elemStyle, isBackground) {
  local height = hdpx(40)

  return function() {
    return {
      pos = [sw(50) - 2* height, sh(50) - height*0.5]
      behavior = Behaviors.RtPropUpdate
      size = [4*height, height]
      children = [
        airHorizonZeroLevel(elemStyle, height, isBackground)
        airHorizon(elemStyle, height, isBackground)
        @(){
          pos = [height, -0.5*height]
          children = horizontalSpeedVector(elemStyle, 2 * height, isBackground)
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
        behavior = Behaviors.RtPropUpdate
        update = function()
        {
          local px = ::interop.state.turretYaw * 100.0
          local py = 100 - ::interop.state.turretPitch * 100.0
          return {
            commands = [
              [VECTOR_LINE, px - crossL - offset, py, px - offset, py],
              [VECTOR_LINE, px + offset, py, px + crossL + offset, py],
              [VECTOR_LINE, px, py - crossL * aspect - offset * aspect, px, py - offset * aspect],
              [VECTOR_LINE, px, py + crossL * aspect + offset * aspect, px, py + offset * aspect]
            ]
          }
        }
      })
    ]
  })
}

local turretAnglesComponent = function(elemStyle, isBackground) {
  local height = hdpx(150)
  local aspect = 2.0

  return function() {
    return {
      pos = [sw(50) - aspect * height * 0.5, sh(90) - height]
      size = SIZE_TO_CONTENT
      children = turretAngles(elemStyle, height, aspect, isBackground)
    }
  }
}

local createHelicopterParam = function(param, width, line_style, isBackground)
{
  local captionComponent = (param.title instanceof Watched) ?
    @() line_style.__merge({
      rendObj = ROBJ_DTEXT
      size = [0.4*width, 0.12 * width]
      text = param.title.value
      watch = param.title
      color = getColor(isBackground)
    })
  :
    @() line_style.__merge({
      rendObj = ROBJ_STEXT
      size = [0.4*width, 0.12 * width]
      text = param.title()
      color = getColor(isBackground)
    })

  return function() {
    return {
      size = SIZE_TO_CONTENT
      flow = FLOW_HORIZONTAL
      children = [
        captionComponent
        @() line_style.__merge({
          color = param?.alertWatched && param.alertWatched.value && !isBackground
            ? helicopterState.AlertColor.value
            : getColor(isBackground)
          rendObj = ROBJ_DTEXT
          size = [0.6*width, 0.12 * width]
          text = param.valueWatched.value
          watch = [param.valueWatched, param?.alertWatched]
        })
      ]
    }
  }
}

local textParamsMap = {
  rpm  = {
    title = @() ::loc("HUD/PROP_RPM_SHORT")
    valueWatched = helicopterState.Rpm
    alertWatched = helicopterState.IsRpmCritical
  }
  trt  = {
    title = helicopterState.TrtCaption
    valueWatched = helicopterState.Trt
  }
  spd  = {
    title = @() ::loc("HUD/REAL_SPEED_SHORT")
    valueWatched = helicopterState.Spd
  }
  can  = {
    title = @() ::loc("HUD/CANNONS_SHORT")
    valueWatched = helicopterState.Can
  }
  can1  = {
    title = @() ::loc("HUD/ADDITIONAL_GUNS_SHORT")
    valueWatched = helicopterState.CanAdditional
  }
  rkt  = {
    title = @() ::loc("HUD/RKT")
    valueWatched = helicopterState.Rkt
  }
  msl  = {
    title = @() ::loc("HUD/MISSILES_SHORT")
    valueWatched = helicopterState.Msl
  }
  bmb = {
    title = @() ::loc("HUD/BOMBS_SHORT")
    valueWatched = helicopterState.Bmb
  }
  rof  = {
    title = @() ::loc("HUD/RATE_OF_FIRE_SHORT")
    valueWatched = helicopterState.RateOfFire
  }
  fbw = {
    title = @() ::loc("HUD/FLIGHT_BY_WIRE_MODE")
    valueWatched = helicopterState.FlyByWireMode
  }
}

for (local i = 0; i < NUM_ENGINES_MAX; ++i)
{
  local indexStr = (i+1).tostring()

  textParamsMap["oil" + i] <- {
    title = @() ::loc("HUD/OIL_TEMPERATURE_SHORT" + indexStr)
    valueWatched = helicopterState.OilTemperature[i]
    alertWatched = helicopterState.IsOilAlert[i]
  }

  textParamsMap["water" + i] <- {
    title = @() ::loc("HUD/WATER_TEMPERATURE_SHORT" + indexStr)
    valueWatched = helicopterState.WaterTemperature[i]
    alertWatched = helicopterState.IsWaterAlert[i]
  }

  textParamsMap["engine" + i] <- {
    title = @() ::loc("HUD/ENGINE_TEMPERATURE_SHORT" + indexStr)
    valueWatched = helicopterState.EngineTemperature[i]
    alertWatched = helicopterState.IsWaterAlert[i]
  }
}


local paramsTableWidth = hdpx(220)
local paramsSightTableWidth = hdpx(220)


local generateParamsTable = function(list, width, pos, gap) {
  local getChildren = function(line_style, isBackground)
  {
    local children =  []
    foreach(key in list.value)
    {
      local param = textParamsMap?[key]
      if (!param)
        continue
      children.append(createHelicopterParam(param, width, line_style, isBackground))
    }
    return children
  }

  return function(line_style, isBackground){
    return @() {
      watch = list
      children = @() line_style.__merge({
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


local helicopterParamsTable = generateParamsTable(helicopterState.MainList,
  paramsTableWidth,
  [hdpx(300), sh(50) - hdpx(100)],
  hdpx(5))

local helicopterSightParamsTable = generateParamsTable(helicopterState.SightList,
  paramsSightTableWidth,
  [sw(50) - hdpx(250) - hdpx(180), hdpx(480)],
  hdpx(3))


local lockSight = function(line_style, width, height, isBackground) {
  local hl = 20
  local vl = 20

  return @() line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, height]
    color = getColor(isBackground)
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

  return function() {
    return {
      pos = [sw(50) - width * 0.5, sh(50) - height * 0.5]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        opacity = ::interop.state.isSightLocked ? 100 : 0
      }
      size = SIZE_TO_CONTENT
      children = lockSight(elemStyle, width, height, isBackground)
    }
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

  return @() {
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
    opacity = helicopterState.IsMainHudVisible.value ? 100 : 0
    watch = [helicopterState.IsMainHudVisible, helicopterState.HudColor]
    children = [
      HelicopterRocketAim(style, isBackground)
      HelicopterGunDirection(style, isBackground)
      HelicopterFixedGunsDirection(style, isBackground)
      HelicopterVertSpeed(style, sh(1.9), sh(15), sw(70), isBackground)
      HelicopterHorizontalSpeedComponent(style, isBackground)
      helicopterParamsTable(style, isBackground)
    ]
  }
}


local helicopterSightHud = function (style, isBackground) {
  return @(){
    opacity = helicopterState.IsSightHudVisible.value ? 100 : 0
    watch = [helicopterState.IsSightHudVisible, helicopterState.HudColor]
    children = [
      HelicopterVertSpeed(style, sh(3.6), sh(30), sw(50) + hdpx(370), isBackground)
      turretAnglesComponent(style, isBackground)
      helicopterSightParamsTable(style, isBackground)
      lockSightComponent(style, isBackground)
      sightComponent(style, isBackground)
      rangeFinderComponent(style, isBackground)
    ]
  }
}


local gunnerHud = function (style, isBackground) {
  return @(){
    opacity = helicopterState.IsGunnerHudVisible.value ? 100 : 0
    watch = [helicopterState.IsGunnerHudVisible, helicopterState.HudColor]
    children = [
      HelicopterRocketAim(style, isBackground)
      HelicopterGunDirection(style, isBackground)
      HelicopterFixedGunsDirection(style, isBackground)
      HelicopterVertSpeed(style, sh(1.9), sh(15), sw(70), isBackground)
      helicopterParamsTable(style, isBackground)
    ]
  }
}


local pilotHud = function (style, isBackground) {
  return @(){
    opacity = helicopterState.IsPilotHudVisible.value ? 100 : 0
    watch = [helicopterState.IsPilotHudVisible, helicopterState.HudColor]
    children = [
      HelicopterVertSpeed(style, sh(1.9), sh(15), sw(70), isBackground)
      helicopterParamsTable(style, isBackground)
    ]
  }
}


local helicopterHUDs = function (color, isBackground) {
  return [
    helicopterMainHud(color, isBackground)
    helicopterSightHud(color, isBackground)
    gunnerHud(color, isBackground)
    pilotHud(color, isBackground)
  ]
}


local Root = function() {
  local children = helicopterHUDs(style.lineBackground, true)
  children.extend(helicopterHUDs(style.lineForeground, false))

  return {
    halign = HALIGN_LEFT
    valign = VALIGN_TOP
    size = [sw(100) , sh(100)]
    children = children
  }
}


return Root
