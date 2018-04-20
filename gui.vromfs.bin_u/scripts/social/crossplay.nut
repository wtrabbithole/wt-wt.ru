local persistentData = {
  xboxIsShownCrossPlayEnableOnce = false
}
::g_script_reloader.registerPersistentData("crossplay", persistentData, ["xboxIsShownCrossPlayEnableOnce"])

//required, when we not logged in, but know player gamertag, so we can identify
//for whom need read this param
local getXboxPlayerCrossPlaySaveId = @() "isCrossPlayEnabled/" + ::xbox_get_active_user_gamertag()

local isCrossPlayEnabled = @() (!::is_platform_xboxone || ::load_local_account_settings(getXboxPlayerCrossPlaySaveId(), false))

local function setIsCrossPlayEnabled(useCrossPlay)
{
  if (::is_platform_xboxone)
    ::save_local_account_settings(getXboxPlayerCrossPlaySaveId(), useCrossPlay)
}

local function showXboxCrossPlayNotificationOnce()
{
  if (isCrossPlayEnabled() || persistentData.xboxIsShownCrossPlayEnableOnce)
    return

  ::scene_msg_box("xbox_cross_play",
    null,
    ::loc("xbox/login/crossPlayRequest") +
      "\n" +
      ::colorize("@warningTextColor", ::loc("xbox/login/crossPlayRequest/annotation")),
    [
      ["yes", @() setIsCrossPlayEnabled(true) ],
      ["no", @() setIsCrossPlayEnabled(false) ]
    ],
    "yes"
  )

  persistentData.xboxIsShownCrossPlayEnableOnce = true
}

return {
  isCrossPlayEnabled = isCrossPlayEnabled
  setIsCrossPlayEnabled = setIsCrossPlayEnabled
  showXboxCrossPlayNotificationOnce = showXboxCrossPlayNotificationOnce
}