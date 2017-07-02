::g_psn_session_invitations <- {
  existingSession = {}
  curSessionParams = {}
  lastUpdateTable = {}
  existingSessionSkirmish = "skirmish"
  existingSessionSquad = "squad"

  updateTimerLimit = 60000
}

function g_psn_session_invitations::saveSessionId(key, sessionId)
{
  if (key in existingSession)
  {
    ::dagor.debug("psnSessionInvitations: Can't save existing session in " + key)
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

function g_psn_session_invitations::sendCreateSession(key, sessionInfo, image, sessionData = "")
{
  local headers = ::DataBlock()
  local content = ::DataBlock()
  local jsonBlockPart = ::DataBlock()

  local blk = ::DataBlock()
  blk.multipart = true
  blk.apiGroup = "sessionInvitation"
  blk.method = ::HTTP_METHOD_POST
  blk.path = "/v1/sessions"

//********************* <Block Request>********************************/
//Required block
//
//------------- <Content-Type: application/json> -------------------
  content.clearData()
  content.name = "Content-Type"
  content.value = "application/json; charset=utf-8"
  headers.content <- content
//------------- </Content-Type: application/json> ------------------
//
//----------- <Content-Description: session-request> ---------------
  content.clearData()
  content.name = "Content-Description"
  content.value = "session-request"
  headers.content <- content
//----------- </Content-Description: session-request> --------------

  jsonBlockPart.reqHeaders = headers
  jsonBlockPart.data = sessionInfo
  blk.part <- jsonBlockPart
//********************* </Block Request>*******************************/

  headers.reset()
  content.reset()
  jsonBlockPart.reset()

//********************* <Block Image>********************************/
//Required block
//
//------------------- <Content-Type:image/jpeg> --------------------
  content.clearData()
  content.name = "Content-Type"
  content.value = "image/jpeg"
  headers.content <- content
//------------------- </Content-Type:image/jpeg> -------------------
//
//----------- <Content-Description: session-image> -----------------
  content.clearData()
  content.name = "Content-Description"
  content.value = "session-image"
  headers.content <- content
//----------- </Content-Description: session-image> ----------------
//
//------------- <Content-Disposition: attachment> ------------------
  content.clearData()
  content.name = "Content-Disposition"
  content.value = "attachment"
  headers.content <- content
//------------- </Content-Disposition: attachment> -----------------

  jsonBlockPart.reqHeaders <- headers
  jsonBlockPart.filePath <- image //JPEG image binary data up to 160 KiB
  blk.part <- jsonBlockPart
//********************* </Block Image>********************************/

  headers.reset()
  content.reset()
  jsonBlockPart.reset()

//********************* <Block Data>********************************/
//Required block data or changable data
//
//------------------- <Content-Type> --------------------
  content.clearData()
  content.name = "Content-Type"
  content.value = "application/octet-stream"
  headers.content <- content
//------------------- </Content-Type> -------------------
//
//----------- <Content-Description> -----------------
  content.clearData()
  content.name = "Content-Description"
  content.value = "session-data"
  headers.content <- content
//----------- </Content-Description> ----------------
//
//------------- <Content-Disposition> ------------------
  content.clearData()
  content.name = "Content-Disposition"
  content.value = "attachment"
  headers.content <- content
//------------- </Content-Disposition: attachment> -----------------

  jsonBlockPart.reqHeaders <- headers
  jsonBlockPart.data <- sessionData
  blk.part <- jsonBlockPart
//********************* </Block Data>********************************/

  local ret = ::ps4_web_api_request(blk)
  if ("error" in ret)
  {
    ::dagor.debug("Error: " + ret.error)
    ::dagor.debug("Error text: " + ret.errorStr)
  }
  else if ("response" in ret)
  {
    ::dagor.debug("Response: " + ret.response)
    saveSessionId(key, ::parse_json(ret.response).sessionId)
  }
}

function g_psn_session_invitations::updateExistedSessionInfo(key, sessionInfo)
{
  if (!::is_platform_ps4)
    return

  local sessionId = getSessionId(key)
  if (sessionId == "")
    return

  local lastUpdate = ::getTblValue(sessionId, lastUpdateTable, 0)
  if (::dagor.getCurTime() - lastUpdate < updateTimerLimit)
  {
    ::dagor.debug("psnSessionInvitations: Too often update call")
    return
  }

  lastUpdateTable[sessionId] <- ::dagor.getCurTime()

  local blk = ::DataBlock()
  blk.apiGroup = "sessionInvitation"
  blk.method = ::HTTP_METHOD_PUT
  blk.path = "/v1/sessions/" + sessionId
  blk.request = getJsonRequestForSession(key, sessionInfo, true)

  local ret = ::ps4_web_api_request(blk)
  if ("error" in ret)
  {
    ::dagor.debug("Error: " + ret.error)
    ::dagor.debug("Error text: " + ret.errorStr)
  }
  else if ("response" in ret)
  {
    ::dagor.debug("Response: " + ret.response)
  }
}

function g_psn_session_invitations::sendDestroySession(key)
{
  local sessionId = getSessionId(key)
  if (::u.isEmpty(sessionId))
    return

  local blk = ::DataBlock()
  blk.apiGroup = "sessionInvitation"
  blk.method = ::HTTP_METHOD_DELETE
  blk.path = "/v1/sessions/" + sessionId

  deleteSavedSessionData(key)
  local ret = ::ps4_web_api_request(blk)
  if ("error" in ret)
  {
    ::dagor.debug("Error: " + ret.error)
    ::dagor.debug("Error text: " + ret.errorStr)
  }
  else if ("response" in ret)
  {
    ::dagor.debug("Response: " + ret.response)
  }
}

function g_psn_session_invitations::getSessionData(sessionId)
{
  local blk = ::DataBlock()
  blk.apiGroup = "sessionInvitation"
  blk.method = ::HTTP_METHOD_GET
  blk.path = "/v1/sessions/" + sessionId + "/sessionData"

  local ret = ::ps4_web_api_request(blk)
  if ("error" in ret)
  {
    ::dagor.debug("Error: " + ret.error)
    ::dagor.debug("Error text: " + ret.errorStr)
  }
  else if ("response" in ret)
  {
    ::dagor.debug("Response: " + ret.response)
    return ::parse_json(ret.response)
  }

  return null
}

function g_psn_session_invitations::setInvitationUsed(invitationId)
{
  local blk = ::DataBlock()
  blk.apiGroup = "sessionInvitation"
  blk.method = ::HTTP_METHOD_PUT
  blk.path = "/v1/users/me/invitations/" + invitationId
  blk.request = "{\r\n\"usedFlag\":true\r\n}"

  local ret = ::ps4_web_api_request(blk)
  if ("error" in ret)
  {
    ::dagor.debug("Error: " + ret.error)
    ::dagor.debug("Error text: " + ret.errorStr)
  }
  else if ("response" in ret)
  {
    ::dagor.debug("Response: " + ret.response)
  }
}

function g_psn_session_invitations::sendInvitation(key, onlineId)
{
  local sessionId = getSessionId(key)
  if (sessionId == "")
  {
    ::dagor.debug("PSN Invitation: Error: empty sessionId for " + key)
    return
  }

  onlineId = onlineId.slice(0, 1) == "*"? onlineId.slice(1) : onlineId

  local accountId = ::g_psn_mapper.getAccountIdByOnlineId(onlineId)
  if (!accountId)
    return

  local blk = ::DataBlock()
  blk.apiGroup = "sdk:sessionInvitation"
  blk.method = ::HTTP_METHOD_POST
  blk.path = "/v1/sessions/" + sessionId + "/invitations"
  blk.multipart = true

  local headers = ::DataBlock()
  local content = ::DataBlock()

//********************* <Block Request> ********************************/
//Required block
//
//------------- <Content-Type: application/json> -------------------
  content.clearData()
  content.name = "Content-Type"
  content.value = "application/json; charset=utf-8"
  headers.content <- content
//------------- </Content-Type: application/json> ------------------
//
//----------- <Content-Description: invitation-request> ---------------
  content.clearData()
  content.name = "Content-Description"
  content.value = "invitation-request"
  headers.content <- content
//----------- </Content-Description: invitation-request> --------------

  local jsonBlockPart = ::DataBlock()
  jsonBlockPart.reqHeaders = headers
  jsonBlockPart.data = "{\r\n\"to\":[\"" + accountId + "\"]\r\n}"
  blk.part <- jsonBlockPart
//********************* </Block Request> *******************************/

  local ret = ::ps4_web_api_request(blk)
  if ("error" in ret)
  {
    ::dagor.debug("Error: " + ret.error)
    ::dagor.debug("Error text: " + ret.errorStr)
  }
  else if ("response" in ret)
  {
    ::dagor.debug("Response: " + ret.response)
  }
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

  return {
    locIdsArray = locIdsArray
    isFriendsOnly = ::SessionLobby.getPublicParam("friendOnly", false)
    maxUsers = ::SessionLobby.getMaxMembersCount()
  }
}

function g_psn_session_invitations::getCurrentSquadInfo()
{
  if (!::g_squad_manager.isInSquad())
    return {}

  return {
    locIdsArray = ["ps4/session/squad"]
    isFriendsOnly = false
    maxUsers = ::g_squad_manager.maxSquadSize
  }
}

function g_psn_session_invitations::getJsonRequestForSession(key, sessionInfo, isForUpdate = false)
{
  saveSessionData(key, sessionInfo)

  local data = getSavedSessionData(key)
  if (::u.isEmpty(data))
  {
    ::dagor.debug("Session Invitation: No data for key " + key)
    return {}
  }

  local sessionName = ::u.map(data.locIdsArray, @(locId) ::loc(locId, ""))
  local feedTextsArray = ::g_localization.getFilledFeedTextByLang(data.locIdsArray)
  local sessionNames = ::g_localization.formatLangTextsInJsonStyle(feedTextsArray)

  local jsonRequest = []
  jsonRequest.append("\"sessionPrivacy\":\"" + (data.isFriendsOnly? "private" : "public") + "\"")
  jsonRequest.append("\"sessionMaxUser\": " + data.maxUsers + "")
  jsonRequest.append("\"sessionName\":\"" + sessionName + "\"")
  jsonRequest.append("\"localizedSessionNames\": [" + sessionNames + "]")
  jsonRequest.append("\"sessionLockFlag\":" + data.isFriendsOnly)

  if (!isForUpdate)
  {
    jsonRequest.append("\"index\": 0")
    jsonRequest.append("\"sessionType\":\"owner-bind\"")
    jsonRequest.append("\"availablePlatforms\": [\"PS4\"]")
  }

  return "{\r\n" + ::implode(jsonRequest, ",\r\n") + "\r\n}\r\n"
}

function g_psn_session_invitations::sendSkirmishInvitation(userName)
{
  return sendInvitation(existingSessionSkirmish, userName)
}

function g_psn_session_invitations::sendSquadInvitation(userName)
{
  if (!::g_squad_manager.isInSquad())
    return ::g_squad_manager.createSquad(@() ::g_psn_session_invitations.sendSquadInvitation(userName))

  if (!::g_squad_manager.isSquadLeader())
    return

  if (::g_squad_manager.isSquadFull())
    return ::g_popups.add(null, ::loc("matching/SQUAD_FULL"))

  if (::g_squad_manager.isInvitedMaxPlayers())
    return ::g_popups.add(null, ::loc("squad/maximum_intitations_sent"))

  return sendInvitation(existingSessionSquad, userName)
}

function g_psn_session_invitations::onEventLobbyStatusChange(params)
{
  if (!::is_platform_ps4
      || ::get_game_mode() != ::GM_SKIRMISH)
    return

  if (::SessionLobby.isInRoom()) //because roomId is existed
  {
    if (getSessionId(existingSessionSkirmish) != "" || ::SessionLobby.roomId == "")
      return

    if (::SessionLobby.isRoomOwner)
    {
      sendCreateSession(existingSessionSkirmish,
                        getJsonRequestForSession(existingSessionSkirmish,
                                                 getCurrentSessionInfo()),
                        "ui/images/reward27.jpg",
                        ::save_to_json({
                          roomId = ::SessionLobby.roomId,
                          inviterUid = ::my_user_id_str,
                          inviterName = ::my_user_name
                          password = ::SessionLobby.password
                          key = existingSessionSkirmish
                        })
                       )
    }
  }
  else
    sendDestroySession(existingSessionSkirmish)
}

function g_psn_session_invitations::onEventLobbySettingsChange(params)
{
  if (!::is_platform_ps4 || ::get_game_mode() != ::GM_SKIRMISH)
    return

  if (isSessionParamsEqual(existingSessionSkirmish, getCurrentSessionInfo()))
    return

  updateExistedSessionInfo(existingSessionSkirmish, getCurrentSessionInfo())
}

function g_psn_session_invitations::onEventSquadStatusChanged(params)
{
  if (!::is_platform_ps4)
    return

  if (::g_squad_manager.isInSquad() && ::g_squad_manager.canInviteMember())
  {
    if (getSessionId(existingSessionSquad) != "")
      return

    sendCreateSession(existingSessionSquad,
                      getJsonRequestForSession(existingSessionSquad,
                                               getCurrentSquadInfo()),
                      "ui/images/reward05.jpg",
                      ::save_to_json({
                        squadId = ::g_squad_manager.getLeaderUid()
                        key = existingSessionSquad
                      }))
  }
  else if (!::g_squad_manager.isInSquad())
    sendDestroySession(existingSessionSquad)
}

function g_psn_session_invitations::onReceiveInvite(invitationData = null)
{
  if (!::getTblValue("accepted", invitationData, false))
    return

  local sessionId = ::getTblValue("sessionId", invitationData, "")
  if (sessionId == "")
    return

  local sessionData = getSessionData(sessionId)
  if (!sessionData)
  {
    ::dagor.debug("PSN SessionInvitation: Could not receive data by sessionId " + sessionId)
    return
  }

  setInvitationUsed(invitationData.invitationId)

  sessionData = ::u.extend(sessionData, invitationData)

  if (sessionData.key == existingSessionSkirmish)
    ::g_invites.addPsnSessionRoomInvite(sessionData)
  else if (sessionData.key == existingSessionSquad)
    ::g_invites.addPsnSquadInvite(sessionData)
}

::subscribe_handler(::g_psn_session_invitations, ::g_listener_priority.DEFAULT_HANDLER)

//Called from C++
::on_ps4_session_invitation <- ::g_psn_session_invitations.onReceiveInvite.bindenv(::g_psn_session_invitations)