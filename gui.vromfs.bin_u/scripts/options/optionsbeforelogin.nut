const AUTOLOGIN_SAVE_ID = "autologin"

function is_autologin_enabled()
{
  local res = ::load_local_shared_settings(AUTOLOGIN_SAVE_ID)
  if (res != null)
    return res
  //compatibility with saves 1.67.2.X and below
  res = ::get_gui_option(::USEROPT_AUTOLOGIN) || false
  ::set_autologin_enabled(res)
  return res
}

function set_autologin_enabled(isEnabled)
{
  ::save_local_shared_settings(AUTOLOGIN_SAVE_ID, isEnabled)
}