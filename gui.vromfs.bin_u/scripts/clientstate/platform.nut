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

local xboxChatEnabledCache = null
local getXboxChatEnableStatus = function(needOverlayMessage = false)
{
   if (!::is_platform_xboxone || !::g_login.isLoggedIn())
     return XBOX_COMMUNICATIONS_ALLOWED

  if (xboxChatEnabledCache == null || (needOverlayMessage && xboxChatEnabledCache == XBOX_COMMUNICATIONS_BLOCKED))
    xboxChatEnabledCache = ::can_use_text_chat_with_target("", needOverlayMessage)//myself, block by parent advisory
  return xboxChatEnabledCache
}

local isChatEnabled = function(needOverlayMessage = false)
{
  if (!::ps4_is_chat_enabled())
  {
    if (needOverlayMessage)
      ::ps4_show_chat_restriction()
    return false
  }
  return getXboxChatEnableStatus(needOverlayMessage) != XBOX_COMMUNICATIONS_BLOCKED
}

local function isChatEnableWithPlayer(playerName) //when you hve contact, you can use direct contact.canInteract
{
  local contact = ::Contact.getByName(playerName)
  return contact ? contact.canInteract() : isChatEnabled()
}

local invalidateCache = function()
{
  xboxChatEnabledCache = null
}

::subscribe_events({
  SignOut = @(p) invalidateCache()
}, ::g_listener_priority.CONFIG_VALIDATION)

return {
  xboxNameRegexp = xboxNameRegexp
  isXBoxPlayerName = isXBoxPlayerName
  ps4NameRegexp = ps4NameRegexp
  isPS4PlayerName = isPS4PlayerName
  getPlayerName = getPlayerName
  getPlayerNameNoSpecSymbol = getPlayerNameNoSpecSymbol
  isPlayerFromXboxOne = isPlayerFromXboxOne

  isChatEnabled = isChatEnabled
  isChatEnableWithPlayer = isChatEnableWithPlayer
  canSquad = @() getXboxChatEnableStatus() == XBOX_COMMUNICATIONS_ALLOWED
}