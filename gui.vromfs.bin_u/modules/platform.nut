local string = require("std/string.nut")

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

local isPlayerFromXboxOne = @(name) isPlatformXboxOne && isXBoxPlayerName(name)

return {
  xboxNameRegexp = xboxNameRegexp
  isXBoxPlayerName = isXBoxPlayerName
  ps4NameRegexp = ps4NameRegexp
  isPS4PlayerName = isPS4PlayerName
  getPlayerName = getPlayerName
  getPlayerNameNoSpecSymbol = getPlayerNameNoSpecSymbol
  isPlayerFromXboxOne = isPlayerFromXboxOne
}