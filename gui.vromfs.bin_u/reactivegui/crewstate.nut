local stateHelpers = require("stateHelpers.nut")

local crewState = {
  totalCrewCount = Watched(0)
  aliveCrewMembersCount = Watched(0)
  minCrewMembersCount = Watched(0)
  totalCrewMembersCount = Watched(1)
  driverAlive = Watched(false)
  gunnerAlive = Watched(false)
}


foreach (stateVarName, stateVar in crewState) {
  if (stateVar instanceof Watched)
    ::interop[stateVarName] <- stateHelpers.updateStateFn(stateVar)
}


return crewState
