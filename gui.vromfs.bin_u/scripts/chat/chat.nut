enum chatUpdateState {
  OUTDATED
  IN_PROGRESS
  UPDATED
}

enum chatErrorName {
  NO_SUCH_NICK_CHANNEL    = "401"
  NO_SUCH_CHANNEL         = "403"
  CANT_SEND_MESSAGE       = "404"
  CANNOT_JOIN_THE_CHANNEL = "475"
}

g_chat <- {
  [PERSISTENT_DATA_PARAMS] = ["isThreadsView", "rooms", "threadsInfo", "threadTitleLenMin", "threadTitleLenMax"]

  MAX_ROOM_MSGS = 50
  MAX_ROOM_MSGS_FOR_MODERATOR = 250
  MAX_MSG_LEN = 200
  MAX_ROOMS_IN_SEARCH = 20
  MAX_LAST_SEND_MESSAGES = 10
  MAX_MSG_VC_SHOW_TIMES = 2

  MAX_ALLOWED_DIGITS_IN_ROOM_NAME = 6
  MAX_ALLOWED_CHARACTERS_IN_ROOM_NAME = 15

  SYSTEM_MESSAGES_USER_ENDING = ".warthunder.com"

  SYSTEM_COLOR = "@chatInfoColor"

  CHAT_ERROR_NO_CHANNEL = "chat/error/403"

  validateRoomNameRegexp = regexp2(@"[  !""#$%&'()*+,./\\:;<=>?@\^`{|}~-]")

  THREADS_INFO_TIMEOUT_MSEC = 300000
  THREADS_INFO_CLEAN_PERIOD_MSEC = 150000  //check clean only on get new thread info
  THREAD_INFO_REFRESH_DELAY_MSEC = 60000

  CHAT_SYSTEM_MESSAGE_TIMEOUT_MSEC = 60000

  threadTitleLenMin = 8
  threadTitleLenMax = 160

  isThreadsView = false

  rooms = [] //for full room params list check addRoom( function in menuchat.nut //!!FIX ME must be here, or separate class
  threadsInfo = {}

  LOCALIZED_MESSAGE_PREFIX = "LMSG "

  color = { //better to allow player tune color sheme
    sender =         { [false] = "@mChatSenderColorDark",        [true] = "@mChatSenderColor" }
    senderMe =       { [false] = "@mChatSenderMeColorDark",      [true] = "@mChatSenderMeColor" }
    senderPrivate =  { [false] = "@mChatSenderPrivateColorDark", [true] = "@mChatSenderPrivateColor" }
    senderSquad =    { [false] = "@mChatSenderMySquadColorDark", [true] = "@mChatSenderMySquadColor" }
    senderFriend =   { [false] = "@mChatSenderFriendColorDark",  [true] = "@mChatSenderFriendColor" }
  }
}


//to test filters - use console "chat_filter_for_myself=true"
::chat_filter_for_myself <- ::is_vendor_tencent()
function g_chat::filterMessageText(text, isMyMessage)
{
  if (::get_option(::USEROPT_CHAT_FILTER).value &&
    (!isMyMessage || ::chat_filter_for_myself))
    return ::dirty_words_filter.checkPhrase(text)
  return text
}


function g_chat::makeBlockedMsg(msg)
{
  //space work as close link. but non-breakable space - work as other symbols.
  msg = ::stringReplace(msg, " ", " ")

  //rnd for duplicate blocked messages
  return ::format("<Link=BL_%d_%s>%s</Link>",
    ::math.rnd() % 99, msg, ::loc("chat/blocked_message"))
}


function g_chat::checkBlockedLink(link)
{
  return (link.len() > 6 && link.slice(0, 3) == "BL_")
}


function g_chat::revertBlockedMsg(text, link)
{
  local start = text.find("<Link=" + link)
  if (start == null)
    return

  local end = text.find("</Link>", start)
  if (end == null)
    return

  end += "</Link>".len()

  local msg = ::stringReplace(link.slice(6), " ", " ")
  text = text.slice(0, start) + msg + text.slice(end)
  return text
}


function g_chat::onCharConfigsLoaded()
{
  isThreadsView = ::has_feature("ChatThreadsView")
}

function g_chat::checkChatConnected()
{
  if (::gchat_is_connected())
    return true

  systemMessage(::loc("chat/not_connected"))
  return false
}

g_chat.nextSystemMessageTime <- 0
function g_chat::systemMessage(msg, needPopup = true, forceMessage = false)
{
  if ( (!forceMessage) && (nextSystemMessageTime > ::dagor.getCurTime()) )
    return

  nextSystemMessageTime = ::dagor.getCurTime() + CHAT_SYSTEM_MESSAGE_TIMEOUT_MSEC

  if (::menu_chat_handler)
    ::menu_chat_handler.addRoomMsg("", "", msg)
  if (needPopup)
    ::g_popups.add(null, ::format("<color=%s>%s</color>", SYSTEM_COLOR, msg))
}

function g_chat::getRoomById(id)
{
  return ::u.search(rooms, (@(id) function (room) { return room.id == id })(id))
}

function g_chat::isRoomJoined(roomId)
{
  local room = getRoomById(roomId)
  return room != null && room.joined
}

g_chat._roomJoinedIdx <- 0
function g_chat::addRoom(room)
{
  room.roomJoinedIdx <- _roomJoinedIdx++
  rooms.append(room)

  rooms.sort(function(a, b)
  {
    if (a.type.tabOrder != b.type.tabOrder)
      return a.type.tabOrder < b.type.tabOrder ? -1 : 1
    if (a.roomJoinedIdx != b.roomJoinedIdx)
      return a.roomJoinedIdx < b.roomJoinedIdx ? -1 : 1
    return 0
  })
}

function g_chat::getMaxRoomMsgAmount()
{
  return ::is_myself_anyof_moderators() ? MAX_ROOM_MSGS_FOR_MODERATOR : MAX_ROOM_MSGS
}

function g_chat::clampMsg(msg) //clamp msg by max chat message len
{
  //!!FIX ME: nned to slice in utf8, but this code work in current chat for a long time without troubles.
  return (msg.len() > 2 * MAX_MSG_LEN) ? msg.slice(0, 2 * MAX_MSG_LEN) : msg
}

function g_chat::isSystemUserName(name)
{
  return ::g_string.endsWith(name, SYSTEM_MESSAGES_USER_ENDING)
}

function g_chat::isSystemChatRoom(roomId)
{
  return ::g_chat_room_type.SYSTEM.checkRoomId(roomId)
}

function g_chat::getSystemRoomId()
{
  return ::g_chat_room_type.SYSTEM.getRoomId("")
}

function g_chat::joinSquadRoom(callback)
{
  local name = getMySquadRoomId()
  if (::u.isEmpty(name))
    return

  local password = ::g_squad_manager.getSquadRoomPassword()
  if (::u.isEmpty(password))
    return

  if (::menu_chat_handler)
    ::menu_chat_handler.joinRoom.call(::menu_chat_handler, name, password, callback)

  if (::is_platform_ps4)
    on_ps4_squad_room_joined()
}

function g_chat::leaveSquadRoom()
{
  if (::menu_chat_handler)
    ::menu_chat_handler.leaveSquadRoom.call(::menu_chat_handler)
}

function g_chat::isRoomSquad(roomId)
{
  return ::g_chat_room_type.SQUAD.checkRoomId(roomId)
}

function g_chat::isSquadRoomJoined()
{
  local roomId = getMySquadRoomId()
  if (roomId == null)
    return false

  return isRoomJoined(roomId)
}

function g_chat::getMySquadRoomId()
{
  if (!::g_squad_manager.isInSquad())
    return null

  local squadRoomName = ::g_squad_manager.getSquadRoomName()
  if (::u.isEmpty(squadRoomName))
    return null

  return ::g_chat_room_type.SQUAD.getRoomId(squadRoomName)
}

function g_chat::isRoomClan(roomId)
{
  return ::g_chat_room_type.CLAN.checkRoomId(roomId)
}

function g_chat::getMyClanRoomId()
{
  local myClanId = ::clan_get_my_clan_id()
  if (myClanId != "-1")
    return ::g_chat_room_type.CLAN.getRoomId(myClanId)
  return ""
}

function g_chat::getBaseRoomsList() //base rooms list opened on chat load for all players
{
  local res = []
  if (isThreadsView)
    res.append(::g_chat_room_type.THREADS_LIST.getRoomId(""))
  else
    res.append(getSystemRoomId())
  return res
}

g_chat._lastCleanTime <- -1
function g_chat::_checkCleanThreadsList()
{
  if (_lastCleanTime + THREADS_INFO_CLEAN_PERIOD_MSEC > ::dagor.getCurTime())
    return
  _lastCleanTime = ::dagor.getCurTime()

  //mark joined threads new
  foreach(room in rooms)
    if (room.type == ::g_chat_room_type.THREAD)
    {
      local threadInfo = getThreadInfo(room.id)
      threadInfo && threadInfo.markUpdated()
    }

  //clear outdated threads
  foreach(id, thread in threadsInfo)
    if (thread.isOutdated())
      delete threadsInfo[id]
}

function g_chat::getThreadInfo(roomId)
{
  return ::getTblValue(roomId, threadsInfo)
}

function g_chat::addThreadInfoById(roomId)
{
  local res = getThreadInfo(roomId)
  if (res)
    return res

  res = ::ChatThreadInfo(roomId)
  threadsInfo[roomId] <- res
  return res
}

function g_chat::updateThreadInfo(dataBlk)
{
  _checkCleanThreadsList()
  local roomId = dataBlk.thread
  if (!roomId)
    return

  local curThread = getThreadInfo(roomId)
  if (curThread)
    curThread.updateInfo(dataBlk)
  else
    threadsInfo[roomId] <- ::ChatThreadInfo(roomId, dataBlk)

  if (dataBlk.type == "thread_list")
    ::g_chat_latest_threads.onNewThreadInfoToList(threadsInfo[roomId])

  ::broadcastEvent("ChatThreadInfoChanged", { roomId = roomId })
}

function g_chat::createThread(title, categoryName, langTags = null)
{
  if (!checkChatConnected() || !::g_chat.canCreateThreads() )
    return

  if (!langTags)
    langTags = ::g_chat_thread_tag.LANG.prefix + ::g_language.getCurLangInfo().chatId
  local categoryTag = ::g_chat_thread_tag.CATEGORY.prefix + categoryName
  local tagsList = ::implode([langTags, categoryTag], ",")
  ::gchat_raw_command("xtjoin " + tagsList + " :" + prepareThreadTitleToSend(title))
  ::broadcastEvent("ChatThreadCreateRequested")
}

function g_chat::joinThread(roomId)
{
  if (!checkChatConnected())
    return
  if (!::g_chat_room_type.THREAD.checkRoomId(roomId))
    return systemMessage(::loc(CHAT_ERROR_NO_CHANNEL))

  if (!isRoomJoined(roomId))
    ::gchat_raw_command("xtjoin " + roomId)
  else if (::menu_chat_handler)
    ::menu_chat_handler.switchCurRoom(roomId)
}

function g_chat::validateRoomName(name)
{
  return validateRoomNameRegexp.replace("", name)
}

function g_chat::validateChatMessage(text, multilineAllowed = false)
{
  //do not allow players to use tag.  <color=#000000>...
  text = ::stringReplace(text, "<", "[")
  text = ::stringReplace(text, ">", "]")
  if (!multilineAllowed)
    text = ::stringReplace(text, "\\n", " ")
  return text
}

function g_chat::validateThreadTitle(title)
{
  local res = ::stringReplace(title, "\\n", "\n")
  res = ::g_string.clearBorderSymbolsMultiline(res)
  res = validateChatMessage(res, true)
  return res
}

function g_chat::prepareThreadTitleToSend(title)
{
  local res = validateThreadTitle(title)
  return ::stringReplace(res, "\n", "<br>")
}

function g_chat::restoreReceivedThreadTitle(title)
{
  local res = ::stringReplace(title, "\\n", "\n")
  res = ::stringReplace(res, "<br>", "\n")
  res = ::g_string.clearBorderSymbolsMultiline(res)
  return res
}

function g_chat::checkThreadTitleLen(title)
{
  local checkLenTitle = prepareThreadTitleToSend(title)
  local titleLen = utf8(checkLenTitle).charCount()
  return threadTitleLenMin <= titleLen && titleLen <= threadTitleLenMax
}

function g_chat::openRoomCreationWnd()
{
  local devoiceMsg = ::get_chat_devoice_msg("activeTextColor")
  if (devoiceMsg)
    return ::showInfoMsgBox(devoiceMsg)

  ::gui_start_modal_wnd(::gui_handlers.CreateRoomWnd)
}

function g_chat::openChatRoom(roomId, ownerHandler = null)
{
  if (!::openChatScene(ownerHandler))
    return

  if (::menu_chat_handler)
    ::menu_chat_handler.switchCurRoom.call(::menu_chat_handler, roomId)
}

function g_chat::openModifyThreadWnd(threadInfo)
{
  if (threadInfo.canEdit())
    ::handlersManager.loadHandler(::gui_handlers.modifyThreadWnd, { threadInfo = threadInfo })
}

function g_chat::openModifyThreadWndByRoomId(roomId)
{
  local threadInfo = getThreadInfo(roomId)
  if (threadInfo)
    openModifyThreadWnd(threadInfo)
}

function g_chat::modifyThread(threadInfo, modifyTable)
{
  if ("title" in modifyTable)
  {
    local title = modifyTable.title
    if (!checkThreadTitleLen(title))
      return false

    modifyTable.title = validateThreadTitle(title)
  }

  local curTitle = threadInfo.title
  local curTagsString = threadInfo.getFullTagsString()
  local curTimeStamp = threadInfo.timeStamp

  foreach(key, value in modifyTable)
    if (key in threadInfo)
      threadInfo[key] = value

  local isChanged = false
  if (threadInfo.title != curTitle)
  {
    local title = ::g_chat.prepareThreadTitleToSend(threadInfo.title)
    ::gchat_raw_command("xtmeta " + threadInfo.roomId + " topic :" + title)
    isChanged = true
  }

  local newTagsString = threadInfo.getFullTagsString()
  if (newTagsString != curTagsString)
  {
    ::gchat_raw_command("xtmeta " + threadInfo.roomId + " tags " + newTagsString)
    isChanged = true
  }

  if (curTimeStamp != threadInfo.timeStamp)
  {
    ::gchat_raw_command("xtmeta " + threadInfo.roomId + " stamp " + threadInfo.timeStamp)
    isChanged = true
  }

  if (isChanged)
  {
    ::broadcastEvent("ChatThreadInfoChanged", { roomId = threadInfo.roomId })
    ::broadcastEvent("ChatThreadInfoModifiedByPlayer", { threadInfo = threadInfo })
  }

  return true
}

function g_chat::canChooseThreadsLang()
{
  //only moderators can modify chat lang tags atm.
  return ::has_feature("ChatThreadLang") && ::is_myself_anyof_moderators()
}

function g_chat::canCreateThreads()
{
  // it can be useful in China to disallow creating threads for ordinary users
  // only moderators allowed to do so
  return ::is_myself_anyof_moderators() || ::has_feature("ChatThreadCreate")
}

function g_chat::isImRoomOwner(roomData)
{
  if (roomData)
    foreach(member in roomData.users)
      if (member.name == ::my_user_name)
        return member.isOwner
  return false
}

function g_chat::generateInviteMenu(playerName)
{
  local menu = []
  if(::my_user_name == playerName)
    return menu
  foreach(room in rooms)
  {
    if (!room.type.canInviteToRoom)
      continue

    if (room.type.havePlayersList)
    {
      local isMyRoom = false
      local isPlayerInRoom = false
      foreach(member in room.users)
      {
        if(member.isOwner && member.name == ::my_user_name)
          isMyRoom = true
        if(member.name == playerName)
          isPlayerInRoom = true
      }
      if (isPlayerInRoom || (!isMyRoom && room.type.onlyOwnerCanInvite))
        continue
    }

    menu.append({
      text = room.getRoomName()
      show = true
      action = (@(playerName, room) function () { ::gchat_raw_command(::format("INVITE %s %s", playerName, room.id)) })(playerName, room)
    })
  }
  return menu
}

function g_chat::getPlayerRClickMenu(playerName, roomId = null, contact = null, position = null)
{
  if (!contact)
    contact = ::findContactByNick(playerName)
  local uid = contact ? contact.uid : null
  local latestName = contact ? contact.name : playerName
  local clanTag = ""
  if(contact)
    clanTag = contact.clanTag
  else if (latestName in ::clanUserTable)
    clanTag = ::clanUserTable[latestName]

  local isMe = latestName == ::my_user_name
  local inMySquad = ::g_squad_manager.isInMySquad(latestName, false)

  local inSquad = ::g_squad_manager.isInSquad()
  local meLeader = ::g_squad_manager.isSquadLeader()
  local roomData = roomId && getRoomById(roomId)
  local isSquadRoom = roomData != null && roomData.id == getMySquadRoomId()

  local inviteMenu = generateInviteMenu(latestName)
  local isFriend = uid != null && ::isPlayerInFriendsGroup(uid)
  local isBlock = uid != null && ::isPlayerInContacts(uid, ::EPL_BLOCKLIST)
  local isModerator = ::is_myself_anyof_moderators()

  local canComplain = false
  if (!isMe)
  {
    if (roomData
        && (roomData.chatText.find("<Link=PL_"+latestName+">") != null
            || roomData.chatText.find("<Link=PLU_"+uid+">") != null))
      canComplain = true
    else
    {
      local threadInfo = getThreadInfo(roomId)
      if (threadInfo && (threadInfo.ownerNick == latestName || threadInfo.ownerNick == playerName))
        canComplain = true
    }
  }

  local menu = [
    {
      text = ::loc("multiplayer/invite_to_session")
      show = uid && ::SessionLobby.canInvitePlayer(uid)
      action = function () {
        if (::is_psn_player_use_same_titleId(latestName))
          ::g_psn_session_invitations.sendSkirmishInvitation(latestName)
        else
          ::SessionLobby.invitePlayer(uid)
      }
    }
    {
      text = ::loc("contacts/message")
      show = !isMe && playerName != roomId && ::ps4_is_chat_enabled()
      action = (@(latestName) function() {
        ::openChatPrivate(latestName)
      })(latestName)
    }
    {
      text = ::loc("mainmenu/btnUserCard")
      action = (@(uid, latestName) function() { ::gui_modal_userCard(uid?{ uid = uid } : {name = latestName}) })(uid, latestName)
    }
    {
      text = ::loc("mainmenu/btnClanCard")
      show = clanTag!="" && ::has_feature("Clans")
      action = (@(clanTag) function() { ::showClanPage("", "", clanTag)})(clanTag)
    }
    {
      text = ::loc("squad/invite_player")
      show = !isMe && ::has_feature("Squad") && !isBlock && ((meLeader && !inMySquad) || !inSquad)
      action = (@(latestName) function() {
        ::find_contact_by_name_and_do(latestName, ::g_squad_manager,
                                        function(contact)
                                        {
                                          if (contact)
                                            inviteToSquad(contact.uid)
                                        })
      })(latestName)
    }
    {
      text = ::loc("squad/remove_player")
      show = !isMe && meLeader && inMySquad
      action = (@(uid) function() {
        ::g_squad_manager.dismissFromSquad(uid)
      })(uid)
    }
    {
      text = ::loc("squad/tranfer_leadership")
      show = ::g_squad_manager.canTransferLeadership(uid)
      action = (@(uid) function() {
        ::g_squad_manager.transferLeadership(uid)
      })(uid)
    }
    {
      text = ::loc("contacts/friendlist/add")
      show = !isMe && ::has_feature("Friends") && !isFriend && !isBlock
      action = (@(uid, latestName) function() { ::editContactMsgBox({uid = uid, name = latestName}, ::EPL_FRIENDLIST, true, this) })(uid, latestName)
    }
    {
      text = ::loc("contacts/friendlist/remove")
      show = isFriend
      action = (@(uid, latestName) function() { ::editContactMsgBox({uid = uid, name = latestName}, ::EPL_FRIENDLIST, false, this) })(uid, latestName)
    }
    {
      text = ::loc("contacts/blacklist/add")
      show = !isMe && !isFriend && !isBlock
      action = (@(uid, latestName) function() { ::editContactMsgBox({uid = uid, name = latestName}, ::EPL_BLOCKLIST, true, this) })(uid, latestName)
    }
    {
      text = ::loc("contacts/blacklist/remove")
      show = isBlock
      action = (@(uid, latestName) function() { ::editContactMsgBox({uid = uid, name = latestName}, ::EPL_BLOCKLIST, false, this) })(uid, latestName)
    }
    {
      text = ::loc("chat/invite_to_room")
      show = inviteMenu && inviteMenu.len() > 0 && ::ps4_is_chat_enabled()
      action = @() ::open_invite_menu(inviteMenu, position)
    }
    {
      text = ::loc("chat/kick_from_room")
      show = !isSquadRoom && isImRoomOwner(roomData)
      action = (@(latestName) function() {
        if (::menu_chat_handler)
          ::menu_chat_handler.kickPlayeFromRoom(latestName)
      })(latestName)
    }
    {
      text = ::loc("mainmenu/btnComplain")
      show = canComplain
      action = (@(uid, latestName, clanTag, roomData, roomId) function() {
        local chatLog = roomData ? roomData.chatText : ""
        local config = {
          userId = uid,
          name = latestName,
          clanTag = clanTag,
          roomId = roomId,
          roomName = roomData ? roomData.getRoomName() : ""
        }

        local threadInfo = getThreadInfo(roomId)
        if (threadInfo)
        {
          chatLog = ::format("Thread category: %s\nThread title:\n%s\nOwner userid: %s\nOwner nick: %s\nRoom log:\n%s"
            threadInfo.category,
            threadInfo.title,
            threadInfo.ownerUid,
            threadInfo.ownerNick,
            chatLog
          )
          if (!roomData)
            config.roomName = ::g_chat_room_type.THREAD.getRoomName(roomId)
        }

        ::gui_modal_complain(config, chatLog)
      })(uid, latestName, clanTag, roomData, roomId)
    }
    {
      text = ::loc("contacts/copyNickToEditbox")
      show = !isMe && ::show_console_buttons
      action = (@(latestName) function() {
        if (::menu_chat_handler)
          ::menu_chat_handler.addNickToEdit(latestName)
      })(latestName)
    }
    {
      show = isModerator
    }
    {
      text = ::loc("contacts/moderator_copyname")
      show = isModerator
      action = (@(latestName) function() { ::copy_to_clipboard(latestName) })(latestName)
    }
    {
      text = ::loc("contacts/moderator_ban")
      show = ::myself_can_devoice() || ::myself_can_ban()
      action = (@(contact, latestName, roomData) function() {
        ::gui_modal_ban(contact || { name = latestName }, roomData? roomData.chatText : "")
      })(contact, latestName, roomData)
    }
  ]

  return menu
}

function g_chat::showPlayerRClickMenu(playerName, roomId = null, contact = null, position = null)
{
  local menu = getPlayerRClickMenu(playerName, roomId, contact, position)
  ::gui_right_click_menu(menu, this, position)
}

function g_chat::generatePlayerLink(name, uid = null)
{
  if(uid)
    return "PLU_" + uid
  return "PL_" + name
}

function g_chat::onEventInitConfigs(p)
{
  local blk = get_game_settings_blk()
  if (!::u.isDataBlock(blk.chat))
    return

  threadTitleLenMin = blk.chat.threadTitleLenMin || threadTitleLenMin
  threadTitleLenMax = blk.chat.threadTitleLenMax || threadTitleLenMax
}

function g_chat::getNewMessagesCount()
{
  local result = 0

  foreach (room in ::g_chat.rooms)
  {
    result += room.newImportantMessagesCount
  }

  return result
}

function g_chat::haveNewMessages()
{
  return getNewMessagesCount() > 0
}

function g_chat::sendLocalizedMessage(roomId, langConfig, isSeparationAllowed = true, needAssert = true)
{
  local message = ::g_system_msg.configToJsonString(langConfig, validateChatMessage)
  local messageLen = message.len() //to be visible in assert callstack
  if (messageLen > MAX_MSG_LEN)
  {
    local res = false
    if (isSeparationAllowed && ::u.isArray(langConfig) && langConfig.len() > 1)
    {
      needAssert = false
      //do not allow to separate more than on 2 messages because of chat server restrictions.
      local sliceIdx = (langConfig.len() + 1) / 2
      res = sendLocalizedMessage(roomId, langConfig.slice(0, sliceIdx), false)
      res = res && sendLocalizedMessage(roomId, langConfig.slice(sliceIdx), false)
    }

    if (!res && needAssert)
    {
      local partsAmount = ::u.isArray(langConfig) ? langConfig.len() : 1
      ::script_net_assert_once("too long json message", "Too long json message to chat. partsAmount = " + partsAmount)
    }
    return res
  }

  ::gchat_chat_message(roomId, LOCALIZED_MESSAGE_PREFIX + message)
  return true
}

function g_chat::localizeReceivedMessage(message)
{
  local jsonString = ::cut_prefix(message, LOCALIZED_MESSAGE_PREFIX)
  if (!jsonString)
    return message

  local res = ::g_system_msg.jsonStringToLang(jsonString, null, "\n   ")
  if (!res)
    dagor.debug("Chat: failed to localize json message: " + message)
  return res || ""
}

function g_chat::sendLocalizedMessageToSquadRoom(langConfig)
{
  local squadRoomId = getMySquadRoomId()
  if (!::u.isEmpty(squadRoomId))
    sendLocalizedMessage(squadRoomId, langConfig)
}

function g_chat::getSenderColor(senderName, isHighlighted = true, isPrivateChat = false, defaultColor = ::g_chat.color.sender)
{
  if (isPrivateChat)
    return color.senderPrivate[isHighlighted]
  if (senderName == ::my_user_name)
    return color.senderMe[isHighlighted]
  if (::g_squad_manager.isInMySquad(senderName, false))
    return color.senderSquad[isHighlighted]
  if (::isPlayerNickInContacts(senderName, ::EPL_FRIENDLIST))
    return color.senderFriend[isHighlighted]
  return ::u.isTable(defaultColor) ? defaultColor[isHighlighted] : defaultColor
}

::g_script_reloader.registerPersistentDataFromRoot("g_chat")
::subscribe_handler(::g_chat, ::g_listener_priority.DEFAULT_HANDLER)
