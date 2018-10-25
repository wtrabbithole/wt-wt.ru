local gamepadIcons = require("scripts/controls/gamepadIcons.nut")
::require("scripts/viewUtils/bhvHelpFrame.nut")

local controlsMarkupSource = {
  ps4 = {
    title = "#controls/help/dualshock4"
    blk = "gui/help/controllerDualshock.blk"
    iconsPreset = gamepadIcons.ICO_PRESET_PS4
    btnBackLocId = "controls/help/dualshock4_btn_share"
  },
  xboxOne = {
    title = "#controls/help/xboxone"
    blk = "gui/help/controllerXboxOne.blk"
    iconsPreset = gamepadIcons.ICO_PRESET_XBOXONE
    btnBackLocId = "xinp/Select"
  },
  xbox360 = {
    title = "#controls/help/xinput"
    blk = "gui/help/controllerXbox.blk"
    iconsPreset = gamepadIcons.ICO_PRESET_DEFAULT
    btnBackLocId = "xinp/Select"
  }
}

local controllerMarkup = ::getTblValue(::target_platform, controlsMarkupSource, controlsMarkupSource.xbox360)

enum help_tab_types
{
  MISSION_OBJECTIVES
  IMAGE_AIRCRAFT
  IMAGE_TANK
  IMAGE_SHIP
  IMAGE_HELICOPTER
  IMAGE_SUBMARINE
  CONTROLLER_AIR
  CONTROLLER_TANK
  CONTROLLER_SHIP
  CONTROLLER_HELICOPTER
  CONTROLLER_SUBMARINE
  KEYBOARD_AIR
  KEYBOARD_TANK
  KEYBOARD_SHIP
  KEYBOARD_HELICOPTER
  KEYBOARD_SUBMARINE
  HOTAS4_COMMON
}

function gui_modal_help(isStartedFromMenu, contentSet)
{
  ::gui_start_modal_wnd(::gui_handlers.helpWndModalHandler, {
    isStartedFromMenu  = isStartedFromMenu
    contentSet = contentSet
  })

  local unitId = ::get_player_cur_unit()
  if (::is_in_flight() && ::is_submarine(unitId))
    ::g_hud_event_manager.onHudEvent("hint:controlsHelp:remove", {})
}

function gui_start_flight_menu_help()
{
  local needFlightMenu = !::get_is_in_flight_menu() && !::is_flight_menu_disabled();
  if (needFlightMenu)
    ::get_cur_base_gui_handler().goForward(function(){::gui_start_flight_menu()})
  ::gui_modal_help(needFlightMenu, HELP_CONTENT_SET.MISSION)
}

class ::gui_handlers.helpWndModalHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/help/helpWnd.blk"

  defaultLinkLinesInterval = "0.5@helpLineInterval"
  allAvaliableTabs = []
  currentSubTabs = []
  curTabIdx = -1
  curSubTabIdx = -1

  contentSet = HELP_CONTENT_SET.MISSION
  isStartedFromMenu = false

  misHelpBlkPath = ""
  pageUnitType = null
  pageUnitTag = null
  modifierSymbols = null

  tabGroups =
  [
    {
      title = "#controls/help/aircraft_simpleControls",
      list = [help_tab_types.IMAGE_AIRCRAFT, help_tab_types.CONTROLLER_AIR, help_tab_types.KEYBOARD_AIR]
    },
    {
      title = "#controls/help/tank_simpleControls",
      list = [help_tab_types.IMAGE_TANK, help_tab_types.CONTROLLER_TANK, help_tab_types.KEYBOARD_TANK]
    },
    {
      title = "#controls/help/ship_simpleControls",
      list = [help_tab_types.IMAGE_SHIP, help_tab_types.CONTROLLER_SHIP, help_tab_types.KEYBOARD_SHIP]
    },
    {
      title = "#hotkeys/ID_HELICOPTER_CONTROL_HEADER",
      list = [help_tab_types.IMAGE_HELICOPTER, help_tab_types.CONTROLLER_HELICOPTER, help_tab_types.KEYBOARD_HELICOPTER]
    },
    {
      title = "#hotkeys/ID_SUBMARINE_CONTROL_HEADER",
      list = [help_tab_types.IMAGE_SUBMARINE, help_tab_types.CONTROLLER_SUBMARINE, help_tab_types.KEYBOARD_SUBMARINE]
    },
    { // if title is not set - the title of the first list element will be taken
      list = [help_tab_types.MISSION_OBJECTIVES]
    },
    {
      list = [help_tab_types.HOTAS4_COMMON]
    }
  ]

  tabsCfg = {
    [help_tab_types.IMAGE_AIRCRAFT] = {
      defaultValues = {
        country = "ussr"
      }
      title = "#hotkeys/ID_COMMON_CONTROL_HEADER"
      showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
      isShow = function(handler, params) {
        return ::getTblValue("showControlsAir", params, false)
      }
      pageUnitType = ::g_unit_type.AIRCRAFT
      pageUnitTag = null
      pageBlkName = "gui/help/controlsAircraft.blk"
      imagePattern = "#ui/images/country_%s_controls_help.jpg?P1"
      hasImageByCountries = [ "ussr", "usa", "britain", "germany", "japan", "italy" ]
      linkLines = {
        obstacles = ["ID_LOCK_TARGET_not_default_0"]
        links = [
          {end = "throttle_value", start = "base_hud_param_label"}
          {end = "real_speed_value", start = "base_hud_param_label"}
          {end = "altitude_value", start = "base_hud_param_label"}
          {end = "throttle_value_2", start = "throttle_and_speed_relaitive_label"}
          {end = "speed_value_2", start = "throttle_and_speed_relaitive_label"}
          {end = "wep_value", start = "wep_description_label"}
          {end = "crosshairs_target_point", start = "crosshairs_label"}
          {end = "target_lead_target_point", start = "target_lead_text_label"}
          {end = "bomb_value", start = "ammo_count_label"}
          {end = "machine_guns_reload_time", start = "weapon_reload_time_label"}
          {end = "cannons_reload_time", start = "weapon_reload_time_label"}
          {end = "bomb_crosshair_target_point", start = "bomb_crosshair_label"}
          {end = "bombs_target_controls_frame_attack_image", start = "bombs_target_text_label"}
          {end = "fire_guns_controls_target_point", start = "fire_guns_controls_frame"}
          {end = "fire_guns_controls_target_point", start = "ID_FIRE_MGUNS_not_default_0"}
        ]
      }
      defaultControlsIds = [ //for default constrols we can see frameId, but for not default custom shortcut
        { frameId = "fire_guns_controls_frame", shortcut = "ID_FIRE_MGUNS" }
        { frameId = "lock_target_controls_frame", shortcut = "ID_LOCK_TARGET" }
        { frameId = "zoom_controls_frame", shortcut = "ID_ZOOM_TOGGLE" }
        { frameId = "bombs_controls_frame", shortcut = "ID_BOMBS" }
        { frameId = "throttle_down_controls_frame" }
        { frameId = "throttle_up_controls_frame" }
        { frameId = "throttle_up_controls_frame_2" }
      ]
      moveControlsFrames = function (defaultControls, scene)
      {
        if (!defaultControls)
        {
          scene.findObject("target_lead_text_label").pos = "350/1760pw-w, 690/900ph";
          scene.findObject("bombs_target_text_label").pos = "900/1760pw, 280/900ph-h";
          scene.findObject("bombs_target_controls_frame").pos = "898/1760pw, 323/900ph";
        }
        else
        {
          scene.findObject("target_lead_text_label").pos = "860/1760pw-w, 650/900ph";
          scene.findObject("bombs_target_text_label").pos = "900/1760pw, 355/900ph-h";
          scene.findObject("bombs_target_controls_frame").pos = "898/1760pw, 393/900ph";
        }
      }
    },

    [help_tab_types.IMAGE_TANK] = {
      defaultValues = {
        country = "ussr"
      }
      title = "#hotkeys/ID_COMMON_CONTROL_HEADER"
      showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
      isShow = function(handler, params) {
        return ::getTblValue("showControlsTank", params, false)
      }
      pageUnitType = ::g_unit_type.TANK
      pageUnitTag = null
      pageBlkName = "gui/help/controlsTank.blk"
      imagePattern = "#ui/images/country_%s_tank_controls_help.jpg?P1"
      hasImageByCountries = ["ussr", "germany"]
      countryRelatedObjs = {
        germany = [
          "transmission_label_1", "transmission_target_point_1",
          "diesel_engine_label_1", "diesel_engine_target_point_1",
          "stowage_area_label_1", "stowage_area_target_point_1",
          "place_gunner_target_point_1",
          "place_commander_target_point_1",
          "place_loader_target_point_1"
        ],
        ussr = [
          "transmission_label_2", "transmission_target_point_2",
          "diesel_engine_label_2", "diesel_engine_target_point_2",
          "stowage_area_label_2", "stowage_area_target_point_2", "stowage_area_target_point_3",
          "place_gunner_target_point_2",
          "place_commander_target_point_2",
          "place_loader_target_point_2",
          "throttle_target_point",
          "turn_right_target_point"
        ]
      }
      linkLines = {
        links = [
          {end = "backward_target_point", start = "backward_label"}
          {end = "gear_value", start = "base_hud_param_label"}
          {end = "rpm_value", start = "base_hud_param_label"}
          {end = "real_speed_value", start = "base_hud_param_label"}
          {end = "throttle_target_point", start = "throttle_label"}
          {end = "turn_left_target_point", start = "turn_left_frame"}
          {end = "turn_right_target_point", start = "turn_right_label"}
          {end = "ammo_1_target_point", start = "controller_switching_ammo"}
          {end = "ammo_2_target_point", start = "controller_switching_ammo"}
          {end = "ammo_1_target_point", start = "keyboard_switching_ammo"}
          {end = "ammo_2_target_point", start = "keyboard_switching_ammo"}
          {end = "artillery_target_point", start = "call_artillery_strike_label"}
          {end = "scout_target_point", start = "scout_label"}
          {end = "smoke_grenade_target_point", start = "smoke_grenade_lable"}
          {end = "smoke_screen_target_point", start = "smoke_screen_label"}
          {end = "smoke_screen_target_point", start = "controller_smoke_screen_label"}
          {end = "medicalkit_target_point", start = "medicalkit_label"}
          {end = "medicalkit_target_point", start = "controller_medicalkit_label"}
          {end = "tank_cannon_direction_target_point", start = "tank_sight_label"}
          {end = "tank_cannon_realy_target_point", start = "tank_sight_label"}
          {end = "tank_cursor_target_point", start = "tank_cursor_frame"}
          {end = "place_loader_target_point_1", start = "place_loader_label"}
          {end = "place_loader_target_point_2", start = "place_loader_label"}
          {end = "place_shooter_radio_operator_target_point_2", start = "place_shooter_radio_operator_label"}
          {end = "place_mechanics_driver_target_point", start = "place_mechanics_driver_label"}
          {end = "place_commander_target_point_1", start = "place_commander_label"}
          {end = "place_commander_target_point_2", start = "place_commander_label"}
          {end = "place_gunner_target_point_1", start = "place_gunner_label"}
          {end = "place_gunner_target_point_2", start = "place_gunner_label"}
          {end = "stowage_area_target_point_1", start = "stowage_area_label_1"}
          {end = "stowage_area_target_point_2", start = "stowage_area_label_2"}
          {end = "stowage_area_target_point_3", start = "stowage_area_label_2"}
          {end = "diesel_engine_target_point_1", start = "diesel_engine_label_1"}
          {end = "diesel_engine_target_point_2", start = "diesel_engine_label_2"}
          {end = "transmission_target_point_1", start = "transmission_label_1"}
          {end = "transmission_target_point_2", start = "transmission_label_2"}
          {end = "traversing_target_point_1", start = "traversing_label"}
          {end = "traversing_target_point_2", start = "traversing_label"}
          {end = "main_gun_target_point", start = "main_gun_tube_label"}
        ]
      }
      actionBarItems = [
        {
          type = ::EII_BULLET
          active = true
          id = "ammo_1"
          selected = true
          icon = "#ui/gameuiskin#apcbc_tank"
        },
        {
          type = ::EII_BULLET
          id = "ammo_2"
          icon = "#ui/gameuiskin#he_frag_tank"
        },
        {
          type = ::EII_SCOUT
          id = "scout"
        },
        {
          type = ::EII_ARTILLERY_TARGET
          id = "artillery"
        },
        {
          type = ::EII_SMOKE_GRENADE
          id = "smoke_grenade"
        },
        {
          type = ::EII_SMOKE_SCREEN
          id = "smoke_screen"
        },
        {
          type = ::EII_MEDICALKIT
          id = "medicalkit"
        }
      ]
    },

    [help_tab_types.IMAGE_SHIP] = {
       defaultValues = {
        country = "ussr"
      }
      title = "#hotkeys/ID_COMMON_CONTROL_HEADER"
      showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
      isShow = function(handler, params) {
        return ::getTblValue("showControlsShip", params, false)
      }
      pageUnitType = ::g_unit_type.SHIP
      pageUnitTag = null
      pageBlkName = "gui/help/controlsShip.blk"
      imagePattern = "#ui/images/country_%s_ship_controls_help.jpg?P1"
      hasImageByCountries = ["ussr"]
      countryRelatedObjs = {
        ussr = [
        ]
      }
      linkLines = {
        links = [
          {end = "turn_right_target_point", start = "turn_right_label"}
          {end = "turn_left_target_point", start = "turn_left_frame"}
          {end = "real_speed_value", start = "base_hud_param_label"}
          {end = "hdg_value", start = "base_hud_param_label"}
          {end = "gear_value", start = "base_hud_param_label"}
          {end = "buoyancy_value", start = "base_hud_param_label"}
          {end = "torpedo_value_1", start = "torpedo_hud_param_label"}
          {end = "torpedo_value_2", start = "torpedo_hud_param_label"}
          {end = "throttle_target_point", start = "throttle_label"}
          {end = "backward_target_point", start = "backward_label"}
          {end = "cannon_markers_point_0", start = "cannon_markers_label"}
          {end = "cursor_control_point", start = "CURSOR_controls_frame"}
          {end = "torpedo_trajectory_point_0", start = "torpedo_trajectory_label"}
          {end = "torpedo_trajectory_point_1", start = "torpedo_trajectory_label"}
          {end = "rocket_trajectory_point_0", start = "rocket_trajectory_label"}
          {end = "bombs_info_point_1", start = "bombs_info_label"}
          {end = "bombs_info_point_0", start = "bombs_info_label"}
          {end = "bomb_value_1", start = "rocket_hud_param_label"}
          {end = "rocket_value_1", start = "rocket_hud_param_label"}
          {end = "rocket_value_2", start = "rocket_hud_param_label"}
       ]
      }
    },

    [help_tab_types.IMAGE_HELICOPTER] = {
       defaultValues = {
        country = "ussr"
      }
      title = "#hotkeys/ID_COMMON_CONTROL_HEADER"
      showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
      isShow = function(handler, params) {
        return ::getTblValue("showControlsHelicopter", params, false)
      }
      pageUnitType = ::g_unit_type.HELICOPTER
      pageUnitTag = null
      pageBlkName = "gui/help/controlsHelicopter.blk"
      imagePattern = "#ui/images/country_%s_helicopter_controls_help.jpg?P1"
      hasImageByCountries = ["ussr"]
      countryRelatedObjs = {
        ussr = [
        ]
      }
      linkLines = {
        links = [
          { start = "hud_movement_indicators_label", end = "rpm_value" }
          { start = "hud_movement_indicators_label", end = "throttle_value" }
          { start = "hud_movement_indicators_label", end = "climb_value" }
          { start = "hud_movement_indicators_label", end = "speed_value" }
          { start = "hud_ammo_indicators_label", end = "cannons_value" }
          { start = "hud_ammo_indicators_label", end = "additional_guns_value" }
          { start = "hud_ammo_indicators_label", end = "bombs_value" }
          { start = "hud_ammo_indicators_label", end = "rockets_value" }
          { start = "hud_ammo_indicators_label", end = "missiles_value" }
          { start = "hud_ammo_indicators_label", end = "rate_of_fire_value" }
          { start = "CURSOR_controls_frame", end = "cursor_control_point" }
          { start = "secondary_cannons_aim_marker_label", end = "secondary_cannons_aim_marker_point" }
          { start = "rocket_aim_marker_label", end = "rocket_aim_marker_point" }
          { start = "bombs_aim_marker_label", end = "bombs_aim_marker_point" }
          { start = "attitude_indicator_label", end = "attitude_indicator_point" }
          { start = "velocity_vector_indicator_label", end = "velocity_vector_indicator_point" }
          { start = "altimeter_indicator_label", end = "altimeter_indicator_point" }
          { start = "vertical_speed_indicator_label", end = "vertical_speed_indicator_point" }
       ]
      }
    },

    [help_tab_types.IMAGE_SUBMARINE] = {
       defaultValues = {
        country = "ussr"
      }
      title = "#hotkeys/ID_COMMON_CONTROL_HEADER"
      showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
      isShow = @(handler, params) !!params?.showControlsSubmarine
      pageUnitType = ::g_unit_type.SHIP
      pageUnitTag = "submarine"
      pageBlkName = "gui/help/controlsSubmarine.blk"
      imagePattern = "#ui/images/country_%s_submarine_controls_help.jpg?P1"
      hasImageByCountries = ["ussr"]
      countryRelatedObjs = {
        ussr = [
        ]
      }
      linkLines = {
        links = [
          { start = "sonar_detected_hud_label", end = "sonar_detected_hud_point" }
          { start = "sonar_detected_sonar_label", end = "sonar_detected_sonar_point" }
          { start = "sonar_detected_sonar_label", end = "sonar_detected_map_point" }
          { start = "sonar_detected_direction_label", end = "sonar_detected_direction_point" }
          { start = "depth_current_label", end = "depth_current_point" }
          { start = "depth_selected_label", end = "depth_selected_point" }
          { start = "depth_change_label", end = "depth_change_point" }
          { start = "torpedo_distance_label", end = "torpedo_distance_point" }
          { start = "torpedo_control_mode_label", end = "torpedo_control_mode_point" }
          { start = "torpedo_sonar_mode_label", end = "torpedo_sonar_mode_point" }
          { start = "map_sonar_passive_label", end = "map_sonar_passive_point" }
          { start = "map_sonar_active_label", end = "map_sonar_active_point" }
          { start = "map_acoustic_contermeasures_label", end = "map_acoustic_contermeasures_point" }
        ]
      }
    },

    [help_tab_types.CONTROLLER_AIR] = {
      title = controllerMarkup.title
      showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
      isShow = function(handler, params) {
        return ::getTblValue("showControlsAir", params, false) && ::getTblValue("hasController", params, false)
      }
      pageUnitType = ::g_unit_type.AIRCRAFT
      pageUnitTag = null
      pageBlkName = controllerMarkup.blk
      pageFillfuncName = "initGamepadPage"
    },
    [help_tab_types.CONTROLLER_TANK] = {
      title = controllerMarkup.title
      showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
      isShow = function(handler, params) {
        return ::getTblValue("showControlsTank", params, false) && ::getTblValue("hasController", params, false)
      }
      pageUnitType = ::g_unit_type.TANK
      pageUnitTag = null
      pageBlkName = controllerMarkup.blk
      pageFillfuncName = "initGamepadPage"
    },
    [help_tab_types.CONTROLLER_SHIP] = {
      title = controllerMarkup.title
      showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
      isShow = function(handler, params) {
        return ::getTblValue("showControlsShip", params, false) && ::getTblValue("hasController", params, false)
      }
      pageUnitType = ::g_unit_type.SHIP
      pageUnitTag = null
      pageBlkName = controllerMarkup.blk
      pageFillfuncName = "initGamepadPage"
    },

    [help_tab_types.CONTROLLER_HELICOPTER] = {
      title = controllerMarkup.title
      showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
      isShow = function(handler, params) {
        return ::getTblValue("showControlsHelicopter", params, false) && ::getTblValue("hasController", params, false)
      }
      pageUnitType = ::g_unit_type.HELICOPTER
      pageUnitTag = null
      pageBlkName = controllerMarkup.blk
      pageFillfuncName = "initGamepadPage"
    },

    [help_tab_types.CONTROLLER_SUBMARINE] = {
      title = controllerMarkup.title
      showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
      isShow = @(handler, params) !!params?.showControlsSubmarine && !!params.hasController
      pageUnitType = ::g_unit_type.SHIP
      pageUnitTag = "submarine"
      pageBlkName = controllerMarkup.blk
      pageFillfuncName = "initGamepadPage"
    },

    [help_tab_types.KEYBOARD_AIR] = {
      title = "#controlType/mouse"
      showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
      isShow = function(handler, params) {
        return ::getTblValue("showControlsAir", params, false) && ::getTblValue("hasKeyboard", params, false)
      }
      pageUnitType = ::g_unit_type.AIRCRAFT
      pageUnitTag = null
      pageBlkName = "gui/help/controllerKeyboard.blk"
      pageFillfuncName = "fillAllTexts"
    },
    [help_tab_types.KEYBOARD_TANK] = {
      title = "#controlType/mouse"
      showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
      isShow = function(handler, params) {
        return ::getTblValue("showControlsTank", params, false) && ::getTblValue("hasKeyboard", params, false)
      }
      pageUnitType = ::g_unit_type.TANK
      pageUnitTag = null
      pageBlkName = "gui/help/controllerKeyboard.blk"
      pageFillfuncName = "fillAllTexts"
    },
    [help_tab_types.KEYBOARD_SHIP] = {
      title = "#controlType/mouse"
      showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
      isShow = function(handler, params) {
        return ::getTblValue("showControlsShip", params, false) && ::getTblValue("hasKeyboard", params, false)
      }
      pageUnitType = ::g_unit_type.SHIP
      pageUnitTag = null
      pageBlkName = "gui/help/controllerKeyboard.blk"
      pageFillfuncName = "fillAllTexts"
    },
    [help_tab_types.KEYBOARD_HELICOPTER] = {
      title = "#controlType/mouse"
      showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
      isShow = function(handler, params) {
        return ::getTblValue("showControlsHelicopter", params, false) && ::getTblValue("hasKeyboard", params, false)
      }
      pageUnitType = ::g_unit_type.HELICOPTER
      pageUnitTag = null
      pageBlkName = "gui/help/controllerKeyboard.blk"
      pageFillfuncName = "fillAllTexts"
    },
    [help_tab_types.KEYBOARD_SUBMARINE] = {
      title = "#controlType/mouse"
      showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
      isShow = @(handler, params) !!params?.showControlsSubmarine && !!params.hasKeyboard
      pageUnitType = ::g_unit_type.SHIP
      pageUnitTag = "submarine"
      pageBlkName = "gui/help/controllerKeyboard.blk"
      pageFillfuncName = "fillAllTexts"
    },

    [help_tab_types.MISSION_OBJECTIVES] = {
      title = "#mission_objectives"
      showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.LOADING ]
      isShow = function(handler, params) {
        return ::getTblValue("misHelpBlkPath", params, "") != ""
      }
      pageFillfuncName = "fillMissionObjectivesTexts"
    },
    [help_tab_types.HOTAS4_COMMON] = {
      title = ::is_platform_xboxone? ::loc("presets/xboxone/thrustmaster_hotasOne") : ::loc("presets/ps4/thrustmaster_hotas4")
      showInSets = [ HELP_CONTENT_SET.MISSION, HELP_CONTENT_SET.CONTROLS ]
      isShow = function(handler, params) { return ::check_joystick_thustmaster_hotas(false) }
      pageFillfuncName = "fillHotas4Image"
      pageBlkName = "gui/help/internalHelp.blk"
    }
  }

  kbdKeysRemapByLang = {
    German = { Y = "Z", Z = "Y"}
    French = { Q = "A", A = "Q", W = "Z", Z = "W" }
  }

  function initScreen()
  {
    ::g_hud_event_manager.onHudEvent("helpOpened")

    local isContentMission  = contentSet == HELP_CONTENT_SET.MISSION
    local isContentControls = contentSet == HELP_CONTENT_SET.CONTROLS
    local isContentLoading  = contentSet == HELP_CONTENT_SET.LOADING

    local hasFeatureTanks = ::has_feature("Tanks")

    local currentUnit = ::get_player_cur_unit()

    pageUnitType = currentUnit ? currentUnit.unitType : ::g_unit_type.AIRCRAFT
    if ((pageUnitType == ::g_unit_type.TANK && !hasFeatureTanks))
          pageUnitType = ::g_unit_type.AIRCRAFT

    pageUnitTag = ::is_submarine(currentUnit) ? "submarine" : null

    local hasSubmarineControls  = ::has_feature("SpecialShips") || pageUnitTag == "submarine"

    local basePresets = ::g_controls_manager.getCurPreset().getBasePresetNames()
    local isPresetCustomForPs4 = ::is_platform_ps4 &&
      !::isInArray("default", basePresets) && !::isInArray("dualshock4", basePresets)

    if (isContentMission && ::is_in_flight() || isContentLoading)
    {
      local gm = ::get_game_mode()
      local gt = ::get_game_type_by_mode(gm)
      local needMissionHelp = !!(gt & ::GT_VERSUS)
      if (needMissionHelp)
      {
        local path = ::g_mission_type.getTypeByMissionName(::get_current_mission_name()).helpBlkPath
        if (path != "" && !::u.isEmpty(::DataBlock(path)))
          misHelpBlkPath = path
      }
    }

    local params = {
      showControlsAir  = (isContentControls || pageUnitType == ::g_unit_type.AIRCRAFT && pageUnitTag == null)
      showControlsTank = (isContentControls || pageUnitType == ::g_unit_type.TANK && pageUnitTag == null) && hasFeatureTanks
      showControlsShip = (isContentControls || pageUnitType == ::g_unit_type.SHIP && pageUnitTag == null)
      showControlsHelicopter = (isContentControls || pageUnitType == ::g_unit_type.HELICOPTER && pageUnitTag == null)
      showControlsSubmarine = (isContentControls || pageUnitType == ::g_unit_type.SHIP &&
        pageUnitTag == "submarine") && hasSubmarineControls
      hasController    = ::is_platform_ps4  || ::show_console_buttons
      hasKeyboard      = ::is_platform_pc || ::is_platform_ps4 && isPresetCustomForPs4
      misHelpBlkPath = misHelpBlkPath
    }

    allAvaliableTabs = []
    foreach (tab in tabsCfg)
    {
      if ( ! ::isInArray(contentSet, tab.showInSets) || ! tab.isShow(this, params))
        continue
      allAvaliableTabs.append(tab)
    }

    fillTabs(getPreferableTabId(params))
  }

  function getPreferableTabId(params)
  {
    if (contentSet == HELP_CONTENT_SET.MISSION || contentSet == HELP_CONTENT_SET.CONTROLS)
    {
      local difficulty = ::is_in_flight() ? ::get_mission_difficulty_int() : ::get_current_shop_difficulty().diffCode
      local isNewbie = ::is_me_newbie()
      local isAdvanced = difficulty == ::DIFFICULTY_HARDCORE

      if (::check_joystick_thustmaster_hotas(false) && pageUnitType == ::g_unit_type.AIRCRAFT && pageUnitTag == null)
        return tabsCfg[help_tab_types.HOTAS4_COMMON]
      if (!isNewbie && !isAdvanced && misHelpBlkPath != "")
        return tabsCfg[help_tab_types.MISSION_OBJECTIVES]
      if (!isAdvanced && pageUnitType == ::g_unit_type.AIRCRAFT && pageUnitTag == null)
        return tabsCfg[help_tab_types.IMAGE_AIRCRAFT]
      if (!isAdvanced && pageUnitType == ::g_unit_type.TANK && pageUnitTag == null)
        return tabsCfg[help_tab_types.IMAGE_TANK]
      if (!isAdvanced && pageUnitType == ::g_unit_type.SHIP && pageUnitTag == null)
        return tabsCfg[help_tab_types.IMAGE_SHIP]
      if (!isAdvanced && pageUnitType == ::g_unit_type.HELICOPTER && pageUnitTag == null)
        return tabsCfg[help_tab_types.IMAGE_HELICOPTER]
      if (!isAdvanced && pageUnitType == ::g_unit_type.SHIP && pageUnitTag == "submarine")
        return tabsCfg[help_tab_types.IMAGE_SUBMARINE]
      if (params.hasController && pageUnitType == ::g_unit_type.AIRCRAFT && pageUnitTag == null)
        return tabsCfg[help_tab_types.CONTROLLER_AIR]
      if (params.hasController && pageUnitType == ::g_unit_type.TANK && pageUnitTag == null)
        return tabsCfg[help_tab_types.CONTROLLER_TANK]
      if (params.hasController && pageUnitType == ::g_unit_type.SHIP && pageUnitTag == null)
        return tabsCfg[help_tab_types.CONTROLLER_SHIP]
      if (params.hasController && pageUnitType == ::g_unit_type.HELICOPTER && pageUnitTag == null)
        return tabsCfg[help_tab_types.CONTROLLER_HELICOPTER]
      if (params.hasController && pageUnitType == ::g_unit_type.SHIP && pageUnitTag == "submarine")
        return tabsCfg[help_tab_types.CONTROLLER_SUBMARINE]
      if (params.hasKeyboard && pageUnitType == ::g_unit_type.AIRCRAFT && pageUnitTag == null)
        return tabsCfg[help_tab_types.KEYBOARD_AIR]
      if (params.hasKeyboard && pageUnitType == ::g_unit_type.TANK && pageUnitTag == null)
        return tabsCfg[help_tab_types.KEYBOARD_TANK]
      if (params.hasKeyboard && pageUnitType == ::g_unit_type.SHIP && pageUnitTag == null)
        return tabsCfg[help_tab_types.KEYBOARD_SHIP]
      if (params.hasKeyboard && pageUnitType == ::g_unit_type.HELICOPTER && pageUnitTag == null)
        return tabsCfg[help_tab_types.KEYBOARD_HELICOPTER]
      if (params.hasKeyboard && pageUnitType == ::g_unit_type.SHIP && pageUnitTag == "submarine")
        return tabsCfg[help_tab_types.KEYBOARD_SUBMARINE]
    }

    return null
  }

  function fillTabs(preselectedTab)
  {
    local tabsObj = scene.findObject("tabs_list")
    local view = {
      tabs = []
    }
    local preselectedTabId = -1
    foreach (tabGroup in tabGroups)
    {
      local firstAvaliableSubTab = null
      foreach (tabType in tabGroup.list)
      {
        if(::isInArray(tabsCfg[tabType], allAvaliableTabs))
        {
          if( ! firstAvaliableSubTab)
            firstAvaliableSubTab = tabsCfg[tabType]
          if(tabsCfg[tabType] == preselectedTab)
            preselectedTabId = view.tabs.len()
        }
      }

      local tabName = ::getTblValue("title", tabGroup)
      if ( ! tabName && firstAvaliableSubTab)
        tabName = ::getTblValue("title", firstAvaliableSubTab, "")
      view.tabs.push({
        tabName = tabName
        hidden = firstAvaliableSubTab == null
      })
    }
    local data = ::handyman.renderCached("gui/frameHeaderTabs", view)
    guiScene.replaceContentFromText(tabsObj, data, data.len(), this)
    setValidIndex(tabsObj, preselectedTabId)
  }

  function fillSubTabs(preselectedTab)
  {
    local subTabsObj = scene.findObject("sub_tabs_list")
    if ( ! ::check_obj(subTabsObj))
      return
    subTabsObj.enable(true)
    subTabsObj.show(true)
    local view = {
      tabs = []
    }
    local preselectedTabId = -1
    local currentTabGroup = ::getTblValue(curTabIdx, tabGroups, tabGroups[0])

    currentSubTabs = []
    foreach (tabType in currentTabGroup.list)
    {
      local currentTab = tabsCfg[tabType]
      if( ! ::isInArray(currentTab, allAvaliableTabs))
        continue
      if(currentTab == preselectedTab)
        preselectedTabId = view.tabs.len()
      view.tabs.push({
        tabName = currentTab.title
      })
      currentSubTabs.push(currentTab)
    }
    local data = ::handyman.renderCached("gui/frameHeaderTabs", view)
    guiScene.replaceContentFromText(subTabsObj, data, data.len(), this)
    setValidIndex(subTabsObj, preselectedTabId)
    local isVisible = (view.tabs.len() > 1)
    subTabsObj.enable(isVisible)
    subTabsObj.show(isVisible)
  }

  function onHelpSheetChange(obj)
  {
    local selTabIdx = obj.getValue()
    if (curTabIdx == selTabIdx)
      return

    curTabIdx = selTabIdx
    curSubTabIdx = -1
    fillSubTabs(null)
  }

  function onHelpSubSheetChange(obj)
  {
    local selTabIdx = obj.getValue()
    if (curSubTabIdx == selTabIdx)
      return
    curSubTabIdx = selTabIdx

    local tab = ::getTblValue(curSubTabIdx, currentSubTabs)
    if (!tab)
      return

    pageUnitType = ::getTblValue("pageUnitType", tab, pageUnitType)
    pageUnitTag = ::getTblValue("pageUnitTag", tab, pageUnitTag)

    local sheetObj = scene.findObject("help_sheet")
    local pageBlkName = ::getTblValue("pageBlkName", tab, "")
    if (!::u.isEmpty(pageBlkName))
      guiScene.replaceContent(sheetObj, pageBlkName, this)

    local fillFuncName = ::getTblValue("pageFillfuncName", tab)
    local fillFunc = fillFuncName ? ::getTblValue(fillFuncName, this) : fillHelpPage
    fillFunc()

    showTabSpecificControls(tab)
    guiScene.performDelayed(this, function() {
      if (!isValid())
        return

      fillTabLinkLines(tab)
    })
  }

  function showTabSpecificControls(tab)
  {
    local countryRelatedObjs = ::getTblValue("countryRelatedObjs", tab, null)
    if (countryRelatedObjs != null)
    {
      local selectedCountry = ::get_profile_country_sq().slice(8)
      selectedCountry = (selectedCountry in countryRelatedObjs) ? selectedCountry : tab.defaultValues.country
      local selectedCountryConfig = countryRelatedObjs[selectedCountry]
      foreach(key, countryConfig in countryRelatedObjs)
        foreach (idx, value in countryConfig)
        {
          local obj = scene.findObject(value)
          if (::checkObj(obj))
            obj.show(::isInArray(value, selectedCountryConfig))
        }
    }
  }

  function fillTabLinkLines(tab)
  {
    local linkLines = ::getTblValue("linkLines", tab, null)
    scene.findObject("link_lines_block").show(linkLines != null)
    if (linkLines == null)
      return

    //Need for update elements visible
    guiScene.applyPendingChanges(false)

    local linkContainer = scene.findObject("help_sheet")
    local linkLinesConfig = {
      startObjContainer = linkContainer
      endObjContainer = linkContainer
      lineInterval = ::getTblValue("lineInterval", linkLines, defaultLinkLinesInterval)
      links = linkLines?.links ?? []
      obstacles = ::getTblValue("obstacles", linkLines, null)
    }
    local linesData = ::LinesGenerator.getLinkLinesMarkup(linkLinesConfig)
    guiScene.replaceContentFromText(scene.findObject("link_lines_block"), linesData, linesData.len(), this)
  }

  function fillHelpPage()
  {
    local tab = ::getTblValue(curSubTabIdx, currentSubTabs)

    local basePresets = ::g_controls_manager.getCurPreset().getBasePresetNames()
    local haveIconsForControls = ::is_xinput_device() ||
      ::isInArray("keyboard", basePresets) || ::isInArray("keyboard_shooter", basePresets)
    showDefaultControls(haveIconsForControls)
    if ("moveControlsFrames" in tab)
      tab.moveControlsFrames(haveIconsForControls, scene)

    local backImg = scene.findObject("help_background_image")
    local curCountry = ::get_profile_country_sq().slice(8)
    if ("hasImageByCountries" in tab)
      curCountry = ::isInArray(curCountry, tab.hasImageByCountries)
                     ? curCountry
                     : tab.defaultValues.country

    backImg["background-image"] = ::format(::getTblValue("imagePattern", tab, ""), curCountry)
    fillActionBar(tab)
    updatePlatformControls()
  }

  //---------------------------- HELPER FUNCTIONS ----------------------------//

  function setValidIndex(obj, index)
  {
    local childrenCount = obj.childrenCount()
    index = ::clamp(index, 0, childrenCount - 1)
    local child = obj.getChild(index)
    if (child.isVisible() && child.isEnabled())
    {
      obj.setValue(index)
      return
    }

    for(local i = 0; i < childrenCount; i++)
    {
      child = obj.getChild(i)
      if (child.isVisible() && child.isEnabled())
      {
        obj.setValue(i)
        return
      }
    }
  }

  function getModifierSymbol(id)
  {
    if (id in modifierSymbols)
      return modifierSymbols[id]

    foreach(item in ::shortcutsAxisList)
      if (typeof(item) == "table" && item.id==id)
      {
        if ("symbol" in item)
          modifierSymbols[id] <- "<color=@axisSymbolColor>" + ::loc(item.symbol) + ::loc("ui/colon") + "</color>"
        return modifierSymbols[id]
      }

    modifierSymbols[id] <- ""
    return modifierSymbols[id]
  }

  function fillAllTexts()
  {
    remapKeyboardKeysByLang()

    local scTextFull = ["", "", ""]
    local scRowId = 0;
    local tipTexts = {} //btnName = { text, isMain }
    modifierSymbols = {}

    local shortcutsList  =
      (pageUnitType == ::g_unit_type.AIRCRAFT   && pageUnitTag == null) ? ::controlsHelp_shortcuts :
      (pageUnitType == ::g_unit_type.TANK       && pageUnitTag == null) ? ::controlsHelp_shortcuts_ground :
      (pageUnitType == ::g_unit_type.SHIP       && pageUnitTag == null) ? ::controlsHelp_shortcuts_naval :
      (pageUnitType == ::g_unit_type.HELICOPTER && pageUnitTag == null) ? ::controlsHelp_shortcuts_helicopter :
      (pageUnitType == ::g_unit_type.SHIP       && pageUnitTag == "submarine")  ? ::controlsHelp_shortcuts_submarine :
      []
    for(local i=0; i<shortcutsList.len(); i++)
    {
      local item = shortcutsList[i]
      local name = (typeof(item)=="table")? item.id : item
      local isAxis = typeof(item)=="table" && ("axisShortcuts" in item)
      local isHeader = typeof(item)=="table" && ("type" in item) && (item.type== CONTROL_TYPE.HEADER)
      local shortcutNames = []
      local scText = ""

      if (isHeader)
      {
        local text = ::loc("hotkeys/" + name);
        scText = "<color=@white>" + text + "</color>";
        if (i > 0)
          scRowId++;
      }
      else
      {
        if (isAxis)
          for(local sc=0; sc<item.axisShortcuts.len(); sc++)
            shortcutNames.append(name + ((item.axisShortcuts[sc]=="")?"" : "_" + item.axisShortcuts[sc]))
        else
          shortcutNames.append(name)

        local shortcuts = ::get_shortcuts(shortcutNames)
        local btnList = {} //btnName = isMain

        //--- F1 help window ---
        for(local sc=0; sc<shortcuts.len(); sc++)
        {
          local text = getShortcutText(shortcuts[sc], btnList, true)
          if (text!="" && (!isAxis || item.axisShortcuts[sc] != "")) //do not show axis text (axis buttons only)
            scText += ((scText!="")? ";  ":"") +
            (isAxis? getModifierSymbol(item.axisShortcuts[sc]) : "") +
            text;
        }

        scText = ::loc((isAxis? "controls/":"hotkeys/") + name) + ::loc("ui/colon") + scText

        foreach(btnName, isMain in btnList)
          if (btnName in tipTexts)
          {
            tipTexts[btnName].isMain = tipTexts[btnName].isMain || isMain
            if (isMain)
              tipTexts[btnName].text = scText + "\n" + tipTexts[btnName].text
            else
              tipTexts[btnName].text += "\n" + scText
          } else
            tipTexts[btnName] <- { text = scText, isMain = isMain }
      }

      if (scText!="" && scRowId<scTextFull.len())
        scTextFull[scRowId] += ((scTextFull[scRowId]=="")? "" : "\n") + scText
    }

    //set texts and tooltips
    foreach(idx, text in scTextFull)
      scene.findObject("full_shortcuts_texts"+idx).setValue(text)
    local kbdObj = scene.findObject("keyboard_div")
    foreach(btnName, btn in tipTexts)
    {
      local objId = ::stringReplace(btnName, " ", "_")
      local tipObj = kbdObj.findObject(objId)
      if (tipObj)
      {
        tipObj.tooltip = btn.text
        if (btn.isMain)
          tipObj.mainKey = "yes"
      } else
        dagor.debug("tipObj = " + btn + " not found in the scene!")
    }
  }

  function remapKeyboardKeysByLang()
  {
    local map = ::getTblValue(::g_language.getLanguageName(), kbdKeysRemapByLang)
    if (!map)
      return
    local kbdObj = scene.findObject("keyboard_div")
    if (!::checkObj(kbdObj))
      return

    local replaceData = {}
    foreach(key, val in map)
    {
      local textObj = kbdObj.findObject(val)
      replaceData[val] <- {
        obj = kbdObj.findObject(key)
        text = (::checkObj(textObj) && textObj.text) || val
      }
    }
    foreach(id, data in replaceData)
      if (data.obj.isValid())
      {
        data.obj.id = id
        data.obj.setValue(data.text)
      }
  }

  function getShortcutText(shortcut, btnList, color = true)
  {
    local scText = ""
    local curPreset = ::g_controls_manager.getCurPreset()
    for(local i=0; i<shortcut.len(); i++)
    {
      local sc = shortcut[i]
      if (!sc) continue

      local text = ""
      for (local k = 0; k < sc.dev.len(); k++)
      {
        text += ((k != 0)? " + ":"") + ::getLocalizedControlName(curPreset, sc.dev[k], sc.btn[k])
        local btnName = curPreset.getButtonName(sc.dev[k], sc.btn[k])
        if (btnName=="MWUp" || btnName=="MWDown")
          btnName = "MMB"
        if (btnName in btnList)
          btnList[btnName] = btnList[btnName] || (i==0)
        else
          btnList[btnName] <- (i==0)
      }
      if (text!="")
        scText += ((scText!="")? ", ":"") + (color? ("<color=@hotkeyColor>" + text + "</color>") : text)
    }
    return scText
  }

  function initGamepadPage()
  {
    guiScene.setUpdatesEnabled(false, false)
    updateGamepadIcons()
    updateGamepadTexts()
    guiScene.setUpdatesEnabled(true, true)
  }

  function updateGamepadIcons()
  {
    foreach(name, val in gamepadIcons.fullIconsList)
    {
      local obj = scene.findObject("ctrl_img_" + name)
      if (::check_obj(obj))
        obj["background-image"] = gamepadIcons.getTexture(name, controllerMarkup.iconsPreset)
    }
  }

  function updateGamepadTexts()
  {
    local forceButtons = (pageUnitType == ::g_unit_type.AIRCRAFT) ? ["camx"] : (pageUnitType == ::g_unit_type.TANK) ? ["ID_ACTION_BAR_ITEM_5"] : []
    local ignoreButtons = ["ID_CONTINUE_SETUP"]
    local ignoreAxis = ["camx", "camy"]
    local customLocalization = { ["camx"] = "controls/help/camx" }

    local curJoyParams = ::JoystickParams()
    curJoyParams.setFrom(::joystick_get_cur_settings())
    local axisIds = [
      { id="joy_axis_l", x=0, y=1 }
      { id="joy_axis_r", x=2, y=3 }
    ]

    local joystickButtons = array(gamepadIcons.TOTAL_BUTTON_INDEXES, null)
    local joystickAxis = array(axisIds.len()*2, null)

    local shortcutNames = []
    local ignoring = false
    for (local i=0; i<::shortcutsList.len(); i++)
    {
      local item = ::shortcutsList[i]
      local name = item.id
      local type = item.type

      if (type == CONTROL_TYPE.HEADER)
        ignoring = ("unitType" in item) && (item.unitType != pageUnitType || ::getTblValue("unitTag", item, null) != pageUnitTag)
      if (ignoring)
        continue

      local isAxis = type == CONTROL_TYPE.AXIS
      local needCheck = isAxis || (type == CONTROL_TYPE.SHORTCUT || type == CONTROL_TYPE.AXIS_SHORTCUT)

      if (needCheck)
      {
        if (isAxis)
        {
          if (::isInArray(name, forceButtons))
            shortcutNames.append(name) // Puts "camx" axis as a shortcut.
          if (::isInArray(name, ignoreAxis))
            continue

          local axisIndex = ::get_axis_index(name)
          local axisId = curJoyParams.getAxis(axisIndex).axisId
          if (axisId != -1 && axisId < joystickAxis.len())
          {
            joystickAxis[axisId] = joystickAxis[axisId] || []
            joystickAxis[axisId].append(name)
          }

        }
        else if (!::isInArray(name, ignoreButtons) || ::isInArray(name, forceButtons))
          shortcutNames.append(name)
      }
    }

    local shortcuts = ::get_shortcuts(shortcutNames)
    foreach (i, item in shortcuts)
    {
      if (item.len() == 0)
        continue

      foreach(itemIdx, itemButton in item)
      {
        if (itemButton.dev.len() > 1) ///!!!TEMP: need to understand, how to show doubled/tripled/etc. shortcuts
          continue

        foreach(idx, devId in itemButton.dev)
          if (devId == ::JOYSTICK_DEVICE_0_ID)
          {
            local btnId = itemButton.btn[idx]
            if (!(btnId in joystickButtons))
              continue

            joystickButtons[btnId] = joystickButtons[btnId] || []
            joystickButtons[btnId].append(shortcutNames[i])
          }
      }
    }

    local bullet = "-"+ ::nbsp
    foreach (btnId, actions in joystickButtons)
    {
      local idSuffix = gamepadIcons.getButtonNameByIdx(btnId)
      if (idSuffix == "")
        continue

      local tObj = scene.findObject("joy_" + idSuffix)
      if (::checkObj(tObj))
      {
        local title = ""
        local tooltip = ""

        if (actions)
        {
          local titlesCount = 0
          local sliceBtn = "button"
          local sliceDirpad = "dirpad"
          local slicedSuffix = idSuffix.slice(0, 6)
          local maxActionsInTitle = 2
          if (slicedSuffix == sliceBtn || slicedSuffix == sliceDirpad)
            maxActionsInTitle = 1

          for (local a=0; a<actions.len(); a++)
          {
            local actionId = actions[a]

            local shText = ::loc("hotkeys/" + actionId)
            if (::getTblValue(actionId, customLocalization, null))
              shText = ::loc(customLocalization[actionId])

            if (titlesCount < maxActionsInTitle)
            {
              title += (title.len()? (::loc("ui/semicolon") + "\n"): "") + shText
              titlesCount++
            }

            tooltip += (tooltip.len()? "\n" : "") + bullet + shText
          }
        }
        title = title.len()? title : "---"
        tooltip = tooltip.len()? tooltip : ::loc("controls/unmapped")
        tooltip = ::loc("controls/help/press") + ::loc("ui/colon") + "\n" + tooltip
        tObj.setValue(title)
        tObj.tooltip = tooltip
      }
    }

    foreach (axis in axisIds)
    {
      local tObj = scene.findObject(axis.id)
      if (::checkObj(tObj))
      {
        local actionsX = (axis.x < joystickAxis.len() && joystickAxis[axis.x])? joystickAxis[axis.x] : []
        local actionsY = (axis.y < joystickAxis.len() && joystickAxis[axis.y])? joystickAxis[axis.y] : []

        local actionIdX = actionsX.len()? actionsX[0] : null
        local isIgnoredX = actionIdX && isInArray(actionIdX, ignoreAxis)
        local titleX = (actionIdX && !isIgnoredX)? ::loc("controls/" + actionIdX) : "---"

        local actionIdY = actionsY.len()? actionsY[0] : null
        local isIgnoredY = actionIdY && isInArray(actionIdY, ignoreAxis)
        local titleY = (actionIdY && !isIgnoredY)? ::loc("controls/" + actionIdY) : "---"

        local tooltipX = ""
        for (local a=0; a<actionsX.len(); a++)
          tooltipX += (tooltipX.len()? "\n" : "") + bullet + ::loc("controls/" + actionsX[a])
        tooltipX = tooltipX.len()? tooltipX : ::loc("controls/unmapped")
        tooltipX = ::loc("controls/help/mouse_aim_x") + ::loc("ui/colon") + "\n" + tooltipX

        local tooltipY = ""
        for (local a=0; a<actionsY.len(); a++)
          tooltipY += (tooltipY.len()? "\n" : "") + bullet + ::loc("controls/" + actionsY[a])
        tooltipY = tooltipY.len()? tooltipY : ::loc("controls/unmapped")
        tooltipY = ::loc("controls/help/mouse_aim_y") + ::loc("ui/colon") + "\n" + tooltipY

        local title = titleX + " + " + titleY
        local tooltip = tooltipX + "\n\n" + tooltipY
        tObj.setValue(title)
        tObj.tooltip = tooltip
      }
    }

    local tObj = scene.findObject("joy_btn_share")
    if (::checkObj(tObj))
    {
      local title = ::loc(controllerMarkup.btnBackLocId)
      tObj.setValue(title)
      tObj.tooltip = ::loc("controls/help/press") + ::loc("ui/colon") + "\n" + title
    }

    local mouseObj = scene.findObject("joy_mouse")
    if (::checkObj(mouseObj))
    {
      local mouse_aim_x = (pageUnitType == ::g_unit_type.AIRCRAFT) ? "controls/mouse_aim_x" : "controls/gm_mouse_aim_x"
      local mouse_aim_y = (pageUnitType == ::g_unit_type.AIRCRAFT) ? "controls/mouse_aim_y" : "controls/gm_mouse_aim_y"

      local joyParams = ::joystick_get_cur_settings()
      local titleX = ::loc(mouse_aim_x)
      local titleY = ::loc(mouse_aim_y)
      local title = titleX + " + " + titleY
      local tooltipX = ::loc("controls/help/mouse_aim_x") + ::loc("ui/colon") + "\n" + ::loc(mouse_aim_x)
      local tooltipY = ::loc("controls/help/mouse_aim_y") + ::loc("ui/colon") + "\n" + ::loc(mouse_aim_y)
      local tooltip = tooltipX + "\n\n" + tooltipY
      mouseObj.setValue(title)
      mouseObj.tooltip = tooltip
    }
  }

  function showDefaultControls(isDefaultControls)
  {
    local tab = ::getTblValue(curSubTabIdx, currentSubTabs)
    local frameForHideIds = ::getTblValue("defaultControlsIds", tab, [])
    foreach (item in frameForHideIds)
      if ("frameId" in item)
        scene.findObject(item.frameId).show(isDefaultControls)

    local defControlsFrame = showSceneBtn("not_default_controls_frame", !isDefaultControls)
    if (isDefaultControls || !defControlsFrame)
      return

    local view = {
      rows = []
    }
    foreach (item in frameForHideIds)
    {
      local shortcutId = ::getTblValue("shortcut", item)
      if (!shortcutId)
        continue

      local rowData = {
        text = ::loc("controls/help/"+shortcutId+"_0")
        shortcutMarkup = ::g_shortcut_type.getShortcutMarkup(shortcutId)
      }
      view.rows.append(rowData)
    }

    local markup = ::handyman.renderCached("gui/help/helpShortcutsList", view)
    guiScene.replaceContentFromText(defControlsFrame, markup, markup.len(), this)
  }

  function updatePlatformControls()
  {
    local isGamepadPreset = ::is_xinput_device()

    local buttonsList = {
      controller_switching_ammo = isGamepadPreset
      keyboard_switching_ammo = !isGamepadPreset
      controller_smoke_screen_label = isGamepadPreset
      smoke_screen_label = !isGamepadPreset
      controller_medicalkit_label = isGamepadPreset
      medicalkit_label = !isGamepadPreset
    }

    ::showBtnTable(scene, buttonsList)

  }

  function fillMissionObjectivesTexts()
  {
    if (misHelpBlkPath == "")
      return
    local sheetObj = scene.findObject("help_sheet")
    guiScene.replaceContent(sheetObj, misHelpBlkPath, this)

    local airCaptureZoneDescTextObj = scene.findObject("air_capture_zone_desc")
    if (::checkObj(airCaptureZoneDescTextObj))
    {
      local altitudeBottom = 0
      local altitudeTop = 0

      local misInfoBlk = ::get_mission_meta_info(::get_current_mission_name())
      local misBlk = misInfoBlk && misInfoBlk.mis_file && ::DataBlock(misInfoBlk.mis_file)
      local areasBlk = misBlk && misBlk.areas
      if (areasBlk)
      {
        for (local i = 0; i < areasBlk.blockCount(); i++)
        {
          local block = areasBlk.getBlock(i)
          if (block && block.type == "Cylinder" && ::u.isTMatrix(block.tm))
          {
            altitudeBottom = ::ceil(block.tm[3].y)
            altitudeTop = ::ceil(block.tm[1].y + block.tm[3].y)
            break
          }
        }
      }

      if (altitudeBottom && altitudeTop)
      {
        airCaptureZoneDescTextObj.setValue(::loc("hints/tutorial_newbie/air_domination/air_capture_zone") + " " +
          ::loc("hints/tutorial_newbie/air_domination/air_capture_zone/altitudes", {
          altitudeBottom = ::colorize("userlogColoredText", altitudeBottom),
          altitudeTop = ::colorize("userlogColoredText", altitudeTop)
          }))
      }
    }
  }

  function fillHotas4Image()
  {
    local imgObj = scene.findObject("image")
    if (!::checkObj(imgObj))
      return

    imgObj["background-image"] = ::loc("thrustmaster_tflight_hotas_4_controls_image", "")
  }

  function afterModalDestroy()
  {
    if (isStartedFromMenu)
    {
      local curHandler = ::handlersManager.getActiveBaseHandler()
      if (curHandler != null && curHandler instanceof ::gui_handlers.FlightMenu)
        curHandler.onResumeRaw()
    }
  }

  function fillActionBar(tab)
  {
    local actionBarItems = tab?.actionBarItems
    if (!actionBarItems || actionBarItems.len() <= 0)
      return

    local nest = scene.findObject("action_bar_place")
    local items = []
    foreach (item in actionBarItems)
      items.append(buildItemView(item))

    local view = {
      items = items
    }
    local blk = ::handyman.renderCached(("gui/help/helpActionBarItem"), view)
    guiScene.replaceContentFromText(nest, blk, blk.len(), this)
  }

  function buildItemView(item)
  {
    local actionBarType = ::g_hud_action_bar_type.getByActionItem(item)
    local viewItem = {}

    viewItem.id                 <- item.id
    viewItem.selected           <- item?.selected ? "yes" : "no"
    viewItem.active             <- item?.active ? "yes" : "no"

    if (item.type == ::EII_BULLET)
      viewItem.icon <- item.icon
    else
      viewItem.icon <- actionBarType.getIcon()

    return viewItem
  }
}

//----------------------------- GLOBAL FUNCTIONS -----------------------------//

function get_shortcut_frame_for_help(shortcut)
{
  local data = "";
  if (!shortcut)
    return "text { text-align:t='center'; text:t='---' }"

  local curPreset = ::g_controls_manager.getCurPreset()
  for (local k = 0; k < shortcut.dev.len(); k++)
  {
    local name = ::getLocalizedControlName(curPreset, shortcut.dev[k], shortcut.btn[k]);
    local buttonFrame = format("controlsHelpBtn { text:t='%s'; font:t='%s' }", ::g_string.stripTags(name), (name.len()>2)? "@fontTiny" : "@fontMedium");

    if (shortcut.dev[k] == ::STD_MOUSE_DEVICE_ID)
    {
      local mouseBtnImg = "controlsHelpMouseBtn { background-image:t='#ui/gameuiskin#%s'; }"
      if (shortcut.btn[k] == 0)
        buttonFrame = format(mouseBtnImg, "mouse_left");
      else if (shortcut.btn[k] == 1)
        buttonFrame = format(mouseBtnImg, "mouse_right");
      else if (shortcut.btn[k] == 2)
        buttonFrame = format(mouseBtnImg, "mouse_center");
    }

    if (shortcut.dev[k] == ::JOYSTICK_DEVICE_0_ID)
    {
      local btnId = shortcut.btn[k]
      if (gamepadIcons.hasTextureByButtonIdx(btnId))
        buttonFrame = format("controlsHelpJoystickBtn { background-image:t='%s' }",
          gamepadIcons.getTextureByButtonIdx(btnId))
    }

    data += ((k != 0)? "text { pos:t='0,0.5ph-0.5h';position:t='relative';text-align:t='center';text:t='+'}":"") + buttonFrame;
  }

  return data;
}

