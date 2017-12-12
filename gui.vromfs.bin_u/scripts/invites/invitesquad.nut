local platformModule = require("scripts/clientState/platform.nut")

class ::g_invites_classes.Squad extends ::BaseInvite
{
  //custom class params, not exist in base invite
  squadId = 0
  leaderId = 0
  isAccepted = false

  static function getUidByParams(params)
  {
    return "SQ_" + ::getTblValue("squadId", params, "")
  }

  function updateCustomParams(params, initial = false)
  {
    squadId = ::getTblValue("squadId", params, squadId)
    leaderId = ::getTblValue("leaderId", params, leaderId)

    updateInviterName()

    if (inviterName.len() == 0)
    {
      setDelayed(true)
      local cb = ::Callback(function(r)
                            {
                              updateInviterName()
                              setDelayed(false)
                            }, this)
      ::g_users_info_manager.requestInfo([leaderId], cb, cb)
    }
    isAccepted = false
  }

  function updateInviterName()
  {
    local leaderContact = ::getContact(leaderId)
    if (leaderContact)
      inviterName = leaderContact.name
  }

  function isValid()
  {
    return !isAccepted
        && !::is_psn_player_use_same_titleId(inviterName)
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
    return "#ui/gameuiskin#lb_each_player_session"
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

    ::g_squad_manager.rejectSquadInvite(squadId)
    remove()
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
    onSuccessfulAccept()
  }
}
