local platformModule = require("scripts/clientState/platform.nut")
local externalIDsService = require("scripts/user/externalIdsService.nut")

local contactsByName = {}

class Contact
{
  name = ""
  uid = ""
  uidInt64 = null
  clanTag = ""

  presence = ::g_contact_presence.UNKNOWN
  forceOffline = false
  isForceOfflineChecked = !::is_platform_xboxone

  voiceStatus = null

  online = null
  unknown = true
  gameStatus = null
  gameConfig = null
  inGameEx = null

  psnName = ""
  xboxId = ""
  steamName = ""
  facebookName = ""

  pilotIcon = "cardicon_bot"
  wins = -1
  expTotal = -1

  afterSuccessUpdateFunc = null

  _cacheCanInteract = null

  constructor(contactData)
  {
    local newName = contactData?["name"] ?? ""
    if (newName.len()
        && ::u.isEmpty(contactData?.clanTag)
        && ::clanUserTable?[newName])
      contactData.clanTag <- ::clanUserTable[newName]

    update(contactData)

    ::add_event_listener("XboxSystemUIReturn", function(p) {
      _cacheCanInteract = null
    }, this)
  }

  static getByName = @(name) contactsByName?[name]

  function update(contactData)
  {
    foreach (key, val in contactData)
      if (key in this)
        this[key] = val

    uidInt64 = uid != "" ? uid.tointeger() : null

    refreshClanTagsTable()
    if (name.len())
      contactsByName[name] <- this

    if (afterSuccessUpdateFunc)
    {
      afterSuccessUpdateFunc()
      afterSuccessUpdateFunc = null
    }
  }

  function resetMatchingParams()
  {
    presence = ::g_contact_presence.UNKNOWN

    online = null
    unknown = true
    gameStatus = null
    gameConfig = null
    inGameEx = null
  }

  function setClanTag(_clanTag)
  {
    clanTag = _clanTag
    refreshClanTagsTable()
  }

  function refreshClanTagsTable()
  {
    //clanTagsTable used in lists where not know userId, so not exist contact.
    //but require to correct work with contacts too
    if (name.len())
      clanUserTable[name] <- clanTag
  }

  function getPresenceText()
  {
    local locParams = {}
    if (presence == ::g_contact_presence.IN_QUEUE
        || presence == ::g_contact_presence.IN_GAME)
    {
      local event = ::events.getEvent(::getTblValue("eventId", gameConfig))
      locParams = {
        gameMode = event ? ::events.getEventNameText(event) : ""
        country = ::loc(::getTblValue("country", gameConfig, ""))
      }
    }
    return presence.getText(locParams)
  }

  function canOpenXBoxFriendsWindow(groupName)
  {
    return platformModule.isPlayerFromXboxOne(name) && groupName != ::EPL_BLOCKLIST
  }

  function openXBoxFriendsEdit()
  {
    if (xboxId != "")
      ::xbox_show_add_remove_friend(xboxId)
    else
      getXboxId(@() ::xbox_show_add_remove_friend(xboxId))
  }

  function getXboxId(afterSuccessCb = null)
  {
    if (xboxId != "")
      return xboxId

    externalIDsService.reqPlayerExternalIDsByUserId(uid, {showProgressBox = true}, afterSuccessCb)
    return null
  }

  function needCheckXboxId()
  {
    return platformModule.isPlayerFromXboxOne(name) && xboxId == ""
  }

  function getWinsText()
  {
    return wins >= 0? wins : ::loc("leaderboards/notAvailable")
  }

  function getRank()
  {
    return ::get_rank_by_exp(expTotal > 0? expTotal : 0)
  }

  function getRankText()
  {
    return expTotal >= 0? getRank().tostring() : ::loc("leaderboards/notAvailable")
  }

  function getName()
  {
    return platformModule.getPlayerName(name)
  }

  function needCheckForceOffline()
  {
    if (isForceOfflineChecked
        || !isInFriendGroup()
        || presence == ::g_contact_presence.UNKNOWN)
      return false

    return platformModule.isPlayerFromXboxOne(name)
  }

  function isMe()
  {
    return uidInt64 == ::my_user_id_int64
      || uid == ::my_user_id_str
      || name == ::my_user_name
  }

  function getInteractionStatus(needShowSystemMessage = false)
  {
    if (!::is_platform_xboxone || isMe())
      return true

    if (xboxId == "")
    {
      if (::g_chat.getXboxChatEnableStatus() == XBOX_COMMUNICATIONS_ONLY_FRIENDS && !isInFriendGroup())
        return false
      return ::g_chat.isChatEnabled()
    }

    if (!needShowSystemMessage && _cacheCanInteract != null)
      return _cacheCanInteract

    _cacheCanInteract = ::can_use_text_chat_with_target(xboxId, needShowSystemMessage) == XBOX_COMMUNICATIONS_ALLOWED
    return _cacheCanInteract
  }

  function getInteractionWithInvitesStatus(needShowSystemMessage = false)
  {
    if (xboxId == "")
        return getInteractionStatus()     // There are no special requirements for crossnetwork mute.

    local interactStatus = ::can_use_text_chat_with_target(xboxId, needShowSystemMessage)   // The function ss called only on invites processing, so there is no need to cache.
    return interactStatus == XBOX_COMMUNICATIONS_ALLOWED || interactStatus == XBOX_COMMUNICATIONS_MUTED
  }

  function canChat(needShowSystemMessage = false)
  {
    return ::g_chat.isCrossNetworkMessageAllowed(name) && getInteractionStatus(needShowSystemMessage)
  }

  function canInvite(needShowSystemMessage = false)
  {
    return ::g_chat.isCrossNetworkMessageAllowed(name) && getInteractionWithInvitesStatus(needShowSystemMessage)
  }

  function isInGroup(groupName)
  {
    if (groupName in ::contacts)
      foreach (p in ::contacts[groupName])
        if (p.uid == uid)
          return true
    return false
  }

  function isInFriendGroup()
  {
    return isInGroup(::EPL_FRIENDLIST) || isInGroup(::EPLX_PS4_FRIENDS)
  }

  function isInBlockGroup()
  {
    return isInGroup(::EPL_BLOCKLIST)
  }
}