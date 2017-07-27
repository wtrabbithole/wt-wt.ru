local stateHelpers = require("stateHelpers.nut")

local shipState = {
  speed = Watched(0)
  steering = Watched(0.0)
  buoyancy = Watched(1.0)
  fire = Watched(false)
  portSideMachine = Watched(-1)
  sideboardSideMachine = Watched(-1)

  fwdAngle = Watched(0)
  sightAngle = Watched(0)
  fov = Watched(0)

  //DM:
  enginesCount = Watched(0)
  brokenEnginesCount = Watched(0)

  steeringGearsCount = Watched(0)
  brokenSteeringGearsCount = Watched(0)

  torpedosCount = Watched(0)
  brokenTorpedosCount = Watched(0)

  artilleryCount = Watched(0)
  brokenArtilleryCount = Watched(0)

  transmissionCount = Watched(0)
  brokenTransmissionCount = Watched(0)

  ruddersCount = Watched(0)
  brokenRuddersCount = Watched(0)

  aiGunnersState = Watched(0)
  hasAiGunners = Watched(true)
}


foreach (stateVarName, stateVar in shipState) {
  if (stateVar instanceof Watched)
    ::interop[stateVarName] <- stateHelpers.updateStateFn(stateVar)
}


return shipState
