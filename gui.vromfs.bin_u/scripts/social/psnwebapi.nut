enum PSN_WEBAPI_PART {
  BINARY = "application/octet-stream"
  IMAGE = "image/jpeg"
  JSON = "application/json; encoding=utf-8"
}

local function createRequest(api, method, path=null, params=null, data=null)
{
  local request = ::DataBlock()
  request.apiGroup = api.group
  request.method = method
  request.path = api.path + (path ? "/" + path : "") + (params ? "?" + params : "")
  request.multipart = u.isArray(data)

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

  local makeHeader = function(name, value) {
    local hdr = ::DataBlock()
    hdr.name = name
    hdr.value = value
    return hdr
  }
  local headers = ::DataBlock()
  headers.content <- makeHeader("Content-Type", type)
  headers.content <- makeHeader("Content-Description", name)
  if (type == PSN_WEBAPI_PART.IMAGE || type == PSN_WEBAPI_PART.BINARY)
    headers.content <- makeHeader("Content-Disposition", "attachment")
  part.reqHeaders = headers

  if (type == PSN_WEBAPI_PART.IMAGE)
    part.filePath = data
  else
    part.data = u.isTable(data) ? ::save_to_json(data) : data
  return part
}


// ------------ Session actions
session <- { group = "sdk:sessionInvitation", path = "/v1/sessions" }

function session::create(info, image, data)
{
  local parts = [createPart(PSN_WEBAPI_PART.JSON, "session-request", info)]
  if (!u.isEmpty(image))
    parts.append(createPart(PSN_WEBAPI_PART.IMAGE, "session-image", image))
  if (!u.isEmpty(data))
    parts.append(createPart(PSN_WEBAPI_PART.BINARY, "session-data", data))
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
  return createRequest(this, ::HTTP_METHOD_GET, sessionId+"/sessionData")
}

function session::invite(sessionId, accountId, data={})
{
  local parts = [createPart(PSN_WEBAPI_PART.JSON, "invitation-request", {to=[accountId]})]
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
  local request = createRequest(this, ::HTTP_METHOD_GET, "friendList", params)
  request.respSize = 8*1024
  return request
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

  send = function(action, onResponse=function(r, e){}, handler=null) {
    local cb = handler ? ::Callback(onResponse, handler) : onResponse
    ::get_cur_gui_scene().performDelayed(this, function() {
        local ret = ::ps4_web_api_request(action)
        if (ret?.error)
        {
          ::dagor.debug("[PSWA] Error: " + ret.error)
          ::dagor.debug("[PSWA] Error text: " + ret.errorStr)
        }

        if (ret?.response)
          ::dagor.debug("[PSSI] Response: " + ret.response)

        cb(ret?.response ? ::parse_json(ret.response) : {}, ret?.error)
      })
  }
}

