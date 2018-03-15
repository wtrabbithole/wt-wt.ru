/************************************************************
* Steps to do.
* 1) Filter users - check is they are in squad already.
* 2) Check is me in squad:
* 2.1) If not in squad:
*       create a squad and send invitations;
* 2.2) If in squad and not a leader:
*       ask to leave squad and make a new one
*   or  do nothing;
* 2.3) If in squad and a leader:
* 2.3.1) if there is enough or less players to full size squad:
*       send invitations;
* 2.3.2) if there is more users than available places in squad:
*       ask to leave squad and make a new one and send invitations
*   or  send invitations anyway
*   or  do nothing.
*
************************************************************/
::g_play_together <- {
  [PERSISTENT_DATA_PARAMS] = ["suspendedInviteesData", "cachedUsersData", "cachedInvitees", "canSendInvites"]

  suspendedInviteesData = null
  cachedUsersData = null
  cachedInvitees = null

  canSendInvites = false
}

function g_play_together::onNewInviteesDataIncome(inviteesArray)
{
  if (!::is_platform_ps4)
    return

  if (!::isInMenu() || !::g_login.isLoggedIn())
  {
    suspendedInviteesData = ::u.copy(inviteesArray)
    ::broadcastEvent("PS4AvailableNewInvite")
    if (::is_in_flight())
      ::g_popups.add(::loc("playTogether/name"), ::loc("playTogether/squad/sendLater"))
    return
  }

  requestUsersList(inviteesArray)
}

function g_play_together::checkAfterFlight()
{
  if (!::u.isEmpty(suspendedInviteesData))
    requestUsersList(suspendedInviteesData)
  suspendedInviteesData = null
}

function g_play_together::requestUsersList(inviteesArray)
{
  local onlineIds = []
  foreach (player in inviteesArray)
  {
    if (::getTblValue("onlineId", player, "") != "")
      onlineIds.append(player.onlineId)
    if (::getTblValue("accountId", player, "") != "")
      onlineIds.append(player.accountId)
  }

  local taskId = ::ps4_find_friends(onlineIds)
  local taskOptions = {
    showProgressBox = true
    progressBoxDelayedButtons = 15
  }
  ::g_tasker.addTask(taskId,
                     taskOptions,
                     ::Callback(gatherUsersDataAndCheck, this),
                     @(err) ::g_popups.add(::loc("playTogether/name"), ::loc("playTogether/noUsers")))
}

function g_play_together::gatherUsersDataAndCheck()
{
  local usersResult = ps4_find_friends_result()
  cachedUsersData = ::u.copy(usersResult)

  checkUsersAndProceed()
}

function g_play_together::checkUsersAndProceed()
{
  if (::u.isEmpty(cachedUsersData))
    return

  filterUsers()

  if (checkMeAsSquadMember())
    return

  if (checkMeAsSquadLeader())
    return

  ::update_ps4_friends()
  sendInvitesToSquad()
}

function g_play_together::filterUsers()
{
  cachedInvitees = {}

  for (local i = 0; i < cachedUsersData.blockCount(); i++)
  {
    local user = cachedUsersData.getBlock(i)
    local uid = user.getBlockName()
    local name = user.nick

    local playerStatus = ::g_squad_manager.getPlayerStatusInMySquad(uid)
    if (playerStatus == squadMemberState.NOT_IN_SQUAD)
      cachedInvitees[uid] <- user.nick
  }
}

function g_play_together::sendInvitesToSquad()
{
  foreach (uid, name in cachedInvitees)
    ::g_squad_manager.inviteToSquad(uid, name)
}

function g_play_together::checkMeAsSquadMember()
{
  if (!::g_squad_manager.isSquadMember())
    return false

  ::showCantJoinSquadMsgBox(
    "squad_not_a_leader",
    ::loc("playTogether/squad/playerIsMember"),
    [
      [
        "createNewSquad",
        function()
        {
          ::g_play_together.canSendInvites = true
          ::g_squad_manager.leaveSquad()
        }
      ],
      [ "cancel", function(){} ]
    ],
    "cancel",
    { cancel_fn = function(){} }
  )
  return true
}

function g_play_together::checkMeAsSquadLeader()
{
  if (!::g_squad_manager.isSquadLeader())
    return false

  local availableSlots = ::g_squad_manager.getMaxSquadSize() - ::g_squad_manager.getSquadSize()
  if (availableSlots >= cachedInvitees.len())
    return false

  ::showCantJoinSquadMsgBox(
    "squad_not_enough_slots",
    ::loc("playTogether/squad/notEnoughtSquadSlots"),
    [
      [
        "createNewSquad",
        function()
        {
          ::g_play_together.canSendInvites = true
          ::g_squad_manager.leaveSquad()
        }
      ],
      [ "sendAnyway", sendInvitesToSquad.bindenv(this) ],
      [ "cancel", function(){} ]
    ],
    "cancel",
    { cancel_fn = function(){} }
  )
  return true
}

function g_play_together::onEventSquadStatusChanged(params)
{
  if (!canSendInvites)
    return

  sendInvitesToSquad()
  canSendInvites = false
}

::g_script_reloader.registerPersistentDataFromRoot("g_play_together")
::subscribe_handler(::g_play_together, ::g_listener_priority.DEFAULT_HANDLER)

//called from C++
function on_ps4_play_together_host(inviteesArray)
{
  dagor.debug("[PSPT] got host event")
  debugTableData(inviteesArray)
  ::g_play_together.onNewInviteesDataIncome(inviteesArray)
}
