::game_chat_handler <- null

function get_game_chat_handler()
{
  if (!::game_chat_handler)
    ::game_chat_handler = ::ChatHandler()
  return ::game_chat_handler
}

enum mpChatView {
  CHAT
  BATTLE
}

class ::ChatHandler
{
  maxLogSize = 20
  log = []
  log_text = ""
  curMode = ::g_mp_chat_mode.TEAM

  senderColor = "@chatSenderFriendColor"
  senderEnemyColor = "@chatSenderEnemyColor"
  senderMeColor = "@chatSenderMeColor"
  senderMySquadColor = "@chatSenderMySquadColor"
  senderSpectatorColor = "@chatSenderSpectatorColor"

  blockedColor = "@chatTextBlockedColor"

  voiceTeamColor = "@chatTextTeamVoiceColor"
  voiceSquadColor = "@chatTextSquadVoiceColor"
  voiceEnemyColor = "@chatTextEnemyVoiceColor"

  scenes = [] //{ idx, scene, handler, transparency, selfHideInput, selfHideLog }
  last_scene_idx = 0
  sceneIdxPID = ::dagui_propid.add_name_id("sceneIdx")

  isMouseCursorVisible = false
  isActive = false // While it is true, in-game unit control shortcuts are disabled in client.

  function constructor()
  {
    ::g_script_reloader.registerPersistentData("mpChat", this,
      ["log", "log_text", "curMode",
       "isActive"
      ])

    ::subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)
    maxLogSize = ::g_chat.getMaxRoomMsgAmount()
    isMouseCursorVisible = ::is_cursor_visible_in_gui()

    if (::is_in_flight())
      ::set_chat_handler(this)
  }

  function loadScene(obj, chatBlk, handler, selfHideInput = false, hiddenInput = false, selfHideLog = false)
  {
    if (!::checkObj(obj))
      return null

    cleanScenesList()
    local sceneData = findSceneDataByScene(obj)
    if (sceneData)
    {
      sceneData.handler = handler
      return sceneData
    }

    obj.getScene().replaceContent(obj, chatBlk, this)
    return addScene(obj, handler, selfHideInput, hiddenInput, selfHideLog)
  }

  function addScene(newScene, handler, selfHideInput, hiddenInput, selfHideLog)
  {
    local sceneData = {
      idx = ++last_scene_idx
      scene = newScene
      handler = handler
      transparency = 0.0
      selfHideLog = selfHideLog     // Hide log on timer
      selfHideInput = selfHideInput // Hide input on send/cancel
      hiddenInput = hiddenInput     // Chat is read-only
      curTab = mpChatView.CHAT
    }

    local scene = sceneData.scene
    local inputObj = scene.findObject("chat_input")
    if (inputObj)
      inputObj.setIntProp(sceneIdxPID, sceneData.idx)

    local chatLog = scene.findObject("chat_log")
    if (chatLog)
      chatLog.setIntProp(sceneIdxPID, sceneData.idx)

    local chatTabs = scene.findObject("chat_tabs")
    if (chatTabs)
      chatTabs.setIntProp(sceneIdxPID, sceneData.idx)

    local timerObj = scene.findObject("chat_update")
    if (timerObj && (selfHideInput || selfHideLog))
    {
      timerObj.setIntProp(sceneIdxPID, sceneData.idx)
      timerObj.setUserData(this)
      updateChatScene(sceneData, 0.0)
      updateChatInput(sceneData)
    }

    updateTabs(sceneData)
    updateContent(sceneData)
    updatePrompt(sceneData)
    scenes.append(sceneData)
    validateCurMode()
    return sceneData
  }

  function cleanScenesList()
  {
    for(local i = scenes.len() - 1; i >= 0; i--)
      if (!::checkObj(scenes[i].scene))
        scenes.remove(i)
  }

  function findSceneDataByScene(scene)
  {
    foreach(sceneData in scenes)
      if (::checkObj(sceneData.scene) && sceneData.scene.isEqual(scene))
        return sceneData
    return null
  }

  function findSceneDataByObj(obj)
  {
    local idx = obj.getIntProp(sceneIdxPID, -1)
    foreach(i, sceneData in scenes)
      if (sceneData.idx == idx)
        if (::checkObj(sceneData.scene))
          return sceneData
        else
        {
          scenes.remove(i)
          break
        }
    return null
  }

  function doForAllScenes(func)
  {
    for(local i = scenes.len() - 1; i >= 0; i--)
      if (::checkObj(scenes[i].scene))
        func(scenes[i])
      else
        scenes.remove(i)
  }

  function onUpdate(obj, dt)
  {
    local sceneData = findSceneDataByObj(obj)
    if (sceneData)
      updateChatScene(sceneData, dt)
  }

  function updateChatScene(sceneData, dt)
  {
    if (!sceneData.selfHideLog)
      return

    local isHudVisible = ::is_hud_visible()
    local transparency = sceneData.transparency
    if (!isHudVisible)
      transparency = 0
    else if (!isActive)
      transparency -= dt / ::chat_window_disappear_time
    else
      transparency += dt / ::chat_window_appear_time
    transparency = ::clamp(transparency, 0.0, 1.0)

    local transValue = (isHudVisible && isMouseCursorVisible) ? 100 :
      (100.0 * (3.0 - 2.0 * transparency) * transparency * transparency).tointeger()
    local obj = sceneData.scene.findObject("chat_log_tdiv")
    if (::checkObj(obj))
    {
      obj.transparent = transValue
      sceneData.scene.findObject("chat_log").transparent = transValue
    }

    sceneData.transparency = transparency
  }

  function onEventChangedCursorVisibility(params)
  {
    isMouseCursorVisible = ::is_cursor_visible_in_gui()

    doForAllScenes(function(sceneData) {
      updateTabs(sceneData)
      updateContent(sceneData)
      updateChatInput(sceneData)
      updateChatScene(sceneData, 0.0)
    })
  }

  function canEnableChatInput()
  {
    if (!::ps4_is_chat_enabled())
      return false
    foreach(sceneData in scenes)
      if (!sceneData.hiddenInput && ::checkObj(sceneData.scene) && sceneData.scene.isVisible())
        return true
    return false
  }

  function enableChatInput(value)
  {
    if (value == isActive)
      return

    isActive = value
    doForAllScenes(updateChatInput)
    ::broadcastEvent("MpChatInputToggled", { active = isActive })
    ::handlersManager.updateControlsAllowMask()
  }

  function updateChatInput(sceneData)
  {
    if (isActive && !sceneData.scene.isVisible())
      return

    local show = (isActive || !sceneData.selfHideInput) && !sceneData.hiddenInput && ::ps4_is_chat_enabled() && getCurView(sceneData) == mpChatView.CHAT
    local scene = sceneData.scene

    ::showBtnTable(scene, {
        chat_input              = show
        chat_prompt             = show
        chat_input_back         = show
        chat_input_placeholder  = !show && canEnableChatInput()
        btn_send                = show
    })
    ::enableBtnTable(scene, {
        chat_input              = show
        btn_send                = show
        chat_mod_accesskey      = show
    })
    if (show && sceneData.selfHideInput)
    {
      local obj = scene.findObject("chat_input")
      if (::checkObj(obj))
        obj.select()
    }
  }

  function hideChatInput(sceneData, value)
  {
    if (value && isActive)
      enableChatInput(false)

    sceneData.hiddenInput = value
    updateChatInput(sceneData)
  }

  function onChatIngameRequestActivate(obj = null)
  {
    ::toggle_ingame_chat(true)
  }

  function onChatIngameRequestCancel(obj = null)
  {
    ::toggle_ingame_chat(false)
  }

  function onChatIngameRequestEnter(obj)
  {
    local editboxObj = (::checkObj(obj) && obj.getParent()) ? obj.getParent().findObject("chat_input") : null
    if (::checkObj(editboxObj) && ("onChatEntered" in editboxObj))
      onChatEntered(editboxObj)
  }

  function onChatEntered(obj)
  {
    local sceneData = findSceneDataByObj(obj)
    if (!sceneData)
      return

    if (sceneData.handler && ("onEmptyChatEntered" in sceneData.handler) && obj && obj.getValue()=="")
      sceneData.handler.onEmptyChatEntered()
    else
    {
      onChatSend()
      if (sceneData.handler && ("onChatEntered" in sceneData.handler))
        sceneData.handler.onChatEntered()
    }
    enableChatInput(false)
  }

  function onWrapUp(obj)
  {
    local sceneData = findSceneDataByObj(obj)
    if (sceneData && sceneData.handler && ("onWrapUp" in sceneData.handler))
      sceneData.handler.onWrapUp(obj)
  }

  function onWrapDown(obj)
  {
    local sceneData = findSceneDataByObj(obj)
    if (sceneData && sceneData.handler && ("onWrapDown" in sceneData.handler))
      sceneData.handler.onWrapDown(obj)
  }

  function onChatCancel(obj)
  {
    local sceneData = findSceneDataByObj(obj)
    if (sceneData && sceneData.handler && ("onChatCancel" in sceneData.handler))
      sceneData.handler.onChatCancel()
    enableChatInput(false)
  }

  function checkAndPrintDevoiceMsg()
  {
    local devoice = ::get_chat_devoice_msg()
    if (devoice)
    {
      devoice = "<color=@chatInfoColor>" + devoice + "</color>"
      addLogMessage(devoice)
      onInputChanged("")
    }
    return devoice != null
  }

  function onChatSend()
  {
    if (checkAndPrintDevoiceMsg())
      return
    ::chat_on_send()
  }

  function onEventPlayerPenaltyStatusChanged(params)
  {
    checkAndPrintDevoiceMsg()
  }

  function onChatChanged(obj)
  {
    ::chat_on_text_update(obj.getValue())
  }

  function onChatClear()
  {
    log = []
    log_text = ""
    updateAllLogs()
  }

  function onInputChanged(str)
  {
    doForAllScenes((@(str) function(sceneData) {
        local edit = sceneData.scene.findObject("chat_input")
        if (edit)
          edit.setValue(str)
      })(str))
  }

  function onChatTabChange(obj)
  {
    local sceneData = findSceneDataByObj(obj)
    if (sceneData)
    {
      sceneData.curTab = obj.getValue()
      updateContent(sceneData)
      updateChatInput(sceneData)
    }
  }

  function onEventMpChatInputRequested(params)
  {
    local activate = ::getTblValue("activate", params, false)
    if (activate && canEnableChatInput())
      foreach(sceneData in scenes)
        if (getCurView(sceneData) != mpChatView.CHAT)
          if (!sceneData.hiddenInput && ::checkObj(sceneData.scene) && sceneData.scene.isVisible())
          {
            local obj = sceneData.scene.findObject("chat_tabs")
            if (::checkObj(obj))
            {
              obj.setValue(mpChatView.CHAT)
              break
            }
          }
  }

  function onEventBattleLogMessage(params)
  {
    doForAllScenes(updateBattleLog)
  }

  function updateContent(sceneData)
  {
    updateChatLog(sceneData)
    updateBattleLog(sceneData)
  }

  function updateBattleLog(sceneData)
  {
    if (getCurView(sceneData) != mpChatView.BATTLE)
      return
    local limit = (isMouseCursorVisible || !sceneData.selfHideLog) ? 0 : maxLogSize
    local chat_log = sceneData.scene.findObject("chat_log")
    if (::checkObj(chat_log))
      chat_log.setValue(::HudBattleLog.getText(0, limit))
  }

  function updatePrompt(sceneData)
  {
    local scene = sceneData.scene
    local prompt = scene.findObject("chat_prompt")
    if (prompt)
    {
      prompt.chatMode = curMode.name
      if (::getTblValue("no_text", prompt, "no") != "yes")
        prompt.setValue(curMode.getNameText())
      if ("tooltip" in prompt)
        prompt.tooltip = ::loc("chat/to") + ::loc("ui/colon") + curMode.getDescText()
    }

    local input = scene.findObject("chat_input")
    if (input)
      input.chatMode = curMode.name

    local hint = scene.findObject("chat_hint")
    if (hint)
      hint.setValue(::get_gamepad_specific_localization(::g_squad_manager.isInSquad() ? "chat/help/squad" : "chat/help/short"))
  }

  function onModeChanged(modeId, playerName)
  {
    local newMode = ::g_mp_chat_mode.getModeById(modeId)
    if (newMode == curMode)
      return

    curMode = newMode
    doForAllScenes(updatePrompt)
  }

  function onChatMode()
  {
    local modeToSet = null
    local isCurFound = false

    foreach(mode in ::g_mp_chat_mode.types)
    {
      if (mode == curMode)
      {
        isCurFound = true
        continue
      }

      if (!mode.isEnabled())
        continue

      if (isCurFound)
      {
        modeToSet = mode
        break
      } else if (!modeToSet)
        modeToSet = mode
    }

    if (modeToSet)
      setMode(modeToSet)
  }

  function setMode(mpChatMode)
  {
    ::chat_set_mode(mpChatMode.id, "")
  }

  function validateCurMode()
  {
    if (curMode.isEnabled())
      return

    foreach(mode in ::g_mp_chat_mode.types)
      if (mode.isEnabled())
        setMode(mode)
  }

  function showPlayerRClickMenu(user)
  {
    local isMe = user == ::my_user_name
    local isModerator = ::is_myself_moderator() || ::is_myself_chat_moderator()
    local curLogText = getLogText()
    local menu = [
      {
        text = ::loc("contacts/message")
        show = !isMe
        action = (@(user) function() {
          ::broadcastEvent("MpChatInputRequested", { activate = true })
          ::chat_set_mode(::CHAT_MODE_PRIVATE, user)
          })(user)
      }
      {
        text = ::loc("mainmenu/btnUserCard")
        action = (@(user) function() { ::gui_modal_userCard({ name = user }) })(user)
      }
      {
        text = ::loc("mainmenu/btnComplain")
        show = !isMe
        action = (@(user, curLogText) function() {
          ::gui_modal_complain({ name = user }, curLogText)
        })(user, curLogText)
      }
      {
        text = ::loc("contacts/moderator_copyname")
        show = isModerator
        action = (@(user) function() { ::copy_to_clipboard(user) })(user)
      }
      {
        text = ::loc("contacts/moderator_ban")
        show = ::myself_can_devoice() || ::myself_can_ban()
        action = (@(user, curLogText) function() {
          ::gui_modal_ban({ name = user }, curLogText? curLogText : "")
        })(user, curLogText)
      }
    ]

    ::gui_right_click_menu(menu, this)
  }

  function onChatLinkClick(obj, itype, link)  { onChatLink(obj, link, ::is_platform_pc) }
  function onChatLinkRClick(obj, itype, link) { onChatLink(obj, link, false) }

  function onChatLink(obj, link, lclick)
  {
    if (link && link.len()<4) return

    if(link.slice(0, 3) == "PL_")
    {
      if (lclick)
      {
        local sceneData = findSceneDataByObj(obj)
        if (sceneData)
          addNickToEdit(sceneData, link.slice(3))
      } else
        showPlayerRClickMenu(link.slice(3))
    } else
      if (::checkBlockedLink(link))
      {
        log_text = ::revertBlockedMsg(log_text, link)

        foreach(i, text in log)
          if (text.find(link))
          {
            log[i] = ::revertBlockedMsg(log[i], link)
            break
          }
        updateAllLogs()
      }
  }

  function onInternalMessage(str)
  {
    addLogMessage(str)
  }

  function onIncomingMessage(sender, msg, enemy, mode, automatic)
  {
    if(!::ps4_is_chat_enabled() && !automatic)
      return false

    local myself = sender==::my_user_name;
    local senderColor = senderColor

    if (myself)
      senderColor = senderMeColor
    else if (::isPlayerDedicatedSpectator(sender))
      senderColor = senderSpectatorColor
    else if (enemy || !::is_mode_with_teams())
      senderColor = senderEnemyColor
    else if (::g_squad_manager.isInMySquad(sender))
      senderColor = senderMySquadColor

    local text;
    if (sender == "") //system
    {
      if ( msg.len() > 5 && msg.slice(0,5) == "chat/" )
        msg = ::loc( msg );
      text = "<color=@chatActiveInfoColor>" + msg + "</color>"
    }
    else
    {
      local msgChatMode = ::g_mp_chat_mode.getModeById(mode)

      local clanTag = ""
      if(!(sender in ::clanUserTable))
        ::add_tags_for_mp_players()
      if(sender in ::clanUserTable)
        clanTag = ::clanUserTable[sender] + " "
      local fullName = clanTag + sender

      msg = ::getFilteredChatMessage(msg, myself)
      local msgColor = msgChatMode.textColor
      if(automatic)
      {
        if (::g_squad_manager.isInMySquad(sender))
          msgColor = voiceSquadColor
        else if (enemy)
          msgColor = voiceEnemyColor
        else
          msgColor = voiceTeamColor
      }

      if (::isPlayerNickInContacts(sender, ::EPL_BLOCKLIST))
      {
        msg = ::makeBlockedMsg(msg)
        msgColor = blockedColor
        senderColor = blockedColor
      }
      text = format("<Color=%s>[%s] <Link=PL_%s>%s:</Link></Color> <Color=%s>%s</Color>",
                        senderColor, msgChatMode.getNameText(),
                        sender, fullName, msgColor, msg)
    }
    addLogMessage(text)

    local autoShowOpt = ::get_option(::USEROPT_AUTO_SHOW_CHAT)
    if (autoShowOpt.value)
      doForAllScenes(function(sceneData) {
        if (!sceneData.scene.isVisible())
          return

        sceneData.transparency = 1.0
        updateChatScene(sceneData, 0.0)
      })

    return true
  }

  function addLogMessage(msg)
  {
    //dagor.debug("gui: " + msg)
    if (log.len() > maxLogSize)
      log.remove(0)
    log.append(msg)

    log_text = log[0]
    for (local i = 1; i < log.len(); ++i)
      log_text = log_text + "\n" + log[i]

    //dagor.debug("log: " + log_text)
    updateAllLogs()
    ::broadcastEvent("MpChatLogUpdated")
  }

  function clearLog()
  {
    dagor.debug("log cleared")
    log.clear()
    updateAllLogs()
  }

  function updateAllLogs()
  {
    doForAllScenes(updateChatLog)
  }

  function updateChatLog(sceneData)
  {
    if (getCurView(sceneData) != mpChatView.CHAT)
      return
    local chat_log = sceneData.scene.findObject("chat_log")
    if (chat_log)
      chat_log.setValue(log_text)
  }

  function getLogText()
  {
    return log_text
  }

  function addNickToEdit(sceneData, user)
  {
    ::broadcastEvent("MpChatInputRequested", { activate = true })

    local inputObj = sceneData.scene.findObject("chat_input")
    if (!inputObj) return

    ::add_text_to_editbox(inputObj, user + " ")
    inputObj.select()
  }

  function getCurView(sceneData)
  {
    return (isMouseCursorVisible || !sceneData.selfHideLog) ? sceneData.curTab : mpChatView.CHAT
  }

  function updateTabs(sceneData)
  {
    local visible = isMouseCursorVisible || !sceneData.selfHideLog

    local obj = sceneData.scene.findObject("chat_tabs")
    if (::checkObj(obj))
    {
      if (obj.getValue() == -1)
        obj.setValue(sceneData.curTab)
      obj.show(visible)
    }
    local obj = sceneData.scene.findObject("chat_log_tdiv")
    if (::checkObj(obj))
    {
      obj.height = visible ? obj["max-height"] : null
      obj.scrollType = visible ? "" : "hidden"
    }
  }

  function getControlsAllowMask()
  {
    return isActive ? CtrlsInGui.CTRL_ALLOW_MP_CHAT | CtrlsInGui.CTRL_ALLOW_VEHICLE_MOUSE : CtrlsInGui.CTRL_ALLOW_FULL
  }
}

function is_chat_screen_allowed()
{
  return ::is_hud_visible() && !::is_menu_state()
}

function set_game_chat_scene(scene = null, handler = null, selfHideInput = false, hiddenInput = false, selfHideLog = false)
{
  return ::get_game_chat_handler().addScene(scene, handler, selfHideInput, hiddenInput, selfHideLog)
}

function loadGameChatToObj(obj, chatBlk, handler, selfHideInput = false, hiddenInput = false, selfHideLog = false)
{
  return ::get_game_chat_handler().loadScene(obj, chatBlk, handler, selfHideInput, hiddenInput, selfHideLog)
}

function detachGameChatSceneData(sceneData)
{
  sceneData.scene = null
  ::get_game_chat_handler().cleanScenesList()
}

function is_chat_active() // called from client
{
  return ::get_game_chat_handler().isActive
}

function game_chat_input_toggle_request(toggle)
{
  ::toggle_ingame_chat(toggle)
}

function enable_game_chat_input(value) // called from client
{
  if (value)
    ::broadcastEvent("MpChatInputRequested")

  local handler = ::get_game_chat_handler()
  if (!value || handler.canEnableChatInput())
    handler.enableChatInput(value)
}

function hide_game_chat_scene_input(sceneData, value)
{
  ::get_game_chat_handler().hideChatInput(sceneData, value)
}

function clear_game_chat()
{
  if (::game_chat_handler)
    ::game_chat_handler.onChatClear()
}

function get_gamechat_log_text()
{
  return ::get_game_chat_handler().getLogText()
}

function get_chat_devoice_msg(activeColor = "chatActiveInfoColor")
{
  local st = ::get_player_penalty_status()
  //st = { status = ::EPS_DEVOICE, duration = 360091, category="FOUL", comment="test ban", seconds_left=2012}
  if (st.status != ::EPS_DEVOICE)
    return null


//  local penalist = get_player_penalty_list();
//  [
//    {...},
//    { "penalty" :  one of "DEVOICE", "BAN", "SILENT_DEVOICE", "DECALS_DISABLE", "WARN"
//      "category" :  one of "FOUL", "ABUSE", "CHEAT", "BOT", "SPAM", "TEAMKILL", "OTHER", "FINGERPRINT", "INGAME"
//      "start": unixtime, when was imputed
//      "duration": seconds, how long it shoud lasts in total
//      "seconds_left": seconds, how long it will lasts from now, updated on each request
//      "comment": text, what to tell user, why he got his penalty
//      },
//    {...}
//  ]
//  Many penalties can be active (seconds_left > 0) at the same time, even of the same type.
//  New interface should be able to show all of them
//  (but only certain types, i.e. "SILENT_DEVOICE" shouldn't be shown to user')


  local txt = ""
  if (st.duration >= ::BANUSER_INFINITE_PENALTY)
    txt += ::loc("charServer/mute/permanent")+"\n"
  else
  {
    local timeText = ::colorize(activeColor, ::hoursToString(st.duration.tofloat()/TIME_HOUR_IN_SECONDS, false))
    txt += format(::loc("charServer/mute/timed"), timeText)

    if (("seconds_left" in st) && st.seconds_left>0)
    {
      timeText = ::colorize(activeColor, ::hoursToString(st.seconds_left.tofloat()/TIME_HOUR_IN_SECONDS, false, true))
      if (timeText != "")
        txt += " " + format(::loc("charServer/ban/timeLeft"), timeText)
    } else
      if (::isInMenu())
        ::update_entitlements_limited()

    if (txt != "")
      txt += "\n"
  }

  txt += ::loc("charServer/ban/reason") + ::loc("ui/colon")+" "
           + ::colorize(activeColor, ::loc("charServer/ban/reason/"+st.category)) + "\n"
  txt += ::loc("charServer/ban/comment") + "\n"+st.comment
  return txt
}

function add_text_to_editbox(obj, text)
{
  local value = obj.getValue()
  local pos = obj.getIntProp(::dagui_propid.get_name_id(":behaviour_edit_position_pos"), -1)
  if (pos > 0 && pos < value.len())
    obj.setValue(value.slice(0, pos) + text + value.slice(pos))
  else
    obj.setValue(value + text)
}

function chat_system_message(text)
{
  ::get_game_chat_handler().onIncomingMessage("", text, false, 0, true)
}

function add_tags_for_mp_players()
{
  local tbl = ::get_mplayers_list(::GET_MPLAYERS_LIST, true)
  if (tbl)
  {
    foreach(block in tbl)
      if(!block.isBot)
        ::clanUserTable[block.name] <- ::getTblValue("clanTag", block, "")
  }
}
