local time = require("scripts/time.nut")
local ingame_chat = require("scripts/chat/mpChatModel.nut")
local penalties = require("scripts/penitentiary/penalties.nut")
local platformModule = require("scripts/clientState/platform.nut")
local playerContextMenu = ::require("scripts/user/playerContextMenu.nut")

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
  chatInputText = ""

  function constructor()
  {
    ::g_script_reloader.registerPersistentData("mpChat", this,
      ["log_text", "curMode",
       "isActive", "chatInputText"
      ])

    ::subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)
    maxLogSize = ::g_chat.getMaxRoomMsgAmount()
    isMouseCursorVisible = ::is_cursor_visible_in_gui()
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
    local sceneFocusObjArray = [
    "chat_prompt_place",
    "chat_input",
    "chat_log",
    "chat_tabs"
    ]

    local scene = sceneData.scene

    foreach (objName in sceneFocusObjArray)
    {
      local obj = scene.findObject(objName)
      if (obj)
        obj.setIntProp(sceneIdxPID, sceneData.idx)
    }

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
    if (!platformModule.isChatEnabled())
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

    local show = (isActive || !sceneData.selfHideInput)
                 && !sceneData.hiddenInput
                 && platformModule.isChatEnabled()
                 && getCurView(sceneData) == mpChatView.CHAT
    local scene = sceneData.scene

    ::showBtnTable(scene, {
        chat_input_back         = show
        chat_input_placeholder  = !show && canEnableChatInput()
    })
    ::enableBtnTable(scene, {
        chat_input              = show
        btn_send                = show
        chat_mod_accesskey      = show && (sceneData.handler?.isSpectate || !::is_hud_visible)
    })
    if (show && sceneData.scene.isVisible())
    {
      local obj = scene.findObject("chat_input")
      if (::checkObj(obj))
      {
        obj.select()
        obj.setValue(chatInputText)
      }
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
    local devoiceMsgText = penalties.getDevoiceMessage()
    if (devoiceMsgText)
    {
      devoiceMsgText = "<color=@chatInfoColor>" + devoiceMsgText + "</color>"
      ingame_chat.onInternalMessage(devoiceMsgText)
      setInputField("")
    }
    return devoiceMsgText != null
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
    chatInputText = obj.getValue()
    ::chat_on_text_update(chatInputText)
  }

  function onEventMpChatInputChanged(params)
  {
    setInputField(params.str)
  }


  function setInputField(str)
  {
    doForAllScenes(function(sceneData) {
      local edit = sceneData.scene.findObject("chat_input")
      if (edit)
        edit.setValue(str)
    })
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
      hint.setValue(getChatHint())
  }

  function getChatHint()
  {
    local hasIME = ::is_ps4_or_xbox || ::is_platform_android || ::is_steam_big_picture()
    return ::loc("chat/help/modeSwitch",
        { modeSwitchShortcuts = "{{ID_TOGGLE_CHAT_MODE}}"
          modeList = ::g_mp_chat_mode.getTextAvailableMode()
        })
      + (hasIME ? ""
        : ::loc("ui/comma")
          + ::loc("chat/help/send", { sendShortcuts = "{{INPUT_BUTTON KEY_ENTER}}" }))
  }

  function onEventMpChatModeChanged(params)
  {
    local newMode = ::g_mp_chat_mode.getModeById(params.modeId)
    if (newMode == curMode)
      return

    curMode = newMode
    doForAllScenes(updatePrompt)
  }

  function onChatMode()
  {
    local newModeId = ::g_mp_chat_mode.getNextMode(curMode.id)
    setMode(::g_mp_chat_mode.getModeById(newModeId))
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

  function showPlayerRClickMenu(playerName)
  {
    playerContextMenu.showMenu(null, this, {
      playerName = playerName
      isMPChat = true
      chatLog = getLogText()
      canComplain = true
    })
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
      }
      else
        showPlayerRClickMenu(link.slice(3))
    }
    else if (::g_chat.checkBlockedLink(link))
    {
      log_text = ::g_chat.revertBlockedMsg(log_text, link)

      local pureMessage = ::stringReplace(link.slice(6), " ", " ")
      ingame_chat.unblockMessage(pureMessage)
      updateAllLogs()
    }
  }


  function onEventMpChatLogUpdated(params)
  {
    local log = ingame_chat.getLog()
    log_text = ""
    for (local i = 0; i < log.len(); ++i)
      log_text = ::g_string.implode([log_text , makeTextFromMessage(log[i])], "\n")
    updateAllLogs()

    local autoShowOpt = ::get_option(::USEROPT_AUTO_SHOW_CHAT)
    if (autoShowOpt.value)
    {
      doForAllScenes(function(sceneData) {
        if (!sceneData.scene.isVisible())
          return

        sceneData.transparency = 1.0
        updateChatScene(sceneData, 0.0)
      })
    }

    return true
  }


  function makeTextFromMessage(message)
  {
    local timeString = time.secondsToString(message.time, false)
    if (message.sender == "") //system
      return ::format(
        "%s <color=@chatActiveInfoColor>%s</color>",
        timeString,
        ::loc(message.text))

    local text = ::g_chat.filterMessageText(message.text, message.isMyself)
    if (!message.isMyself)
    {
      if (::isPlayerNickInContacts(message.sender, ::EPL_BLOCKLIST))
        text = ::g_chat.makeBlockedMsg(message.text)
      else if (!platformModule.isChatEnableWithPlayer(message.sender))
        text = ::g_chat.makeXBoxRestrictedMsg(message.text)
    }

    local senderColor = getSenderColor(message)
    local msgColor = getMessageColor(message)
    local fullName = ::g_contacts.getPlayerFullName(
      platformModule.getPlayerName(message.sender),
      ::get_player_tag(message.sender)
    )

    return ::format(
      "%s <Color=%s>[%s] <Link=PL_%s>%s:</Link></Color> <Color=%s>%s</Color>",
      timeString
      senderColor,
      ::g_mp_chat_mode.getModeById(message.mode).getNameText(),
      message.sender,
      fullName,
      msgColor,
      text
    )
  }


  function getSenderColor(message)
  {
    if (message.isMyself)
      return senderMeColor
    else if (::isPlayerDedicatedSpectator(message.sender))
      return senderSpectatorColor
    else if (message.isEnemy || !::is_mode_with_teams())
      return senderEnemyColor
    else if (::g_squad_manager.isInMySquad(message.sender))
      return senderMySquadColor
    return senderColor
  }


  function getMessageColor(message)
  {
    if (message.isBlocked)
      return blockedColor
    else if (message.isAutomatic)
    {
      if (::g_squad_manager.isInMySquad(message.sender))
        return voiceSquadColor
      else if (message.isEnemy)
        return voiceEnemyColor
      else
        return voiceTeamColor
    }
    return ::g_mp_chat_mode.getModeById(message.mode).textColor
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
    return isActive
      ? CtrlsInGui.CTRL_IN_MP_CHAT | CtrlsInGui.CTRL_ALLOW_VEHICLE_MOUSE | CtrlsInGui.CTRL_ALLOW_MP_CHAT
      : CtrlsInGui.CTRL_ALLOW_FULL
  }

  function onEventLoadingStateChange(params)
  {
    clearInputChat()
  }

  function clearInputChat()
  {
    chatInputText = ""
    ::chat_on_text_update(chatInputText)
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
  debugTableData(ingame_chat)
  ingame_chat.clearLog()
}

function get_gamechat_log_text()
{
  return ::get_game_chat_handler().getLogText()
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
  ingame_chat.onIncomingMessage("", text, false, 0, true)
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


function get_player_tag(playerNick)
{
  if(!(playerNick in ::clanUserTable))
    ::add_tags_for_mp_players()
  return ::getTblValue(playerNick, ::clanUserTable, "")
}
