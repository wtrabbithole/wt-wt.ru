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

if (!("min" in getroottable())) 
  function min(a, b) { return (a < b)? a : b }

if (!("max" in getroottable())) 
  function max(a, b) { return (a > b)? a : b }

if (!("clamp" in getroottable())) {
  function clamp(value, min, max) {
    return (value < min) ? min : (value > max) ? max : value
  }
}

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

  get_preset_by_skin_tags = @(unitId, skinId) ::get_ugc_tags_preset_by_skin_tags(unitId, skinId)
})
