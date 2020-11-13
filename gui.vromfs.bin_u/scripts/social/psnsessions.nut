local subscriptions = require("sqStdLibs/helpers/subscriptions.nut")

local psn = require("sonyLib/webApi.nut")
local { isPlatformSony } = require("scripts/clientState/platform.nut")

enum PSN_SESSION_TYPE {
  SKIRMISH = "skirmish"
  SQUAD = "squad"
}

//{ id = { type, info }}, joined sessions, only id is mandatory
local sessions = persist("sessions", @() Watched({}) )

// in-flight cache for invitations accepted via PSN
local invitations = persist("invitations", @() Watched([]) )

// { PSN_SESSION_TYPE = { type, info }} - waitng sessionId from PSN or joining
local pendingSessions = persist("pendingSessions", @() Watched({}) )

local function formatSessionInfo(data, isCreateRequest=true)
{
  local names = ::g_localization.getFilledFeedTextByLang(data.locIdsArray)
  local info = {
    sessionPrivacy = data.isPrivate ? "private" : "public"
    sessionMaxUser = data.maxUsers
    sessionName = data.locIdsArray.map(@(id) ::loc(id, "")).reduce(@(res,str) res+str)
    localizedSessionNames = names.map(@(n) {npLanguage = n.abbreviation, sessionName = n.text})
    sessionLockFlag = false
  }
  if (isCreateRequest) {
    info.index <- data.index
    info.sessionType <- data.sessionType
    info.availablePlatforms <- ["PS4"]
  }
  return ::save_to_json(info)
}

local sessionParams = {
  [PSN_SESSION_TYPE.SKIRMISH] = {
    image = @() "ui/images/reward27.jpg"
    info = function() {
      local missionLoc = ::split(::SessionLobby.getMissionData()?.locName || "", "; ")
      local defaultLoc = ["missions/" + ::SessionLobby.getMissionName(true)]
      return {
        index = 0
        locIdsArray = u.isEmpty(missionLoc) ? defaultLoc : missionLoc
        maxUsers = ::SessionLobby.getMaxMembersCount()
        isPrivate = ::SessionLobby.getPublicParam("friendOnly", false)
                 || !::SessionLobby.getPublicParam("allowJip", true)
        sessionType = "owner-migration"
      }
    }
    data = @() {
      roomId = ::SessionLobby.roomId,
      inviterUid = ::my_user_id_str,
      inviterName = ::my_user_name
      password = ::SessionLobby.password
      key = PSN_SESSION_TYPE.SKIRMISH
    }
  },

  [PSN_SESSION_TYPE.SQUAD] = {
    image = @() "ui/images/reward05.jpg"
    info = @() {
      index = 1
      locIdsArray = ["ps4/session/squad"]
      maxUsers = ::g_squad_manager.getMaxSquadSize()
      isPrivate = true
      sessionType = "owner-migration"
    }
    data = @() {
      squadId = ::my_user_id_str
      leaderId = ::my_user_id_str
      key = PSN_SESSION_TYPE.SQUAD
    }
  }
}


local function create(sType, cb = psn.noOpCb) {
  local params = sessionParams[sType] // Cache info for use in callback
  pendingSessions.update(@(v) v[sType] <- { type = sType, info = params.info })
  local saveSession = function(response, err) {
    if (!err && response?.sessionId)
      sessions.update(@(v) v[response.sessionId] <- pendingSessions.value[sType])
    pendingSessions.update(@(v) delete v[sType])

    cb(response, err)
  }
  psn.send(psn.session.create(formatSessionInfo(params.info()), params.image(), params.data()),
           ::Callback(saveSession, this))
}

local function invite(session, invitee, cb=psn.noOpCb) {
  if (session in sessions.value)
    psn.send(psn.session.invite(session, invitee), cb)
}

local function join(session, invitation=null, cb=psn.noOpCb) {
  // If we're in this session, just mark invitation used, favor rate limits
  if (session in sessions.value && invitation?.invitationId)
    psn.send(psn.invitation.use(invitation.invitattionId), cb)
  else
  {
    sessions.update(@(v) v[session] <- { type = invitation.key }) // consider ourselves in session early
    pendingSessions.update(@(v) v[invitation.key] <- { type = invitation.key })
    local afterJoin = function(response, err) {
      pendingSessions.update(@(v) delete v[invitation.key])
      if (err)
        sessions.update(@(v) delete v[session])
      else // Mark all invitations to this particular session as used
        psn.send(psn.invitation.list(), function(r, e) {
              local all = r?.invitations ?? []
              local toMark = all.filter(@(i) !i.usedFlag && i.sessionId == session)
              toMark.apply(@(i) psn.send(psn.invitation.use(i.invitationId)))
            })

      cb(response, err)
    }
    psn.send(psn.session.join(session), ::Callback(afterJoin, this))
  }
}

local function update(session, info) {
  local psnSession = sessions.value?[session]
  local shouldUpdate = !u.isEqual((psnSession && psnSession?.info) || {}, info)
  ::dagor.debug("[PSSI] update "+ session+" ("+psnSession+"): "+ shouldUpdate)

  if (shouldUpdate)
    psn.send(psn.session.update(session, formatSessionInfo(info, false)), function(r,e) {
          if (!e)
            psnSession.info <- info
        })
}

local function leave(session, cb=psn.noOpCb) {
  if (session in sessions.value)
  {
    local afterLeave = function(response, err) {
      if (session in sessions.value)
        sessions.update(@(v) delete v[session])
      cb(response, err)
    }
    psn.send(psn.session.leave(session), ::Callback(afterLeave, this))
  }
  else
    cb({}, 0)
}


local function checkAfterFlight() {
  if (!isPlatformSony)
    return

  invitations.value.apply(@(i) i.processDelayed(i))
  invitations.update([])
}

subscriptions.addListenersWithoutEnv({
  RoomJoined = function(p) {
    if (!isPlatformSony || ::get_game_mode() != ::GM_SKIRMISH)
      return

    local session = ::SessionLobby.getExternalId()
    ::dagor.debug("[PSSI] onEventRoomJoined: "+session)
    if (u.isEmpty(session) && ::SessionLobby.isRoomOwner)
      create(PSN_SESSION_TYPE.SKIRMISH, @(r,e) ::SessionLobby.setExternalId(r?.sessionId))
    else if (session && !(session in sessions.value))
      join(session, {key=PSN_SESSION_TYPE.SKIRMISH})
  }
  LobbyStatusChange = function(p)
  {
    ::dagor.debug("[PSSI] onEventLobbyStatusChange in room "+::SessionLobby.isInRoom())
    // Leave psn session, join has its own event. Actually leave all skirmishes,
    // we can have only one in game but we no longer know it's psn Id in Lobby
    if (isPlatformSony && !::SessionLobby.isInRoom())
      foreach(id,s in sessions.value.filter(@(s) s.type == PSN_SESSION_TYPE.SKIRMISH))
        leave(id)
  }
  LobbySettingsChange = function(p)
  {
    local session = ::SessionLobby.getExternalId()
    if (!isPlatformSony || u.isEmpty(session))
      return

    ::dagor.debug("[PSSI] onEventLobbySettingsChange for " + session)
    if (::SessionLobby.isRoomOwner)
      update(session, sessionParams[PSN_SESSION_TYPE.SKIRMISH].info())
    else if (!(session in sessions.value))
      join(session, {key=PSN_SESSION_TYPE.SKIRMISH})
  }
  SquadStatusChanged = function(p)
  {
    if (!isPlatformSony)
      return

    local session = ::g_squad_manager.getPsnSessionId()
    local isLeader = ::g_squad_manager.isSquadLeader()
    local isInPsnSession = session in sessions.value
    ::dagor.debug("[PSSI] onEventSquadStatusChanged " + ::g_squad_manager.state + " for " + session)
    ::dagor.debug("[PSSI] onEventSquadStatusChanged leader: " + isLeader + ", psnSessions: " + sessions.value.len())
    ::dagor.debug("[PSSI] onEventSquadStatusChanged session bound to PSN: " + isInPsnSession)

    local bindSquadSession = function(r,e) {
      if (!e && r?.sessionId)
        ::g_squad_manager.setPsnSessionId(r.sessionId)
      ::g_squad_manager.processDelayedInvitations()
    }

    switch (::g_squad_manager.state)
    {
      case squadState.IN_SQUAD:
        if (PSN_SESSION_TYPE.SQUAD in pendingSessions.value)
          break
        if (!isLeader && !isInPsnSession) // Invite accepted or normal relogin
          join(session, {key = PSN_SESSION_TYPE.SQUAD})
        if (!isLeader && sessions.value[session]?.info) // Leadership transfer
          sessions.update(@(v) delete v[session].info)
        else if (isLeader && u.isEmpty(session)) // Squad implicitly created
          create(PSN_SESSION_TYPE.SQUAD, bindSquadSession)
        else if (isLeader && u.isEmpty(sessions.value)) // Autotransfer on login
          create(PSN_SESSION_TYPE.SQUAD, bindSquadSession)
        else if (isLeader && sessions.value?[session] && !sessions.value[session]?.info) // Leadership transfer
        {
          update(session, sessionParams[PSN_SESSION_TYPE.SQUAD].info())
          psn.send(psn.session.change(session, sessionParams[PSN_SESSION_TYPE.SQUAD].data()))
        }
        break

      case squadState.LEAVING:
        if (isInPsnSession)
          leave(session)
        break
    }
  }
})

local function onPsnInvitation(invitation) {
  ::dagor.debug("[PSSI] PSN invite "+invitation.invitationId+" to "+invitation.sessionId)
  local delayInvitation = function(i, cb) {
    i.processDelayed <- cb
    invitations.update(@(v) v.append(i))
  }
  local isInPsnSession = invitation.sessionId in sessions.value

  if (u.isEmpty(invitation.sessionId) || isInPsnSession)
    return // Most-likely we are joining from PS4 Blue Screen

  if (!::g_login.isLoggedIn() || ::is_in_loading_screen())
  {
    ::dagor.debug("[PSSI] delaying PSN invite until logged in and loaded")
    delayInvitation(invitation, ::on_ps4_session_invitation)
    return
  }

  if (isInPsnSession)
  {
    ::dagor.debug("[PSSI] stale PSN invite: already joined")
    psn.send(psn.invitation.use(invitation.invitationId)) // Stale PSN-invitation
    return
  }

  if (!::isInMenu())
  {
    ::dagor.debug("[PSSI] delaying PSN invite until in menu")
    delayInvitation(invitation, ::on_ps4_session_invitation)
    ::get_cur_gui_scene().performDelayed(this, function() {
      ::showInfoMsgBox(::loc("msgbox/add_to_squad_after_fight"), "add_to_squad_after_fight")
    })
    return
  }

  local acceptInvitation = function(response, err) {
    ::dagor.debug("[PSSI] ready to accept PSN invite, error " + err)
    if (!err)
    {
      local fullInfo = ::u.extend(response, invitation)
      switch (response.key)
      {
        case PSN_SESSION_TYPE.SKIRMISH:
          ::g_invites.addSessionRoomInvite(fullInfo.roomId, fullInfo.inviterUid, fullInfo.inviterName, fullInfo.password).accept()
          break
        case PSN_SESSION_TYPE.SQUAD:
          ::g_invites.addInviteToSquad(fullInfo.squadId, fullInfo.leaderId).accept()
          break
      }
    }
  }
  psn.send(psn.session.data(invitation.sessionId), acceptInvitation)
}

return {
  onPsnInvitation
  invite
  checkInvitesAfterFlight = checkAfterFlight
}