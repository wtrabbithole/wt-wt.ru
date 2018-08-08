local platformModule = require("scripts/clientState/platform.nut")

local mpChatState = {
  log = []
  currentModeId = null
  PERSISTENT_DATA_PARAMS = ["log"]
}


local mpChatModel = {
  maxLogSize = 20


  function init() {
    maxLogSize = ::g_chat.getMaxRoomMsgAmount()
  }


  function getLog() {
    return mpChatState.log
  }


  function onInternalMessage(str) {
    onIncomingMessage("", str, false, ::CHAT_MODE_ALL, true)
  }


  function onIncomingMessage(sender, msg, enemy, mode, automatic) {
    if ( (!platformModule.isChatEnabled()
         || !::g_chat.isCrossNetworkMessageAllowed(sender))
        && !automatic) {
      return false
    }

    local player = u.search(::get_mplayers_list(::GET_MPLAYERS_LIST, true), @(p) p.name == sender)

    local message = {
      sender = sender
      text = msg
      isMyself = sender == ::my_user_name
      isBlocked = ::isPlayerNickInContacts(sender, ::EPL_BLOCKLIST)
      isAutomatic = automatic
      mode = mode
      time = ::get_usefull_total_time()

      team = player ? player.team:0
    }

    if (mpChatState.log.len() > maxLogSize) {
      mpChatState.log.remove(0)
    }
    mpChatState.log.append(message)

    ::broadcastEvent("MpChatLogUpdated")
    ::call_darg("mpChatPushMessage", message)
    return true
  }


  function clearLog() {
    onChatClear()
    ::broadcastEvent("MpChatLogUpdated")
  }


  function onModeChanged(modeId, playerName) {
    if (mpChatState.currentModeId == modeId)
      return

    mpChatState.currentModeId = modeId
    ::call_darg("mpChatModeChange", modeId)
    ::broadcastEvent("MpChatModeChanged", { modeId = mpChatState.currentModeId})
  }


  function onInputChanged(str) {
    ::call_darg("mpChatInputChanged", str)
    ::broadcastEvent("MpChatInputChanged", {str = str})
  }


  function onChatClear() {
    mpChatState.log.clear()
    ::call_darg("mpChatClear")
  }


  function unblockMessage(text) {
    foreach (message in mpChatState.log) {
      if (message.text == text) {
        message.isBlocked = false
        return
      }
    }
  }

  function onModeSwitched() {
    local newModeId = ::g_mp_chat_mode.getNextMode(mpChatState.currentModeId)
    if (newModeId == null)
      return

    ::chat_set_mode(newModeId, "")
  }
}


::g_script_reloader.registerPersistentData(
  "mpChatState",
  mpChatState,
  ["log", "currentModeId"]
)

::set_chat_handler(mpChatModel)
return mpChatModel
