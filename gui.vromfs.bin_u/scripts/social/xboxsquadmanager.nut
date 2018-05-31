::g_xbox_squad_manager <- {
  [PERSISTENT_DATA_PARAMS] = ["lastReceivedUsersCache, isSquadStatusCheckedOnce, currentUsersListCache, xboxIsGameStartedByInvite", "suspendedData"]
  lastReceivedUsersCache = []
  currentUsersListCache = []
  isSquadStatusCheckedOnce = false
  needCheckSquadInvites = false
  needCheckSquadInvitesOnContactsUpdate = false

  xboxIsGameStartedByInvite = ::xbox_is_game_started_by_invite()

  suspendedData = null

  notFoundIds = []

  function updateSquadList(xboxIdsList = [])
  {
    if (!::is_platform_xboxone)
      return

    if (!::isInMenu() || !::g_login.isLoggedIn())
    {
      needCheckSquadInvites = ::is_in_flight()
      ::dagor.debug("XBOX SQUAD MANAGER: set needCheckSquadInvites " + needCheckSquadInvites + "; " + ::toString(xboxIdsList))
      suspendedData = clone xboxIdsList
      return
    }

    if (!xboxIdsList || !xboxIdsList.len()) //C++ code return empty array when leader is in battle or offline
    {
      ::dagor.debug("XBOX SQUAD MANAGER: show popup in updateSquadList")
      ::g_popups.add(::loc("squad/name"), ::loc("squad/wait_until_battle_end"))
      return
    }

    currentUsersListCache = clone xboxIdsList
    if (!isMeLeader(xboxIdsList))
    {
      if (needCheckSquadInvites)
      {
        ::dagor.debug("XBOX SQUAD MANAGER: player is not a leader. Requested to check invites on squad update.")
        checkSquadInvites(currentUsersListCache)
      }
      else
        ::dagor.debug("XBOX SQUAD MANAGER: player is not a leader. Don't proceed invites.")
      return
    }

    notFoundIds.clear()
    validateList(xboxIdsList)
    ::dagor.debug("XBOX SQUAD MANAGER: notFoundIds " + notFoundIds.len())

    if (notFoundIds.len())
      requestUnknownIds(notFoundIds)
  }

  isMeLeaderByList = @(xboxIdsList) xboxIdsList?[0] == ::get_my_external_id(::EPL_XBOXONE)

  function isMeLeader(xboxIdsList)
  {
    if (!::g_squad_manager.isInSquad())
      return isMeLeaderByList(xboxIdsList)
    if (::g_squad_manager.isSquadMember())
      return false //!!FIX ME: Better to add squad leave logic here when im real leader.

    if (isMeLeaderByList(xboxIdsList))
      return true

    foreach(member in ::g_squad_manager.getMembers())
    {
      if (member.isMe())
        continue
      local contact = ::getContact(member.uid)
      if (::isInArray(contact?.xboxId, xboxIdsList)) //other xbox squad member in my squad already
        return true
    }
    return false
  }

  function checkAfterFlight()
  {
    ::dagor.debug("XBOX SQUAD MANAGER: launch checkAfterFlight, suspendedData " + suspendedData + "; " + ::isInMenu())
    if (!::isInMenu())
    {
      ::dagor.debug("XBOX SQUAD MANAGER: launch checkAfterFlight, terminate process, not in menu.")
      return
    }

    if (suspendedData)
    {
      updateSquadList(suspendedData)
      isSquadStatusCheckedOnce = true
    }

    if (xboxIsGameStartedByInvite && !suspendedData && !isSquadStatusCheckedOnce && !::g_squad_manager.isInSquad())
    {
      ::dagor.debug("XBOX SQUAD MANAGER: show popup in checkAfterFlight")
      ::g_popups.add(::loc("squad/name"), ::loc("squad/wait_until_battle_end"))
    }

    suspendedData = null
  }

  function validateList(xboxIdsList)
  {
    foreach (id in xboxIdsList)
      if (!::isInArray(id, lastReceivedUsersCache))
        if (!proceedContact(::findContactByXboxId(id), true) && !::isInArray(id, notFoundIds))
          notFoundIds.append(id)

    foreach (id in lastReceivedUsersCache)
      if (!::isInArray(id, xboxIdsList))
        if (!proceedContact(::findContactByXboxId(id), false) && !::isInArray(id, notFoundIds))
          notFoundIds.append(id)

    lastReceivedUsersCache = clone xboxIdsList
  }

  function proceedContact(contact, needInviteUser = true)
  {
    if (!contact)
      return false

    if (needInviteUser)
    {
      if (::g_squad_manager.canInviteMember(contact.uid) && !::g_squad_manager.isPlayerInvited(contact.uid, contact.name))
        ::g_squad_manager.inviteToSquad(contact.uid, contact.name)
    }
    else if (::g_squad_manager.canDismissMember(contact.uid))
      ::g_squad_manager.dismissFromSquad(contact.uid)
    return true
  }

  function isPlayerFromXboxSquadList(userXboxId = "")
  {
    if (!isSquadStatusCheckedOnce)
      checkAfterFlight()

    return ::isInArray(userXboxId, currentUsersListCache)
  }

  function acceptExistingInvite(playerUid)
  {
    local inviteUid = ::g_invites_classes.Squad.getUidByParams({squadId = playerUid})
    local invite = ::g_invites.findInviteByUid(inviteUid)
    if (!invite)
      return false

    invite.accept()
    return true
  }

  function checkSquadInvites(xboxIdsList)
  {
    local idsArray = []
    foreach (xboxId in xboxIdsList)
    {
      local contact = ::findContactByXboxId(xboxId)
      if (contact && acceptExistingInvite(contact.uid))
        return

      if (!contact)
        idsArray.append(xboxId)
    }

    if (!idsArray.len())
      return

    notFoundIds = clone idsArray
    needCheckSquadInvitesOnContactsUpdate = true
    requestUnknownIds(notFoundIds)
  }

  function requestUnknownIds(idsList)
  {
    if (!idsList.len())
      return

    local taskId = ::xbox_find_friends(idsList)
    ::g_tasker.addTask(taskId, null, ::Callback(function() {
      local blk = ::DataBlock()
      blk = ::xbox_find_friends_result()
      local table = ::buildTableFromBlk(blk)
      checkFoundIds(table)
    }, this))
  }

  function sendSystemInvite(uid, name)
  {
    //Check, if player not in system lobby already.
    //Because, no need to send system invitation if he is there already.

    local contact = ::getContact(uid, name)
    if (contact.needCheckXboxId())
      contact.getXboxId(::Callback(function() {
        if (!::isInArray(contact.xboxId, currentUsersListCache))
          @() ::xbox_invite_user(contact.xboxId)
      }, this))
    else if (contact.xboxId != "")
    {
      if (!::isInArray(contact.xboxId, currentUsersListCache))
        ::xbox_invite_user(contact.xboxId)
    }
  }

  function checkFoundIds(p)
  {
    if (!notFoundIds.len())
      return

    local isLeader = isMeLeader(currentUsersListCache)
    foreach(uid, data in p)
    {
      local contact = ::getContact(uid, data.nick)
      if (isLeader && !proceedContact(contact))
        ::dagor.debug("XBOX_SQUAD_MANAGER: Not found xboxId " + data.id + " after charServer call")

      if (contact)
      {
        contact.update({xboxId = data.id})
        if (needCheckSquadInvitesOnContactsUpdate && acceptExistingInvite(uid))
          needCheckSquadInvitesOnContactsUpdate = false
      }
    }
    notFoundIds.clear()
  }

  function onEventSquadStatusChanged(p)
  {
    if (::g_squad_manager.isInSquad())
      return

    lastReceivedUsersCache.clear()
    currentUsersListCache.clear()
    isSquadStatusCheckedOnce = false
    xboxIsGameStartedByInvite = false
    needCheckSquadInvites = false
    needCheckSquadInvitesOnContactsUpdate = false
  }

  function onEventXboxInviteAccepted(p)
  {
    needCheckSquadInvites = true
  }
}
::g_script_reloader.registerPersistentDataFromRoot("g_xbox_squad_manager")
::subscribe_handler(::g_xbox_squad_manager, ::g_listener_priority.DEFAULT_HANDLER)

::xbox_update_warthunder_squad <- @(xboxIdsList) ::g_xbox_squad_manager.updateSquadList.call(::g_xbox_squad_manager, xboxIdsList)
::xbox_on_invite_accepted <- @() ::broadcastEvent("XboxInviteAccepted")