local shipState = require("shipState.nut")
local crewState = require("crewState.nut")
local colors = require("style/colors.nut")
local background = require("style/hudBackground.nut")

const STATE_ICON_MARGIN = 0.7
const STATE_ICON_SIZE = 5

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
  torpedo = Picture("!ui/gameuiskin#ship_torpedo_weapon_state_indicator")
  buoyancy = Picture("!ui/gameuiskin#buoyancy_icon")
  fire = Picture("!ui/gameuiskin#fire_indicator")
  dotHole = Picture("!ui/gameuiskin#dot_hole")
  dotFilled = Picture("!ui/gameuiskin#dot_filled")
  steeringMark = Picture("!ui/gameuiskin#drop_menu_icon")
  sightCone = Picture("+ui/hudskin#radar_camera")
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
local font = Fonts.small_text_hud

local speed = function () {
  local speedValue = @() {
    watch = shipState.speed
    rendObj = ROBJ_TEXT
    text = shipState.speed.value.tostring()
    font = font
    margin = [0,0,0,sh(1)]
  }

  local speedUnits = @() {
    rendObj = ROBJ_STEXT
    font = font
    fontSize = sh(18.0/1080*100)
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
          fontSize = sh(18.0/1080*100)
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
        size = [flex(3), SIZE_TO_CONTENT]
        children = [machine(shipState.portSideMachine, shipState.sideboardSideMachine, shipState.stopping)]
        halign = HALIGN_RIGHT
      }
      {
        size = [flex(2), SIZE_TO_CONTENT]
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


///
/// Return component represents state of group
/// of similar dm modules (engines, torpedos, etc.)
///
local dmModule = function (icon, count_total_state, count_broken_state) {
  return function () {
    if (count_total_state.value == 0) {
      return {
        watch = count_total_state
      }
    }

    local color = colors.hud.damageModule.dmModuleNormal
    if (count_total_state.value == count_broken_state.value)
      color = colors.hud.damageModule.dmModuleDestroyed
    else if (count_broken_state.value > 0)
      color = colors.hud.damageModule.dmModuleDamaged
    ::start_anim(count_broken_state)
    local image = {
      rendObj = ROBJ_IMAGE
      color =  color
      image = icon
      size = [sh(STATE_ICON_SIZE), sh(STATE_ICON_SIZE)]

      transform = {}
      animations = [
        {
          prop = AnimProp.color
          from = colors.hud.damageModule.alertHighlight
          easing = Linear
          duration = 0.15
          trigger = count_broken_state
        }
        {
          prop = AnimProp.scale
          from = [1.3, 1.3]
          easing = InOutCubic
          duration = 0.15
          trigger = count_broken_state
        }
      ]
    }

    local dotAlive = @(totalDotsCount) {
      rendObj = ROBJ_IMAGE
      image = images.dotFilled
      color = count_broken_state.value > 0 ? colors.hud.damageModule.active : colors.hud.damageModule.inactive
      size = [sh(1), sh(1)]
      margin = [sh(0.2), sh(0.2)]
    }
    local dotDead = @(totalDotsCount) {
      rendObj = ROBJ_IMAGE
      image = images.dotHole
      color = colors.hud.damageModule.dmModuleDestroyed
      size = [sh(1), sh(1)]
      margin = [sh(0.2), sh(0.2)]
      transform = {}
      animations = [
        {
          prop = AnimProp.scale
          from = [1.3, 1.3]
          easing = InOutCubic
          play = true
          duration = 0.25
        }
      ]
    }

    local dots = function () {
      local aliveCount = count_total_state.value - count_broken_state.value
      local children = []
      if (aliveCount > 0 && count_total_state.value > 0)
      {
        children.resize(aliveCount, dotAlive(count_total_state.value))
        children.resize(count_total_state.value, dotDead(count_total_state.value))
      }

      return {
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_HORIZONTAL
        halign = HALIGN_CENTER
        children = children
      }
    }


    local text = @() {
      rendObj = ROBJ_TEXT
      color = count_broken_state.value > 0 ? colors.hud.damageModule.active : colors.hud.damageModule.inactive
      halign = HALIGN_CENTER
      text = (count_total_state.value - count_broken_state.value) + "/" + count_total_state.value
    }

    local children = [image]
    if (count_total_state.value > 1) {
      if (count_total_state.value < max_dost) {
        children.append(dots)
      } else {
        children.append(text)
      }
    }

    return {
      size = SIZE_TO_CONTENT
      flow = FLOW_VERTICAL
      margin = [sh(STATE_ICON_MARGIN), 0]
      halign = HALIGN_CENTER
      watch = [
        count_total_state
        count_broken_state
      ]

      children = children
    }
  }
}

local engine = dmModule(images.engine, shipState.enginesCount, shipState.brokenEnginesCount)
local steeringGears = dmModule(images.steeringGear, shipState.steeringGearsCount, shipState.brokenSteeringGearsCount)
local transmission = dmModule(images.transmission, shipState.transmissionCount, shipState.brokenTransmissionCount)
local torpedo = dmModule(images.torpedo, shipState.torpedosCount, shipState.brokenTorpedosCount)
local artillery = dmModule(images.artillery, shipState.artilleryCount, shipState.brokenArtilleryCount)

local damageModules = {
  size = SIZE_TO_CONTENT
  flow = FLOW_VERTICAL
  children = [
    engine
    steeringGears
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
      size = [sh(STATE_ICON_SIZE), sh(1)]
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
      size = [sh(STATE_ICON_SIZE), sh(STATE_ICON_SIZE)]
    }
    buoyancyIndicator
  ]
}

local aiGunners = @() {
  vplace = VALIGN_BOTTOM
  size = [sh(STATE_ICON_SIZE), sh(STATE_ICON_SIZE)]
  marigin = [sh(STATE_ICON_MARGIN), 0]

  rendObj = ROBJ_IMAGE
  image = images.gunnerState.__get(shipState.aiGunnersState.value, images.gunnerState[0])
  color = colors.hud.damageModule.active
  watch = shipState.aiGunnersState
}


local crewCountColor = function(min, current) {
  if (current < min) {
    return colors.hud.damageModule.dmModuleDestroyed
  } else if (current < min * 1.1) {
    return colors.hud.damageModule.dmModuleDamaged
  }
  return colors.hud.damageModule.active
}

local crewBlock = {
  vplace = VALIGN_BOTTOM
  flow = FLOW_VERTICAL
  size = [sh(STATE_ICON_SIZE), SIZE_TO_CONTENT]
  vplace = VALIGN_BOTTOM

  children = [
    @() {
      size = [sh(STATE_ICON_SIZE), sh(STATE_ICON_SIZE)]
      marigin = [sh(STATE_ICON_MARGIN), 0]
      rendObj = ROBJ_IMAGE
      image = images.driver
      color = crewState.driverAlive.value ? colors.hud.damageModule.inactive : colors.hud.damageModule.alert
      watch = crewState.driverAlive
    }
    @() {
      size = [sh(STATE_ICON_SIZE), sh(STATE_ICON_SIZE)]
      marigin = [sh(STATE_ICON_MARGIN), 0]
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
        text = (100 * crewState.aliveCrewMembersCount.value / crewState.totalCrewMembersCount.value) + "%"
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
    size = [sh(1.4), sh(1)]
    pos = @() [p * pw(100) - w(100)/2 + 1, -h(100)/2]
  }

  local line = {
    size = [sh(0.1), sh(0.5)]
    rendObj = ROBJ_SOLID
    color = colors.hud.shipSteeringGauge.serif
  }
  local space = {
    size = flex()
  }
  return {
    watch = shipState.steering
    size = [pw(50), sh(0.3)]
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
  size = [sh(12), sh(30)]
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
    {size=[flex(),sh(0.7)]}
    steering
  ]
}


return {
  size = SIZE_TO_CONTENT
  flow = FLOW_VERTICAL
  padding = sh(1)
  children = [
    speed
    {size=[flex(),sh(0.5)]}
    shipStateDisplay
  ]
}.patchComponent(background)
