local penalties = require("scripts/penitentiary/penalties.nut")

::menu_chat_handler <- null
::menu_chat_sizes <- null
::last_chat_scene_show <- false
::empty_chat_text <- ""
::last_send_messages <- []
::delayed_chat_messages <- ""
::clanUserTable <- {}

::default_chat_rooms <- ["general"]
::langs_list <- ["en", "ru"] //first is default
::global_chat_rooms_list <- null
::global_chat_rooms <- [{name = "general", langs = ["en", "ru", "de", "zh", "vn"] },
                        {name = "radio", langs = ["ru"], hideInOtherLangs = true },
                        {name = "lfg" },
                        {name = "historical"},
                        {name = "realistic"}
                       ]

::punctuation_list <- [" ", ".", ",", ":", ";", "\"", "'", "~","!","@","#","$","%","^","&","*",
                       "(",")","+","|","-","=","\\","/","<",">","[","]","{","}","`","?"]
::cur_chat_lang <- ::loc("current_lang")

::available_cmd_list <- ["help", //local command to view help
                         "edit", //local command to open thread edit window for opened thread
                         "msg", "join", "part", "invite", "mode"
                         "kick", /*"list",*/
                         /* "ping", "users", */
                         "shelp", "squad_invite", "sinvite", "squad_remove", "sremove", "squad_ready", "sready",
                         "reauth", "xpost", "mpost", "p_check"
                        ]

::voiceChatIcons <- {
  [voiceChatStats.online] = "voip_enabled",
  //[voiceChatStats.offline] = "voip_disabled",
  [voiceChatStats.talking] = "voip_talking"
}

::g_script_reloader.registerPersistentData("MenuChatGlobals", ::getroottable(), ["clanUserTable"]) //!!FIX ME: must be in contacts

function sortChatUsers(a, b)
{
  if (a.name > b.name) return 1
    else if (a.name < b.name) return -1
  return 0;
}


function getGlobalRoomsListByLang(lang, roomsList = null)
{
  local res = []
  local def_lang = ::isInArray(lang, ::langs_list)? lang : ::langs_list[0]
  foreach(r in ::global_chat_rooms)
  {
    local l = def_lang
    if ("langs" in r && r.langs.len())
    {
      l = ::isInArray(lang, r.langs)? lang : r.langs[0]
      if (::getTblValue("hideInOtherLangs", r, false) && !::isInArray(lang, r.langs))
        continue
    }
    if (!roomsList || ::isInArray(r.name, roomsList))
      res.append(r.name + "_" + l)
  }
  return res
}

function getGlobalRoomsList(all_lang=false)
{
  local res = getGlobalRoomsListByLang(::cur_chat_lang)
  if (all_lang)
    foreach(lang in ::langs_list)
      if (lang!=::cur_chat_lang)
      {
        local list = getGlobalRoomsListByLang(lang)
        foreach(ch in list)
          if (!::isInArray(ch, res))
            res.append(ch)
      }
  return res
}
::global_chat_rooms_list = getGlobalRoomsList(true)

class ::MenuChatHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  needLocalEcho = true
  skipMyMessages = false //to skip local echo from code events
  presenceDetectionTimer = 0

  static roomRegexp = regexp2("^#[^\\s]")

  roomHandlerWeak = null

  prevScenes = [] //{ scene, show }

  wndControlsAllowMask = CtrlsInGui.CTRL_ALLOW_FULL

  function constructor(gui_scene, params = {})
  {
    ::g_script_reloader.registerPersistentData("MenuChatHandler", this, ["roomsInited"]) //!!FIX ME: must be in g_chat

    base.constructor(gui_scene, params)
    ::subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)
  }

  function isValid()
  {
    return true
  }

  function getControlsAllowMask()
  {
    if (!::last_chat_scene_show || !checkScene() || !scene.isEnabled())
      return CtrlsInGui.CTRL_ALLOW_FULL
    return wndControlsAllowMask
  }

  function updateControlsAllowMask()
  {
    local mask = CtrlsInGui.CTRL_ALLOW_FULL

    if (::last_chat_scene_show) {
      local focusObj = getCurFocusObj(true)
      if (::check_obj(focusObj))
        if (::show_console_buttons)
          mask = CtrlsInGui.CTRL_ALLOW_VEHICLE_FULL & ~CtrlsInGui.CTRL_ALLOW_VEHICLE_XINPUT
        else if (focusObj.id == "menuchat_input")
          mask = CtrlsInGui.CTRL_ALLOW_VEHICLE_FULL & ~CtrlsInGui.CTRL_ALLOW_VEHICLE_KEYBOARD
    }

    switchControlsAllowMask(mask)
  }

  _lastMaskUpdateDelayedCall = 0
  function updateControlsAllowMaskDelayed()
  {
    if (_lastMaskUpdateDelayedCall
        && ::dagor.getCurTime() - _lastMaskUpdateDelayedCall < LOST_DELAYED_ACTION_MSEC)
      return

    _lastMaskUpdateDelayedCall = ::dagor.getCurTime()
    guiScene.performDelayed(this, function()
    {
      _lastMaskUpdateDelayedCall = 0
      updateControlsAllowMask()
    })
  }

  function onChatFocus(obj)
  {
    updateControlsAllowMaskDelayed()
  }

  function initChat(obj, resetList = true)
  {
    if (obj!=null && obj == scene)
      return

    needLocalEcho = !::is_vendor_tencent()

    set_gchat_event_cb(null, ::menuChatCb)
    chatSceneShow(false)
    scene = obj
    sceneChanged = true
    if (resetList)
      prevScenes = []
    chatSceneShow(true)
    reloadChatScene()
  }

  function switchScene(obj, onlyShow = false)
  {
    if (!::checkObj(obj) || (::checkObj(scene) && scene.isEqual(obj)))
    {
      if (!onlyShow || !::last_chat_scene_show)
        chatSceneShow()
    } else
    {
      prevScenes.append({
        scene = scene
        show = ::last_chat_scene_show
        roomHandlerWeak = roomHandlerWeak && roomHandlerWeak.weakref()
      })
      roomHandlerWeak = null
      removeFromPrevScenes(obj)
      initChat(obj, false)
    }
  }

  function removeFromPrevScenes(obj)
  {
    for(local i=prevScenes.len()-1; i>=0; i--)
    {
      local scn = prevScenes[i].scene
      if (!::checkObj(scn) || scn.isEqual(obj))
        prevScenes.remove(i)
    }
  }

  function checkScene()
  {
    if (::checkObj(scene))
      return true

    for(local i=prevScenes.len()-1; i>=0; i--)
      if (::checkObj(prevScenes[i].scene))
      {
        scene = prevScenes[i].scene
        guiScene = scene.getScene()
        local prevRoomHandler = prevScenes[i].roomHandlerWeak
        roomHandlerWeak = prevRoomHandler && prevRoomHandler.weakref()
        sceneChanged = true
        chatSceneShow(prevScenes[i].show || ::last_chat_scene_show)
        return true
      } else
        prevScenes.remove(i)
    scene = null
    return false
  }

  function reloadChatScene()
  {
    if (!checkScene())
      return

    if (!scene.findObject("menuchat"))
    {
      guiScene = scene.getScene()
      sceneChanged = true
      guiScene.replaceContent(scene, "gui/chat/menuChat.blk", this)
      setSavedSizes()
      scene.findObject("menu_chat_update").setUserData(this)
      showSceneBtn("chat_input_place", ::ps4_is_chat_enabled())
      local chatObj = scene.findObject("menuchat_input")
      chatObj.show(::ps4_is_chat_enabled())
      chatObj["max-len"] = ::g_chat.MAX_MSG_LEN.tostring()
      showSceneBtn("btn_send", ::ps4_is_chat_enabled())
      searchInited = false
      updateRoomsList()
    }
  }

  function fillList(listObj, formatText, listTotal)
  {
    local total = listObj.childrenCount()
    if (total > listTotal)
      for(local i = total-1; i>=listTotal; i--)
        guiScene.destroyElement(listObj.getChild(i))
    else if (total < listTotal)
    {
      local data = ""
      for(local i = total; i<listTotal; i++)
        data += format(formatText, i, i)
      guiScene.appendWithBlk(listObj, data, this)
    }
  }

  function switchCurRoom(room, needUpdateWindow = true)
  {
    if (::u.isString(room))
      room = ::g_chat.getRoomById(room)
    if (!room || room == curRoom)
      return

    curRoom = room
    sceneChanged = true
    if (needUpdateWindow)
      updateRoomsList()
  }

  function updateRoomsList()
  {
    if (!checkScene())
      return
    local obj = scene.findObject("rooms_list")
    if(!::checkObj(obj))
      return

    guiScene.setUpdatesEnabled(false, false)
    local roomFormat = "shopFilter { shopFilterText { id:t='room_txt_%d'; text:t='' } Button_close { id:t='close_%d'; on_click:t='onRoomClose';}}\n"
    fillList(obj, roomFormat, ::g_chat.rooms.len())

    local curVal = -1
    foreach(idx, room in ::g_chat.rooms)
    {
      updateRoomTabByIdx(idx, room, obj)

      if (room == curRoom)
        curVal = idx
    }

    if (curVal<0 && ::g_chat.rooms.len() > 0)
    {
      curVal = obj.getValue()
      if (curVal < 0 || curVal > ::g_chat.rooms.len())
        curVal = ::g_chat.rooms.len()-1
    }

    if (curVal != obj.getValue())
      obj.setValue(curVal)

    guiScene.setUpdatesEnabled(true, true)

    if (!onRoomChanged())
    {
      checkNewMessages()
      updateRoomsIcons()
    }
  }

  function onRoomChanged()
  {
    if (!checkScene())
      return false

    local obj = scene.findObject("rooms_list")
    local value = obj.getValue()
    local roomData = ::getTblValue(value, ::g_chat.rooms)

    if (!roomData)
    {
      updateUsersList()
      updateChatText()
      updateInputText(roomData)
      scene.findObject("chat_input_place").show(false)
      return false
    }

    if (roomData == curRoom && !sceneChanged)
      return false

    curRoom = roomData
    showSceneBtn("btn_showPlayersList", !alwaysShowPlayersList() && roomData.havePlayersList)
    showSceneBtn("btn_showSearchList", ::g_chat.isThreadsView)
    showSceneBtn("chat_input_place", !roomData.hasCustomViewHandler)
    showSceneBtn("menu_chat_text_block", !roomData.hasCustomViewHandler)

    updateUsersList()
    updateChatText()
    updateInputText(roomData)
    checkNewMessages()
    updateRoomsIcons()

    if (!::g_chat.isThreadsView)
      showSearch(::g_chat.isSystemChatRoom(curRoom.id))

    checkSwitchRoomHandler(roomData)
    updateHeaderBlock(roomData)

    sceneChanged = false

    restoreChatFocus()
    return true
  }

  function onRoomRClick(obj)
  {
    if (curRoom.type == ::g_chat_room_type.PRIVATE)
      ::g_chat.showPlayerRClickMenu(curRoom.id, curRoom.id)
  }

  function checkSwitchRoomHandler(roomData)
  {
    showSceneBtn("menu_chat_custom_handler_block", roomData.hasCustomViewHandler)
    if (!roomData.hasCustomViewHandler)
      return

    if (!roomHandlerWeak)
      return createRoomHandler(roomData)

    if (("roomId" in roomHandlerWeak) && roomHandlerWeak.roomId != roomData.id)
    {
      if ("remove" in roomHandlerWeak)
        roomHandlerWeak.remove()
      createRoomHandler(roomData)
      return
    }

    if ("onSceneShow" in roomHandlerWeak)
      roomHandlerWeak.onSceneShow()
  }

  function createRoomHandler(roomData)
  {
    local obj = scene.findObject("menu_chat_custom_handler_block")
    local roomHandler = roomData.type.loadCustomHandler(obj, roomData.id)
    roomHandlerWeak = roomHandler && roomHandler.weakref()
  }

  function updateHeaderBlock(roomData)
  {
    if (!checkScene())
      return

    local hasChatHeader = roomData.type.hasChatHeader
    local obj = showSceneBtn("menu_chat_header_block", hasChatHeader)
    local isRoomChanged = obj.roomId != roomData.id
    if (!isRoomChanged)
    {
      if (hasChatHeader)
        roomData.type.updateChatHeader(obj, roomData)
      return
    }

    if (!hasChatHeader)
      return //header block is hidden, so no point to remvoe it.

    roomData.type.fillChatHeader(obj, roomData)
    obj.roomId = roomData.id
  }

  function updateInputText(roomData)
  {
    scene.findObject("menuchat_input").setValue(::getTblValue("lastTextInput", roomData, ""))
  }

  function updateRoomTabByIdx(idx, room, listObj = null)
  {
    if (!listObj)
    {
      if (!checkScene())
        return
      listObj = scene.findObject("rooms_list")
    }

    local roomTab = listObj.getChild(idx)
    if (!::checkObj(roomTab))
      return

    roomTab.canClose = room.canBeClosed? "yes" : "no"
    roomTab.enable(!room.hidden)
    roomTab.show(!room.hidden)
    roomTab.tooltip = room.type.getTooltip(room.id)
    local textObj = roomTab.findObject("room_txt_"+idx)
    textObj.colorTag = room.type.getRoomColorTag(room.id)
    textObj.setValue(room.getRoomName())
  }

  function updateRoomTabById(roomId)
  {
    foreach(idx, room in ::g_chat.rooms)
      if (room.id == roomId)
        updateRoomTabByIdx(idx, room)
  }

  function updateAllRoomTabs()
  {
    if (!checkScene())
      return
    local listObj = scene.findObject("rooms_list")
    foreach(idx, room in ::g_chat.rooms)
      updateRoomTabByIdx(idx, room, listObj)
  }

  function onEventChatThreadInfoChanged(p)
  {
    updateRoomTabById(::getTblValue("roomId", p))
  }

  function onEventChatFilterChanged(p)
  {
    updateAllRoomTabs()
  }

  function onEventContactsGroupUpdate(p)
  {
    updateAllRoomTabs()
  }

  function onEventSquadStatusChanged(p)
  {
    updateAllRoomTabs()
  }

  function alwaysShowPlayersList()
  {
    return ::show_console_buttons
  }

  function getRoomIdxById(id)
  {
    foreach(idx, item in ::g_chat.rooms)
      if (item.id == id)
        return idx
    return -1
  }

  function updateRoomsIcons()
  {
    if (!checkScene() || !::last_chat_scene_show)
      return

    local roomsObj = scene.findObject("rooms_list")
    if (!roomsObj)
      return

    local total = roomsObj.childrenCount()
    if (total > ::g_chat.rooms.len())
      total = ::g_chat.rooms.len() //Maybe assert here?
    for(local i=0; i<total; i++)
    {
      local childObj = roomsObj.getChild(i)
      local obj = childObj.findObject("new_msgs")
      local haveNew = ::g_chat.rooms[i].newImportantMessagesCount > 0
      if (::checkObj(obj) != haveNew)
        if (haveNew)
        {
          local data = "cornerImg { id:t='new_msgs'; background-image:t='#ui/gameuiskin#chat_new' }"
          guiScene.appendWithBlk(childObj, data, this)
        } else
          guiScene.destroyElement(obj)

    }
  }

  function updateUsersList()
  {
    if (!checkScene())
      return

    guiScene.setUpdatesEnabled(false, false)
    local listObj = scene.findObject("users_list")
    local leftObj = scene.findObject("middleLine")
    if (!curRoom || !curRoom.havePlayersList || (!showPlayersList && !alwaysShowPlayersList()))
    {
      leftObj.show(false)
      //guiScene.replaceContentFromText(listObj, "", 0, this)
    }
    else
    {
      leftObj.show(true)
      local users = curRoom.users
      if (users==null)
        guiScene.replaceContentFromText(listObj, "", 0, this)
      else
      {
        local userFormat = "text { id:t='user_name_%d'; behaviour:t='button'; " +
                             "on_click:t='onUserListClick'; on_r_click:t='onUserListRClick'; " +
                             "tooltipObj { id:t='tooltip'; uid:t=''; on_tooltip_open:t='onContactTooltipOpen'; on_tooltip_close:t='onTooltipObjClose'; display:t='hide' }\n " +
                             "title:t='$tooltipObj';\n" +
                           "}\n"
        fillList(listObj, userFormat, users.len())
        foreach(idx, user in users)
        {
          local fullName = ""
          if((user.name in ::clanUserTable) && ::clanUserTable[user.name]!="")
            fullName = ::clanUserTable[user.name] + " "
          fullName += user.name
          listObj.findObject("user_name_"+idx).setValue(fullName)
        }
      }
    }
    if (curRoom)
      foreach(idx, user in curRoom.users)
      {
        if (user.uid == null && (::g_squad_manager.isInMySquad(user.name, false) || ::is_in_my_clan(user.name)))
          user.uid = ::getPlayerUid(user.name)

        local contact = (user.uid != null)? ::getContact(user.uid) : null
        updateUserPresence(listObj, idx, contact)
      }

    updateReadyButton()
    updateSquadInfo()
    guiScene.setUpdatesEnabled(true, true)
  }

  function updateReadyButton()
  {
    if (!checkScene() || !showPlayersList || !curRoom)
      return

    local readyShow = curRoom.id == ::g_chat.getMySquadRoomId() && ::g_squad_manager.canSwitchReadyness()
    local readyObj = scene.findObject("btn_ready")
    showSceneBtn("btn_ready", readyShow)
    if (readyShow)
      readyObj.setValue(::g_squad_manager.isMeReady() ? ::loc("multiplayer/btnNotReady") : ::loc("mainmenu/btnReady"))
  }

  function updateSquadInfo()
  {
    if (!checkScene() || !curRoom)
      return
    local squadRankTextObj = showSceneBtn("squad_rank_text", curRoom.id == ::g_chat.getMySquadRoomId())
    if (!::checkObj(squadRankTextObj))
      return

    local sRank = ::g_squad_manager.getSquadRank()
    squadRankTextObj.setValue((sRank >= 0)? format(::loc("squad/rank"), sRank) : "")
  }

  function onEventSquadDataUpdated(params)
  {
    updateSquadInfo()
  }

  function updateUserPresence(listObj, idx, contact)
  {
    local obj = listObj.findObject("user_name_" + idx)
    if (obj)
    {
      local inMySquad = contact && ::g_squad_manager.isInMySquad(contact.name, false)
      local inMyClan = contact && ::is_in_my_clan(contact.name)
      local img = inMySquad ? contact.presence.getIcon() : ""
      local img2 = ""
      local voiceIcon = ""
      if (inMySquad)
      {
        local memberData = ::g_squad_manager.getMemberData(contact.uid)
        if (memberData && checkCountry(memberData.country, "squad member data ( uid = " + contact.uid + ")", true))
          img2 = ::get_country_icon(memberData.country)
      }
      obj.findObject("tooltip").uid = (inMySquad && contact)? contact.uid : ""
      if (inMySquad || inMyClan)
        if(contact.voiceStatus in ::voiceChatIcons)
          voiceIcon = "#ui/gameuiskin#" + ::voiceChatIcons[contact.voiceStatus]

      setIcon(obj, "statusImg", "img", img)
      setIcon(obj, "statusImg2", "img2", img2)
      setIcon(obj, "statusVoiceIcon", "voiceIcon", voiceIcon)
      local imgCount = (inMySquad? 2 : 0) + (voiceIcon != ""? 1 : 0)
      obj.imgType = imgCount==0? "none" : (imgCount.tostring()+"ico")
    }
  }

  function setIcon(obj, id, blockName, image)
  {
    if(!checkObj(obj))
      return

    local picObj = obj.findObject(id)
    if(picObj)
      picObj["background-image"] = image
    else
    {
      local string = "%s { id:t='%s'; background-image:t='%s'}"
      local data = format(string, blockName, id, image)
      guiScene.prependWithBlk(obj, data, this)
    }
  }

  function updatePresenceContact(contact)
  {
    if (!checkScene() || !::last_chat_scene_show)
      return

    if (!curRoom) return

    foreach(idx, user in curRoom.users)
      if (user.name == contact.name)
      {
        user.uid = contact.uid
        local listObj = scene.findObject("users_list")
        updateUserPresence(listObj, idx, contact)
        if (curRoom.id == ::g_chat.getMySquadRoomId())
          updateSquadInfo()
        return
      }
  }

  function updateChatText()
  {
    updateCustomChatTexts()
    if (!checkScene())
      return

    local text = ""
    if (curRoom)
    {
      if (curRoom.hasCustomViewHandler)
        return
      text = curRoom.chatText
    } else
      if (!::gchat_is_connected())
      {
        if (::gchat_is_connecting() || ::g_chat.rooms.len()==0)
          text = ::loc("chat/connecting")
        else
          text = ::loc("chat/disconnected")
        text = format("<color=%s>%s</color>", systemColor, text)
        if (::empty_chat_text!="")
          text = ::empty_chat_text + "\n" + text
      }

    if (text != curChatText || sceneChanged)
    {
      curChatText = text
      local textObj = scene.findObject("menu_chat_text")
      if (::checkObj(textObj))
        textObj.setValue(curChatText)
    }
  }

  function chatSceneShow(show=null)
  {
    if (!checkScene())
      return

    if (show==null)
      show = !scene.isVisible()
    if (!show)
    {
      getSizes()
      broadcastEvent("OutsideObjWrap", { obj = getCurFocusObj(), dir = -1 })
    }
    scene.show(show)
    scene.enable(show)
    ::last_chat_scene_show = show
    if (show)
    {
      setSavedSizes()
      rejoinDefaultRooms(true)
      checkNewMessages()
      updateRoomsList()

      guiScene.performDelayed(this, function()
      {
        restoreChatFocus()
      })
    }

    updateControlsAllowMaskDelayed()
  }

  function restoreChatFocus()
  {
    local focusObj = getCurFocusObj()
    if (focusObj) focusObj.select()
  }

  function validateRoomName(roomName)
  {
    foreach(r in ::default_chat_rooms) //validate incorrect created default chat rooms by cur lang
      if (roomName == "#" + r + "_" + ::cur_chat_lang)
      {
        local rList = ::getGlobalRoomsListByLang(::cur_chat_lang, [r])
        return rList.len()? "#" + rList[0] : roomName
      }

    local idx = roomName.find(" ")
    local clearedName = idx ? roomName.slice(0, idx) : roomName
    if (clearedName.len())
      clearedName = clearedName.slice(1)
    clearedName = ::g_chat.validateRoomName(clearedName)
    return "#" + clearedName + (idx? roomName.slice(idx) : "")
  }

  function rejoinDefaultRooms(initRooms = false)
  {
    if (!::gchat_is_connected())
      return
    if (roomsInited && !initRooms)
      return

    local baseRoomsList = ::g_chat.getBaseRoomsList()
    foreach(idx, roomId in baseRoomsList)
      if (!::g_chat.getRoomById(roomId))
        addRoom(roomId, null, null, idx == 0)

    if (::ps4_is_chat_enabled())
    {
      local cdb = ::get_local_custom_settings_blk()
      local roomIdx = 0
      if (cdb.chatRooms!=null)
        for(roomIdx = 0; cdb.chatRooms["room"+roomIdx]; roomIdx++)
        {
          local roomName = validateRoomName(cdb.chatRooms["room"+roomIdx])
          local roomType = ::g_chat_room_type.getRoomType(roomName)
          if (!roomType.needSave()) //"needSave" has changed
            continue

          ::gchat_raw_command("join " + roomName)
          addChatJoinParams(roomName)
        }

      if (roomIdx==0 && !roomsInited && !::g_chat.isThreadsView)
      {
        local roomsList = ::getGlobalRoomsListByLang(::cur_chat_lang, ::default_chat_rooms)
        foreach(room in roomsList)
          joinRoom("#" + room)
      }
    }
    roomsInited = true
  }

  function saveJoinedRooms()
  {
    if (!roomsInited)
      return

    local saveIdx = 0
    local cdb = ::get_local_custom_settings_blk()
    cdb.chatRooms = ::DataBlock()
    foreach(room in ::g_chat.rooms)
      if (!room.hidden && room.type.needSave())
      {
        if (room.joinParams != "")
          cdb.chatRooms["room" + saveIdx] = room.id + " " + room.joinParams
        else
          cdb.chatRooms["room" + saveIdx] = room.id
        saveIdx++
      }
    ::save_profile_offline_limited()
  }

  function goBack()
  {
    chatSceneShow(false)
  }

  function getSizes()
  {
    if (::last_chat_scene_show && checkScene())
    {
      ::menu_chat_sizes = {}
      local obj = scene.findObject("menuchat")
      ::menu_chat_sizes.pos <- obj.getPosRC()
      ::menu_chat_sizes.size <- obj.getSize()
      obj = scene.findObject("middleLine")
      ::menu_chat_sizes.usersSize <- obj.getSize()
      obj = scene.findObject("searchDiv")
      if (obj.isVisible())
        ::menu_chat_sizes.searchSize <- obj.getSize()

      saveLocalByScreenSize("menu_chat_sizes", save_to_json(::menu_chat_sizes))
    }
  }

  function onRoomCreator()
  {
    ::g_chat.openRoomCreationWnd()
  }

  function setSavedSizes()
  {
    if (!::menu_chat_sizes)
    {
      local data = loadLocalByScreenSize("menu_chat_sizes")
      if (data)
      {
        ::menu_chat_sizes = ::parse_json(data)
        if (!("pos" in ::menu_chat_sizes) || !("size" in ::menu_chat_sizes) || !("usersSize" in ::menu_chat_sizes))
          ::menu_chat_sizes = null
        else
          ::menu_chat_sizes.pos[0] = ::menu_chat_sizes.pos[0].tointeger()
          ::menu_chat_sizes.pos[1] = ::menu_chat_sizes.pos[1].tointeger()
          ::menu_chat_sizes.size[0] = ::menu_chat_sizes.size[0].tointeger()
          ::menu_chat_sizes.size[1] = ::menu_chat_sizes.size[1].tointeger()
          ::menu_chat_sizes.usersSize[0] = ::menu_chat_sizes.usersSize[0].tointeger()
          ::menu_chat_sizes.usersSize[1] = ::menu_chat_sizes.usersSize[1].tointeger()
      }
    }

    if (!::last_chat_scene_show || !::menu_chat_sizes || !checkScene())
      return

    local obj = scene.findObject("menuchat")
    if (!obj) return

    local pos = ::getTblValue("pos", ::menu_chat_sizes)
    local size = ::getTblValue("size", ::menu_chat_sizes)
    if (!pos || !size)
      return

    local rootSize = guiScene.getRoot().getSize()
    for(local i=0; i<=1; i++) //pos chat in screen
      if (pos[i] < ::top_menu_borders[i][0]*rootSize[i])
        pos[i] = (::top_menu_borders[i][0]*rootSize[i]).tointeger()
      else
        if (pos[i]+size[i] > ::top_menu_borders[i][1]*rootSize[i])
          pos[i] = (::top_menu_borders[i][1]*rootSize[i] - size[i]).tointeger()

    obj.pos = pos[0] + ", " + pos[1]
    obj.size = size[0] + ", " + size[1]

    if ("usersSize" in ::menu_chat_sizes)
    {
      obj = scene.findObject("middleLine")
      obj.size = ::menu_chat_sizes.usersSize[0] + ", ph" // + ::menu_chat_sizes.usersSize[1]
    }

    if ("searchSize" in ::menu_chat_sizes)
    {
      obj = scene.findObject("searchDiv")
      if (obj.isVisible() && ("searchSize" in ::menu_chat_sizes))
        obj.size = ::menu_chat_sizes.searchSize[0] + ", ph"
    }
  }

  function onPresenceDetectionCheckIn( code )
  {
    if ( (code >= 0) && (code < ::get_pds_code_limit()) )
    {
      local taskId = ::send_pds_presence_check_in( code )
//      if (taskId >= 0)
//      {
//        ::set_char_cb(this, slotOpCb)
//        showTaskProgressBox(::loc("charServer/send"))
//        afterSlotOp = goBack
//      }
    }
  }

  function onPresenceDetectionTick()
  {
    if ( !::gchat_is_connected() )
      return

    if ( !::is_myself_anyof_moderators() )
      return

    if ( presenceDetectionTimer <= 0 )
    {
      presenceDetectionTimer = get_pds_next_time()
    }

    if ( get_charserver_time_sec() > presenceDetectionTimer )
    {
      presenceDetectionTimer = 0
      local msg = format( ::loc("chat/presenceCheck"), ::get_pds_code_suggestion().tostring() )

      addRoomMsg("", "", msg, false, false, systemColor)
    }
  }

  //once per 1 sec
  function onUpdate(obj, dt)
  {
    if (!::last_chat_scene_show)
      return

    getSizes()
    onPresenceDetectionTick()
  }

  function onEventCb(event, taskId, db)
  {
//    if (event == ::GCHAT_EVENT_TASK_RESPONSE || event == ::GCHAT_EVENT_TASK_ERROR)
    foreach(idx, t in chatTasks)
      if (t.task==taskId)
      {
        t.handler.call(this, event, db, t)
        chatTasks.remove(idx)
      }
    if (event == ::GCHAT_EVENT_MESSAGE)
    {
      if(::ps4_is_chat_enabled())
        onMessage(db)
    }
    else if (event == ::GCHAT_EVENT_CONNECTED)
    {
      if (roomsInited)
      {
        local msg = ::loc("chat/connected")
        showRoomPopup(null, msg, ::g_chat.getSystemRoomId())
      }
      rejoinDefaultRooms()
      if (g_chat.rooms.len() > 0)
      {
        local msg = ::loc("chat/connected")
        addRoomMsg("", "", msg)
      }

      foreach (room in ::g_chat.rooms)
      {
        if (room.id.slice(0, 1) != "#" || ::g_chat.isSystemChatRoom(room.id))
          continue

        local cb = (!::checkObj(room.customScene))? null : (@(room) function() { afterReconnectCustomRoom(room.id) })(room)
        joinRoom(room.id, "", cb, null, null, true)
      }
      ::checkSquadInvitesFromPS4Friends(false)
      updateRoomsList()
      ::broadcastEvent("ChatConnected")
    } else if (event == ::GCHAT_EVENT_DISCONNECTED)
      addRoomMsg("", "", ::loc("chat/disconnected"))
    else if (event == ::GCHAT_EVENT_CONNECTION_FAILURE)
      addRoomMsg("", "", ::loc("chat/connectionFail"))
    else if (event == ::GCHAT_EVENT_TASK_RESPONSE)
      onEventTaskResponse(taskId, db)
    else if (event == ::GCHAT_EVENT_VOICE)
    {
      if(db.uid)
      {
        local contact = ::getContact(db.uid)
        local voiceChatStatus = null
        if(db.type == "join")
        {
          voiceChatStatus = voiceChatStats.online
        }
        if(db.type == "part")
        {
          voiceChatStatus = voiceChatStats.offline
        }
        if(db.type == "update")
        {
          if(db.is_speaking)
            voiceChatStatus = voiceChatStats.talking
          else
            voiceChatStatus = voiceChatStats.online
        }

        if(!contact)
          ::collectMissedContactData(db.uid, "voiceStatus", voiceChatStatus)
        else
        {
          contact.voiceStatus = voiceChatStatus
          if (checkScene())
            ::chatUpdatePresence(contact)
          ::updateVoicechatDisplay(contact)
        }

        ::broadcastEvent("VoiceChatStatusUpdated", {
                                                    uid = db.uid,
                                                    voiceChatStatus = voiceChatStatus
                                                   })
      }
    }
    /* //!! For debug only!!
    //dlog("GP: New event: " + event + ", " + taskId)
    local msg = "New event: " + event + ", " + taskId
    if (db)
    {
      foreach(name, param in db)
        if (typeof(param) != "instance")
          msg += "\n" + name + " = " + param
        else
        if (name=="list")
        {
          msg+="list = ["
          foreach(idx, val in param % "item")
            msg += ((idx!=0)? ", " : "") + val
          msg+="]\n"
        }
        else
        {
          msg += "\n" + name + " {"
          foreach(n, p in param)
            msg += "\n  " + n + " = " + p
          msg+="\n}"
        }
    }
    addRoomMsg(curRoom.id, "", msg)
    */ //debug end
  }

  function createRoomUserInfo(name, uid = null)
  {
    return {
      name = name
      uid = uid
      isOwner = false
    }
  }

  function onEventTaskResponse(taskId, db)
  {
    if (!checkEventResponseByType(db))
      checkEventResponseByTaskId(taskId, db)
  }

  function checkEventResponseByType(db)
  {
    local dbType = db && db.type
    if (!dbType)
      return false

    if (dbType=="rooms")
    {
      searchInProgress = false
      if (db.list)
        searchRoomList = db.list % "item"
      validateSearchList()
      defaultRoomsInSearch = false
      searchInited = false
      fillSearchList()
    }
    else if (dbType=="names")
    {
      if (!db.list || !db.channel)
        return true

      local roomData = ::g_chat.getRoomById(db.channel)
      if (roomData)
      {
        local uList = db.list % "item"
        roomData.users = []
        foreach(idx, u in uList)
          if (::find_in_array(uList, u)==idx) //check duplicates
          {
            local utbl = createRoomUserInfo(u)
            local first = utbl.name.slice(0,1)
            if (first == "@" || first == "+")
            {
              utbl.name = utbl.name.slice(1,utbl.name.len())
              utbl.isOwner = true
            }
            roomData.users.append(utbl)
          }
        roomData.users.sort(::sortChatUsers)
        updateUsersList()
      }
      if (::g_chat.isRoomClan(db.channel))
        ::broadcastEvent("ClanRoomMembersChanged");
    }
    else if (dbType=="user_leave")
    {
      if(!db.channel || !db.nick)
        return true
      if (db.channel=="")
        foreach(roomData in ::g_chat.rooms)
        {
          removeUserFromRoom(roomData, db.nick)
          if (::g_chat.isRoomClan(roomData.id))
            ::broadcastEvent(
              "ClanRoomMembersChanged",
              {nick = db.nick, presence = ::g_contact_presence.OFFLINE }
            )
        }
      else
      {
        removeUserFromRoom(::g_chat.getRoomById(db.channel), db.nick)
        if (::g_chat.isRoomClan(db.channel))
          ::broadcastEvent(
            "ClanRoomMembersChanged",
            {nick = db.nick, presence = ::g_contact_presence.OFFLINE }
          )
      }
    }
    else if (dbType=="user_join")
    {
      if(!db.channel || !db.nick)
        return true
      local roomData = ::g_chat.getRoomById(db.channel)
      if (roomData)
      {
        local found = false
        foreach(u in roomData.users)
          if (u.name == db.nick)
          {
            found = true
            break
          }
        if (!found)
        {
          roomData.users.append(createRoomUserInfo(db.nick))
          roomData.users.sort(::sortChatUsers)
          if (::g_chat.isRoomSquad(roomData.id))
            onSquadListMember(db.nick, true)

          updateUsersList()
        }
        if (::g_chat.isRoomClan(db.channel))
          ::broadcastEvent(
            "ClanRoomMembersChanged",
            {nick = db.nick, presence = ::g_contact_presence.ONLINE }
          )
      }
    }
    else if (dbType=="invitation")
    {
      if (!db.channel || !db.from)
        return true

      local fromNick = db.from
      local roomId = db.channel
      ::g_invites.addChatRoomInvite(roomId, fromNick)
    }
    else if (db.type == "thread_list" || db.type == "thread_update")
      ::g_chat.updateThreadInfo(db)
    else if (db.type == "progress_caps")
      ::g_chat.updateProgressCaps(db)
    else if ( db.type == "thread_list_end" )
      ::g_chat_latest_threads.onThreadsListEnd()
    else
      return false
    return true
  }

  function checkEventResponseByTaskId(taskId, db)
  {
    if (::g_string.startsWith(taskId, "join_#"))
    {
      local roomId = taskId.slice(5)
      if (::g_chat.isSystemChatRoom(roomId))
        return

      local room = ::g_chat.getRoomById(roomId)
      if (!room)
        room = addRoom(roomId)
      else
      {
        room.joined = true
        if (room.customScene)
          afterReconnectCustomRoom(roomId)
      }
      if (changeRoomOnJoin == roomId)
        switchCurRoom(room, false)
      updateRoomsList()
      ::broadcastEvent("ChatRoomJoin", { room = room })
    }
    else if (::g_string.startsWith(taskId, "leave_#"))
    {
      local roomId = taskId.slice(6) //auto reconnect to this channel by server
      if (::g_chat.isSystemChatRoom(roomId))
        return
      local room = ::g_chat.getRoomById(roomId)
      if (room)
      {
        room.joined = false
        room.users = []
        local isSquad = ::g_chat.isRoomSquad(room.id)
        local msgId = isSquad ? "squad/leaveChannel" : "chat/leaveChannel"
        if (isSquad)
        {
          ::updateVoicechatDisplay(null)
          room.canBeClosed = true
          updateRoomTabById(room.id)
        }
        addRoomMsg(room.id, "", format(::loc(msgId), room.getRoomName()))
        sceneChanged = true
        onRoomChanged()
        ::broadcastEvent("ChatRoomLeave", { room = room })
      }
    }
  }

  function removeUserFromRoom(roomData, nick)
  {
    if(!("users" in roomData))
      return
    foreach(idx, u in roomData.users)
      if (u.name == nick)
      {
        if (::g_chat.isRoomSquad(roomData.id))
          onSquadListMember(nick, false)
        else if("isOwner" in u && u.isOwner == true)
          ::gchat_list_names(roomData.id)
        roomData.users.remove(idx)
        if (curRoom == roomData)
          updateUsersList()
        break
      }
  }

  function filterSystemUserMsg(msg)
  {
    msg = ::g_chat.filterMessageText(msg, false)
    local localized = false
    foreach(ending in ["is set READONLY", "is set BANNED"])
    {
      if (!::g_string.endsWith(msg, ending))
        continue

      localized = true
      local locText = ::loc(ending, "")
      local playerName = ::g_string.slice(msg, 0, -ending.len() - 1)
      if (locText != "")
        msg = ::format(locText, playerName)
      if (playerName == ::my_user_name)
        ::sync_handler_simulate_signal("profile_reload")
      break
    }
    if (!localized)
      msg = ::loc(msg)
    return msg
  }

  function addRoomMsg(roomId, messageAuthor, msg, privateMsg = false, myPrivate = false, overlaySystemColor = null, important=false)
  {//messageAuthor can be as string - Player nick, and as table - player contact.
   //after getting type, and acting accordingly, name must be string and mean name of player
    local text = ""
    local clanTag = ""
    local myself = false
    local fullName = ""
    local userColor = ""
    local uid = null

    if(typeof(messageAuthor) != "instance")
    {
      if(messageAuthor in ::clanUserTable && ::clanUserTable[messageAuthor] != "" && !::g_chat.isRoomClan(roomId))
          clanTag = ::clanUserTable[messageAuthor]
    }
    else
    {
      uid = messageAuthor.uid
      clanTag = messageAuthor.clanTag
      messageAuthor = messageAuthor.name
    }
    if(::g_chat.isSystemUserName(messageAuthor))
    {
      messageAuthor = ""
      msg = filterSystemUserMsg(msg)
    }
    myself = messageAuthor == ::my_user_name

    local fullName = (clanTag!=""? (clanTag + " "): "") + messageAuthor

    if (messageAuthor=="")
      text = format("<color=%s>%s</color>", overlaySystemColor? overlaySystemColor : systemColor, msg)
    else
    {
      local userColor = ::g_chat.getSenderColor(messageAuthor, true, privateMsg)
      if (!::g_chat.isRoomSquad(roomId))
        msg = ::g_chat.filterMessageText(msg, myself || myPrivate)

      local msgColor = privateMsg? privateColor : ""
      if (overlaySystemColor)
      {
        msgColor = overlaySystemColor
      }
      else if (!myPrivate && ::isPlayerNickInContacts(messageAuthor, ::EPL_BLOCKLIST))
      {
        if (privateMsg) return
        userColor = blockedColor
        msgColor = blockedColor
        msg = ::g_chat.makeBlockedMsg(msg)
      } else
        msg = colorMyNameInText(msg)

      if (msgColor!="")
        msg = "<Color="+msgColor+">" + msg + "</Color>"

      local from = myPrivate? format(::loc("chat/myPrivateMsgToPlayer"), fullName) : fullName
      text = format("<Link=%s><Color=%s>%s</Color>:</Link> %s",
                      ::g_chat.generatePlayerLink(messageAuthor, uid), userColor, from, msg)
    }

    if (privateMsg && roomId=="" && !::last_chat_scene_show)
      newMessagesGC()

    foreach(roomData in ::g_chat.rooms)
    {
      if ((roomId=="") || roomData.id == roomId)
      {
        roomData.chatText += ((roomData.chatText=="")? "":"\n") + text

        if (messageAuthor!="")
          if (roomData.msgCount < ::g_chat.getMaxRoomMsgAmount())
            roomData.msgCount++
          else
          {
            local start = roomData.chatText.find("<Link=PL")
            if (start!=null)
              start = roomData.chatText.find("<Link=PL", start+1)
            if (start!=null)
              roomData.chatText = roomData.chatText.slice(start)
          }


        if (roomData == curRoom || roomData.hidden)
        {
          updateChatText()
        }

        if ((roomId!="" && (!::last_chat_scene_show || roomData != curRoom)) &&
           ((privateMsg && !myPrivate) || important))
        {
          roomData.newImportantMessagesCount++
          updateRoomsIcons()
          newMessagesGC()
          if (!myself)
            showRoomPopup(fullName, msg, roomData.id)
        }
        else if (roomId=="" && important
                 && (!::last_chat_scene_show || curRoom.type != ::g_chat_room_type.SYSTEM)
                 && ::g_chat.isSystemChatRoom(roomData.id))
        {
          roomData.newImportantMessagesCount++
          updateRoomsIcons()
          newMessagesGC()
        }
      }
    }

    if (::g_chat.rooms.len() == 0)
    {
      if (important)
      {
        ::delayed_chat_messages += ((::delayed_chat_messages=="")? "":"\n") + text
        newMessagesGC()
      }
      else if (roomId=="")
      {
        ::empty_chat_text += ((::empty_chat_text!="")? "\n" : "") + text
        updateChatText()
      }
    }
  }

  function colorMyNameInText(msg)
  {
    if (::my_user_name=="" || msg.len() < ::my_user_name.len())
      return msg

    local counter = 0;
    msg = " "+msg+" "; //add temp spaces before name coloring

    while (counter+::my_user_name.len() <= msg.len())
    {
      local nameStartPos = msg.find(::my_user_name, counter);
      if (nameStartPos == null)
        break;

      local nameEndPos = nameStartPos + ::my_user_name.len();
      counter = nameEndPos;

      if (::isInArray(msg.slice(nameStartPos-1, nameStartPos), ::punctuation_list) &&
          ::isInArray(msg.slice(nameEndPos, nameEndPos+1),     ::punctuation_list))
      {
        local msgStart = msg.slice(0, nameStartPos);
        local msgEnd = msg.slice(nameEndPos);
        local msgName = msg.slice(nameStartPos, nameEndPos);
        local msgProcessedPart = msgStart + ::colorize(::g_chat.color.senderMe[false], msgName)
        msg = msgProcessedPart + msgEnd;
        counter = msgProcessedPart.len();
      }
    }
    msg = msg.slice(1, msg.len()-1); //remove temp spaces after name coloring

    return msg
  }

  function newMessagesGC()
  {
    ::update_gamercards()
  }

  function checkNewMessages()
  {
    if (::delayed_chat_messages != "")
      return

    if (!::last_chat_scene_show || !curRoom)
      return

    curRoom.newImportantMessagesCount = 0

    ::update_gamercards()
  }

  function checkLastActionRoom()
  {
    if (lastActionRoom=="" || !::g_chat.getRoomById(lastActionRoom))
      lastActionRoom = ::getTblValue("id", curRoom, "")
  }

  function onMessage(db)
  {
    if (!db || !db.from)
      return

    if (skipMyMessages && db.sender && db.sender.nick == ::my_user_name)
      return

    if (db.type == "xpost")
    {
      local roomId = db.sender.name
      if (db.message.len() > 0)
        foreach (room in ::g_chat.rooms)
          if (room.id == roomId)
          {
            local idxLast = db.message.find(">")
            if ((db.message.slice(0,1)=="<") && (idxLast != null))
            {
              local src = db.message.slice(1, idxLast)
              local text = db.message.slice(idxLast+1)
              addRoomMsg(roomId, src, ::g_chat.clampMsg(text), false, false, mpostColor)
            }
            else
              addRoomMsg(roomId, "", ::g_chat.clampMsg(db.message), false, false, xpostColor)
          }
    }
    else if (db.type == "groupchat" || db.type == "chat")
    {
      //local from = db.from
      local roomId = ""
      local user = ""
      local userContact = null
      local clanTag = ""
      local privateMsg = false
      local myPrivate = false
      local important = false

      if (!db.sender || db.sender.debug)
        return

      local message = ::g_chat.localizeReceivedMessage(db.message)
      if (::u.isEmpty(message))
        return

      if (!db.sender.service)
      {
        clanTag = db.tag? db.tag : ""
        user = db.sender.nick
        if(db.userId && db.userId != "0")
          userContact = getContact(db.userId, db.sender.nick, clanTag, true)
        else if (db.sender.nick!=::my_user_name)
          ::clanUserTable[db.sender.nick] <- clanTag
        roomId = db.sender.name
        privateMsg = (db.type == "chat") || !roomRegexp.match(roomId)
        if (privateMsg)  //private message
        {
          if(::isUserBlockedByPrivateSetting(db.userId))
            return

          if (db.type == "chat")
            roomId = db.sender.nick
          myPrivate = db.sender.nick == ::my_user_name
          if ( myPrivate )
          {
            user = db.sender.name
            userContact = null
          }

          local haveRoom = false;
          foreach (room in ::g_chat.rooms)
            if (room.id == roomId)
            {
              haveRoom = true;
              break;
            }
          if (!haveRoom)
          {
            if (::isPlayerNickInContacts(user, ::EPL_BLOCKLIST))
              return
            addRoom(roomId)
            updateRoomsList()
          }
        }
        if (::g_chat.isRoomSquad(roomId))
        {
          important = true
        }

        // System message
        if (::g_chat.isSystemUserName(user))
        {
          local nameLen = ::my_user_name.len()
          if (message.len() >= nameLen && message.slice(0, nameLen) == ::my_user_name)
            ::sync_handler_simulate_signal("profile_reload")
        }
      }
      addRoomMsg(roomId, userContact || user, ::g_chat.clampMsg(message),
                 privateMsg, myPrivate, null, important)
    }
    else if (db.type == "error")
    {
      if (!db.error)
        return

      checkLastActionRoom()
      local errorName = db.error.errorName
      local roomId = lastActionRoom
      local senderFrom = db.sender && db.sender.from
      if (db.error.param1)
        roomId = db.error.param1
      else if (senderFrom && roomRegexp.match(senderFrom))
        roomId = senderFrom

      if (errorName == chatErrorName.NO_SUCH_NICK_CHANNEL)
      {
        local userName = roomId
        if (!roomRegexp.match(userName)) //private room
        {
          addRoomMsg(lastActionRoom, "", format(::loc("chat/error/401/userNotConnected"), userName))
          return
        }
      }
      else if (errorName == chatErrorName.CANNOT_JOIN_THE_CHANNEL && roomId.len() > 1)
      {
        local wasPasswordEntered = ::getTblValue(roomId, roomJoinParamsTable, "") != ""
        local locId = wasPasswordEntered ? "chat/wrongPassword" : "chat/enterPassword"
        local params = {
          title = roomId.slice(1)
          editboxHeaderText = ::format(::loc(locId), roomId.slice(1))
          allowEmpty = false
          okFunc = ::Callback(@(pass) joinRoom(roomId, pass), ::menu_chat_handler)
        }

        ::gui_modal_editbox_wnd(params)
        return
      }
      if (::isInArray(errorName, [chatErrorName.NO_SUCH_CHANNEL, chatErrorName.NO_SUCH_NICK_CHANNEL]))
      {
        if (roomId == ::g_chat.getMySquadRoomId())
        {
          leaveSquadRoom()
          return
        }
        if (::g_chat_room_type.getRoomType(roomId) == ::g_chat_room_type.THREAD)
        {
          local threadInfo = ::g_chat.getThreadInfo(roomId)
          if (threadInfo)
            threadInfo.invalidate()
        }
      }

      //remap roomnames in params
      local locParams = {}
      local errParamCount = db.error.errorParamCount || db.error.getInt("paramCount", 0) //"paramCount" is a support old client
      for(local i = 0; i < errParamCount; i++)
      {
        local key = "param" + i
        local value = db.error[key]
        if (!value)
          continue

        if (roomRegexp.match(value))
        {
          local roomType = ::g_chat_room_type.getRoomType(value)
          value = roomType.getRoomName(value)
        }
        locParams[key] <- value
      }

      local roomType = ::g_chat_room_type.getRoomType(roomId)
      local errMsg = ::loc("chat/error/" + errorName, locParams)
      local roomToSend = roomId
      if (!::g_chat.getRoomById(roomToSend))
        roomToSend = lastActionRoom
      addRoomMsg(roomToSend, "", errMsg)
      if (roomId != roomToSend)
        addRoomMsg(roomId, "", errMsg)
      if (roomType.isErrorPopupAllowed)
        showRoomPopup(null, errMsg, roomId)
    }
    else
      dagor.debug("Chat error: Received message of unknown type = " + db.type)
  }

  function joinRoom(id, password = "", onJoinFunc = null, customScene = null, ownerHandler = null, reconnect = false)
  {
    local roomData = ::g_chat.getRoomById(id)
    if (roomData && id == ::g_chat.getMySquadRoomId())
      roomData.canBeClosed = false

    if (roomData && roomData.joinParams != "")
      return ::gchat_raw_command("join " + id + " " + roomData.joinParams)

    if (roomData && reconnect && roomData.joined) //reconnect only to joined rooms
      return

    addChatJoinParams(id + (password == "" ? "" : " " + password))
    if (customScene && !roomData)
      addRoom(id, customScene, ownerHandler) //for correct reconnect

    local task = ::gchat_join_room(id, password) //FIX ME: better to remove this and work via gchat_raw_command always
    if (task != "")
      chatTasks.append({ task = task, handler = onJoinRoom, roomId = id,
                         onJoinFunc = onJoinFunc, customScene = customScene,
                         ownerHandler = ownerHandler
                       })
  }

  function onJoinRoom(event, db, taskConfig)
  {
    if (event != ::GCHAT_EVENT_TASK_ERROR && db && db.type!="error")
    {
      local needNewRoom = true
      foreach(room in ::g_chat.rooms)
        if (taskConfig.roomId == room.id)
        {
          if (!room.joined)
          {
            local msgId = ::g_chat.isRoomSquad(taskConfig.roomId)? "squad/joinChannel" : "chat/joinChannel"
            addRoomMsg(room.id, "", format(::loc(msgId), room.getRoomName()))
          }
          room.joined = true
          needNewRoom = false
        }

      if (needNewRoom)
        addRoom(taskConfig.roomId, taskConfig.customScene, taskConfig.ownerHandler, true)

      if (("onJoinFunc" in taskConfig) && taskConfig.onJoinFunc)
        taskConfig.onJoinFunc.call(this)
    }
  }

  function addRoom(id, customScene = null, ownerHandler = null, selectRoom = false)
  {
    local roomType = ::g_chat_room_type.getRoomType(id)
    local canBeClosed = roomType.canBeClosed(id)

    if (roomType != ::g_chat_room_type.PRIVATE)
      ::play_gui_sound("chat_join")

    local r = {
      id = id
      type = roomType
      getRoomName = @(isColored = false) type.getRoomName(id, isColored)
      canBeClosed = canBeClosed
      havePlayersList = roomType.havePlayersList
      hasCustomViewHandler = roomType.hasCustomViewHandler
      joined = true
      users = []
      chatText = ""
      msgCount = 0
      newImportantMessagesCount = 0
      joinParams = ""
      lastTextInput = ""

      customScene = customScene
      ownerHandler = ownerHandler
      hidden = customScene != null
      existOnlyInCustom = customScene != null
    }
    if (roomJoinParamsTable.rawin(id))
      r.joinParams <- roomJoinParamsTable[id]

    ::g_chat.addRoom(r)

    local showCount = unhiddenRoomsCount()
    if (showCount==1)
    {
      if (::ps4_is_chat_enabled())
        addRoomMsg(id, "", ::loc("menuchat/hello"))
    }
    if (selectRoom || roomType.needSwitchRoomOnJoin)
      switchCurRoom(r, false)

    if (roomType == ::g_chat_room_type.SQUAD && ::ps4_is_chat_enabled())
      addRoomMsg(id, "", ::loc("squad/channelIntro"))

    if (::delayed_chat_messages!="")
    {
      r.chatText += ((r.chatText!="")? "\n" : "") + ::delayed_chat_messages
      ::delayed_chat_messages = ""
      updateChatText()
      checkNewMessages()
    }
    if (!r.hidden)
      saveJoinedRooms()
    if (::gchat_is_voice_enabled() && roomType.canVoiceChat)
    {
      local VCdata = get_option(::USEROPT_VOICE_CHAT)
      local cdb = ::get_local_custom_settings_blk()
      cdb.voiceChatShowCount = cdb.voiceChatShowCount? cdb.voiceChatShowCount : 0
      if(isFirstAskForSession && cdb.voiceChatShowCount < ::g_chat.MAX_MSG_VC_SHOW_TIMES && !VCdata.value)
      {
        msgBox("join_voiceChat", ::loc("msg/enableVoiceChat"),
                [
                  ["yes", function(){::set_option(::USEROPT_VOICE_CHAT, true)}],
                  ["no", function(){} ]
                ], "no",
                { cancel_fn = function(){}})
        cdb.voiceChatShowCount++
        ::save_profile_offline_limited()
      }
      isFirstAskForSession = false
    }
    return r
  }

  function onEventClanInfoUpdate(p)
  {
    local haveChanges = false
    foreach(room in ::g_chat.rooms)
      if (::g_chat.isRoomClan(room.id)
          && (room.canBeClosed != (room.id != ::g_chat.getMyClanRoomId())))
      {
        haveChanges = true
        room.canBeClosed = !room.canBeClosed
      }
    if (haveChanges)
      updateRoomsList()
  }

  function unhiddenRoomsCount()
  {
    local count = 0
    foreach(room in ::g_chat.rooms)
      if (!room.hidden)
        count++
    return count
  }

  function onRoomClose(obj)
  {
    if (!obj) return
    local id = obj.id
    if (id.len() < 7 || id.slice(0, 6) != "close_")
      return

    local value = id.slice(6).tointeger()
    closeRoom(value)
  }

  function onRemoveRoom(obj)
  {
    closeRoom(obj.getValue(), true)
  }

  function closeRoom(roomIdx, askAllRooms = false)
  {
    if (!(roomIdx in ::g_chat.rooms))
      return
    local roomData = ::g_chat.rooms[roomIdx]
    if (!roomData.canBeClosed)
      return

    if (askAllRooms)
    {
      local msg = format(::loc("chat/ask/leaveRoom"), roomData.getRoomName())
      msgBox("leave_squad", msg,
        [
          ["yes", (@(roomIdx) function() { closeRoom(roomIdx) })(roomIdx)],
          ["no", function() {} ]
        ], "yes",
        { cancel_fn = function() {} })
      return
    }

    if (roomData.id.slice(0, 1) == "#" && roomData.joined)
      ::gchat_raw_command("part " + roomData.id)

    ::g_chat.rooms.remove(roomIdx)
    saveJoinedRooms()
    ::broadcastEvent("ChatRoomLeave", { room = roomData })
    guiScene.performDelayed(this, function() {
      updateRoomsList()
    })
  }

  function closeRoomById(id)
  {
    local idx = getRoomIdxById(id)
    if (idx >= 0)
      closeRoom(idx)
  }

  function onUsersListActivate(obj)
  {
    local value = obj.getValue()
    if (value < 0 || value > obj.childrenCount())
      return

    if (!curRoom || curRoom.users.len() <= value || !checkScene())
      return

    ::g_chat.showPlayerRClickMenu(curRoom.users[value].name, curRoom.id, null, obj.getChild(value).getPosRC())
  }

  function onChatCancel(obj)
  {
    if (isCustomRoomActionObj(obj))
    {
      local customRoom = findCustomRoomByObj(obj)
      if (customRoom && customRoom.ownerHandler && ("onCustomChatCancel" in customRoom.ownerHandler))
        customRoom.ownerHandler.onCustomChatCancel.call(customRoom.ownerHandler)
    }
    else
      goBack()
  }

  function onChatEntered(obj)
  {
    chatSendAction(obj, false)
  }

  function checkCmd(msg)
  {
    if (msg.slice(0, 1)=="\\" || msg.slice(0, 1)=="/")
      foreach(cmd in ::available_cmd_list)
        if ((msg.len() > (cmd.len()+2) && msg.slice(1, cmd.len()+2) == (cmd + " "))
            || (msg.len() == (cmd.len()+1) && msg.slice(1, cmd.len()+1) == cmd))
        {
          local hasParam = msg.len() > cmd.len()+2;

          if (cmd == "help" || cmd == "shelp")
            addRoomMsg(curRoom.id, "", ::loc("menuchat/" + cmd))
          else if (cmd == "edit")
            ::g_chat.openModifyThreadWndByRoomId(curRoom.id)
          else if (cmd == "msg")
            return hasParam ? msg.slice(0,1) + msg.slice(cmd.len()+2) : null
          else if (cmd == "p_check")
          {
            if (!hasParam)
            {
              addRoomMsg(curRoom.id, "", ::loc("chat/presenceCheckArg"));
              return null;
            }

            if ( !::is_myself_anyof_moderators() )
            {
              addRoomMsg(curRoom.id, "", ::loc("chat/presenceCheckDenied"));
              return null;
            }

            onPresenceDetectionCheckIn(::to_integer_safe(msg.slice(cmd.len()+2), -1))
            return null;
          }
          else if (cmd == "join" || cmd == "part")
          {
            if (cmd == "join")
            {
              if (!hasParam)
              {
                addRoomMsg(curRoom.id, "", ::loc("chat/error/461"));
                return null;
              }

              local paramStr = msg.slice(cmd.len()+2)
              local roomName = ""
              if (paramStr.slice(0, 1) != "#")
                paramStr = "#" + paramStr
              addChatJoinParams(paramStr)
            }
            if (msg.len() > cmd.len()+2)
              if (msg.slice(cmd.len()+2, cmd.len()+3)!="#")
                ::gchat_raw_command(msg.slice(1, cmd.len()+2) + "#" + msg.slice(cmd.len()+2))
              else
                ::gchat_raw_command(msg.slice(1))
            return null
          }
          else if (cmd == "invite")
          {
            if (curRoom)
            {
              if (curRoom.id == ::g_chat.getMySquadRoomId())
              {
                if (!hasParam)
                {
                  addRoomMsg(curRoom.id, "", ::loc("chat/error/461"));
                  return null;
                }

                inviteToSquadRoom(msg.slice(cmd.len()+2))
              }
              else
                ::gchat_raw_command(msg.slice(1) + " " + curRoom.id)
            } else
              addRoomMsg(curRoom.id, "", ::loc(::g_chat.CHAT_ERROR_NO_CHANNEL))
          }
          else if (cmd == "mode" || cmd == "xpost" || cmd == "mpost")
            gchatRawCmdWithCurRoom(msg, cmd)
          else if (cmd == "squad_invite" || cmd == "sinvite")
          {
            if (!hasParam)
            {
              addRoomMsg(curRoom.id, "", ::loc("chat/error/461"));
              return null;
            }

            inviteToSquadRoom(msg.slice(cmd.len()+2))
          }
          else if (cmd == "squad_remove" || cmd == "sremove" || cmd == "kick")
          {
            if (!hasParam)
            {
              addRoomMsg(curRoom.id, "", ::loc("chat/error/461"));
              return null;
            }

            local playerName = msg.slice(cmd.len()+2)
            if (cmd == "kick")
              kickPlayeFromRoom(playerName)
            else
              ::g_squad_manager.dismissFromSquadByName(playerName)
          }
          else if (cmd == "squad_ready" || cmd == "sready")
            ::g_squad_manager.setReadyFlag()
          else
            ::gchat_raw_command(msg.slice(1))
          return null
        }
    return msg
  }

  function gchatRawCmdWithCurRoom(msg, cmd)
  {
    if (!curRoom)
      addRoomMsg("", "", ::loc(::g_chat.CHAT_ERROR_NO_CHANNEL))
    else
    if (::g_chat.isSystemChatRoom(curRoom.id))
      addRoomMsg(curRoom.id, "", ::loc("chat/cantWriteInSystem"))
    else
    {
      if (msg.len() > cmd.len()+2)
        ::gchat_raw_command(msg.slice(1, cmd.len()+2) + curRoom.id + " " + msg.slice(cmd.len()+2))
      else
        ::gchat_raw_command(msg.slice(1) + " " + curRoom.id)
    }
  }

  function kickPlayeFromRoom(playerName)
  {
    if (!curRoom || ::g_chat.isSystemChatRoom(curRoom.id))
      return addRoomMsg(curRoom || "", "", ::loc(::g_chat.CHAT_ERROR_NO_CHANNEL))
    if (curRoom.id == ::g_chat.getMySquadRoomId())
      return ::g_squad_manager.dismissFromSquadByName(playerName)

    ::gchat_raw_command("kick " + curRoom.id + " " + playerName)
  }

  function squadMsg(msg)
  {
    local sRoom = ::g_chat.getMySquadRoomId()
    addRoomMsg(sRoom, "", msg)
    if (curRoom && curRoom.id != sRoom)
      addRoomMsg(curRoom.id, "", msg)
  }

  function leaveSquadRoom()
  {
    //squad room can be only one joined at once, but at moment we want to leave it cur squad room id can be missed.
    foreach(room in ::g_chat.rooms)
    {
      if (room.type != ::g_chat_room_type.SQUAD || !room.joined)
        continue

      ::gchat_raw_command("part " + room.id)
      room.joined = false //becoase can be disconnected from chat, but this info is still important.
      room.canBeClosed = true
      room.users.clear()
      updateRoomTabById(room.id)

      if(curRoom == room)
        updateUsersList()
    }
  }

  function isInSquadRoom()
  {
    local roomName = ::g_chat.getMySquadRoomId()
    foreach(room in ::g_chat.rooms)
      if (room.id == roomName)
        return room.joined
    return false
  }

  function inviteToSquadRoom(playerName, delayed=false)
  {
    if (!::gchat_is_connected())
      return false

    if (!::has_feature("Squad"))
    {
      addRoomMsg(curRoom.id, "", ::loc("msgbox/notAvailbleYet"))
      return false
    }

    if (!::g_squad_manager.isInSquad())
      return false

    if (!playerName)
      return false

    if (!::g_squad_manager.isSquadLeader())
    {
      addRoomMsg(curRoom.id, "", ::loc("squad/only_leader_can_invite"))
      return false
    }

    if (!isInSquadRoom())
      return false

    if (delayed)
    {
      local dcmd = "xinvite " + playerName + " " + ::g_chat.getMySquadRoomId()
      dagor.debug(dcmd)
      ::gchat_raw_command(dcmd)
    }

    ::gchat_raw_command("invite " + playerName + " " + ::g_chat.getMySquadRoomId())
    return true
  }

  function onSquadListMember(name, join)
  {
    if (!::g_squad_manager.isInSquad())
      return

    addRoomMsg(::g_chat.getMySquadRoomId(), "", format(::loc(join? "squad/player_join" : "squad/player_leave"), name))
  }

  function squadReady()
  {
    if (::g_squad_manager.canSwitchReadyness())
      ::g_squad_manager.setReadyFlag()
  }

  function onEventSquadSetReady(params)
  {
    updateReadyButton()
    squadMsg(::g_squad_manager.isMeReady() ? ::loc("squad/change_to_ready") : ::loc("squad/change_to_not_ready"))
  }

  function onEventQueueChangeState(params)
  {
    updateReadyButton()
  }

  function onEventSquadPlayerInvited(params)
  {
    if (!::g_squad_manager.isSquadLeader())
      return

    local uid = ::getTblValue("uid", params, "")
    if (::u.isEmpty(uid))
      return

    local contact = ::getContact(uid)
    if (contact != null)
       squadMsg(format(::loc("squad/invited_player"), contact.name))
  }

  function checkValidAndSpamMessage(msg, room = null, isPrivate = false)
  {
    if (::is_chat_message_empty(msg))
      return false
    if (isPrivate || ::is_myself_anyof_moderators())
      return true
    if (::is_chat_message_allowed(msg))
      return true
    addRoomMsg(room? room : curRoom.id, "", ::loc("charServer/ban/reason/SPAM"))

    return false
  }

  function checkAndPrintDevoiceMsg(roomId = null)
  {
    if (!roomId)
      roomId = curRoom.id

    local devoice = penalties.getDevoiceMessage()
    if (devoice)
      addRoomMsg(roomId, "", devoice)
    return devoice != null
  }

  function onChatEdit(obj)
  {
    local sceneData = getSceneDataByActionObj(obj)
    if (!sceneData)
      return
    local roomData = ::g_chat.getRoomById(sceneData.room)
    if (roomData)
      roomData.lastTextInput = obj.getValue()
  }

  function onChatSend(obj)
  {
    chatSendAction(obj, true)
  }

  function chatSendAction(obj, isFromButton = false)
  {
    local sceneData = getSceneDataByActionObj(obj)
    if (!sceneData)
      return

    if (sceneData.room=="")
      return

    lastActionRoom = sceneData.room
    local inputObj = sceneData.scene.findObject("menuchat_input")
    local value = ::checkObj(inputObj)? inputObj.getValue() : ""
    if (value == "")
    {
      local roomData = findCustomRoomByObj(obj)
      if (!isFromButton && roomData && roomData.ownerHandler && ("onCustomChatContinue" in roomData.ownerHandler))
        roomData.ownerHandler.onCustomChatContinue.call(roomData.ownerHandler)
      return
    }

    inputObj.setValue("")
    sendMessageToRoom(value, sceneData.room)
  }

  function sendMessageToRoom(msg, roomId, isSystemMessage = false)
  {
    ::last_send_messages.append(msg)
    if (::last_send_messages.len() > ::g_chat.MAX_LAST_SEND_MESSAGES)
      ::last_send_messages.remove(0)
    lastSendIdx = -1

    if (!::g_chat.checkChatConnected())
      return

    msg = checkCmd(msg)
    if (!msg)
      return

    if (checkAndPrintDevoiceMsg(roomId))
      return

    if (!isSystemMessage)
      msg = ::g_chat.validateChatMessage(msg)

    local privateData = getPrivateData(msg, roomId)
    if (privateData)
      onChatPrivate(privateData)
    else
    {
      if (checkValidAndSpamMessage(msg, roomId))
      {
        if (::g_chat.isSystemChatRoom(roomId))
          addRoomMsg(roomId, "", ::loc("chat/cantWriteInSystem"))
        else {
          skipMyMessages = !needLocalEcho
          gchat_chat_message(roomId, msg)
          skipMyMessages = false
          ::play_gui_sound("chat_send")
        }
      }
    }
  }

  function getPrivateData(msg, roomId = null)
  {
    if (msg.slice(0, 1)=="\\" || msg.slice(0, 1)=="/")
    {
      msg = msg.slice(1)
      local res = { user = "", msg = "" }
      local start = msg.find(" ")
      if (start==null || start<1)
        res.user = msg
      else
      {
        res.user = msg.slice(0, start)
        res.msg = msg.slice(start+1)
      }
      return res
    }
    if (!roomId && curRoom)
      roomId = curRoom.id
    if (roomId && ::g_chat_room_type.PRIVATE.checkRoomId(roomId))
      return { user = roomId, msg = msg }
    return null
  }

  function onChatPrivate(data)
  {
    if (!checkValidAndSpamMessage(data.msg, null, true))
      return
    if (!curRoom)
      return

    if (gchat_chat_private_message(curRoom.id, data.user, data.msg))
    {
      if (needLocalEcho)
        addRoomMsg(curRoom.id, data.user, data.msg, true, true)

      local blocked = ::isPlayerNickInContacts(data.user, ::EPL_BLOCKLIST)
      if (blocked)
        addRoomMsg(curRoom.id, "", format(::loc("chat/cantChatWithBlocked"), "<Link="+::g_chat.generatePlayerLink(data.user)+">"+data.user+"</Link>"))
      else
        if (data.user!=curRoom.id)
        {
          local userRoom = ::g_chat.getRoomById(data.user)
          if (!userRoom)
          {
            addRoom(data.user)
            updateRoomsList()
          }
          if (needLocalEcho)
            addRoomMsg(data.user, data.user, data.msg, true, true)
        }
    }
  }

  function showLastSendMsg(showScene = null)
  {
    if (!::checkObj(showScene))
      return
    local obj = showScene.findObject("menuchat_input")
    if (!::checkObj(obj))
      return

    obj.setValue((lastSendIdx in ::last_send_messages)? ::last_send_messages[lastSendIdx] : "")
  }

  function openInviteMenu(menu, position)
  {
    if(menu.len() > 0)
      ::gui_right_click_menu(menu, this, position)
  }

  function hasPrefix(roomId, prefix)
  {
    return roomId.len() >= prefix.len() && roomId.slice(0, prefix.len()) == prefix
  }

  function switchLastSendMsg(inc, obj)
  {
    if (::last_send_messages.len()==0)
      return

    local selObj = guiScene.getSelectedObject()
    if (!::checkObj(selObj) || selObj.id!="menuchat_input")
      return
    local sceneData = getSceneDataByActionObj(selObj)
    if (!sceneData)
      return

    lastSendIdx += inc
    if (lastSendIdx < -1)
      lastSendIdx = ::last_send_messages.len()-1
    if (lastSendIdx >= ::last_send_messages.len())
      lastSendIdx = -1
    showLastSendMsg(sceneData.scene)
  }

  function onPrevMsg(obj)
  {
    switchLastSendMsg(-1, obj)
  }

  function onNextMsg(obj)
  {
    switchLastSendMsg(-1, obj)
  }

  function onShowPlayersList()
  {
    showPlayersList = !showPlayersList
    updateUsersList()
  }

  function onChatLinkClick(obj, itype, link)  { onChatLink(obj, link, ::is_platform_pc) }
  function onChatLinkRClick(obj, itype, link) { onChatLink(obj, link, false) }

  function onChatLink(obj, link, lclick)
  {
    local sceneData = getSceneDataByActionObj(obj)
    if (!sceneData)
      return

    if (link && link.len() < 4)
      return

    if(link.slice(0, 2) == "PL")
    {
      local name = ""
      local contact = null
      if(link.slice(0, 4) == "PLU_")
      {
        contact = getContact(link.slice(4))
        name = contact.name
      }
      else
      {
        name = link.slice(3)
        contact = findContactByNick(name)
      }
      if (lclick)
        addNickToEdit(name, sceneData.scene)
      else
        ::g_chat.showPlayerRClickMenu(name, sceneData.room, contact)
    }
    else if (::g_chat.checkBlockedLink(link))
    {
      local roomData = ::g_chat.getRoomById(sceneData.room)
      if (!roomData)
        return

      roomData.chatText = ::g_chat.revertBlockedMsg(roomData.chatText, link)
      updateChatText()
    }
    else
      ::g_invites.acceptInviteByLink(link)
  }

  function onUserListClick(obj)  { onUserList(obj, ::is_platform_pc) }
  function onUserListRClick(obj) { onUserList(obj, false) }

  function onUserList(obj, lclick)
  {
    if (!obj || !obj.id || obj.id.len() <= 10 || obj.id.slice(0,10) != "user_name_") return

    local num = obj.id.slice(10).tointeger()
    local name = obj.text
    if (curRoom && checkScene())
      if(curRoom.users.len() > num)
        {
          name = curRoom.users[num].name
          scene.findObject("users_list").setValue(num)
        }

    local sceneData = getSceneDataByActionObj(obj)
    if (!sceneData)
      return
    if (lclick)
      addNickToEdit(name, sceneData.scene)
    else
      ::g_chat.showPlayerRClickMenu(name, sceneData.room)
  }

  function changePrivateTo(user)
  {
    if (!::g_chat.checkChatConnected())
      return
    if (!checkScene())
      return

    if (user!=curRoom.id)
    {
      local userRoom = ::g_chat.getRoomById(user)
      if (!userRoom)
        addRoom(user)
      switchCurRoom(user)
    }
    ::broadcastEvent("ChatOpenPrivateRoom", { room = user })
  }

  function addNickToEdit(user, showScene = null)
  {
    if (!showScene)
    {
      if (!checkScene())
        return
      showScene = scene
    }

    local inputObj = showScene.findObject("menuchat_input")
    if (!::checkObj(inputObj))
      return

    ::add_text_to_editbox(inputObj, user + " ")
    inputObj.select()
  }

  function onShowSearchList()
  {
    showSearch()
  }

  function showSearch(show=null)
  {
    if (!checkScene())
      return

    local sObj = scene.findObject("searchDiv")
    local wasVisible = sObj.isVisible()
    if (show==null)
      show = !wasVisible

    if (!show && wasVisible)
      getSizes()

    sObj.show(show)
    if (show)
    {
      setSavedSizes()
      if (!searchInited)
        fillSearchList()
    }
  }

  function validateSearchList()
  {
    if (!searchRoomList)
      return

    for(local i = searchRoomList.len() - 1; i >= 0; i--)
      if (!::g_chat_room_type.getRoomType(searchRoomList[i]).isVisibleInSearch())
        searchRoomList.remove(i)
  }

  function resetSearchList()
  {
    if (::g_chat_room_type.GLOBAL.isVisibleInSearch())
      searchRoomList = ::getGlobalRoomsList()
    else
      searchRoomList = []
    searchShowNotFound = false
    defaultRoomsInSearch = true
  }

  function fillSearchList()
  {
    if (!checkScene())
      return

    if (!searchRoomList)
      resetSearchList()

    showSceneBtn("btn_mainChannels", !defaultRoomsInSearch && ::g_chat_room_type.GLOBAL.isVisibleInSearch())

    local listObj = scene.findObject("searchList")
    if (!::checkObj(listObj))
      return

    guiScene.setUpdatesEnabled(false, false)
    local data = ""
    local total = ::min(searchRoomList.len(), ::g_chat.MAX_ROOMS_IN_SEARCH)
    if (searchRoomList.len() > 0)
    {
      for(local i = 0; i < total; i++)
      {
        local rName = searchRoomList[i]
        rName = (rName.slice(0, 1)=="#")? rName.slice(1) : ::loc("chat/channel/" + rName, rName)
        data += ::format("text { id:t='search_room_txt_%d'; text:t='%s'; tooltip:t='%s'; }",
                    i, ::g_string.stripTags(rName), ::g_string.stripTags(rName))
      }
    }
    else
    {
      if (searchInProgress)
        data = "animated_wait_icon { pos:t='0.5(pw-w),0.03sh'; position:t='absolute'; background-rotation:t='0' }"
      else if (searchShowNotFound)
        data = "textAreaCentered { text:t='#contacts/searchNotFound'; enable:t='no' }"
      searchShowNotFound = true
    }

    guiScene.replaceContentFromText(listObj, data, data.len(), this)
    guiScene.setUpdatesEnabled(true, true)

    searchInited = true
  }

  last_search_time = -10000000
  function onSearchStart()
  {
    if (!checkScene())
      return

    if (!::ps4_is_ugc_enabled())
    {
      ::ps4_show_ugc_restriction()
      return
    }

    if (searchInProgress && (::dagor.getCurTime() - last_search_time < 5000))
      return

    local sObj = scene.findObject("search_edit")
    local value = sObj.getValue()
    if (!value || ::is_chat_message_empty(value))
      return

    value = "#" + ::clearBorderSymbols(value, [" ", "*"]) + "*"
    searchInProgress = true
    defaultRoomsInSearch = false
    searchRoomList = []
    ::gchat_list_rooms(value)
    fillSearchList()

    last_search_time = ::dagor.getCurTime()
  }

  function closeSearch()
  {
    if (::g_chat.isSystemChatRoom(curRoom.id))
      goBack()
    else if (checkScene())
    {
      scene.findObject("searchDiv").show(false)
      onWrapToEditbox()
    }
  }

  function onCancelSearchEdit(obj)
  {
    if (!::checkObj(obj))
      return

    if (obj.getValue()=="" && defaultRoomsInSearch)
      closeSearch()
    else
    {
      onMainChannels()
      obj.setValue("")
    }

    searchShowNotFound = false
  }

  function onCancelSearchRooms(obj)
  {
    if (!checkScene())
      return

    if (defaultRoomsInSearch)
      return closeSearch()

    local searchObj = scene.findObject("search_edit")
    if (::checkObj(searchObj) && searchObj.isVisible())
      searchObj.select()
    onMainChannels()
  }

  function onSearchRoomJoin(obj)
  {
    if (!checkScene())
      return

    if (!::checkObj(obj))
      obj = scene.findObject("searchList")

    local value = obj.getValue()
    if (value in searchRoomList)
    {
      if (!::ps4_is_chat_enabled())
      {
        ::ps4_show_chat_restriction()
        return
      }
      else if (!::isInArray(searchRoomList[value], ::global_chat_rooms_list) && !::ps4_is_ugc_enabled())
      {
        ::ps4_show_ugc_restriction()
        return
      }

      onWrapToEditbox()
      local rName = (searchRoomList[value].slice(0,1)!="#")? "#"+searchRoomList[value] : searchRoomList[value]
      local room = ::g_chat.getRoomById(rName)
      if (room)
        switchCurRoom(room)
      else
      {
        changeRoomOnJoin = rName
        joinRoom(changeRoomOnJoin)
      }
    }
  }

  function onMainChannels()
  {
    if (checkScene() && !defaultRoomsInSearch)
      guiScene.performDelayed(this, function()
      {
        if (!defaultRoomsInSearch)
        {
          resetSearchList()
          fillSearchList()
        }
      })
  }

  function isMenuChatActive()
  {
    return checkScene() && ::last_chat_scene_show;
  }

  function addChatJoinParams(request)
  {
    if(request.find(" "))
    {
      local roomName = request.slice(0, request.find(" "))
      roomJoinParamsTable[roomName] <- request.slice(roomName.len() + 1)
    }
  }

  function showRoomPopup(from, msg, roomId)
  {
    if (!from)
      msg = format("<color=%s>%s</color>", systemColor, msg)

    ::g_popups.add(from && (from + ":"),
            msg,
            (@(roomId) function () { openChatRoom(roomId) })(roomId),
            [],
            this)
  }

  function popupAcceptInvite(roomId)
  {
    if (::g_chat_room_type.THREAD.checkRoomId(roomId))
    {
      ::g_chat.joinThread(roomId)
      changeRoomOnJoin = roomId
      return
    }

    openChatRoom(curRoom.id)
    joinRoom(roomId)
    changeRoomOnJoin = roomId
  }

  function openChatRoom(roomId)
  {
    local curScene = getLastGamercardScene()

    switchMenuChatObj(getChatDiv(curScene))
    chatSceneShow(true)

    local roomList = scene.findObject("rooms_list")
    foreach (idx, room in ::g_chat.rooms)
      if (room.id == roomId)
      {
        roomList.setValue(idx)
        break
      }
    onRoomChanged()
  }

  function onEventPlayerPenaltyStatusChanged(params)
  {
    checkAndPrintDevoiceMsg()
  }

  function onEventNewSceneLoaded(p)
  {
    guiScene.performDelayed(this, function() //need delay becoase of in the next scene can be obj for this chat room too (mpLobby)
    {
      updateCustomChatTexts()
    })
  }

  function updateCustomChatTexts()
  {
    for(local idx = ::g_chat.rooms.len()-1; idx>=0; idx--)
    {
      local room = ::g_chat.rooms[idx]
      if (::checkObj(room.customScene))
      {
        local obj = room.customScene.findObject("menu_chat_text")
        if (::checkObj(obj))
          obj.setValue(room.chatText)
      }
      else if (room.existOnlyInCustom)
        closeRoom(idx)
    }
  }

  function isCustomRoomActionObj(obj)
  {
    local id = obj && obj._customRoomId
    return id!=null && id!=""
  }

  function findCustomRoomByObj(obj)
  {
    local id = obj._customRoomId
    if (id && id!="")
      return ::g_chat.getRoomById(id)

    //try to find by scene
    foreach(item in ::g_chat.rooms)
      if (::checkObj(item.customScene) && item.customScene.isEqual(obj))
        return item
    return null
  }

  function getSceneDataByActionObj(obj)
  {
    local showScene = null
    local showRoom = curRoom.id
    if (isCustomRoomActionObj(obj))
    {
      local customRoom = findCustomRoomByObj(obj)
      if (!customRoom || !::checkObj(customRoom.customScene))
        return null
      showScene = customRoom.customScene
      showRoom = customRoom.id
    }
    else if (checkScene())
      showScene = scene
    else
      return null

    return { room = showRoom, scene = showScene }
  }

  function joinCustomObjRoom(sceneObj, roomId, password, ownerHandler)
  {
    local prevRoom = findCustomRoomByObj(sceneObj)
    if (prevRoom)
      if (prevRoom.id == roomId)
        return
      else
        closeRoomById(prevRoom.id)

    local objGuiScene = sceneObj.getScene()
    objGuiScene.replaceContent(sceneObj, "gui/chat/customChat.blk", this)
    foreach(name in ["menuchat_input", "menu_chat_text", "btn_send", "btn_prevMsg", "btn_nextMsg"])
    {
      local obj = sceneObj.findObject(name)
      obj._customRoomId = roomId
    }

    local room = ::g_chat.getRoomById(roomId)
    if (room)
    {
      room.customScene = sceneObj
      room.ownerHandler = ownerHandler
      room.joined = true
      afterReconnectCustomRoom(roomId)
      updateChatText()
    }

    joinRoom(roomId, password,
      function() {
        afterReconnectCustomRoom(roomId)
      },
      sceneObj, ownerHandler)
  }

  function afterReconnectCustomRoom(roomId)
  {
    local roomData = ::g_chat.getRoomById(roomId)
    if (!roomData || !::checkObj(roomData.customScene))
      return

    foreach(objName in ["menuchat_input", "btn_send"])
    {
      local obj = roomData.customScene.findObject(objName)
      if (::checkObj(obj))
        obj.enable(::ps4_is_chat_enabled())
    }
  }

  function wrapNextSelect(obj = null, dir = 0)
  {
    if (isCustomRoomActionObj(obj))
    {
      local customRoom = findCustomRoomByObj(obj)
      if (customRoom && customRoom.ownerHandler && ("wrapNextSelect" in customRoom.ownerHandler))
        customRoom.ownerHandler.wrapNextSelect.call(customRoom.ownerHandler, obj, dir)
      return
    }

    if (checkScene())
    {
      base.wrapNextSelect(obj, dir)
      updateControlsAllowMaskDelayed()
    }
  }

  function getCurFocusObj(onlyFocused = false)
  {
    if (!checkScene() || scene.getModalCounter() != 0)
      return null
    local obj = findObjInFocusArray(true)
    if (!obj && !onlyFocused)
      obj = getFocusItemObj(currentFocusItem) || findObjInFocusArray(false)
    return obj
  }

  function getHeaderFocusObj()
  {
    return scene.findObject("rooms_list")
  }

  function onSwitchHeaderObj(obj)
  {
    if (!checkScene())
      return

    local curHeaderObjId = (obj.id=="rooms_list")? "header_buttons" : "rooms_list"
    local newObj = scene.findObject(curHeaderObjId)
    if (::checkObj(newObj))
    {
      local chCount = newObj.childrenCount()
      if (chCount <= 0)
        return

      for(local i = 0; i < chCount; i++)
      {
        local nextChObj = newObj.getChild(i)
        if (nextChObj.isVisible() && nextChObj.isEnabled())
        {
          newObj.select()
          break
        }
      }
    }
  }

  function onWrapToEditbox()
  {
    if (!checkScene())
      return
    local obj = scene.findObject("menuchat_input")
    if (::checkObj(obj))
      obj.select()
  }

  function getUsersListObj()
  {
    local obj = scene.findObject("users_list")
    return (::checkObj(obj) && obj.childrenCount())? obj : null
  }

  function getButtonsObj()
  {
    local obj = scene.findObject("buttons_list")
    return (::checkObj(obj) && ::is_obj_have_active_childs(obj))? obj : null
  }

  function checkListValue(obj)
  {
    if (obj.getValue() < 0 && obj.childrenCount())
      obj.setValue(0)
  }

  function onChatListFocus(obj)
  {
    checkListValue(obj)
    updateControlsAllowMaskDelayed()
  }

  function onEventInviteReceived(params)
  {
    local invite = ::getTblValue("invite", params)
    if (!invite || !invite.isVisible())
      return

    local msg = invite.getChatInviteText()
    if (msg.len())
      addRoomMsg("", "", msg, false, false, invite.inviteColor, true)
  }

  function onEventInviteUpdated(params)
  {
    onEventInviteReceived(params)
  }

  function getRoomHandlerFocusObj(idx)
  {
    if (!roomHandlerWeak || !roomHandlerWeak.isSceneActive())
      return null

    local funcId = "getMainFocusObj" + ((idx == 1)? "" : idx)
    return roomHandlerWeak[funcId]()
  }

  isPrimaryFocus = false
  focusArray = [
    function() { return getHeaderFocusObj() }
    function() { return getUsersListObj() }
    function() { return getButtonsObj() }
    "search_edit"
    function() { return (searchRoomList && searchRoomList.len())? scene.findObject("searchList") : null }
    function() { return getRoomHandlerFocusObj(1) }
    function() { return getRoomHandlerFocusObj(2) }
    function() { return getRoomHandlerFocusObj(3) }
    "menuchat_input"
  ]
  currentFocusItem = -1
  defaultFocus = 1

  scene = null
  sceneChanged = true
  roomsInited = false
  isFirstAskForSession = true

  chatTasks = []
  lastSendIdx = -1

  invitedToSquad = []

  roomJoinParamsTable = {} //roomName : paramString

  roomHost = "@conference.char2.yuplay.com"
  userHost = "@char2.yuplay.com"

  curRoom = null
  curChatText = ""
  lastActionRoom = ""
  showPlayersList = true

  searchInProgress = false
  searchShowNotFound = false
  searchRoomList = null
  searchInited = false
  defaultRoomsInSearch = false
  changeRoomOnJoin = ""

  privateColor = "@chatTextPrivateColor"
  blockedColor = "@chatTextBlockedColor"
  xpostColor = "@chatTextXpostColor"
  mpostColor = "@chatTextMpostColor"

  systemColor = "@chatInfoColor"
}

function menuChatCb(event, taskId, db)
{
  if (::menu_chat_handler)
    ::menu_chat_handler.onEventCb.call(::menu_chat_handler, event, taskId, db)
}

function initEmptyMenuChat()
{
  if (!::menu_chat_handler)
  {
    ::menu_chat_handler <- ::MenuChatHandler(::get_gui_scene())
    ::menu_chat_handler.initChat(null)
  }
}

if (::g_login.isLoggedIn())
  initEmptyMenuChat()

function loadMenuChatToObj(obj)
{
  if (!::checkObj(obj))
    return

  local guiScene = obj.getScene()
  if (!::menu_chat_handler)
    ::menu_chat_handler <- ::MenuChatHandler(guiScene)
  ::menu_chat_handler.initChat(obj)
}

function switchMenuChatObj(obj)
{
  if (!::menu_chat_handler)
  {
    ::loadMenuChatToObj(obj)
  } else
    ::menu_chat_handler.switchScene(obj)
}

function switchMenuChatObjIfVisible(obj)
{
  if (::menu_chat_handler &&
      ::last_chat_scene_show &&
      !(::is_platform_ps4 && ::is_in_loading_screen()) //!!!HACK, till hover is not working on loading
     )
    ::menu_chat_handler.switchScene(obj, true)
}

function checkMenuChatBack()
{
  if (::menu_chat_handler)
    ::menu_chat_handler.checkScene()
}

function openChatScene(ownerHandler = null)
{
  if (!gchat_is_enabled() || !::has_feature("Chat"))
  {
    ::showInfoMsgBox(::loc("msgbox/notAvailbleYet"))
    return false
  }

  local scene = ownerHandler ? ownerHandler.scene : ::getLastGamercardScene()
  if(!::checkObj(scene))
    return false

  local obj = getChatDiv(scene)
  if (!::menu_chat_handler)
    ::loadMenuChatToObj(obj)
  else
    ::menu_chat_handler.switchScene(obj, true)
  return ::menu_chat_handler!=null
}

function openChatPrivate(playerName, ownerHandler = null)
{
  if (!::openChatScene(ownerHandler))
    return
  ::menu_chat_handler.changePrivateTo.call(::menu_chat_handler, playerName)
}

function isMenuChatActive()
{
  if (!::menu_chat_handler)
    return false;

  return ::menu_chat_handler.isMenuChatActive();
}

function chatUpdatePresence(contact)
{
  if (::menu_chat_handler)
    ::menu_chat_handler.updatePresenceContact.call(::menu_chat_handler, contact)
}

function resetChat()
{
  ::g_chat.rooms = []
  ::new_menu_chat_messages <- false
  ::last_send_messages <- []
  ::delayed_chat_messages <- ""
  ::last_chat_scene_show <- false
  if (::menu_chat_handler)
    ::menu_chat_handler.roomsInited = false
}

function getChatDiv(scene)
{
  if(!::checkObj(scene))
    scene = null
  local guiScene = get_gui_scene()
  local chatObj = scene ? scene.findObject("menuChat_scene") : guiScene["menuChat_scene"]
  if (!chatObj)
  {
    guiScene.appendWithBlk(scene? scene : "", "tdiv { id:t='menuChat_scene' }")
    chatObj = scene ? scene.findObject("menuChat_scene") : guiScene["menuChat_scene"]
  }
  return chatObj
}

function addChatJoinParams(request)
{
  if (::menu_chat_handler)
    ::menu_chat_handler.addChatJoinParams.call(::menu_chat_handler, request)
}

function open_invite_menu(menu, position)
{
  if (::menu_chat_handler)
    ::menu_chat_handler.openInviteMenu.call(::menu_chat_handler, menu, position)
}

function joinCustomObjRoom(obj, roomName, password = "", owner = null)
//owner need if you want to handle custom room events:
//  onCustomChatCancel   (press esc when room input in focus)
//  onCustomChatContinue (press enter on empty message)
{
  if (::menu_chat_handler)
    ::menu_chat_handler.joinCustomObjRoom.call(::menu_chat_handler, obj, roomName, password, owner)
}

function getCustomObjEditbox(obj)
{
  if (!::checkObj(obj))
    return null
  local inputBox = obj.findObject("menuchat_input")
  return ::checkObj(inputBox)? inputBox : null
}

function get_menuchat_focus_obj()
{
  if (::menu_chat_handler)
    return ::menu_chat_handler.getCurFocusObj.call(::menu_chat_handler)
  return null
}

function isUserBlockedByPrivateSetting(uid = null, userName = "")
{
  local checkUid = uid != null

  local privateValue = ::get_gui_option_in_mode(::USEROPT_ONLY_FRIENDLIST_CONTACT, ::OPTIONS_MODE_GAMEPLAY)
  return (privateValue && !::isPlayerInFriendsGroup(uid, checkUid, userName))
}
