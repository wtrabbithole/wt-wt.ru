local interopGen = require("daRg/helpers/interopGen.nut")

const NUM_ENGINES_MAX = 3

local helicopterState = {
  IndicatorsVisible = Watched(false)
  DistanceToGround = Watched(0.0)
  VerticalSpeed = Watched(0.0)

  RocketAimX = Watched(0.0)
  RocketAimY = Watched(0.0)
  RocketAimVisible = Watched(false)

  AamAimGimbalX = Watched(0.0)
  AamAimGimbalY = Watched(0.0)
  AamAimGimbalSize = Watched(0.0)
  AamAimGimbalVisible = Watched(false)

  AamAimTrackerX = Watched(0.0)
  AamAimTrackerY = Watched(0.0)
  AamAimTrackerSize = Watched(0.0)
  AamAimTrackerVisible = Watched(false)

  GunDirectionX = Watched(0.0)
  GunDirectionY = Watched(0.0)
  GunDirectionVisible = Watched(false)

  HorAngle = Watched(0.0)

  TurretYaw = Watched(0.0)
  TurretPitch = Watched(0.0)

  IsSightLocked = Watched(false)
  IsLaserDesignatorEnabled = Watched(false)

  MainMask = Watched(0)
  SightMask = Watched(0)

  HudColor = Watched(Color(71, 232, 39, 240))
  AlertColor = Watched(Color(255, 0, 0, 240))

  TrtMode = Watched(0)

  Rpm = Watched(0)
  Trt = Watched(0)
  Spd = Watched(0)

  Cannons = {
    count = Watched(0)
    seconds = Watched(-1)
  }

  MachineGuns = {
    count = Watched(0)
    seconds = Watched(-1)
  }

  CannonsAdditional = {
    count = Watched(0)
    seconds = Watched(-1)
  }

  Rockets = {
    count = Watched(0)
    seconds = Watched(-1)
  }

  Agm = {
    count = Watched(0)
    seconds = Watched(-1)
    timeToTarget = Watched(-1)
  }

  Aam = {
    count = Watched(0)
    seconds = Watched(-1)
  }

  Bombs = {
    count = Watched(0)
    seconds = Watched(-1)
  }

  Flares = {
    count = Watched(0)
    seconds = Watched(-1)
  }

  IsCanEmpty = Watched(false)
  IsMachineGunEmpty = Watched(false)
  IsCanAdditionalEmpty = Watched(false)
  IsRktEmpty = Watched(false)
  IsAgmEmpty = Watched(false)
  IsAamEmpty = Watched(false)
  IsBmbEmpty = Watched(false)
  IsFlrEmpty = Watched(false)

  IsHighRateOfFire = Watched(false)

  IsRpmCritical = Watched(false)

  FixedGunDirectionX = Watched(-100)
  FixedGunDirectionY = Watched(-100)
  FixedGunDirectionVisible = Watched(false)

  IsRangefinderEnabled = Watched(false)
  RangefinderDist = Watched(0)

  OilTemperature = []
  WaterTemperature = []
  EngineTemperature = []

  OilState = []
  WaterState = []
  EngineState = []

  IsOilAlert = []
  IsWaterAlert = []
  IsEngineAlert = []

  IsMainHudVisible = Watched(false)
  IsSightHudVisible = Watched(false)
  IsPilotHudVisible = Watched(false)
  IsGunnerHudVisible = Watched(false)

  GunOverheatState = Watched(0)

  AgmGuidanceLockState = Watched(-1)
  AamGuidanceLockState = Watched(-1)

  IsCompassVisible = Watched(false)
}

::interop.updateCannons <- function(count, sec = -1) {
  helicopterState.Cannons.count.update(count)
  helicopterState.Cannons.seconds.update(sec)
}

::interop.updateMachineGuns <- function(count, sec = -1) {
  helicopterState.MachineGuns.count.update(count)
  helicopterState.MachineGuns.seconds.update(sec)
}

::interop.updateAdditionalCannons <- function(count, sec = -1) {
  helicopterState.CannonsAdditional.count.update(count)
}

::interop.updateRockets <- function(count, sec = -1) {
  helicopterState.Rockets.count.update(count)
  helicopterState.Rockets.seconds.update(sec)
}

::interop.updateAgm <- function(count, sec, timeToTarget) {
  helicopterState.Agm.count.update(count)
  helicopterState.Agm.seconds.update(sec)
  helicopterState.Agm.timeToTarget.update(timeToTarget)
}

::interop.updateAam <- function(count, sec = -1) {
  helicopterState.Aam.count.update(count)
  helicopterState.Aam.seconds.update(sec)
}

::interop.updateBombs <- function(count, sec = -1) {
  helicopterState.Bombs.count.update(count)
  helicopterState.Bombs.seconds.update(sec)
}

::interop.updateFlares <- function(count, sec = -1) {
  helicopterState.Flares.count.update(count)
  helicopterState.Flares.seconds.update(sec)
}

for (local i = 0; i < NUM_ENGINES_MAX; ++i)
{
  helicopterState.OilTemperature.append(Watched(0))
  helicopterState.WaterTemperature.append(Watched(0))
  helicopterState.EngineTemperature.append(Watched(0))

  helicopterState.OilState.append(Watched(0))
  helicopterState.WaterState.append(Watched(0))
  helicopterState.EngineState.append(Watched(0))

  helicopterState.IsOilAlert.append(Watched(false))
  helicopterState.IsWaterAlert.append(Watched(false))
  helicopterState.IsEngineAlert.append(Watched(false))
}

interopGen({
  stateTable = helicopterState
  prefix = "helicopter"
  postfix = "Update"
})

::interop.updateOilTemperature <- function (temperature, state, index) {
  helicopterState.OilTemperature[index].update(temperature)
  helicopterState.OilState[index].update(state)
}

::interop.updateWaterTemperature <- function (temperature, state, index) {
  helicopterState.WaterTemperature[index].update(temperature)
  helicopterState.WaterState[index].update(state)
}

::interop.updateEngineTemperature <- function (temperature, state, index) {
  helicopterState.EngineTemperature[index].update(temperature)
  helicopterState.EngineState[index].update(state)
}

::interop.updateOilAlert <- function (value, index) {
  helicopterState.IsOilAlert[index].update(value)
}

::interop.updateWaterAlert <- function (value, index) {
  helicopterState.IsWaterAlert[index].update(value)
}

::interop.updateEngineAlert <- function (value, index) {
  helicopterState.IsEngineAlert[index].update(value)
}

return helicopterState