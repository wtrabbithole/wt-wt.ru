::g_psn_session_invitations <- {
  existingSession = {}
  curSessionParams = {}
  existingSessionSkirmish = "skirmish"

  updateTimerLimit = 60000
  lastUpdate = 0
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
  curSessionParams[key] <- clone data
}

function g_psn_session_invitations::getSavedSessionData(key)
{
  return ::getTblValue(key, curSessionParams, {})
}

function g_psn_session_invitations::isSessionParamsEqual(key, checkData)
{
  return ::u.isEqual(::getTblValue(key, curSessionParams, {}), checkData)
}

function g_psn_session_invitations::sendCreateSession()
{
  if (!::is_platform_ps4 || !::SessionLobby.isRoomOwner)
    return

  if (getSessionId(existingSessionSkirmish) != "")
  {
    ::dagor.debug("psnSessionInvitations: Cannot create new session for " + existingSessionSkirmish)
    ::dagor.debug("psnSessionInvitations: because of existing session = " + existingSession[existingSessionSkirmish])
    ::dagor.debug("psnSessionInvitations: update info instead")
    updateExistedSessionInfo()
    return
  }

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
  jsonBlockPart.data = getJsonRequestForSession()
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
  jsonBlockPart.filePath <- "ui/images/reward27.jpg" //JPEG image binary data up to 160 KiB
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
  local hex = ::str_to_hex(::SessionLobby.getMissionName(true))
  jsonBlockPart.data <- !::u.isEmpty(hex)? hex : "00010001000003a8"
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
    saveSessionId(existingSessionSkirmish, ::parse_json(ret.response).sessionId)
  }
}

function g_psn_session_invitations::updateExistedSessionInfo()
{
  if (!::is_platform_ps4)
    return

  local sessionId = getSessionId(existingSessionSkirmish)
  if (sessionId == "")
    return

  if (::dagor.getCurTime() - lastUpdate < updateTimerLimit)
  {
    ::dagor.debug("psnSessionInvitations: Too often update call")
    return
  }

  lastUpdate = ::dagor.getCurTime()

  local blk = ::DataBlock()
  blk.apiGroup = "sessionInvitation"
  blk.method = ::HTTP_METHOD_PUT
  blk.path = "/v1/sessions/" + sessionId
  blk.request = getJsonRequestForSession(true)

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

function g_psn_session_invitations::sendInvitation(onlineId)
{
  local sessionId = getSessionId(existingSessionSkirmish)
  if (sessionId == "")
  {
    ::dagor.debug("PSN Invitation: Error: empty sessionId")
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
//----------- <Content-Description: session-request> ---------------
  content.clearData()
  content.name = "Content-Description"
  content.value = "invitation-request"
  headers.content <- content
//----------- </Content-Description: session-request> --------------

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

function g_psn_session_invitations::getJsonRequestForSession(isForUpdate = false)
{
  saveSessionData(existingSessionSkirmish, getCurrentSessionInfo())

  local data = getSavedSessionData(existingSessionSkirmish)

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

function g_psn_session_invitations::onEventLobbyStatusChange(params)
{
  if (!::is_platform_ps4
      || ::get_game_mode() != ::GM_SKIRMISH)
    return

  if (::SessionLobby.isInRoom())
  {
    if (getSessionId(existingSessionSkirmish) != "")
      return

    sendCreateSession()
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

  updateExistedSessionInfo()
}

::subscribe_handler(::g_psn_session_invitations, ::g_listener_priority.DEFAULT_HANDLER)