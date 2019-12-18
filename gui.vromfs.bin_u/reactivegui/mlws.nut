local screenState = require("style/screenState.nut")
local interopGen = require("daRg/helpers/interopGen.nut")
local helicopterState = require("helicopterState.nut");

local backgroundColor = Color(0, 0, 0, 50)

local aircraftWidthFactor = 0.20
local aircraftHeightFactor = 0.25
local aircraftRadiusFactor = 0.3

local function getFontScale()
{
  return sh(100) / 1080
}

local mlwsState = {
  IsMlwsHudVisible = Watched(false),
  CurrentTime = Watched(0.0),
  targets = [],
  TargetsTrigger = Watched(0),
  SignalHoldTimeInv = Watched(0.0)
}

::interop.clearMlwsTargets <- function() {
  local needUpdateTargets = false
  for(local i = 0; i < mlwsState.targets.len(); ++i)
  {
    if (mlwsState.targets[i] != null)
    {
      mlwsState.targets[i] = null
      needUpdateTargets = true
    }
  }
  if (needUpdateTargets)
  {
    mlwsState.TargetsTrigger.trigger()
  }
}

::interop.updateMlwsTarget <- function(index, x, y, age, enemy) {
  if (index >= mlwsState.targets.len())
    mlwsState.targets.resize(index + 1)
  mlwsState.targets[index] = {
    x = x,
    y = y,
    age = age,
    enemy = enemy
  }
  mlwsState.TargetsTrigger.trigger()
}

interopGen({
  stateTable = mlwsState
  prefix = "mlws"
  postfix = "Update"
})

local indicatorRadius = 70.0
local trackRadarsRadius = 0.04
local azimuthMarkLength = 50 * 3 * trackRadarsRadius  

local background = function(colorStyle, width, height) {

  local circle = colorStyle.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, height]
    fillColor = backgroundColor
    lineWidth = hdpx(1) * LINE_WIDTH
    commands = [
      [VECTOR_ELLIPSE, 50, 50, indicatorRadius, indicatorRadius]
    ]
  })

  local aircraftW = width * aircraftRadiusFactor
  local aircraftH = height * aircraftRadiusFactor

  local aircraftCircle = @() colorStyle.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(1) * 2.0
    fillColor = Color(0, 0, 0, 0)
    size = [aircraftW, aircraftH]
    pos = [0.5 * width - 0.5 * aircraftW,  0.5 * height - 0.5 * aircraftH]
    commands = [
      [VECTOR_ELLIPSE, 50, 50, 50, 50]
    ]
    behavior = Behaviors.RtPropUpdate
    update = function() {
      return {
        opacity = 0.42
      }
    }
  })

  local aircraftWidth = width * aircraftWidthFactor
  local aircraftHeight = height * aircraftHeightFactor

  local tailW = 25
  local tailH = 10
  local tailOffset1 = 10
  local tailOffset2 = 5
  local tailOffset3 = 25
  local fuselageWHalf = 10
  local wingOffset1 = 45
  local wingOffset2 = 30
  local wingW = 32
  local wingH = 18
  local wingOffset3 = 30
  local noseOffset = 5

  local aircraftIcon = colorStyle.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(1) * 2.0
    fillColor = Color(0, 0, 0, 0)
    size = [aircraftWidth, aircraftHeight]
    pos = [0.5 * width - 0.5 * aircraftWidth,  0.5 * height - 0.5 * aircraftHeight]
    opacity = 0.42
    commands = [
      [VECTOR_POLY,
        // tail left
        50, 100 - tailOffset1,
        50 - tailW, 100 - tailOffset2,
        50 - tailW, 100 - tailOffset2 - tailH,
        50 - fuselageWHalf, 100 - tailOffset3,
        // wing left
        50 - fuselageWHalf, 100 - wingOffset1,
        50 - fuselageWHalf - wingW, 100 - wingOffset2,
        50 - fuselageWHalf - wingW, 100 - wingOffset2 - wingH,
        50 - fuselageWHalf, wingOffset3,
        // nose
        50, noseOffset,
        // wing rigth
        50 + fuselageWHalf, wingOffset3,
        50 + fuselageWHalf + wingW, 100 - wingOffset2 - wingH,
        50 + fuselageWHalf + wingW, 100 - wingOffset2,
        50 + fuselageWHalf, 100 - wingOffset1,
        // tail right
        50 + fuselageWHalf, 100 - tailOffset3,
        50 + tailW, 100 - tailOffset2 - tailH,
        50 + tailW, 100 - tailOffset2
      ]
    ]
  })

  local azimuthMarksCommands = []
  const angleGrad = 30.0
  local angle = math.PI * angleGrad / 180.0
  local dashCount = 360.0 / angleGrad
  local innerMarkRadius = indicatorRadius - azimuthMarkLength  
  for(local i = 0; i < dashCount; ++i)
  {
    azimuthMarksCommands.append([
      VECTOR_LINE,
      50 + math.cos(i * angle) * innerMarkRadius,
      50 + math.sin(i * angle) * innerMarkRadius,
      50 + math.cos(i * angle) * indicatorRadius,
      50 + math.sin(i * angle) * indicatorRadius
    ])
  }

  local azimuthMarks = colorStyle.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(1)
    fillColor = Color(0, 0, 0, 0)
    size = [width, height]
    opacity = 0.42
    commands = azimuthMarksCommands
  })

  return {
    children = [
      circle
      aircraftCircle
      aircraftIcon
      azimuthMarks
    ]
  }
}

local function createTarget(index, colorStyle, width, height)
{
  local target = mlwsState.targets[index]
  local radiusRel =  0.06
  local distMargin = 2.5 * radiusRel
  local radius = radiusRel * width
  local distance = 1.0 - distMargin

  local targetOffsetX = 0.5 + indicatorRadius * 0.01 * target.x * distance
  local targetOffsetY = 0.5 + indicatorRadius * 0.01 * target.y * distance
  local targetOpacity = max(0.0, 1.0 - min(target.age * mlwsState.SignalHoldTimeInv.value, 1.0))

  local targetComponent = colorStyle.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [2 * radius, 2 * radius]
    lineWidth = hdpx(1)
    fillColor = Color(0, 0, 0, 0)
    opacity = targetOpacity
    commands = target.enemy ?
      [
        [ VECTOR_ELLIPSE, 50, 50, 50, 50 ]
      ]
      :
      [
        [ VECTOR_ELLIPSE, 50, 50, 50, 50 ],
        [ VECTOR_ELLIPSE, 50, 50, 60, 60 ]
      ]
    transform = {
      pivot = [0.5, 0.5]
      translate = [
        targetOffsetX * width - radius,
        targetOffsetY * width - radius
      ]
    }
    halign = HALIGN_CENTER
    valign = VALIGN_MIDDLE
    children = [
      colorStyle.__merge({
        rendObj = ROBJ_STEXT
        size = [0.8 * radius, 0.9 * radius]
        opacity = 0.42
        text = "x"
        font = Fonts.hud
        fontScale = helicopterState.MlwsForMfd.value ? 1.5 : getFontScale() * 0.8
      })
    ]
  })

  return {
    size = [width, height]
    children = [
      targetComponent
    ]
  }
}

local targetsComponent = function(colorStyle, width, height)
{
  local getTargets = function() {
    local targets = []
    for (local i = 0; i < mlwsState.targets.len(); ++i)
    {
      if (!mlwsState.targets[i])
        continue
      targets.append(createTarget(i, colorStyle, width, height))
    }
    return targets
  }

  return @()
  {
    size = [width, height]
    children = getTargets()
    watch = mlwsState.TargetsTrigger
  }
}

local scope = function(colorStyle, width, height)
{
  return {
    children = [
      {
        size = SIZE_TO_CONTENT
        children = [
          background(colorStyle, width, height)
          targetsComponent(colorStyle, width, height)
        ]
      }
    ]
  }
}

local mlws = function(colorStyle, posX = sw(75), posY = sh(70), w = sh(20), h = sh(20), for_mfd = false)
{
  local getChildren = function() {
    return mlwsState.IsMlwsHudVisible.value ? [
      scope(colorStyle, w, h)
    ] : null
  }
  return @(){
    pos = [(for_mfd ? 0 : screenState.safeAreaSizeHud.value.borders[1]) + posX, posY]
    size = SIZE_TO_CONTENT
    halign = HALIGN_CENTER
    valign = VALIGN_MIDDLE
    watch = mlwsState.IsMlwsHudVisible
    children = getChildren()
  }
}

return mlws