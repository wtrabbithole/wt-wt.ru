::is_version_equals_or_newer <- function is_version_equals_or_newer(verTxt, isTorrentVersion = false) // "1.43.7.75"
{
  if (!("get_game_version" in ::getroottable()))
    return false
  local cur = isTorrentVersion ? ::get_game_version() : ::get_base_game_version()
  return cur == 0 || cur >= ::get_version_int_from_string(verTxt)
}

::is_version_equals_or_older <- function is_version_equals_or_older(verTxt, isTorrentVersion = false) // "1.61.1.37"
{
  if (!("get_game_version" in ::getroottable()))
    return true
  local cur = isTorrentVersion ? ::get_game_version() : ::get_base_game_version()
  return cur != 0 && cur <= ::get_version_int_from_string(verTxt)
}

::get_version_int_from_string <- function get_version_int_from_string(versionText)
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

::getTblValueByPath <- function getTblValueByPath(path, tbl, defValue = null, separator = ".")
{
  if (path == "")
    return defValue
  if (path.find(separator) == null)
    return tbl?[path] ?? defValue
  local keys = ::split(path, separator)
  return ::get_tbl_value_by_path_array(keys, tbl, defValue)
}

::get_tbl_value_by_path_array <- function get_tbl_value_by_path_array(pathArray, tbl, defValue = null)
{
  foreach(key in pathArray)
    tbl = tbl?[key] ?? defValue
  return tbl
}

//--------------------------------------------------------------------//
//----------------------COMPATIBILITIES BY VERSIONS-------------------//
// -----------can be removed after version reach all platforms--------//
//--------------------------------------------------------------------//

//----------------------------wop_1_85_0_X---------------------------------//
::apply_compatibilities({
  set_hud_width_limit = @(w) null
  get_local_time_sec       = @()  ::mktime(::get_local_time())
  get_user_log_time_sec    = @(i) ::mktime(::get_user_log_time(i))
  get_file_modify_time_sec = @(f) ::mktime(::get_file_modify_time(f))
  ps4_is_circle_selected_as_enter_button = @() false
  clan_get_exp             = @()  0
  clan_get_researching_unit= @() ""
  getWheelBarItems = @() null
  WEAPON_PRIMARY = 22
  WEAPON_SECONDARY = 23
  WEAPON_MACHINEGUN = 24
  get_option_use_oculus_to_aim_helicopter = @() null
})

//----------------------------wop_1_87_0_X---------------------------------//
::apply_compatibilities({
  EULT_CLAN_UNITS = 58
  clan_get_unit_open_cost_gold = @() 0
})

//----------------------------wop_1_87_1_X---------------------------------//
::apply_compatibilities({
  EULT_WW_AWARD = 59
  AUTO_SAVE_FLG_LOGIN = 1
  AUTO_SAVE_FLG_PASS = 2
  AUTO_SAVE_FLG_DISABLE = 4
  AUTO_SAVE_FLG_NOSSLCERT = 8
  userstat = { request = @(...) null }
  xbox_link_email = @(email, cb) cb(::YU2_FAIL)
})

//----------------------------wop_1_89_1_X---------------------------------//
::apply_compatibilities({
  function warbonds_has_active_battle_task(name)
  {
    return !::warbonds_can_buy_battle_task(name)
  }
  restart_without_steam = restart_game
  get_authenticated_url_sso = @(u, s) get_authenticated_url_table(u)
  EATT_SIMPLE_OK = 43
  OPTION_HIDE_MOUSE_SPECTATOR = 255
  function clan_get_exp_boost() {return 0}
  YU2_DOI_INCOMPLETE = 31
  function set_selected_unit_info(unit, slot_id){}
  function is_eac_inited()
  {
    return true
  }
  get_level_texture = @(lvl, f) ::map_to_location(lvl ?? "") + (f ? "_tankmap*" : "_map*")
})

//----------------------------wop_1_91_0_X---------------------------------//
::apply_compatibilities({
    XBOX_COMMUNICATIONS_MUTED = 3
    EII_HULL_AIMING = -1
})