local mpChatState = {
  log = []
  currentModeId = null
  PERSISTENT_DATA_PARAMS = ["log"]
}


local mpChatModel = {
  maxLogSize = 20


  function init()
  {
    ::set_chat_handler(this)
    maxLogSize = ::g_chat.getMaxRoomMsgAmount()
  }


  function getLog() {
    return mpChatState.log
  }


  function onInternalMessage(str) {
    onIncomingMessage("", str, false, ::CHAT_MODE_ALL, true)
  }


  function onIncomingMessage(sender, msg, enemy, mode, automatic) {
    if(!::ps4_is_chat_enabled() && !automatic) {
      return false
    }

    local message = {
      sender = sender
      text = msg
      isMyself = sender == ::my_user_name
      isEnemy = enemy
      isBlocked = ::isPlayerNickInContacts(sender, ::EPL_BLOCKLIST)
      isAutomatic = automatic
      mode = mode
      time = ::get_usefull_total_time()
    }

    if (mpChatState.log.len() > maxLogSize) {
      mpChatState.log.remove(0)
    }
    mpChatState.log.append(message)

    ::broadcastEvent("MpChatLogUpdated")
    ::push_message(message)
    return true
  }


  clearLog = function() {
    onChatClear()
    ::broadcastEvent("MpChatLogUpdated")
  }


  function onModeChanged(modeId, playerName) {
    if (mpChatState.currentModeId == modeId)
      return

    mpChatState.currentModeId = modeId
    ::push_new_mode_type(modeId)
    ::broadcastEvent("MpChatModeChanged", { modeId = mpChatState.currentModeId})
  }


  function onInputChanged(str) {
    ::push_new_input_string(str)
    ::broadcastEvent("MpChatInputChanged", {str = str})
  }


  function onChatClear() {
    mpChatState.log.clear()
    ::clear_chat_log()
  }


  function unblockMessage(text) {
    foreach (message in mpChatState.log) {
      if (message.text == text) {
        message.isBlocked = false
        return
      }
    }
  }
}


::g_script_reloader.registerPersistentData(
  "mpChatState",
  mpChatState,
  ["log", "currentModeId"]
)


return mpChatModel
