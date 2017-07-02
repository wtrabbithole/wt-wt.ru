class ::g_invites_classes.PsnSessionRoom extends ::g_invites_classes.SessionRoom
{
  static lifeTimeMsec = 900000

  isDelayed = true

  static function getUidByParams(params)
  {
    return "PSN_SR_" + ::getTblValue("invitationId", params, "")
  }

  function updateCustomParams(params, initial = false)
  {
    base.updateCustomParams(params, initial)
    accept()
  }

  function getPopupText() { return "" }
}