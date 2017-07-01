::g_mplayer_param_type <- {
  types = []
  cache = {
    byId = {}
  }
}

function g_mplayer_param_type::_substract(old, new) {
  return ::to_integer_safe(new) - ::to_integer_safe(old)
}

function g_mplayer_param_type::_newer(old, new) {
  return new
}

::g_mplayer_param_type.template <- {
  id = ""
  fontIcon = null
  tooltip = ""
  defVal = 0
  isVirtual = false
  missionObjective = MISSION_OBJECTIVE.ANY
  printFunc = function(val, id, player) {
    return val != null ? val.tostring() : ""
  }
  diffFunc = ::g_mplayer_param_type._substract

  width = null
  relWidth = 10
  updateSpecificMarkupParams = function(markupTbl) {}
  getMarkupData = function()
  {
    local res = {
      fontIcon = fontIcon
      tooltip = tooltip || ""
    }

    if (width != null)
      res.width <- width
    else if (relWidth != 0)
      res.relWidth <- relWidth

    updateSpecificMarkupParams(res)
    return res
  }

  isVisible = function(objectivesMask)
  {
    return (missionObjective == MISSION_OBJECTIVE.ANY) || (missionObjective & objectivesMask) != 0
  }
}

::g_enum_utils.addTypesByGlobalName("g_mplayer_param_type", {
  UNKNOWN = {
  }

  NAME = {
    id = "name"
    tooltip = "#multiplayer/name"
    defVal = ""
    printFunc = function(val, id, player) {
      return ::build_mplayer_name(player, false)
    }
    diffFunc = ::g_mplayer_param_type._newer
    width = "1@nameWidth + 1.5@tableIcoSize + 1@tablePad"
    updateSpecificMarkupParams = function(markupTbl)
    {
      markupTbl.widthInWideScreen <- "1@nameWidthInWideScreen + 1.5@tableIcoSize + 1@tablePad"
      markupTbl.airWeaponIcons <- false
      markupTbl.readyIcon <- false
      delete markupTbl.tooltip
    }
  }

  AIRCRAFT_NAME = {
    id = "aircraftName"
    tooltip = "#options/unit"
    defVal = ""
    relWidth = 30
    printFunc = function(val, id, player) {
      return ::getUnitName(val)
    }
    diffFunc = ::g_mplayer_param_type._newer
  }

  AIRCRAFT = {
    id = "aircraft"
    relWidth = 30
  }

  SCORE = {
    id = "score"
    fontIcon = "#icon/mpstats/score"
    tooltip = "#multiplayer/score"
    relWidth = 20
  }

  AIR_KILLS = {
    id = "kills"
    fontIcon = "#icon/mpstats/kills"
    tooltip = "#multiplayer/air_kills"
    missionObjective = MISSION_OBJECTIVE.KILLS_AIR
  }

  GROUND_KILLS = {
    id = "groundKills"
    fontIcon = "#icon/mpstats/groundKills"
    tooltip = "#multiplayer/ground_kills"
    missionObjective = MISSION_OBJECTIVE.KILLS_GROUND
  }

  NAVAL_KILLS = {
    id = "navalKills"
    fontIcon = "#icon/mpstats/navalKills"
    tooltip = "#multiplayer/naval_kills"
    missionObjective = MISSION_OBJECTIVE.KILLS_NAVAL
  }

  AI_AIR_KILLS = {
    id = "aiKills"
    fontIcon = "#icon/mpstats/aiKills"
    tooltip = "#multiplayer/air_kills_ai"
    missionObjective = MISSION_OBJECTIVE.KILLS_AIR_AI
  }

  AI_GROUND_KILLS = {
    id = "aiGroundKills"
    fontIcon = "#icon/mpstats/aiGroundKills"
    tooltip = "#multiplayer/ground_kills_ai"
    missionObjective = MISSION_OBJECTIVE.KILLS_GROUND_AI
  }

  AI_NAVAL_KILLS = {
    id = "aiNavalKills"
    fontIcon = "#icon/mpstats/aiNavalKills"
    tooltip = "#multiplayer/naval_kills_ai"
    missionObjective = MISSION_OBJECTIVE.KILLS_NAVAL_AI
  }

  ASSISTS = {
    id = "assists"
    fontIcon = "#icon/mpstats/assists"
    tooltip = "#multiplayer/assists"
  }

  DEATHS = {
    id = "deaths"
    fontIcon = "#icon/mpstats/deaths"
    tooltip = "#multiplayer/deaths"
  }

  CAPTURE_ZONE = {
    id = "captureZone"
    fontIcon = "#icon/mpstats/captureZone"
    tooltip = "#multiplayer/zone_captures"
    missionObjective = MISSION_OBJECTIVE.ZONE_CAPTURE
  }

  DAMAGE_ZONE = {
    id = "damageZone"
    fontIcon = "#icon/mpstats/damageZone"
    tooltip = "#debriefing/Damage"
    missionObjective = MISSION_OBJECTIVE.ZONE_BOMBING
    printFunc = function(val, id, player) {
      return ::roundToDigits(val * ::ZONE_HP_TO_TNT_EQUIVALENT_TONS, 3).tostring()
    }
  }

  ROW_NO = {
    id = "rowNo"
    fontIcon = "#icon/mpstats/rowNo"
    tooltip = "#multiplayer/place"
    isVirtual = true
    diffFunc = ::g_mplayer_param_type._newer
  }

  RACE_LAST_CHECKPOINT = {
    id = "raceLastCheckpoint"
    fontIcon = "#icon/mpstats/raceLastCheckpoint"
    tooltip = "#multiplayer/raceLastCheckpoint"
    relWidth = 15
    printFunc = function(val, id, player) {
      local total = ::get_race_checkpioints_count()
      local laps = ::get_race_laps_count()
      if (total && laps)
        val = (::max(val - 1, 0) % (total / laps)) + 1
      return val.tostring()
    }
    diffFunc = ::g_mplayer_param_type._newer
  }

  RACE_LAST_CHECKPOINT_TIME = {
    id = "raceLastCheckpointTime"
    fontIcon = "#icon/mpstats/raceLastCheckpointTime"
    tooltip = "#multiplayer/raceLastCheckpointTime"
    relWidth = 30
    defVal = -1
    printFunc = function(val, id, player) {
      return ::getRaceTimeFromSeconds(val)
    }
    diffFunc = ::g_mplayer_param_type._newer
  }

  RACE_LAP = {
    id = "raceLap"
    fontIcon = "#icon/mpstats/raceLap"
    tooltip = "#multiplayer/raceLap"
    diffFunc = ::g_mplayer_param_type._newer
  }

  RACE_BEST_LAP_TIME = {
    id = "raceBestLapTime"
    tooltip = "#multiplayer/each_player_fastlap"
    relWidth = 30
    defVal = -1
    printFunc = function(val, id, player) {
      return ::getRaceTimeFromSeconds(val)
    }
    diffFunc = function(old, new) {
      return old != new ? new : -1
    }
  }

  RACE_FINISH_TIME = {
    id = "raceFinishTime"
    tooltip = "#HUD_RACE_FINISH"
    relWidth = 30
    defVal = -1
    isVirtual = true
    printFunc = function(val, id, player) {
      if (val < 0)
      {
        local total = ::get_race_checkpioints_count()
        if (total)
          return (100 * ::getTblValue("raceLastCheckpoint", player, 0) / total).tointeger() + "%"
      }
      return ::getRaceTimeFromSeconds(val)
    }
    diffFunc = ::g_mplayer_param_type._newer
  }

  RACE_SAME_CHECKPOINT_TIME = {
    id = "raceSameCheckpointTime"
    relWidth = 30
    isVirtual = true
  }

  SQUAD = {
    id = "squad"
    width = "1@tableIcoSize"
    isVirtual = true
    updateSpecificMarkupParams = function(markupTbl)
    {
      markupTbl.image <- "#ui/gameuiskin#table_squad_background"
      markupTbl.hideImage <- true
    }
  }
})

function g_mplayer_param_type::getTypeById(id)
{
  return ::g_enum_utils.getCachedType("id", id, ::g_mplayer_param_type.cache.byId,
    ::g_mplayer_param_type, ::g_mplayer_param_type.UNKNOWN)
}
