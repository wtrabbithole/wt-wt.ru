class ::g_invites_classes.PsnSquad extends ::g_invites_classes.Squad
{
  static lifeTimeMsec = 900000

  isDelayed = true

  static function getUidByParams(params)
  {
    return "PSN_SQ_" + ::getTblValue("invitationId", params, "")
  }

  function updateCustomParams(params, initial = false)
  {
    base.updateCustomParams(params, initial)
    accept()
  }

  function getPopupText() { return "" }
}