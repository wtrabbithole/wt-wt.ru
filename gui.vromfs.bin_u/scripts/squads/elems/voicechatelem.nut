local elemModelType = ::require("sqDagui/elemUpdater/elemModelType.nut")
local elemViewType = ::require("sqDagui/elemUpdater/elemViewType.nut")

elemModelType.addTypes({
  VOICE_CHAT = {

    init = @() ::subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)

    onEventVoiceChatStatusUpdated = @(p) notify([])
    onEventSquadStatusChanged = @(p) notify([])
  }
})


elemViewType.addTypes({
  VOICE_CHAT = {
    model = elemModelType.VOICE_CHAT

    updateView = function(obj, params)
    {
      if (!::g_login.isLoggedIn())
        return

      local childRequired = ::g_squad_manager.isInSquad() ? ::g_squad_manager.MAX_SQUAD_SIZE
        : ::my_clan_info ? ::my_clan_info.mlimit
        : 0
      if (obj.childrenCount() < childRequired)
      {
        if (isAnybodyTalk())
          obj.getScene().performDelayed(this, function() {
            if (!obj.isValid())
              return

            fillContainer(obj, childRequired)
            updateMembersView(obj)
          })
      }
      else
        updateMembersView(obj)
    }

    isAnybodyTalk = function()
    {
      if (::g_squad_manager.isInSquad())
      {
        foreach (uid, member in ::g_squad_manager.getMembers())
          if (::getContact(uid)?.voiceStatus == voiceChatStats.talking)
            return true
      }
      else if (::my_clan_info)
        foreach (member in ::my_clan_info.members)
          if (::getContact(member.uid)?.voiceStatus == voiceChatStats.talking)
            return true

      return false
    }

    updateMembersView = function(obj)
    {
      local memberIndex = 0
      if (::g_squad_manager.isInSquad())
      {
        memberIndex = 1
        local leader = ::g_squad_manager.getSquadLeaderData()
        foreach (uid, member in ::g_squad_manager.getMembers())
          updateMemberView(obj, member == leader ? 0 : memberIndex++, uid)
      }
      else if (::my_clan_info)
        foreach (member in ::my_clan_info.members)
          updateMemberView(obj, memberIndex++, member.uid)

      while (memberIndex < obj.childrenCount())
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

    fillContainer = function(obj, childRequired)
    {
      local data = ::handyman.renderCached("gui/chat/voiceChatElement",
        { voiceChatElement = ::array(childRequired, {}) })
      obj.getScene().replaceContentFromText(obj, data, data.len(), this)
    }
  }
})

return {}
