local platformModule = require("scripts/clientState/platform.nut")

class Contact
{
  name = ""
  uid = ""
  clanTag = ""
  presence = null
  voiceStatus = null

  online = null
  unknown = null
  gameStatus = null
  gameConfig = null
  inGameEx = null

  pilotIcon = "cardicon_bot"
  wins = -1
  rank = -1

  update = false

  constructor(contactData)
  {
    presence = ::g_contact_presence.UNKNOWN
    unknown = true

    local newName = ::getTblValue(name, contactData, "")
    if (newName.len()
        && ::u.isEmpty(::getTblValue("clanTag", contactData))
        && newName in clanUserTable)
      contactData.clanTag <- clanUserTable[newName]

    update(contactData)
  }

  function update(contactData)
  {
    foreach (name, val in contactData)
      if (name in this)
        this[name] = val
    refreshClanTagsTable()
  }

  function getWinsText() {
    if (wins >= 0)
      return wins
    return ::loc("leaderboards/notAvailable")
  }

  function getRankText() {
    if (rank >= 0)
      return rank
    return ::loc("leaderboards/notAvailable")
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

  function getName()
  {
    return platformModule.getPlayerName(name)
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
      res = ::replaceParamsInLocalizedText(res, locParams)
    }

    return res
  }
}