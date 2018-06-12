local platformModule = require("scripts/clientState/platform.nut")
local externalIDsService = require("scripts/user/externalIdsService.nut")

local contactsByName = {}

class Contact
{
  name = ""
  uid = ""
  uidInt64 = null
  clanTag = ""

  presence = null
  forceOffline = false
  isForceOfflineChecked = !::is_platform_xboxone

  voiceStatus = null

  online = null
  unknown = null
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

  update = false
  afterSuccessUpdateFunc = null

  constructor(contactData)
  {
    presence = ::g_contact_presence.UNKNOWN
    unknown = true

    local newName = ::getTblValue(name, contactData, "")
    if (newName.len()
        && ::u.isEmpty(::getTblValue("clanTag", contactData))
        && newName in ::clanUserTable)
      contactData.clanTag <- ::clanUserTable[newName]

    update(contactData)
  }

  static getByName = @(name) contactsByName?[name]

  function update(contactData)
  {
    foreach (name, val in contactData)
      if (name in this)
        this[name] = val

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
    local res = presence.getText()
    if (presence == ::g_contact_presence.IN_QUEUE
        || presence == ::g_contact_presence.IN_GAME)
    {
      local event = ::events.getEvent(::getTblValue("eventId", gameConfig))
      local locParams = {
        gameMode = event ? ::events.getEventNameText(event) : ""
        country = ::loc(::getTblValue("country", gameConfig, ""))
      }
      return ::replaceParamsInLocalizedText(res, locParams)
    }

    return res
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

  _cacheCanInteract = null
  function canInteract(needShowSystemMessage = false)
  {
    if (!::is_platform_xboxone || isMe() || !platformModule.isPlayerFromXboxOne(name))
      return true

    if (xboxId == "")
      return platformModule.isChatEnabled()

    if (!needShowSystemMessage && _cacheCanInteract != null)
      return _cacheCanInteract

    _cacheCanInteract = ::can_use_text_chat_with_target(xboxId, needShowSystemMessage) == XBOX_COMMUNICATIONS_ALLOWED
    return _cacheCanInteract
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