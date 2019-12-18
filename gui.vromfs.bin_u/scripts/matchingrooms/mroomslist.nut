const ROOM_LIST_REFRESH_MIN_TIME = 3000 //ms
const ROOM_LIST_REQUEST_TIME_OUT = 45000 //ms
const ROOM_LIST_TIME_OUT = 180000
const MAX_SESSIONS_LIST_LEN = 1000
const SKIRMISH_ROOMS_LIST_ID = "skirmish"

class MRoomsList
{
  id = ""
  roomsList = null
  requestParams = null

  lastUpdateTimeMsec = - ROOM_LIST_TIME_OUT
  lastRequestTimeMsec = - ROOM_LIST_REQUEST_TIME_OUT
  isInUpdate = false

  static mRoomsListById = {}

/*************************************************************************************************/
/*************************************PUBLIC FUNCTIONS *******************************************/
/*************************************************************************************************/

  static function getMRoomsListByRequestParams(requestParams)
  {
    local roomsListId = SKIRMISH_ROOMS_LIST_ID //empty request params is a skirmish
    if ("eventEconomicName" in requestParams)
      roomsListId = "economicName:" + requestParams.eventEconomicName

    local listById = ::MRoomsList.mRoomsListById
    if (!(roomsListId in listById))
      listById[roomsListId] <- ::MRoomsList(roomsListId, requestParams)
    return listById[roomsListId]
  }

  constructor(roomsListId, request)
  {
    id = roomsListId
    roomsList = []
    requestParams = request || {}
  }

  function isNewest()
  {
    return !isInUpdate && ::dagor.getCurTime() - lastUpdateTimeMsec < ROOM_LIST_REFRESH_MIN_TIME
  }

  function canRequestByTime()
  {
    local checkTime = isInUpdate ? ROOM_LIST_REQUEST_TIME_OUT : ROOM_LIST_REFRESH_MIN_TIME
    return  ::dagor.getCurTime() - lastRequestTimeMsec >= checkTime
  }

  function canRequest()
  {
    return !isNewest() && canRequestByTime()
  }

  function validateList()
  {
    if (::dagor.getCurTime() - lastUpdateTimeMsec >= ROOM_LIST_TIME_OUT)
      roomsList.clear()
  }

  function getList(filter = null)
  {
    validateList()
    requestList()
    if (!roomsList.len() || !filter || !filter.len())
      return roomsList

    local res = []
    foreach(room in roomsList)
      if (checkRoomByFilter(room, filter))
        res.append(room)
    return res
  }

  function getRoom(roomId)
  {
    return ::u.search(getList(), (@(roomId) function(r) { return r.roomId == roomId })(roomId))
  }

  function requestList()
  {
    if (!canRequest())
      return false

    isInUpdate = true
    lastRequestTimeMsec = ::dagor.getCurTime()

    local roomsData = this
    ::fetch_rooms_list(getFetchRoomsParams(), (@(roomsData) function(p) {  roomsData.requestListCb(p) })(roomsData))
    ::broadcastEvent("RoomsSearchStarted", { roomsList = this })
    return true
  }

/*************************************************************************************************/
/************************************PRIVATE FUNCTIONS *******************************************/
/*************************************************************************************************/

  function requestListCb(p)
  {
    isInUpdate = false

    local digest = ::checkMatchingError(p, false) ? ::getTblValue("digest", p) : null
    if (!digest)
      return

    lastUpdateTimeMsec = ::dagor.getCurTime()
    updateRoomsList(digest)
    ::broadcastEvent("SearchedRoomsChanged", { roomsList = this })
  }

  function setPlatformFilter(filter) {
    if (::is_platform_xboxone) {
      filter["public/platformRestriction"] <- {
        test = "eq"
        value = "xboxOne"
      }
    }
    else {
      filter["public/platformRestriction"] <- {
        test = "eq"
        value = null // only non-restricted rooms will be passed
      }
    }
  }

  function getFetchRoomsParams()
  {
    local filter = {}
    local res = {
      group = "custom-lobby" // "xbox-lobby" for xbox
      filter = filter

      // TODO: implement paging in client
      cursor = 0
      count = 100
    }
    if ("eventEconomicName" in requestParams) {
      local economicName = requestParams.eventEconomicName
      local modesList = ::g_matching_game_modes.getGameModeIdsByEconomicName(economicName)
      res.group = "matching-lobby"

      if (modesList.len()) {
        filter["public/game_mode_id"] <-
            {
              test = "in"
              value = modesList
            }
      }
      else {
        ::assertf_once("no gamemodes for mrooms", "Error: cant find any gamemodes by economic name: " + economicName)
        filter["public/game_mode_name"] <-
            {
              test = "eq"
              value =  economicName
            }
      }
    }
    setPlatformFilter(filter)
    return res
  }

  function updateRoomsList(rooms) //can be called each update
  {
    if (rooms.len() > MAX_SESSIONS_LIST_LEN)
    {
      local message = ::format("Error in SessionLobby::updateRoomsList:\nToo long rooms list - %d", rooms.len())
      ::script_net_assert_once("too long rooms list", message)

      rooms.resize(MAX_SESSIONS_LIST_LEN)
    }

    roomsList.clear()
    foreach(room in rooms)
      if (isRoomVisible(room))
        roomsList.append(room)
  }

  function isRoomVisible(room)
  {
    local userUid = ::SessionLobby.getRoomCreatorUid(room)
    if (userUid && ::isPlayerInContacts(userUid, ::EPL_BLOCKLIST))
      return false
    return ::SessionLobby.getMisListType(room.public).canJoin(::GM_SKIRMISH)
  }

  function checkRoomByFilter(room, filter)
  {
    local public = ::getTblValue("public", room)
    local mission = ::getTblValue("mission", public)

    local diff = ::getTblValue("diff", filter, -1)
    if (diff != -1
        && ::g_difficulty.getDifficultyByDiffCode(filter.diff).name != ::getTblValue("difficulty", mission))
      return false

    local clusters = ::getTblValue("clusters", filter)
    if (clusters && !::isInArray(::getTblValue("cluster", room), clusters))
      return false

    if (!::getTblValue("hasFullRooms", filter, true)
        && ::SessionLobby.getRoomMembersCnt(room) >= ::getTblValue("maxPlayers", mission, 0))
        return false

    return true
  }
}
