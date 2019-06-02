local aircraft = [
  { id ="ID_BASIC_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
  "ID_FIRE_MGUNS",
  "ID_FIRE_CANNONS",
  "ID_FIRE_ADDITIONAL_GUNS",
  "ID_BAY_DOOR",
  "ID_BOMBS",
  "ID_ROCKETS",
  "ID_AGM",
  "ID_WEAPON_LOCK",
  "ID_AAM",
  "ID_SENSOR_SWITCH",
  "ID_SENSOR_MODE_SWITCH",
  "ID_SENSOR_SCAN_PATTERN_SWITCH",
  "ID_SENSOR_RANGE_SWITCH",
  "ID_SENSOR_TARGET_SWITCH",
  "ID_SENSOR_TARGET_LOCK",
  "ID_SCHRAEGE_MUSIK",
  "ID_GEAR",
  { id="ailerons", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  { id="elevator", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  { id="rudder", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  { id="throttle", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  "ID_LOCK_TARGET",
  "ID_NEXT_TARGET",
  "ID_PREV_TARGET",
  "ID_RELOAD_GUNS",
  "ID_SHOW_HERO_MODULES",

  { id ="ID_VIEW_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
  "ID_ZOOM_TOGGLE"
  "ID_TARGET_CAMERA", "ID_CAMERA_NEUTRAL",
  "ID_CAMERA_TPS", "ID_CAMERA_FPS", "ID_CAMERA_VIRTUAL_FPS", "ID_CAMERA_GUNNER",
  "ID_CAMERA_BOMBVIEW", "ID_CAMERA_DEFAULT",
  "ID_CAMERA_FOLLOW_OBJECT"
  "ID_TOGGLE_VIEW"

  { id ="ID_MISC_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
  "ID_HELP"
  "ID_GAME_PAUSE",
//  "ID_BAILOUT",
  "ID_TACTICAL_MAP", "ID_MPSTATSCREEN",
  "ID_TOGGLE_CHAT_TEAM",
  "ID_TOGGLE_CHAT"
  "ID_SHOW_VOICE_MESSAGE_LIST"
  "ID_SHOW_VOICE_MESSAGE_LIST_SQUAD"
  "ID_HIDE_HUD"
]

local tank = [
  { id ="ID_BASIC_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
  "ID_FIRE_GM",
  { id="gm_throttle", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  { id="gm_steering", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  { id="gm_mouse_aim_x", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  { id="gm_mouse_aim_y", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  "ID_TRANS_GEAR_UP",
  "ID_TRANS_GEAR_DOWN",
  "ID_ACTION_BAR_ITEM_1",
  "ID_ACTION_BAR_ITEM_2",
  "ID_ACTION_BAR_ITEM_3",
  "ID_ACTION_BAR_ITEM_4",
  "ID_ACTION_BAR_ITEM_5",
  "ID_ACTION_BAR_ITEM_6",
  "ID_SHOOT_ARTILLERY",
  "ID_LOCK_TARGET",
  "ID_REPAIR_TANK",
  "ID_SHOW_HERO_MODULES",
  "ID_SMOKE_SCREEN_GENERATOR",
  "ID_SENSOR_SWITCH_TANK",
  "ID_SENSOR_MODE_SWITCH_TANK",
  "ID_SENSOR_SCAN_PATTERN_SWITCH_TANK",
  "ID_SENSOR_RANGE_SWITCH_TANK",
  "ID_SENSOR_TARGET_SWITCH_TANK",
  "ID_SENSOR_TARGET_LOCK_TANK",
  "ID_SUSPENSION_PITCH_UP",
  "ID_SUSPENSION_PITCH_DOWN",
  "ID_SUSPENSION_ROLL_UP",
  "ID_SUSPENSION_ROLL_DOWN",
  "ID_SUSPENSION_CLEARANCE_UP",
  "ID_SUSPENSION_CLEARANCE_DOWN",
  "ID_SUSPENSION_RESET",

  { id ="ID_VIEW_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
  "ID_ZOOM_TOGGLE"
  "ID_TARGET_CAMERA"
  "ID_CAMERA_NEUTRAL"
  "ID_TOGGLE_VIEW_GM"

  { id ="ID_MISC_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
  "ID_HELP"
  "ID_GAME_PAUSE",
  "ID_TACTICAL_MAP", "ID_MPSTATSCREEN",
  "ID_TOGGLE_CHAT_TEAM",
  "ID_TOGGLE_CHAT"
  "ID_SHOW_VOICE_MESSAGE_LIST"
  "ID_SHOW_VOICE_MESSAGE_LIST_SQUAD"
  "ID_HIDE_HUD"
]

local ship = [
  { id = "ID_SHIP_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
  "ID_SHIP_WEAPON_ALL"
  "ID_SHIP_WEAPON_PRIMARY"
  "ID_SHIP_WEAPON_SECONDARY"
  "ID_SHIP_WEAPON_MACHINEGUN"
  "ID_SHIP_WEAPON_TORPEDOES"
  "ID_SHIP_TORPEDO_SIGHT"
  "ID_SHIP_WEAPON_DEPTH_CHARGE"
  "ID_SHIP_WEAPON_MINE"
  "ID_SHIP_WEAPON_MORTAR"
  "ID_SHIP_WEAPON_ROCKETS"
  "ID_SHIP_SMOKE_SCREEN_GENERATOR"
  { id="ship_main_engine", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  { id="ship_steering", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  "ID_SHIP_ACTION_BAR_ITEM_1",
  "ID_SHIP_ACTION_BAR_ITEM_2",
  "ID_SHIP_ACTION_BAR_ITEM_3",
  "ID_SHIP_ACTION_BAR_ITEM_4",
  "ID_SHIP_ACTION_BAR_ITEM_5",
  "ID_SHIP_ACTION_BAR_ITEM_6",
  "ID_SHIP_ACTION_BAR_ITEM_11",
  "ID_REPAIR_BREACHES",
  "ID_SHIP_ACTION_BAR_ITEM_10",
  "ID_LOCK_TARGET",
  "ID_SHOW_HERO_MODULES",

  { id ="ID_VIEW_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
  "ID_ZOOM_TOGGLE"
  "ID_TARGET_CAMERA"
  "ID_CAMERA_NEUTRAL"
  "ID_TOGGLE_VIEW_SHIP"

  { id ="ID_MISC_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
  "ID_HELP"
  "ID_GAME_PAUSE",
  "ID_TACTICAL_MAP", "ID_MPSTATSCREEN",
  "ID_TOGGLE_CHAT_TEAM",
  "ID_TOGGLE_CHAT"
  "ID_SHOW_VOICE_MESSAGE_LIST"
  "ID_SHOW_VOICE_MESSAGE_LIST_SQUAD"
  "ID_HIDE_HUD"
]

local helicopter = [
  { id ="ID_BASIC_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
  "ID_CONTROL_MODE_HELICOPTER"
  { id="helicopter_collective", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  { id="helicopter_cyclic_roll", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  { id="helicopter_pedals", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  { id="helicopter_cyclic_pitch", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  "ID_GEAR_HELICOPTER"
  "ID_FIRE_MGUNS_HELICOPTER"
  "ID_FIRE_CANNONS_HELICOPTER"
  "ID_FIRE_ADDITIONAL_GUNS_HELICOPTER"
  "ID_BOMBS_HELICOPTER"
  "ID_ROCKETS_HELICOPTER"
  "ID_ATGM_HELICOPTER"
  "ID_WEAPON_LOCK_HELICOPTER"
  "ID_TOGGLE_LASER_DESIGNATOR_HELICOPTER"
  "ID_AAM_HELICOPTER"

  { id ="ID_VIEW_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
  "ID_TOGGLE_VIEW_HELICOPTER"
  "ID_CAMERA_FPS_HELICOPTER"
  "ID_CAMERA_TPS_HELICOPTER"
  "ID_CAMERA_VIRTUAL_TARGET_FPS_HELICOPTER"
  "ID_CAMERA_GUNNER_HELICOPTER"
  "ID_LOCK_TARGETING_AT_POINT_HELICOPTER"
  "ID_TARGET_CAMERA_HELICOPTER"
  "ID_LOCK_TARGET"

  { id ="ID_MISC_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
  "ID_HELP"
  "ID_TACTICAL_MAP"
  "ID_MPSTATSCREEN"
  "ID_TOGGLE_CHAT_TEAM"
  "ID_SHOW_VOICE_MESSAGE_LIST"
  "ID_SHOW_VOICE_MESSAGE_LIST_SQUAD"
  "ID_HIDE_HUD"
]

local ufo = [
  { id ="ID_BASIC_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
  { id="thrust_vector_forward_ufo", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  { id="thrust_vector_lateral_ufo", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  { id="thrust_vector_vertical_ufo", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  "ID_GEAR_UFO"

  { id = "ID_PLANE_FIRE_HEADER", type = CONTROL_TYPE.HEADER }
  "ID_FIRE_LASERGUNS_UFO"
  "ID_FIRE_RAILGUNS_UFO"
  "ID_TORPEDOES_UFO"
  "ID_TORPEDO_LOCK_UFO"

  { id ="ID_MISC_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
  "ID_HELP"
  "ID_TACTICAL_MAP", "ID_MPSTATSCREEN",
  "ID_TOGGLE_CHAT_TEAM",
  "ID_SHOW_VOICE_MESSAGE_LIST"
  "ID_SHOW_VOICE_MESSAGE_LIST_SQUAD"
  "ID_HIDE_HUD"
]

local submarine = [
  { id ="ID_SUBMARINE_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
  { id="submarine_main_engine", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  { id="submarine_steering", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  { id="submarine_depth", axisShortcuts = ["rangeMin", "rangeMax", ""] }
  "ID_SUBMARINE_FULL_STOP",
  "ID_SUBMARINE_ACOUSTIC_COUNTERMEASURES",
  "ID_SUBMARINE_ACTION_BAR_ITEM_11",
  "ID_SUBMARINE_REPAIR_BREACHES",

  { id ="ID_SUBMARINE_FIRE_HEADER", type = CONTROL_TYPE.HEADER }
  "ID_SUBMARINE_SWITCH_ACTIVE_SONAR",
  "ID_SUBMARINE_WEAPON_TORPEDOES",
  "ID_TOGGLE_VIEW_SUBMARINE",
  "ID_SUBMARINE_WEAPON_TOGGLE_ACTIVE_SENSOR",
  "ID_SUBMARINE_WEAPON_TOGGLE_SELF_HOMMING",

  { id ="ID_MISC_CONTROL_HEADER", type = CONTROL_TYPE.HEADER }
  "ID_HELP"
  "ID_TACTICAL_MAP", "ID_MPSTATSCREEN",
  "ID_TOGGLE_CHAT_TEAM",
  "ID_SHOW_VOICE_MESSAGE_LIST"
  "ID_SHOW_VOICE_MESSAGE_LIST_SQUAD"
  "ID_HIDE_HUD"
]

local getList = function(unitType, unitTag)
{
  local shArray = []
  if (unitType == ::g_unit_type.AIRCRAFT && unitTag == null)
    shArray = aircraft
  else if (unitType == ::g_unit_type.AIRCRAFT && unitTag == "ufo")
    shArray = ufo
  else if (unitType == ::g_unit_type.TANK && unitTag == null)
    shArray = tank
  else if (unitType == ::g_unit_type.SHIP && unitTag == null)
    shArray = ship
  else if (unitType == ::g_unit_type.SHIP && unitTag == "submarine")
    shArray = submarine
  else if (unitType == ::g_unit_type.HELICOPTER && unitTag == null)
    shArray = helicopter

  if (::is_platform_pc) //See AcesApp::makeScreenshot()
    shArray.extend(["ID_SCREENSHOT", "ID_SCREENSHOT_WO_HUD",])

  return shArray
}

return {
  getList = getList
}