function is_version_equals_or_newer(verTxt) // "1.43.7.75"
{
  if (!("get_game_version" in ::getroottable()))
    return false
  local cur = ::get_game_version()
  return cur == 0 || cur >= ::get_version_int_from_string(verTxt)
}

function is_version_equals_or_older(verTxt) // "1.61.1.37"
{
  if (!("get_game_version" in ::getroottable()))
    return true
  local cur = ::get_game_version()
  return cur != 0 && cur <= ::get_version_int_from_string(verTxt)
}

function get_version_int_from_string(versionText)
{
  local res = 0
  local list = ::split(versionText, ".")
  local intRegExp = regexp2(@"\D+")
  for(local i = list.len()-1; i >= 0; i--)
  {
    local val = list[i]
    if (intRegExp.match(val))
    {
      ::dagor.assertf(false, "Error: cant convert version text to int: " + versionText)
      break
    }
    res += val.tointeger() << (8 * (list.len() - i - 1))
  }
  return res
}

//--------------------------------------------------------------------//
//!!!!!!!!!!!!!!!!!!!IMPORTANT COMPATIBILITIES!!!!!!!!!!!!!!!!!!!!!!!!//
//------must be in all versions becoase of used before login----------//
//--------------------------------------------------------------------//
::compatibility_main <- {
  DM_VIEWER_NONE = 0 //appear in 1_43_9_x

  HIT_CAMERA_FINISH = 12 //appear in 1_43_9_x  //hud in old versions can be called before login
  HIT_CAMERA_START = 11  //appear in 1_43_9_x

  get_config_name           = function()     { return "config.blk" } //appear in 1_43_10_x
  get_dgs_tex_quality       = function()     { return 0 }

  script_net_assert = function(error) { dagor.debug("Exception:" + error) }
  is_gui_webcache_enabled = function() { return false }

  is_option_free_camera_inertia_exist = ("OPTION_FREE_CAMERA_INERTIA" in getroottable())
  is_option_replay_camera_wiggle_exist = ("OPTION_REPLAY_CAMERA_WIGGLE" in getroottable())
}

::apply_compatibilities(::compatibility_main)
compatibility_main <- null

if (!("set_control_helpers_mode" in getroottable())) // func was renamed
  set_control_helpers_mode <- ::set_helpers_mode

//--------------------------------------------------------------------//
//!!!!!!!!!!!!!!!!END OF IMPORTANT COMPATIBILITIES!!!!!!!!!!!!!!!!!!!!!//
//--------------------------------------------------------------------//

//--------------------------------------------------------------------//
//----------------------COMPATIBILITIES BY VERSIONS-------------------//
// -----------can be removed after version reach all platforms--------//
//--------------------------------------------------------------------//

//----------------------------wop_1_59_X_X---------------------------------//
::apply_compatibilities({
  EULT_INVITE_TO_TOURNAMENT = 51

  EATT_BUYING_AIRCRAFT        = 0
  EATT_BUYING_AIRCRAFT_CREW   = 1
  EATT_LOADING                = 2
  EATT_SAVING                 = 3
  EATT_UPDATE_ENTITLEMENTS    = 4
  EATT_BUY_ENTITLEMENT        = 5
  EATT_REPAIR_AIRCRAFT        = 7
  EATT_BUYING_WEAPON          = 8
  EATT_BUYING_MODIFICATION    = 9
  EATT_BUYING_SLOT            = 10
  EATT_TRAINING_AIRCRAFT      = 11
  EATT_SEND_BLK               = 13
  EATT_COMPLAINT              = 17
  EATT_ENABLE_MODIFICATIONS   = 23
  EATT_SET_EXTERNAL_ID        = 35
  EATT_CLAN_TRANSACTION       = 36
  EATT_CLANSYNCPROFILE        = 44
  EATT_BUYING_UNLOCK          = 45

  gui_start_logo = function()
  {
    gui_start_startscreen()
  }

  gui_start_logo_force = function()
  {
    gui_start_startscreen()
  }

  char_request_blk_from_server = function(...) { return -1 }

  enable_keyboard_layout_change_tracking = function(en)
  {
  }

  enable_keyboard_locks_change_tracking = function(en)
  {
  }

  get_steam_link_token = function() { return "" }
  hangar_save_current_attachables = function() {}
  hangar_save_current_decal = function() {}

  get_meta_mission_info_by_name = function(name) { return get_meta_mission_info("name", name) }
  get_skins_for_unit = function(name) { return [ { name = "" } ] }
  clan_get_current_season_info = function() {
    return {
      rewardDay = ::get_next_clan_duel_reward_day()
      startDay  = ::get_charserver_time_sec()
      numberInYear  = 0
      ordinalNumber = 0
    }
  }
})

//----------------------------wop_1_61_1_X---------------------------------//

// Temporary fix for ::mktime() for client version 1.61.1.37 and older.
if (::is_version_equals_or_older("1.61.1.37") && ("mktime" in getroottable()) && !("_mktime" in getroottable()))
{
  ::_mktime <- ::mktime
  ::mktime = function(timeTbl) {
    if (!::g_login.isLoggedIn())
      return ::_mktime(timeTbl)

    local precisionMaxSec = 600
    local tLocal = ::_mktime(::get_local_time())
    local tChar  = ::get_charserver_time_sec()
    local shift = tLocal - tChar
    if (::abs(::abs(shift) - 3600) > precisionMaxSec)
    {
      ::mktime = ::_mktime
      dagor.debug("LOCAL TIME DST FIX = 0")
    }
    else
    {
      local dstFix = shift > 0 ? -3600 : 3600
      ::mktime = (@(dstFix) function(timeTbl) {
        local res = ::_mktime(timeTbl)
        return (res >= 3600) ? (res + dstFix) : res
      })(dstFix)
      dagor.debug("LOCAL TIME DST FIX = " + dstFix)
    }

    return ::mktime(timeTbl)
  }
}

::apply_compatibilities({
  ww_get_operation_time_millisec = function() { return 1000 * get_charserver_time_sec() }
  DM_HIT_RESULT_METAPART = 7
  DM_HIT_RESULT_AMMO     = 8
  DM_HIT_RESULT_FUEL     = 9
  DM_HIT_RESULT_CREW     = 10
  DM_HIT_RESULT_TORPEDO  = 11
  EULT_WW_START_OPERATION = 52
  EULT_WW_END_OPERATION = 53
  EULT_WW_CREATE_OPERATION = 54
  is_nvidia_ansel_allowed = function() { return false }

  // PS4UpdaterModal

  UPDATER_CHECKING_FAST = 0
  UPDATER_CHECKING = 1
  UPDATER_DOWNLOADING_YUP = 2
  UPDATER_RESPATCH = 3
  UPDATER_DOWNLOADING = 4
  UPDATER_PURIFYING = 5
  UPDATER_COPYING = 6

  UPDATER_CB_STAGE = 0
  UPDATER_CB_PROGRESS = 1
  UPDATER_CB_ERROR = 2
  UPDATER_CB_FINISH = 3

  ps4_start_updater = function(param1, param2, param3) { return false }
  ps4_stop_updater = function(){}
  ps4_load_after_login = function(){}

  ww_update_popuped_armies_name = function(array) {}
})

//----------------------------wop_1_63_2_X---------------------------------//

::apply_compatibilities({
  ps4_is_production_env = function() { return true }
  set_controls_preset_ext = function(...) {}
  ww_preview_operation = function(...) { return -1 }
  ww_stop_preview = function() {}
  ww_enable_render_map_category_for_preveiw = function() {}
  ww_mark_zones_as_outlined_by_name = function(zonesNames)  {return true}
  pick_globe_operation = function(...) {}
  ww_get_operation_winner = function() { return ::SIDE_NONE }
  briefing_finish = function() { ::loading_press_apply() }

  set_allowed_controls_mask = function(mask) {}
  set_ingame_shortcuts_active = function(value) {}

  add_big_query_record = function(event, params) {}

  get_mplayers_count = function(team, includeLeftPlayers)
  {
    return ::get_mplayers_list(team, includeLeftPlayers).len()
  }
})

//----------------------------wop_1_63_3_X---------------------------------//

::apply_compatibilities({
  get_cur_unit_weapon_preset = function() { return get_flightmodel_weapon_preset() }

  AF_VIEW_ACCESS = 1
  AF_PLAY_ACCESS = 2
  AF_PLAY_LOCKED = 4
  AF_FULL_ACCESS = 3

  get_tournament_access_flags = function(tournamentName) { return AF_FULL_ACCESS }

  UT_ARTILLERY = 5
  UT_TOTAL = 6

  set_use_gamepad_cursor_control = function (val) {}

  get_option_speech_country_type = function() { return 0 }
  set_option_speech_country_type = function(value) { }

  get_option_hangar_sound = function() { return 1 }
  set_option_hangar_sound = function(value) { }

  get_mp_session_id = function() { return "" }

  is_unlock_need_popup_in_menu = function (unlockId) { return false }

  steam_get_my_id = function() { return "" }

  get_bots_blk = function() { return ::DataBlock() }

  find_files_ex = function(path)
  {
    // Compatibility function list only files, not dirs
    return ::u.map(
      ::find_files_in_folder(path, "", false, true, false),
      function(fileName) {return {name = fileName}}
    )
  }
})

//----------------------------wop_1_65_1_X---------------------------------//

::apply_compatibilities({
  get_option_camera_shake_multiplier = function() { return 1.0 }
  set_option_camera_shake_multiplier = function(value) {}

  get_save_load_path = function() {return ""}
  get_exe_dir = function() {return ""}

  ww_get_sides_info = function(blk) {}
  webpoll_authorize = function(...) {}

  can_receive_pve_trophy = function(userId, trophyName) {return false}
  set_pve_event_was_played = function(userId, trophyName) {}
  webpoll_authorize_with_url = function(baseUrl, pollId) { webpoll_authorize(pollId) }
})

//----------------------------wop_1_67_2_X---------------------------------//
::apply_compatibilities({
  is_player_unit_alive = @() true

  save_common_local_settings = function() {}
  get_common_local_settings_blk = function() { return ::DataBlock() }

  correct_color_lightness = function(colorStr, lightness) { return colorStr }

  ps4_get_account_id = @() ""

  EII_TORPEDO = 10
  EII_DEPTH_CHARGE = 11
  EII_ROCKET = 12

  get_option_depthcharge_activation_time = @() get_option_dive_bomb_activation_time()
  set_option_depthcharge_activation_time = @(value) set_option_dive_bomb_activation_time(value)

  str_to_hex = function(str) { return "" }
})

//----------------------------wop_1_67_3_X---------------------------------//
::apply_compatibilities({
  display_scale = @() 1.0

  EII_SMOKE_SCREEN = 13

  //Old version of loc. New implemented in c++ and supports
  //all features which this one does.
  loc = function(key, param1 = null, param2 = null)
  {
    if (key.len() > 1 && key.slice(0, 1) == "#")
      key = key.slice(1)

    local defaultValue
    if (typeof(param1) == "string")
      defaultValue = param1
    if (typeof(param2) == "string")
      defaultValue = param2

    local locParams
    if (typeof(param1) == "table" || typeof(param1) == "instance")
      locParams = param1
    if (typeof(param2) == "table" || typeof(param2) == "instance")
      locParams = param2

    local text
    if (defaultValue == null)
      text = ::dagor.getLocTextEx(key)
    else
      text = ::dagor.getLocTextEx(key, defaultValue)

    if (locParams == null)
      return text
    return ::replaceParamsInLocalizedText(text, locParams)
  }

  GT_FFA_DEATHMATCH = 524288

})


//----------------------------wop_1_69_1_X---------------------------------//
::apply_compatibilities({
  HUD_TYPE_UNKNOWN = -1

  set_tactical_map_hud_type = @(hudType) set_tactical_map_type_without_unit(hudType)
  get_respawn_base_time_left_by_id = @(id) ::get_mp_zone_countdown()

  GT_FFA = 16777216
  GT_LAST_MAN_STANDING = 33554432
  EII_REPAIR_BREACHES = 14

  run_reactive_gui = function () {}

  set_shortcuts_groups = function(groupData) {}
})

//----------------------------wop_1_69_2_X---------------------------------//
{
  local unitTypesCache = {}
  local aiUnitTypes = {
    warShip         = ::ES_UNIT_TYPE_SHIP
    fortification   = ::ES_UNIT_TYPE_TANK
    heavyVehicle    = ::ES_UNIT_TYPE_TANK
    lightVehicle    = ::ES_UNIT_TYPE_TANK
    infantry        = ::ES_UNIT_TYPE_TANK
    radar           = ::ES_UNIT_TYPE_TANK
    walker          = ::ES_UNIT_TYPE_TANK
    barrageBalloon  = ::ES_UNIT_TYPE_AIRCRAFT
  }

  local aiUnitBlkPaths = [
    "ships"
    "air_defence"
    "structures"
    "tankModels"
    "tracked_vehicles"
    "wheeled_vehicles"
    "infantry"
    "radars"
    "walkerVehicle"
  ]

  local getAiUnitBlk = function(unitId)
  {
    if (unitId == "")
      return ::DataBlock()

    local fn = ::get_unit_file_name(unitId)
    local blk = ::DataBlock(fn)
    if (!::u.isEqual(blk, ::DataBlock()))
      return blk

    foreach (path in aiUnitBlkPaths)
    {
      blk = ::DataBlock(::format("gameData/units/%s/%s.blk", path, unitId))
      if (!::u.isEqual(blk, ::DataBlock()))
        return blk
    }

    return ::DataBlock()
  }

  ::find_unit_type <- function(name) //really slow function, so only for compatibility here.
  {
    if (name == "")
      return ::ES_UNIT_TYPE_TANK

    local unit = ::getAircraftByName(name)
    if (unit)
      return unit.esUnitType

    if (!(name in unitTypesCache))
    {
      local blk = getAiUnitBlk(name)
      local unitType = blk.subclass ? ::getTblValue(blk.subclass, aiUnitTypes, null) : null

      if (unitType == null)
        foreach (utype in blk % "type")
        {
          local unitClass = ::getTblValue(utype, ::unlock_condition_unitclasses, ::ES_UNIT_TYPE_INVALID)
          if (unitClass != ::ES_UNIT_TYPE_INVALID)
          {
            unitType = unitClass
            break
          }
        }

      if (unitType == null)
        unitType = ::ES_UNIT_TYPE_TANK
      unitTypesCache[name] <- unitType
    }

    return unitTypesCache[name]
  }
}

::apply_compatibilities({
  INVALID_USER_ID = -1

  UT_Airplane      = 0
  UT_Balloon       = 1
  UT_Artillery     = 2
  UT_HeavyVehicle  = 3
  UT_LightVehicle  = 4
  UT_Ship          = 5
  UT_WarObj        = 6
  UT_InfTroop      = 7
  UT_Fortification = 8
  UT_AirWing       = 9
  UT_AirSquadron   = 10
  UT_WalkerVehicle = 11
  UT_Helicopter    = 12
  
  warbond_get_shop_levels = function(wbName, stageName)
  {
    return {"Original" : 0, "Special" : 0}
  }

  get_warbond_balance = function(wbName)  {return 0}


  push_message = function (message) {}
  push_new_mode_type = function (modeId) {}
  push_new_input_string = function (str) {}
  clear_chat_log = function () {}
})

//----------------------------wop_1_69_4_X---------------------------------//
::apply_compatibilities({
  send_error_log = function(msg, production_only, db)
  {
  }
})
