local shipState = require("shipState.nut")
local crewState = require("crewState.nut")

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
}

local fontFxColor = Color(80, 80, 80)
local fontFx = FFT_GLOW

local speed = function () {
  local speedValue = @() {
    rendObj = ROBJ_TEXT
    text = shipState.speed.value.tostring()
    font = Fonts.medium_text_hud
    fontFx = fontFx
    fontFxColor = fontFxColor
    margin = [0, sh(2)]
  }

  local machine = function (port, sideboard) {
    local averegeSpeed = clamp((port + sideboard) / 2, 0, machineSpeedLoc.len())
    return {
      rendObj = ROBJ_TEXT
      font = Fonts.medium_text_hud
      color = Color(200, 200, 200)
      fontFx = fontFx
      fontFxColor = fontFxColor
      text = machineSpeedLoc[averegeSpeed] + " " + machineDirectionLoc[averegeSpeed]
    }
  }

  return {
    size = SIZE_TO_CONTENT
    flow = FLOW_HORIZONTAL
    watch = [
      shipState.speed
      shipState.portSideMachine
      shipState.sideboardSideMachine
    ]

    children = [
      machine(shipState.portSideMachine.value, shipState.sideboardSideMachine.value)
      speedValue
    ]
  }
}


///
/// Return component represents state of group
/// of similar dm modules (engines, torpedos, etc.)
///
local dmModule = function (icon, count_total_state, count_broken_state) {
  return function () {
    local color = Color(37, 46, 53, 80)
    if (count_total_state.value == count_broken_state.value)
      color = Color(221, 17, 17)
    else if (count_broken_state.value > 0)
      color = Color(255, 176, 37)
    local image = {
      rendObj = ROBJ_IMAGE
      color =  color
      image = icon
      size = [sh(5), sh(5)]
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

    local children = [image]
    if (count_total_state.value > 1)
      children.append(dots)

    return {
      size = SIZE_TO_CONTENT
      flow = FLOW_VERTICAL
      margin = [sh(0.7), 0]
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

local buoyancyIndicator = {
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
    }
    {
      rendObj = ROBJ_IMAGE
      image = images.buoyancy
      size = [sh(5), sh(1)]
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
      size = [sh(5), sh(5)]
    }
    buoyancyIndicator
  ]
}


local crewBlock = {
  vplace = VALIGN_BOTTOM
  flow = FLOW_VERTICAL
  size = [sh(5), SIZE_TO_CONTENT]
  vplace = VALIGN_BOTTOM

  children = [
    @() {
      size = [sh(5), sh(5)]
      marigin = [sh(0.7), 0]
      rendObj = ROBJ_IMAGE
      image = images.gunner
      color = crewState.gunnerAlive.value ? Color(37, 46, 53, 80) : Color(221, 17, 17)
      watch = crewState.gunnerAlive
    }
    @() {
      size = [sh(5), sh(5)]
      marigin = [sh(0.7), 0]
      rendObj = ROBJ_IMAGE
      image = images.driver
      color = crewState.driverAlive.value ? Color(37, 46, 53, 80) : Color(221, 17, 17)
      watch = crewState.driverAlive
    }
    {
      size = [sh(5), sh(5)]
      marigin = [sh(0.7), 0]
      rendObj = ROBJ_IMAGE
      image = images.shipCrew
      children = @() {
        vplace = VALIGN_BOTTOM
        hplace = HALIGN_RIGHT
        rendObj = ROBJ_TEXT
        text = crewState.aliveCrewMembersCount.value.tostring()
        font = Fonts.small_text_hud
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
    color = Color(255, 255, 0)
    size = [sh(1.4), sh(1)]
    pos = @() [p * pw(100) - w(100)/2 + 1, -h(100)/2]
  }

  local line = {
    size = [sh(0.1), sh(1.2)]
    rendObj = ROBJ_SOLID
    color = Color(135, 163, 160)
  }
  local space = {
    size = flex()
  }
  return {
    watch = shipState.steering
    size = [flex(), sh(1)]

    children = [
      {
        size = flex()
        rendObj = ROBJ_SOLID
        color = Color(0, 0, 0, 180)
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
    rendObj = ROBJ_IMAGE
    image = images.sightCone
    color = Color(255, 200, 0)
    size = [sh(30), sh(30)]
    transform = {
      pivot = [0.5, 0.5]
      rotate = shipState.sightAngle.value - shipState.fwdAngle.value
      scale = [::math.sin(shipState.fov.value), 1.0]
    }
  }
}


local doll = {
  color = Color(0, 255, 0)
  size = [sh(15), sh(40)]
  rendObj = ROBJ_XRAYDOLL
  rotateWithCamera = false

  children = fov([sh(15)/2, sh(40)/2])
}


local leftBlock = damageModules

local rightBlock = {
  size = [SIZE_TO_CONTENT, flex()]
  children = [
    stateBlock
    crewBlock
  ]
}

return {
  vplace = VALIGN_BOTTOM
  flow = FLOW_VERTICAL
  margin = [sh(1), sh(5)]
  children = [
    speed
    {
      flow = FLOW_HORIZONTAL
      size = SIZE_TO_CONTENT
      children = [
        leftBlock
        doll
        rightBlock
      ]
    }
    steering
  ]
  size = SIZE_TO_CONTENT
}
