const WW_OPERATION_INVITE_EXPIRE_SEC = 3600

class ::g_invites_classes.WwOperation extends ::BaseInvite
{
  //custom class params, not exist in base invite
  operationId = ""
  isStarted = false
  clanName = ""
  startTime = -1

  inviteActiveColor = "userlogColoredText"

  static function getUidByParams(params)
  {
    return "WWO_" + ::getTblValue("operationId", params, "")
  }

  function updateCustomParams(params, initial = false)
  {
    operationId = ::getTblValue("operationId", params, operationId)
    isStarted = ::getTblValue("isStarted", params, isStarted)
    clanName = ::getTblValue("clanName", params, clanName)

    //do not set delayed when scipt reload to not receive invite popup on each script reload
    setDelayed(!::g_script_reloader.isInReloading && !getOperation())

    if (!initial)
      return

    ::add_event_listener("WWGlobalStatusChanged",
      function (p)
      {
        if (!(p.changedListsMask & WW_GLOBAL_STATUS_TYPE.ACTIVE_OPERATIONS))
          return

        if (getOperation())
          setDelayed(false)
        else if (!isDelayed)
          remove()
      },
      this)

    ::add_event_listener("WWLoadOperation",
      function (p)
      {
        if (::ww_get_operation_id() == operationId)
          remove()
      },
      this)

    startTime = params?.inviteTime??startTime
    if (startTime > 0)
      setTimedParams(0, startTime + WW_OPERATION_INVITE_EXPIRE_SEC)
  }

  function getOperation()
  {
    return ::g_ww_global_status.getOperationById(operationId)
  }

  function isValid()
  {
    return isDelayed || !!getOperation()
  }

  function getInviteText()
  {
    local operation = getOperation()
    local locId = isStarted ? "worldWar/userlog/startOperation"
                            : "worldWar/userlog/createOperation"
    local params = {
      clan = ::colorize(inviteActiveColor, clanName)
      operation = ::colorize(inviteActiveColor, operation ? operation.getNameText() : operationId)
    }
    return ::loc(locId, params)
  }

  function getPopupText()
  {
    return getInviteText()
  }

  function getIcon()
  {
    return "#ui/gameuiskin#battles_open"
  }

  function haveRestrictions()
  {
    return !::isInMenu()
  }

  function getRestrictionText()
  {
    if (haveRestrictions())
      return ::loc("invite/session/cant_apply_in_flight")
    return ""
  }

  function accept()
  {
    ::g_world_war.joinOperationById(operationId)
  }
}