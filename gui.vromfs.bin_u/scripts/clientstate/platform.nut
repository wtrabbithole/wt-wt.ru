local string = require("std/string.nut")
local subscriptions = require("sqStdlibs/helpers/subscriptions.nut")

local XBOX_ONE_PLAYER_PREFIX = "^"
local XBOX_ONE_PLAYER_POSTFIX = "@live"

local PS4_PLAYER_PREFIX = "*"
local PS4_PLAYER_POSTFIX = "@psn"

local PS4_REGION_NAMES = {
  [::SCE_REGION_SCEE]  = "scee",
  [::SCE_REGION_SCEA]  = "scea",
  [::SCE_REGION_SCEJ]  = "scej"
}

local targetPlatform = ::get_platform()
local isPlatformXboxOne = targetPlatform == "xboxOne"
local isPlatformPS4 = targetPlatform == "ps4"
local isPlatformPC = ["win32", "win64", "macosx", "linux64"].find(targetPlatform) >= 0

local xboxNameRegexp = ::regexp2(@"^['^']")
local isXBoxPlayerName = @(name) xboxNameRegexp.match(name)

local ps4NameRegexp = ::regexp2(@"^['*']")
local isPS4PlayerName = @(name) ps4NameRegexp.match(name)

local getPlayerNameNoSpecSymbol = function(name, remove_prefix=true, remove_suffix=true) {
  if (remove_prefix)
    name = string.cutPrefix(name, PS4_PLAYER_PREFIX, string.cutPrefix(name, XBOX_ONE_PLAYER_PREFIX, name))
  if (remove_suffix)
    name = string.cutPostfix(name, PS4_PLAYER_POSTFIX, string.cutPostfix(name XBOX_ONE_PLAYER_POSTFIX, name))
  return name
}

local getPlayerName = @(name) name
if (isPlatformXboxOne || isPlatformPS4)
  getPlayerName = @(name) getPlayerNameNoSpecSymbol(name, !isPlatformPS4, true)

local isPlayerFromXboxOne = @(name) isPlatformXboxOne && isXBoxPlayerName(name)

local isMePS4Player = @() ::g_user_utils.haveTag("ps4")
local isMeXBOXPlayer = @() ::g_user_utils.haveTag("xbone")

local canSpendRealMoney = @() !isPlatformPC || !::has_entitlement("XBOXAccount")

local isPs4XboxOneInteractionAvailable = function(name)
{
  local isPS4Player = isPS4PlayerName(name)
  local isXBOXPlayer = isXBoxPlayerName(name)
  if (((isMePS4Player() && isXBOXPlayer) || (isMeXBOXPlayer() && isPS4Player)) && !::has_feature("Ps4XboxOneInteraction"))
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

local isChatEnableWithPlayer = function(playerName) //when you have contact, you can use direct contact.canInteract
{
  local contact = ::Contact.getByName(playerName)
  if (contact)
    return contact.canInteract(false)

  if (getXboxChatEnableStatus(false) == XBOX_COMMUNICATIONS_ONLY_FRIENDS)
    return ::isPlayerInFriendsGroup(null, false, playerName)

  return isChatEnabled()
}

local attemptShowOverlayMessage = function(playerName) //tries to display Xbox overlay message
{
  local contact = ::Contact.getByName(playerName)
  if (contact)
    contact.canInteract(true)
  else
    getXboxChatEnableStatus(true)
}

local invalidateCache = function()
{
  xboxChatEnabledCache = null
}

subscriptions.addListenersWithoutEnv({
  SignOut = @(p) invalidateCache()
}, ::g_listener_priority.CONFIG_VALIDATION)

return {
  targetPlatform = targetPlatform
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

  isMePS4Player = isMePS4Player
  isMeXBOXPlayer = isMeXBOXPlayer

  isChatEnabled = isChatEnabled
  isChatEnableWithPlayer = isChatEnableWithPlayer
  attemptShowOverlayMessage = attemptShowOverlayMessage
  canSquad = @() getXboxChatEnableStatus() == XBOX_COMMUNICATIONS_ALLOWED
  getXboxChatEnableStatus = getXboxChatEnableStatus
  canInteractCrossConsole = canInteractCrossConsole
  isPs4XboxOneInteractionAvailable = isPs4XboxOneInteractionAvailable

  canSpendRealMoney = canSpendRealMoney

  ps4RegionName = @() PS4_REGION_NAMES[::ps4_get_region()]
}
