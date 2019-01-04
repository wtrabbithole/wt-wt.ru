function is_version_equals_or_newer(verTxt, isTorrentVersion = false) // "1.43.7.75"
{
  if (!("get_game_version" in ::getroottable()))
    return false
  local cur = isTorrentVersion ? ::get_game_version() : ::get_base_game_version()
  return cur == 0 || cur >= ::get_version_int_from_string(verTxt)
}

function is_version_equals_or_older(verTxt, isTorrentVersion = false) // "1.61.1.37"
{
  if (!("get_game_version" in ::getroottable()))
    return true
  local cur = isTorrentVersion ? ::get_game_version() : ::get_base_game_version()
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
//----------------------OBSOLETTE SCRIPT FUNCTIONS--------------------//
//-- Do not use them. Use null operators or native functons instead --//
//--------------------------------------------------------------------//

::getTblValue <- @(key, tbl, defValue = null) key in tbl ? tbl[key] : defValue

function getTblValueByPath(path, tbl, defValue = null, separator = ".")
{
  if (path == "")
    return defValue
  if (path.find(separator) == null)
    return tbl?[path] ?? defValue
  local keys = ::split(path, separator)
  return ::get_tbl_value_by_path_array(keys, tbl, defValue)
}

function get_tbl_value_by_path_array(pathArray, tbl, defValue = null)
{
  foreach(key in pathArray)
    tbl = tbl?[key] ?? defValue
  return tbl
}

//--------------------------------------------------------------------//
//----------------------COMPATIBILITIES BY VERSIONS-------------------//
// -----------can be removed after version reach all platforms--------//
//--------------------------------------------------------------------//

//----------------------------wop_1_75_1_X---------------------------------//
::apply_compatibilities({
  EWBAT_EXT_INVENTORY_ITEM = 9
  is_highlights_inited = @() false
  show_highlights = @() null

  EPL_XBOXONE = "x"

  get_char_error_msg = function() { return "" }

  load_template_text = @(name) ::load_scene_template(name)

  set_hint_options_by_blk = function(blk) {}
  get_profile_country = @() ::get_cur_rank_info().country

  gchat_escape_target = function( target )  {
    local reserved = "\r\n\t ,;%'";
    local result = "";
    foreach( ch in target )  {
      if ( reserved.find(ch.tochar()) == null )
        result += ch.tochar();
      else
        result += ::format("%%%02X", ch);
    }
    return result
  }
  gchat_unescape_target = function ( target )  {
    local result = "";
    local sym = 0;
    local cnt = 0;
    foreach( ch in target )  {
      if ( cnt == 0 )  {
        if ( ch != '%' )
          result += ch.tochar();
        else  {
          cnt = 2;  sym = 0;
        }
      }  else  {
        sym *= 16;  cnt--;

        if ( ch >= '0' && ch <= '9' )
          sym += ch-'0';
        else  if ( ch >= 'A' && ch <= 'F' )
          sym += ch-'A'+10;
        else  if ( ch >= 'a' && ch <= 'f' )
          sym += ch-'a'+10;
        else  {
          cnt = 0;  continue;
        }
        if ( cnt == 0 )
          result += sym.tochar();
      }
    }
    return result
  }
  get_option_ai_target_type = @() 1
  set_option_ai_target_type = @(v) null
  get_ugc_blk = @() ::DataBlock("config/ugc.blk")
  get_option_default_ai_target_type = @() 1
  set_option_default_ai_target_type = @(v) null

  get_modification_level = @(unit, mod) 0
  get_modifications_overdrive = @(unitName) []

  EIT_MOD_OVERDRIVE = 7
  EIT_MOD_UPGRADE = 8

  is_opengl_driver = @() false

  xbox_is_player_in_chat = @(uid) false
  xbox_is_game_started_by_invite = @() false
  xbox_on_local_player_leave_squad = @() null

  is_online_available = @() ::is_connected_to_matching()
  hangar_get_attachable_group = @() ""
  EII_SUBMARINE_SONAR = 17
  EII_TORPEDO_SENSOR = 18
})

::dagui_propid.add_name_id("inc-min")
::dagui_propid.add_name_id("inc-max")
::dagui_propid.add_name_id("inc-is-cyclic")

if (!("get_unit_wp_to_respawn" in getroottable()))
{
  local lastRefreshTime = 0
  local crewsCache = null
  ::get_unit_wp_to_respawn <- function(unitName)
  {
    if (!crewsCache || (::dagor.getCurTime() > lastRefreshTime + 1000))
    {
      lastRefreshTime = ::dagor.getCurTime()
      crewsCache = ::get_crew_info()
    }
    foreach(countryData in crewsCache)
      foreach(crew in countryData.crews)
        if (unitName == crew?.aircraft)
          return crew?.wpToRespawn ?? 0
    return 0
  }
}

//----------------------------wop_1_77_2_X---------------------------------//
if (!("logerr" in ::dagor))
  ::dagor.logerr <- ::dagor.debug

::apply_compatibilities({
  get_authenticated_url_table = function(url)
  {
    local urlRet = ::get_authenticated_url(url)
    return {
      yuplayResult = urlRet == ""? ::YU2_FAIL : ::YU2_OK
      url = urlRet
    }
  }

  can_use_text_chat_with_target = @(...) 2
  XBOX_COMMUNICATIONS_BLOCKED = 0
  XBOX_COMMUNICATIONS_ONLY_FRIENDS = 1
  XBOX_COMMUNICATIONS_ALLOWED = 2

  DM_VIEWER_EXTERIOR = 6
  DM_VIEWER_PROTECTION = DM_VIEWER_NONE
  CHECK_PROT_RICOCHET_NONE = 0
  CHECK_PROT_RICOCHET_POSSIBLE = 1
  CHECK_PROT_RICOCHET_GUARANTEED = 2
  set_protection_checker_params = @(...) null

  is_gpu_nvidia = @() ["win32", "win64"].find(::get_platform()) >= 0

  EULT_INVENTORY_FAIL_ITEM = 56
  INVENTORY_STATE_INVALID  = 0
  INVENTORY_STATE_SETUP    = 1
  INVENTORY_STATE_SENDING  = 2
  INVENTORY_STATE_DONE     = 3
  INVENTORY_STATE_FAIL     = 4

  inventory_generate_key                = function()      { return ""   }
  inventory_get_transfer_items          = function()      { return []   }
  inventory_get_transfer_items_by_state = function(state) { return []   }
  inventory_find_transfer_item_by_key   = function(key)   { return null }

  get_option_mine_depth = @() 1
  set_option_mine_depth = @(v) null
  get_option_save_zoom_camera = @() null
  set_option_save_zoom_camera = @(v) null

  char_send_custom_action = function(action, type, headers, body, length) { return -1 }
  EATT_JSON_REQUEST = 64

  start_content_updater = function(cfg, obj, cb) { if (is_platform_ps4) ::ps4_start_updater(cfg, obj, cb) }
  stop_content_updater = function(cfg, obj, cb) { if (is_platform_ps4) ::ps4_stop_updater(cfg, obj, cb) }
  xbox_is_production_env = @() false
})

//----------------------------wop_1_77_2_X---------------------------------//
::apply_compatibilities({
  get_team_colors = @() null
  is_tank_damage_indicator_visible = @() true

  EVENT_STAT_EXTENDED_1 = "ext1"
  EVENT_STAT_EXTENDED_2 = "ext2"
  EVENT_STAT_EXTENDED_3 = "ext3"
  EVENT_STAT_EXTENDED_4 = "ext4"

  EUCT_HELICOPTER = 14
  xbox_complete_login = function() {}
  EII_MORTAR = 24
  DM_HIT_RESULT_BREAKING = 13

  CUT_INVALID = -1
  CUT_AIRCRAFT = 0
  CUT_TANK = 1
  CUT_SHIP = 2
  CUT_TOTAL = 3

  ES_UNIT_TYPE_HELICOPTER = 3
})

//----------------------------wop_1_79_2_X---------------------------------//
::apply_compatibilities({
  live_preview_resource             = ::getroottable()?.ugc_preview_resource
  live_preview_resource_by_guid     = ::getroottable()?.ugc_preview_resource_by_guid
  live_preview_resource_for_approve = ::getroottable()?.ugc_preview_resource_for_approve

  CLASS_FLAGS_SHIP = 2
  CLASS_FLAGS_HELICOPTER = 3
})

//----------------------------wop_1_81_1_X---------------------------------//
::apply_compatibilities({
  steam_get_app_id = @() 236390
  set_option_horizontal_speed = @(v) null
  get_option_horizontal_speed = @() null
})

//----------------------------wop_1_81_2_X---------------------------------//
::apply_compatibilities({
  EUCT_CRUISER = 15
})

//----------------------------wop_1_83_0_X---------------------------------//
::apply_compatibilities({
  REPLAY_LOAD_COCKPIT_NO_ONE = 0
  REPLAY_LOAD_COCKPIT_AUTHOR = 1
  REPLAY_LOAD_COCKPIT_ALL = 2
  HUD_MSG_STREAK_EX = -10
  xbox_is_item_bought = @(id) false
  EII_TORPEDO_SIGHT = -1
  hangar_show_hidden_dm_parts_change = @(v) null
  single_torpedo_selected = @() true
  show_external_dm_parts_change = @(v) null
  show_hidden_xray_parts_change = @(v) null
  webauth_start = @(o,f) false
  webauth_stop = @() null

  EULT_TOURNAMENT_AWARD = 57
})

//----------------------------wop_1_85_0_X---------------------------------//
::apply_compatibilities({
  is_triple_head = @(sw, sh) sw >= 3 * sh
})
