local platformModule = require("scripts/clientState/platform.nut")
local externalIDsService = require("scripts/user/externalIdsService.nut")

class Contact
{
  name = ""
  uid = ""
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
  rank = -1

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

  function update(contactData)
  {
    foreach (name, val in contactData)
      if (name in this)
        this[name] = val
    refreshClanTagsTable()

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

  function canOpenXBoxFriendsWindow()
  {
    return ::is_player_from_xbox_one(name)
  }

  function openXBoxFriendsEdit()
  {
    if (!canOpenXBoxFriendsWindow())
      return

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

  function getWinsText()
  {
    return wins >= 0? wins : ::loc("leaderboards/notAvailable")
  }

  function getRankText()
  {
    return rank >= 0? rank : ::loc("leaderboards/notAvailable")
  }

  function getName()
  {
    return platformModule.getPlayerName(name)
  }

  function needCheckForceOffline()
  {
    if (isForceOfflineChecked)
      return false

    if (!::isPlayerInFriendsGroup(uid))
      return false

    return ::is_player_from_xbox_one(name)
  }
}