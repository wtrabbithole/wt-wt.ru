local psnApi = require("scripts/social/psnWebApi.nut")

enum PSN_SESSION_TYPE {
  SKIRMISH = "skirmish"
  SQUAD = "squad"
}

::g_psn_session_invitations <- {
  [PERSISTENT_DATA_PARAMS] = ["existingSession", "curSessionParams", "lastUpdateTable", "suspendedInvitationData",
                              "suspendedSquadDisband"]

  existingSession = {}
  curSessionParams = {}
  lastUpdateTable = {}

  sessionTypeToIndex = {
    [PSN_SESSION_TYPE.SKIRMISH] = 0,
    [PSN_SESSION_TYPE.SQUAD] = 1
  }

  updateTimerLimit = 60000
  suspendedInvitationData = null
  suspendedSquadDisband = false
}

function g_psn_session_invitations::saveSessionId(key, sessionId)
{
  if (key in existingSession)
  {
    ::dagor.debug("[PSSI] saveSessionId: refuse overwrite "+existingSession[key]+" with "+sessionId)
    return false
  }

  existingSession[key] <- sessionId
  return true
}

function g_psn_session_invitations::deleteSavedSessionData(key)
{
  if (key in existingSession)
    delete existingSession[key]
  if (key in curSessionParams)
    delete curSessionParams[key]
}

function g_psn_session_invitations::getSessionId(key)
{
  return ::getTblValue(key, existingSession, "")
}

function g_psn_session_invitations::isInSession(key)
{
  return !u.isEmpty(getSessionId(key))
}

function g_psn_session_invitations::saveSessionData(key, data = {})
{
  if (::u.isEmpty(data))
    return

  curSessionParams[key] <- clone data
}

function g_psn_session_invitations::getSavedSessionData(key)
{
  return ::getTblValue(key, curSessionParams)
}

function g_psn_session_invitations::isSessionParamsEqual(key, checkData)
{
  return ::u.isEqual(::getTblValue(key, curSessionParams, {}), checkData)
}

function g_psn_session_invitations::sendCreateSession(key, sessionInfo, image, sessionData = "", onSuccess=function(r,e){})
{
  local cb = function(response, error) {
    if (response?.sessionId)
    {
      saveSessionId(key, response.sessionId)
      onSuccess(response, error)
    }
    else
      ::dagor.debug("[PSSI] Web API did not return session ID")
  }
  psnApi.send(psnApi.session.create(sessionInfo, image, sessionData), cb, this)
}

function g_psn_session_invitations::updateExistingSessionInfo(key, sessionInfo)
{
  if (!::is_platform_ps4)
    return

  local sessionId = getSessionId(key)
  if (u.isEmpty(sessionId))
    return

  local lastUpdate = ::getTblValue(sessionId, lastUpdateTable, 0)
  if (::dagor.getCurTime() - lastUpdate < updateTimerLimit)
  {
    ::dagor.debug("[PSSI] updateExsitingSessionInfo: Too often update call")
    return
  }

  lastUpdateTable[sessionId] <- ::dagor.getCurTime()

  local info = getJsonRequestForSession(key, sessionInfo, true)
  psnApi.send(psnApi.session.update(sessionId, info))
}

function g_psn_session_invitations::sendLeaveSession(key)
{
  local sessionId = getSessionId(key)
  dagor.debug("[PSSI] sendLeaveSession "+key+" ("+sessionId+")")
  if (!::u.isEmpty(sessionId))
  {
    psnApi.send(psnApi.session.leave(sessionId), function(r, e) { deleteSavedSessionData(key) }, this)
    deleteSavedSessionData(key)
  }
}

function g_psn_session_invitations::setInvitationUsed(invitationId)
{
  if (::is_platform_ps4 && !u.isEmpty(invitationId))
    psnApi.send(psnApi.invitation.use(invitationId))
}

function g_psn_session_invitations::setInvitationsUsed(sessionId)
{
  if (!::is_platform_ps4 || !(isInSession(PSN_SESSION_TYPE.SQUAD) || isInSession(PSN_SESSION_TYPE.SKIRMISH)))
    return

  psnApi.send(psnApi.invitation.list(), function(response, error) {
      if (error)
        return

      local invitations = response?.invitations ?? []
      foreach (invit in invitations)
      {
        if (!invit.usedFlag && invit.sessionId == sessionId)
          setInvitationUsed(invit.invitationId)
      }
    },
    this)
}

function g_psn_session_invitations::sendInvitation(key, psnAccountId)
{
  if (!psnAccountId)
  {
    ::script_net_assert_once("no PSN AcccountID", "[PSSI] Abort invite to "+key+" session")
    return
  }

  local sessionId = getSessionId(key)
  if (u.isEmpty(sessionId))
  {
    ::dagor.debug("[PSSI] Error: empty sessionId for " + key)
    return
  }

  psnApi.send(psnApi.session.invite(sessionId, psnAccountId))
}

function g_psn_session_invitations::getCurrentSessionInfo()
{
  if (!::SessionLobby.isInRoom())
    return {}

  local misData = ::SessionLobby.getMissionData()
  local locIdsArray = []
  if (::getTblValue("locName", misData, "").len() > 0)
    locIdsArray = ::split(misData.locName, "; ")
  else
    locIdsArray = ["missions/" + ::SessionLobby.getMissionName(true)]

  local isFriendOnly = ::SessionLobby.getPublicParam("friendOnly", false)
  local isJipAllowed = ::SessionLobby.getPublicParam("allowJIP", false)
  return {
    locIdsArray = locIdsArray
    isPrivate = isFriendOnly || !isJipAllowed
    maxUsers = ::SessionLobby.getMaxMembersCount()
  }
}

function g_psn_session_invitations::getJsonRequestForSession(key, sessionInfo, isForUpdate = false)
{
  saveSessionData(key, sessionInfo)

  local data = getSavedSessionData(key)
  if (::u.isEmpty(data))
  {
    ::dagor.debug("[PSSI] Session Invitation: No data for key " + key)
    return {}
  }

  local sessionName = ::u.map(data.locIdsArray, @(locId) ::loc(locId, ""))
  local feedTextsArray = ::g_localization.getFilledFeedTextByLang(data.locIdsArray)
  local sessionNames = ::g_localization.formatLangTextsInJsonStyle(feedTextsArray)

  local isForSquad = key == PSN_SESSION_TYPE.SQUAD
  local jsonRequest = []
  jsonRequest.append("\"sessionPrivacy\":\"" + (data.isPrivate ? "private" : "public") + "\"")
  jsonRequest.append("\"sessionMaxUser\": " + data.maxUsers + "")
  jsonRequest.append("\"sessionName\":\"" + sessionName + "\"")
  jsonRequest.append("\"localizedSessionNames\": [" + sessionNames + "]")
  jsonRequest.append("\"sessionLockFlag\":" + false)

  if (!isForUpdate)
  {
    jsonRequest.append("\"index\": " + ::getTblValue(key, sessionTypeToIndex, -1))
    jsonRequest.append("\"sessionType\":\"" + (isForSquad ? "owner-migration" : "owner-bind") + "\"")
    jsonRequest.append("\"availablePlatforms\": [\"PS4\"]")
  }

  return "{\r\n" + ::g_string.implode(jsonRequest, ",\r\n") + "\r\n}\r\n"
}

function g_psn_session_invitations::sendSkirmishInvitation(psnAccountId)
{
  return sendInvitation(PSN_SESSION_TYPE.SKIRMISH, psnAccountId)
}

function g_psn_session_invitations::createSquadSession(leaderUid, cb=function(r, e){})
{
  local squadInfo = {
    locIdsArray = ["ps4/session/squad"]
    isPrivate = true
    maxUsers = ::g_squad_manager.getMaxSquadSize()
  }

  dagor.debug("[PSSI] createSquadSession: from "+leaderUid)
  sendCreateSession(PSN_SESSION_TYPE.SQUAD,
                    getJsonRequestForSession(PSN_SESSION_TYPE.SQUAD, squadInfo),
                    "ui/images/reward05.jpg",
                    ::save_to_json({
                      squadId = leaderUid
                      leaderId = leaderUid
                      key = PSN_SESSION_TYPE.SQUAD
                    }),
                    cb)
}

function g_psn_session_invitations::destroySquadSession()
{
  if (isInMenu())
  {
    suspendedSquadDisband = false
    sendLeaveSession(PSN_SESSION_TYPE.SQUAD)
  }
  else
    suspendedSquadDisband = true
}

function g_psn_session_invitations::sendSquadInvitation(psnAccountId)
{
  if (!isInSession(PSN_SESSION_TYPE.SQUAD)) //because we are creating the squad via invite
    createSquadSession(::my_user_id_str, function(r, e) { sendInvitation(PSN_SESSION_TYPE.SQUAD, psnAccountId) })
  else
    sendInvitation(PSN_SESSION_TYPE.SQUAD, psnAccountId)
}

function g_psn_session_invitations::joinSession(key, sessionId)
{
  if (!::is_platform_ps4 || sessionId == getSessionId(key))
    return

  saveSessionId(key, sessionId)
  psnApi.send(psnApi.session.join(sessionId, sessionTypeToIndex[key]),
      function(response, error) {
        if (error)
          deleteSavedSessionData(key)
        else
          setInvitationsUsed(sessionId)
      },
      this)
}

function g_psn_session_invitations::onEventLobbyStatusChange(params)
{
  if (!::is_platform_ps4
      || (::SessionLobby.isInRoom() && ::get_game_mode() != ::GM_SKIRMISH))
    return

  local haveSessionOnPsn = isInSession(PSN_SESSION_TYPE.SKIRMISH)
  if (::SessionLobby.isInRoom()) //because roomId exists
  {
    if (haveSessionOnPsn || ::SessionLobby.roomId == INVALID_ROOM_ID)
      return

    if (::SessionLobby.isRoomOwner)
    {
      local cb = function(r, e) {
        ::SessionLobby.setExternalId(getSessionId(PSN_SESSION_TYPE.SKIRMISH))
      }
      sendCreateSession(PSN_SESSION_TYPE.SKIRMISH,
                        getJsonRequestForSession(PSN_SESSION_TYPE.SKIRMISH,
                                                 getCurrentSessionInfo()),
                        "ui/images/reward27.jpg",
                        ::save_to_json({
                          roomId = ::SessionLobby.roomId,
                          inviterUid = ::my_user_id_str,
                          inviterName = ::my_user_name
                          password = ::SessionLobby.password
                          key = PSN_SESSION_TYPE.SKIRMISH
                        }),
                        cb)
    }
    else if (!u.isEmpty(::SessionLobby.getExternalId()))
      joinSession(PSN_SESSION_TYPE.SKIRMISH, ::SessionLobby.getExternalId())
  }
  else
    sendLeaveSession(PSN_SESSION_TYPE.SKIRMISH)
}

function g_psn_session_invitations::onEventLobbySettingsChange(params)
{
  if (!::is_platform_ps4 || ::get_game_mode() != ::GM_SKIRMISH)
    return

  if (isSessionParamsEqual(PSN_SESSION_TYPE.SKIRMISH, getCurrentSessionInfo()))
    return

  updateExistingSessionInfo(PSN_SESSION_TYPE.SKIRMISH, getCurrentSessionInfo())
}

function g_psn_session_invitations::onEventSquadStatusChanged(params)
{
  if (!::is_platform_ps4)
    return

  local haveSquadOnPsn = isInSession(PSN_SESSION_TYPE.SQUAD)
  if (::g_squad_manager.isInSquad())
  {
    local psnSessionId = ::g_squad_manager.getPsnSessionId()
    if (::g_squad_manager.isSquadMember() && !haveSquadOnPsn && !u.isEmpty(psnSessionId))
      joinSession(PSN_SESSION_TYPE.SQUAD, psnSessionId)
  }
  else if (haveSquadOnPsn)
    destroySquadSession()
}

function g_psn_session_invitations::checkAfterFlight()
{
  if (suspendedSquadDisband)
    destroySquadSession()

  if (suspendedInvitationData)
    onReceiveInvite(suspendedInvitationData)
  suspendedInvitationData = null
}

function g_psn_session_invitations::onReceiveInvite(invitationData = null)
{
  if (::is_in_loading_screen() || !::g_login.isLoggedIn())
  {
    suspendedInvitationData = invitationData
    ::broadcastEvent("PS4AvailableNewInvite")
    return
  }

  if (!::isInMenu())
  {
    suspendedInvitationData = invitationData
    ::get_cur_gui_scene().performDelayed(this, function() {
      ::showInfoMsgBox(::loc("msgbox/add_to_squad_after_fight"), "add_to_squad_after_fight")
    })
    return
  }

  local sessionId = invitationData?.sessionId
  if (sessionId)
  {
    local cb = function(response, error) {
      if (!error)
      {
        local sessionData = ::u.extend(response, invitationData)

        if (sessionData.key == PSN_SESSION_TYPE.SKIRMISH)
          ::g_invites.addPsnSessionRoomInvite(sessionData)
        else if (sessionData.key == PSN_SESSION_TYPE.SQUAD)
          ::g_invites.addPsnSquadInvite(sessionData)
      }
    }
    psnApi.send(psnApi.session.data(sessionId), cb, this)
  }
}

::g_script_reloader.registerPersistentDataFromRoot("g_psn_session_invitations")
::subscribe_handler(::g_psn_session_invitations, ::g_listener_priority.DEFAULT_HANDLER)

//Called from C++
::on_ps4_session_invitation <- ::g_psn_session_invitations.onReceiveInvite.bindenv(::g_psn_session_invitations)
