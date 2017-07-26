class ChatThreadInfo
{
  roomId = "" //threadRoomId
  lastUpdateTime = -1

  title = ""
  category = ""
  numPosts = 0
  customTags = null
  ownerUid = ""
  ownerNick = ""
  ownerClanTag = ""
  membersAmount = 0
  isHidden = false
  isPinned = false
  timeStamp = -1
  langs = null

  isValid = true

  constructor(threadRoomId, dataBlk = null) //dataBlk from chat response
  {
    roomId = threadRoomId
    isValid = roomId.len() > 0
    ::dagor.assertf(::g_chat_room_type.THREAD.checkRoomId(roomId), "Chat thread created with not thread id = " + roomId)
    langs = []

    updateInfo(dataBlk)
  }

  function markUpdated()
  {
    lastUpdateTime = ::dagor.getCurTime()
  }

  function invalidate()
  {
    isValid = false
  }

  function isOutdated()
  {
    return lastUpdateTime + ::g_chat.THREADS_INFO_TIMEOUT_MSEC < ::dagor.getCurTime()
  }

  function checkRefreshThread()
  {
    if (!isValid
        || !::g_chat.checkChatConnected()
        || lastUpdateTime + ::g_chat.THREAD_INFO_REFRESH_DELAY_MSEC > ::dagor.getCurTime()
       )
      return

    ::gchat_raw_command("xtmeta " + roomId)
  }

  function updateInfo(dataBlk)
  {
    if (!dataBlk)
      return

    title = ::g_chat.restoreReceivedThreadTitle(dataBlk.topic) || title
    if (title == "")
      title = roomId
    numPosts = dataBlk.numposts || numPosts

    updateInfoTags(::u.isString(dataBlk.tags) ? ::split(dataBlk.tags, ",") : [])
    if (ownerNick.len() && ownerUid.len())
      ::getContact(ownerUid, ownerNick, ownerClanTag)

    markUpdated()
  }

  function updateInfoTags(tagsList)
  {
    foreach(tagType in ::g_chat_thread_tag.types)
    {
      if (!tagType.isRegular)
        continue

      tagType.updateThreadBeforeTagsUpdate(this)

      local found = false
      for(local i = tagsList.len() - 1; i >= 0; i--)
        if (tagType.updateThreadByTag(this, tagsList[i]))
        {
          tagsList.remove(i)
          found = true
        }

      if (!found)
        tagType.updateThreadWhenNoTag(this)
    }
    customTags = tagsList
    sortLangList()
  }

  function getFullTagsString()
  {
    local resArray = []
    foreach(tagType in ::g_chat_thread_tag.types)
    {
      if (!tagType.isRegular)
        continue

      local str = tagType.getTagString(this)
      if (str.len())
        resArray.push(str)
    }
    resArray.extend(customTags)
    return ::implode(resArray, ",")
  }

  function sortLangList()
  {
    //usually only one lang in thread, but moderators can set some threads to multilang
    if (langs.len() < 2)
      return

    local unsortedLangs = clone langs
    langs.clear()
    foreach(langInfo in ::g_language.getGameLocalizationInfo())
    {
      local idx = unsortedLangs.find(langInfo.chatId)
      if (idx >= 0)
        langs.append(unsortedLangs.remove(idx))
    }
    langs.extend(unsortedLangs) //unknown langs at the end
  }

  function isMyThread()
  {
    return ownerUid == "" || ownerUid == ::my_user_id_str
  }

  function getTitle()
  {
    return ::getFilteredChatMessage(title, isMyThread())
  }

  function getOwnerText(isColored = true, defaultColor = "")
  {
    if (!ownerNick.len())
      return ownerUid

    local res = ownerClanTag.len() ? ownerClanTag + " " : ""
    res += ownerNick
    if (isColored)
      res = ::colorize(::g_chat.getSenderColor(ownerNick, false, false, defaultColor), res)
    return res
  }

  function getRoomTooltipText()
  {
    local res = getOwnerText(true, "userlogColoredText")
    res += "\n" + ::loc("chat/thread/participants") + ::loc("ui/colon")
           + ::colorize("activeTextColor", membersAmount)
    res += "\n\n" + getTitle()
    return ::tooltipColorTheme(res)
  }

  function isJoined()
  {
    return ::g_chat.isRoomJoined(roomId)
  }

  function join()
  {
    ::g_chat.joinThread(roomId)
  }

  function showOwnerMenu(position = null)
  {
    local contact = ::getContact(ownerUid, ownerNick, ownerClanTag)
    ::g_chat.showPlayerRClickMenu(ownerNick, roomId, contact, position)
  }

  function getJoinText()
  {
    return isJoined() ? ::loc("chat/showThread") : ::loc("chat/joinThread")
  }

  function getMembersAmountText()
  {
    return ::loc("chat/thread/participants") + ::loc("ui/colon") + membersAmount
  }

  function showThreadMenu(position = null)
  {
    local thread = this
    local menu = [
      {
        text = getJoinText()
        action = (@(thread) function() {
          thread.join()
        })(thread)
      }
    ]

    local contact = ::getContact(ownerUid, ownerNick, ownerClanTag)
    menu.extend(::g_chat.getPlayerRClickMenu(ownerNick, roomId, contact, position))

    ::gui_right_click_menu(menu, ::g_chat, position)
  }

  function canEdit()
  {
    return ::is_myself_anyof_moderators()
  }

  function setObjValueById(objNest, id, value)
  {
    local obj = objNest.findObject(id)
    if (::checkObj(obj))
      obj.setValue(value)
  }

  function updateInfoObj(obj, updateActionBtn = false)
  {
    if (!::checkObj(obj))
      return

    obj.active = isJoined() ? "yes" : "no"

    if (updateActionBtn)
      setObjValueById(obj, "action_btn", getJoinText())

    setObjValueById(obj, "ownerName_" + roomId, getOwnerText())
    setObjValueById(obj, "thread_title", getTitle())
    setObjValueById(obj, "thread_members", getMembersAmountText())
  }

  function needShowLang()
  {
    return ::g_chat.canChooseThreadsLang()
  }

  function getLangsList()
  {
    local res = []
    foreach(langId in langs)
    {
      local langInfo = ::g_language.getLangInfoByChatId(langId)
      if (langInfo)
        res.append(langInfo)
    }
    return res
  }
}