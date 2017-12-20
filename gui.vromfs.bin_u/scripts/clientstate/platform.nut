local getPlayerName = @(name) name
if (::is_platform_xboxone)
  getPlayerName = @(name) ::g_string.cutPrefix(name, "*", name)

//required, when we not logged in, but know player gamertag, so we can identify
//for whom need read this param
local getXboxPlayerCrossPlaySaveId = @() "isCrossPlayEnabled/" + ::xbox_get_active_user_gamertag()

local isCrossPlayEnabled = @() (!::is_platform_xboxone || ::load_local_shared_settings(getXboxPlayerCrossPlaySaveId(), false))

local function setIsCrossPlayEnabled(useCrossPlay)
{
  if (::is_platform_xboxone)
    ::save_local_shared_settings(getXboxPlayerCrossPlaySaveId(), useCrossPlay)
}

return {
  getPlayerName = getPlayerName
  isCrossPlayEnabled = isCrossPlayEnabled
  setIsCrossPlayEnabled = setIsCrossPlayEnabled
}