local u = ::require("std/u.nut")
local platformModule = ::require("scripts/clientState/platform.nut")
local localDevoice = ::require("scripts/penitentiary/localDevoice.nut")
local crossplayModule = require("scripts/social/crossplay.nut")

//-----------------------------
// params keys:
//  - uid
//  - playerName
//  - clanTag
//  - roomId
//  - isMPChat
//  - canInviteToChatRoom
//  - isMPLobby
//  - clanData
//  - chatLog
//  - squadMemberData
//  - position
//  - canComplain
// ----------------------------

local verifyContact = function(params)
{
  local name = params?.playerName
  local newContact = ::getContact(params?.uid, name, params?.clanTag)
  if (!newContact && name)
    newContact = ::Contact.getByName(name)

  return newContact
}

local getPlayerCardInfoTable = function(uid, name)
{
  local info = {}
  if (uid)
   info.uid <- uid
  if (name)
   info.name <- name

  return info
}

local showNotAvailableActionPopup = @() ::g_popups.add(null, ::loc("xbox/actionNotAvailableDiffPlatform"))
local showPrivacySettingsRestrictionPopup = @() ::g_popups.add(null, ::loc("xbox/actionNotAvailableOnlinePrivacy"))
local showCrossPlayRestrictionPopup = @() ::g_popups.add(null, ::colorize("warningTextColor", ::loc("xbox/crossPlayRequired")))
local showXboxFriendOnlySquadInvitePopup = @() ::g_popups.add(null, ::loc("squad/xbox/friendsOnly"))
local showXboxSquadInviteOnlyOnlinePopup = @() ::g_popups.add(null, ::loc("squad/xbox/onlineOnly"))
local showBlockedPlayerPopup = @(playerName) ::g_popups.add(null, ::loc("chat/player_blocked", {playerName = platformModule.getPlayerName(playerName)}))
local showNoInviteForDiffPlatformPopup = @() ::g_popups.add(null, ::loc("msg/squad/noPlayersForDiffConsoles"))

local getActions = function(contact, params)
{
  local uid = contact?.uid
  local uidInt64 = contact?.uidInt64
  local name = contact?.name ?? params?.playerName
  local clanTag = contact?.clanTag ?? params?.clanTag

  local isMe = uid == ::my_user_id_str
  local isXBoxOnePlayer = platformModule.isXBoxPlayerName(name)
  local canInteract = platformModule.isChatEnableWithPlayer(name)
  local canInteractCrossConsole = platformModule.canInteractCrossConsole(name)
  local canInteractCrossPlatform = isXBoxOnePlayer || crossplayModule.isCrossPlayEnabled()
  local showCrossPlayIcon = canInteractCrossConsole && ::is_platform_xboxone && !isXBoxOnePlayer

  local isFriend = ::isPlayerInFriendsGroup(uid)
  local isBlock = ::isPlayerInContacts(uid, ::EPL_BLOCKLIST)

  local roomId = params?.roomId
  local roomData = roomId? ::g_chat.getRoomById(roomId) : null

  local isMPChat = params?.isMPChat ?? false
  local isMPLobby = params?.isMPLobby ?? false
  local canInviteToChatRoom = params?.canInviteToChatRoom ?? true

  local chatLog = params?.chatLog ?? roomData && roomData.getLogForBanhammer() ?? ""
  local canInviteToSesson = isXBoxOnePlayer == ::is_platform_xboxone

  local actions = []
//---- <Session Join> ---------
  actions.append({
    text = crossplayModule.getTextWithCrossplayIcon(showCrossPlayIcon, ::loc("multiplayer/invite_to_session"))
    show = canInviteToChatRoom && ::SessionLobby.canInvitePlayer(uid) && canInviteToSesson
    isVisualDisabled = !canInteractCrossConsole || !canInteractCrossPlatform
    action = function () {
      if (!canInteractCrossConsole)
        return showNotAvailableActionPopup()
      if (!canInteractCrossPlatform)
        return showCrossPlayRestrictionPopup()

      if (::isPlayerPS4Friend(name))
        ::g_psn_sessions.invite(::SessionLobby.getExternalId(), ::get_psn_account_id(name))
      ::SessionLobby.invitePlayer(uid)
    }
  })

  if (contact && contact.inGameEx && contact.online && ::isInMenu())
  {
    local eventId = contact.gameConfig?.eventId
    local event = ::events.getEvent(eventId)
    if (event && ::events.isEnableFriendsJoin(event))
    {
      actions.append({
        text = crossplayModule.getTextWithCrossplayIcon(showCrossPlayIcon, ::loc("contacts/join_team"))
        show = canInviteToSesson
        isVisualDisabled = !canInteractCrossConsole || !canInteractCrossPlatform
        action = function() {
          if (!canInteractCrossConsole)
            showNotAvailableActionPopup()
          else if (!canInteractCrossPlatform)
            showCrossPlayRestrictionPopup()
          else
            ::queues.joinFriendsQueue(contact.inGameEx, eventId)
        }
      })
    }
  }
//---- </Session Join> ---------

//---- <Common> ----------------
  actions.extend([
    {
      text = ::loc("contacts/message")
      show = !isMe && ::ps4_is_chat_enabled() && ::has_feature("Chat") && !u.isEmpty(name)
      isVisualDisabled = !canInteract || isBlock
      action = function() {
        if (!canInteract)
          return showPrivacySettingsRestrictionPopup()

        if (isBlock)
          return showBlockedPlayerPopup(name)

        if (isMPChat)
        {
          ::broadcastEvent("MpChatInputRequested", { activate = true })
          ::chat_set_mode(::CHAT_MODE_PRIVATE, name)
        }
        else
          ::openChatPrivate(name)
      }
    }
    {
      text = ::loc("mainmenu/btnUserCard")
      show = getPlayerCardInfoTable(uid, name).len() > 0
      action = @() ::gui_modal_userCard(getPlayerCardInfoTable(uid, name))
    }
    {
      text = ::loc("mainmenu/btnClanCard")
      show = ::has_feature("Clans") && !u.isEmpty(clanTag) && clanTag != ::clan_get_my_clan_tag()
      action = @() ::showClanPage("", "", clanTag)
    }
  ])
//---- </Common> ------------------

//---- <Squad> --------------------
  if (::has_feature("Squad"))
  {
    local meLeader = ::g_squad_manager.isSquadLeader()
    local inMySquad = ::g_squad_manager.isInMySquad(name, false)
    local squadMemberData = params?.squadMemberData
    local hasApplicationInMySquad = ::g_squad_manager.hasApplicationInMySquad(uidInt64, name)
    local canInviteDiffConsole = ::g_squad_manager.canInviteMemberByPlatform(name)

    actions.extend([
      {
        text = ::loc("squadAction/openChat")
        show = !isMe && ::g_chat.isSquadRoomJoined() && inMySquad && platformModule.isChatEnabled()
        action = @() ::g_chat.openChatRoom(::g_chat.getMySquadRoomId())
      }
      {
        text = crossplayModule.getTextWithCrossplayIcon(showCrossPlayIcon, hasApplicationInMySquad
            ? ::loc("squad/accept_membership")
            : ::loc("squad/invite_player")
          )
        isVisualDisabled = !canInteract || !canInteractCrossConsole || !canInteractCrossPlatform || !canInviteDiffConsole
        show = ::has_feature("SquadInviteIngame")
               && canInviteToChatRoom
               && !isMe
               && !isBlock
               && ::g_squad_manager.canInviteMember(uid)
               && !::g_squad_manager.isPlayerInvited(uid, name)
               && !squadMemberData?.isApplication
        action = function() {
          if (!canInteractCrossConsole)
            showNotAvailableActionPopup()
          else if (!canInteractCrossPlatform)
            showCrossPlayRestrictionPopup()
          else if (!canInteract)
            showPrivacySettingsRestrictionPopup()
          else if (!canInviteDiffConsole)
            showNoInviteForDiffPlatformPopup()
          else if (hasApplicationInMySquad)
            ::g_squad_manager.acceptMembershipAplication(uidInt64)
          else
            ::g_squad_manager.inviteToSquad(uid, name)
        }
      }
      {
        text = ::loc("squad/revoke_invite")
        show = squadMemberData && meLeader && squadMemberData?.isInvite
        action = @() ::g_squad_manager.revokeSquadInvite(uid)
      }
      {
        text = ::loc("squad/accept_membership")
        show = squadMemberData && meLeader && squadMemberData?.isApplication
        action = @() ::g_squad_manager.acceptMembershipAplication(uidInt64)
      }
      {
        text = ::loc("squad/deny_membership")
        show = squadMemberData && meLeader && squadMemberData?.isApplication
        action = @() ::g_squad_manager.denyMembershipAplication(uidInt64,
          @(response) ::g_squad_manager.removeApplication(uidInt64))
      }
      {
        text = ::loc("squad/remove_player")
        show = ::g_squad_manager.canDismissMember(uid)
        action = @() ::g_squad_manager.dismissFromSquad(uid)
      }
      {
        text = ::loc("squad/tranfer_leadership")
        show = !isMe && ::g_squad_manager.canTransferLeadership(uid)
        action = @() ::g_squad_manager.transferLeadership(uid)
      }
    ])
  }
//---- </Squad> -------------------

//---- <XBox Specific> ------------
  if (::is_platform_xboxone && uidInt64 != null && isXBoxOnePlayer)
  {
    local isXboxPlayerMuted = ::xbox_is_chat_player_muted(uidInt64)
    actions.append({
      text = isXboxPlayerMuted? ::loc("mainmenu/btnUnmute") : ::loc("mainmenu/btnMute")
      show = !isMe && ::xbox_is_player_in_chat(uidInt64)
      action = @() ::xbox_mute_chat_player(uidInt64, !isXboxPlayerMuted)
    })
  }
//---- </XBox Specific> -----------

//---- <Clan> ---------------------
  local clanData = params?.clanData
  if (::has_feature("Clans") && clanData)
  {
    local clanId = clanData?.id ?? "-1"
    local myClanId = ::clan_get_my_clan_id()
    local isMyClan = myClanId != "-1" && clanId == myClanId

    local myClanRights = isMyClan? ::g_clans.getMyClanRights() : []
    local isMyRankHigher = ::g_clans.getClanMemberRank(clanData, name) < ::clan_get_role_rank(::clan_get_my_role())
    local isClanAdmin = ::clan_get_admin_editor_mode()

    actions.extend([
      {
        text = ::loc("clan/activity")
        show = ::has_feature("ClanActivity")
        action = @() ::gui_start_clan_activity_wnd(name, clanData)
      }
      {
        text = ::loc("clan/btnChangeRole")
        show = (isMyClan
                && ::isInArray("MEMBER_ROLE_CHANGE", myClanRights)
                && ::g_clans.haveRankToChangeRoles(clanData)
                && isMyRankHigher
               )
               || isClanAdmin
        action = @() ::gui_start_change_role_wnd(contact, clanData)
      }
      {
        text = ::loc("clan/btnDismissMember")
        show = (!isMe
                && isMyClan
                && ::isInArray("MEMBER_DISMISS", myClanRights)
                && isMyRankHigher
               )
               || isClanAdmin
        action = @() ::g_clans.dismissMember(contact, clanData)
      }
    ])
  }
//---- </Clan> ---------------------

//---- <Contacts> ------------------
  if (::has_feature("Friends"))
  {
    local canBlock = !::is_platform_xboxone || !isXBoxOnePlayer

    actions.extend([
      {
        text = crossplayModule.getTextWithCrossplayIcon(showCrossPlayIcon, ::loc("contacts/friendlist/add"))
        show = !isMe && !isFriend && !isBlock
        isVisualDisabled = !canInteractCrossConsole || !canInteractCrossPlatform
        action = function() {
          if (!canInteractCrossConsole)
            showNotAvailableActionPopup()
          else if (!canInteractCrossPlatform)
            showCrossPlayRestrictionPopup()
          else
            ::editContactMsgBox(contact, ::EPL_FRIENDLIST, true)
        }
      }
      {
        text = ::loc("contacts/friendlist/remove")
        show = isFriend && !::isPlayerPS4Friend(name)
        action = @() ::editContactMsgBox(contact, ::EPL_FRIENDLIST, false)
      }
      {
        text = ::loc("contacts/blacklist/add")
        show = !isMe && !isFriend && !isBlock && canBlock
        action = @() ::editContactMsgBox(contact, ::EPL_BLOCKLIST, true)
      }
      {
        text = ::loc("contacts/blacklist/remove")
        show = isBlock && canBlock
        action = @() ::editContactMsgBox(contact, ::EPL_BLOCKLIST, false)
      }
    ])
  }
//---- </Contacts> ------------------

//---- <MP Lobby> -------------------
  if (isMPLobby)
    actions.append({
      text = ::loc("mainmenu/btnKick")
      show = !isMe && ::SessionLobby.isRoomOwner && !::SessionLobby.isEventRoom
      action = @() ::SessionLobby.kickPlayer(::SessionLobby.getMemberByName(name))
    })
//---- </MP Lobby> ------------------

//---- <In Battle> ------------------
  if (::is_in_flight())
    actions.append({
      text = ::loc(localDevoice.isMuted(name, localDevoice.DEVOICE_RADIO) ? "mpRadio/enable" : "mpRadio/disable")
      show = !isMe && !isBlock
      action = function() {
        localDevoice.switchMuted(name, localDevoice.DEVOICE_RADIO)
        local popupLocId = localDevoice.isMuted(name, localDevoice.DEVOICE_RADIO) ? "mpRadio/disabled/msg" : "mpRadio/enabled/msg"
        ::g_popups.add(null, ::loc(popupLocId, { player = ::colorize("activeTextColor", platformModule.getPlayerName(name)) }))
      }
    })
//---- </In Battle> -----------------

//---- <Chat> -----------------------
  if (::has_feature("Chat"))
  {
    if (platformModule.isChatEnabled() && canInviteToChatRoom)
    {
      local inviteMenu = ::g_chat.generateInviteMenu(name)
      actions.append({
        text = ::loc("chat/invite_to_room")
        show = inviteMenu && inviteMenu.len() > 0
        action = @() ::open_invite_menu(inviteMenu, params?.position)
      })
    }

    if (roomData)
      actions.extend([
        {
          text = ::loc("chat/kick_from_room")
          show = !::g_chat.isRoomSquad(roomId) && !::SessionLobby.isLobbyRoom(roomId) && ::g_chat.isImRoomOwner(roomData)
          action = @() ::menu_chat_handler ? ::menu_chat_handler.kickPlayeFromRoom(name) : null
        }
        {
          text = ::loc("contacts/copyNickToEditbox")
          show = !isMe && ::show_console_buttons && ::menu_chat_handler
          action = @() ::menu_chat_handler ? ::menu_chat_handler.addNickToEdit(name) : null
        }
      ])

    local canComplain = !isMe && (params?.canComplain ?? false)
    if (!isMe)
    {
      if (roomData) {
        for (local i = 0; i < roomData.mBlocks.len(); i++) {
          if (roomData.mBlocks[i].from == name || roomData.mBlocks[i].uid == uid) {
            canComplain = true
            break
          }
        }
      } else {
        local threadInfo = ::g_chat.getThreadInfo(roomId)
        if (threadInfo && threadInfo.ownerNick == name)
          canComplain = true
      }
    }

    if (canComplain)
      actions.append({
        text = ::loc("mainmenu/btnComplain")
        action = function() {
          local config = {
            userId = uid,
            name = name,
            clanTag = clanTag,
            roomId = roomId,
            roomName = roomData ? roomData.getRoomName() : ""
          }

          if (!isMPChat)
          {
            local threadInfo = ::g_chat.getThreadInfo(roomId)
            if (threadInfo) {
              chatLog = chatLog != "" ? chatLog : {}
              chatLog.category   <- threadInfo.category
              chatLog.title      <- threadInfo.title
              chatLog.ownerUid   <- threadInfo.ownerUid
              chatLog.ownerNick  <- threadInfo.ownerNick
              if (!roomData)
                config.roomName = ::g_chat_room_type.THREAD.getRoomName(roomId)
            }
          }

          ::gui_modal_complain(config, chatLog)
        }
      })
  }
//---- </Chat> ----------------------

//---- <Moderator> ------------------
  if (::is_myself_anyof_moderators() && (roomId || isMPChat || isMPLobby))
    actions.extend([
      {
        text = "" //for separator
      }
      {
        text = ::loc("contacts/moderator_copyname")
        action = @() ::copy_to_clipboard(platformModule.getPlayerName(name))
      }
      {
        text = ::loc("contacts/moderator_ban")
        show = ::myself_can_devoice() || ::myself_can_ban()
        action = @() ::gui_modal_ban(contact, chatLog)
      }
    ])
//---- </Moderator> -----------------

  local buttons = params?.extendButtons ?? []
  buttons.extend(actions)
  return buttons
}

local showMenu = function(_contact, handler, params = {})
{
  local contact = _contact || verifyContact(params)
  local showMenu = ::callee()
  if (contact && contact.needCheckXboxId())
    return contact.getXboxId(@() showMenu(contact, handler, params))

  if (!contact && params?.playerName)
    return ::find_contact_by_name_and_do(params.playerName, @(c) c && showMenu(c, handler, params))

  local menu = getActions(contact, params)
  ::gui_right_click_menu(menu, handler, params?.position, params?.orientation)
}

return {
  getActions = getActions
  showMenu = showMenu
  showNotAvailableActionPopup = showNotAvailableActionPopup
  showPrivacySettingsRestrictionPopup = showPrivacySettingsRestrictionPopup
}
