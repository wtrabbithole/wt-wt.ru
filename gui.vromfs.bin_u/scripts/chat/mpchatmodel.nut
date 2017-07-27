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
    }

    if (mpChatState.log.len() > maxLogSize) {
      mpChatState.log.remove(0)
    }
    mpChatState.log.append(message)

    ::broadcastEvent("MpChatLogUpdated")
    return true
  }


  clearLog = function() {
    mpChatState.log = []
    ::broadcastEvent("MpChatLogUpdated")
  }


  function onModeChanged(modeId, playerName) {
    if (mpChatState.currentModeId == modeId)
      return

    mpChatState.currentModeId = modeId
    ::broadcastEvent("MpChatModeChanged", { modeId = mpChatState.currentModeId})
  }


  function onInputChanged(str) {
    ::broadcastEvent("MpChatInputChanged", {str = str})
  }


  function onChatClear() {
    clearLog()
  }


  function unblockMessage(text) {
    foreach (message in log) {
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
