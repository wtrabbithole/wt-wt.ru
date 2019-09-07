local DataBlock = require("DataBlock")
local string = require("string")
local json = require_optional("json")
local toJson = json?.to_string ?? ::save_to_json

local webApiMimeTypeBinary = "application/octet-stream"
local webApiMimeTypeImage = "image/jpeg"
local webApiMimeTypeJson = "application/json; encoding=utf-8"

local webApiMethodGet = 0
local webApiMethodPost = 1
local webApiMethodPut = 2
local webApiMethodDelete = 3

local function createRequest(api, method, path=null, params=null, data=null, forceBinary=false) {
  local request = DataBlock()
  request.apiGroup = api.group
  request.method = method
  request.path = api.path + ((path != null) ? "/" + path : "") + ((params != null) ? "?" + params : "")
  request.forceBinary = forceBinary

  if (::type(data) == "string")
    request.request = data
  if (::type(data) == "table")
    request.request = toJson(data)
  else if (::type(data) == "array")
    foreach(part in data)
      request.part <- part
  return request
}

local function createPart(mimeType, name, data) {
  local part = DataBlock()
  part.reqHeaders = DataBlock()
  part.reqHeaders["Content-Type"] = mimeType
  part.reqHeaders["Content-Description"] = name
  if (mimeType == webApiMimeTypeImage || mimeType == webApiMimeTypeBinary)
    part.reqHeaders["Content-Disposition"] = "attachment"

  if (mimeType == webApiMimeTypeImage)
    part.filePath = data
  else
    part.data = (::type(data) == "table") ? toJson(data) : data
  return part
}

local function noOpCb(response, err) { /* NO OP */ }


// ------------ Session actions
local sessionParams = { group = "sdk:sessionInvitation", path = "/v1/sessions" }
local session = {
  function create(info, image, data) {
    local parts = [createPart(webApiMimeTypeJson, "session-request", info)]
    if (image != null && image.len() > 0)
      parts.append(createPart(webApiMimeTypeImage, "session-image", image))
    if (data != null && data.len() > 0)
      parts.append(createPart(webApiMimeTypeBinary, "changeable-session-data", data))
    return createRequest(sessionParams, webApiMethodPost, null, null, parts)
  }

  function update(sessionId, sessionInfo) {
    return createRequest(sessionParams, webApiMethodPut, sessionId, null, sessionInfo)
  }

  function join(sessionId, index=0) {
    return createRequest(sessionParams, webApiMethodPost, sessionId+"/members", "index="+index)
  }

  function leave(sessionId) {
    return createRequest(sessionParams, webApiMethodDelete, sessionId+"/members/me")
  }

  function data(sessionId) {
    return createRequest(sessionParams, webApiMethodGet, sessionId+"/changeableSessionData")
  }

  function change(sessionId, changedata) {
    return createRequest(sessionParams, webApiMethodPut, sessionId+"/changeableSessionData", null, changedata, true)
  }

  function invite(sessionId, accounts, invitedata={}) {
    if (::type(accounts) == "string")
      accounts = [accounts]
    local parts = [createPart(webApiMimeTypeJson, "invitation-request", {to=accounts})]
    if (invitedata != null && invitedata.len() > 0)
      parts.append(createPart(webApiMimeTypeBinary, "invitation-data", invitedata))
    return createRequest(sessionParams, webApiMethodPost, sessionId+"/invitations", null, parts)
  }
}



// ------------ Invitation actions
local invitationParams = { group = "sdk:sessionInvitation", path = "/v1/users/me/invitations" }
local invitation = {
  function use(invitationId) {
    return createRequest(invitationParams, webApiMethodPut, invitationId, null, {usedFlag = true})
  }

  function list() {
    return createRequest(invitationParams, webApiMethodGet, null, "fields=@default,sessionId")
  }
}

// ------------ Profile actions
local profileParams = { group = "sdk:userProfile", path = "/v1/users/me" }
local profile = {
  function listFriends(offset, limit) {
    local params = string.format("friendStatus=friend&presenceType=incontext&offset=%d&limit=%d", offset, limit)
    return createRequest(profileParams, webApiMethodGet, "friendList", params)
  }
}

// ------------ Activity Feed actions
local feedParams = { group = "sdk:activityFeed", path = "/v1/users/me" }
local feed = {
  function post(message) {
    return createRequest(feedParams, webApiMethodPost, "feed", null, message)
  }
}

return {
  session = session
  invitation = invitation
  profile = profile
  feed = feed

  noOpCb = noOpCb
}