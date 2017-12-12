local interopGet = require("daRg/helpers/interopGen.nut")
local chatBase = require("daRg/components/chat.nut")


local shipState = {
  speed = Watched(0)
  steering = Watched(0.0)
  buoyancy = Watched(1.0)
  fire = Watched(false)
  portSideMachine = Watched(-1)
  sideboardSideMachine = Watched(-1)
  stopping = Watched(false)

  fwdAngle = Watched(0)
  sightAngle = Watched(0)
  fov = Watched(0)

  depthUnderShip = Watched(-1)
  showDepthUnderShip = Watched(false)
  depthUnderShipIsCritical = Watched(false)

  obstacleIsNear = Watched(false)
  distanceToObstacle = Watched(-1)

  //DM:
  enginesCount = Watched(0)
  brokenEnginesCount = Watched(0)

  steeringGearsCount = Watched(0)
  brokenSteeringGearsCount = Watched(0)

  torpedosCount = Watched(0)
  brokenTorpedosCount = Watched(0)

  artilleryType = Watched(TRIGGER_GROUP_PRIMARY)
  artilleryCount = Watched(0)
  brokenArtilleryCount = Watched(0)

  transmissionCount = Watched(0)
  brokenTransmissionCount = Watched(0)

  aiGunnersState = Watched(0)
  hasAiGunners = Watched(true)
}


interopGet({
  stateTable = shipState
  prefix = "ship"
  postfix = "Update"
})


return shipState
