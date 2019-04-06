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

//----------------------------wop_1_85_0_X---------------------------------//
::apply_compatibilities({
  is_triple_head = @(sw, sh) sw >= 3 * sh
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
