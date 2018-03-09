local platformModule = require("scripts/clientState/platform.nut")

function gui_modal_ban(playerInfo, chatLog)
{
  ::gui_start_modal_wnd(::gui_handlers.BanHandler, { player = playerInfo, chatLog = chatLog })
}

function gui_modal_complain(playerInfo, chatLog = "")
{
  if (!::tribunal.canComplaint())
    return

  local cLog = (chatLog != "") ? chatLog : ::get_gamechat_log_text()
  if (cLog == "" && ::debriefing_result)
      cLog = ::getTblValue("chatLog", ::debriefing_result, "")

  ::gui_start_modal_wnd(::gui_handlers.ComplainHandler, {
                                                          pInfo = playerInfo
                                                          chatLog = cLog
                                                        })
}

class ::gui_handlers.BanHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName = "gui/complain.blk"
  wndType = handlerType.MODAL

  player = null
  playerName = null
  optionsList = null
  chatLog = ""

  function initScreen()
  {
    if (!scene || !player || !canBan())
      return goBack()

    playerName = ::getTblValue("name", player, "")
    if (!::getTblValue("uid", player))
    {
      taskId = ::find_contact_by_name_and_do(playerName, this, onPlayerFound)
      if (taskId!=null && taskId<0)
      {
        notFoundPlayerMsg()
        return
      }
    }

    local titleObj = scene.findObject("complaint_title")
    if (::checkObj(titleObj))
      titleObj.setValue(::loc("contacts/moderator_ban/title"))

    local nameObj = scene.findObject("complain_text")
    if (::checkObj(nameObj))
      nameObj.setValue(::loc("clan/nick") + ::loc("ui/colon"))

    local clanTag = ::getTblValue("clanTag", player, "")
    local targetObj = scene.findObject("complain_target")
    if (::checkObj(targetObj))
      targetObj.setValue((clanTag.len() > 0? (clanTag + " ") : "") + platformModule.getPlayerName(playerName))

    local options = [
      ::USEROPT_COMPLAINT_CATEGORY,
      ::USEROPT_BAN_PENALTY,
      ::USEROPT_BAN_TIME
    ]
    optionsList = []
    foreach(o in options)
      optionsList.append(::get_option(o))

    local optionsBox = scene.findObject("options_rows_div")
    local objForClones = optionsBox.getChild(0)
    for(local i=1; i<=optionsList.len(); i++)
    {
      local idx = (i<optionsList.len())? i : 0
      local opt = optionsList[idx]
      local optRow = null
      if (idx==0)
        optRow = objForClones
      else
        optRow = objForClones.getClone(optionsBox, this)

      optRow.findObject("option_name").setValue(::loc("options/" + opt.id))
      local typeObj = optRow.findObject("option_list")
      local data = create_option_list(opt.id, opt.items, opt.value, null, false)
      guiScene.replaceContentFromText(typeObj, data, data.len(), this)
      typeObj.id = opt.id
    }

    initFocusArray()
    onTypeChange()
    updateButtons()
  }

  function getMainFocusObj()
  {
    return getObj(optionsList[0].id)
  }

  function getMainFocusObj2()
  {
    return getObj(optionsList[1].id)
  }

  function getMainFocusObj3()
  {
    return getObj(optionsList[2].id)
  }

  function getMainFocusObj4()
  {
    return getObj("complaint_text")
  }

  function canBan()
  {
    return ::myself_can_devoice() || ::myself_can_ban()
  }

  function notFoundPlayerMsg()
  {
    msgBox("incorrect_user", ::loc("chat/error/item-not-found", { nick = platformModule.getPlayerName(playerName) }),
        [
          ["ok", function() { goBack() } ]
        ], "ok")
  }

  function updateButtons()
  {
    local haveUid = ::getTblValue("uid", player) != null
    showSceneBtn("info_loading", !haveUid)
    showSceneBtn("btn_send", haveUid)
  }

  function onPlayerFound(contact)
  {
    if (!contact)
      return notFoundPlayerMsg()

    player = contact
    if (::checkObj(scene))
      updateButtons()
  }

  function onTypeChange()
  {
    scene.findObject("complaint_text").select()
  }

  function onApply()
  {
    if (!canBan())
      return goBack()

    local comment = ::g_string.clearBorderSymbolsMultiline(  scene.findObject("complaint_text").getValue()  )
    if (comment.len() < 10)
    {
      msgBox("need_text", ::loc("msg/complain/needDetailedComment"),
        [["ok", function() {} ]], "ok")
      return
    }

    local uid = ::getTblValue("uid", player)
    if (!uid)
      return

    foreach(opt in optionsList)
    {
      local obj = scene.findObject(opt.id)
      ::set_option(opt.type, obj.getValue(), opt)
    }

    local duration = ::get_gui_option(::USEROPT_BAN_TIME)
    local category = ::get_gui_option(::USEROPT_COMPLAINT_CATEGORY)
    local penalty =  ::get_gui_option(::USEROPT_BAN_PENALTY)

    dagor.debug(format("%s user: %s, for %s, for %d sec.\n comment: %s",
                       penalty, playerName, category, duration, comment))

    taskId = char_ban_user(uid, duration, "", category, penalty,
                           comment, ""/*hidden_note*/, chatLog)
    if (taskId >= 0)
    {
      ::set_char_cb(this, slotOpCb)
      showTaskProgressBox(::loc("charServer/send"))
      afterSlotOp = function()
        {
          dagor.debug("[IRC] sending /reauth " + playerName)
          ::gchat_raw_command("reauth " + playerName)
          goBack()
        }
    }
  }
}

class ::gui_handlers.ComplainHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  optionsList = null

  function initScreen()
  {
    if (!scene || !pInfo || typeof(pInfo) != "table")
      return goBack()

    local gameMode = "GameMode = " + ::loc(format("multiplayer/%sMode", ::get_game_mode_name(::get_game_mode())))
    local location = gameMode
    if (chatLog != "")
    {
      if ("roomId" in pInfo && "roomName" in pInfo)
        location = "Main Chat, Channel = " + pInfo.roomName + " (" + pInfo.roomId + ")"
      else
        location = "In-game Chat; " + gameMode
    }
    chatLog = location + "\n" + chatLog

    local pName = platformModule.getPlayerName(pInfo.name)
    local clanTag
    if("clanData" in pInfo)
    {
      local clanData = pInfo.clanData
      clanTag = ("tag" in clanData) ? clanData.tag : null

      local clanInfo = ("id" in clanData ? "clan id = " + clanData.id + "\n" : "") +
                ("tag" in clanData ? "clan tag = " + clanData.tag + "\n" : "") +
                ("name" in clanData ? "clan name = " + clanData.name + "\n" : "") +
                ("slogan" in clanData ? "clan slogan = " + clanData.slogan + "\n" : "") +
                ("desc" in clanData ? "clan description = " + clanData.desc : "")
      chatLog += "\n" + clanInfo
    }
    clanTag = clanTag || ( ("clanTag" in pInfo && pInfo.clanTag != "") ? pInfo.clanTag : null )
    pName = clanTag ? (clanTag + " " + pName) : pName

    local titleObj = scene.findObject("complaint_title")
    if (::checkObj(titleObj))
      titleObj.setValue(::loc("mainmenu/btnComplain"))

    local nameObj = scene.findObject("complain_text")
    if (::checkObj(nameObj))
      nameObj.setValue(::loc("clan/nick") + ::loc("ui/colon"))
    local targetObj = scene.findObject("complain_target")
    if (::checkObj(targetObj))
      targetObj.setValue(pName)

    local typeObj = scene.findObject("option_list")

    optionsList = []
    local option = ::get_option(::USEROPT_COMPLAINT_CATEGORY)
    optionsList.append(option)
    local data = create_option_list(option.id, option.items, option.value, null, false)
    guiScene.replaceContentFromText(typeObj, data, data.len(), this)
    typeObj.id = option.id

    initFocusArray()
    onTypeChange()
  }

  function getMainFocusObj()
  {
    return getObj(optionsList[0].id)
  }

  function getMainFocusObj2()
  {
    return getObj("complaint_text")
  }

  function onTypeChange()
  {
    scene.findObject("complaint_text").select()
  }

  function collectThreadListForTribunal()
  {
    local threads = []
    foreach( t in ::g_chat_latest_threads.getList())
    {
      threads.append({  tags      = t.getFullTagsString(),
                        title     = t.title,
                        numPosts  = t.numPosts,
                        owner     = t.getOwnerText()       })
    }
    return threads
  }

  function collectUserDetailsForTribunal( src )
  {
    local res = {};

    if ( src != null )
    {
      foreach(key in ["kills", "teamKills", "name", "clanTag", "groundKills", "navalKills", "exp", "deaths"])
      {
        res[key] <- ((key in src)&&(src[key] != null))? src[key] : "<N/A>";
      }
      res["uid"] <- (("userId" in src) && src.userId) || "<N/A>" //in mplayer uid not the same like in other places. userId is real uid.
    }

    return res;
  }

  function onApply()
  {
    if (!isValid())
      return

    local user_comment = ::g_string.clearBorderSymbolsMultiline( scene.findObject("complaint_text").getValue() )
    if (user_comment.len() < 10)
    {
      msgBox("need_text", ::loc("msg/complain/needDetailedComment"),
        [["ok", function() {} ]], "ok")
      return
    }

    local option = ::get_option(::USEROPT_COMPLAINT_CATEGORY)
    local cValue = scene.findObject(option.id).getValue()
    local category = (cValue in option.values)? option.values[cValue] : option.values[0]
    local details = ::save_to_json({
      own      = collectUserDetailsForTribunal( ::get_local_mplayer() ),
      offender = collectUserDetailsForTribunal( pInfo ),
      chats    = collectThreadListForTribunal()
    });

    dagor.debug("Send complaint " + category + ": \ncomment = " + user_comment + ", \nchatLog = " + chatLog + ", \ndetails = " + details)
    dagor.debug("pInfo:")
    debugTableData(pInfo)

    taskId = -1
    if (("userId" in pInfo) && pInfo.userId)
      taskId = send_complaint_by_uid(pInfo.userId, category, user_comment, chatLog, details)
    else if ("name" in pInfo)
      taskId = send_complaint_by_nick(pInfo.name, category, user_comment, chatLog, details)
    else
      taskId = send_complaint(pInfo.id, category, user_comment, chatLog, details)
    if (taskId >= 0)
    {
      ::set_char_cb(this, slotOpCb)
      showTaskProgressBox(::loc("charServer/send"))
      afterSlotOp = goBack
    }
  }

  pInfo = null
  chatLog = ""

  scene = null
  task = ""
  wndType = handlerType.MODAL
  sceneBlkName = "gui/complain.blk"
}
