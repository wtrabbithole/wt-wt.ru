local shipState = require("shipState.nut")
local crewState = require("crewState.nut")

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
  dotHole = Picture("!ui/gameuiskin#wheeled_radar_target")
  dotFilled = Picture("!ui/gameuiskin#wheeled_radar")
  steeringMark = Picture("!ui/gameuiskin#drop_menu_icon")
  sightCone = Picture("+ui/gameuiskin#radar_camera")
  shipCrew = Picture("!ui/gameuiskin#ship_crew")
  gunner = Picture("!ui/gameuiskin#ship_crew_gunner")
  driver = Picture("!ui/gameuiskin#ship_crew_driver")

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
    rendObj = ROBJ_TEXT
    text = shipState.speed.value.tostring()
    font = font
    fontFx = fontFx
    fontFxColor = fontFxColor
    margin = [0,0,0,sh(2)]
  }

  local machine = function (port, sideboard) {
    local averegeSpeed = clamp((port + sideboard) / 2, 0, machineSpeedLoc.len())
    return {
      size = SIZE_TO_CONTENT
      children = {
        rendObj = ROBJ_TEXT
        font = font
        color = Color(200, 200, 200)
        fontFx = fontFx
        fontFxColor = fontFxColor
        text = machineSpeedLoc[averegeSpeed] + " " + machineDirectionLoc[averegeSpeed]
      }
    }
  }

  return {
    size = [flex(), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    hplace = HALIGN_CENTER
    halign = HALIGN_RIGHT
//    padding = [0, sh(3)]

    watch = [
      shipState.speed
      shipState.portSideMachine
      shipState.sideboardSideMachine
    ]

    children = [
      
      {size = [flex(3),SIZE_TO_CONTENT] children = machine(shipState.portSideMachine.value, shipState.sideboardSideMachine.value) halign=HALIGN_RIGHT}
      {size = [flex(2),SIZE_TO_CONTENT] children = speedValue}
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

    local color = Color(37, 46, 53, 80)
    if (count_total_state.value == count_broken_state.value)
      color = Color(221, 17, 17)
    else if (count_broken_state.value > 0)
      color = Color(255, 176, 37)
    local image = {
      rendObj = ROBJ_IMAGE
      color =  color
      image = icon
      size = [sh(STATE_ICON_SIZE), sh(STATE_ICON_SIZE)]
    }

    local dotAlive = @(totalDotsCount) {
      rendObj = ROBJ_IMAGE
      image = images.dotFilled
      color = count_broken_state.value > 0 ? Color(255, 255, 255) : Color(37, 46, 53, 80)
      size = [sh(1), sh(1)]
      margin = [sh(0.2), sh(0.2)]
    }
    local dotDead = @(totalDotsCount) {
      rendObj = ROBJ_IMAGE
      image = images.dotHole
      color = Color(255, 50, 0)
      size = [sh(1), sh(1)]
      margin = [sh(0.2), sh(0.2)]
    }

    local dots = function () {
      local aliveCount = count_total_state.value - count_broken_state.value
      local children = []
      children.resize(aliveCount, dotAlive(count_total_state.value))
      children.resize(count_total_state.value, dotDead(count_total_state.value))

      return {
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_HORIZONTAL
        halign = HALIGN_CENTER
        children = children
      }
    }


    local text = @() {
      rendObj = ROBJ_TEXT
      color = count_broken_state.value > 0 ? Color(255, 255, 255) : Color(37, 46, 53, 80)
      fontFx = fontFx
      fontFxColor = fontFxColor
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
      fontFx = fontFx
      fontFxColor = fontFxColor
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
      color =  shipState.fire.value ? Color(221, 17, 17) : Color(37, 46, 53, 80)
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
  image = ::get_value(shipState.aiGunnersState.value, images.gunnerState, images.gunnerState[0])
  color = Color(255, 255, 255)
  watch = shipState.aiGunnersState
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
      image = images.gunner
      color = crewState.gunnerAlive.value ? Color(37, 46, 53, 80) : Color(221, 17, 17)
      watch = crewState.gunnerAlive
    }
    @() {
      size = [sh(STATE_ICON_SIZE), sh(STATE_ICON_SIZE)]
      marigin = [sh(STATE_ICON_MARGIN), 0]
      rendObj = ROBJ_IMAGE
      image = images.driver
      color = crewState.driverAlive.value ? Color(37, 46, 53, 80) : Color(221, 17, 17)
      watch = crewState.driverAlive
    }
    {
      size = [sh(STATE_ICON_SIZE), sh(STATE_ICON_SIZE)]
      marigin = [sh(STATE_ICON_MARGIN), 0]
      rendObj = ROBJ_IMAGE
      image = images.shipCrew
      children = @() {
        vplace = VALIGN_BOTTOM
        hplace = HALIGN_RIGHT
        rendObj = ROBJ_TEXT
        text = crewState.aliveCrewMembersCount.value.tostring()
//        font = Fonts.small_text_hud //better show bigger and brighter (red probably)
        fontFx = fontFx
        fontFxColor = fontFxColor
        watch = crewState.aliveCrewMembersCount
      }
    }
  ]
}


local steering = function () {
  local mark = @(p) {
    rendObj = ROBJ_IMAGE
    image = images.steeringMark
    color = Color(235, 235, 60, 200)
    size = [sh(1.4), sh(1)]
    pos = @() [p * pw(100) - w(100)/2 + 1, -h(100)/2]
  }

  local line = {
    size = [sh(0.1), sh(0.5)]
    rendObj = ROBJ_SOLID
    color = Color(135, 163, 160, 100)
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
        color = Color(0, 0, 0, 50)
        flow = FLOW_HORIZONTAL
        valign = VALIGN_BOTTOM
        children = [
          line
          space
          line
          space
          line
          space
          line
          space
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
  vplace = VALIGN_BOTTOM
  size = SIZE_TO_CONTENT
  flow = FLOW_VERTICAL
  margin = [sh(5), sh(1)] //keep gap for counters
  children = [
    speed
    {size=[flex(),sh(0.5)]}
    shipStateDisplay
  ]
}
