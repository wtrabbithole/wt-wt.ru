local string =  require("std/string.nut")

local XBOX_ONE_PLAYER_PREFIX = "^"

local isPlatformXboxOne = ::get_platform() == "xboxOne"

local xboxNameRegexp = ::regexp2(@"^['^']")
local isXBoxPlayerName = @(name) xboxNameRegexp.match(name)

local ps4NameRegexp = ::regexp2(@"^['*']")
local isPS4PlayerName = @(name) ps4NameRegexp.match(name)

local getPlayerNameNoSpecSymbol = @(name) string.cutPrefix(name, "*", string.cutPrefix(name, XBOX_ONE_PLAYER_PREFIX, name))
local getPlayerName = @(name) name
if (isPlatformXboxOne)
  getPlayerName = getPlayerNameNoSpecSymbol

//required, when we not logged in, but know player gamertag, so we can identify
//for whom need read this param
local getXboxPlayerCrossPlaySaveId = @() "isCrossPlayEnabled/" + ::xbox_get_active_user_gamertag()

local isCrossPlayEnabled = @() (!isPlatformXboxOne || ::load_local_shared_settings(getXboxPlayerCrossPlaySaveId(), false))

local function setIsCrossPlayEnabled(useCrossPlay)
{
  if (isPlatformXboxOne)
    ::save_local_shared_settings(getXboxPlayerCrossPlaySaveId(), useCrossPlay)
}

return {
  xboxNameRegexp = xboxNameRegexp
  isXBoxPlayerName = isXBoxPlayerName
  ps4NameRegexp = ps4NameRegexp
  isPS4PlayerName = isPS4PlayerName
  getPlayerName = getPlayerName
  getPlayerNameNoSpecSymbol = getPlayerNameNoSpecSymbol
  isCrossPlayEnabled = isCrossPlayEnabled
  setIsCrossPlayEnabled = setIsCrossPlayEnabled
}