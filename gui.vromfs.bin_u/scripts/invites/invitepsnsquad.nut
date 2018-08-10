class ::g_invites_classes.PsnSquad extends ::g_invites_classes.Squad
{
  isDelayed = true
  invitationId = ""
  sessionId = ""

  static function getUidByParams(params)
  {
    return "PSN_SQ_" + ::getTblValue("squadId", params, "")
  }

  function updateCustomParams(params, initial = false)
  {
    invitationId = params?.invitationId ?? ""
    sessionId = params?.sessionId ?? ""
    base.updateCustomParams(params, initial)
    accept()
  }

  function onSuccessfulReject()
  {
    ::g_psn_session_invitations.setInvitationUsed(invitationId)
  }

  function onSuccessfulAccept()
  {
    base.onSuccessfulAccept()
    ::g_psn_session_invitations.joinSession(PSN_SESSION_TYPE.SQUAD, sessionId)
  }

  function getPopupText() { return "" }
}
