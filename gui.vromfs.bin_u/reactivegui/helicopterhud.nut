local math = require("std/math.nut")
local screenState = require("style/screenState.nut")
local rwr = require("rwr.nut")
local mlws = require("mlws.nut")
local radarComponent = require("radarComponent.nut")
local helicopterState = require("helicopterState.nut")
local aamAim = require("rocketAamAim.nut")
local hudElems = require("helicopterHudElems.nut")

local compassWidth = hdpx(420)
local compassHeight = hdpx(40)

local style = {}

local backgroundColor = Color(0, 0, 0, 150)
local fontOutlineColor = Color(0, 0, 0, 235)

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
  fillColor = Color(0, 0, 0, 0)
  lineWidth = hdpx(1) * LINE_WIDTH
  font = Fonts.hud
  fontFxColor = fontOutlineColor
  fontFxFactor = 40
  fontFx = FFT_GLOW
  fontScale = getFontScale()
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

    local allCannonsEmpty = helicopterState.IsCannonEmpty.reduce(@(res, val) res && val.value, true)

    for (local i = 0; i < commands.len(); ++i)
    {
      if (i >= helicopterState.GunOverheatState.value)
      {
        mainCommands.append(commands[i])
        if (!allCannonsEmpty || !helicopterState.IsMachineGunEmpty.value)
          mainCommands.append(commandsDash[i])
      }
      else
      {
        overheatCommands.append(commands[i])
        if (!allCannonsEmpty || !helicopterState.IsMachineGunEmpty.value)
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

  local watchList = [
    helicopterState.IsMachineGunEmpty,
    helicopterState.GunOverheatState,
    helicopterState.GunDirectionX,
    helicopterState.GunDirectionY,
    helicopterState.GunDirectionVisible
  ]
  watchList.extend(helicopterState.IsCannonEmpty)

  return @() {
    size = SIZE_TO_CONTENT
    halign = HALIGN_CENTER
    valign = VALIGN_MIDDLE
    watch = watchList
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

local paramsTableWidth = hdpx(450)
local paramsSightTableWidth = hdpx(270)

local helicopterParamsTable = hudElems.paramsTable(helicopterState.MainMask,
  paramsTableWidth,
  [max(screenState.safeAreaSizeHud.value.borders[1], sw(50) - hdpx(660)), sh(50) - hdpx(100)],
  hdpx(5))

local helicopterSightParamsTable = hudElems.paramsTable(helicopterState.SightMask,
  paramsSightTableWidth,
  [sw(50) - hdpx(250) - hdpx(200), hdpx(480)],
  hdpx(3))

local agmTrackZone = function(line_style, width, height, isBackground) {
  return @() line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, height]
    opacity = helicopterState.AtgmTrackerRadius.value > 0.0 ? 100 : 0
    color = getColor(isBackground)
    lineWidth = hdpx(LINE_WIDTH)
    watch = [helicopterState.IsAgmEmpty, helicopterState.IsATGMOutOfTrackerSector, helicopterState.AtgmTrackerRadius]
    commands = !helicopterState.IsAgmEmpty.value && helicopterState.IsATGMOutOfTrackerSector.value ?
    [
      [ VECTOR_ELLIPSE, 50, 50,
        helicopterState.AtgmTrackerRadius.value / width * 100,
        helicopterState.AtgmTrackerRadius.value / height * 100 ]
    ] : []
  })
}

local agmTrackZoneComponent = function(elemStyle, isBackground) {
  local width = sw(100)
  local height = sh(100)

  return @() {
    pos = [sw(50) - width * 0.5, sh(50) - height * 0.5]
    size = SIZE_TO_CONTENT
    behavior = Behaviors.RtPropUpdate
    update = function() {
      return {
        opacity = math.round(helicopterState.CurrentTime.value * 4) % 2 == 0 ? 100 : 0
      }
    }
    children = agmTrackZone(elemStyle, width, height, isBackground)
  }
}

local laserDesignator = function(line_style, width, height, isBackground) {
  local lhl = 5
  local lvl = 7

  return @() line_style.__merge({
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, height]
    watch = helicopterState.IsAgmEmpty
    color = !isBackground && helicopterState.IsAgmEmpty.value ? helicopterState.AlertColor.value : getColor(isBackground)
    commands = [
      [VECTOR_LINE, 50 - lhl, 50 - lvl, 50 + lhl, 50 - lvl],
      [VECTOR_LINE, 50 - lhl, 50 + lvl, 50 + lhl, 50 + lvl],
      [VECTOR_LINE, 50 - lhl, 50 - lvl, 50 - lhl, 50 + lvl],
      [VECTOR_LINE, 50 + lhl, 50 - lvl, 50 + lhl, 50 + lvl],
    ]
  })
}

local laserDesignatorComponent = function(elemStyle, isBackground) {
  local width = hdpx(150)
  local height = hdpx(100)

  return @() {
    pos = [sw(50) - width * 0.5, sh(50) - height * 0.5]
    watch = helicopterState.IsLaserDesignatorEnabled
    opacity = helicopterState.IsLaserDesignatorEnabled.value ? 100 : 0
    size = SIZE_TO_CONTENT
    children = laserDesignator(elemStyle, width, height, isBackground)
  }
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
    pos = [sw(50), sh(38)]
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
    color = getColor(isBackground)
    behavior = Behaviors.RtPropUpdate
    update = function() {
      return {
        text = helicopterState.IsATGMOutOfTrackerSector.value ? ::loc("HUD/TXT_ATGM_OUT_OF_TRACKER_SECTOR") : ::loc("HUD/TXT_NO_LOS_ATGM")
        opacity = (helicopterState.IsATGMOutOfTrackerSector.value || helicopterState.NoLosToATGM.value) &&
                  (math.round(helicopterState.CurrentTime.value * 4) % 2 == 0) ? 100 : 0
      }
    }
  })

  local resCompoment = @() {
    pos = [sw(50), sh(41)]
    halign = HALIGN_CENTER
    size = [0, 0]
    children = atgmTrackerStatus
  }

  return resCompoment
}


local function helicopterMainHud(elemStyle, isBackground) {
  local azimuth = !radarComponent.state.IsRadarHudVisible.value ?
   hudElems.compassElem(elemStyle, isBackground, compassWidth, compassHeight, sw(50) - 0.5*compassWidth, sh(15)) : null
  return @(){
    watch = helicopterState.IsMainHudVisible
    children = helicopterState.IsMainHudVisible.value
    ? [
      hudElems.rocketAim(elemStyle, sh(0.8), sh(1.8), isBackground)
      aamAim(elemStyle, @() getColor(isBackground))
      HelicopterGunDirection(elemStyle, isBackground)
      HelicopterFixedGunsDirection(elemStyle, isBackground)
      hudElems.vertSpeed(elemStyle, sh(4.0), sh(15), sw(50) + hdpx(384), sh(42.5), isBackground)
      hudElems.horSpeed(elemStyle, isBackground)
      helicopterParamsTable(elemStyle, isBackground)
      azimuth
      hudElems.taTarget(elemStyle, sw(25), sh(25), isBackground)
    ]
    : null
  }
}

local function helicopterSightHud(elemStyle, isBackground) {
  local azimuth = !radarComponent.state.IsRadarHudVisible.value ?
   hudElems.compassElem(elemStyle, isBackground, compassWidth, compassHeight, sw(50) - 0.5*compassWidth, sh(15)) : null
  return @(){
    watch = helicopterState.IsSightHudVisible
    pos = [0, 0]
    children = helicopterState.IsSightHudVisible.value ?
    [
      hudElems.vertSpeed(elemStyle, sh(4.0), sh(30), sw(50) + hdpx(384), sh(35), isBackground)
      hudElems.turretAngles(elemStyle, hdpx(150), sw(50), sh(90), isBackground)
      hudElems.launchDistanceMax(elemStyle, hdpx(150), sw(50), sh(90), isBackground)
      helicopterSightParamsTable(elemStyle, isBackground)
      hudElems.lockSight(elemStyle, hdpx(150), hdpx(100), sw(50), sh(50), isBackground)
      hudElems.targetSize(elemStyle, sw(100), sh(100), isBackground)
      agmTrackZoneComponent(elemStyle, isBackground)
      laserDesignatorComponent(elemStyle, isBackground)
      hudElems.sight(elemStyle, sw(50), sh(50), hdpx(500), isBackground)
      hudElems.rangeFinder(elemStyle, sw(50), sh(59), isBackground)
      laserDesignatorStatusComponent(elemStyle, isBackground)
      atgmTrackerStatusComponent(elemStyle, isBackground)
      azimuth
    ]
    : null
  }
}


local function gunnerHud(elemStyle, isBackground) {
  return @(){
    watch = helicopterState.IsGunnerHudVisible
    children = helicopterState.IsGunnerHudVisible.value
    ? [
      hudElems.rocketAim(elemStyle, sh(0.8), sh(1.8), isBackground)
      aamAim(elemStyle, @() getColor(isBackground))
      HelicopterGunDirection(elemStyle, isBackground)
      HelicopterFixedGunsDirection(elemStyle, isBackground)
      hudElems.vertSpeed(elemStyle, sh(4.0), sh(15), sw(50) + hdpx(384), sh(42.5), isBackground)
      helicopterParamsTable(elemStyle, isBackground)
    ]
    : null
  }
}


local function pilotHud(elemStyle, isBackground) {
  return @(){
    watch = helicopterState.IsPilotHudVisible
    pos = [0, 0]
    children = helicopterState.IsPilotHudVisible.value ?
    [
      hudElems.vertSpeed(elemStyle, sh(4.0), sh(15), sw(50) + hdpx(384), sh(42.5), isBackground)
      helicopterParamsTable(elemStyle, isBackground)
    ]
    : null
  }
}

local function helicopterHUDs(colorStyle, isBackground) {
  local rwrStyle = colorStyle.__merge({
    color = getColor(isBackground)
  })
  local radar = !helicopterState.IsMfdEnabled.value ? radarComponent.radar(false, sh(6), sh(6), getColor(isBackground)) : null
  return [
    helicopterMainHud(colorStyle, isBackground)
    helicopterSightHud(colorStyle, isBackground)
    gunnerHud(colorStyle, isBackground)
    pilotHud(colorStyle, isBackground)
    mlws(rwrStyle)
    rwr(rwrStyle)
    radar
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
