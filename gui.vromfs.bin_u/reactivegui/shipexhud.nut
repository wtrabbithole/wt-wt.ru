local networkState = require("networkState.nut")
local activeOrder = require("activeOrder.nut")
local shipStateModule = require("shipStateModule.nut")
local hudLogs = require("hudLogs.nut")
local shipState = require("shipState.nut")
local shellState = require("shellState.nut")
local voiceChat = require("chat/voiceChat.nut")
local screenState = require("style/screenState.nut")

local style = {}

local getDepthColor = function(depth){
  local green = depth < 2 ? 255 : 0
  local blue =  depth < 1 ? 255 : 0
  return Color(255, green, blue, 255)
}

style.lineBackground <- class {
  color = Color(255, 255, 255, 255)
  fillColor = Color(0, 0, 0, 0)
  opacity = 0.5
  lineWidth = LINE_WIDTH + 1
}

style.shipHudText <- class {
  color = Color(255, 255, 255, 255)
  font = Fonts.medium_text_hud
  fontFxColor = Color(0, 0, 0, 80)
  fontFxFactor = 16
  fontFx = FFT_GLOW
}

local verticalSpeedInd = function(line_style, height, c) {
  return class extends line_style {
    rendObj = ROBJ_VECTOR_CANVAS
    size = [height, height]
    pos = [0, -height*0.5]
    color = c
    commands = [
      [VECTOR_LINE, 0, 0, 100, 50, 0, 100, 0, 0],
    ]
  }
}

local verticalSpeedScale = function(line_style, width, height, c) {
  return class extends line_style {
    rendObj = ROBJ_VECTOR_CANVAS
    size = [width, height]
    halign = HALIGN_RIGHT
    color = c
    commands = [
      [VECTOR_LINE, 0, 0, 100, 0],
      [VECTOR_LINE, 0, 12.5, 50, 12.5],
      [VECTOR_LINE, 0, 25, 50, 25],
      [VECTOR_LINE, 0, 37.5, 50, 37.5],
      [VECTOR_LINE, 0, 50, 100, 50],
      [VECTOR_LINE, 0, 62.5, 50, 62.5],
      [VECTOR_LINE, 0, 75, 50, 75],
      [VECTOR_LINE, 0, 87.5, 50, 87.5],
      [VECTOR_LINE, 0, 100, 100, 100],
    ]
  }
}

local ShipVertSpeed = function(elemStyle) {
  local scaleWidth = sh(1)
  local height = sh(20)

  return @() {
    watch = shellState.isAimCamera
    isHidden = shellState.isAimCamera.value
    valign = VALIGN_MIDDLE
    flow = FLOW_HORIZONTAL
    gap = hdpx(15)
    children = [
      @(){
        watch = shipState.depthLevel
        children = class extends style.shipHudText {
          rendObj = ROBJ_DTEXT
          behavior = Behaviors.RtPropUpdate
          color = getDepthColor(shipState.depthLevel.value)
          halign = HALIGN_RIGHT
          update = @() {
            isHidden = false
            text = ::math.floor(shipState.waterDist.value).tostring()
          }
        }
      }
      @(){
        size = [scaleWidth*3, scaleWidth]
        children = []
      }
      @(){
        children = [
          @(){
            watch = shipState.depthLevel
            children = verticalSpeedScale(elemStyle, scaleWidth, height, getDepthColor(shipState.depthLevel.value))
          }
          @(){
            behavior = Behaviors.RtPropUpdate
            pos = [-scaleWidth, 0]
            update = @() {
              transform = {
                translate = [0, height * 0.01 * clamp(50 - shipState.buoyancyEx.value * 50.0, 0, 100)]
              }
            }
            watch = shipState.depthLevel
            children = verticalSpeedInd(elemStyle, sh(1.), getDepthColor(shipState.depthLevel.value))
          }
        ]
      }
      @(){
        watch = shipState.depthLevel
        children = class extends style.shipHudText {
          rendObj = ROBJ_DTEXT
          behavior = Behaviors.RtPropUpdate
          color = getDepthColor(shipState.depthLevel.value)
          halign = HALIGN_LEFT
          update = @() {
            isHidden = false
            text = ::math.floor(::max(shipState.wishDist.value, 0)).tostring()
          }
        }
      }
    ]
  }
}

local ShipShellState = @() {
  watch = shellState.isAimCamera
  flow = FLOW_VERTICAL
  isHidden = !shellState.isAimCamera.value
  children = [
    @() {
      watch = shellState.altitude
      children =
        class extends style.shipHudText {
          rendObj = ROBJ_DTEXT
          text = ::loc("hud/depth") + " "
              + ::cross_call.measureTypes.DISTANCE_SHORT.getMeasureUnitsText(max(0, -shellState.altitude.value), false)
        }
    }
    @() {
      watch = shellState.remainingDist
      children =
        class extends style.shipHudText {
          rendObj = ROBJ_DTEXT
          text = shellState.remainingDist.value <= 0.0 ? "" :
            ::cross_call.measureTypes.DISTANCE_SHORT.getMeasureUnitsText(shellState.remainingDist.value)
        }
    }
    @() {
      watch = shellState.isOperated
      children =
        class extends style.shipHudText {
          rendObj = ROBJ_DTEXT
          text = ::loc(shellState.isOperated.value ? "hud/shell_operated" : "hud/shell_homing")
        }
    }
    @() {
      watch = shellState.isActiveSensor
      children =
        class extends style.shipHudText {
          rendObj = ROBJ_DTEXT
          text = ::loc(shellState.isActiveSensor.value ? "activeSonar" : "passiveSonar")
        }
    }
  ]
}

local shipHud = @(){
  watch = networkState.isMultiplayer
  size = [SIZE_TO_CONTENT, flex()]
  margin = screenState.safeAreaSizeHud.value.borders
  flow = FLOW_VERTICAL
  valign = VALIGN_BOTTOM
  halign = HALIGN_LEFT
  gap = sh(1)
  children = [
    voiceChat
    activeOrder
    networkState.isMultiplayer.value ? hudLogs : null
    shipStateModule
  ]
}

local sensorsHud = @() {
  pos = [sw(60), 0]
  size = flex()
  valign = VALIGN_MIDDLE
  children = [
    ShipVertSpeed(style.lineBackground)
    ShipShellState
  ]
}

return {
  size = flex()
  children = [
    shipHud
    sensorsHud
  ]
}