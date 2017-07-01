::last_save_profile_time <- ::dagor.getCurTime()
function save_profile_offline_limited(forceSave = false)
{
  if (!::g_login.isLoggedIn())
    return

  if (forceSave || !::is_platform_ps4 || ::dagor.getCurTime() - ::last_save_profile_time > 60000)
  {
    ::last_save_profile_time = ::dagor.getCurTime()
    ::save_profile(false)
  }
}

function getRootSizeText()
{
  return ::screen_width() + "x" + ::screen_height()
}

//save/load settings by account. work only after local profile received from host.
function save_local_account_settings(path, value, forceSave = false)
{
  local cdb = ::get_local_custom_settings_blk()

  if (::set_blk_value_by_path(cdb, path, value))
    ::save_profile_offline_limited(forceSave)
}

function load_local_account_settings(path, defValue = null)
{
  local cdb = ::get_local_custom_settings_blk()

  return ::get_blk_value_by_path(cdb, path, defValue)
}

//save/load setting to local profile, not depend on account, so can be usable before login.
function save_local_shared_settings(path, value)
{
  local blk = ::get_common_local_settings_blk()
  if (::set_blk_value_by_path(blk, path, value))
    ::save_common_local_settings()
}

function load_local_shared_settings(path, defValue = null)
{
  local blk = ::get_common_local_settings_blk()
  return ::get_blk_value_by_path(blk, path, defValue)
}

//save/load settings by account and by screenSize
function loadLocalByScreenSize(name, defValue=null)
{
  local rootName = getRootSizeText()
  if (!rootName)
    return defValue

  local cdb = ::get_local_custom_settings_blk()
  if (cdb[rootName]!=null && typeof(cdb[rootName])=="instance" && cdb[rootName][name]!=null)
    return cdb[rootName][name]
  return defValue
}

function saveLocalByScreenSize(name, value)
{
  local rootName = getRootSizeText()
  if (!rootName)
    return

  local cdb = ::get_local_custom_settings_blk()
  if (cdb[rootName]==null || typeof(cdb[rootName])!="instance")
    cdb[rootName] <- ::DataBlock()
  if (cdb[rootName][name]==null)
    cdb[rootName][name] <- value
  else
    if (cdb[rootName][name] == value)
      return  //no need save when no changes
    else
      cdb[rootName][name] = value
  ::save_profile_offline_limited()
}

// Deprecated, for storing new data use load_local_account_settings() instead.
function loadLocalByAccount(path, defValue=null)
{
  local cdb = ::get_local_custom_settings_blk()
  local id = ::my_user_id_str + "." + (::isProductionCircuit() ? "production" : ::get_cur_circuit_name())
  local profileBlk = cdb.accounts && cdb.accounts[id]
  if (profileBlk)
  {
    local value = ::get_blk_value_by_path(profileBlk, path)
    if (value != null)
      return value
  }
  profileBlk = cdb.accounts && cdb.accounts[::my_user_id_str]
  if (profileBlk)
  {
    local value = ::get_blk_value_by_path(profileBlk, path)
    if (value != null)
      return value
  }
  return defValue
}

// Deprecated, for storing new data use save_local_account_settings() instead.
function saveLocalByAccount(path, value, forceSave = false)
{
  local cdb = ::get_local_custom_settings_blk()
  local id = ::my_user_id_str + "." + (::isProductionCircuit() ? "production" : ::get_cur_circuit_name())
  if (::set_blk_value_by_path(cdb, "accounts/" + id + "/" + path, value))
    ::save_profile_offline_limited(forceSave)
}