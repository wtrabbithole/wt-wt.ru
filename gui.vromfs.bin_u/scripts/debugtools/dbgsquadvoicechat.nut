::g_squad_voice_chat <- {
  isChatOn = false
  avgEventPerSec = 10
  lastStepTime = 0
}

function g_squad_voice_chat::start(newAvgEventPerSec = 10)
{
  isChatOn = !isChatOn
  avgEventPerSec = newAvgEventPerSec

  runVoiceChatStep()
}

function g_squad_voice_chat::stop()
{
  foreach (uid, member in ::g_squad_manager.getMembers())
    imitateUserSpeaking(uid, false)

  isChatOn = false
}

function g_squad_voice_chat::runVoiceChatStep()
{
  if (!::g_squad_manager.isInSquad())
    return stop()

  if (!isChatOn)
    return stop()

  ::handlersManager.doDelayed(function() {
    if (!isChatOn)
      return

    immitateVoiceChat()
    runVoiceChatStep()
  }.bindenv(this))
}

function g_squad_voice_chat::immitateVoiceChat()
{
  local curStepTime = ::dagor.getCurTime()
  local dt = curStepTime - lastStepTime
  lastStepTime = curStepTime

  if (::math.frnd() * 1000 > dt * avgEventPerSec)
    return

  local members = ::g_squad_manager.getOnlineMembers()
  if (members.len() <= 1)
    return

  imitateUserSpeaking(::u.chooseRandom(members).uid, ::u.chooseRandom([true, false]))
}

function g_squad_voice_chat::imitateUserSpeaking(uid, isSpeaking)
{
  menuChatCb(::GCHAT_EVENT_VOICE, null, { uid = uid, type = "update", is_speaking = isSpeaking })
}
