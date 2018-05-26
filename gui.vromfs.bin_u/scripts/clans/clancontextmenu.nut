local playerContextMenu = ::require("scripts/user/playerContextMenu.nut")

local getClanActions = function(clanId)
{
  if (!::has_feature("Clans"))
    return []

  local myClanId = ::clan_get_my_clan_id()

  return [
    {
      text = ::loc("clan/btn_membership_req")
      show = myClanId == "-1" && ::clan_get_requested_clan_id() != clanId
      action = @() ::g_clans.requestMembership(clanId)
    }
    {
      text = ::loc("clan/clanInfo")
      show = clanId != "-1"
      action = @() ::showClanPage(clanId, "", "")
    }
    {
      text = ::loc("mainmenu/btnComplain")
      show = myClanId != clanId
      action = @() ::g_clans.requestOpenComplainWnd(clanId)
    }
  ]
}

local getRequestActions = function(clanId, playerUid, playerName = "", handler = null)
{
  if (!playerUid)
    return []

  local myClanRights = ::g_clans.getMyClanRights()
  local isClanAdmin = ::clan_get_admin_editor_mode()

  local isBlock = ::isPlayerInContacts(playerUid, ::EPL_BLOCKLIST)
  local contact = ::getContact(playerUid, playerName)
  local name = contact?.name ?? playerName
  local canInteract = ::g_chat.xboxIsChatAvailableForFriend(name) && (!contact || contact.canInteract())

  return [
    {
      text = ::loc("contacts/message")
      isVisualDisabled = !canInteract || isBlock
      show = playerUid != ::my_user_id_str
             && ::ps4_is_chat_enabled()
             && !u.isEmpty(name)
             && ::has_feature("Chat")
      action = function()
      {
        if (isBlock)
          return playerContextMenu.showBlockedPlayerPopup(name)

        if (!canInteract)
          return playerContextMenu.showPrivacySettingsRestrictionPopup()

        ::openChatPrivate(name, handler)
      }
    }
    {
      text = ::loc("mainmenu/btnUserCard")
      action = @() ::gui_modal_userCard({uid = playerUid})
    }
    {
      text = ::loc("clan/requestApprove")
      show = ::isInArray("MEMBER_ADDING", myClanRights) || isClanAdmin
      action = @() ::g_clans.approvePlayerRequest(playerUid, clanId)
    }
    {
      text = ::loc("clan/requestReject")
      show = ::isInArray("MEMBER_REJECT", myClanRights) || isClanAdmin
      action = @() ::g_clans.rejectPlayerRequest(playerUid)
    }
    {
      text = ::loc("clan/blacklistAdd")
      show = ::isInArray("MEMBER_BLACKLIST", myClanRights)
      action = @() ::g_clans.blacklistAction(playerUid, true)
    }
  ]
}

return {
  getClanActions = getClanActions
  getRequestActions = getRequestActions
}