local math = require("std/math.nut")
local screenState = require("style/screenState.nut")
local interopGen = require("daRg/helpers/interopGen.nut")
local compass = require("compass.nut")
local compassState = require("compassState.nut")

local style = {}

local greenColor = Color(10, 202, 10, 250)
local greenColorGrid = Color(10, 202, 10, 200)
local backgroundColor = Color(0, 0, 0, 150)
local fontOutlineColor = Color(0, 0, 0, 235)
local targetSectorColor = Color(10, 40, 10, 200)

local greenColorTarget = Color(0, 0, 0, 0)
const TURRET_LINE_WIDTH = 2.0

local compassWidth = hdpx(500)
local compassHeight = hdpx(40)
local compassStep = 5.0
local compassOneElementWidth = compassHeight

local getFontScale = function()
{
  return sh(100) / 1080
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
  Elevation = Watched(0.0)
  Distance = Watched(0.0)
  AzimuthHalfWidth = Watched(0.0)

  //radar 2
  IsRadar2Visible = Watched(false)
  Azimuth2 = Watched(0.0)
  Elevation2 = Watched(0.0)
  Distance2 = Watched(0.0)
  AzimuthHalfWidth2 = Watched(0.0)

  TurretAzimuth = Watched(0.0)
  TargetRadarAzimuthWidth = Watched(0.0)
  TargetRadarDist = Watched(0.0)
  AzimuthMin = Watched(0)
  AzimuthMax = Watched(0)
  ElevationMinDeg = Watched(0)
  ElevationMaxDeg = Watched(0)

  targets = []
  TargetsTrigger = Watched(0)
  currentTime = 0.0
  screenTargets = {}
  ScreenTargetsTrigger = Watched(0)
  ViewMode = Watched(0)
  HasDistanceScale = Watched(0)
  DistanceMax = Watched(0)
  AzimuthMinDeg = Watched(0)
  AzimuthMaxDeg = Watched(0)
  azimuthMarkers = {}
  AzimuthMarkersTrigger = Watched(0)
  Irst = Watched(false)

  IsForestallVisible = Watched(false)
  forestall = {
    x = 0.0
    y = 0.0
  }
  selectedTarget = {
    x = 0.0
    y = 0.0
  }

  selectedTargetBlinking = false
  selectedTargetSpeedBlinking = false
}

local getAzimuthRange = @() radarState.AzimuthMax.value - radarState.AzimuthMin.value
local getBlinkOpacity = @() math.round(radarState.currentTime * 3) % 2 == 0 ? 1.0 : 0.2


::interop.updateCurrentTime <- function(curr_time) {
  radarState.currentTime = curr_time
}


::interop.updateBlinking <- function(isTargetBlink, isSpeedBlink) {
  radarState.selectedTargetBlinking = isTargetBlink
  radarState.selectedTargetSpeedBlinking = isSpeedBlink
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


::interop.updateTarget <- function (index, azimuth, elevation, distance, age_rel, is_selected, is_detected, is_enemy, signal_rel) {
  if(index >= radarState.targets.len())
    radarState.targets.resize(index + 1)

  local cvt = @(val, vmin, vmax, omin, omax) omin + ((omax - omin) * (val - vmin)) / (vmax - vmin)

  local signalRel = signal_rel < 0.05
    ? 0.0
    : cvt(signal_rel, 0.05, 1.0, 0.3, 1.0)

  radarState.targets[index] = {
    azimuth = azimuth
    elevation = elevation
    distance = distance
    ageRel = age_rel
    isSelected = is_selected
    isDetected = is_detected
    isEnemy = is_enemy
    signalRel = signalRel
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
      isUpdated = true
    }
  }
  else
  {
    radarState.screenTargets[id].x = x
    radarState.screenTargets[id].y = y
    radarState.screenTargets[id].dist = dist
    radarState.screenTargets[id].speed = speed
    radarState.screenTargets[id].isUpdated = true
  }

  radarState.ScreenTargetsTrigger.trigger()
}


::interop.updateAzimuthMarker <- function(id, target_time, age, azimuth_world_deg, is_selected, is_detected, is_enemy) {
  if (!radarState.azimuthMarkers)
    radarState.azimuthMarkers = {}

  if (!radarState.azimuthMarkers?[id])
  {
    radarState.azimuthMarkers[id] <- {
      azimuthWorldDeg = azimuth_world_deg
      targetTime = target_time
      age = age
      isSelected = is_selected
      isDetected = is_detected
      isEnemy = is_enemy
      isUpdated = true
    }
  }
  else if (target_time > radarState.azimuthMarkers[id].targetTime)
  {
    radarState.azimuthMarkers[id].azimuthWorldDeg = azimuth_world_deg
    radarState.azimuthMarkers[id].isSelected = is_selected
    radarState.azimuthMarkers[id].targetTime = target_time
    radarState.azimuthMarkers[id].age = age
    radarState.azimuthMarkers[id].isDetected = is_detected
    radarState.azimuthMarkers[id].isEnemy = is_enemy
    radarState.azimuthMarkers[id].isUpdated = true
  }
  else
    return

  radarState.AzimuthMarkersTrigger.trigger()
}


::interop.resetTargetsFlags <- function()
{
  foreach(id, target in radarState.screenTargets)
    if (target)
      target.isUpdated = false

  foreach(id, marker in radarState.azimuthMarkers)
    if (marker)
      marker.isUpdated = false
}


::interop.clearUnusedTargets <- function()
{
  local needUpdate = false
  foreach(id, target in radarState.screenTargets)
    if (target && !target.isUpdated)
    {
      radarState.screenTargets[id] = null
      needUpdate = true
    }
  if(needUpdate)
    radarState.ScreenTargetsTrigger.trigger()

  needUpdate = false
  foreach(id, marker in radarState.azimuthMarkers)
    if (marker && !marker.isUpdated && radarState.currentTime > marker.targetTime + targetLifeTime)
    {
      radarState.azimuthMarkers[id] = null
      needUpdate = true
    }
  if(needUpdate)
    radarState.AzimuthMarkersTrigger.trigger()
}


::interop.updateForestall <- function(x, y)
{
  radarState.forestall.x = x
  radarState.forestall.y = y
}


::interop.updateSelectedTarget <- function(x, y)
{
  radarState.selectedTarget.x = x
  radarState.selectedTarget.y = y
}


interopGen({
  stateTable = radarState
  prefix = "radar"
  postfix = "Update"
})


local C_ScopeBackground = function(width, height) {

  local back = {
    rendObj = ROBJ_SOLID
    size = [width, height]
    color = backgroundColor
  }

  local frame = style.lineForeground.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, height]
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
    size = [width, height]
    opacity = 0.42
    commands = [
      [VECTOR_LINE, 0, 25, 100, 25],
      [VECTOR_LINE, 0, 75, 100, 75],
      [VECTOR_LINE, 25, 0, 25, 100],
      [VECTOR_LINE, 75, 0, 75, 100],
      [VECTOR_LINE, 0, 50, 100, 50],
      [VECTOR_LINE, 50, 0, 50, 100]
    ]
  })

  return {
    children = [
      back
      frame
      gridSecondary
    ]
  }

}

local C_ScopeAzimuthComponent = function(width, height, valueWatched, distWatched, halfWidthWatched)
{
  local getChildren = function() {
    if (distWatched && distWatched.value == 1.0 && halfWidthWatched && halfWidthWatched.value > 0)
    {
      local halfAzimuthWidth = 100.0 * (getAzimuthRange() > 0 ? halfWidthWatched.value / getAzimuthRange() : 0)

      return {
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = hdpx(1)
        color = greenColor
        fillColor = greenColorGrid
        opacity = 0.6
        size = [width, height]
        commands = [
          [VECTOR_POLY, -halfAzimuthWidth, 0, halfAzimuthWidth, 0, halfAzimuthWidth, 100, -halfAzimuthWidth, 100]
        ]
      }
    }
    else
    {
      return style.lineForeground.__merge({
        rendObj = ROBJ_VECTOR_CANVAS
        size = [width, height]
        commands = distWatched
          ? [[VECTOR_LINE_DASHED, 0, 100.0 * (1.0 - distWatched.value), 0, 100.0, hdpx(10), hdpx(5)]]
          : [[VECTOR_LINE, 0, 0, 0, 100.0]]
      })
    }
  }

  return @() style.lineForeground.__merge({
    size = SIZE_TO_CONTENT
    children = getChildren()
    watch = [valueWatched, distWatched, halfWidthWatched]
    transform = {
      translate = [valueWatched.value * width, 0]
    }
  })
}

local function C_ScopeTargetSectorComponent(width, valueWatched, distWatched, halfWidthWatched, fillColor = greenColorGrid) {

  local function getChildren() {
    if (distWatched && halfWidthWatched && halfWidthWatched.value > 0) {

      local halfAzimuthWidth = 100.0 * (getAzimuthRange() > 0 ? halfWidthWatched.value / getAzimuthRange() : 0)
      local com = [[VECTOR_POLY, -halfAzimuthWidth, 100 * (1 - distWatched.value), halfAzimuthWidth, 100 * (1 - distWatched.value),
            halfAzimuthWidth, 100, -halfAzimuthWidth, 100]]

      if (valueWatched.value * 100 - halfAzimuthWidth < 0)
        com.append([VECTOR_POLY, -halfAzimuthWidth + 100, 100 * (1 - distWatched.value), halfAzimuthWidth + 100, 100 * (1 - distWatched.value),
            halfAzimuthWidth + 100, 100, -halfAzimuthWidth + 100, 100])
      if (valueWatched.value * 100 + halfAzimuthWidth > 100)
        com.append([VECTOR_POLY, -halfAzimuthWidth - 100, 100 * (1 - distWatched.value), halfAzimuthWidth - 100, 100 * (1 - distWatched.value),
            halfAzimuthWidth - 100, 100, -halfAzimuthWidth - 100, 100])
      return {
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = hdpx(1)
        color = greenColor
        fillColor = fillColor
        opacity = 0.42
        size = [width, width]
        commands = com
      }
    }
    return null
  }

  local isTank = getAzimuthRange() > math.PI
  return @() style.lineForeground.__merge({
    size = SIZE_TO_CONTENT
    children = getChildren()
    watch = [valueWatched, distWatched, halfWidthWatched]
    transform = {
      translate = [(isTank ? valueWatched.value : 0.5) * width, 0]
    }
  })
}

local function createTargetOnRadar(index, radius, radarWidth, radarHeight, targetFunc) {
  local offset = targetFunc(index)

  local selectionFrame = null
  local frameWidth = 4.0 * radius
  local target = radarState.targets[index]
  local opacity = (1.0 - target.ageRel) * target.signalRel

  if (target.isSelected || target.isDetected || !target.isEnemy)
  {
    local frameCommands = []

    if (target.isSelected)
      frameCommands.extend([
        [VECTOR_LINE, 0, 0, 100, 0],
        [VECTOR_LINE, 100, 0, 100, 100],
        [VECTOR_LINE, 100, 100, 0, 100],
        [VECTOR_LINE, 0, 100, 0, 0]
      ])
    else if (target.isDetected)
      frameCommands.extend([
        [VECTOR_LINE, 100, 0, 100, 100],
        [VECTOR_LINE, 0, 100, 0, 0]
      ])

    if (!target.isEnemy)
    {
      local yOffset = target.isSelected ? 130 : 100
      local xOffset = target.isSelected ? 0 : 20
      frameCommands.append([VECTOR_LINE, xOffset, yOffset, 100.0 - xOffset, yOffset])
    }

    selectionFrame = target.isSelected
    ? @() style.lineForeground.__merge({
        rendObj = ROBJ_VECTOR_CANVAS
        size = [frameWidth, frameWidth]
        pos = [-frameWidth * 0.5 + radius, -frameWidth * 0.5 + radius]
        commands = frameCommands
        behavior = Behaviors.RtPropUpdate
        update = function() {
          return {
            opacity = radarState.selectedTargetBlinking ? getBlinkOpacity() : opacity
          }
        }
      })
    : style.lineForeground.__merge({
      rendObj = ROBJ_VECTOR_CANVAS
      size = [frameWidth, frameWidth]
      pos = [-frameWidth * 0.5 + radius, -frameWidth * 0.5 + radius]
      commands = frameCommands
    })
  }

  return {
    rendObj = ROBJ_VECTOR_CANVAS
    size = [2*radius, 2*radius]
    lineWidth = hdpx(1)
    color = greenColorTarget
    fillColor = greenColorGrid
    opacity = opacity
    commands = [
      [VECTOR_ELLIPSE, 50, 50, 50, 50]
    ]
    transform = {
      pivot = [0.5, 0.5]
      translate = [
        offset.x * radarWidth - radius,
        offset.y * radarHeight - radius
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
  local distance = radarState.HasDistanceScale.value ? radarState.targets[index].distance : 0.9
  return {
    x = 0.5 + 0.5 * math.cos(angle) * distance
    y = 0.5 + 0.5 * math.sin(angle) * distance
  }
}

local targetsComponent = function(radarWidth, radarHeight, targetFunc)
{
  local getTargets = function() {
    local targets = []
    for(local i = 0; i < radarState.targets.len(); ++i)
    {
      if (!radarState.targets[i])
        continue
      targets.append(createTargetOnRadar(i, hdpx(5), radarWidth, radarHeight, targetFunc))
    }
    return targets
  }

  return @()
  {
    size = [radarWidth, radarHeight]
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
        watch = [ radarState.HasDistanceScale, radarState.DistanceMax ]
        text = radarState.HasDistanceScale.value ?
          radarState.DistanceMax.value.tointeger() + ::loc("measureUnits/km_dist") : ""
      })
      style.lineForeground.__merge({
        rendObj = ROBJ_STEXT
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
      {
        size = [radarWidth, SIZE_TO_CONTENT]
        children = @() style.lineForeground.__merge({
          rendObj = ROBJ_DTEXT
          pos = [-hdpx(4), hdpx(4)]
          hplace = HALIGN_RIGHT
          watch = radarState.AzimuthMaxDeg
          text = radarState.AzimuthMaxDeg.value + ::loc("measureUnits/deg")
        })
      }
      style.lineForeground.__merge({
        rendObj = ROBJ_DTEXT
        size = SIZE_TO_CONTENT
        pos = [radarWidth * 0.5 - hdpx(4), -hdpx(20)]
        opacity = ((radarState.IsRadarVisible?.value ?? false) || (radarState.IsRadar2Visible?.value ?? false)) ? 100 : 0
        text = radarState.Irst.value ? ::loc("hud/irst") : ::loc("hud/radarEmitting")
      })
    ]
  }
}


local B_ScopeSquare = function(width) {
  local getChildren = function() {
    local children = [
      C_ScopeBackground(width, width),
      C_ScopeTargetSectorComponent(width, radarState.TurretAzimuth, radarState.TargetRadarDist, radarState.TargetRadarAzimuthWidth,
      targetSectorColor),
      C_ScopeAzimuthComponent(width, width, radarState.TurretAzimuth, null, null),
      {
        size = [width, width]
        rendObj = ROBJ_RADAR_GROUND_REFLECTIONS
        isSquare = true
        xFragments = 30
        yFragments = 10
        color = greenColor
      }
    ]
    if (radarState.IsRadarVisible.value)
      children.append(C_ScopeAzimuthComponent(width, width, radarState.Azimuth, radarState.Distance, radarState.AzimuthHalfWidth))
    if (radarState.IsRadar2Visible.value)
      children.append(C_ScopeAzimuthComponent(width, width, radarState.Azimuth2, radarState.Distance2, radarState.AzimuthHalfWidth2))
    children.append(targetsComponent(width, width, b_ScopeRectTargetFunc))
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

  local commands = radarState.HasDistanceScale.value ?
  [
    [VECTOR_ELLIPSE, 50, 50, 12.5, 12.5],
    [VECTOR_ELLIPSE, 50, 50, 25.0, 25.0],
    [VECTOR_ELLIPSE, 50, 50, 37.5, 37.5]
  ] :
  [
    [VECTOR_ELLIPSE, 50, 50, 45.0, 45.0]
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


local B_ScopeAzimuthComponent = function(width, valueWatched, distWatched, halfWidthWatched, lineWidth = LINE_WIDTH)
{
  local getChildren = function() {
    if (distWatched && distWatched.value == 1.0 && halfWidthWatched && halfWidthWatched.value > 0)
    {
      local sectorCommands = [VECTOR_POLY, 50, 50]
      local step = math.PI * 0.05
      local angleCenter = radarState.AzimuthMin.value + getAzimuthRange() * valueWatched.value - math.PI * 0.5
      local angleFinish = angleCenter + halfWidthWatched.value
      local angle = angleCenter - halfWidthWatched.value

      while (angle <= angleFinish) {
        sectorCommands.append(50.0 + 50.0 * math.cos(angle))
        sectorCommands.append(50.0 + 50.0 * math.sin(angle))
        if (angle == angleFinish)
          break;
        angle += step
        if (angle > angleFinish)
          angle = angleFinish
      }

      return {
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = hdpx(1)
        color = greenColor
        fillColor = greenColorGrid
        opacity = 0.6
        size = [width, width]
        commands = [sectorCommands]
      }
    }
    else {
      return function() {
        local angle = radarState.AzimuthMin.value + getAzimuthRange() * valueWatched.value - math.PI * 0.5
        local commands = distWatched ? [VECTOR_LINE_DASHED] : [VECTOR_LINE]
        commands.extend([
          50, 50,
          50.0 + 50.0 * (distWatched?.value ?? 1.0) * math.cos(angle),
          50.0 + 50.0 * (distWatched?.value ?? 1.0) * math.sin(angle),
        ])
        if (distWatched)
          commands.extend([hdpx(10), hdpx(5)])

        return {
          rendObj = ROBJ_VECTOR_CANVAS
          lineWidth = hdpx(1) * lineWidth
          color = greenColor
          size = [width, width]
          watch = [valueWatched, distWatched]
          commands = [commands]
        }
      }
    }
  }

  return @() {
    watch = [valueWatched, distWatched, halfWidthWatched]
    size = SIZE_TO_CONTENT
    children = getChildren()
  }
}

local function B_ScopeSectorComponent(width, valueWatched, distWatched, halfWidthWatched, fillColorP = greenColorGrid) {

  local function getChildren() {
    if (distWatched && halfWidthWatched && halfWidthWatched.value > 0) {

      local sectorCommands = [VECTOR_POLY, 50, 50]
      local step = math.PI * 0.05
      local angleCenter = radarState.AzimuthMin.value + getAzimuthRange() *
        (valueWatched?.value ?? 0.5) - math.PI * 0.5
      local angleFinish = angleCenter + halfWidthWatched.value
      local angle = angleCenter - halfWidthWatched.value

      while (angle <= angleFinish) {
        sectorCommands.append(50.0 + distWatched.value * 50 * math.cos(angle))
        sectorCommands.append(50.0 + distWatched.value * 50 * math.sin(angle))
        if (angle == angleFinish)
          break;
        angle += step
        if (angle > angleFinish)
          angle = angleFinish
      }

      return {
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = hdpx(1)
        color = greenColor
        fillColor = fillColorP
        opacity = 0.42
        size = [width, width]
        commands = [sectorCommands]
      }
    }
    return null
  }

  return @() {
    watch = [valueWatched, distWatched, halfWidthWatched]
    size = SIZE_TO_CONTENT
    children = getChildren()
  }
}

local B_ScopeCircleMarkers = function(radarWidth)
{
  local offsetScaleFactor = 1.3
  return {
    size = [offsetScaleFactor * radarWidth, offsetScaleFactor * radarWidth]
    children = [
      style.lineForeground.__merge({
        rendObj = ROBJ_STEXT
        size = SIZE_TO_CONTENT
        pos = [radarWidth + hdpx(4), radarWidth * 0.5 - hdpx(15)]
        text = "90" + ::loc("measureUnits/deg")
      }),
      @() style.lineForeground.__merge({
        rendObj = ROBJ_DTEXT
        size = SIZE_TO_CONTENT
        pos = [radarWidth + hdpx(4), radarWidth * 0.5 + hdpx(5)]
        watch = [ radarState.HasDistanceScale, radarState.DistanceMax ]
        text = radarState.HasDistanceScale.value ?
          radarState.DistanceMax.value.tointeger() + ::loc("measureUnits/km_dist") : ""
      })
      style.lineForeground.__merge({
        rendObj = ROBJ_STEXT
        size = SIZE_TO_CONTENT
        pos = [radarWidth * 0.5 - hdpx(4), -hdpx(18)]
        text = "0" + ::loc("measureUnits/deg")
      }),
      style.lineForeground.__merge({
        rendObj = ROBJ_STEXT
        size = SIZE_TO_CONTENT
        pos = [radarWidth * 0.5 - hdpx(18), radarWidth + hdpx(4)]
        text = "180" + ::loc("measureUnits/deg")
      }),
      style.lineForeground.__merge({
        rendObj = ROBJ_STEXT
        size = SIZE_TO_CONTENT
        pos = [-hdpx(52), radarWidth * 0.5 - hdpx(15)]
        text = "270" + ::loc("measureUnits/deg")
      }),
      @() style.lineForeground.__merge({
        rendObj = ROBJ_DTEXT
        size = SIZE_TO_CONTENT
        pos = [-hdpx(56), radarWidth * 0.5 + hdpx(5)]
        watch = [ radarState.HasDistanceScale, radarState.DistanceMax ]
        text = radarState.HasDistanceScale.value ?
          radarState.DistanceMax.value.tointeger() + ::loc("measureUnits/km_dist") : ""
      }),
      style.lineForeground.__merge({
        rendObj = ROBJ_DTEXT
        size = SIZE_TO_CONTENT
        pos = [radarWidth * 0.5 - hdpx(4), -hdpx(40)]
        opacity = ((radarState.IsRadarVisible?.value ?? false) || (radarState.IsRadar2Visible?.value ?? false)) ? 100 : 0
        text = radarState.Irst.value ? ::loc("hud/irst") : ::loc("hud/radarEmitting")
      })
    ]
  }
}


local B_Scope = function(width) {
  local getChildren = function() {
    local children = [
      B_ScopeBackground(width),
      B_ScopeAzimuthComponent(width, radarState.TurretAzimuth, null, null, TURRET_LINE_WIDTH),
      B_ScopeSectorComponent(width, radarState.TurretAzimuth, radarState.TargetRadarDist, radarState.TargetRadarAzimuthWidth, targetSectorColor)
    ]
    if (radarState.IsRadarVisible.value)
      children.append(B_ScopeAzimuthComponent(width, radarState.Azimuth, radarState.Distance, radarState.AzimuthHalfWidth))
    if (radarState.IsRadar2Visible.value)
      children.append(B_ScopeAzimuthComponent(width, radarState.Azimuth2, radarState.Distance2, radarState.AzimuthHalfWidth2))
    children.append(targetsComponent(width, width, b_ScopeCircleTargetFunc))
    return children
  }

  return @() {
    watch = [radarState.IsRadarVisible, radarState.IsRadar2Visible, radarState.HasDistanceScale]
    children = [
      {
        size = [width + hdpx(2), width + hdpx(2)]
        clipChildren = true
        halign = HALIGN_CENTER
        valign = VALIGN_MIDDLE
        children = getChildren()
      },
      B_ScopeCircleMarkers(width)
    ]
  }

}


local B_ScopeHalfBackground = function(width) {

  local getChildren = function() {
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

    local rad2deg = 180.0 / math.PI
    local angleStartDeg = angleStart * rad2deg
    local angleFinishDeg = angleFinish * rad2deg

    local commands = [
      [VECTOR_SECTOR, 50, 50, 12.5, 12.5, angleStartDeg, angleFinishDeg],
      [VECTOR_SECTOR, 50, 50, 25.0, 25.0, angleStartDeg, angleFinishDeg],
      [VECTOR_SECTOR, 50, 50, 37.5, 37.5, angleStartDeg, angleFinishDeg],
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

    return [
      circle
      gridSecondary
      gridMain
    ]
  }

  return @() {
    watch = [radarState.AzimuthMin, radarState.AzimuthMax]
    children = getChildren()
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
        watch = [ radarState.HasDistanceScale, radarState.DistanceMax ]
        text = radarState.HasDistanceScale.value ?
          radarState.DistanceMax.value.tointeger() + ::loc("measureUnits/km_dist") : ""
      })
      style.lineForeground.__merge({
        rendObj = ROBJ_DTEXT
        size = SIZE_TO_CONTENT
        pos = [radarWidth * 0.5 - hdpx(4), -hdpx(20)]
        opacity = ((radarState.IsRadarVisible?.value ?? false) || (radarState.IsRadar2Visible?.value ?? false)) ? 100 : 0
        text = radarState.Irst.value ? ::loc("hud/irst") : ::loc("hud/radarEmitting")
      })
    ]
  }
}


local B_ScopeHalf = function(width) {
  local getChildren = function() {
    local children = [
      B_ScopeHalfBackground(width),
      B_ScopeSectorComponent(width, null, radarState.TargetRadarDist, radarState.TargetRadarAzimuthWidth, targetSectorColor),
      {
        size = [width, width]
        rendObj = ROBJ_RADAR_GROUND_REFLECTIONS
        isSquare = false
        xFragments = 20
        yFragments = 8
        color = greenColor
      }
    ]
    if (radarState.IsRadarVisible.value)
      children.append(B_ScopeAzimuthComponent(width, radarState.Azimuth, radarState.Distance, radarState.AzimuthHalfWidth))
    if (radarState.IsRadar2Visible.value)
      children.append(B_ScopeAzimuthComponent(width, radarState.Azimuth2, radarState.Distance2, radarState.AzimuthHalfWidth2))
    children.append(targetsComponent(width, width, b_ScopeCircleTargetFunc))
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

local function createTargetOnScreen(id, width) {
  local function radarTgtsSpd(){
    local spd = radarState.screenTargets?[id]?.speed
    return {
      text = (spd != null) ? ("Vr = " + spd + ::loc("measureUnits/metersPerSecond_climbSpeed")) : ""
      opacity = radarState.selectedTargetSpeedBlinking ? (math.round(radarState.currentTime * 4) % 2 == 0 ? 1.0 : 0.42) : 1.0
    }
  }

  local function radarTgtsDist(){
    local dist = radarState.screenTargets?[id]?.dist
    return {text = (dist != null) ? ("D = " + dist + ::loc("measureUnits/meters_alt")) : ""}
  }

  return @() {
    size = [width, width]
    behavior = Behaviors.RtPropUpdate
    update = function() {
      local tgt = radarState.screenTargets?[id]
      return {
        opacity = radarState.selectedTargetBlinking ? getBlinkOpacity() : 1.0
        transform = {
          translate = [
            (tgt?.x ?? -100) - 0.5 * width,
            (tgt?.y ?? -100) - 0.5 * width
          ]
        }
      }
    }
    children = [
      @() {
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = hdpx(1) * 2.0
        color = greenColor
        size = [width, width]
        commands = [
          [VECTOR_LINE, 0, 0, 0, 100],
          [VECTOR_LINE, 0, 100, 100, 100],
          [VECTOR_LINE, 100, 100, 100, 0],
          [VECTOR_LINE, 100, 0, 0, 0],
        ]
      },
      style.lineForeground.__merge({
        rendObj = ROBJ_DTEXT
        size = [width * 4, SIZE_TO_CONTENT]
        behavior = Behaviors.RtPropUpdate
        pos = [width + hdpx(3), 0]
        fontScale = getFontScale() * 0.8
        fontFxFactor = 5
        update = radarTgtsDist
      }),
      style.lineForeground.__merge({
        rendObj = ROBJ_DTEXT
        size = [width * 4, SIZE_TO_CONTENT]
        behavior = Behaviors.RtPropUpdate
        pos = [width + hdpx(3), hdpx(18)]
        fontScale = getFontScale() * 0.8
        fontFxFactor = 5
        update = radarTgtsSpd
      })
    ]
  }
}


local forestallRadius = hdpx(10)
local targetOnScreenWidth = hdpx(30)


local targetsOnScreenComponent = function() {
  local getTargets = function() {
    if (!radarState.screenTargets)
      return null

    local targets = []
    foreach (id, target in radarState.screenTargets)
    {
      if (!target)
        continue
      targets.append(createTargetOnScreen(id, targetOnScreenWidth))
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
  local getChildren = function() {
    return radarState.IsForestallVisible.value
      ? @() {
          rendObj = ROBJ_VECTOR_CANVAS
          size = [2 * forestallRadius, 2 * forestallRadius]
          lineWidth = hdpx(1) * LINE_WIDTH
          color = greenColor
          fillColor = Color(0, 0, 0, 0)
          commands = [
            [VECTOR_ELLIPSE, 50, 50, 50, 50]
          ]
          behavior = Behaviors.RtPropUpdate
          update = @() {
            opacity = radarState.selectedTargetBlinking ? getBlinkOpacity() : 1.0
            transform = {
              translate = [radarState.forestall.x - forestallRadius, radarState.forestall.y - forestallRadius]
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


local getForestallTargetLineCoords = function() {
  local p1 = {
    x = radarState.forestall.x
    y = radarState.forestall.y
  }
  local p2 = {
    x = radarState.selectedTarget.x
    y = radarState.selectedTarget.y
  }

  local resPoint1 = {
    x = 0
    y = 0
  }
  local resPoint2 = {
    x = 0
    y = 0
  }

  local dx = p1.x - p2.x
  local dy = p1.y - p2.y
  local absDx = math.fabs(dx)
  local absDy = math.fabs(dy)

  if (absDy >= absDx)
  {
    resPoint2.x = p2.x
    resPoint2.y = p2.y + (dy > 0 ? 0.5 : -0.5) * targetOnScreenWidth
  }
  else
  {
    resPoint2.y = p2.y
    resPoint2.x = p2.x + (dx > 0 ? 0.5 : -0.5) * targetOnScreenWidth
  }

  local vecDx = p1.x - resPoint2.x
  local vecDy = p1.y - resPoint2.y
  local vecLength = math.sqrt(vecDx * vecDx + vecDy * vecDy)
  local vecNorm = {
    x = vecLength > 0 ? vecDx / vecLength : 0
    y = vecLength > 0 ? vecDy / vecLength : 0
  }

  resPoint1.x = resPoint2.x + vecNorm.x * (vecLength - forestallRadius)
  resPoint1.y = resPoint2.y + vecNorm.y * (vecLength - forestallRadius)

  return [resPoint2, resPoint1]
}


local forestallTargetLine = function() {
  local w = sw(100)
  local h = sh(100)

  local getChildren = function() {
    return radarState.IsForestallVisible.value
      ? @() {
          rendObj = ROBJ_VECTOR_CANVAS
          size = [w, h]
          lineWidth = hdpx(1) * LINE_WIDTH
          color = greenColor
          opacity = 0.8
          behavior = Behaviors.RtPropUpdate
          update = function() {
            local resLine = getForestallTargetLineCoords()

            return {
              opacity = radarState.selectedTargetBlinking ? getBlinkOpacity() : 1.0
              commands = [
                [VECTOR_LINE, resLine[0].x * 100.0 / w, resLine[0].y * 100.0 / h, resLine[1].x * 100.0 / w, resLine[1].y * 100.0 / h]
              ]
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


local createAzimuthMark = function(width, height, is_selected, is_detected, is_enemy) {
  local frame = null

  if (is_selected || is_detected || !is_enemy)
  {
    local frameSizeW = width * 1.5
    local frameSizeH = height * 1.5
    local commands = []

    if (is_selected)
      commands.extend([
        [VECTOR_LINE, 0, 0, 100, 0],
        [VECTOR_LINE, 100, 0, 100, 100],
        [VECTOR_LINE, 100, 100, 0, 100],
        [VECTOR_LINE, 0, 100, 0, 0]
      ])
    else if (is_detected)
      commands.extend([
        [VECTOR_LINE, 100, 0, 100, 100],
        [VECTOR_LINE, 0, 100, 0, 0]
      ])

    if (!is_enemy)
    {
      local yOffset = is_selected ? 110 : 95
      local xOffset = is_selected ? 0 : 10
      commands.append([VECTOR_LINE, xOffset, yOffset, 100.0 - xOffset, yOffset])
    }

    frame = {
      size = [frameSizeW, frameSizeH]
      pos = [(width - frameSizeW) * 0.5, (height - frameSizeH) * 0.5 ]
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = hdpx(1) * 2.0
      color = greenColorGrid
      fillColor = Color(0, 0, 0, 0)
      commands = commands
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


local createAzimuthMarkWithOffset = function(id, width, height, total_width, angle, is_selected, is_detected, is_enemy, isSecondRound) {
  local offset = (isSecondRound ? total_width : 0) +
    total_width * angle / 360.0 + 0.5 * width

  local animTrigger = "fadeMarker" + id + (is_selected ? "_1" : "_0")

  if (!is_selected)
    ::anim_start(animTrigger)

  return @() {
    size = SIZE_TO_CONTENT
    pos = [offset, 0]
    children = createAzimuthMark(width, height, is_selected, is_detected, is_enemy)
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
      if (!azimuthMarker)
        continue

      markers.append(createAzimuthMarkWithOffset(id, markerWidth, height, total_width,
        azimuthMarker.azimuthWorldDeg, azimuthMarker.isSelected, azimuthMarker.isDetected, azimuthMarker.isEnemy, false))
      markers.append(createAzimuthMarkWithOffset(id, markerWidth, height, total_width,
        azimuthMarker.azimuthWorldDeg, azimuthMarker.isSelected, azimuthMarker.isDetected, azimuthMarker.isEnemy, true))
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


local radar = function(posX, posY){
  return {
    pos = [screenState.safeAreaSizeHud.value.borders[1] + posX, posY]  //sh(8), sh(32)]
    size = SIZE_TO_CONTENT
    children = function(){
      local width = sh(28)

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
        watch = [radarState.ViewMode, radarState.AzimuthMax, radarState.AzimuthMin]
        children = [ scopeChild ]
      }
    }
  }
}


local Root = function(radarPosX = sh(8), radarPosY = sh(32)) {
  local getChildren = function() {
    return radarState.IsRadarHudVisible.value ?
      [
        targetsOnScreenComponent()
        forestallComponent()
        forestallTargetLine()
        radar(radarPosX, radarPosY)
        compassComponent
        azimuthMarkStrike
      ]
      : null
  }

  return @(){
    halign = HALIGN_LEFT
    valign = VALIGN_TOP
    size = [sw(100), sh(100)]
    watch = radarState.IsRadarHudVisible
    children = getChildren()
  }
}


return Root
