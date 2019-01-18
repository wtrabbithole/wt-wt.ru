local string = require("std/string.nut")
local subscriptions = require("sqStdlibs/helpers/subscriptions.nut")

local XBOX_ONE_PLAYER_PREFIX = "^"

local targetPlatform = ::get_platform()
local isPlatformXboxOne = targetPlatform == "xboxOne"
local isPlatformPS4 = targetPlatform == "ps4"
local isPlatformPC = ["win32", "win64", "macosx", "linux64"].find(targetPlatform) >= 0

local xboxNameRegexp = ::regexp2(@"^['^']")
local isXBoxPlayerName = @(name) xboxNameRegexp.match(name)

local ps4NameRegexp = ::regexp2(@"^['*']")
local isPS4PlayerName = @(name) ps4NameRegexp.match(name)

local getPlayerNameNoSpecSymbol = @(name) string.cutPrefix(name, "*", string.cutPrefix(name, XBOX_ONE_PLAYER_PREFIX, name))
local getPlayerName = @(name) name
if (isPlatformXboxOne)
  getPlayerName = getPlayerNameNoSpecSymbol

local isPlayerFromXboxOne = @(name) isPlatformXboxOne && isXBoxPlayerName(name)

local isPs4XboxOneInteractionAvailable = function(name)
{
  local isPS4Player = isPS4PlayerName(name)
  local isXBOXPlayer = isXBoxPlayerName(name)
  if (((isPlatformPS4 && isXBOXPlayer) || (isPlatformXboxOne && isPS4Player)) && !::has_feature("Ps4XboxOneInteraction"))
    return false
  return true
}

local canInteractCrossConsole = function(name) {
  local isPS4Player = isPS4PlayerName(name)
  local isXBOXPlayer = isXBoxPlayerName(name)

  if (!isXBOXPlayer && (isPlatformPC || isPlatformPS4))
    return true

  if ((isPS4Player && isPlatformPS4) || (isXBOXPlayer && isPlatformXboxOne))
    return true

  if (!isPs4XboxOneInteractionAvailable(name))
    return false

  return ::has_feature("XboxCrossConsoleInteraction")
}

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

local isChatEnableWithPlayer = function(playerName, needOverlayMessage = false) //when you have contact, you can use direct contact.canInteract
{
  local contact = ::Contact.getByName(playerName)
  if (contact)
    return contact.canInteract(needOverlayMessage)

  if (getXboxChatEnableStatus(needOverlayMessage) == XBOX_COMMUNICATIONS_ONLY_FRIENDS)
    return ::isPlayerInFriendsGroup(null, false, playerName)

  return isChatEnabled()
}

local invalidateCache = function()
{
  xboxChatEnabledCache = null
}

subscriptions.addListenersWithoutEnv({
  SignOut = @(p) invalidateCache()
}, ::g_listener_priority.CONFIG_VALIDATION)

return {
  isPlatformXboxOne = isPlatformXboxOne
  isPlatformPS4 = isPlatformPS4
  isPlatformPC = isPlatformPC

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
  getXboxChatEnableStatus = getXboxChatEnableStatus
  canInteractCrossConsole = canInteractCrossConsole
  isPs4XboxOneInteractionAvailable = isPs4XboxOneInteractionAvailable
}
