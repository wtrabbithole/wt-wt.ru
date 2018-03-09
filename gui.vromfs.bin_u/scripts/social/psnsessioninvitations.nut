local platformModule = require("scripts/clientState/platform.nut")

enum PSN_SESSION_TYPE {
  SKIRMISH = "skirmish"
  SQUAD = "squad"
}

::g_psn_session_invitations <- {
  [PERSISTENT_DATA_PARAMS] = ["existingSession", "curSessionParams", "lastUpdateTable", "suspendedInvitationData"]

  existingSession = {}
  curSessionParams = {}
  lastUpdateTable = {}

  sessionTypeToIndex = {
    [PSN_SESSION_TYPE.SKIRMISH] = 0,
    [PSN_SESSION_TYPE.SQUAD] = 1
  }

  updateTimerLimit = 60000
  suspendedInvitationData = null
}

function g_psn_session_invitations::saveSessionId(key, sessionId)
{
  if (key in existingSession)
  {
    ::dagor.debug("[PSSI] saveSessionId: Can't save existing session in " + key)
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
  blk.apiGroup = "sdk:sessionInvitation"
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
    ::dagor.debug("[PSSI] Error: " + ret.error)
    ::dagor.debug("[PSSI] Error text: " + ret.errorStr)
  }
  else if ("response" in ret)
  {
    ::dagor.debug("[PSSI] Response: " + ret.response)
    saveSessionId(key, ::parse_json(ret.response).sessionId)
  }
}

function g_psn_session_invitations::updateExistingSessionInfo(key, sessionInfo)
{
  if (!::is_platform_ps4)
    return

  local sessionId = getSessionId(key)
  if (sessionId == "")
    return

  local lastUpdate = ::getTblValue(sessionId, lastUpdateTable, 0)
  if (::dagor.getCurTime() - lastUpdate < updateTimerLimit)
  {
    ::dagor.debug("[PSSI] updateExsitingSessionInfo: Too often update call")
    return
  }

  lastUpdateTable[sessionId] <- ::dagor.getCurTime()

  local blk = ::DataBlock()
  blk.apiGroup = "sdk:sessionInvitation"
  blk.method = ::HTTP_METHOD_PUT
  blk.path = "/v1/sessions/" + sessionId
  blk.request = getJsonRequestForSession(key, sessionInfo, true)

  local ret = ::ps4_web_api_request(blk)
  if ("error" in ret)
  {
    ::dagor.debug("[PSSI] Error: " + ret.error)
    ::dagor.debug("[PSSI] Error text: " + ret.errorStr)
  }
  else if ("response" in ret)
  {
    ::dagor.debug("[PSSI] Response: " + ret.response)
  }
}

function g_psn_session_invitations::sendDestroySession(key)
{
  dagor.debug("[PSSI] sendDestroySession "+key)
  local sessionId = getSessionId(key)
  if (::u.isEmpty(sessionId))
    return

  local blk = ::DataBlock()
  blk.apiGroup = "sdk:sessionInvitation"
  blk.method = ::HTTP_METHOD_DELETE
  blk.path = "/v1/sessions/" + sessionId

  deleteSavedSessionData(key)
  local ret = ::ps4_web_api_request(blk)
  if ("error" in ret)
  {
    ::dagor.debug("[PSSI] Error: " + ret.error)
    ::dagor.debug("[PSSI] Error text: " + ret.errorStr)
  }
  else if ("response" in ret)
  {
    ::dagor.debug("[PSSI] Response: " + ret.response)
  }
}

function g_psn_session_invitations::getSessionData(sessionId)
{
  dagor.debug("[PSSI] getSessionData: "+sessionId)
  local blk = ::DataBlock()
  blk.apiGroup = "sdk:sessionInvitation"
  blk.method = ::HTTP_METHOD_GET
  blk.path = "/v1/sessions/" + sessionId + "/sessionData"

  local ret = ::ps4_web_api_request(blk)
  if ("error" in ret)
  {
    ::dagor.debug("[PSSI] Error: " + ret.error)
    ::dagor.debug("[PSSI] Error text: " + ret.errorStr)
  }
  else if ("response" in ret)
  {
    ::dagor.debug("[PSSI] Response: " + ret.response)
    return ::parse_json(ret.response)
  }

  return null
}

function g_psn_session_invitations::setInvitationUsed(invitationId)
{
  if (!::is_platform_ps4 || invitationId == "")
    return

  dagor.debug("[PSSI] setInvitationUsed: "+invitationId)

  local blk = ::DataBlock()
  blk.apiGroup = "sdk:sessionInvitation"
  blk.method = ::HTTP_METHOD_PUT
  blk.path = "/v1/users/me/invitations/" + invitationId
  blk.request = "{\r\n\"usedFlag\":true\r\n}"

  local ret = ::ps4_web_api_request(blk)
  if ("error" in ret)
  {
    ::dagor.debug("[PSSI] Error: " + ret.error)
    ::dagor.debug("[PSSI] Error text: " + ret.errorStr)
  }
  else if ("response" in ret)
  {
    ::dagor.debug("[PSSI] Response: " + ret.response)
  }
}

function g_psn_session_invitations::getInvitationsList()
{
  if (!::is_platform_ps4)
    return

  dagor.debug("[PSSI] getInvitationsList")
  local blk = ::DataBlock()
  blk.apiGroup = "sdk:sessionInvitation"
  blk.method = ::HTTP_METHOD_GET
  blk.path = "/v1/users/me/invitations?fields=@default,sessionId"

  local ret = ::ps4_web_api_request(blk)
  if ("error" in ret)
  {
    ::dagor.debug("[PSSI] Error: " + ret.error)
    ::dagor.debug("[PSSI] Error text: " + ret.errorStr)
  }
  else if ("response" in ret)
  {
    ::dagor.debug("[PSSI] Response: " + ret.response)
    return ::parse_json(ret.response)
  }
  return null
}

function g_psn_session_invitations::setInvitationsUsed()
{
  if (!::is_platform_ps4)
    return

  local squadSessionId = ::g_squad_manager.getPsnSessionId()
  local invitationsData = ::g_psn_session_invitations.getInvitationsList()
  local invitations = invitationsData?.invitations ?? []
  foreach (invit in invitations)
  {
    if (invit.usedFlag)
      continue

    if (squadSessionId != "" && invit.sessionId != squadSessionId)
      continue

    setInvitationUsed(invit.invitationId)
  }
}

function g_psn_session_invitations::sendInvitation(key, psnAccountId)
{
  if (!psnAccountId)
  {
    ::script_net_assert_once("no PSN AcccountID", "[PSSI] Abort invite to "+key+" session")
    return
  }

  local sessionId = getSessionId(key)
  if (sessionId == "")
  {
    ::dagor.debug("[PSSI] Error: empty sessionId for " + key)
    return
  }

  dagor.debug("[PSSI] sendInvitation to "+key)
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
  jsonBlockPart.data = "{\r\n\"to\":[\"" + psnAccountId + "\"]\r\n}"
  blk.part <- jsonBlockPart
//********************* </Block Request> *******************************/

  local ret = ::ps4_web_api_request(blk)
  if ("error" in ret)
  {
    ::dagor.debug("[PSSI] Error: " + ret.error)
    ::dagor.debug("[PSSI] Error text: " + ret.errorStr)
  }
  else if ("response" in ret)
  {
    ::dagor.debug("[PSSI] Response: " + ret.response)
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
  jsonRequest.append("\"sessionPrivacy\":\"" + ((data.isFriendsOnly || isForSquad) ? "private" : "public") + "\"")
  jsonRequest.append("\"sessionMaxUser\": " + data.maxUsers + "")
  jsonRequest.append("\"sessionName\":\"" + sessionName + "\"")
  jsonRequest.append("\"localizedSessionNames\": [" + sessionNames + "]")
  jsonRequest.append("\"sessionLockFlag\":" + data.isFriendsOnly)

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

function g_psn_session_invitations::createSquadSession(leaderUid)
{
  local squadInfo = {
    locIdsArray = ["ps4/session/squad"]
    isFriendsOnly = false
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
                    }))
}

function g_psn_session_invitations::sendSquadInvitation(psnAccountId)
{
  if (getSessionId(PSN_SESSION_TYPE.SQUAD) == "")
    createSquadSession(::my_user_id_str) //because we are creating the squad via invite

  return sendInvitation(PSN_SESSION_TYPE.SQUAD, psnAccountId)
}

function g_psn_session_invitations::onEventLobbyStatusChange(params)
{
  if (!::is_platform_ps4
      || ::get_game_mode() != ::GM_SKIRMISH)
    return

  if (::SessionLobby.isInRoom()) //because roomId exists
  {
    if (getSessionId(PSN_SESSION_TYPE.SKIRMISH) != "" || ::SessionLobby.roomId == "")
      return

    if (::SessionLobby.isRoomOwner)
    {
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
                        })
                       )
    }
  }
  else
    sendDestroySession(PSN_SESSION_TYPE.SKIRMISH)
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

  if (::g_squad_manager.isInSquad())
  {
    if (::g_squad_manager.isSquadMember())
    {
      setInvitationsUsed()
      return
    }

    if (::g_squad_manager.canInviteMember() && getSessionId(PSN_SESSION_TYPE.SQUAD) == "")
      createSquadSession(::g_squad_manager.getLeaderUid())
  }
  else
    sendDestroySession(PSN_SESSION_TYPE.SQUAD)
}

function g_psn_session_invitations::checkReceievedInvitation()
{
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

  local sessionId = ::getTblValue("sessionId", invitationData, "")
  if (sessionId == "")
    return

  local sessionData = getSessionData(sessionId)
  if (::u.isEmpty(sessionData))
  {
    ::dagor.debug("[PSSI] onReceiveInvite: Could not receive data by sessionId " + sessionId)
    return
  }

  sessionData = ::u.extend(sessionData, invitationData)

  if (sessionData.key == PSN_SESSION_TYPE.SKIRMISH)
    ::g_invites.addPsnSessionRoomInvite(sessionData)
  else if (sessionData.key == PSN_SESSION_TYPE.SQUAD)
    ::g_invites.addPsnSquadInvite(sessionData)
}

::g_script_reloader.registerPersistentDataFromRoot("g_psn_session_invitations")
::subscribe_handler(::g_psn_session_invitations, ::g_listener_priority.DEFAULT_HANDLER)

//Called from C++
::on_ps4_session_invitation <- ::g_psn_session_invitations.onReceiveInvite.bindenv(::g_psn_session_invitations)
