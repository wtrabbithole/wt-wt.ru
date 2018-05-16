local platformModule = require("modules/platform.nut")

class ::g_invites_classes.Squad extends ::BaseInvite
{
  //custom class params, not exist in base invite
  squadId = 0
  leaderId = 0
  isAccepted = false
  leaderContact = null

  static function getUidByParams(params)
  {
    return "SQ_" + ::getTblValue("squadId", params, "")
  }

  function updateCustomParams(params, initial = false)
  {
    squadId = ::getTblValue("squadId", params, squadId)
    leaderId = ::getTblValue("leaderId", params, leaderId)

    updateInviterContact()

    if (inviterName.len() != 0)
    {
      //Don't show invites from xbox players, as notification comes from system overlay
      //And we don't wan't players to be confused.
      if (platformModule.isPlayerFromXboxOne(inviterName) && !haveRestrictions())
        setDelayed(true)
    }
    else
    {
      setDelayed(true)
      local cb = ::Callback(function(r)
                            {
                              updateInviterContact()
                              setDelayed(platformModule.isPlayerFromXboxOne(inviterName) && !haveRestrictions())
                            }, this)
      ::g_users_info_manager.requestInfo([leaderId], cb, cb)
    }
    isAccepted = false

    if (initial)
      ::add_event_listener("SquadStatusChanged",
        function (p) {
          if (::g_squad_manager.isInSquad()
            && ::g_squad_manager.getLeaderUid() == squadId.tostring())
            remove()
        }, this)
  }

  function updateInviterContact()
  {
    leaderContact = ::getContact(leaderId)
    updateInviterName()
    checkAutoAcceptXboxInvite()
    checkAutoRejectXboxInvite()
  }

  function updateInviterName()
  {
    if (leaderContact)
      inviterName = leaderContact.name
  }

  function checkAutoAcceptXboxInvite()
  {
    if (!::is_platform_xboxone || !leaderContact)
      return

    if (leaderContact.xboxId != "")
      autoacceptXboxInvite(leaderContact.xboxId)
    else
      leaderContact.getXboxId(::Callback(@() autoacceptXboxInvite(leaderContact.xboxId), this))
  }

  function checkAutoRejectXboxInvite()
  {
    if (!::is_platform_xboxone || !leaderContact || isAccepted)
      return

    if (leaderContact.xboxId != "")
      autorejectXboxInvite()
    else
      leaderContact.getXboxId(::Callback(@() autorejectXboxInvite(), this))
  }

  function autoacceptXboxInvite(leaderXboxId = "")
  {
    if (::g_xbox_squad_manager.isPlayerFromXboxSquadList(leaderXboxId))
      accept()
  }

  function autorejectXboxInvite()
  {
    if (!::g_chat.xboxIsChatEnabled() || !leaderContact.canInteract())
      reject()
  }

  function isValid()
  {
    return !isAccepted
  }

  function getInviteText()
  {
    return ::loc("multiplayer/squad/invite/desc",
                 {
                   name = getInviterName() || platformModule.getPlayerName(leaderId)
                 })
  }

  function getPopupText()
  {
    return ::loc("multiplayer/squad/invite/desc",
                 {
                   name = getInviterName() || platformModule.getPlayerName(leaderId)
                 })
  }

  function getRestrictionText()
  {
    if (haveRestrictions())
      return ::loc("squad/cant_join_in_flight")
    return ""
  }

  function haveRestrictions()
  {
    return !::g_squad_manager.canManageSquad()
  }

  function getIcon()
  {
    return "#ui/gameuiskin#lb_each_player_session.svg"
  }

  function onSuccessfulReject() {}
  function onSuccessfulAccept() {}

  function accept()
  {
    local acceptCallback = ::Callback(_implAccept, this)
    local callback = function () { ::queues.checkAndStart(acceptCallback, null, "isCanNewflight")}

    local canJoin = ::g_squad_utils.canJoinFlightMsgBox(
      { allowWhenAlone = false, msgId = "squad/leave_squad_for_invite" },
      callback
    )

    if (canJoin)
      callback()
  }

  function reject()
  {
    if (isOutdated())
      return remove()

    isRejected = true
    ::g_squad_manager.rejectSquadInvite(squadId)
    remove()
    ::g_invites.removeInviteToSquad(squadId)
    onSuccessfulReject()
  }

  function _implAccept()
  {
    if (isOutdated())
      return ::g_invites.showExpiredInvitePopup()
    if (!::g_squad_manager.canJoinSquad())
      return

    ::g_squad_manager.acceptSquadInvite(squadId)
    isAccepted = true
    remove()
    ::g_invites.removeInviteToSquad(squadId)
    onSuccessfulAccept()
  }
}
