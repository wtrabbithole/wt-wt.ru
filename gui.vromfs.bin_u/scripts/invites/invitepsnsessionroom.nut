class ::g_invites_classes.PsnSessionRoom extends ::g_invites_classes.SessionRoom
{
  isDelayed = true
  invitationId = ""

  static function getUidByParams(params)
  {
    return "PSN_SR_" + ::getTblValue("invitationId", params, "")
  }

  function updateCustomParams(params, initial = false)
  {
    invitationId = ::getTblValue("invitationId", params, "")
    base.updateCustomParams(params, initial)
    accept()
  }

  function onSuccessfulReject()
  {
    ::g_psn_session_invitations.setInvitationUsed(invitationId)
  }

  function onSuccessfulAccept()
  {
    ::g_psn_session_invitations.setInvitationUsed(invitationId)
  }

  function getPopupText() { return "" }
}