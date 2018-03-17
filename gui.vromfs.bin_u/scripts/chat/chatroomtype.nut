local u = ::require("std/u.nut")
local enums = ::require("std/enums.nut")
local platformModule = require("scripts/clientState/platform.nut")

enum chatRoomCheckOrder {
  CUSTOM
  GLOBAL
  REGULAR
}

enum chatRoomTabOrder {
  THREADS_LIST
  SYSTEM
  STATIC  //cant be closed
  REGULAR
  PRIVATE
  HIDDEN
}

::g_chat_room_type <- {
  types = []
}

::g_chat_room_type.template <- {
  typeName = "" //Generic from type.
  roomPrefix = "#"
  checkOrder = chatRoomCheckOrder.CUSTOM
  tabOrder = chatRoomTabOrder.REGULAR
  isErrorPopupAllowed = true

  checkRoomId = function(roomId) { return ::g_string.startsWith(roomId, roomPrefix) }

  //roomId params depend on roomType
  getRoomId   = function(param1, param2 = null) { return roomPrefix + param1 }

  roomNameLocId = null
    //localized roomName
  getRoomName = function(roomId, isColored = false)
  {
    if (roomNameLocId)
      return ::loc(roomNameLocId)
    local roomName = roomId.slice(1)
    return ::loc("chat/channel/" + roomName, roomName)
  }
  getTooltip = @(roomId) getRoomName(roomId, true)
  getRoomColorTag = @(roomId) ""

  havePlayersList = true
  canVoiceChat = false
  canBeClosed = function(roomId) { return true }
  needSave = function() { return false }
  needSwitchRoomOnJoin = false //do not use it in pair with needSave
  canInviteToRoom = false
  onlyOwnerCanInvite = true
  isVisibleInSearch = function() { return false }
  hasCustomViewHandler = false
  loadCustomHandler = function(scene, roomId) { return null }

  inviteLocIdNoNick = "chat/receiveInvite/noNick"
  inviteLocIdFull = "chat/receiveInvite"
  inviteIcon = "#ui/gameuiskin#chat.svg"
  getInviteClickNameText = function(roomId)
  {
    return format(::loc("chat/receiveInvite/clickToJoin"), getRoomName(roomId))
  }

  canCreateRoom = function() { return false }

  hasChatHeader = false
  fillChatHeader = function(obj, roomData) {}
  updateChatHeader = function(obj, roomData) {}
  isAllowed = @() true
}

enums.addTypesByGlobalName("g_chat_room_type", {
  DEFAULT_ROOM = {
    checkOrder = chatRoomCheckOrder.REGULAR
    needSave = function() { return true }
    canInviteToRoom = true
    getTooltip = function(roomId) { return roomId.slice(1) }
    isVisibleInSearch = function() { return true }
    isAllowed = ::ps4_is_ugc_enabled
    canCreateRoom = @() isAllowed()
  }

  PRIVATE = {
    checkOrder = chatRoomCheckOrder.REGULAR
    tabOrder = chatRoomTabOrder.PRIVATE
    havePlayersList = false
    checkRoomId  = function(roomId) { return !::g_string.startsWith(roomId, roomPrefix) }
    getRoomId    = function(playerName, ...) { return playerName }
    getRoomName  = function(roomId, isColored = false) //roomId == playerName
    {
      local clanTag = ::getTblValue(roomId, ::clanUserTable, "")
      local res = platformModule.getPlayerName(roomId)
      if (!u.isEmpty(clanTag))
        res = clanTag + " " + res
      if (isColored)
        res = ::colorize(::g_chat.getSenderColor(roomId), res)
      return res
    }
    getRoomColorTag = function(roomId) //roomId == playerName
    {
      if (::g_squad_manager.isInMySquad(roomId, false))
        return "squad"
      if (::isPlayerNickInContacts(roomId, ::EPL_FRIENDLIST))
        return "friend"
      return ""
    }
  }

  SQUAD = { //param - random
    roomPrefix = "#_msquad_"
    roomNameLocId = "squad/name"
    inviteLocIdNoNick = "squad/receiveInvite/noNick"
    inviteLocIdFull = "squad/receiveInvite"
    inviteIcon = "#ui/gameuiskin#squad_leader"
    canVoiceChat = true

    getRoomName = function(roomId, isColored = false)
    {
      local res = ::loc(roomNameLocId)
      if (isColored && roomId == ::g_chat.getMySquadRoomId())
        res = ::colorize(::g_chat.color.senderSquad[true], res)
      return res
    }
    getRoomColorTag = @(roomId) roomId == ::g_chat.getMySquadRoomId() ? "squad" : ""

    canBeClosed = function(roomId) { return !::g_squad_manager.isInSquad() || roomId != ::g_chat.getMySquadRoomId() }
    getInviteClickNameText = function(roomId) { return ::loc("squad/inviteSquadName") }
  }

  CLAN = { //para - clanId
    tabOrder = chatRoomTabOrder.STATIC
    roomPrefix = "#_clan_"
    roomNameLocId = "clan/name"
    canVoiceChat = true
    isErrorPopupAllowed = false
    canBeClosed = function(roomId) { return roomId != getRoomId(::clan_get_my_clan_id()) }
  }

  SYSTEM = { //param none
    tabOrder = chatRoomTabOrder.SYSTEM
    roomPrefix = "#___empty___"
    havePlayersList = false
    isErrorPopupAllowed = false
    checkRoomId = function(roomId) { return roomId == roomPrefix }
    getRoomId   = function(...) { return roomPrefix }
    canBeClosed = function(roomId) { return false }
  }

  MP_LOBBY = { //param SessionLobby.roomId
    tabOrder = chatRoomTabOrder.HIDDEN
    roomPrefix = "#lobby_room_"
    havePlayersList = false
    isErrorPopupAllowed = false
  }

  GLOBAL = {
    checkOrder = chatRoomCheckOrder.GLOBAL
    havePlayersList = false
    needSave = function() { return !::g_chat.isThreadsView }
    isVisibleInSearch = function() { return !::g_chat.isThreadsView }
    checkRoomId = function(roomId) {
      if (!::g_string.startsWith(roomId, "#"))
        return false
      foreach(r in ::global_chat_rooms)
        if (roomId.find(r.name + "_", 1) == 1)
        {
          local lang = ::g_string.slice(roomId, r.name.len() + 2)
          local langsList = ::getTblValue("langs", r, ::langs_list)
          return ::isInArray(lang, langsList)
        }
      return false
    }
    getRoomId = function(roomName, lang = null) //room id is  #<<roomName>>_<<validated lang>>
    {
      if (!lang)
        lang = ::cur_chat_lang
      foreach(r in ::global_chat_rooms)
      {
        if (r.name != roomName)
          continue

        local langsList = ::getTblValue("langs", r, ::langs_list)
        if (!::isInArray(lang, langsList))
          lang = langsList[0]
        return ::format("#%s_%s", roomName, lang)
      }
      return ""
    }
    getTooltip = function(roomId) { return roomId.slice(1) }
  }

  THREAD = {
    roomPrefix = "#_x_thread_"
    roomNameLocId = "chat/thread"
    needSwitchRoomOnJoin = true
    havePlayersList = false
    canInviteToRoom = true
    onlyOwnerCanInvite = false

    threadNameLen = 15
    getRoomName = function(roomId, isColored = false)
    {
      local threadInfo = ::g_chat.getThreadInfo(roomId)
      if (!threadInfo)
        return ::loc(roomNameLocId)

      local title = threadInfo.getTitle()
      //use text only before first linebreak
      local idx = title.find("\n")
      if (idx)
        title = title.slice(0, idx)

      if (utf8(title).charCount() > threadNameLen)
        return utf8(title).slice(0, threadNameLen)
      return title
    }
    getTooltip = function(roomId)
    {
      local threadInfo = ::g_chat.getThreadInfo(roomId)
      return threadInfo ? threadInfo.getRoomTooltipText() : ""
    }

    canCreateRoom = function() { return ::g_chat.isThreadsView && ::g_chat.canCreateThreads() }

    hasChatHeader = true
    fillChatHeader = function(obj, roomData)
    {
      local handler = ::handlersManager.loadHandler(::gui_handlers.ChatThreadHeader,
                                                    {
                                                      scene = obj
                                                      roomId = roomData.id
                                                    })
      obj.setUserData(handler)
    }
    updateChatHeader = function(obj, roomData)
    {
      local ud = obj.getUserData()
      if ("onSceneShow" in ud)
        ud.onSceneShow()
    }
  }

  THREADS_LIST = {
    tabOrder = chatRoomTabOrder.THREADS_LIST
    roomPrefix = "#___threads_list___"
    roomNameLocId = "chat/threadsList"
    havePlayersList = false
    checkRoomId = function(roomId) { return roomId == roomPrefix }
    getRoomId   = function(...) { return roomPrefix }
    canBeClosed = function(roomId) { return false }


    hasCustomViewHandler = true
    loadCustomHandler = function(scene, roomId)
    {
      return ::handlersManager.loadHandler(::gui_handlers.ChatThreadsListView, { scene = scene, roomId = roomId })
    }
  }
}, null, "typeName")

::g_chat_room_type.types.sort(function(a, b) {
  if (a.checkOrder != b.checkOrder)
    return a.checkOrder < b.checkOrder ? -1 : 1
  return 0
})

function g_chat_room_type::getRoomType(roomId)
{
  foreach(roomType in types)
    if (roomType.checkRoomId(roomId))
      return roomType

  ::dagor.assertf(false, "Cant get room type by roomId = " + roomId)
  return DEFAULT_ROOM
}
