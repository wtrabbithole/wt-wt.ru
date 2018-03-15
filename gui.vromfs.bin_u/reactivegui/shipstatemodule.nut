local shipState = require("shipState.nut")
local crewState = require("crewState.nut")
local dmModule = require("dmModule.nut")
local colors = require("style/colors.nut")
local setHudBg = require("style/hudBackground.nut")

local mathEx = require("std/math.nut")

const STATE_ICON_MARGIN = 1
const STATE_ICON_SIZE = 54

const max_dost = 5

local machineDirectionLoc = [
  ::loc("HUD/ENGINE_REV_BACK_SHORT")
  ::loc("HUD/ENGINE_REV_BACK_SHORT")
  ::loc("HUD/ENGINE_REV_BACK_SHORT")
  ""
  ::loc("HUD/ENGINE_REV_AHEAD_SHORT")
  ::loc("HUD/ENGINE_REV_AHEAD_SHORT")
  ::loc("HUD/ENGINE_REV_AHEAD_SHORT")
  ::loc("HUD/ENGINE_REV_AHEAD_SHORT")
  ::loc("HUD/ENGINE_REV_AHEAD_SHORT")
]

local machineSpeedLoc = [
  ::loc("HUD/ENGINE_REV_FULL_SHORT")
  ::loc("HUD/ENGINE_REV_TWO_THIRDS_SHORT")
  ::loc("HUD/ENGINE_REV_ONE_THIRD_SHORT")
  ::loc("HUD/ENGINE_REV_STOP_SHORT")
  ::loc("HUD/ENGINE_REV_ONE_THIRD_SHORT")
  ::loc("HUD/ENGINE_REV_TWO_THIRDS_SHORT")
  ::loc("HUD/ENGINE_REV_STANDARD_SHORT")
  ::loc("HUD/ENGINE_REV_FULL_SHORT")
  ::loc("HUD/ENGINE_REV_FLANK_SHORT")
]

local images = {
  engine = Picture("!ui/gameuiskin#engine_state_indicator")
  transmission = Picture("!ui/gameuiskin#ship_transmission_state_indicator")
  steeringGear = Picture("!ui/gameuiskin#ship_steering_gear_state_indicator")
  artillery = Picture("!ui/gameuiskin#artillery_weapon_state_indicator")
  artillerySecondary = Picture("!ui/gameuiskin#artillery_secondary_weapon_state_indicator")
  machineGun = Picture("!ui/gameuiskin#machine_gun_weapon_state_indicator")
  torpedo = Picture("!ui/gameuiskin#ship_torpedo_weapon_state_indicator")
  buoyancy = Picture("!ui/gameuiskin#buoyancy_icon")
  fire = Picture("!ui/gameuiskin#fire_indicator")
  steeringMark = Picture("!ui/gameuiskin#floatage_arrow_down")
  sightCone = Picture("+ui/gameuiskin#map_camera")
  shipCrew = Picture("!ui/gameuiskin#ship_crew")
  gunner = Picture("!ui/gameuiskin#ship_crew_gunner")
  driver = Picture("!ui/gameuiskin#ship_crew_driver")

  bg = Picture("!ui/gameuiskin#debriefing_bg_grad@@ss")

  gunnerState = [ //according to AI_GUNNERS_ enum
    Picture("!ui/gameuiskin#ship_gunner_state_hold_fire")
    Picture("!ui/gameuiskin#ship_gunner_state_fire_at_will")
    Picture("!ui/gameuiskin#ship_gunner_state_air_targets")
    Picture("!ui/gameuiskin#ship_gunner_state_naval_targets")
  ]
}


local fontFxColor = Color(80, 80, 80)
local fontFx = FFT_GLOW
local font = Fonts.tiny_text_hud

local speed = function () {
  local speedValue = @() {
    watch = shipState.speed
    rendObj = ROBJ_TEXT
    text = shipState.speed.value.tostring()
    font = Fonts.tiny_text_hud
    margin = [0,0,0,sh(1)]
  }

  local speedUnits = @() {
    rendObj = ROBJ_STEXT
    font = font
    fontSize = hdpx(13)
    fontFitIntoBox = [hdpx(40), hdpx(13)]
    text = ::cross_call.measureTypes.SPEED.getMeasureUnitsName()
    margin = [0,0,0,sh(0.5)]
  }

  local machine = function (port, sideboard, stopping) {
    return function () {
      local averageSpeed = clamp((port.value + sideboard.value) / 2, 0, machineSpeedLoc.len())
      return {
        size = SIZE_TO_CONTENT
        watch = [port, sideboard, stopping]
        children = {
          rendObj = ROBJ_STEXT
          font = font
          color = stopping.value ? Color(255, 100, 100) : Color(200, 200, 200)
          fontSize = hdpx(13)
          fontFitIntoBox = [hdpx(200), hdpx(13)]
          text = machineSpeedLoc[averageSpeed] + " " + machineDirectionLoc[averageSpeed]
        }
      }
    }
  }

  return {
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    hplace = HALIGN_CENTER
    halign = HALIGN_RIGHT
    valign = VALIGN_MIDDLE

    children = [
      {
        size = [flex(4), SIZE_TO_CONTENT]
        children = [machine(shipState.portSideMachine, shipState.sideboardSideMachine, shipState.stopping)]
        halign = HALIGN_RIGHT
      }
      {
        size = [flex(1.8), SIZE_TO_CONTENT]
        flow = FLOW_HORIZONTAL
        valign = VALIGN_BOTTOM

        children = [
          speedValue
          speedUnits
        ]
      }
    ]
  }
}


local engine = dmModule({
  icon = images.engine
  iconSize = [hdpx(STATE_ICON_SIZE), hdpx(STATE_ICON_SIZE)]
  totalCountState = shipState.enginesCount
  brokenCountState = shipState.brokenEnginesCount
})

local transmission = dmModule({
  icon = images.transmission
  iconSize = [hdpx(STATE_ICON_SIZE), hdpx(STATE_ICON_SIZE)]
  totalCountState = shipState.transmissionCount
  brokenCountState = shipState.brokenTransmissionCount
})
local torpedo = dmModule({
  icon = images.torpedo
  iconSize = [hdpx(STATE_ICON_SIZE), hdpx(STATE_ICON_SIZE)]
  totalCountState = shipState.torpedosCount
  brokenCountState = shipState.brokenTorpedosCount
})
local artillery = dmModule({
  icon = @(art_type) art_type == TRIGGER_GROUP_PRIMARY     ? images.artillery
                   : art_type == TRIGGER_GROUP_SECONDARY   ? images.artillerySecondary
                   : art_type == TRIGGER_GROUP_MACHINE_GUN ? images.machineGun
                   : images.artillery
  iconWatch = shipState.artilleryType
  iconSize = [hdpx(STATE_ICON_SIZE), hdpx(STATE_ICON_SIZE)]
  totalCountState = shipState.artilleryCount
  brokenCountState = shipState.brokenArtilleryCount
})
local steeringGears = dmModule({
  icon = images.steeringGear
  iconSize = [hdpx(30), hdpx(30)]
  totalCountState = shipState.steeringGearsCount
  brokenCountState = shipState.brokenSteeringGearsCount
})


local damageModules = {
  size = SIZE_TO_CONTENT
  flow = FLOW_VERTICAL
  gap = sh(STATE_ICON_MARGIN)
  children = [
    engine
    transmission
    torpedo
    artillery
  ]
}

local buoyancyIndicator = @() {
  size = SIZE_TO_CONTENT
  flow = FLOW_VERTICAL
  halign = HALIGN_CENTER
  children = [
    @() {
      rendObj = ROBJ_TEXT
      text = (shipState.buoyancy.value * 100).tointeger() + "%"
      font = Fonts.small_text_hud
      watch = shipState.buoyancy
    }
    {
      rendObj = ROBJ_IMAGE
      image = images.buoyancy
      size = [hdpx(STATE_ICON_SIZE), hdpx(10)]
    }
  ]
}

local stateBlock = {
  size = SIZE_TO_CONTENT
  flow = FLOW_VERTICAL
  children = [
    @() {
      rendObj = ROBJ_IMAGE
      color =  shipState.fire.value ? colors.hud.damageModule.alert : colors.hud.damageModule.inactive
      watch = shipState.fire
      image = images.fire
      size = [hdpx(STATE_ICON_SIZE), hdpx(STATE_ICON_SIZE)]
    }
    buoyancyIndicator
  ]
}


local playAiSwithAnimation = function (ne_value) {
  ::start_anim(shipState.aiGunnersState)
}

local aiGunners = @() {
  vplace = VALIGN_BOTTOM
  size = [hdpx(STATE_ICON_SIZE), hdpx(STATE_ICON_SIZE)]
  marigin = [hdpx(STATE_ICON_MARGIN), 0]

  rendObj = ROBJ_IMAGE
  image = images.gunnerState.__get(shipState.aiGunnersState.value, images.gunnerState[0])
  color = colors.hud.damageModule.active
  watch = shipState.aiGunnersState
  onAttach = @(elem) shipState.aiGunnersState.subscribe(playAiSwithAnimation)
  onDetach = @(elem) shipState.aiGunnersState.unsubscribe(playAiSwithAnimation)
  transform = {}
  animations = [
    {
      prop = AnimProp.color
      from = colors.hud.damageModule.aiSwitchHighlight
      easing = Linear
      duration = 0.15
      trigger = shipState.aiGunnersState
    }
    {
      prop = AnimProp.scale
      from = [1.5, 1.5]
      easing = InOutCubic
      duration = 0.2
      trigger = shipState.aiGunnersState
    }
  ]
}


local crewCountColor = function(min, current) {
  if (current < min) {
    return colors.hud.damageModule.dmModuleDestroyed
  } else if (current < min * 1.1) {
    return colors.hud.damageModule.dmModuleDamaged
  }
  return colors.hud.damageModule.active
}


local countCrewLeftPercent = @() mathEx.clamp(mathEx.lerp(crewState.minCrewMembersCount.value - 1,
  crewState.totalCrewMembersCount.value, 0, 100, crewState.aliveCrewMembersCount.value), 0, 100)


local crewBlock = {
  vplace = VALIGN_BOTTOM
  flow = FLOW_VERTICAL
  size = [hdpx(STATE_ICON_SIZE), SIZE_TO_CONTENT]
  vplace = VALIGN_BOTTOM

  children = [
    @() {
      size = [hdpx(STATE_ICON_SIZE), hdpx(STATE_ICON_SIZE)]
      marigin = [hdpx(STATE_ICON_MARGIN), 0]
      rendObj = ROBJ_IMAGE
      image = images.driver
      color = crewState.driverAlive.value ? colors.hud.damageModule.inactive : colors.hud.damageModule.alert
      watch = crewState.driverAlive
    }
    @() {
      size = [hdpx(STATE_ICON_SIZE), hdpx(STATE_ICON_SIZE)]
      marigin = [hdpx(STATE_ICON_MARGIN), 0]
      rendObj = ROBJ_IMAGE
      image = images.shipCrew
      color = crewCountColor(
        crewState.minCrewMembersCount.value,
        crewState.aliveCrewMembersCount.value
      )
      watch = [
        crewState.aliveCrewMembersCount
        crewState.minCrewMembersCount
      ]
      children = {
        vplace = VALIGN_BOTTOM
        hplace = HALIGN_RIGHT
        rendObj = ROBJ_TEXT
        text = countCrewLeftPercent() + "%"
        font = Fonts.tiny_text_hud
        fontFx = fontFx
        fontFxColor = fontFxColor
      }
    }
  ]
}


local steering = function () {
  local mark = @(p) {
    rendObj = ROBJ_IMAGE
    image = images.steeringMark
    color = colors.hud.shipSteeringGauge.mark
    size = [hdpx(12), hdpx(10)]
    pos = @() [p * pw(100) - w(100)/2 + 1, -h(100)/2]
  }

  local line = {
    size = [hdpx(1), flex()]
    rendObj = ROBJ_SOLID
    color = colors.hud.shipSteeringGauge.serif
  }
  local space = {
    size = flex()
  }
  return {
    watch = shipState.steering
    size = [pw(50), hdpx(3)]
    hplace = HALIGN_CENTER

    children = [
      {
        size = flex()
        rendObj = ROBJ_SOLID
        color = colors.hud.shipSteeringGauge.background
        flow = FLOW_HORIZONTAL
        gap = space
        valign = VALIGN_BOTTOM
        children = [
          line
          line
          line
          line
          line
        ]

      }
      mark((-shipState.steering.value)/2 + 0.5)
    ]
  }
}


local fov = function (pivot) {
  return @() {
    watch = [
      shipState.fwdAngle
      shipState.sightAngle
      shipState.fov
    ]
    pos = @() [pivot[0] - w(50), pivot[1] - h(50)]
    size = [sh(30), sh(30)]
    transform = {
      pivot = [0.5, 0.5]
      rotate = shipState.sightAngle.value - shipState.fwdAngle.value
      scale = [::math.sin(shipState.fov.value), 1.0]
    }
    children = [
      {    
        size = [flex(),flex()]
        rendObj = ROBJ_IMAGE
        image = images.sightCone
        color = Color(155, 255, 0, 120)
      }
      {
        size = [flex(),flex()]
        rendObj = ROBJ_IMAGE
        image = images.sightCone
        color = Color(155, 255, 0)
      }
    ]
  }
}


local doll = {
  color = Color(0, 255, 0)
  size = [sh(16), sh(32)]
  rendObj = ROBJ_XRAYDOLL
  rotateWithCamera = false

  children = fov([sh(12)/2, sh(30+4)/2])
}


local leftBlock = damageModules

local rightBlock = @() {
  size = [SIZE_TO_CONTENT, flex()]
  flow = FLOW_VERTICAL
  children = [
    stateBlock
    { size = [SIZE_TO_CONTENT, flex()] }
    shipState.hasAiGunners.value ? aiGunners : null
    crewBlock
  ]
  watch = shipState.hasAiGunners
}


local shipStateDisplay = {
  size = SIZE_TO_CONTENT
  flow = FLOW_VERTICAL
  halign = HALIGN_CENTER
  children = [
    {
      flow = FLOW_HORIZONTAL
      size = SIZE_TO_CONTENT
      children = [
        leftBlock
        doll
        rightBlock
      ]
    }
    steeringGears
    steering
  ]
}


return setHudBg({
  size = SIZE_TO_CONTENT
  flow = FLOW_VERTICAL
  padding = hdpx(10)
  gap = {size=[flex(),hdpx(5)]}
  children = [
    speed
    shipStateDisplay
  ]
})
