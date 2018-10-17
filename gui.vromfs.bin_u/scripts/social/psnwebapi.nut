enum PSN_WEBAPI_PART {
  BINARY = "application/octet-stream"
  IMAGE = "image/jpeg"
  JSON = "application/json; encoding=utf-8"
}

local function createRequest(api, method, path=null, params=null, data=null, forceBinary=false)
{
  local request = ::DataBlock()
  request.apiGroup = api.group
  request.method = method
  request.path = api.path + (path ? "/" + path : "") + (params ? "?" + params : "")
  request.forceBinary = forceBinary

  if (u.isString(data))
    request.request = data
  if (u.isTable(data))
    request.request = ::save_to_json(data)
  else if (u.isArray(data))
    foreach(part in data)
      request.part <- part
  return request
}

local function createPart(type, name, data)
{
  local part = ::DataBlock()
  part.reqHeaders = ::DataBlock()
  part.reqHeaders["Content-Type"] = type
  part.reqHeaders["Content-Description"] = name
  if (type == PSN_WEBAPI_PART.IMAGE || type == PSN_WEBAPI_PART.BINARY)
    part.reqHeaders["Content-Disposition"] = "attachment"

  if (type == PSN_WEBAPI_PART.IMAGE)
    part.filePath = data
  else
    part.data = u.isTable(data) ? ::save_to_json(data) : data
  return part
}

local function noOpCb(response, error) { /* NO OP */ }

// ------------ Session actions
session <- { group = "sdk:sessionInvitation", path = "/v1/sessions" }

function session::create(info, image, data)
{
  local parts = [createPart(PSN_WEBAPI_PART.JSON, "session-request", info)]
  if (!u.isEmpty(image))
    parts.append(createPart(PSN_WEBAPI_PART.IMAGE, "session-image", image))
  if (!u.isEmpty(data))
    parts.append(createPart(PSN_WEBAPI_PART.BINARY, "changeable-session-data", data))
  return createRequest(this, ::HTTP_METHOD_POST, null, null, parts)
}

function session::update(sessionId, sessionInfo)
{
  return createRequest(this, ::HTTP_METHOD_PUT, sessionId, null, sessionInfo)
}

function session::join(sessionId, index=0)
{
  return createRequest(this, ::HTTP_METHOD_POST, sessionId+"/members", "index="+index)
}

function session::leave(sessionId)
{
  return createRequest(this, ::HTTP_METHOD_DELETE, sessionId+"/members/me")
}

function session::data(sessionId)
{
  return createRequest(this, ::HTTP_METHOD_GET, sessionId+"/changeableSessionData")
}

function session::change(sessionId, data)
{
  return createRequest(this, ::HTTP_METHOD_PUT, sessionId+"/changeableSessionData", null, data, true)
}


function session::invite(sessionId, accounts, data={})
{
  if (u.isString(accounts))
    accounts = [accounts]
  local parts = [createPart(PSN_WEBAPI_PART.JSON, "invitation-request", {to=accounts})]
  if (!u.isEmpty(data))
    parts.append(createPart(PSN_WEBAPI_PART.BINARY, "invitation-data", data))
  return createRequest(this, ::HTTP_METHOD_POST, sessionId+"/invitations", null, parts)
}


// ------------ Invitation actions
invitation <- { group = "sdk:sessionInvitation", path = "/v1/users/me/invitations" }

function invitation::use(invitationId)
{
  return createRequest(this, ::HTTP_METHOD_PUT, invitationId, null, {usedFlag = true})
}

function invitation::list()
{
  return createRequest(this, ::HTTP_METHOD_GET, null, "fields=@default,sessionId")
}


// ------------ Profile actions
profile <- { group = "sdk:userProfile", path = "/v1/users/me" }

function profile::listFriends(offset, limit)
{
  local params = ::format("friendStatus=friend&presenceType=incontext&offset=%d&limit=%d", offset, limit)
  return createRequest(this, ::HTTP_METHOD_GET, "friendList", params)
}


// ------------ Activity Feed actions
feed <- { group = "sdk:activityFeed", path = "/v1/users/me" }

function feed::post(message)
{
  return createRequest(this, ::HTTP_METHOD_POST, "feed", null, message)
}


return {
  session = session
  invitation = invitation
  profile = profile
  feed = feed

  noOpCb = noOpCb

  send = function(action, onResponse=noOpCb, handler=null) {
    local cb = handler ? ::Callback(onResponse, handler) : onResponse
    ::ps4_send_web_api_request(action,
        @(r) cb(r?.response ? ::parse_json(r.response) : null, r?.error))
  }
}

