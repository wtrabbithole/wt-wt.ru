local elemModelType = ::require("sqDagui/elemUpdater/elemModelType.nut")
local elemViewType = ::require("sqDagui/elemUpdater/elemViewType.nut")

elemModelType.addTypes({
  SQUAD_VOICE_CHAT = {

    init = @() ::subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)

    onEventVoiceChatStatusUpdated = @(p) notify([])
    onEventSquadStatusChanged = @(p) notify([])
  }
})


elemViewType.addTypes({
  SQUAD_VOICE_CHAT = {
    model = elemModelType.SQUAD_VOICE_CHAT

    updateView = function(obj, params)
    {
      if (!::g_login.isLoggedIn())
        return
      if (!obj.childrenCount())
      {
        if (isAnybodyTalk())
          obj.getScene().performDelayed(this, function() {
            if (!obj.isValid())
              return

            fillContainer(obj)
            updateMembersView(obj)
          })
      }
      else
        updateMembersView(obj)
    }

    isAnybodyTalk = function()
    {
      foreach (uid, member in ::g_squad_manager.getMembers())
        if (::getContact(uid)?.voiceStatus == voiceChatStats.talking)
          return true

      return false
    }

    updateMembersView = function(obj)
    {
      local memberIndex = 1
      if (::g_squad_manager.isInSquad())
      {
        local leader = ::g_squad_manager.getSquadLeaderData()
        foreach (uid, member in ::g_squad_manager.getMembers())
          updateMemberView(obj, member == leader ? 0 : memberIndex++, uid)
      }

      while (memberIndex < ::g_squad_manager.MAX_SQUAD_SIZE)
        updateMemberView(obj, memberIndex++, null)
    }

    updateMemberView = function(obj, objIndex, uid)
    {
      local memberObj = objIndex < obj.childrenCount() ? obj.getChild(objIndex) : null
      if (!::check_obj(memberObj))
        return

      local contact = ::getContact(uid)
      local isTalking = contact?.voiceStatus == voiceChatStats.talking
      memberObj.fade = isTalking ? "in" : "out"
      if (isTalking)
        memberObj.findObject("users_name").setValue(contact?.name ?? "")
    }

    fillContainer = function(obj)
    {
      local data = ::handyman.renderCached("gui/chat/voiceChatElement",
        { voiceChatElement = ::array(::g_squad_manager.MAX_SQUAD_SIZE, {}) })
      obj.getScene().replaceContentFromText(obj, data, data.len(), this)
    }
  }
})

return {}
