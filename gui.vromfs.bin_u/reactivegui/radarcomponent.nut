local math = require("std/math.nut")
local interopGen = require("daRg/helpers/interopGen.nut")
local compass = require("compass.nut")
local compassState = require("compassState.nut")


local style = {}

local greenColor = Color(10, 202, 10, 250)
local greenColorGrid = Color(10, 202, 10, 200)
local backgroundColor = Color(0, 0, 0, 150)
local fontOutlineColor = Color(0, 0, 0, 235)

local greenColorTarget = Color(0, 100, 0, 250)

const LINE_WIDTH = 1.6
const TURRET_LINE_WIDTH = 2.0

local compassWidth = hdpx(500)
local compassHeight = hdpx(40)
local compassStep = 5.0
local compassOneElementWidth = compassHeight

local getFontScale = function()
{
  return max(sh(100) / 1080, 1)
}

local getCompassStrikeWidth = @(oneElementWidth, step) 360.0 * oneElementWidth / step


style.lineForeground <- class {
  color = greenColor
  fillColor = greenColor
  lineWidth = hdpx(1) * LINE_WIDTH
  font = Fonts.hud
  fontFxColor = fontOutlineColor
  fontFxFactor = 40
  fontFx = FFT_GLOW
  fontScale = getFontScale()
}


local radarState = {
  IsRadarHudVisible = Watched(false)
  //radar 1
  IsRadarVisible = Watched(false)
  Azimuth = Watched(0.0)
  Distance = Watched(0.0)
  //radar 2
  IsRadar2Visible = Watched(false)
  Azimuth2 = Watched(0.0)
  Distance2 = Watched(0.0)
  TurretAzimuth = Watched(0.0)

  AzimuthMin = Watched(0)
  AzimuthMax = Watched(0)

  targets = []
  TargetsTrigger = Watched(0)
  currentTime = 0.0
  screenTargets = {}
  ScreenTargetsTrigger = Watched(0)
  ViewMode = Watched(0)
  DistanceMax = Watched(0)
  AzimuthMinDeg = Watched(0)
  AzimuthMaxDeg = Watched(0)
  azimuthMarkers = {}
  AzimuthMarkersTrigger = Watched(0)

  IsForestallVisible = Watched(false)
  forestall = {
    x = 0.0
    y = 0.0
  }
}

local getAzimuthRange = @() radarState.AzimuthMax.value - radarState.AzimuthMin.value


::interop.updateCurrentTime <- function(curr_time) {
  radarState.currentTime = 0.0
}


::interop.clearTargets <- function() {
  local needUpdate = false
  for(local i = 0; i < radarState.targets.len(); ++i)
  {
    if (radarState.targets[i] != null)
    {
      radarState.targets[i] = null
      needUpdate = true
    }
  }

  if (needUpdate)
    radarState.TargetsTrigger.trigger()
}


::interop.updateTarget <- function (index, azimuth, elevation, width, distance, relSpeed, ageRel, isSelected) {
  if(index >= radarState.targets.len())
    radarState.targets.resize(index + 1)

  radarState.targets[index] = {
    azimuth = azimuth
    elevation = elevation
    width = width
    distance = distance
    relSpeed = relSpeed
    ageRel = ageRel
    isSelected = isSelected
  }

  radarState.TargetsTrigger.trigger()
}


const targetLifeTime = 5.0


::interop.updateScreenTarget <- function(id, x, y, dist, speed) {
  if (!radarState.screenTargets)
    radarState.screenTargets = {}

  if (!radarState.screenTargets?[id])
  {
    radarState.screenTargets[id] <- {
      x = x
      y = y
      dist = dist
      speed = speed
    }
  }
  else
  {
    radarState.screenTargets[id].x = x
    radarState.screenTargets[id].y = y
    radarState.screenTargets[id].dist = dist
    radarState.screenTargets[id].speed = speed
  }

  radarState.ScreenTargetsTrigger.trigger()
}

::interop.clearScreenTargets <- function()
{
  if (radarState.screenTargets)
  {
    radarState.screenTargets = null
    radarState.ScreenTargetsTrigger.trigger()
  }
}


::interop.updateAzimuthMarker <- function(id, target_time, age, azimuth_world_deg, is_selected) {
  if (!radarState.azimuthMarkers)
    radarState.azimuthMarkers = {}

  if (!radarState.azimuthMarkers?[id])
  {
    radarState.azimuthMarkers[id] <- {
      azimuthWorldDeg = azimuth_world_deg
      targetTime = target_time
      age = age
      isSelected = is_selected
    }
  }
  else if (target_time > radarState.azimuthMarkers[id].targetTime)
  {
    radarState.azimuthMarkers[id].azimuthWorldDeg = azimuth_world_deg
    radarState.azimuthMarkers[id].isSelected = is_selected
    radarState.azimuthMarkers[id].targetTime = target_time
    radarState.azimuthMarkers[id].age = age
  }
  else
    return

  radarState.AzimuthMarkersTrigger.trigger()
}

::interop.clearAzimuthMarkers <- function()
{
  if (radarState.azimuthMarkers)
  {
    radarState.azimuthMarkers = null
    radarState.AzimuthMarkersTrigger.trigger()
  }
}


::interop.updateForestall <- function(x, y)
{
  radarState.forestall.x = x
  radarState.forestall.y = y
}


interopGen({
  stateTable = radarState
  prefix = "radar"
  postfix = "Update"
})


local C_ScopeBackground = function(width) {

  local back = {
    rendObj = ROBJ_SOLID
    size = [width, width]
    color = backgroundColor
  }

  local frame = style.lineForeground.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, width]
    commands = [
      [VECTOR_LINE, 0, 0, 0, 100],
      [VECTOR_LINE, 0, 100, 100, 100],
      [VECTOR_LINE, 100, 100, 100, 0],
      [VECTOR_LINE, 100, 0, 0, 0]
    ]
  })

  local gridSecondary = style.lineForeground.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(1)
    color = greenColorGrid
    size = [width, width]
    opacity = 0.42
    commands = [
      [VECTOR_LINE, 0, 25, 100, 25],
      [VECTOR_LINE, 0, 75, 100, 75],
      [VECTOR_LINE, 25, 0, 25, 100],
      [VECTOR_LINE, 75, 0, 75, 100],
      [VECTOR_LINE, 0, 50, 100, 50]
    ]
  })

  local gridMain = style.lineForeground.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, width]
    commands = [
      [VECTOR_LINE, 50, 0, 50, 98],
    ]
  })

  return {
    children = [
      back
      frame
      gridSecondary
      gridMain
    ]
  }

}

local C_ScopeAzimuthComponent = function(width, valueWatched, distWatched)
{
  local azimuthLine = @() style.lineForeground.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, width]
    watch = distWatched
    commands = [
      [VECTOR_LINE, 0, 100.0 * (1.0 - distWatched.value), 0, 100.0]
    ]
  })

  return @() style.lineForeground.__merge({
    size = SIZE_TO_CONTENT
    children = azimuthLine
    watch = valueWatched
    transform = {
      translate = [valueWatched.value * width, 0]
    }
  })
}


local createTargetOnRadar = function(index, radius, radarWidth, targetFunc) {
  local offset = targetFunc(index)
  local commands = [[VECTOR_ELLIPSE, 50, 50, 50, 50]]

  local selectionFrame = null
  if (radarState.targets[index].isSelected)
  {
    local frameWidth = 4.0 * radius
    selectionFrame = style.lineForeground.__merge({
      rendObj = ROBJ_VECTOR_CANVAS
      size = [frameWidth, frameWidth]
      pos = [-frameWidth * 0.5 + radius, -frameWidth * 0.5 + radius]
      commands = [
        [VECTOR_LINE, 0, 0, 0, 100],
        [VECTOR_LINE, 0, 100, 100, 100],
        [VECTOR_LINE, 100, 100, 100, 0],
        [VECTOR_LINE, 100, 0, 0, 0]
      ]
    })
  }

  return {
    rendObj = ROBJ_VECTOR_CANVAS
    size = [2*radius, 2*radius]
    lineWidth = hdpx(1)
    color = greenColorTarget
    fillColor = greenColorGrid
    opacity = (1.0 - radarState.targets[index].ageRel)
    commands = [
      [VECTOR_ELLIPSE, 50, 50, 50, 50]
    ]
    transform = {
      pivot = [0.5, 0.5]
      translate = [
        offset.x * radarWidth - radius,
        offset.y * radarWidth - radius
      ]
    }
    children = selectionFrame
  }
}


local b_ScopeRectTargetFunc = @(index) {
  x = radarState.targets[index].azimuth
  y = 1.0 - radarState.targets[index].distance
}


local b_ScopeCircleTargetFunc = function(index) {
  local angle = radarState.AzimuthMin.value + getAzimuthRange() * radarState.targets[index].azimuth - math.PI * 0.5
  return {
    x = 0.5 + 0.5 * math.cos(angle) * radarState.targets[index].distance
    y = 0.5 + 0.5 * math.sin(angle) * radarState.targets[index].distance
  }
}


local targetsComponent = function(radarWidth, targetFunc)
{
  local getTargets = function() {
    local targets = []
    for(local i = 0; i < radarState.targets.len(); ++i)
    {
      if (!radarState.targets[i])
        continue
      targets.append(createTargetOnRadar(i, hdpx(3), radarWidth, targetFunc))
    }
    return targets
  }

  return @()
  {
    size = [radarWidth, radarWidth]
    children = getTargets()
    watch = radarState.TargetsTrigger
  }
}


local B_ScopeSquareMarkers = function(radarWidth)
{
  local offsetScaleFactor = 1.3
  return {
    size = [offsetScaleFactor * radarWidth, offsetScaleFactor * radarWidth]
    children = [
      @() style.lineForeground.__merge({
        rendObj = ROBJ_DTEXT
        size = SIZE_TO_CONTENT
        pos = [radarWidth + hdpx(4), hdpx(4)]
        watch = radarState.DistanceMax
        text = radarState.DistanceMax.value + ::loc("measureUnits/km_dist")
      })
      @() style.lineForeground.__merge({
        rendObj = ROBJ_DTEXT
        size = SIZE_TO_CONTENT
        pos = [radarWidth + hdpx(4), radarWidth - hdpx(20)]
        text = "0" + ::loc("measureUnits/km_dist")
      })
      @() style.lineForeground.__merge({
        rendObj = ROBJ_DTEXT
        size = SIZE_TO_CONTENT
        pos = [hdpx(4), hdpx(4)]
        watch = radarState.AzimuthMinDeg
        text = radarState.AzimuthMinDeg.value + ::loc("measureUnits/deg")
      })
      @() style.lineForeground.__merge({
        rendObj = ROBJ_DTEXT
        size = SIZE_TO_CONTENT
        pos = [radarWidth - hdpx(40), hdpx(4)]
        watch = radarState.AzimuthMaxDeg
        text = radarState.AzimuthMaxDeg.value + ::loc("measureUnits/deg")
      })
    ]
  }
}


local B_ScopeSquare = function(width) {
  local getChildren = function() {
    local children = [ C_ScopeBackground(width) ]
    if (radarState.IsRadarVisible.value)
      children.append(C_ScopeAzimuthComponent(width, radarState.Azimuth, radarState.Distance))
    if (radarState.IsRadar2Visible.value)
      children.append(C_ScopeAzimuthComponent(width, radarState.Azimuth2, radarState.Distance2))
    children.append(targetsComponent(width, b_ScopeRectTargetFunc))
    return children
  }

  return @() {
    watch = [radarState.IsRadarVisible, radarState.IsRadar2Visible]
    children = [
      {
        size = SIZE_TO_CONTENT
        clipChildren = true
        children = getChildren()
      },
      B_ScopeSquareMarkers(width)
    ]
  }
}


local B_ScopeBackground = function(width) {

  local circle = {
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, width]
    color = greenColorGrid
    fillColor = backgroundColor
    lineWidth = hdpx(1) * LINE_WIDTH
    commands = [
      [VECTOR_ELLIPSE, 50, 50, 50, 50]
    ]
  }

  local commands = [
    [VECTOR_ELLIPSE, 50, 50, 12.5, 12.5],
    [VECTOR_ELLIPSE, 50, 50, 25.0, 25.0],
    [VECTOR_ELLIPSE, 50, 50, 37.5, 37.5],
  ]

  const angleGrad = 30.0
  local angle = math.PI * angleGrad / 180.0
  local dashCount = 360.0 / angleGrad
  for(local i = 0; i < dashCount; ++i)
  {
    commands.append([
      VECTOR_LINE, 50, 50,
      50 + math.cos(i * angle) * 50.0,
      50 + math.sin(i * angle) * 50.0
    ])
  }

  local gridSecondary = {
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(1)
    color = greenColorGrid
    fillColor = Color(0, 0, 0, 0)
    size = [width, width]
    opacity = 0.42
    commands = commands
  }

  return {
    children = [
      circle
      gridSecondary
    ]
  }
}


local B_ScopeAzimuthComponent = function(width, valueWatched, distWatched, lineWidth = LINE_WIDTH)
{
  return function()
  {
    local angle = radarState.AzimuthMin.value + getAzimuthRange() * valueWatched.value - math.PI * 0.5

    return {
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = hdpx(1) * lineWidth
      color = greenColor
      size = [width, width]
      watch = [valueWatched, distWatched]
      commands = [
        [
          VECTOR_LINE, 50, 50,
          50.0 + 50.0 * (distWatched?.value ?? 1.0) * math.cos(angle),
          50.0 + 50.0 * (distWatched?.value ?? 1.0) * math.sin(angle),
        ]
      ]
    }
  }
}


local B_ScopeCircleMarkers = function(radarWidth)
{
  local offsetScaleFactor = 1.3
  return {
    size = [offsetScaleFactor * radarWidth, offsetScaleFactor * radarWidth]
    children = [
      style.lineForeground.__merge({
        rendObj = ROBJ_DTEXT
        size = SIZE_TO_CONTENT
        pos = [radarWidth + hdpx(4), radarWidth * 0.5 - hdpx(15)]
        text = "90" + ::loc("measureUnits/deg")
      }),
      @() style.lineForeground.__merge({
        rendObj = ROBJ_DTEXT
        size = SIZE_TO_CONTENT
        pos = [radarWidth + hdpx(4), radarWidth * 0.5 + hdpx(5)]
        watch = radarState.DistanceMax
        text = radarState.DistanceMax.value + ::loc("measureUnits/km_dist")
      })
      style.lineForeground.__merge({
        rendObj = ROBJ_DTEXT
        size = SIZE_TO_CONTENT
        pos = [radarWidth * 0.5 - hdpx(4), -hdpx(18)]
        text = "0" + ::loc("measureUnits/deg")
      }),
      style.lineForeground.__merge({
        rendObj = ROBJ_DTEXT
        size = SIZE_TO_CONTENT
        pos = [radarWidth * 0.5 - hdpx(18), radarWidth + hdpx(4)]
        text = "180" + ::loc("measureUnits/deg")
      }),
      style.lineForeground.__merge({
        rendObj = ROBJ_DTEXT
        size = SIZE_TO_CONTENT
        pos = [-hdpx(52), radarWidth * 0.5 - hdpx(15)]
        text = "270" + ::loc("measureUnits/deg")
      }),
      @() style.lineForeground.__merge({
        rendObj = ROBJ_DTEXT
        size = SIZE_TO_CONTENT
        pos = [-hdpx(56), radarWidth * 0.5 + hdpx(5)]
        watch = radarState.DistanceMax
        text = radarState.DistanceMax.value + ::loc("measureUnits/km_dist")
      })
    ]
  }
}


local B_Scope = function(width) {
  local getChildren = function() {
    local children = [
      B_ScopeBackground(width),
      B_ScopeAzimuthComponent(width, radarState.TurretAzimuth, null, TURRET_LINE_WIDTH)
    ]
    if (radarState.IsRadarVisible.value)
      children.append(B_ScopeAzimuthComponent(width, radarState.Azimuth, radarState.Distance))
    if (radarState.IsRadar2Visible.value)
      children.append(B_ScopeAzimuthComponent(width, radarState.Azimuth2, radarState.Distance2))
    children.append(targetsComponent(width, b_ScopeCircleTargetFunc))
    return children
  }

  return @() {
    watch = [radarState.IsRadarVisible, radarState.IsRadar2Visible]
    children = [
      {
        size = SIZE_TO_CONTENT
        clipChildren = true
        children = getChildren()
      },
      B_ScopeCircleMarkers(width)
    ]
  }

}


local B_ScopeHalfBackground = function(width) {

  local circle = {
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, width]
    color = greenColorGrid
    fillColor = backgroundColor
    lineWidth = hdpx(1) * LINE_WIDTH
    opacity = 0.7
    commands = [
      [VECTOR_ELLIPSE, 50, 50, 50, 50]
    ]
  }

  local angleStart = radarState.AzimuthMin.value - math.PI * 0.5
  local angleFinish = radarState.AzimuthMax.value - math.PI * 0.5

  local commands = [
    [VECTOR_SECTOR, 50, 50, 12.5, 12.5, angleStart, angleFinish],
    [VECTOR_SECTOR, 50, 50, 25.0, 25.0, angleStart, angleFinish],
    [VECTOR_SECTOR, 50, 50, 37.5, 37.5, angleStart, angleFinish],
  ]

  const angleGrad = 15.0
  local angle = math.PI * angleGrad / 180.0
  local dashCount = 360.0 / angleGrad
  for(local i = 0; i < dashCount; ++i)
  {
    local currAngle = i * angle
    if (currAngle < angleStart + 2 * math.PI || currAngle > angleFinish + 2 * math.PI)
      continue

    commands.append([
      VECTOR_LINE, 50, 50,
      50 + math.cos(currAngle) * 50.0,
      50 + math.sin(currAngle) * 50.0
    ])
  }

  local gridSecondary = {
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(1)
    color = greenColorGrid
    fillColor = Color(0, 0, 0, 0)
    size = [width, width]
    opacity = 0.42
    commands = commands
  }

  local gridMain = {
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, width]
    color = greenColorGrid
    lineWidth = hdpx(1) * LINE_WIDTH
    opacity = 0.7
    commands = [
      [VECTOR_LINE, 0, 49.5, 100, 49.5],
      [
        VECTOR_LINE, 50, 50,
        50 + math.cos(angleStart) * 50.0,
        50 + math.sin(angleStart) * 50.0
      ],
      [
        VECTOR_LINE, 50, 50,
        50 + math.cos(angleFinish) * 50.0,
        50 + math.sin(angleFinish) * 50.0
      ]
    ]
  }

  return {
    children = [
      circle
      gridSecondary
      gridMain
    ]
  }
}


local B_ScopeHalfCircleMarkers = function(radarWidth)
{
  local offsetScaleFactor = 1.3
  return {
    size = [offsetScaleFactor * radarWidth, offsetScaleFactor * radarWidth]
    children = [
      @() style.lineForeground.__merge({
        rendObj = ROBJ_DTEXT
        size = SIZE_TO_CONTENT
        pos = [radarWidth + hdpx(4), radarWidth * 0.5 - hdpx(10)]
        watch = radarState.DistanceMax
        text = radarState.DistanceMax.value + ::loc("measureUnits/km_dist")
      })
    ]
  }
}


local B_ScopeHalf = function(width) {
  local getChildren = function() {
    local children = [ B_ScopeHalfBackground(width) ]
    if (radarState.IsRadarVisible.value)
      children.append(B_ScopeAzimuthComponent(width, radarState.Azimuth, radarState.Distance))
    if (radarState.IsRadar2Visible.value)
      children.append(B_ScopeAzimuthComponent(width, radarState.Azimuth2, radarState.Distance2))
    children.append(targetsComponent(width, b_ScopeCircleTargetFunc))
    return children
  }

  return @() {
    watch = [radarState.IsRadarVisible, radarState.IsRadar2Visible]
    children = [
      {
        size = [width + hdpx(2), 0.5 * width]
        halign = HALIGN_CENTER
        clipChildren = true
        children = getChildren()
      },
      B_ScopeHalfCircleMarkers(width)
    ]
  }
}


local createTargetOnScreen = function(id, xFunc, yFunc, distFunc, speedFunc, width) {
  return @() {
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(1) * LINE_WIDTH
    color = greenColor
    size = [width, width]
    commands = [
      [VECTOR_LINE, 0, 0, 0, 100],
      [VECTOR_LINE, 0, 100, 100, 100],
      [VECTOR_LINE, 100, 100, 100, 0],
      [VECTOR_LINE, 100, 0, 0, 0],
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [xFunc() - 0.5 * width, yFunc() - 0.5 * width]
      }
    }
    children = [
      @() style.lineForeground.__merge({
        rendObj = ROBJ_DTEXT
        size = [width * 4, SIZE_TO_CONTENT]
        behavior = Behaviors.RtPropUpdate
        pos = [0, width + hdpx(2)]
        fontScale = getFontScale() * 0.6
        fontFxFactor = 5
        update = @() {
          text = distFunc()
        }
      }),
      @() style.lineForeground.__merge({
        rendObj = ROBJ_DTEXT
        size = [width * 4, SIZE_TO_CONTENT]
        behavior = Behaviors.RtPropUpdate
        pos = [0, width + hdpx(15)]
        fontScale = getFontScale() * 0.6
        fontFxFactor = 5
        update = @() {
          text = speedFunc()
        }
      })
    ]
  }
}


local targetsOnScreenComponent = function() {
  local targetWidth = hdpx(30)

  local getTargets = function() {
    if (!radarState.screenTargets)
      return null

    local targets = []
    foreach (id, target in radarState.screenTargets)
    {
      local getX = @() radarState.screenTargets?[id]?.x ?? -100
      local getY = @() radarState.screenTargets?[id]?.y ?? -100
      local getDist = @() "D = " + radarState.screenTargets?[id]?.dist + ::loc("measureUnits/meters_alt") ?? ""
      local getSpeed = @() "dV = " + radarState.screenTargets?[id]?.speed + ::loc("measureUnits/kmh") ?? ""
      targets.append(createTargetOnScreen(id, getX, getY, getDist, getSpeed, targetWidth))
    }
    return targets
  }

  return @(){
    size = [sw(100), sh(100)]
    children = getTargets()
    watch = radarState.ScreenTargetsTrigger
  }
}


local forestallComponent = function() {
  local radius = hdpx(10)

  local getChildren = function() {
    return radarState.IsForestallVisible.value
      ? @() {
          rendObj = ROBJ_VECTOR_CANVAS
          size = [2*radius, 2*radius]
          lineWidth = hdpx(1)
          color = greenColorTarget
          fillColor = Color(0, 0, 0, 0)
          commands = [
            [VECTOR_ELLIPSE, 50, 50, 50, 50]
          ]
          behavior = Behaviors.RtPropUpdate
          update = @() {
            transform = {
              translate = [radarState.forestall.x - radius, radarState.forestall.y - radius]
            }
          }
        }
      : null
  }

  return @(){
    size = [sw(100), sh(100)]
    children = getChildren()
    watch = radarState.IsForestallVisible
  }
}


local compassComponent = @() {
  size = SIZE_TO_CONTENT
  pos = [sw(50) - 0.5 * compassWidth, sh(12)]
  children = [
    compass(style.lineForeground, compassWidth, compassHeight, greenColor)
  ]
}


local createAzimuthMark = function(width, height, isSelected) {

  local frame = null

  if (isSelected)
  {
    local frameSizeW = width * 1.5
    local frameSizeH = height * 1.5

    frame = {
      size = [frameSizeW, frameSizeH]
      pos = [(width - frameSizeW) * 0.5, (height - frameSizeH) * 0.5 ]
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = hdpx(1) * 2.0
      color = greenColorGrid
      fillColor = Color(0, 0, 0, 0)
      commands = [
        [VECTOR_LINE, 0, 0, 100, 0],
        [VECTOR_LINE, 100, 0, 100, 100],
        [VECTOR_LINE, 100, 100, 0, 100],
        [VECTOR_LINE, 0, 100, 0, 0]
      ]
    }
  }

  return {
    size = [width, height]
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(1) * 3.0
    color = greenColor
    fillColor = Color(0, 0, 0, 0)
    commands = [
      [VECTOR_LINE, 0, 100, 50, 0],
      [VECTOR_LINE, 50, 0, 100, 100],
      [VECTOR_LINE, 100, 100, 0, 100]
    ]
    children = frame
  }
}


local createAzimuthMarkWithOffset = function(id, width, height, total_width, angle, isSelected, isSecondRound) {
  local offset = (isSecondRound ? total_width : 0) +
    total_width * angle / 360.0 + 0.5 * width

  local animTrigger = "fadeMarker" + id + (isSelected ? "_1" : "_0")

  if (!isSelected)
    ::anim_start(animTrigger)

  return @() {
    size = SIZE_TO_CONTENT
    pos = [offset, 0]
    children = createAzimuthMark(width, height, isSelected)
    animations = [
      {
        trigger = animTrigger
        prop = AnimProp.opacity
        from = 1.0
        to = 0.0
        duration = targetLifeTime
      }
    ]
  }
}


local createAzimuthMarkStrike = function(total_width, height, markerWidth) {
  local getChildren = function() {
    if (!radarState.azimuthMarkers)
      return null

    local markers = []
    foreach(id, azimuthMarker in radarState.azimuthMarkers)
    {
      markers.append(createAzimuthMarkWithOffset(id, markerWidth, height, total_width,
        azimuthMarker.azimuthWorldDeg, azimuthMarker.isSelected, false))
      markers.append(createAzimuthMarkWithOffset(id, markerWidth, height, total_width,
        azimuthMarker.azimuthWorldDeg, azimuthMarker.isSelected, true))
    }

    return markers
  }

  return @() {
    size = [total_width * 2.0, height]
    pos = [0, height * 0.5]
    watch = radarState.AzimuthMarkersTrigger
    children = getChildren()
  }
}


local createAzimuthMarkStrikeComponent = function(width, total_width, height) {

  local markerWidth = hdpx(20)

  local getOffset = @() 0.5 * (width - compassOneElementWidth)
    + compassState.CompassValue.value * compassOneElementWidth * 2.0 / compassStep
    - total_width

  return @() {
    size = [width, height * 2.0]
    clipChildren = true
    children = @() {
      children = createAzimuthMarkStrike(total_width, height, markerWidth)
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = [getOffset(), 0]
        }
      }
    }
  }
}


local azimuthMarkStrike = function() {
  local width = compassWidth * 1.5
  local totalWidth = 2.0 * getCompassStrikeWidth(compassOneElementWidth, compassStep)

  return {
    size = SIZE_TO_CONTENT
    pos = [sw(50) - 0.5 * width, sh(17)]
    children = [
      createAzimuthMarkStrikeComponent(width, totalWidth, hdpx(30))
    ]
  }
}


local radar = @(){
  pos = [sw(5), sh(32)]
  size = SIZE_TO_CONTENT
  children = function(){
    local width = sw(15)

    local scopeChild = null
    if (radarState.ViewMode.value == RadarViewMode.B_SCOPE_ROUND)
    {
      if (getAzimuthRange() > math.PI)
        scopeChild = B_Scope(width)
      else
        scopeChild = B_ScopeHalf(width)
    }
    else if (radarState.ViewMode.value == RadarViewMode.B_SCOPE_SQUARE)
      scopeChild = B_ScopeSquare(width)

    return {
      size = SIZE_TO_CONTENT
      flow = FLOW_VERTICAL
      gap = hdpx(10)
      watch = radarState.ViewMode
      children = scopeChild
    }
  }
}


local Root = function() {
  local getChildren = function() {
    return radarState.IsRadarHudVisible.value ?
      [
        targetsOnScreenComponent()
        forestallComponent()
        radar
        compassComponent
        azimuthMarkStrike
      ]
      : null
  }

  return {
    halign = HALIGN_LEFT
    valign = VALIGN_TOP
    size = [sw(100), sh(100)]
    watch = radarState.IsRadarHudVisible
    children = getChildren()
  }
}


return Root
