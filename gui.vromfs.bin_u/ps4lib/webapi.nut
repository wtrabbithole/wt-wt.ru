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
  request.path = "".concat(api.path, ((path != null) ? "/{0}".subst(path) : ""), ((params != null) ? "?{0}".subst(params): ""))
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
local sessionApi = { group = "sdk:sessionInvitation", path = "/v1/sessions" }
local session = {
  function create(info, image, data) {
    local parts = [createPart(webApiMimeTypeJson, "session-request", info)]
    if (image != null && image.len() > 0)
      parts.append(createPart(webApiMimeTypeImage, "session-image", image))
    if (data != null && data.len() > 0)
      parts.append(createPart(webApiMimeTypeBinary, "changeable-session-data", data))
    return createRequest(sessionApi, webApiMethodPost, null, null, parts)
  }

  function update(sessionId, sessionInfo) {
    return createRequest(sessionApi, webApiMethodPut, sessionId, null, sessionInfo)
  }

  function join(sessionId, index=0) {
    return createRequest(sessionApi, webApiMethodPost, "".concat(sessionId,"/members"), "index={0}".subst(index))
  }

  function leave(sessionId) {
    return createRequest(sessionApi, webApiMethodDelete, "".concat(sessionId,"/members/me"))
  }

  function data(sessionId) {
    return createRequest(sessionApi, webApiMethodGet, "".concat(sessionId,"/changeableSessionData"))
  }

  function change(sessionId, changedata) {
    return createRequest(sessionApi, webApiMethodPut, "".concat(sessionId,"/changeableSessionData"), null, changedata, true)
  }

  function invite(sessionId, accounts, invitedata={}) {
    if (::type(accounts) == "string")
      accounts = [accounts]
    local parts = [createPart(webApiMimeTypeJson, "invitation-request", {to=accounts})]
    if (invitedata != null && invitedata.len() > 0)
      parts.append(createPart(webApiMimeTypeBinary, "invitation-data", invitedata))
    return createRequest(sessionApi, webApiMethodPost, "".concat(sessionId,"/invitations"), null, parts)
  }
}



// ------------ Invitation actions
local invitationApi = { group = "sdk:sessionInvitation", path = "/v1/users/me/invitations" }
local invitation = {
  function use(invitationId) {
    return createRequest(invitationApi, webApiMethodPut, invitationId, null, {usedFlag = true})
  }

  function list() {
    return createRequest(invitationApi, webApiMethodGet, null, "fields=@default,sessionId")
  }
}

// ------------ Profile actions
local profileApi = { group = "sdk:userProfile", path = "/v1/users/me" }
local profile = {
  function listFriends(offset, limit) {
    local params = string.format("friendStatus=friend&presenceType=incontext&offset=%d&limit=%d", offset, limit)
    return createRequest(profileApi, webApiMethodGet, "friendList", params)
  }
}

// ------------ Activity Feed actions
local feedApi = { group = "sdk:activityFeed", path = "/v1/users/me" }
local feed = {
  function post(message) {
    return createRequest(feedApi, webApiMethodPost, "feed", null, message)
  }
}

// ----------- Commerce actions
local commerceApi = { group = "sdk:commerce" path = "/v1/users/me/container" }
local commerce = {
  function getProductsInfo(productsList = [], offset = 0, limit = 20) {
    local plist = ":".join(productsList)
    local params = "start={0}&size={1}".subst(offset, limit)
    return createRequest(commerceApi, webApiMethodGet, plist, null, params)
  }
}

// ---------- Entitlement actions
local entitlementApi = { group = "sdk:entitlement", path = "/v1/users/me/entitlements"}
local entitlement = {
  function getUserEntitlements(offset = 0, limit = 20) {
    local params = "entitlement_type=service&entitlement_type=unified&start={0}&size={1}".subst(offset, limit)
    return createRequest(entitlementApi, webApiMethodGet, null, params)
  }
}

return {
  session = session
  invitation = invitation
  profile = profile
  feed = feed
  commerce = commerce
  entitlement = entitlement

  noOpCb = noOpCb
}
