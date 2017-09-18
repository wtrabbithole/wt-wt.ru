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

    if (::g_squad_manager.isMySquadLeader(inviterUid))
    {
      implAccept(true) //auto accept squad leader room invite
      isAccepted = true //if fail to join, it will try again on ready
      return
    }

    if (initial)
    {
      ::add_event_listener("LobbyIsInRoomChanged",
        function (p) {
          if (::SessionLobby.isInRoom() && ::SessionLobby.roomId == roomId)
          {
            remove()
            onSuccessfulAccept()
          }
        },
        this)
      ::add_event_listener("MRoomInfoUpdated",
        function (p) {
          if (p.roomId != roomId)
            return
          setDelayed(false)
          if (!isValid())
            remove()
          else
            ::g_invites.broadcastInviteUpdated(this)
        },
        this)
    }

    //do not set delayed when scipt reload to not receive invite popup on each script reload
    setDelayed(!::g_script_reloader.isInReloading && !::g_mroom_info.get(roomId).getFullRoomData())
  }

  function isValid()
  {
    return !isAccepted
        && !::g_mroom_info.get(roomId).isRoomDestroyed
        && !::is_psn_player_use_same_titleId(inviterName)
  }

  function remove()
  {
    isAccepted = true
    base.remove()
  }

  function getText(locIdFormat, activeColor = null)
  {
    if (!activeColor)
      activeColor = inviteActiveColor

    local room = ::g_mroom_info.get(roomId).getFullRoomData()
    local event = room ? ::SessionLobby.getRoomEvent(room) : null
    local modeId = "skirmish"
    local params = { player = ::colorize(activeColor, inviterName) }
    if (event)
    {
      modeId = "event"
      params.eventName <- ::colorize(activeColor, ::events.getEventNameText(event))
    }
    else
      params.missionName <- room ? ::colorize(activeColor, ::SessionLobby.getMissionNameLoc(room)) : ""

    return ::loc(::format(locIdFormat, modeId), params)
  }

  function getInviteText()
  {
    return getText("invite/%s/message_no_nick", "userlogColoredText")
  }

  function getPopupText()
  {
    return getText("invite/%s/message")
  }

  function getIcon()
  {
    return "#ui/gameuiskin#lb_each_player_session"
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

  function onSuccessfulReject() {}
  function onSuccessfulAccept() {}

  function reject()
  {
    base.reject()
    onSuccessfulReject()
  }

  function accept()
  {
    local room = ::g_mroom_info.get(roomId).getFullRoomData()
    if (!::check_gamemode_pkg(::SessionLobby.getGameMode(room)))
      return

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

    local room = ::g_mroom_info.get(roomId).getFullRoomData()
    local event = room ? ::SessionLobby.getRoomEvent(room) : null
    if (event)
      ::gui_handlers.EventRoomsHandler.open(event, false, roomId)
    else
      ::SessionLobby.joinRoom(roomId, inviterUid, password)
  }
}