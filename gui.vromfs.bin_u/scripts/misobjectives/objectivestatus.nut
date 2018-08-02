local enums = ::require("sqStdlibs/helpers/enums.nut")
::g_objective_status <- {
  types = []
}

::g_objective_status.template <- {
  code = -1
  name = ""
  missionObjImg = ""
  wwMissionObjImg = ""
}

enums.addTypesByGlobalName("g_objective_status", {
  DELAYED = {
    code = ::MISSION_OBJECTIVE_STATUS_DELAYED
    name = "delayed"
  }
  RUNNING = {
    code = ::MISSION_OBJECTIVE_STATUS_IN_PROGRESS
    name = "running"
    missionObjImg = "#ui/gameuiskin#icon_primary"
    wwMissionObjImg = "#ui/gameuiskin#icon_primary"
  }
  SUCCEED = {
    code = ::MISSION_OBJECTIVE_STATUS_COMPLETED
    name = "succeed"
    missionObjImg = "#ui/gameuiskin#icon_primary_success"
    wwMissionObjImg = "#ui/gameuiskin#favorite"
  }
  FAILED = {
    code = ::MISSION_OBJECTIVE_STATUS_FAILED
    name = "failed"
    missionObjImg = "#ui/gameuiskin#icon_primary_fail"
    wwMissionObjImg = "#ui/gameuiskin#icon_primary_fail"
  }
  UNKNOWN = {
    name = "unknown"
  }
})

function g_objective_status::getObjectiveStatusByCode(statusCode)
{
  return enums.getCachedType("code", statusCode, ::g_objective_status_cache.byCode,
    ::g_objective_status, ::g_objective_status.UNKNOWN)
}

::g_objective_status_cache <- {
  byCode = {}
}
