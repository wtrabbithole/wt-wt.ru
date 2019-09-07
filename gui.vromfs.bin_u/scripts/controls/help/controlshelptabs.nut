local u = require("sqStdLibs/helpers/u.nut")
local platform = require("scripts/clientState/platform.nut")
local helpTypes = require("scripts/controls/help/controlsHelpTypes.nut")

local tabGroups = [
  {
    title = "#controls/help/aircraft_simpleControls"
    list = [
      helpTypes.IMAGE_AIRCRAFT
      helpTypes.CONTROLLER_AIRCRAFT
      helpTypes.KEYBOARD_AIRCRAFT
    ]
  }
  {
    title = "#controls/help/tank_simpleControls"
    list = [
      helpTypes.IMAGE_TANK
      helpTypes.CONTROLLER_TANK
      helpTypes.KEYBOARD_TANK
    ]
  }
  {
    title = "#controls/help/ship_simpleControls"
    list = [
      helpTypes.IMAGE_SHIP
      helpTypes.CONTROLLER_SHIP
      helpTypes.KEYBOARD_SHIP
    ]
  }
  {
    title = "#hotkeys/ID_SUBMARINE_CONTROL_HEADER"
    list = [
      helpTypes.IMAGE_SUBMARINE
      helpTypes.CONTROLLER_SUBMARINE
      helpTypes.KEYBOARD_SUBMARINE
    ]
  }
  {
    title = "#hotkeys/ID_HELICOPTER_CONTROL_HEADER"
    list = [
      helpTypes.IMAGE_HELICOPTER
      helpTypes.CONTROLLER_HELICOPTER
      helpTypes.KEYBOARD_HELICOPTER
    ]
  }
  {
    title = "#hotkeys/ID_CONTROL_HEADER_UFO"
    list = [
      helpTypes.IMAGE_UFO
      helpTypes.CONTROLLER_UFO
      helpTypes.KEYBOARD_UFO
    ]
  }
  {
    title = "#mission_objectives"
    list = [
      helpTypes.MISSION_OBJECTIVES
    ]
  }
  {
    title = platform.isPlatformXboxOne? "#presets/xboxone/thrustmaster_hotasOne" : "#presets/ps4/thrustmaster_hotas4"
    list = [
      helpTypes.HOTAS4_COMMON
    ]
  }
]

function getTabs(contentSet)
{
  local res = []
  foreach (group in tabGroups)
  {
    local filteredGroup = group.list.filter(@(idx, t) t.needShow(contentSet))
    if (filteredGroup.len() > 0)
      res.append(group.__update({list = filteredGroup}))
  }
  return res
}

function getPrefferableType(contentSet)
{
  if (contentSet == HELP_CONTENT_SET.LOADING)
    return helpTypes.MISSION_OBJECTIVES

  //FIXME: fix function add in there replace for show_aircraft if dummy
  local unit = ::get_player_cur_unit()
  if (!unit || unit.name == "dummy_plane")
    unit = ::show_aircraft

  local unitType = unit? unit.unitType : ::g_unit_type.INVALID

  local unitTag = ::is_submarine(unit)
                ? "submarine" : unit?.isUfo?()
                  ? "ufo"
                : null

  if (helpTypes.HOTAS4_COMMON.needShow(contentSet) && helpTypes.HOTAS4_COMMON.showByUnit(unitType, unitTag))
    return helpTypes.HOTAS4_COMMON

  //!!!FIXME appear in many files, change to common function
  local difficulty = ::is_in_flight() ? ::get_mission_difficulty_int() : ::get_current_shop_difficulty().diffCode
  local isAdvanced = difficulty == ::DIFFICULTY_HARDCORE

  if (!::is_me_newbie() && unitTag == null && !isAdvanced && helpTypes.MISSION_OBJECTIVES.needShow(contentSet))
    return helpTypes.MISSION_OBJECTIVES

  return u.search(helpTypes.types, @(t) t.helpPattern == CONTROL_HELP_PATTERN.IMAGE
                              && t.needShow(contentSet)
                              && t.showByUnit(unitType, unitTag))
      || u.search(helpTypes.types, @(t) t.helpPattern == CONTROL_HELP_PATTERN.GAMEPAD
                              && t.needShow(contentSet)
                              && t.showByUnit(unitType, unitTag))
      || u.search(helpTypes.types, @(t) t.helpPattern == CONTROL_HELP_PATTERN.KEYBOARD_MOUSE
                              && t.needShow(contentSet)
                              && t.showByUnit(unitType, unitTag))
      || helpTypes.IMAGE_AIRCRAFT
}

return {
  getTabs = getTabs
  getPrefferableType = getPrefferableType
}