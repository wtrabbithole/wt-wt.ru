enum MISSION_OBJECTIVE
{
  KILLS_AIR           = 0x0001
  KILLS_GROUND        = 0x0002
  KILLS_NAVAL         = 0x0004

  KILLS_AIR_AI        = 0x0010
  KILLS_GROUND_AI     = 0x0020
  KILLS_NAVAL_AI      = 0x0040

  KILLS_TOTAL_AI      = 0x0100

  ZONE_CAPTURE        = 0x0200
  ZONE_BOMBING        = 0x0400
  ALIVE_TIME          = 0x0800

  //masks
  NONE                = 0x0000
  ANY                 = 0xFFFF

  KILLS_ANY           = 0x0077
  KILLS_AIR_OR_TANK   = 0x0033
  KILLS_ANY_AI        = 0x0070
}

::g_mission_type <- {
  types = []
  _cacheByMissionName = {}
}

::g_mission_type.template <- {
  _typeName = "" //filled by type name
  reMisName = ::regexp2(@"^$")
  objectives   = MISSION_OBJECTIVE.KILLS_AIR_OR_TANK
  objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.KILLS_TOTAL_AI
  helpBlkPath = ""
  getObjectives = function(misInfoBlk) {
    return ::getTblValue("isWorldWar", misInfoBlk) ? objectivesWw : objectives
  }
}

::g_enum_utils.addTypesByGlobalName("g_mission_type", {
  UNKNOWN = {
  }

  A_AD = {  // Air: Air Domination
    reMisName = ::regexp2(@"_AD(n|to)?(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.ZONE_CAPTURE
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.ZONE_CAPTURE | MISSION_OBJECTIVE.KILLS_TOTAL_AI
    helpBlkPath = "gui/help/missionAirDomination.blk"
  }

  A_AFD = {  // Air: Airfield Domination
    reMisName = ::regexp2(@"_AfD(n|to)?(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
    helpBlkPath = "gui/help/missionAirfieldCapture.blk"
  }

  A_GS = {  // Air: Ground Strike
    reMisName = ::regexp2(@"_GS(n|to)?(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND_AI | MISSION_OBJECTIVE.KILLS_NAVAL_AI
                 | MISSION_OBJECTIVE.ZONE_BOMBING
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_BOMBING
    helpBlkPath = "gui/help/missionGroundStrikeComplete.blk"
  }

  A_BFD = {  // Air: Battlefront Domination
    reMisName = ::regexp2(@"_BfD(n|to)?(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND_AI | MISSION_OBJECTIVE.KILLS_NAVAL_AI
                 | MISSION_OBJECTIVE.ZONE_BOMBING
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_BOMBING
    helpBlkPath = "gui/help/missionGroundStrikeComplete.blk"
  }

  A_I2M = {  // Air: Enduring Confrontation
    reMisName = ::regexp2(@"_I2M(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_ANY_AI | MISSION_OBJECTIVE.ZONE_BOMBING
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_BOMBING
    helpBlkPath = "gui/help/missionGroundStrikeComplete.blk"
  }

  A_DUEL = {  // Air: Duel
    reMisName = ::regexp2(@"_duel(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR
  }

  A_RACE = {  // Air: Race
    reMisName = ::regexp2(@"_race(_|$)")
    objectives = MISSION_OBJECTIVE.NONE
    objectivesWw = MISSION_OBJECTIVE.NONE
  }

  G_DOM = {  // Ground: Domination
    reMisName = ::regexp2(@"_Dom(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.ZONE_CAPTURE
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
    helpBlkPath = "gui/help/missionGroundCapture.blk"
  }

  G_CONQ = {  // Ground: Conquest
    reMisName = ::regexp2(@"_Conq\d*(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.ZONE_CAPTURE
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
    helpBlkPath = "gui/help/missionGroundCapture.blk"
  }

  G_BTTL = {  // Ground: Battle
    reMisName = ::regexp2(@"_Bttl(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.ZONE_CAPTURE
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
    helpBlkPath = "gui/help/missionGroundCapture.blk"
  }

  G_BTO = {  // Ground: Break
    reMisName = ::regexp2(@"_Bto(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.ZONE_CAPTURE
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.KILLS_TOTAL_AI | MISSION_OBJECTIVE.ZONE_CAPTURE
    helpBlkPath = "gui/help/missionGroundCapture.blk"
  }

  G_BR = {  // Ground: Battle Royalle
    reMisName = ::regexp2(@"_BR(_|$)")
    objectives = MISSION_OBJECTIVE.KILLS_GROUND | MISSION_OBJECTIVE.ALIVE_TIME
  }

  NA = {
    reMisName = ::regexp2(@"_NA")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.KILLS_NAVAL_AI
                 | MISSION_OBJECTIVE.ZONE_CAPTURE
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.KILLS_TOTAL_AI
                 | MISSION_OBJECTIVE.ZONE_CAPTURE
  }

  N_DOM = {
    reMisName = ::regexp2(@"_NDom")
    objectives = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.KILLS_NAVAL_AI
                 | MISSION_OBJECTIVE.ZONE_CAPTURE
    objectivesWw = MISSION_OBJECTIVE.KILLS_AIR | MISSION_OBJECTIVE.KILLS_NAVAL | MISSION_OBJECTIVE.KILLS_TOTAL_AI
                 | MISSION_OBJECTIVE.ZONE_CAPTURE
  }

  PvE = {
    reMisName = ::regexp2(@"_PvE")
    objectives = MISSION_OBJECTIVE.KILLS_ANY_AI
    objectivesWw = MISSION_OBJECTIVE.KILLS_ANY_AI
  }
}, null, "_typeName")

function g_mission_type::getTypeByMissionName(misName)
{
  if (!misName)
    return UNKNOWN
  if (misName in _cacheByMissionName)
    return _cacheByMissionName[misName]

  local res = UNKNOWN
  foreach (val in types)
    if (val.reMisName.match(misName))
    {
      res = val
      break
    }
  if (res == UNKNOWN && ::is_mission_for_tanks(::get_mission_meta_info(misName)))
    res = G_DOM

  _cacheByMissionName[misName] <- res
  return res
}

function g_mission_type::getCurrent()
{
  return getTypeByMissionName(::get_current_mission_name())
}

function g_mission_type::getCurrentObjectives()
{
  return getCurrent().getObjectives(::get_current_mission_info_cached())
}
