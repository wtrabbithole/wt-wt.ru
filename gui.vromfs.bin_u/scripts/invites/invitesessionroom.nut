class ::g_invites_classes.SessionRoom extends ::BaseInvite
{
  //custom class params, not exist in base invite
  roomId = ""
  password = ""
  isAccepted = false

  static function getUidByParams(params)
  {
    return "SR_" + ::getTblValue("inviterName", params, "") + "/" + ::getTblValue("roomId", params, "")
  }

  function updateCustomParams(params, initial = false)
  {
    roomId = ::getTblValue("roomId", params, roomId)
    password = ::getTblValue("password", params, password)

    isAccepted = false

    if (::g_squad_manager.isMySquadLeader(inviterUid))
      implAccept(true) //auto accpet squad leader room invite
  }

  function isValid()
  {
    return !isAccepted
  }

  function getChatInviteText()
  {
    local nameF = "<Link=%s><Color="+inviteActiveColor+">%s</Color></Link>"

    local inviterText = ::format(nameF, getChatInviterLink(), inviterName)
    return ::format(::loc("multiplayer/invite_to_session_message"), inviterText)
           + ::format(nameF, getChatLink(), ::loc("multiplayer/invite_to_session_link_text"))
  }

  function getInviteText()
  {
    return ::loc("multiplayer/invite_to_session_message/no_nick")
  }

  function getPopupText()
  {
    return ::format(::loc("multiplayer/invite_to_session_message"),
                    ::colorize(inviteActiveColor, inviterName))
  }

  function getIcon()
  {
    return "#ui/gameuiskin#lb_each_player_session"
  }

  function accept()
  {
    implAccept()
  }

  function implAccept(ignoreCheckSquad = false)
  {
    if (!::check_gamemode_pkg(::GM_SKIRMISH))
      return

    local canJoin = ignoreCheckSquad
                    ||  ::g_squad_utils.canJoinFlightMsgBox(
                          { isLeaderCanJoin = true }, ::Callback(_implAccept, this))
    if (canJoin)
      _implAccept()
  }

  function _implAccept()
  {
    if (isOutdated())
      return ::g_invites.showExpiredInvitePopup()

    ::SessionLobby.joinRoom(roomId, inviterUid, password)
    isAccepted = true
    remove()
  }
}