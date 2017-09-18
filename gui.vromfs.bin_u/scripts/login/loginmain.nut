foreach (fn in [
                 "login.nut"
                 "loginWnd.nut"
                 "steamLogin.nut"
                 "ps4Login.nut"
                 "xboxOneLogin.nut"
                 "tencentLogin.nut"
                 "dmmLogin.nut"
                 "loginProcess.nut"
                 "waitForLoginWnd.nut"
                 "updaterModal.nut"
               ])
  ::g_script_reloader.loadOnce("scripts/login/" + fn)

function use_tencent_login()
{
  return ::is_platform_windows && ::getFromSettingsBlk("yunetwork/useTencentLogin", false)
}

function use_fpt_login()
{
  return ::is_platform_windows && ::getFromSettingsBlk("yunetwork/useFptLogin", false)
}

function use_dmm_login()
{
  return ::dgs_get_argv("dmm_user_id") && ::dgs_get_argv("dmm_token")
}
