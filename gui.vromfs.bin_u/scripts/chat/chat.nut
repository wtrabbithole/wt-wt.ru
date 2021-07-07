local penalties = require("scripts/penitentiary/penalties.nut")
local systemMsg = require("scripts/utils/systemMsg.nut")
local playerContextMenu = require("scripts/user/playerContextMenu.nut")
local dirtyWordsFilter = require("scripts/dirtyWords/dirtyWords.nut")
local { clearBorderSymbolsMultiline } = require("std/string.nut")

global enum chatUpdateState {
  OUTDATED
  IN_PROGRESS
  UPDATED
}

global enum chatErrorName {
  NO_SUCH_NICK_CHANNEL    = "401"
  NO_SUCH_CHANNEL         = "403"
  CANT_SEND_MESSAGE       = "404"
  CANNOT_JOIN_CHANNEL_NO_INVITATION = "473"
  CANNOT_JOIN_THE_CHANNEL = "475"
}

::g_chat <- {
  [PERSISTENT_DATA_PARAMS] = ["isThreadsView", "rooms", "threadsInfo", "userCaps", "userCapsGen",
                              "threadTitleLenMin", "threadTitleLenMax"]

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
  userCapsGen = 1 // effectively makes caps falsy
  userCaps = {
      ALLOWPOST     = 0
      ALLOWPRIVATE  = 0
      ALLOWJOIN     = 0
      ALLOWXTJOIN   = 0
      ALLOWSPAWN    = 0
      ALLOWXTSPAWN  = 0
      ALLOWINVITE   = 0
    }

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
g_chat.filterMessageText <- function filterMessageText(text, isMyMessage)
{
  if (::get_option(::USEROPT_CHAT_FILTER).value &&
    (!isMyMessage || ::chat_filter_for_myself))
    return dirtyWordsFilter.checkPhrase(text)
  return text
}
::cross_call_api.filter_chat_message <- ::g_chat.filterMessageText


g_chat.convertBlockedMsgToLink <- function convertBlockedMsgToLink(msg)
{
  //space work as close link. but non-breakable space - work as other symbols.
  //rnd for duplicate blocked messages
  return ::format("BL_%02d_%s", ::math.rnd() % 99, ::stringReplace(msg, " ", ::nbsp))
}


g_chat.convertLinkToBlockedMsg <- function convertLinkToBlockedMsg(link)
{
  local prefixLen = 6 // Prefix is "BL_NN_", where NN are digits.
  return ::stringReplace(link.slice(prefixLen), ::nbsp, " ")
}


g_chat.makeBlockedMsg <- function makeBlockedMsg(msg, replacelocId = "chat/blocked_message")
{
  local link = convertBlockedMsgToLink(msg)
  return ::format("<Link=%s>%s</Link>", link, ::loc(replacelocId))
}

g_chat.makeXBoxRestrictedMsg <- function makeXBoxRestrictedMsg(msg)
{
  return makeBlockedMsg(msg, "chat/blocked_message/xbox_restriction")
}

g_chat.checkBlockedLink <- function checkBlockedLink(link)
{
  return !::is_platform_xbox && (link.len() > 6 && link.slice(0, 3) == "BL_")
}


g_chat.revealBlockedMsg <- function revealBlockedMsg(text, link)
{
  local start = text.indexof("<Link=" + link)
  if (start == null)
    return text

  local end = text.indexof("</Link>", start)
  if (end == null)
    return text

  end += "</Link>".len()

  local msg = convertLinkToBlockedMsg(link)
  text = text.slice(0, start) + msg + text.slice(end)
  return text
}


g_chat.onCharConfigsLoaded <- function onCharConfigsLoaded()
{
  isThreadsView = ::has_feature("ChatThreadsView")
}

g_chat.checkChatConnected <- function checkChatConnected()
{
  if (::gchat_is_connected())
    return true

  systemMessage(::loc("chat/not_connected"))
  return false
}

g_chat.nextSystemMessageTime <- 0
g_chat.systemMessage <- function systemMessage(msg, needPopup = true, forceMessage = false)
{
  if ( (!forceMessage) && (nextSystemMessageTime > ::dagor.getCurTime()) )
    return

  nextSystemMessageTime = ::dagor.getCurTime() + CHAT_SYSTEM_MESSAGE_TIMEOUT_MSEC

  if (::menu_chat_handler)
    ::menu_chat_handler.addRoomMsg("", "", msg)
  if (needPopup && ::get_gui_option_in_mode(::USEROPT_SHOW_SOCIAL_NOTIFICATIONS, ::OPTIONS_MODE_GAMEPLAY))
    ::g_popups.add(null, ::colorize(SYSTEM_COLOR, msg))
}

g_chat.getRoomById <- function getRoomById(id)
{
  return ::u.search(rooms, (@(id) function (room) { return room.id == id })(id))
}

g_chat.isRoomJoined <- function isRoomJoined(roomId)
{
  local room = getRoomById(roomId)
  return room != null && room.joined
}

g_chat._roomJoinedIdx <- 0
g_chat.addRoom <- function addRoom(room)
{
  room.roomJoinedIdx = _roomJoinedIdx++
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

g_chat.getMaxRoomMsgAmount <- function getMaxRoomMsgAmount()
{
  return ::is_myself_anyof_moderators() ? MAX_ROOM_MSGS_FOR_MODERATOR : MAX_ROOM_MSGS
}

g_chat.isSystemUserName <- function isSystemUserName(name)
{
  return ::g_string.endsWith(name, SYSTEM_MESSAGES_USER_ENDING)
}

g_chat.isSystemChatRoom <- function isSystemChatRoom(roomId)
{
  return ::g_chat_room_type.SYSTEM.checkRoomId(roomId)
}

g_chat.getSystemRoomId <- function getSystemRoomId()
{
  return ::g_chat_room_type.SYSTEM.getRoomId("")
}

g_chat.openPrivateRoom <- function openPrivateRoom(name, ownerHandler)
{
  if (::openChatScene(ownerHandler))
    ::menu_chat_handler.changePrivateTo.call(::menu_chat_handler, name)
}

g_chat.joinSquadRoom <- function joinSquadRoom(callback)
{
  local name = getMySquadRoomId()
  if (::u.isEmpty(name))
    return

  local password = ::g_squad_manager.getSquadRoomPassword()
  if (::u.isEmpty(password))
    return

  if (::menu_chat_handler)
    ::menu_chat_handler.joinRoom.call(::menu_chat_handler, name, password, callback)
}

g_chat.leaveSquadRoom <- function leaveSquadRoom()
{
  if (::menu_chat_handler)
    ::menu_chat_handler.leaveSquadRoom.call(::menu_chat_handler)
}

g_chat.isRoomSquad <- function isRoomSquad(roomId)
{
  return ::g_chat_room_type.SQUAD.checkRoomId(roomId)
}

g_chat.isSquadRoomJoined <- function isSquadRoomJoined()
{
  local roomId = getMySquadRoomId()
  if (roomId == null)
    return false

  return isRoomJoined(roomId)
}

g_chat.getMySquadRoomId <- function getMySquadRoomId()
{
  if (!::g_squad_manager.isInSquad())
    return null

  local squadRoomName = ::g_squad_manager.getSquadRoomName()
  if (::u.isEmpty(squadRoomName))
    return null

  return ::g_chat_room_type.SQUAD.getRoomId(squadRoomName)
}

g_chat.isRoomClan <- function isRoomClan(roomId)
{
  return ::g_chat_room_type.CLAN.checkRoomId(roomId)
}

g_chat.getMyClanRoomId <- function getMyClanRoomId()
{
  local myClanId = ::clan_get_my_clan_id()
  if (myClanId != "-1")
    return ::g_chat_room_type.CLAN.getRoomId(myClanId)
  return ""
}

g_chat.getBaseRoomsList <- function getBaseRoomsList() //base rooms list opened on chat load for all players
{
  local res = []
  if (isThreadsView)
    res.append(::g_chat_room_type.THREADS_LIST.getRoomId(""))
  else
    res.append(getSystemRoomId())
  return res
}

g_chat._lastCleanTime <- -1
g_chat._checkCleanThreadsList <- function _checkCleanThreadsList()
{
  if (_lastCleanTime + THREADS_INFO_CLEAN_PERIOD_MSEC > ::dagor.getCurTime())
    return
  _lastCleanTime = ::dagor.getCurTime()

  //mark joined threads new
  foreach(room in rooms)
    if (room.type == ::g_chat_room_type.THREAD)
    {
      local threadInfo = getThreadInfo(room.id)
      if (threadInfo)
        threadInfo.markUpdated()
    }

  //clear outdated threads
  local outdatedArr = []
  foreach(id, thread in threadsInfo)
    if (thread.isOutdated())
      outdatedArr.append(id)
  foreach(id in outdatedArr)
    delete threadsInfo[id]
}

g_chat.getThreadInfo <- function getThreadInfo(roomId)
{
  return ::getTblValue(roomId, threadsInfo)
}

g_chat.addThreadInfoById <- function addThreadInfoById(roomId)
{
  local res = getThreadInfo(roomId)
  if (res)
    return res

  res = ::ChatThreadInfo(roomId)
  threadsInfo[roomId] <- res
  return res
}

g_chat.updateThreadInfo <- function updateThreadInfo(dataBlk)
{
  _checkCleanThreadsList()
  local roomId = dataBlk?.thread
  if (!roomId)
    return

  local curThread = getThreadInfo(roomId)
  if (curThread)
    curThread.updateInfo(dataBlk)
  else
    threadsInfo[roomId] <- ::ChatThreadInfo(roomId, dataBlk)

  if (dataBlk?.type == "thread_list")
    ::g_chat_latest_threads.onNewThreadInfoToList(threadsInfo[roomId])

  ::update_gamercards_chat_info()
  ::broadcastEvent("ChatThreadInfoChanged", { roomId = roomId })
}

g_chat.haveProgressCaps <- function haveProgressCaps(name)
{
  return (userCaps?[name]) == userCapsGen;
}

g_chat.updateProgressCaps <- function updateProgressCaps(dataBlk)
{
  userCapsGen++;

  if ((dataBlk?.caps ?? "") != "")
  {
    local capsList = ::split(dataBlk.caps, ",");
    foreach(idx, prop in capsList)
    {
      if (prop in userCaps)
        userCaps[prop] = userCapsGen;
    }
  }

  dagor.debug("ChatProgressCapsChanged: "+userCapsGen)
  debugTableData(userCaps);
  ::broadcastEvent("ChatProgressCapsChanged")
}

g_chat.createThread <- function createThread(title, categoryName, langTags = null)
{
  if (!checkChatConnected() || !::g_chat.canCreateThreads() )
    return

  if (!langTags)
    langTags = ::g_chat_thread_tag.LANG.prefix + ::g_language.getCurLangInfo().chatId
  local categoryTag = ::g_chat_thread_tag.CATEGORY.prefix + categoryName
  local tagsList = ::g_string.implode([langTags, categoryTag], ",")
  ::gchat_raw_command("xtjoin " + tagsList + " :" + prepareThreadTitleToSend(title))
  ::broadcastEvent("ChatThreadCreateRequested")
}

g_chat.joinThread <- function joinThread(roomId)
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

g_chat.validateRoomName <- function validateRoomName(name)
{
  return validateRoomNameRegexp.replace("", name)
}

g_chat.validateChatMessage <- function validateChatMessage(text, multilineAllowed = false)
{
  //do not allow players to use tag.  <color=#000000>...
  text = ::stringReplace(text, "<", "[")
  text = ::stringReplace(text, ">", "]")
  if (!multilineAllowed)
    text = ::stringReplace(text, "\\n", " ")
  return text
}

g_chat.validateThreadTitle <- function validateThreadTitle(title)
{
  local res = ::stringReplace(title, "\\n", "\n")
  res = clearBorderSymbolsMultiline(res)
  res = validateChatMessage(res, true)
  return res
}

g_chat.prepareThreadTitleToSend <- function prepareThreadTitleToSend(title)
{
  local res = validateThreadTitle(title)
  return ::stringReplace(res, "\n", "<br>")
}

g_chat.restoreReceivedThreadTitle <- function restoreReceivedThreadTitle(title)
{
  local res = ::stringReplace(title, "\\n", "\n")
  res = ::stringReplace(res, "<br>", "\n")
  res = clearBorderSymbolsMultiline(res)
  res = validateChatMessage(res, true)
  return res
}

g_chat.checkThreadTitleLen <- function checkThreadTitleLen(title)
{
  local checkLenTitle = prepareThreadTitleToSend(title)
  local titleLen = utf8(checkLenTitle).charCount()
  return threadTitleLenMin <= titleLen && titleLen <= threadTitleLenMax
}

g_chat.openRoomCreationWnd <- function openRoomCreationWnd()
{
  local devoiceMsg = penalties.getDevoiceMessage("activeTextColor")
  if (devoiceMsg)
    return ::showInfoMsgBox(devoiceMsg)

  ::gui_start_modal_wnd(::gui_handlers.CreateRoomWnd)
}

g_chat.openChatRoom <- function openChatRoom(roomId, ownerHandler = null)
{
  if (!::openChatScene(ownerHandler))
    return

  if (::menu_chat_handler)
    ::menu_chat_handler.switchCurRoom.call(::menu_chat_handler, roomId)
}

g_chat.openModifyThreadWnd <- function openModifyThreadWnd(threadInfo)
{
  if (threadInfo.canEdit())
    ::handlersManager.loadHandler(::gui_handlers.modifyThreadWnd, { threadInfo = threadInfo })
}

g_chat.openModifyThreadWndByRoomId <- function openModifyThreadWndByRoomId(roomId)
{
  local threadInfo = getThreadInfo(roomId)
  if (threadInfo)
    openModifyThreadWnd(threadInfo)
}

g_chat.modifyThread <- function modifyThread(threadInfo, modifyTable)
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

g_chat.canChooseThreadsLang <- function canChooseThreadsLang()
{
  //only moderators can modify chat lang tags atm.
  return ::has_feature("ChatThreadLang") && ::is_myself_anyof_moderators()
}

g_chat.canCreateThreads <- function canCreateThreads()
{
  // it can be useful in China to disallow creating threads for ordinary users
  // only moderators allowed to do so
  return ::is_myself_anyof_moderators() || ::has_feature("ChatThreadCreate")
}

g_chat.isImRoomOwner <- function isImRoomOwner(roomData)
{
  if (roomData)
    foreach(member in roomData.users)
      if (member.name == ::my_user_name)
        return member.isOwner
  return false
}

g_chat.generateInviteMenu <- function generateInviteMenu(playerName)
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
      action = (@(playerName, room) function () {
          ::gchat_raw_command(::format("INVITE %s %s",
                                        ::gchat_escape_target(playerName),
                                        ::gchat_escape_target(room.id)))
          })(playerName, room)
    })
  }
  return menu
}

g_chat.showPlayerRClickMenu <- function showPlayerRClickMenu(playerName, roomId = null, contact = null, position = null)
{
  playerContextMenu.showMenu(contact, this, {
    position = position
    roomId = roomId
    playerName = playerName
    canComplain = true
  })
}

g_chat.generatePlayerLink <- function generatePlayerLink(name, uid = null)
{
  if(uid)
    return "PLU_" + uid
  return "PL_" + name
}

g_chat.onEventInitConfigs <- function onEventInitConfigs(p)
{
  local blk = ::get_game_settings_blk()
  if (!::u.isDataBlock(blk?.chat))
    return

  threadTitleLenMin = blk.chat?.threadTitleLenMin ?? threadTitleLenMin
  threadTitleLenMax = blk.chat?.threadTitleLenMax ?? threadTitleLenMax
}

g_chat.getNewMessagesCount <- function getNewMessagesCount()
{
  local result = 0

  foreach (room in ::g_chat.rooms)
    if (!room.hidden && !room.concealed())
      result += room.newImportantMessagesCount

  return result
}

g_chat.haveNewMessages <- function haveNewMessages()
{
  return getNewMessagesCount() > 0
}

g_chat.sendLocalizedMessage <- function sendLocalizedMessage(roomId, langConfig, isSeparationAllowed = true, needAssert = true)
{
  local message = systemMsg.configToJsonString(langConfig, validateChatMessage)
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

  ::gchat_chat_message(::gchat_escape_target(roomId), LOCALIZED_MESSAGE_PREFIX + message)
  return true
}

g_chat.localizeReceivedMessage <- function localizeReceivedMessage(message)
{
  local jsonString = ::g_string.cutPrefix(message, LOCALIZED_MESSAGE_PREFIX)
  if (!jsonString)
    return message

  local res = systemMsg.jsonStringToLang(jsonString, null, "\n   ")
  if (!res)
    dagor.debug("Chat: failed to localize json message: " + message)
  return res || ""
}

g_chat.sendLocalizedMessageToSquadRoom <- function sendLocalizedMessageToSquadRoom(langConfig)
{
  local squadRoomId = getMySquadRoomId()
  if (!::u.isEmpty(squadRoomId))
    sendLocalizedMessage(squadRoomId, langConfig)
}

g_chat.getSenderColor <- function getSenderColor(senderName, isHighlighted = true, isPrivateChat = false, defaultColor = ::g_chat.color.sender)
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
