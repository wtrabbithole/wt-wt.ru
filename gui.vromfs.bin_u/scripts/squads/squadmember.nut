class SquadMember
{
  uid = ""
  name = ""
  rank = -1
  country = ""
  clanTag = ""
  pilotIcon = "cardicon_default"
  online = false
  selAirs = null
  selSlots = null
  crewAirs = null
  brokenAirs = null
  missedPkg = null
  wwOperations = null
  isReady = false
  cyberCafeId = ""
  unallowedEventsENames = null
  sessionRoomId = ""

  isChanged = false
  isWaiting = true
  isInvite = false
  isInvitedToSquadChat = false

  updatedProperties = ["name", "rank", "country", "clanTag", "pilotIcon", "selAirs",
                       "selSlots", "crewAirs", "brokenAirs", "missedPkg", "wwOperations", "isReady", "cyberCafeId",
                       "unallowedEventsENames", "sessionRoomId"]

  constructor(uid, isInvite = false)
  {
    this.uid = uid.tostring()
    this.isInvite = isInvite

    initUniqueInstanceValues()
  }

  function initUniqueInstanceValues()
  {
    selAirs = {}
    selSlots = {}
    crewAirs = {}
    brokenAirs = []
    missedPkg = []
    wwOperations = {}
    unallowedEventsENames = []
  }

  function update(data)
  {
    local newValue = null
    foreach(idx, property in updatedProperties)
    {
      newValue = ::getTblValue(property, data, null)
      if (newValue == null)
        continue

      if (newValue != this[property])
      {
        this[property] = newValue
        isChanged = true
      }
    }
    isWaiting = false
  }

  function isActualData()
  {
    return !isWaiting && !isInvite
  }

  function canJoinSessionRoom()
  {
    return isReady && sessionRoomId == ""
  }

  function getData()
  {
    local result = {uid = uid}
    foreach(idx, property in updatedProperties)
      if (!::u.isEmpty(this[property]))
        result[property] <- this[property]

    return result
  }

  function getWwOperationCountryById(wwOperationId)
  {
    return ::getTblValue(wwOperationId, wwOperations, null)
  }

  function isEventAllowed(eventEconomicName)
  {
    return !::isInArray(eventEconomicName, unallowedEventsENames)
  }

  function isMe()
  {
    return uid == ::my_user_id_str
  }
}